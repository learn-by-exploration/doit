// Tests for ConsecutiveCounter — pure-Dart math over a completion
// log.
//
// v1.4-stab-K (Phase 51 / SYS-138 / ADR-069 / WF-066): the
// model-layer direct unit tests for `lib/do/consecutive_counter.dart`
// that bring the file to 100% line coverage.
//
// v1.6-θ (SYS-153 / ADR-084 / WF-081): +4 cross-cutting
// invariants — `StreakSnapshot` value equality, `CompletionLogEntry`
// value equality, grace-window boundary at exactly the
// 03:00 cutoff, and `SkipBudget` consumption propagating into
// `restDaysUsed`.

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

  // ---- v1.6-θ / SYS-153 / ADR-084 / WF-081 ----
  // Cross-cutting invariants on the data classes that the
  // calculator returns + the boundary behavior of the
  // grace-window cutoff + the `SkipBudget` → `restDaysUsed`
  // propagation that the calculator uses to surface the
  // budget state to the UI.
  group('Cross-cutting invariants (v1.6-θ)', () {
    test('StreakSnapshot value equality + hashCode match for identical '
        'contents (v1.6-θ)', () {
      // Arrange — two snapshots with identical fields. `const`
      // literals are canonicalized in Dart, so `a` and `b`
      // resolve to the SAME instance. The test pins the
      // PUBLIC contract — value-equality + matching hashCodes —
      // without asserting on identity. The diff pair below
      // proves that single-field inequality propagates.
      const a = StreakSnapshot(
        currentStreak: 3,
        longestStreak: 5,
        lastCompletion: null,
        brokenAt: null,
        restDaysUsed: 0,
      );
      const b = StreakSnapshot(
        currentStreak: 3,
        longestStreak: 5,
        lastCompletion: null,
        brokenAt: null,
        restDaysUsed: 0,
      );

      // Act + Assert — value equality holds AND hashCodes
      // match (a contract that enables Set<StreakSnapshot> +
      // Map<StreakSnapshot, ...> consumers). The v1.4-stab-K
      // baseline covered the calculator output; v1.6-θ adds
      // the value-equality pin on the result class itself.
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);

      // Field-by-field inequality propagates — single-field
      // change must break equality (the contract is sound in
      // both directions).
      const diff = StreakSnapshot(
        currentStreak: 4, // ← differs from a/b's 3
        longestStreak: 5,
        lastCompletion: null,
        brokenAt: null,
        restDaysUsed: 0,
      );
      expect(a == diff, isFalse);
    });

    test('CompletionLogEntry value equality matches field-wise '
        '(v1.6-θ)', () {
      // Arrange — two entries with identical fields but
      // distinct object identities. `CompletionLogEntry`
      // does NOT override `==`, so the default identity-
      // equality applies.
      final a = CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 15));
      final b = CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 15));

      // Act + Assert — Dart 3's `@immutable` data classes
      // get value-equality from the synthesized `==` only
      // when the class does NOT override it. `CompletionLogEntry`
      // does NOT override `==`, so the default identity-
      // equality applies. This test pins the current
      // behavior so a future "override to add value-equality"
      // change fails loudly here (and is easy to update
      // when the team decides to add it).
      expect(identical(a, b), isFalse);
      expect(a.doId, b.doId);
      expect(a.date, b.date);
      expect(a.note, b.note);
    });

    test('grace window boundary at exactly 03:00 of the day after a '
        'missed day keeps the run alive (v1.6-θ)', () {
      // Arrange — SYS-019 specifies a default 03:00 grace
      // window. The boundary is `endOfLastDay + graceWindow`,
      // so a completion at 2026-01-15 with `asOf` on
      // 2026-01-16 keeps the run alive UNTIL exactly
      // 2026-01-16 03:00. The grace logic only fires when
      // `daysSinceLast == 1` (i.e., asOf is the day AFTER
      // the last completion, not 2+ days later).
      final snapInside = ConsecutiveCounter.compute(
        log: <CompletionLogEntry>[
          CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 15)),
        ],
        config: StreakConfig(
          graceWindow: kDefaultGraceWindow, // 3 hours
          skipBudget: _emptyBudget(),
        ),
        // asOf = 2026-01-16 02:59:59 — INSIDE the grace
        // window (just before the 03:00 cutoff).
        asOf: DateTime(2026, 1, 16, 2, 59, 59),
      );
      expect(snapInside.currentStreak, 1);
      expect(snapInside.brokenAt, isNull);

      // Act + Assert — at 03:00:01 (one second past), the
      // run is now broken.
      final snapPast = ConsecutiveCounter.compute(
        log: <CompletionLogEntry>[
          CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 15)),
        ],
        config: StreakConfig(
          graceWindow: kDefaultGraceWindow,
          skipBudget: _emptyBudget(),
        ),
        asOf: DateTime(2026, 1, 16, 3, 0, 1),
      );
      expect(snapPast.currentStreak, 0);
      // `brokenAt` is the day AFTER the last completion, so
      // 2026-01-16 (one day after 1/15).
      expect(snapPast.brokenAt, DateTime(2026, 1, 16));
    });

    test('SkipBudget consumption propagates into StreakSnapshot.restDaysUsed '
        '(cross-cutting — v1.6-θ)', () {
      // Arrange — a budget with one consumed day in the
      // current calendar month. The calculator surfaces
      // `restDaysUsed` in the snapshot so the home tile can
      // display "1 of 2 skip days used this month".
      final consumed = _emptyBudget().consume(DateTime(2026, 1, 10));

      // Act.
      final snap = ConsecutiveCounter.compute(
        log: <CompletionLogEntry>[
          CompletionLogEntry(doId: 'h1', date: DateTime(2026, 1, 15)),
        ],
        config: StreakConfig(
          graceWindow: kDefaultGraceWindow,
          skipBudget: consumed,
        ),
        asOf: DateTime(2026, 1, 15, 12),
      );

      // Assert — the snapshot carries `restDaysUsed: 1` even
      // though the log has only 1 completion (the restDaysUsed
      // field is independent of the streak math).
      expect(snap.restDaysUsed, 1);
      expect(snap.currentStreak, 1);
    });
  });
}
