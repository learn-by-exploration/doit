// Unit tests for `home_tile_budget.dart` — the pure-Dart
// budget-remaining helper that drives the in-app home
// tile's "X / Y rest days left this month" caption
// (v1.4c / Phase 30 / SYS-117 / ADR-047 / WF-044).
//
// The helper has two responsibilities:
//   1. `BudgetRemaining` value class — the immutable
//      (used, limit, remaining) triple with derived
//      `canSkip` / `isExhausted` flags.
//   2. `budgetRemainingForDo(...)` — async fetch of the
//      triple for a do + frozen `asOf`.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/screens/home_tile_budget.dart';
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/db/schema.dart';
import 'package:flutter_test/flutter_test.dart';

Do _do({String id = 'h1', int restDaysPerMonth = 2}) {
  return DoFixed(
    id: id,
    name: 'Stretch',
    proofMode: const SoftProof(),
    createdAt: DateTime(2026, 5, 17),
    restDaysPerMonth: restDaysPerMonth,
    weekdays: const {1, 2, 3, 4, 5, 6, 7},
    time: const DoTime(9, 0),
  );
}

class _FakeCompletionLog implements CompletionLogService {
  _FakeCompletionLog({this.restDays = const <CompletionRow>[]});
  final List<CompletionRow> restDays;

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

CompletionRow _restDayRow(String habitId, int year, int month, int day) {
  return CompletionRow(
    id: 'r-$habitId-$year$month$day',
    habitId: habitId,
    dayMillis: DateTime(year, month, day).millisecondsSinceEpoch,
    completedAtMillis: DateTime(year, month, day).millisecondsSinceEpoch,
    source: 'rest_day',
    proofModeAtTime: 'soft',
  );
}

void main() {
  group('BudgetRemaining', () {
    test('used 0 of 2 → remaining 2, canSkip true, not exhausted', () {
      const b = BudgetRemaining(used: 0, limit: 2, remaining: 2);
      expect(b.canSkip, isTrue);
      expect(b.isExhausted, isFalse);
    });

    test('used 1 of 2 → remaining 1, canSkip true, not exhausted', () {
      const b = BudgetRemaining(used: 1, limit: 2, remaining: 1);
      expect(b.canSkip, isTrue);
      expect(b.isExhausted, isFalse);
    });

    test('used 2 of 2 → remaining 0, canSkip false, exhausted', () {
      const b = BudgetRemaining(used: 2, limit: 2, remaining: 0);
      expect(b.canSkip, isFalse);
      expect(b.isExhausted, isTrue);
    });

    test('limit 0 → remaining 0, canSkip false, not exhausted', () {
      // The `isExhausted` getter requires `limit > 0`.
      // A do that opted out of rest days is NOT
      // "exhausted" — it never had any to consume.
      const b = BudgetRemaining(used: 0, limit: 0, remaining: 0);
      expect(b.canSkip, isFalse);
      expect(b.isExhausted, isFalse);
    });

    test('value-equality holds for equal triples', () {
      const a = BudgetRemaining(used: 1, limit: 2, remaining: 1);
      const b = BudgetRemaining(used: 1, limit: 2, remaining: 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('budgetRemainingForDo', () {
    test('do with limit 0 returns the empty-budget snapshot', () async {
      final fake = _FakeCompletionLog();
      final b = await budgetRemainingForDo(
        activeDo: _do(restDaysPerMonth: 0),
        asOf: DateTime(2026, 6, 13),
        completionLog: fake,
      );
      expect(b.used, 0);
      expect(b.limit, 0);
      expect(b.remaining, 0);
      expect(b.canSkip, isFalse);
    });

    test('do with no rest-day rows → used 0', () async {
      final fake = _FakeCompletionLog();
      final b = await budgetRemainingForDo(
        activeDo: _do(),
        asOf: DateTime(2026, 6, 13),
        completionLog: fake,
      );
      expect(b.used, 0);
      expect(b.limit, 2);
      expect(b.remaining, 2);
    });

    test('do with 1 of 2 used → remaining 1', () async {
      final fake = _FakeCompletionLog(
        restDays: [_restDayRow('h1', 2026, 6, 5)],
      );
      final b = await budgetRemainingForDo(
        activeDo: _do(),
        asOf: DateTime(2026, 6, 13),
        completionLog: fake,
      );
      expect(b.used, 1);
      expect(b.remaining, 1);
    });

    test('do with 2 of 2 used → remaining 0, exhausted', () async {
      final fake = _FakeCompletionLog(
        restDays: [
          _restDayRow('h1', 2026, 6, 5),
          _restDayRow('h1', 2026, 6, 20),
        ],
      );
      final b = await budgetRemainingForDo(
        activeDo: _do(),
        asOf: DateTime(2026, 6, 25),
        completionLog: fake,
      );
      expect(b.used, 2);
      expect(b.remaining, 0);
      expect(b.isExhausted, isTrue);
    });

    test('only counts rows for the do passed in', () async {
      final fake = _FakeCompletionLog(
        restDays: [
          _restDayRow('h1', 2026, 6, 5),
          _restDayRow('h2', 2026, 6, 5),
          _restDayRow('h2', 2026, 6, 6),
        ],
      );
      final b = await budgetRemainingForDo(
        activeDo: _do(restDaysPerMonth: 3),
        asOf: DateTime(2026, 6, 13),
        completionLog: fake,
      );
      expect(b.used, 1);
      expect(b.remaining, 2);
    });

    test('clamps negative remaining to 0 (defensive)', () async {
      // If the user lowers `restDaysPerMonth` mid-month
      // and their existing usage exceeds the new cap,
      // the clamp keeps the snapshot valid (negative
      // remaining would be a UI bug — the tile would
      // show "-1 / 1 rest days left").
      final fake = _FakeCompletionLog(
        restDays: [
          _restDayRow('h1', 2026, 6, 5),
          _restDayRow('h1', 2026, 6, 6),
          _restDayRow('h1', 2026, 6, 7),
        ],
      );
      final b = await budgetRemainingForDo(
        activeDo: _do(),
        asOf: DateTime(2026, 6, 25),
        completionLog: fake,
      );
      expect(b.used, 3);
      expect(b.remaining, 0);
    });
  });
}
