// Tests for ConsecutiveCounter — pure-Dart math over a completion
// log.
//
// v1.4-stab-K (Phase 51 / SYS-138 / ADR-069 / WF-066): the
// model-layer direct unit tests for `lib/do/consecutive_counter.dart`
// that bring the file to 100% line coverage.

import 'package:doit/do/consecutive_counter.dart';
import 'package:doit/do/skip_budget.dart';
import 'package:flutter_test/flutter_test.dart';

SkipBudget _emptyBudget() => SkipBudget(doId: 'h1', monthlyLimit: 2);

void main() {
  group('ConsecutiveCounter.compute — empty log', () {
    test('zero completions yields streak 0', () {
      final snap = ConsecutiveCounter.compute(
        log: const <CompletionLogEntry>[],
        config: StreakConfig(
          graceWindow: kDefaultGraceWindow,
          skipBudget: _emptyBudget(),
        ),
        asOf: DateTime(2026, 1, 15),
      );
      expect(snap.currentStreak, 0);
      expect(snap.longestStreak, 0);
      expect(snap.lastCompletion, isNull);
      expect(snap.brokenAt, isNull);
    });
  });

  group('ConsecutiveCounter.compute — single completion', () {
    test('one completion today yields streak 1', () {
      final snap = ConsecutiveCounter.compute(
        log: <CompletionLogEntry>[
          CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 15)),
        ],
        config: StreakConfig(
          graceWindow: kDefaultGraceWindow,
          skipBudget: _emptyBudget(),
        ),
        asOf: DateTime(2026, 1, 15, 12),
      );
      expect(snap.currentStreak, 1);
      expect(snap.lastCompletion, DateTime(2026, 1, 15));
    });
  });

  group('ConsecutiveCounter.compute — consecutive days', () {
    test('three consecutive completions yield streak 3', () {
      final snap = ConsecutiveCounter.compute(
        log: <CompletionLogEntry>[
          CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 13)),
          CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 14)),
          CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 15)),
        ],
        config: StreakConfig(
          graceWindow: kDefaultGraceWindow,
          skipBudget: _emptyBudget(),
        ),
        asOf: DateTime(2026, 1, 15, 12),
      );
      expect(snap.currentStreak, 3);
      expect(snap.longestStreak, 3);
    });
  });

  group('ConsecutiveCounter.compute — missed day past grace', () {
    test('missed day beyond grace window breaks the run', () {
      final snap = ConsecutiveCounter.compute(
        log: <CompletionLogEntry>[
          CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 13)),
          // 2026-01-14 is missing
          CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 15)),
        ],
        config: StreakConfig(
          graceWindow: kDefaultGraceWindow,
          skipBudget: _emptyBudget(),
        ),
        asOf: DateTime(2026, 1, 15, 12),
      );
      // The streak is broken at 1/14; the current streak is 1
      // (only 1/15).
      expect(snap.currentStreak, 1);
      expect(snap.brokenAt, DateTime(2026, 1, 14));
    });
  });

  group('ConsecutiveCounter.compute — within grace window', () {
    test('late completion within grace window keeps streak alive', () {
      final snap = ConsecutiveCounter.compute(
        log: <CompletionLogEntry>[
          CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 13)),
          CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 14)),
        ],
        config: StreakConfig(
          graceWindow: const Duration(hours: 12),
          skipBudget: _emptyBudget(),
        ),
        // asOf is 6 hours into 2026-01-15 — within grace of 1/14.
        asOf: DateTime(2026, 1, 15, 6),
      );
      // The streak survives because 1/15 is still within grace of
      // 1/14 (window is 12h).
      expect(snap.currentStreak, greaterThanOrEqualTo(2));
    });
  });

  group('ConsecutiveCounter.compute — duplicate same-day entries', () {
    test('two completions on the same day collapse to one', () {
      final snap = ConsecutiveCounter.compute(
        log: <CompletionLogEntry>[
          CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 15, 8)),
          CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 15, 20)),
        ],
        config: StreakConfig(
          graceWindow: kDefaultGraceWindow,
          skipBudget: _emptyBudget(),
        ),
        asOf: DateTime(2026, 1, 15, 22),
      );
      expect(snap.currentStreak, 1);
    });
  });

  group(
    'ConsecutiveCounter.compute — longestStreak independent of current',
    () {
      test('longestStreak persists even when currentStreak is 0', () {
        final snap = ConsecutiveCounter.compute(
          log: <CompletionLogEntry>[
            CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 15)),
            CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 16)),
            CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 17)),
            // Long gap; current streak is now 0.
            CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 24)),
          ],
          config: StreakConfig(
            graceWindow: kDefaultGraceWindow,
            skipBudget: _emptyBudget(),
          ),
          // asOf is well past 1/24's grace window.
          asOf: DateTime(2026, 1, 30, 12),
        );
        expect(snap.longestStreak, greaterThanOrEqualTo(3));
      });
    },
  );
}
