// Unit tests for `home_tile_undo.dart` — the pure-Dart
// `undoToday` helper that backs the in-app home tile's
// "Undo today" button (v1.4d / Phase 31 / SYS-118 /
// ADR-048 / WF-045).
//
// The helper's only job is to find today's completion (or
// rest-day) row via `CompletionLogService.listForHabit` and
// delete it via `CompletionLogService.deleteById`.
//
//   - On hit: returns `UndoResult.removed(rowId, source)`
//     and calls `deleteById(row.id)` exactly once.
//   - On no row: returns `UndoResult.nothingToUndo()` and
//     does NOT call `deleteById`.
//
// Because the helper imports the singleton
// `CompletionLogService` (which holds a Drift DB), the
// tests use a hand-rolled fake that records the last
// `deleteById` call AND seeds `listForHabit` for the
// matching test case. This avoids the need for mockito
// (not in pubspec dev_dependencies) AND avoids spinning
// up a real database for a pure helper.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/screens/home_tile_undo.dart';
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/db/schema.dart';
import 'package:flutter_test/flutter_test.dart';

class _DeleteCall {
  const _DeleteCall(this.id);
  final String id;
}

class _FakeCompletionLog implements CompletionLogService {
  // Pre-seeded completions for the helper's
  // `listForHabit` call. The helper uses this to find
  // today's row.
  final List<CompletionRow> seeded;
  final List<_DeleteCall> deletes = <_DeleteCall>[];
  _FakeCompletionLog({this.seeded = const <CompletionRow>[]});

  @override
  Future<List<CompletionRow>> listForHabit(String habitId) async {
    return seeded.where((r) => r.habitId == habitId).toList(growable: false);
  }

  @override
  Future<void> deleteById(String id) async {
    deletes.add(_DeleteCall(id));
  }

  // The helper does not call these — the methods exist
  // only to satisfy the `implements CompletionLogService`
  // contract.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Do _do({String id = 'h1'}) {
  return DoFixed(
    id: id,
    name: 'Stretch',
    proofMode: const SoftProof(),
    createdAt: DateTime(2026, 5, 17),
    restDaysPerMonth: 2,
    weekdays: const {1, 2, 3, 4, 5, 6, 7},
    time: const DoTime(9, 0),
  );
}

CompletionRow _row({
  required String id,
  required String habitId,
  required DateTime day,
  String source = 'manual',
  String proofModeAtTime = 'soft',
}) {
  return CompletionRow(
    id: id,
    habitId: habitId,
    dayMillis: DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
    completedAtMillis: day.millisecondsSinceEpoch,
    source: source,
    proofModeAtTime: proofModeAtTime,
  );
}

void main() {
  group('undoToday', () {
    test('returns UndoResult.removed(rowId, source) when a manual completion '
        'row exists for asOf\'s local-midnight', () async {
      final today = DateTime(2026, 6, 13, 14, 30);
      final row = _row(id: 'c1', habitId: 'h1', day: today);
      final fake = _FakeCompletionLog(seeded: [row]);
      final result = await undoToday(
        activeDo: _do(),
        asOf: today,
        completionLog: fake,
      );
      expect(result, isA<UndoResultRemoved>());
      expect((result as UndoResultRemoved).rowId, 'c1');
      expect(result.source, 'manual');
    });

    test('returns UndoResult.removed(rowId, source) when a rest-day row '
        'exists for asOf\'s local-midnight', () async {
      final today = DateTime(2026, 6, 13, 14, 30);
      final row = _row(id: 'c2', habitId: 'h1', day: today, source: 'rest_day');
      final fake = _FakeCompletionLog(seeded: [row]);
      final result = await undoToday(
        activeDo: _do(),
        asOf: today,
        completionLog: fake,
      );
      expect(result, isA<UndoResultRemoved>());
      expect((result as UndoResultRemoved).rowId, 'c2');
      expect(result.source, 'rest_day');
    });

    test('returns UndoResult.nothingToUndo() when no row exists for '
        'asOf\'s local-midnight', () async {
      final fake = _FakeCompletionLog();
      final result = await undoToday(
        activeDo: _do(),
        asOf: DateTime(2026, 6, 13, 14, 30),
        completionLog: fake,
      );
      expect(result, isA<UndoResultNothingToUndo>());
    });

    test('matches the row whose day equals DateTime(asOf.year, asOf.month, '
        'asOf.day) regardless of source', () async {
      final today = DateTime(2026, 6, 13, 14, 30);
      // Two rows for the same day but different sources;
      // the helper picks the FIRST matching row in
      // listForHabit order (oldest-first). The test
      // pins "exactly one delete call" to assert the
      // helper does not loop through both rows.
      final manual = _row(id: 'manual-id', habitId: 'h1', day: today);
      final restDay = _row(
        id: 'rest-id',
        habitId: 'h1',
        day: today.add(const Duration(hours: 2)),
        source: 'rest_day',
      );
      final fake = _FakeCompletionLog(seeded: [manual, restDay]);
      final result = await undoToday(
        activeDo: _do(),
        asOf: today,
        completionLog: fake,
      );
      expect(result, isA<UndoResultRemoved>());
      expect(fake.deletes, hasLength(1));
      // First matching row is `manual` (since its
      // dayMillis is earlier or equal — same day but
      // earlier clock-time stored as completedAtMillis;
      // the day filter is by dayMillis).
    });

    test('matches a row in the past at the same day even when asOf is in '
        'the future (no future-leak)', () async {
      // The row was written yesterday at 23:59, the
      // user taps undo at 00:01 today. The row's
      // `dayMillis` is yesterday's midnight, so it
      // should NOT match today's midnight.
      final pastDay = DateTime(2026, 6, 12);
      final yesterdayRow = _row(id: 'yest', habitId: 'h1', day: pastDay);
      final fake = _FakeCompletionLog(seeded: [yesterdayRow]);
      final result = await undoToday(
        activeDo: _do(),
        asOf: DateTime(2026, 6, 13, 0, 1),
        completionLog: fake,
      );
      expect(result, isA<UndoResultNothingToUndo>());
      expect(fake.deletes, isEmpty);
    });

    test('calls completionLog.deleteById exactly once per invocation on '
        'the happy path', () async {
      final today = DateTime(2026, 6, 13, 14, 30);
      final row = _row(id: 'c1', habitId: 'h1', day: today);
      final fake = _FakeCompletionLog(seeded: [row]);
      await undoToday(activeDo: _do(), asOf: today, completionLog: fake);
      expect(fake.deletes, hasLength(1));
      expect(fake.deletes.first.id, 'c1');
    });

    test('does NOT call completionLog.deleteById on the nothingToUndo '
        'path', () async {
      final fake = _FakeCompletionLog();
      await undoToday(
        activeDo: _do(),
        asOf: DateTime(2026, 6, 13, 14, 30),
        completionLog: fake,
      );
      expect(fake.deletes, isEmpty);
    });

    test('UndoResult value-equality holds for removed + nothingToUndo', () {
      const a = UndoResultNothingToUndo();
      const b = UndoResultNothingToUndo();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);

      const r1 = UndoResultRemoved(rowId: 'x', source: 'manual');
      const r2 = UndoResultRemoved(rowId: 'x', source: 'manual');
      expect(r1, equals(r2));
      expect(r1.hashCode, r2.hashCode);

      // Different id → not equal.
      const r3 = UndoResultRemoved(rowId: 'y', source: 'manual');
      expect(r1 == r3, isFalse);

      // Different source → not equal.
      const r4 = UndoResultRemoved(rowId: 'x', source: 'rest_day');
      expect(r1 == r4, isFalse);

      // Different variants → not equal.
      expect(a == r1, isFalse);
    });
  });
}
