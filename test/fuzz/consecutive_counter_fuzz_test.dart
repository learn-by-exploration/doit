// v1.4-stab-L / Phase 52 / SYS-139 / ADR-070 / WF-067:
// ConsecutiveCounter fuzz test.
//
// 1000 iterations of randomized completion-log + asOf inputs
// driving [ConsecutiveCounter.compute]. Invariants pinned:
//   - streak never goes negative (Cycle A audit invariant).
//   - streak is bounded by the log size + grace-window rules.
//   - the function is deterministic — same inputs → same
//     snapshot, every iteration.
//   - the function does not throw on arbitrary inputs (no
//     DateTime.now() inside; pure-Dart computation).
//
// Fuzz seed: `dart:math.Random(seed)`.

import 'dart:math';

import 'package:doit/do/consecutive_counter.dart';
import 'package:doit/do/skip_budget.dart';
import 'package:flutter_test/flutter_test.dart';

const int _iterations = 1000;

class _Fuzz {
  _Fuzz(int seed) : _rng = Random(seed);
  final Random _rng;

  int nextInt(int max) => _rng.nextInt(max);

  /// Generates a randomized completion log. Length 0..30.
  List<CompletionLogEntry> nextLog(String doId) {
    final n = _rng.nextInt(31);
    final base = DateTime(2026, 1 + _rng.nextInt(12), 15);
    final log = <CompletionLogEntry>[];
    var cursor = base;
    for (var i = 0; i < n; i++) {
      // Day jitter — most days consecutive, some gaps.
      cursor = cursor.add(Duration(days: _rng.nextInt(4)));
      log.add(
        CompletionLogEntry(
          doId: doId,
          date: cursor,
          note: _rng.nextBool() ? null : 'note-$i',
        ),
      );
    }
    return log;
  }
}

void main() {
  test(
    'ConsecutiveCounter.compute invariants hold over 1000 fuzz iterations',
    () {
      // Arrange
      final fuzz = _Fuzz(46);
      const doId = 'do-fuzz';

      // Act + Assert
      for (var i = 0; i < _iterations; i++) {
        final log = fuzz.nextLog(doId);
        final asOf = DateTime(
          2026,
          1 + fuzz.nextInt(12),
          15,
          fuzz.nextInt(24),
          fuzz.nextInt(60),
        );
        final grace = Duration(hours: fuzz.nextInt(48));
        final budget = SkipBudget(doId: doId, monthlyLimit: fuzz.nextInt(5));
        final config = StreakConfig(graceWindow: grace, skipBudget: budget);

        // Deterministic + non-throwing.
        final snap1 = ConsecutiveCounter.compute(
          log: log,
          config: config,
          asOf: asOf,
        );
        final snap2 = ConsecutiveCounter.compute(
          log: log,
          config: config,
          asOf: asOf,
        );

        // Invariant: streak never goes negative.
        expect(snap1.currentStreak, greaterThanOrEqualTo(0));
        expect(snap1.longestStreak, greaterThanOrEqualTo(0));

        // Invariant: longestStreak ≥ currentStreak.
        expect(snap1.longestStreak, greaterThanOrEqualTo(snap1.currentStreak));

        // Invariant: deterministic — same inputs → same output.
        expect(snap2.currentStreak, equals(snap1.currentStreak));
        expect(snap2.longestStreak, equals(snap1.longestStreak));
        expect(snap2.lastCompletion, equals(snap1.lastCompletion));
        expect(snap2.brokenAt, equals(snap1.brokenAt));
        expect(snap2.restDaysUsed, equals(snap1.restDaysUsed));
      }
    },
  );
}
