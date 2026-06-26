// Pure-Dart "7-day streak history" helper for the in-app
// home tile.
//
// Renders the last 7 days as a row of dots: filled = at
// least one completion (manual OR rest-day); empty = no
// completion recorded. Today is highlighted (the last dot).
//
// Mirrors `home_tile_undo.dart` (v1.4d / SYS-118) for the
// day-comparison convention: local-midnight at the row's
// `dayMillis` field equals `DateTime(asOf.year, asOf.month,
// asOf.day).millisecondsSinceEpoch`.
//
// Layer rules (per `.claude/rules/lib-screens.md`):
//   - The helper does NOT import `package:flutter/*`.
//   - No `DateTime.now()` inside. The caller passes the
//     frozen `asOf`.
//   - Pure side-effecting function — the only side effect is
//     the `completionLog.listForHabit` call.
//
// v1.4e / Phase 32 / SYS-119 / ADR-049 / WF-046.

import 'package:doit/do/do.dart';
import 'package:doit/services/completion_log_service.dart';

/// A single dot in the 7-day sparkline.
///
/// Sealed value class with three factories:
///
///   - [SparklineDot.filled] — at least one completion row
///     exists for [day]'s local-midnight; carries the
///     source tag so the widget can branch on
///     `rest_day` vs `manual` (the v1.0 streak calculator
///     credits both, but the sparkline tooltip may
///     distinguish them in the future).
///   - [SparklineDot.empty] — no completion row for [day].
///   - [SparklineDot.future] — [day] is in the future
///     relative to [asOf]; the widget renders a dimmed dot.
///
/// The widget treats [SparklineDot.future] the same as
/// [SparklineDot.empty] for visuals (an outline dot) but
/// the sealed split lets a future widget use a different
/// glyph for future days without re-computing the row
/// status.
sealed class SparklineDot {
  const SparklineDot();

  /// A completion row exists for [day]'s local-midnight.
  /// [source] is the source tag (`'manual'`, `'rest_day'`,
  /// `'notification'`, `'mission'`) of the first matching
  /// row in `listForHabit` order.
  const factory SparklineDot.filled({
    required DateTime day,
    required String source,
  }) = SparklineDotFilled;

  /// No completion row for [day].
  const factory SparklineDot.empty({required DateTime day}) = SparklineDotEmpty;

  /// [day] is in the future relative to `asOf`.
  const factory SparklineDot.future({required DateTime day}) =
      SparklineDotFuture;

  /// The local-midnight this dot represents. Always present
  /// across all three variants (the widget uses it to
  /// position the dot in the row).
  DateTime get day;
}

class SparklineDotFilled extends SparklineDot {
  const SparklineDotFilled({required this.day, required this.source});
  @override
  final DateTime day;
  final String source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SparklineDotFilled &&
          other.day == day &&
          other.source == source);

  @override
  int get hashCode => Object.hash(day, source);

  @override
  String toString() => 'SparklineDot.filled(day: $day, source: $source)';
}

class SparklineDotEmpty extends SparklineDot {
  const SparklineDotEmpty({required this.day});
  @override
  final DateTime day;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SparklineDotEmpty && other.day == day);

  @override
  int get hashCode => day.hashCode;

  @override
  String toString() => 'SparklineDot.empty(day: $day)';
}

class SparklineDotFuture extends SparklineDot {
  const SparklineDotFuture({required this.day});
  @override
  final DateTime day;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SparklineDotFuture && other.day == day);

  @override
  int get hashCode => day.hashCode;

  @override
  String toString() => 'SparklineDot.future(day: $day)';
}

/// The 7-day sparkline: a row of 7 dots, oldest first, today
/// last. The helper is pure-Dart: takes a frozen [asOf] and
/// the completion log, returns the 7 dots. The widget
/// renders them.
///
/// The 7 days are the 6 days BEFORE [asOf]'s local-midnight
/// plus [asOf]'s day itself (so today is always the last dot,
/// even when [asOf] is in the morning — the user has not yet
/// completed today's row, but the dot is positioned at the
/// "today" slot so the visual rhythm matches the calendar).
///
/// The helper does NOT filter by [CompletionSource] — both
/// `manual` and `rest_day` (and `notification` / `mission`)
/// count as "the day was resolved". The v1.0 streak
/// calculator credits `rest_day` identically to `manual`,
/// so this is the consistent semantic.
Future<List<SparklineDot>> sparklineForDo({
  required Do activeDo,
  required DateTime asOf,
  required CompletionLogService completionLog,
}) async {
  // 1. Fetch all completions for the do. Same query
  // backs `CompletionLogSection` (v1.2m / SYS-108) +
  // `home_tile_undo.undoToday` (v1.4d / SYS-118) +
  // `streakForDo` (v1.4b / SYS-116). DB is the
  // source-of-truth.
  final rows = await completionLog.listForHabit(activeDo.id);

  // 2. Build the 7 day-midnight timestamps, oldest first.
  // `asOf`'s local-midnight is today (the 7th dot); the 6
  // days before it are the 1st..6th dots.
  final today = DateTime(asOf.year, asOf.month, asOf.day);
  final days = <DateTime>[
    for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
  ];

  // 3. First-match lookup: returns the source tag of the
  // first row in `listForHabit` order whose `dayMillis`
  // matches the queried day, or null when no row matches.
  // This is a linear scan over `rows`; the in-app home
  // screen has at most ~30 days × 10 dos = 300 rows per
  // rebuild, so the cost is negligible. The "first match"
  // semantic mirrors `home_tile_undo.undoToday` (v1.4d)
  // so the two helpers stay in lockstep on the
  // same-day tiebreak rule.
  String? sourceFor(int dayMillis) {
    for (final r in rows) {
      if (r.dayMillis == dayMillis) return r.source;
    }
    return null;
  }

  // 4. Emit the 7 dots. If `today` is in the future of
  // [asOf] (which can happen when a unit test passes a
  // frozen [asOf] that has not yet been written), emit a
  // `SparklineDot.future` instead of `empty`. (Today is
  // never future relative to [asOf] by construction — [asOf]
  // IS today — but the helper is robust to that edge case
  // for unit-test convenience.)
  final dots = <SparklineDot>[];
  for (final day in days) {
    final source = sourceFor(day.millisecondsSinceEpoch);
    if (source != null) {
      dots.add(SparklineDot.filled(day: day, source: source));
    } else if (day.isAfter(today)) {
      dots.add(SparklineDot.future(day: day));
    } else {
      dots.add(SparklineDot.empty(day: day));
    }
  }
  return dots;
}
