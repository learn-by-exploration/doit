// Pure-Dart widget-state builder.
//
// Turns a [Do] + completion log + current reliability
// + reference time into a [DoitWidgetState]. Used by the
// Dart `WidgetService` on every recompute (completion-log
// write, reliability change, do-list change).
//
// Layer rules:
//   - No Flutter imports. The widget state is plain Dart
//     so the unit tests can exercise it without a Flutter
//     test harness.
//   - No `DateTime.now()` inside the builder. The caller
//     passes `asOf` so the streak computation and
//     `isCompletedToday` check are deterministic.
//   - Reuses [ConsecutiveCounter.compute] verbatim — the
//     streak calculation is the same one the home screen
//     uses, so the widget never disagrees with the home
//     screen.
//
// v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042.
// v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047: restDaysPerMonth.
// v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052: selectedHabitId —
// the user-picked habit id for this widget instance, threaded
// through into the returned DoitWidgetState.

import 'package:doit/do/consecutive_counter.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/skip_budget.dart';
import 'package:doit/reminders/alarm_scheduler.dart' show Reliability;
import 'package:doit/widget/doit_widget_state.dart';

/// Pure-Dart computation: turn the inputs into a
/// [DoitWidgetState] for the home widget.
///
/// [activeDo] is the active do — by v1.4k, the
/// `selectedHabitId` from the cached state if set and
/// resolvable, otherwise the v1.4a `firstActiveDo`
/// fallback. `null` when no active do exists — the
/// builder returns the empty-state snapshot.
///
/// [completions] is the completion log for [activeDo],
/// oldest-first. The builder de-dupes per local-day via
/// the [ConsecutiveCounter] algorithm (matches the home-
/// screen streak exactly).
///
/// [reliability] is the current app-wide reliability.
/// The widget shows the matching badge icon.
///
/// [asOf] is the frozen reference time. The builder uses
/// it for the streak's "is the run still alive at asOf?"
/// check and for the `isCompletedToday` lookup.
///
/// [skipBudget] is the per-do skip-day budget. The
/// builder threads it into the [StreakConfig] so the
/// per-do rest-day allowance is honored.
///
/// [selectedHabitId] is the user-picked habit id for
/// this widget instance. v1.4k / SYS-125 / ADR-055 /
/// WF-052: when non-null, it is preserved in the
/// returned state's `selectedHabitId` so a future
/// `handleRefreshRequest` re-resolves to the same do.
/// When `null` (default), the builder preserves the
/// "first-active" behavior of v1.4a..v1.4j — the
/// selectedHabitId is `null` in the next cached state.
DoitWidgetState buildWidgetState({
  required Do? activeDo,
  required List<CompletionLogEntry> completions,
  required Reliability reliability,
  required DateTime asOf,
  required SkipBudget skipBudget,
  String? selectedHabitId,
}) {
  if (activeDo == null) {
    return DoitWidgetState(
      habitId: '',
      habitName: '',
      streakNumber: 0,
      isCompletedToday: false,
      reliability: _mapReliability(reliability),
      asOf: asOf,
      // v1.4k / SYS-125: when activeDo is null the
      // selection is preserved (the user might be
      // re-binding the widget and the underlying do is
      // temporarily missing). The reconciliation in
      // WidgetService.handleRefreshRequest will clear
      // it on the next pass if getById keeps returning
      // null.
      selectedHabitId: selectedHabitId,
    );
  }
  final config = activeDo.effectiveStreakConfig(skipBudget: skipBudget);
  final streak = ConsecutiveCounter.compute(
    log: completions,
    config: config,
    asOf: asOf,
  );
  final today = DateTime(asOf.year, asOf.month, asOf.day);
  final done = completions.any((entry) {
    final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
    return day == today;
  });
  return DoitWidgetState(
    habitId: activeDo.id,
    habitName: activeDo.name,
    streakNumber: streak.currentStreak,
    isCompletedToday: done,
    reliability: _mapReliability(reliability),
    asOf: asOf,
    // v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047:
    // thread the active do's rest-day budget so the Kotlin
    // `WidgetRenderer` can show / hide the "Skip today"
    // ImageButton. The home tile has the same conditional
    // render via `_SkipButton`.
    restDaysPerMonth: activeDo.restDaysPerMonth,
    // v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052.
    // Thread the user-picked habit id through so a
    // future `handleRefreshRequest` re-resolves to the
    // same do. The Kotlin `WidgetRenderer.openAppIntent`
    // reads `selectedHabitId` from the cached state
    // JSON to add `EXTRA_HABIT_ID` to the body-tap
    // PendingIntent.
    selectedHabitId: selectedHabitId,
  );
}

DoitWidgetReliability _mapReliability(Reliability r) {
  switch (r) {
    case Reliability.optimal:
      return DoitWidgetReliability.optimal;
    case Reliability.degraded:
      return DoitWidgetReliability.degraded;
    case Reliability.unknown:
      return DoitWidgetReliability.unknown;
  }
}
