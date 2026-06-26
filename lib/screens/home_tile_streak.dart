// Pure-Dart streak helper for the in-app home tile.
//
// Mirrors the streak computation in
// `lib/widget/widget_state_builder.dart` (v1.4a) but
// returns the raw `int` the tile renders next to the do
// name, not the full `DoitWidgetState` envelope the widget
// renders. The tile and the widget share the same
// `ConsecutiveCounter.compute(...)` algorithm and the
// same `Do.effectiveStreakConfig(...)` factory, so the
// streak number is byte-identical across surfaces.
//
// Layer rules (per `.claude/rules/lib-habits.md`):
//   - Pure Dart. No Flutter imports.
//   - No `DateTime.now()` inside. The caller passes the
//     frozen `asOf`.
//   - Pure function. No side effects.
//
// v1.4b / Phase 29 / SYS-116 / ADR-046 / WF-043.

import 'package:doit/do/consecutive_counter.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/skip_budget.dart';

/// Returns the current consecutive-run for [activeDo] as of
/// [asOf]. Uses
/// `ConsecutiveCounter.compute({log, config, asOf})` and
/// pulls `currentStreak` off the resulting `StreakSnapshot`.
///
/// The `completions` list is the full completion log for
/// the do (oldest-first). The caller passes the frozen
/// list — the helper does NOT query any service.
///
/// `asOf` is the frozen reference time. The caller passes
/// the same `asOf` it uses for the rest of the screen so
/// the per-tile streak stays consistent across rebuilds.
int streakForDo({
  required Do activeDo,
  required List<CompletionLogEntry> completions,
  required DateTime asOf,
}) {
  final config = activeDo.effectiveStreakConfig(
    skipBudget: SkipBudget(
      doId: activeDo.id,
      monthlyLimit: activeDo.restDaysPerMonth,
    ),
  );
  final snapshot = ConsecutiveCounter.compute(
    log: completions,
    config: config,
    asOf: asOf,
  );
  return snapshot.currentStreak;
}

/// Returns `true` iff the do has a completion row for the
/// local-calendar day that contains [asOf]. Used by the
/// home tile to gray-out the "Done" button after the user
/// has already marked today done.
///
/// The `completions` list is the full completion log for
/// the do (oldest-first). The helper floors each entry's
/// `date` to its local midnight and compares to the
/// midnight at `asOf` (NOT a timestamp comparison — the
/// dedupe key is `(doId, local-day)`).
bool isCompletedOnDay({
  required List<CompletionLogEntry> completions,
  required DateTime asOf,
}) {
  final asOfMidnight = DateTime(asOf.year, asOf.month, asOf.day);
  for (final entry in completions) {
    final entryMidnight = DateTime(
      entry.date.year,
      entry.date.month,
      entry.date.day,
    );
    if (entryMidnight == asOfMidnight) return true;
  }
  return false;
}
