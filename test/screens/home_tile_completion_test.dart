// Unit tests for `home_tile_completion.dart` — the pure-Dart
// `markDoDone` helper that backs the in-app home tile's
// "Done" button (v1.4b / Phase 29 / SYS-116 / ADR-046 /
// WF-043).
//
// The helper's only job is to call
// `CompletionLogService.append` with the right arguments:
//   - `habitId` ← `do.id`
//   - `day` ← local-midnight at `asOf`
//   - `source` ← `CompletionSource.manual`
//   - `proofModeAtTime` ← `'soft' | 'strong' | 'auto'`
//
// Because the helper imports the singleton
// `CompletionLogService` (which holds a Drift DB), the
// tests use a hand-rolled fake that records the last
// `append` call. This avoids the need for mockito
// (not in pubspec dev_dependencies) AND avoids
// spinning up a real database for a pure helper.
//
// Future consolidation (post v1.4a merge): the
// `_proofModeTag` inline copy here is byte-identical to
// the one in `lib/services/widget_service.dart`; a future
// PR will extract both into `lib/do/proof_mode_tag.dart`.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/missions/chain.dart';
import 'package:doit/screens/home_tile_completion.dart';
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
  // Optional: if non-null, the fake returns this instead
  // of throwing on listForHabit (the helper does not call
  // listForHabit, but the type implements the surface).
  final Map<String, List<CompletionRow>> _byHabit =
      <String, List<CompletionRow>>{};

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
  Future<List<CompletionRow>> listForHabit(String habitId) async {
    return _byHabit[habitId] ?? const <CompletionRow>[];
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
  group('markDoDone', () {
    test('calls append with source=manual and the do\'s id', () async {
      final fake = _FakeCompletionLog();
      await markDoDone(
        activeDo: _do(),
        asOf: DateTime(2026, 6, 13, 14, 30),
        completionLog: fake,
      );
      expect(fake.calls, hasLength(1));
      expect(fake.calls.first.habitId, 'h1');
      expect(fake.calls.first.source, CompletionSource.manual);
    });

    test('day argument is local-midnight at asOf', () async {
      final fake = _FakeCompletionLog();
      // asOf is 14:30 on 6/13 — the helper should floor to
      // 00:00 on 6/13 (the dedupe key in
      // CompletionLogService.append).
      await markDoDone(
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
        await markDoDone(
          activeDo: _do(),
          asOf: DateTime(2026, 6, 13),
          completionLog: fakeSoft,
        );
        expect(fakeSoft.calls.first.proofModeAtTime, 'soft');

        final fakeStrong = _FakeCompletionLog();
        await markDoDone(
          activeDo: _do(mode: StrongProof(MissionChain.empty)),
          asOf: DateTime(2026, 6, 13),
          completionLog: fakeStrong,
        );
        expect(fakeStrong.calls.first.proofModeAtTime, 'strong');

        final fakeAuto = _FakeCompletionLog();
        await markDoDone(
          activeDo: _do(mode: const AutoProof()),
          asOf: DateTime(2026, 6, 13),
          completionLog: fakeAuto,
        );
        expect(fakeAuto.calls.first.proofModeAtTime, 'auto');
      },
    );

    test('helper makes exactly one append call per invocation', () async {
      // Defensive — a regression that loops inside the
      // helper would multiply completions. The
      // CompletionLogService append already dedupes on
      // (habitId, day), so the only contract here is "one
      // append call per tap".
      final fake = _FakeCompletionLog();
      await markDoDone(
        activeDo: _do(),
        asOf: DateTime(2026, 6, 13),
        completionLog: fake,
      );
      expect(fake.calls, hasLength(1));
      // A second tap on the same day hits the dedupe path
      // upstream — but the helper itself still fires one
      // append (the dedupe happens inside append).
      await markDoDone(
        activeDo: _do(),
        asOf: DateTime(2026, 6, 13, 16),
        completionLog: fake,
      );
      expect(fake.calls, hasLength(2));
    });
  });
}
