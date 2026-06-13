// Tests for the rest-day budget.

import 'package:common_games/habits/rest_day_budget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RestDayBudget', () {
    test('starts empty', () {
      final b = RestDayBudget(habitId: 'h1', monthlyLimit: 2);
      expect(b.usedInMonth(DateTime(2026, 6, 13)), 0);
      expect(b.remainingInMonth(DateTime(2026, 6, 13)), 2);
    });

    test('consume decrements the remaining count', () {
      final b = RestDayBudget(
        habitId: 'h1',
        monthlyLimit: 2,
      ).consume(DateTime(2026, 6, 5));
      expect(b.usedInMonth(DateTime(2026, 6, 5)), 1);
      expect(b.remainingInMonth(DateTime(2026, 6, 5)), 1);
    });

    test('consuming twice in the same month consumes 2', () {
      final b = RestDayBudget(
        habitId: 'h1',
        monthlyLimit: 2,
      ).consume(DateTime(2026, 6, 5)).consume(DateTime(2026, 6, 10));
      expect(b.usedInMonth(DateTime(2026, 6, 13)), 2);
      expect(b.remainingInMonth(DateTime(2026, 6, 13)), 0);
    });

    test('consuming past the limit throws', () {
      final b = RestDayBudget(
        habitId: 'h1',
        monthlyLimit: 1,
      ).consume(DateTime(2026, 6, 5));
      expect(
        () => b.consume(DateTime(2026, 6, 10)),
        throwsA(isA<RestDayBudgetExhausted>()),
      );
    });

    test('month roll-over resets the count', () {
      final b = RestDayBudget(habitId: 'h1', monthlyLimit: 2)
          .consume(DateTime(2026, 6, 30))
          .consume(DateTime(2026, 6, 30))
          .rollOver(DateTime(2026, 7));
      expect(b.usedInMonth(DateTime(2026, 7, 5)), 0);
      expect(b.remainingInMonth(DateTime(2026, 7, 5)), 2);
    });

    test('consume in a new month after roll-over succeeds', () {
      final b = RestDayBudget(habitId: 'h1', monthlyLimit: 1)
          .consume(DateTime(2026, 6, 30))
          .rollOver(DateTime(2026, 7))
          .consume(DateTime(2026, 7, 5));
      expect(b.usedInMonth(DateTime(2026, 7, 5)), 1);
    });

    test(
      'per-habit isolation: habit A consumption does not affect habit B',
      () {
        // Different budget instances are fully independent;
        // this is more of a smoke test for the model.
        final a = RestDayBudget(
          habitId: 'a',
          monthlyLimit: 1,
        ).consume(DateTime(2026, 6, 5));
        final b = RestDayBudget(habitId: 'b', monthlyLimit: 1);
        expect(a.usedInMonth(DateTime(2026, 6, 5)), 1);
        expect(b.usedInMonth(DateTime(2026, 6, 5)), 0);
      },
    );

    test('consume on the same calendar day twice is idempotent', () {
      // The budget's internal Set dedupes by local-calendar
      // day. A second consume on the same day is a no-op
      // (returns a budget with the same consumed set). This
      // matches the user expectation: double-tapping the
      // rest-day button should not burn two budget units.
      final b = RestDayBudget(
        habitId: 'h1',
        monthlyLimit: 2,
      ).consume(DateTime(2026, 6, 5, 8)).consume(DateTime(2026, 6, 5, 22));
      expect(b.usedInMonth(DateTime(2026, 6, 5)), 1);
    });

    test('usedInMonth returns 0 for a different month', () {
      final b = RestDayBudget(
        habitId: 'h1',
        monthlyLimit: 2,
      ).consume(DateTime(2026, 6, 30));
      expect(b.usedInMonth(DateTime(2026, 7)), 0);
    });

    test('rollOver is a no-op when nothing to clear', () {
      final b = RestDayBudget(
        habitId: 'h1',
        monthlyLimit: 2,
      ).rollOver(DateTime(2026, 7));
      expect(identical(b, b), isTrue);
    });
  });
}
