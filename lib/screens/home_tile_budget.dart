// Pure-Dart budget-remaining helper for the in-app home tile.
//
// The tile shows a small "X / Y rest days left this month"
// caption under the streak number (v1.4c / SYS-117).
// Computing the caption needs:
//   - the do's `restDaysPerMonth` (the cap)
//   - the count of rest-day completions in the reference
//     month (the usage)
//
// This helper exposes the derived `BudgetRemaining` value
// (a `(used, limit, remaining)` triple) so the tile can
// render without doing the math inline.
//
// Layer rules (per `.claude/rules/lib-screens.md`):
//   - No Flutter imports.
//   - No `DateTime.now()` inside. The caller passes the
//     frozen `asOf`.
//   - Pure function.
//
// v1.4c / Phase 30 / SYS-117 / ADR-047 / WF-044.

import 'package:doit/do/do.dart';
import 'package:doit/services/completion_log_service.dart';

/// Snapshot of the per-do rest-day budget state for the
/// month of [asOf]. Immutable.
class BudgetRemaining {
  const BudgetRemaining({
    required this.used,
    required this.limit,
    required this.remaining,
  }) : assert(limit >= 0),
       assert(used >= 0),
       assert(remaining >= 0);

  /// How many rest days the user has consumed in the
  /// reference month.
  final int used;

  /// The do's monthly cap (`Do.restDaysPerMonth`).
  final int limit;

  /// `limit - used`, clamped to 0. Negative deltas are
  /// impossible (a do with a smaller `limit` than
  /// historical usage would only happen via a config
  /// change mid-month; the clamp surfaces this as 0
  /// rather than throwing).
  final int remaining;

  /// True iff the user has at least one rest day left
  /// for the reference month. The tile uses this to
  /// decide whether to enable the "Skip today" button.
  bool get canSkip => remaining > 0;

  /// True iff the user has used ALL their rest days for
  /// the month. Used by the tile to switch the budget
  /// caption to "no rest days left" copy.
  bool get isExhausted => remaining == 0 && limit > 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BudgetRemaining &&
        other.used == used &&
        other.limit == limit &&
        other.remaining == remaining;
  }

  @override
  int get hashCode => Object.hash(used, limit, remaining);
}

/// Compute the rest-day budget snapshot for [activeDo]
/// at [asOf].
///
/// Pure-Dart: walks the [completionLog]'s
/// `listRestDaysInMonth` (already a pure async query)
/// and derives the triple.
///
/// A do with `restDaysPerMonth == 0` returns a snapshot
/// with `limit: 0`, `used: 0`, `remaining: 0`, and
/// `canSkip: false`. The tile uses the `limit == 0` to
/// hide the budget caption entirely (no budget to track).
Future<BudgetRemaining> budgetRemainingForDo({
  required Do activeDo,
  required DateTime asOf,
  required CompletionLogService completionLog,
}) async {
  final limit = activeDo.restDaysPerMonth;
  if (limit <= 0) {
    return const BudgetRemaining(used: 0, limit: 0, remaining: 0);
  }
  final monthRestDays = await completionLog.listRestDaysInMonth(
    activeDo.id,
    year: asOf.year,
    month: asOf.month,
  );
  final used = monthRestDays.length;
  final remaining = (limit - used).clamp(0, limit);
  return BudgetRemaining(used: used, limit: limit, remaining: remaining);
}
