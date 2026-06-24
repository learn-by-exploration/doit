// Consecutive-run counter — pure-Dart math over a completion log.
//
// The completion log is the source of truth; the consecutive-run
// number is derived. The counter is the only place that decides
// what "did the run break today?" means.
//
// v1.0 reframe (Phase A): renamed from `ConsecutiveCounter` to
// `ConsecutiveCounter` to better reflect the user-facing
// semantics (PR A2 will swap the UI copy "streak" →
// "consecutive done"). The DB column stays `proofMode` and the
// algorithm is unchanged.
//
// Layer rules (per .claude/rules/lib-do.md):
//   - No Flutter imports.
//   - No `DateTime.now()` inside the calculator. The caller
//     passes `asOf`. This is the only way the consecutive-run is
//     testable across DST / timezone changes / time travel.
//   - The consecutive-run never goes negative.
//
// Inputs:
//   - `log` is the full history of completions for a single do,
//     ordered or unordered. The calculator sorts by date and
//     de-duplicates per-day (multiple completions on the same
//     day collapse to one).
//   - `config` carries the grace window and the skip-day
//     budget. Both are per-do; the calculator does not know
//     the do's other fields.
//   - `asOf` is the reference "now" — the test's frozen clock
//     or the app's wall clock.

import 'package:doit/do/skip_budget.dart';
import 'package:meta/meta.dart';

/// v1.3a (SYS-116): the app-wide default grace window for the
/// consecutive-run calculator. The user has this much time
/// past the end of a missed day to retroactively complete it
/// before the run is considered broken.
///
/// Lives at top-level (not on [StreakConfig]) so it is the
/// single source of truth that both [StreakConfig] consumers
/// (the stats screen) and the per-do override factory
/// ([Do.effectiveStreakConfig]) reference. Keep it
/// `Duration.zero`-aware: a do that sets its
/// `graceWindowOverride` to `Duration.zero` is honoring
/// *no* grace window, not falling back to this default.
const Duration kDefaultGraceWindow = Duration(hours: 3);

/// A single completion of a do.
///
/// [date] is the local-calendar date the user marked the do
/// done. Times of day are ignored — two completions on the same
/// calendar day collapse to one (the calculator de-dupes).
@immutable
class CompletionLogEntry {
  const CompletionLogEntry({required this.doId, required this.date, this.note});

  final String doId;
  final DateTime date;
  final String? note;
}

/// Configuration for consecutive-run calculation. Per-do.
@immutable
class StreakConfig {
  const StreakConfig({required this.graceWindow, required this.skipBudget});

  /// How long after a missed day can the user still complete
  /// the do without breaking the consecutive-run. SYS-019:
  /// default 03:00 — the user has until 3:00 AM of the next
  /// day to mark yesterday done.
  final Duration graceWindow;

  /// The skip-day budget for this do. A day the user explicitly
  /// marks as a "skip day" (not just missed) consumes one
  /// budget unit and does NOT break the consecutive-run.
  final SkipBudget skipBudget;
}

/// Snapshot of the consecutive-run state at a point in time.
@immutable
class StreakSnapshot {
  const StreakSnapshot({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastCompletion,
    required this.brokenAt,
    required this.restDaysUsed,
  });

  /// The consecutive-run as of [asOf]. Always ≥ 0.
  final int currentStreak;

  /// The longest consecutive-run the user has ever held on
  /// this do.
  final int longestStreak;

  /// The most recent completion date in the log.
  final DateTime? lastCompletion;

  /// The date the current consecutive-run was broken, if
  /// applicable. `null` if the run is still alive.
  final DateTime? brokenAt;

  /// How many skip days the user has used this calendar month.
  /// Surfaced in the UI so the user knows how many they have
  /// left.
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
///
/// v1.0 reframe: the canonical name is `ConsecutiveCounter`.
/// The old name `ConsecutiveCounter` is kept as a typedef alias
/// in `lib/do/streak_calculator_shim.dart` for backward-compat
/// with PR-A1 imports. New code uses `ConsecutiveCounter`.
@immutable
class ConsecutiveCounter {
  const ConsecutiveCounter._();

  /// Compute the consecutive-run. Pure function.
  ///
  /// Rules:
  ///   1. Two completions on the same calendar day count as
  ///      one.
  ///   2. A gap of more than 1 day in the log breaks the
  ///      consecutive-run. A 1-day gap is a missed day; the
  ///      run resets after it.
  ///   3. The grace window is a *boundary* check: if the last
  ///      completion is yesterday (in calendar days) AND
  ///      `asOf` is within the grace window past yesterday's
  ///      end-of-day, the run is still considered alive.
  ///      SYS-019: default grace 03:00 means the user has
  ///      until 03:00 of the day after the missed day to
  ///      "fix" it (i.e., complete the missed day
  ///      retroactively — the engine treats the boundary as
  ///      alive so the UI can prompt for it).
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
      restDaysUsed: config.skipBudget.usedOnOrBefore(asOf),
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
        // Run broke between prev and day. Record the
        // earliest break only.
        brokenAt ??= _addDays(prev, 1);
        run = 1;
      }
      if (run > longest) longest = run;
    }

    // Boundary check: is the consecutive-run still alive at asOf?
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
        restDaysUsed: config.skipBudget.usedOnOrBefore(asOf),
      );
    }

    return StreakSnapshot(
      currentStreak: run,
      longestStreak: longest,
      lastCompletion: lastDay,
      brokenAt: brokenAt,
      restDaysUsed: config.skipBudget.usedOnOrBefore(asOf),
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
