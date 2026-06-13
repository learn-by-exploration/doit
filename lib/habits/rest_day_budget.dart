// Rest-day budget — per-habit, per-calendar-month counter.
//
// Each habit gets a fixed number of rest days per month
// (default 2; stored on the habit itself as `restDaysPerMonth`).
// A rest day is a calendar day the user explicitly marks as
// "not doing this habit" — distinct from a missed day. Rest
// days do NOT break the streak; missed days do.
//
// The budget is in-memory state for v0.1; the Drift
// persistence layer (Phase 2) will store the consumed-days
// list per habit. The in-memory representation is a sorted
// list of `DateTime` (local-calendar day) entries.
//
// Layer rules: pure Dart, no Flutter, no `DateTime.now()`.

import 'package:meta/meta.dart';

/// Thrown by [RestDayBudget.consume] when the budget is
/// exhausted for the current month.
@immutable
class RestDayBudgetExhausted implements Exception {
  const RestDayBudgetExhausted(this.habitId, this.year, this.month);
  final String habitId;
  final int year;
  final int month;

  @override
  String toString() =>
      'RestDayBudgetExhausted: $habitId has no rest days '
      'left in $year-${month.toString().padLeft(2, "0")}.';
}

/// Per-habit, per-calendar-month rest-day counter.
///
/// The state is a sorted set of consumed days for the current
/// month. When a new month is touched (consume or query), the
/// stored days are filtered to the new month, effectively
/// rolling the budget over.
@immutable
class RestDayBudget {
  RestDayBudget({
    required this.habitId,
    required this.monthlyLimit,
    Set<DateTime>? consumedDays,
  }) : assert(monthlyLimit >= 0),
       _consumed = Set<DateTime>.unmodifiable(consumedDays ?? <DateTime>{});

  final String habitId;
  final int monthlyLimit;
  final Set<DateTime> _consumed;

  /// Days consumed in the current calendar month (as of the
  /// most recent mutate). The set is keyed by local-calendar
  /// day, with time-of-day stripped.
  Set<DateTime> get consumedDays => _consumed;

  /// Count consumed in the month of [reference]. Returns 0
  /// outside the current month.
  int usedInMonth(DateTime reference) {
    final ref = _toDay(reference);
    return _consumed.where((d) => _isSameMonth(d, ref)).length;
  }

  /// Alias used by the streak calculator: count consumed on
  /// or before [reference]. Equivalent to `usedInMonth`.
  int usedOnOrBefore(DateTime reference) => usedInMonth(reference);

  /// Remaining rest days for the month of [reference].
  int remainingInMonth(DateTime reference) {
    final used = usedInMonth(reference);
    final rem = monthlyLimit - used;
    return rem < 0 ? 0 : rem;
  }

  /// Consume one rest day for [date]. Returns a NEW budget
  /// (immutability). Throws [RestDayBudgetExhausted] when the
  /// month is full. The new budget has the same `habitId` and
  /// `monthlyLimit`; only `_consumed` changes.
  RestDayBudget consume(DateTime date) {
    final day = _toDay(date);
    final used = usedInMonth(day);
    if (used >= monthlyLimit) {
      throw RestDayBudgetExhausted(habitId, day.year, day.month);
    }
    final next = Set<DateTime>.from(_consumed)..add(day);
    return RestDayBudget(
      habitId: habitId,
      monthlyLimit: monthlyLimit,
      consumedDays: next,
    );
  }

  /// Roll over to the month of [reference]. Any stored days
  /// outside the reference month are dropped. Returns a new
  /// budget.
  RestDayBudget rollOver(DateTime reference) {
    final ref = _toDay(reference);
    final next = _consumed.where((d) => _isSameMonth(d, ref)).toSet();
    if (next.length == _consumed.length) return this;
    return RestDayBudget(
      habitId: habitId,
      monthlyLimit: monthlyLimit,
      consumedDays: next,
    );
  }

  static DateTime _toDay(DateTime d) {
    final l = d.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  static bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;
}
