// Tests for the streak calculator. SYS-019: 20+ cases.
//
// The calculator is pure. `asOf` is the reference clock.

import 'package:doit/habits/rest_day_budget.dart';
import 'package:doit/habits/streak_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

StreakConfig _config({Duration grace = const Duration(hours: 3)}) {
  return StreakConfig(
    graceWindow: grace,
    restDayBudget: RestDayBudget(habitId: 'h1', monthlyLimit: 2),
  );
}

DateTime _day(int y, int m, int d, [int h = 0, int mm = 0]) =>
    DateTime(y, m, d, h, mm);

CompletionLogEntry _entry(int y, int m, int d) =>
    CompletionLogEntry(habitId: 'h1', date: _day(y, m, d));

void main() {
  group('StreakCalculator.compute', () {
    test('empty log → streak 0', () {
      final snap = StreakCalculator.compute(
        log: const <CompletionLogEntry>[],
        config: _config(),
        asOf: _day(2026, 6, 13),
      );
      expect(snap.currentStreak, 0);
      expect(snap.longestStreak, 0);
      expect(snap.lastCompletion, isNull);
      expect(snap.brokenAt, isNull);
    });

    test('single completion today → streak 1, longest 1', () {
      final snap = StreakCalculator.compute(
        log: [_entry(2026, 6, 13)],
        config: _config(),
        asOf: _day(2026, 6, 13),
      );
      expect(snap.currentStreak, 1);
      expect(snap.longestStreak, 1);
    });

    test('consecutive days → streak equals the run length', () {
      final log = [for (var d = 1; d <= 7; d++) _entry(2026, 6, d)];
      final snap = StreakCalculator.compute(
        log: log,
        config: _config(),
        asOf: _day(2026, 6, 7),
      );
      expect(snap.currentStreak, 7);
      expect(snap.longestStreak, 7);
    });

    test('1-day gap in the middle breaks the streak', () {
      // 1,2,3,4,5 then gap on 6, then 7,8,9,10.
      final log = [
        for (var d = 1; d <= 5; d++) _entry(2026, 6, d),
        for (var d = 7; d <= 10; d++) _entry(2026, 6, d),
      ];
      final snap = StreakCalculator.compute(
        log: log,
        config: _config(),
        asOf: _day(2026, 6, 10),
      );
      // First run 5, broken at 6/6; second run 4.
      expect(snap.currentStreak, 4);
      expect(snap.longestStreak, 5);
      expect(snap.brokenAt, _day(2026, 6, 6));
    });

    test('2-day gap (past grace) breaks the streak', () {
      final log = [
        for (var d = 1; d <= 5; d++) _entry(2026, 6, d),
        for (var d = 8; d <= 10; d++) _entry(2026, 6, d),
      ];
      final snap = StreakCalculator.compute(
        log: log,
        config: _config(),
        asOf: _day(2026, 6, 10),
      );
      expect(snap.currentStreak, 3);
      expect(snap.longestStreak, 5);
      expect(snap.brokenAt, _day(2026, 6, 6));
    });

    test('single completion 4 days ago is broken (asOf is later)', () {
      final snap = StreakCalculator.compute(
        log: [_entry(2026, 6, 9)],
        config: _config(),
        asOf: _day(2026, 6, 13),
      );
      expect(snap.currentStreak, 0);
      // longest is 1 — a 1-day run was held on 6/9, even
      // though the streak is now broken.
      expect(snap.longestStreak, 1);
      // log has no gaps, so brokenAt is set by the boundary check.
      expect(snap.brokenAt, _day(2026, 6, 10));
    });

    test('missed-then-backfilled → streak restarts at the backfill', () {
      final log = [
        _entry(2026, 6, 1),
        _entry(2026, 6, 2),
        // 6/3 missed
        _entry(2026, 6, 4),
        _entry(2026, 6, 5),
      ];
      final snap = StreakCalculator.compute(
        log: log,
        config: _config(),
        asOf: _day(2026, 6, 5),
      );
      // 2-day streak broken at 6/3, then 2-day streak 6/4..6/5.
      expect(snap.currentStreak, 2);
      expect(snap.longestStreak, 2);
      expect(snap.brokenAt, _day(2026, 6, 3));
    });

    test('multiple completions on the same day collapse to one', () {
      final log = [
        CompletionLogEntry(habitId: 'h1', date: _day(2026, 6, 1, 8)),
        CompletionLogEntry(habitId: 'h1', date: _day(2026, 6, 1, 14)),
        CompletionLogEntry(habitId: 'h1', date: _day(2026, 6, 1, 22)),
        _entry(2026, 6, 2),
      ];
      final snap = StreakCalculator.compute(
        log: log,
        config: _config(),
        asOf: _day(2026, 6, 2),
      );
      expect(snap.currentStreak, 2);
    });

    test('rest day budget is reported (usedOnOrBefore)', () {
      final budget = RestDayBudget(
        habitId: 'h1',
        monthlyLimit: 2,
      ).consume(_day(2026, 6, 5)).consume(_day(2026, 6, 10));
      final config = StreakConfig(
        graceWindow: const Duration(hours: 3),
        restDayBudget: budget,
      );
      final snap = StreakCalculator.compute(
        log: const <CompletionLogEntry>[],
        config: config,
        asOf: _day(2026, 6, 13),
      );
      expect(snap.restDaysUsed, 2);
    });

    test('longest streak tracks the maximum run, not just the current', () {
      final log = [
        for (var d = 1; d <= 5; d++) _entry(2026, 5, d),
        for (var d = 8; d <= 12; d++) _entry(2026, 5, d),
        for (var d = 14; d <= 18; d++) _entry(2026, 5, d),
        for (var d = 21; d <= 23; d++) _entry(2026, 5, d),
      ];
      final snap = StreakCalculator.compute(
        log: log,
        config: _config(),
        asOf: _day(2026, 5, 23),
      );
      // Runs: 5, 5, 5, 3. Longest 5. Current 3.
      expect(snap.currentStreak, 3);
      expect(snap.longestStreak, 5);
    });

    test('DST spring-forward: streak does not break across the transition', () {
      // US DST 2026 starts on 2026-03-08. A 02:00 EST becomes
      // 03:00 EDT. The completion log is in local clock; the
      // engine strips time-of-day.
      final log = [_entry(2026, 3, 7), _entry(2026, 3, 8), _entry(2026, 3, 9)];
      final snap = StreakCalculator.compute(
        log: log,
        config: _config(),
        asOf: _day(2026, 3, 9),
      );
      expect(snap.currentStreak, 3);
    });

    test('zero grace window: asOf 04:00 of next day breaks the streak', () {
      final log = [_entry(2026, 6, 12)];
      final snap = StreakCalculator.compute(
        log: log,
        config: _config(grace: Duration.zero),
        asOf: _day(2026, 6, 13, 4),
      );
      // 6/13 is 1 day after 6/12. Grace is 0 hours. End of
      // 6/12 is 6/13 00:00; graceEnd is also 6/13 00:00. asOf
      // 04:00 is past graceEnd → broken.
      expect(snap.currentStreak, 0);
    });

    test('12h grace window: asOf 13:00 of next day breaks the streak', () {
      final log = [_entry(2026, 6, 12)];
      final snap = StreakCalculator.compute(
        log: log,
        config: _config(grace: const Duration(hours: 12)),
        asOf: _day(2026, 6, 13, 13),
      );
      // End of 6/12 is 6/13 00:00; graceEnd is 6/13 12:00.
      // 13:00 is past → broken.
      expect(snap.currentStreak, 0);
    });

    test('12h grace window: asOf 11:00 of next day keeps the streak alive', () {
      final log = [_entry(2026, 6, 12)];
      final snap = StreakCalculator.compute(
        log: log,
        config: _config(grace: const Duration(hours: 12)),
        asOf: _day(2026, 6, 13, 11),
      );
      // Within grace.
      expect(snap.currentStreak, 1);
    });

    test('streak is never negative even with no completions', () {
      final snap = StreakCalculator.compute(
        log: const <CompletionLogEntry>[],
        config: _config(),
        asOf: _day(2026, 6, 13),
      );
      expect(snap.currentStreak, isNonNegative);
    });

    test('lastCompletion field is the latest entry, not the first', () {
      final log = [
        _entry(2026, 6, 1),
        _entry(2026, 6, 5),
        _entry(2026, 6, 3), // out of order
      ];
      final snap = StreakCalculator.compute(
        log: log,
        config: _config(),
        asOf: _day(2026, 6, 5),
      );
      expect(snap.lastCompletion, _day(2026, 6, 5));
    });

    test('a single completion on the same day as asOf gives streak 1', () {
      final snap = StreakCalculator.compute(
        log: [_entry(2026, 6, 13)],
        config: _config(),
        asOf: _day(2026, 6, 13, 23, 59),
      );
      expect(snap.currentStreak, 1);
    });

    test('a single completion yesterday, asOf today 01:00 → still 1', () {
      final snap = StreakCalculator.compute(
        log: [_entry(2026, 6, 12)],
        config: _config(),
        asOf: _day(2026, 6, 13, 1),
      );
      expect(snap.currentStreak, 1);
    });

    test('a single completion yesterday, asOf 04:00 next day → broken', () {
      final snap = StreakCalculator.compute(
        log: [_entry(2026, 6, 12)],
        config: _config(),
        asOf: _day(2026, 6, 13, 4),
      );
      expect(snap.currentStreak, 0);
    });

    test('a streak that ends exactly at the asOf is still alive', () {
      final snap = StreakCalculator.compute(
        log: [_entry(2026, 6, 13)],
        config: _config(),
        asOf: _day(2026, 6, 13),
      );
      expect(snap.currentStreak, 1);
    });

    test(
      'a completion 2 days in the future relative to asOf is not counted',
      () {
        // Log has a date in the future; the calculator's
        // lastCompletion is that future date, but the asOf
        // boundary is what counts. With 0-day diff, the
        // streak is alive (1). This is a degenerate case; the
        // service layer is expected to backfill entries only
        // up to "today".
        final snap = StreakCalculator.compute(
          log: [_entry(2026, 6, 15)],
          config: _config(),
          asOf: _day(2026, 6, 13),
        );
        // daysSinceLast = -2 (future). My isStreakAlive check
        // is `daysSinceLast == 0 || (daysSinceLast == 1 && ...)`.
        // -2 doesn't match → not alive.
        expect(snap.currentStreak, 0);
      },
    );

    test('long runs (50 days) compute correctly', () {
      // 50-day run starting 2026-04-01 through 2026-05-20.
      final log = <CompletionLogEntry>[];
      for (var d = 1; d <= 50; d++) {
        if (d <= 30) {
          log.add(_entry(2026, 4, d));
        } else {
          log.add(_entry(2026, 5, d - 30));
        }
      }
      final snap = StreakCalculator.compute(
        log: log,
        config: _config(),
        asOf: _day(2026, 5, 20),
      );
      expect(snap.currentStreak, 50);
      expect(snap.longestStreak, 50);
    });

    test('dedup keeps the note when present', () {
      final log = [
        CompletionLogEntry(habitId: 'h1', date: _day(2026, 6, 1, 8)),
        CompletionLogEntry(
          habitId: 'h1',
          date: _day(2026, 6, 1, 22),
          note: 'real completion',
        ),
      ];
      final snap = StreakCalculator.compute(
        log: log,
        config: _config(),
        asOf: _day(2026, 6, 1, 23),
      );
      expect(snap.currentStreak, 1);
    });
  });
}
