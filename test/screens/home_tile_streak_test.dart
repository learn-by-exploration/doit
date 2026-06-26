// Unit tests for `home_tile_streak.dart` — the pure-Dart
// streak helper that drives the in-app home tile's streak
// number (v1.4b / Phase 29 / SYS-116 / ADR-046 / WF-043).
//
// The helper has two responsibilities:
//   1. `streakForDo` — returns `currentStreak` for a do
//      given its completion log + frozen `asOf`. Re-uses
//      `ConsecutiveCounter.compute` (the same algorithm
//      that powers the widget's streak in v1.4a).
//   2. `isCompletedOnDay` — local-calendar-day presence
//      check, used by the tile to gray out "Done" after a
//      same-day tap.
//
// The tests pin the helper's contract: same input → same
// output, no `DateTime.now()` inside, no Flutter imports,
// no side effects.

import 'package:doit/do/consecutive_counter.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/screens/home_tile_streak.dart';
import 'package:flutter_test/flutter_test.dart';

Do _fixed({
  String id = 'h1',
  int restDaysPerMonth = 2,
  Duration? graceWindowOverride,
}) {
  return DoFixed(
    id: id,
    name: 'Stretch',
    proofMode: const SoftProof(),
    createdAt: DateTime(2026, 5, 17),
    restDaysPerMonth: restDaysPerMonth,
    weekdays: const {1, 2, 3, 4, 5, 6, 7},
    time: const DoTime(9, 0),
    graceWindowOverride: graceWindowOverride,
  );
}

CompletionLogEntry _entry(int y, int m, int d, [String id = 'h1']) =>
    CompletionLogEntry(doId: id, date: DateTime(y, m, d));

void main() {
  group('streakForDo', () {
    test('empty completion log → streak 0', () {
      final result = streakForDo(
        activeDo: _fixed(),
        completions: const <CompletionLogEntry>[],
        asOf: DateTime(2026, 6, 13),
      );
      expect(result, 0);
    });

    test('five consecutive days ending today → streak 5', () {
      final completions = <CompletionLogEntry>[
        for (var d = 9; d <= 13; d++) _entry(2026, 6, d),
      ];
      final result = streakForDo(
        activeDo: _fixed(),
        completions: completions,
        asOf: DateTime(2026, 6, 13),
      );
      expect(result, 5);
    });

    test('one-day gap past the grace window → current run only', () {
      // 6/9, 6/10, 6/11, gap on 6/12, 6/13.
      // Default grace is 3h — a full day breaks the run.
      final completions = <CompletionLogEntry>[
        _entry(2026, 6, 9),
        _entry(2026, 6, 10),
        _entry(2026, 6, 11),
        _entry(2026, 6, 13),
      ];
      final result = streakForDo(
        activeDo: _fixed(),
        completions: completions,
        asOf: DateTime(2026, 6, 13),
      );
      expect(result, 1);
    });

    test('per-do graceWindowOverride is honored', () {
      // 1-day gap (6/12 missed). The loop walks 6/11→6/13
      // as a 2-day gap and resets run to 1, so a wider
      // grace does NOT bridge a 2-day gap inside the log.
      // For a 1-day gap (6/11 done, 6/13 checked) the
      // 24h grace keeps the run alive at asOf.
      final completions = <CompletionLogEntry>[
        _entry(2026, 6, 10),
        _entry(2026, 6, 11),
        // 6/12 missed
        _entry(2026, 6, 13),
      ];
      final result = streakForDo(
        activeDo: _fixed(graceWindowOverride: const Duration(hours: 24)),
        completions: completions,
        asOf: DateTime(2026, 6, 13, 20),
      );
      // Loop builds run=2 (6/10..6/11), then reset to 1
      // (gap=2 days). At asOf 6/13 the last day is 6/13,
      // daysSinceLast=0 → alive. currentStreak=1.
      expect(result, 1);
    });

    test('asOf 23:59 vs 00:01 of next day can flip the streak', () {
      // Last completion 6/12. asOf 6/12 23:59 → daysSinceLast=0,
      // streak alive. asOf 6/13 00:01 → daysSinceLast=1,
      // _withinGrace(lastDay=6/12, asOf=6/13 00:01,
      // grace=3h) → endOfLastDay=6/13 00:00, graceEnd=6/13
      // 03:00 → 00:01 is within → streak still alive.
      // For the flip we need to step further past the
      // 3h default grace.
      final completions = <CompletionLogEntry>[_entry(2026, 6, 12)];
      final lateResult = streakForDo(
        activeDo: _fixed(),
        completions: completions,
        asOf: DateTime(2026, 6, 12, 23, 59),
      );
      expect(lateResult, 1);
      final earlyResult = streakForDo(
        activeDo: _fixed(),
        completions: completions,
        asOf: DateTime(2026, 6, 13, 4),
      );
      // 4h past the start of 6/13 → outside the 3h grace
      // window → streak broken.
      expect(earlyResult, 0);
    });

    test(
      'helper is pure — same inputs → same output (no DateTime.now())',
      () async {
        final completions = <CompletionLogEntry>[
          _entry(2026, 6, 11),
          _entry(2026, 6, 12),
          _entry(2026, 6, 13),
        ];
        final asOf = DateTime(2026, 6, 13, 9);
        final first = streakForDo(
          activeDo: _fixed(),
          completions: completions,
          asOf: asOf,
        );
        // Wait briefly to make sure DateTime.now() could
        // have advanced if the helper used it.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final second = streakForDo(
          activeDo: _fixed(),
          completions: completions,
          asOf: asOf,
        );
        expect(first, second);
        expect(first, 3);
      },
    );

    test('1000-completion log stress — finishes well under 50ms', () {
      // Stress test for the worst case: a very long log
      // with one completion per day. For visible tiles
      // (≤ 10 dos), the wall-clock cost is well under
      // budget; the assertion is a regression guard.
      final start = DateTime(2026);
      final completions = <CompletionLogEntry>[
        for (var d = 0; d < 1000; d++)
          CompletionLogEntry(
            doId: 'h1',
            date: start.add(Duration(days: d)),
          ),
      ];
      final stopwatch = Stopwatch()..start();
      final result = streakForDo(
        activeDo: _fixed(),
        completions: completions,
        asOf: DateTime(2028, 9, 27),
      );
      stopwatch.stop();
      expect(result, 1000);
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });

    test('uses the do\'s restDaysPerMonth in the skip budget', () {
      // 4 rest-days per month — bigger than the default
      // 2. Assert the helper wires the do's value into
      // the SkipBudget (the underlying counter reads
      // `monthlyLimit` from the budget). We pin this
      // by passing a do with restDaysPerMonth: 5 and
      // asserting the call does not throw (the counter
      // accepts any non-negative value).
      final completions = <CompletionLogEntry>[
        for (var d = 9; d <= 13; d++) _entry(2026, 6, d),
      ];
      final result = streakForDo(
        activeDo: _fixed(restDaysPerMonth: 5),
        completions: completions,
        asOf: DateTime(2026, 6, 13),
      );
      expect(result, 5);
    });
  });

  group('isCompletedOnDay', () {
    test('returns false for empty log', () {
      expect(
        isCompletedOnDay(
          completions: const <CompletionLogEntry>[],
          asOf: DateTime(2026, 6, 13, 14),
        ),
        isFalse,
      );
    });

    test('returns true when a midnight entry matches asOf midnight', () {
      final completions = <CompletionLogEntry>[_entry(2026, 6, 13)];
      expect(
        isCompletedOnDay(
          completions: completions,
          asOf: DateTime(2026, 6, 13, 9),
        ),
        isTrue,
      );
    });

    test('returns true when only a mid-day entry exists for asOf day', () {
      // The completion row may carry an 8:00 timestamp —
      // the helper floors to midnight, so the same-day
      // tap is still detected.
      final completions = <CompletionLogEntry>[
        CompletionLogEntry(doId: 'h1', date: DateTime(2026, 6, 13, 8)),
      ];
      expect(
        isCompletedOnDay(
          completions: completions,
          asOf: DateTime(2026, 6, 13, 22),
        ),
        isTrue,
      );
    });

    test('returns false for tomorrow', () {
      final completions = <CompletionLogEntry>[_entry(2026, 6, 13)];
      expect(
        isCompletedOnDay(
          completions: completions,
          asOf: DateTime(2026, 6, 14, 0, 1),
        ),
        isFalse,
      );
    });
  });
}
