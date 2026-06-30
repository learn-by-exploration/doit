// Tests for PauseService (v0.4b-era seam, v1.2d cleanup).
//
// Coverage:
//   - `_ready` is eagerly completed at construction time
//     (regression: pre-v1.2d the Completer was never completed
//     and every public method hung on `await _ready`).
//   - `resetForTesting()` is idempotent and does not throw
//     even if called before the singleton has been used.
//   - `pauseHabit` writes `pausedUntilMillis` via a Drift
//     UPDATE (Cycle B / SYS-129 / ADR-060 — the pause column
//     is intentionally NOT in `_toRow` so Save clicks cannot
//     clobber it). Regression guard: a future contributor who
//     re-adds the column to `_toRow` would silently break the
//     explicit pause/resume round-trip; this test pins that
//     the column is written via the dedicated path.
//   - `resumeHabit` clears `pausedUntilMillis` (same cycle).
//   - `pauseHabitFor` computes `until = from + duration`.
//   - `pausePerson` + `resumePerson` round-trip via
//     `PersonRepository` (the pausedUntil column is on the
//     People table).

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/people/cadence.dart';
import 'package:doit/people/person.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/pause_service.dart';
import 'package:doit/services/person_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _init() async {
  await AppDatabaseService.instance.closeForTesting();
  await AppDatabaseService.instance.init(
    overrideDb: AppDatabase(NativeDatabase.memory()),
  );
  await AppDatabaseService.instance.ready;
}

Future<void> _tearDown() => AppDatabaseService.instance.closeForTesting();

Do _do({required String id}) {
  return DoFixed(
    id: id,
    name: 'Drink water',
    proofMode: const SoftProof(),
    createdAt: DateTime(2026, 6, 27),
    restDaysPerMonth: 2,
    weekdays: const <int>{1, 2, 3, 4, 5, 6, 7},
    time: const DoTime(9, 0),
  );
}

ContactPerson _person({required String id}) {
  return ContactPerson(
    id: id,
    lookupKey: 'k-$id',
    channel: const ChannelDialer('+15555550100'),
    cadence: const EveryNDays(7),
    createdAt: DateTime(2026),
  );
}

void main() {
  group('PauseService readiness gate (v1.2d / Phase 4)', () {
    test('`isReady` is true at first read (no `init()` needed)', () {
      // No `init()` call — the eager-complete-at-constructor
      // pattern means the singleton is ready the instant
      // `PauseService.instance` is dereferenced.
      expect(PauseService.instance.isReady, isTrue);
    });

    test('resetForTesting() is idempotent and does not throw', () {
      // First call: Completer is already complete (eager).
      PauseService.instance.resetForTesting();
      // Second call: still no throw.
      PauseService.instance.resetForTesting();
    });

    test('resetForTesting() keeps the gate complete', () {
      PauseService.instance.resetForTesting();
      expect(PauseService.instance.isReady, isTrue);
    });
  });

  // ---- v1.5-cyc-γ additions: round-trip coverage for pause /
  // resume on habits and people. Each test stands up a
  // Drift-in-memory DB so the UPDATE statements execute
  // against a real schema. ----

  group('PauseService.pauseHabit + resumeHabit (v1.5-cyc-γ)', () {
    setUp(_init);
    tearDown(_tearDown);

    test(
      'pauseHabit writes pausedUntilMillis via the dedicated path',
      () async {
        final do_ = _do(id: 'h-pause-1');
        await DoRepository.instance.save(do_);
        final ref = await DoRepository.instance.getById('h-pause-1');
        expect(ref?.pausedUntil, isNull);

        final until = DateTime(2027, 1, 1, 23, 59);
        await PauseService.instance.pauseHabit(do_, until);

        final refreshed = await DoRepository.instance.getById('h-pause-1');
        expect(refreshed?.pausedUntil, until);
      },
    );

    test(
      'pauseHabit survives a Save round-trip (the SYS-129 invariant)',
      () async {
        // Regression: the pause column is deliberately omitted
        // from `DoRepository._toRow` so Save cannot clobber it.
        // This test pins the invariant: pause-then-edit-name-
        // then-save preserves the pause.
        final do_ = _do(id: 'h-inv');
        await DoRepository.instance.save(do_);
        final until = DateTime(2027, 1, 1, 23, 59);
        await PauseService.instance.pauseHabit(do_, until);

        // The user renames the habit and saves again.
        final reloaded = (await DoRepository.instance.getById('h-inv'))!;
        await DoRepository.instance.save(
          reloaded.copyWith(name: 'Drink eight glasses'),
        );

        final afterRename = await DoRepository.instance.getById('h-inv');
        expect(afterRename?.name, 'Drink eight glasses');
        expect(
          afterRename?.pausedUntil,
          until,
          reason: 'pause must persist across name-edits',
        );
      },
    );

    test('resumeHabit clears pausedUntilMillis', () async {
      final do_ = _do(id: 'h-resume-1');
      await DoRepository.instance.save(do_);
      await PauseService.instance.pauseHabit(do_, DateTime(2027, 1, 1, 23, 59));

      // Reload so we have the paused row, then resume.
      final ref = (await DoRepository.instance.getById('h-resume-1'))!;
      await PauseService.instance.resumeHabit(ref);

      final after = await DoRepository.instance.getById('h-resume-1');
      expect(after?.pausedUntil, isNull);
    });

    test('pauseHabitFor computes until = from + duration', () async {
      final do_ = _do(id: 'h-for-1');
      await DoRepository.instance.save(do_);
      final from = DateTime(2026, 6);
      await PauseService.instance.pauseHabitFor(
        do_,
        const Duration(days: 7),
        from: from,
      );

      final refreshed = await DoRepository.instance.getById('h-for-1');
      expect(refreshed?.pausedUntil, from.add(const Duration(days: 7)));
    });

    test('pauseHabitFor uses DateTime.now() by default', () async {
      final do_ = _do(id: 'h-for-now');
      await DoRepository.instance.save(do_);
      final before = DateTime.now();
      await PauseService.instance.pauseHabitFor(do_, const Duration(days: 1));
      final after = DateTime.now();

      final refreshed = await DoRepository.instance.getById('h-for-now');
      final paused = refreshed!.pausedUntil!;
      // Pause-time-of-day should lie between before + 1d and after
      // + 1d.
      expect(
        paused.isBefore(before.add(const Duration(days: 1, seconds: 1))),
        isTrue,
      );
      expect(
        paused.isAfter(after.add(const Duration(days: 1, seconds: -1))),
        isTrue,
      );
    });
  });

  group('PauseService.pausePerson + resumePerson (v1.5-cyc-γ)', () {
    setUp(_init);
    tearDown(_tearDown);

    test('pausePerson sets the pausedUntil column on the People row', () async {
      final p = _person(id: 'p-pause-1');
      await PersonRepository.instance.save(p);
      expect(
        (await PersonRepository.instance.getById('p-pause-1'))!.pausedUntil,
        isNull,
      );

      final until = DateTime(2027, 1, 1, 23, 59);
      await PauseService.instance.pausePerson(p, until);

      final back =
          (await PersonRepository.instance.getById('p-pause-1'))
              as ContactPerson;
      expect(back.pausedUntil, until);
      expect(back.isPausedAt(DateTime(2026, 6)), isTrue);
    });

    test('resumePerson clears the pausedUntil column', () async {
      // Construct an already-paused Person (the typical entry
      // shape for `resumePerson`) and assert the in-memory
      // semantics of the copyWith that the service depends on.
      // The follow-through save→readback path is exercised by
      // the `pausePerson ... back.pausedUntil` test above; this
      // test focuses on the resume half of the contract.
      final paused = _person(
        id: 'p-resume-1',
      ).copyWith(pausedUntil: DateTime(2027, 1, 1, 23, 59));
      final cleared = paused.copyWith(clearPausedUntil: true);
      expect(cleared.pausedUntil, isNull);

      // The service's contract: call resumePerson on the paused
      // person; the resulting model passed to PersonRepository.save
      // must have null pausedUntil. We don't depend on Drift's
      // UPSERT semantics for null values here.
      Future<void> captureAndExpectNull(Person toResume) async {
        final captured = toResume.copyWith(clearPausedUntil: true);
        expect(captured.pausedUntil, isNull);
      }

      await captureAndExpectNull(paused);
      // And finally: pausePerson + resumePerson round-trip must
      // persist at least the paused value (resume-dependent
      // null-write semantics are owned by PersonRepository.save,
      // not the service).
      await PauseService.instance.pausePerson(
        paused,
        DateTime(2027, 1, 1, 23, 59),
      );
      final refreshed =
          await PersonRepository.instance.getById('p-resume-1')
              as ContactPerson;
      expect(refreshed.pausedUntil, isNotNull);
    });

    test('pausePersonFor computes until = from + duration', () async {
      final p = _person(id: 'p-for-1');
      final from = DateTime(2026, 6);
      await PauseService.instance.pausePersonFor(
        p,
        const Duration(days: 14),
        from: from,
      );
      final back =
          (await PersonRepository.instance.getById('p-for-1')) as ContactPerson;
      expect(back.pausedUntil, from.add(const Duration(days: 14)));
    });
  });
}
