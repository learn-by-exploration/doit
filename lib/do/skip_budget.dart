// Skip-day budget — per-do, per-calendar-month counter.
//
// Each do gets a fixed number of skip days per month (default 2;
// stored on the do itself as `restDaysPerMonth`). A skip day is
// a calendar day the user explicitly marks as "not doing this
// do" — distinct from a missed day. Skip days do NOT break the
// consecutive-run; missed days do.
//
// v1.0 reframe (Phase A): renamed from `SkipBudget` to
// `SkipBudget` to better reflect the user-facing semantics. The
// DB column stays `restDaysPerMonth` (no migration).
//
// The budget is in-memory state for v0.1; the Drift
// persistence layer (Phase 2) will store the consumed-days
// list per do. The in-memory representation is a sorted list
// of `DateTime` (local-calendar day) entries.
//
// Layer rules: pure Dart, no Flutter, no `DateTime.now()`.

import 'package:meta/meta.dart';

/// WF-024 (Phase 11g). The global default skip-day budget per
/// calendar month. Per-do overrides live on
/// `Do.restDaysPerMonth` (already a field on the model since
/// v0.1); the UI in `lib/screens/add_habit.dart` defaults new
/// dos to this value. Matches the historical default of 2
/// rest days per month.
const int kDefaultRestDaysPerMonth = 2;

/// Thrown by [SkipBudget.consume] when the budget is exhausted
/// for the current month.
@immutable
class SkipBudgetExhausted implements Exception {
  const SkipBudgetExhausted(this.doId, this.year, this.month);
  final String doId;
  final int year;
  final int month;

  @override
  String toString() =>
      'SkipBudgetExhausted: $doId has no skip days '
      'left in $year-${month.toString().padLeft(2, "0")}.';
}

/// Per-do, per-calendar-month skip-day counter.
///
/// The state is a sorted set of consumed days for the current
/// month. When a new month is touched (consume or query), the
/// stored days are filtered to the new month, effectively
/// rolling the budget over.
@immutable
class SkipBudget {
  SkipBudget({
    required this.doId,
    required this.monthlyLimit,
    Set<DateTime>? consumedDays,
  }) : assert(monthlyLimit >= 0),
       _consumed = Set<DateTime>.unmodifiable(consumedDays ?? <DateTime>{});

  final String doId;
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

  /// Alias used by the consecutive-run calculator: count
  /// consumed on or before [reference]. Equivalent to
  /// `usedInMonth`.
  int usedOnOrBefore(DateTime reference) => usedInMonth(reference);

  /// Remaining skip days for the month of [reference].
  int remainingInMonth(DateTime reference) {
    final used = usedInMonth(reference);
    final rem = monthlyLimit - used;
    return rem < 0 ? 0 : rem;
  }

  /// Consume one skip day for [date]. Returns a NEW budget
  /// (immutability). Throws [SkipBudgetExhausted] when the
  /// month is full. The new budget has the same `doId` and
  /// `monthlyLimit`; only `_consumed` changes.
  SkipBudget consume(DateTime date) {
    final day = _toDay(date);
    final used = usedInMonth(day);
    if (used >= monthlyLimit) {
      throw SkipBudgetExhausted(doId, day.year, day.month);
    }
    final next = Set<DateTime>.from(_consumed)..add(day);
    return SkipBudget(
      doId: doId,
      monthlyLimit: monthlyLimit,
      consumedDays: next,
    );
  }

  /// Roll over to the month of [reference]. Any stored days
  /// outside the reference month are dropped. Returns a new
  /// budget.
  SkipBudget rollOver(DateTime reference) {
    final ref = _toDay(reference);
    final next = _consumed.where((d) => _isSameMonth(d, ref)).toSet();
    if (next.length == _consumed.length) return this;
    return SkipBudget(
      doId: doId,
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
