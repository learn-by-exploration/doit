// Streak calculator — pure-Dart math over a completion log.
//
// The completion log is the source of truth; the streak number
// is derived. The calculator is the only place that decides
// what "did the streak break today?" means.
//
// Layer rules (per .claude/rules/lib-habits.md):
//   - No Flutter imports.
//   - No `DateTime.now()` inside the calculator. The caller
//     passes `asOf`. This is the only way the streak is
//     testable across DST / timezone changes / time travel.
//   - The streak never goes negative.
//
// Inputs:
//   - `log` is the full history of completions for a single
//     habit, ordered or unordered. The calculator sorts by
//     date and de-duplicates per-day (multiple completions on
//     the same day collapse to one).
//   - `config` carries the grace window and the rest-day
//     budget. Both are per-habit; the calculator does not
//     know the habit's other fields.
//   - `asOf` is the reference "now" — the test's frozen clock
//     or the app's wall clock.

import 'package:common_games/habits/rest_day_budget.dart';
import 'package:meta/meta.dart';

/// A single completion of a habit.
///
/// [date] is the local-calendar date the user marked the habit
/// done. Times of day are ignored — two completions on the
/// same calendar day collapse to one (the calculator de-dupes).
@immutable
class CompletionLogEntry {
  const CompletionLogEntry({
    required this.habitId,
    required this.date,
    this.note,
  });

  final String habitId;
  final DateTime date;
  final String? note;
}

/// Configuration for streak calculation. Per-habit.
@immutable
class StreakConfig {
  const StreakConfig({required this.graceWindow, required this.restDayBudget});

  /// How long after a missed day can the user still complete
  /// the habit without breaking the streak. SYS-019: default
  /// 03:00 — the user has until 3:00 AM of the next day to
  /// mark yesterday done.
  final Duration graceWindow;

  /// The rest-day budget for this habit. A day the user
  /// explicitly marks as a "rest day" (not just missed)
  /// consumes one budget unit and does NOT break the streak.
  final RestDayBudget restDayBudget;
}

/// Snapshot of the streak state at a point in time.
@immutable
class StreakSnapshot {
  const StreakSnapshot({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastCompletion,
    required this.brokenAt,
    required this.restDaysUsed,
  });

  /// The streak as of [asOf]. Always ≥ 0.
  final int currentStreak;

  /// The longest streak the user has ever held on this habit.
  final int longestStreak;

  /// The most recent completion date in the log.
  final DateTime? lastCompletion;

  /// The date the current streak was broken, if applicable.
  /// `null` if the streak is still alive.
  final DateTime? brokenAt;

  /// How many rest days the user has used this calendar
  /// month. Surfaced in the UI so the user knows how many
  /// they have left.
  final int restDaysUsed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StreakSnapshot &&
        other.currentStreak == currentStreak &&
        other.longestStreak == longestStreak &&
        other.lastCompletion == lastCompletion &&
        other.brokenAt == brokenAt &&
        other.restDaysUsed == restDaysUsed;
  }

  @override
  int get hashCode => Object.hash(
    currentStreak,
    longestStreak,
    lastCompletion,
    brokenAt,
    restDaysUsed,
  );
}

/// The calculator. Stateless: pass the inputs, get a snapshot.
@immutable
class StreakCalculator {
  const StreakCalculator._();

  /// Compute the streak. Pure function.
  ///
  /// Rules:
  ///   1. Two completions on the same calendar day count as
  ///      one.
  ///   2. A gap of more than 1 day in the log breaks the
  ///      streak. A 1-day gap is a missed day; the streak
  ///      resets after it.
  ///   3. The grace window is a *boundary* check: if the
  ///      last completion is yesterday (in calendar days)
  ///      AND `asOf` is within the grace window past
  ///      yesterday's end-of-day, the streak is still
  ///      considered alive. SYS-019: default grace 03:00
  ///      means the user has until 03:00 of the day after
  ///      the missed day to "fix" it (i.e., complete the
  ///      missed day retroactively — the engine treats the
  ///      boundary as alive so the UI can prompt for it).
  static StreakSnapshot compute({
    required List<CompletionLogEntry> log,
    required StreakConfig config,
    required DateTime asOf,
  }) {
    final empty = StreakSnapshot(
      currentStreak: 0,
      longestStreak: 0,
      lastCompletion: null,
      brokenAt: null,
      restDaysUsed: config.restDayBudget.usedOnOrBefore(asOf),
    );
    if (log.isEmpty) return empty;

    // De-duplicate per day.
    final byDay = <DateTime, CompletionLogEntry>{};
    for (final entry in log) {
      final day = _toDay(entry.date);
      final existing = byDay[day];
      if (existing == null || (entry.note != null && existing.note == null)) {
        byDay[day] = entry;
      }
    }
    final sortedDays = byDay.keys.toList()..sort();
    if (sortedDays.isEmpty) return empty;
    final lastDay = sortedDays.last;
    final asOfDay = _toDay(asOf);

    // Walk the log, counting runs.
    var run = 1;
    var longest = 1;
    DateTime? brokenAt;
    for (var i = 1; i < sortedDays.length; i++) {
      final prev = sortedDays[i - 1];
      final day = sortedDays[i];
      final gap = day.difference(prev).inDays;
      if (gap == 1) {
        run++;
      } else {
        // Streak broke between prev and day. Record the
        // earliest break only.
        brokenAt ??= _addDays(prev, 1);
        run = 1;
      }
      if (run > longest) longest = run;
    }

    // Boundary check: is the streak still alive at asOf?
    final daysSinceLast = asOfDay.difference(lastDay).inDays;
    final isStreakAlive =
        daysSinceLast == 0 ||
        (daysSinceLast == 1 && _withinGrace(lastDay, asOf, config));

    if (!isStreakAlive) {
      brokenAt ??= _addDays(lastDay, 1);
      return StreakSnapshot(
        currentStreak: 0,
        longestStreak: longest,
        lastCompletion: lastDay,
        brokenAt: brokenAt,
        restDaysUsed: config.restDayBudget.usedOnOrBefore(asOf),
      );
    }

    return StreakSnapshot(
      currentStreak: run,
      longestStreak: longest,
      lastCompletion: lastDay,
      brokenAt: brokenAt,
      restDaysUsed: config.restDayBudget.usedOnOrBefore(asOf),
    );
  }

  /// True if [asOf] is at most `1 day + graceWindow` past the
  /// end of [lastDay]. I.e., the user is still inside the
  /// grace window after a single missed day.
  static bool _withinGrace(
    DateTime lastDay,
    DateTime asOf,
    StreakConfig config,
  ) {
    final endOfLastDay = DateTime(
      lastDay.year,
      lastDay.month,
      lastDay.day,
    ).add(const Duration(days: 1));
    final graceEnd = endOfLastDay.add(config.graceWindow);
    return !asOf.isAfter(graceEnd);
  }

  static DateTime _toDay(DateTime d) {
    final l = d.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  static DateTime _addDays(DateTime d, int n) {
    final l = d.toLocal();
    return DateTime(l.year, l.month, l.day + n);
  }
}
