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

import 'package:doit/do/consecutive_counter.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/skip_budget.dart';
import 'package:doit/reminders/alarm_scheduler.dart' show Reliability;
import 'package:doit/widget/doit_widget_state.dart';

/// Pure-Dart computation: turn the inputs into a
/// [DoitWidgetState] for the home widget.
///
/// [activeDo] is the first-active do (oldest by `createdAt`,
/// skipping paused). `null` when no active do exists —
/// the builder returns the empty-state snapshot.
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
DoitWidgetState buildWidgetState({
  required Do? activeDo,
  required List<CompletionLogEntry> completions,
  required Reliability reliability,
  required DateTime asOf,
  required SkipBudget skipBudget,
}) {
  if (activeDo == null) {
    return DoitWidgetState(
      habitId: '',
      habitName: '',
      streakNumber: 0,
      isCompletedToday: false,
      reliability: _mapReliability(reliability),
      asOf: asOf,
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
