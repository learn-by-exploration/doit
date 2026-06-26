// Unit tests for `home_tile_skip.dart` — the pure-Dart
// `markDoSkipped` helper that backs the in-app home tile's
// "Skip today" button (v1.4c / Phase 30 / SYS-117 /
// ADR-047 / WF-044).
//
// The helper's only job is to call
// `CompletionLogService.append` with the right arguments:
//   - `habitId` ← `do.id`
//   - `day` ← local-midnight at `asOf`
//   - `source` ← `CompletionSource.restDay`
//   - `proofModeAtTime` ← `'soft' | 'strong' | 'auto'`
//
// AND to reject the tap when the do has no rest-day
// budget remaining for the month. The rejection is
// surfaced as `NoRestDaysRemaining` so the UI can show a
// "no rest days left this month" snackbar instead of
// silently failing.
//
// Because the helper imports the singleton
// `CompletionLogService` (which holds a Drift DB), the
// tests use a hand-rolled fake that records the last
// `append` call AND stubs `listRestDaysInMonth` for the
// remaining-budget check. This avoids the need for
// mockito (not in pubspec dev_dependencies) AND avoids
// spinning up a real database for a pure helper.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/missions/chain.dart';
import 'package:doit/screens/home_tile_skip.dart';
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/db/schema.dart';
import 'package:flutter_test/flutter_test.dart';

class _AppendCall {
  const _AppendCall({
    required this.habitId,
    required this.day,
    required this.source,
    required this.proofModeAtTime,
  });
  final String habitId;
  final DateTime day;
  final CompletionSource source;
  final String proofModeAtTime;
}

class _FakeCompletionLog implements CompletionLogService {
  final List<_AppendCall> calls = <_AppendCall>[];
  // Pre-seeded rest-day rows for the "asOf" month. The
  // helper uses `listRestDaysInMonth` to derive the
  // remaining count.
  final List<CompletionRow> restDays;
  _FakeCompletionLog({this.restDays = const <CompletionRow>[]});

  @override
  Future<String> append({
    required String habitId,
    required DateTime day,
    required CompletionSource source,
    required String proofModeAtTime,
    String? note,
    String? missionResultsJson,
  }) async {
    calls.add(
      _AppendCall(
        habitId: habitId,
        day: day,
        source: source,
        proofModeAtTime: proofModeAtTime,
      ),
    );
    return 'fake-$habitId-${day.millisecondsSinceEpoch}';
  }

  @override
  Future<List<CompletionRow>> listRestDaysInMonth(
    String habitId, {
    required int year,
    required int month,
  }) async {
    return restDays.where((r) => r.habitId == habitId).toList(growable: false);
  }

  // The helper does not call these — the methods exist
  // only to satisfy the `implements CompletionLogService`
  // contract.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Do _do({
  String id = 'h1',
  DoProofMode mode = const SoftProof(),
  int restDaysPerMonth = 2,
}) {
  return DoFixed(
    id: id,
    name: 'Stretch',
    proofMode: mode,
    createdAt: DateTime(2026, 5, 17),
    restDaysPerMonth: restDaysPerMonth,
    weekdays: const {1, 2, 3, 4, 5, 6, 7},
    time: const DoTime(9, 0),
  );
}

void main() {
  group('markDoSkipped', () {
    test('calls append with source=restDay and the do\'s id', () async {
      final fake = _FakeCompletionLog();
      await markDoSkipped(
        activeDo: _do(),
        asOf: DateTime(2026, 6, 13, 14, 30),
        completionLog: fake,
      );
      expect(fake.calls, hasLength(1));
      expect(fake.calls.first.habitId, 'h1');
      expect(fake.calls.first.source, CompletionSource.restDay);
    });

    test('day argument is local-midnight at asOf', () async {
      final fake = _FakeCompletionLog();
      await markDoSkipped(
        activeDo: _do(),
        asOf: DateTime(2026, 6, 13, 14, 30),
        completionLog: fake,
      );
      expect(fake.calls.first.day, DateTime(2026, 6, 13));
      expect(fake.calls.first.day.hour, 0);
      expect(fake.calls.first.day.minute, 0);
    });

    test(
      'proofModeAtTime tag matches SoftProof / StrongProof / AutoProof',
      () async {
        final fakeSoft = _FakeCompletionLog();
        await markDoSkipped(
          activeDo: _do(),
          asOf: DateTime(2026, 6, 13),
          completionLog: fakeSoft,
        );
        expect(fakeSoft.calls.first.proofModeAtTime, 'soft');

        final fakeStrong = _FakeCompletionLog();
        await markDoSkipped(
          activeDo: _do(
            mode: StrongProof(
              MissionChain.from([
                const MathMission(
                  id: 'm1',
                  label: 'Solve',
                  timeout: Duration(seconds: 30),
                  difficulty: MathDifficulty.easy,
                ),
              ]),
            ),
          ),
          asOf: DateTime(2026, 6, 13),
          completionLog: fakeStrong,
        );
        expect(fakeStrong.calls.first.proofModeAtTime, 'strong');

        final fakeAuto = _FakeCompletionLog();
        await markDoSkipped(
          activeDo: _do(mode: const AutoProof()),
          asOf: DateTime(2026, 6, 13),
          completionLog: fakeAuto,
        );
        expect(fakeAuto.calls.first.proofModeAtTime, 'auto');
      },
    );

    test('throws NoRestDaysRemaining when restDaysPerMonth == 0', () async {
      final fake = _FakeCompletionLog();
      expect(
        () => markDoSkipped(
          activeDo: _do(restDaysPerMonth: 0),
          asOf: DateTime(2026, 6, 13),
          completionLog: fake,
        ),
        throwsA(isA<NoRestDaysRemaining>()),
      );
      expect(fake.calls, isEmpty);
    });

    test(
      'throws NoRestDaysRemaining when the month\'s budget is exhausted',
      () async {
        // 2 rest days per month, both already used in 6/2026.
        final used = <CompletionRow>[
          CompletionRow(
            id: 'r1',
            habitId: 'h1',
            dayMillis: DateTime(2026, 6, 5).millisecondsSinceEpoch,
            completedAtMillis: DateTime(2026, 6, 5).millisecondsSinceEpoch,
            source: 'rest_day',
            proofModeAtTime: 'soft',
          ),
          CompletionRow(
            id: 'r2',
            habitId: 'h1',
            dayMillis: DateTime(2026, 6, 20).millisecondsSinceEpoch,
            completedAtMillis: DateTime(2026, 6, 20).millisecondsSinceEpoch,
            source: 'rest_day',
            proofModeAtTime: 'soft',
          ),
        ];
        final fake = _FakeCompletionLog(restDays: used);
        expect(
          () => markDoSkipped(
            activeDo: _do(),
            asOf: DateTime(2026, 6, 25),
            completionLog: fake,
          ),
          throwsA(isA<NoRestDaysRemaining>()),
        );
        expect(fake.calls, isEmpty);
      },
    );

    test(
      'allows the last budget unit to be consumed (used == limit - 1)',
      () async {
        // 2 per month, 1 used → remaining is 1 → second tap OK.
        final used = <CompletionRow>[
          CompletionRow(
            id: 'r1',
            habitId: 'h1',
            dayMillis: DateTime(2026, 6, 5).millisecondsSinceEpoch,
            completedAtMillis: DateTime(2026, 6, 5).millisecondsSinceEpoch,
            source: 'rest_day',
            proofModeAtTime: 'soft',
          ),
        ];
        final fake = _FakeCompletionLog(restDays: used);
        await markDoSkipped(
          activeDo: _do(),
          asOf: DateTime(2026, 6, 25),
          completionLog: fake,
        );
        expect(fake.calls, hasLength(1));
      },
    );

    test('NoRestDaysRemaining carries doId + month for the snackbar', () async {
      final fake = _FakeCompletionLog();
      try {
        await markDoSkipped(
          activeDo: _do(id: 'h42', restDaysPerMonth: 0),
          asOf: DateTime(2026, 6, 13),
          completionLog: fake,
        );
        fail('expected throw');
      } on NoRestDaysRemaining catch (e) {
        expect(e.doId, 'h42');
        expect(e.year, 2026);
        expect(e.month, 6);
      }
    });

    test('helper makes exactly one append call per invocation', () async {
      final fake = _FakeCompletionLog();
      await markDoSkipped(
        activeDo: _do(),
        asOf: DateTime(2026, 6, 13),
        completionLog: fake,
      );
      expect(fake.calls, hasLength(1));
    });
  });
}
