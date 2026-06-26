// Pure-Dart "Skip today" helper for the in-app home tile.
//
// Mirrors `markDoDone` (v1.4b / SYS-116) but appends a
// rest-day completion (`CompletionSource.restDay`) instead
// of a manual one. The rest-day completion is the "I
// intentionally did not do this today" affordance —
// distinct from a missed day (which breaks the streak)
// and from a manual completion (which preserves it).
//
// The semantics:
//   - A manual completion for a day → streak credited.
//   - A rest-day completion for a day → streak credited
//     AND one rest-day budget unit consumed for that
//     month.
//   - A day with no completion AND no rest-day → streak
//     potentially broken (subject to the grace window).
//
// The streak calculator (`ConsecutiveCounter.compute`)
// already credits rest-day completions as part of the
// consecutive-run. The home tile just needs to expose the
// affordance to write one.
//
// Layer rules (per `.claude/rules/lib-screens.md`):
//   - No Flutter imports.
//   - No `DateTime.now()` inside. The caller passes the
//     frozen `asOf`.
//   - Pure side-effecting function — the only side effect
//     is the `completionLog.append` call.
//
// v1.4c / Phase 30 / SYS-117 / ADR-047 / WF-044.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode_tag.dart';
import 'package:doit/do/skip_budget.dart';
import 'package:doit/services/completion_log_service.dart';

/// Thrown by [markDoSkipped] when the do has no rest-day
/// budget left for the month of [asOf].
///
/// Surfaced by the tile so the UI can show a "no rest days
/// left this month" snackbar instead of silently failing.
class NoRestDaysRemaining implements Exception {
  const NoRestDaysRemaining(this.doId, this.year, this.month);
  final String doId;
  final int year;
  final int month;

  @override
  String toString() =>
      'NoRestDaysRemaining: $doId has no rest days '
      'left in $year-${month.toString().padLeft(2, "0")}.';
}

/// Append a rest-day completion for [activeDo] via
/// [completionLog] (consuming one rest-day budget unit
/// for the month of [asOf]).
///
/// The `day` argument is the local-midnight at [asOf];
/// the `source` is [CompletionSource.restDay] (the tile's
/// "Skip today" tap is conceptually distinct from the
/// tile's "Done" tap — same dedupe key, different `source`
/// tag so the streak calculator can credit it without
/// treating it as a manual completion).
///
/// The `proofModeAtTime` tag mirrors the do's current
/// `proofMode` via the shared [proofModeTag] helper
/// (v1.4c consolidation). The mode is recorded so a
/// future stats query can distinguish "skipped a strong-mode
/// habit" from "skipped a soft-mode habit" — useful for
/// debugging chain-side failures.
///
/// Throws [NoRestDaysRemaining] if [activeDo] has a zero
/// monthly budget OR the budget is exhausted for the
/// reference month. The caller catches and shows a
/// "no rest days left this month" snackbar.
Future<void> markDoSkipped({
  required Do activeDo,
  required DateTime asOf,
  required CompletionLogService completionLog,
}) async {
  // 1. Reject if the do has no rest-day budget at all.
  // The do's `restDaysPerMonth` is the authoritative
  // monthly cap; a 0 means the user opted out of
  // rest days.
  if (activeDo.restDaysPerMonth <= 0) {
    throw NoRestDaysRemaining(activeDo.id, asOf.year, asOf.month);
  }

  // 2. Count rest-day rows in the reference month. The
  // completion log is the source of truth — the
  // `RestDayBudgets` Drift table is a fast-read
  // snapshot, but `listRestDaysInMonth` walks the log
  // directly so it never lies.
  final monthRestDays = await completionLog.listRestDaysInMonth(
    activeDo.id,
    year: asOf.year,
    month: asOf.month,
  );
  final used = monthRestDays.length;

  // 3. Reject if the budget is exhausted. The
  // comparison is strict-greater-or-equal so the last
  // unit can still be consumed (e.g., limit=2, used=1
  // → remaining=1 → 1 < 2 → consume OK).
  if (used >= activeDo.restDaysPerMonth) {
    throw NoRestDaysRemaining(activeDo.id, asOf.year, asOf.month);
  }

  // 4. Reuse `SkipBudget.consume` for the immutable
  // record-keeping surface even though the DB write is
  // the source of truth. The `_SkipBudget.consume` is
  // defensive — if a future caller wraps the write
  // path in a transaction, this gives them a
  // pure-Dart check that doesn't need a DB round-trip.
  final _ = SkipBudget(
    doId: activeDo.id,
    monthlyLimit: activeDo.restDaysPerMonth,
  ).consume(asOf);

  // 5. Append the rest-day completion. The `day`
  // argument is local-midnight at `asOf` (the dedupe
  // key in `CompletionLogService.append`).
  final day = DateTime(asOf.year, asOf.month, asOf.day);
  await completionLog.append(
    habitId: activeDo.id,
    day: day,
    source: CompletionSource.restDay,
    proofModeAtTime: proofModeTag(activeDo.proofMode),
  );
}
