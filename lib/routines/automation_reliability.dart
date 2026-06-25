// AutomationReliability — per-automation reliability state.
//
// v1.1f follow-up to the v1.0 app-wide `Reliability` enum
// (lib/reminders/alarm_scheduler.dart). The app-wide enum
// captures "can the system wake us up at the right time?"
// (driven by exact-alarm + Doze). This file captures the
// orthogonal question: "given the user's current runtime
// permissions, is THIS specific automation's trigger able to
// fire?".
//
// Two reasons we don't reuse the existing `Reliability`
// enum directly:
//
//   - The existing enum is the answer to "is the alarm
//     system reliable app-wide?". This is per-routine —
//     the same device can have an `optimal` global state
//     and a `degraded` location-routine (because
//     ACCESS_COARSE_LOCATION was revoked).
//   - `lib/routines/` is the executor / model layer; the
//     app-wide `Reliability` enum lives in
//     `lib/reminders/`. Adding a `lib/routines/` →
//     `lib/reminders/` import would be a new
//     cross-cutting dependency for a 3-line enum.
//
// The two enums share semantics (`optimal` / `degraded` /
// `unknown`) on purpose so the existing `ReliabilityBanner`
// and the new `AutomationReliabilityBadge` render with the
// same visual language.
//
// v1.2 (SYS-086 / ADR-030 follow-up) folds in two new
// trigger-permission mappings that v1.1f deferred:
//   - `TriggerForegroundApp` → `PermissionKind.usageStats`.
//   - `TriggerCallIncoming*` → `PermissionKind.callScreening`
//     (the role check, not the (still-out-of-scope)
//     `READ_PHONE_STATE`). The badge now reports `degraded`
//     when the role is not held; the home banner still
//     reports the app-wide `Reliability` enum for the
//     cross-cutting "system is unable to wake us" signal.
//
// v1.5b (Phase 25) folds in the action-side permission
// gates that v1.1f + v1.2 reserved:
//   - `ActionCallIntercept` → `PermissionKind.callScreening`.
//     Same role as the trigger-side check; the action just
//     reuses the same probe.
//   - `ActionOverrideSilent` → `PermissionKind.notificationPolicy`.
//     Android M+ requires `ACCESS_NOTIFICATION_POLICY` for an
//     app to toggle DND. The kind is opt-in (ADR-030
//     precedent); the user is never blocked from using do it
//     for declining.
//   - `ActionFullscreen` → `PermissionKind.fullScreenIntent`.
//     Mirrors the v1.3c probe; the action is degraded on
//     API 34+ devices without the permission.
//   - `ActionNotify` and `ActionOpenApp` gate no permission.
//
// The trigger-side check still wins on a "both sides
// degraded" routine (the user sees the trigger's permission
// gate first; the action's gate renders below as a secondary
// section in the dialog).

import 'package:doit/routines/routine.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';

/// Per-automation reliability state. Mirrors the v1.0
/// app-wide `Reliability` enum semantics so the
/// `AutomationReliabilityBadge` and `ReliabilityBanner`
/// can share the same visual treatment.
enum AutomationReliability {
  /// No runtime permissions gate this trigger, or every
  /// required permission is currently `granted`.
  optimal,

  /// At least one required permission is `denied` /
  /// `permanentlyDenied` (or the app has not yet probed
  /// and we cannot tell — see `unknown`).
  degraded,

  /// We have not yet probed the runtime permission state
  /// (e.g., the `PermissionService` `ValueNotifier` has not
  /// resolved for the kind in question). The badge renders
  /// but does not act as an alert until the probe resolves.
  unknown,
}

/// Pure function: derive the reliability state of a single
/// [Automation] given the current `PermissionService.statuses`
/// snapshot. Exhaustive over the sealed [Trigger] and [Action]
/// hierarchies — adding a new leaf in either requires a new
/// case here.
///
/// Mapping (per `docs/v_model/notification_reliability.md`):
///   - `TriggerLocation*` → needs `PermissionKind.location`.
///   - `TriggerCalendarEvent*` → needs `PermissionKind.calendar`.
///   - `TriggerDeviceState*` → no runtime gate (the device-state
///     probe reads `BroadcastReceiver`s, not a runtime grant);
///     `optimal`.
///   - `TriggerCallIncoming*` → `PermissionKind.callScreening`
///     (the role probe through `CallInterceptorService
///     .isCallScreeningRoleHeld`; v1.2 wiring).
///   - `TriggerForegroundApp` → `PermissionKind.usageStats`
///     (the special-access permission through
///     `UsageStatsService.isGranted`; v1.2 wiring).
///   - `TriggerTimeOfDay` → alarm system reliability; the
///     `AlarmScheduler.reliability` getter is the source of
///     truth here, but we default to `optimal` in this
///     pure function (the badge consumer can fall back to the
///     app-wide banner if it has access).
///   - `ActionCallIntercept` → `PermissionKind.callScreening`
///     (v1.5b / Phase 25).
///   - `ActionOverrideSilent` → `PermissionKind.notificationPolicy`
///     (v1.5b / Phase 25; Android `ACCESS_NOTIFICATION_POLICY`).
///   - `ActionFullscreen` → `PermissionKind.fullScreenIntent`
///     (v1.5b / Phase 25; mirrors the v1.3c probe).
///   - `ActionNotify` and `ActionOpenApp` gate no permission.
AutomationReliability automationReliability(
  Automation automation, {
  required Map<PermissionKind, PermissionResult?> statuses,
}) {
  // Trigger-side check wins first (the user sees the
  // trigger's permission gate first in the dialog).
  final triggerKind = _requiredPermissionForTrigger(automation.trigger);
  if (triggerKind != null) {
    final status = statuses[triggerKind];
    if (status == null) return AutomationReliability.unknown;
    if (!_isGranted(status)) return AutomationReliability.degraded;
  }
  // Action-side check. Every leaf with a permission gate
  // reduces to a single kind; the dialog renders the
  // matched kind as a secondary section.
  for (final actionKind in _requiredPermissionsForAction(automation.action)) {
    final status = statuses[actionKind];
    if (status == null) return AutomationReliability.unknown;
    if (!_isGranted(status)) return AutomationReliability.degraded;
  }
  return AutomationReliability.optimal;
}

/// Map a [Trigger] leaf to the runtime permission it needs.
/// Returns `null` when no runtime permission gates the
/// trigger (e.g. `TriggerDeviceState`, `TriggerTimeOfDay`).
PermissionKind? _requiredPermissionForTrigger(Trigger trigger) {
  return switch (trigger) {
    // Geofence needs coarse location.
    TriggerLocation() => PermissionKind.location,
    // Calendar observer needs read-calendar.
    TriggerCalendarEvent() => PermissionKind.calendar,
    // Call-screening role (v1.2 wiring — was `null` in v1.1f).
    TriggerCallIncoming() => PermissionKind.callScreening,
    // Foreground-app trigger (v1.2 addition — gated by
    // `PACKAGE_USAGE_STATS`).
    TriggerForegroundApp() => PermissionKind.usageStats,
    // Device-state probes read public broadcasts; no runtime
    // permission gates them.
    TriggerDeviceState() => null,
    // Time-of-day alarms gate on the app-wide `Reliability`
    // enum (exact-alarm + Doze); the per-automation function
    // cannot see that here, so we report `optimal` and the
    // badge consumer falls back to the home banner.
    TriggerTimeOfDay() => null,
  };
}

/// True when a [PermissionResult] reports a currently-granted
/// state. `PermissionResultDenied` (the user can still be
/// re-asked) and `PermissionResultPermanentlyDenied` (the
/// user said "Don't ask again", or the OS policy requires an
/// out-of-app grant) both mean "this won't fire without a
/// system-settings trip", which the badge treats as
/// `degraded`.
bool _isGranted(PermissionResult result) {
  return switch (result) {
    PermissionResultGranted() => true,
    PermissionResultDenied() => false,
    PermissionResultPermanentlyDenied() => false,
  };
}

/// Map an [Action] leaf to the runtime permissions it needs.
/// Returns an empty list when no runtime permission gates
/// the action (e.g. `ActionNotify`, `ActionOpenApp`).
///
/// Exhaustive over the sealed [Action] hierarchy — adding a
/// new action leaf without updating this switch is a
/// compile-time error. The dialog renders one
/// `_KindSection` per non-null entry; when the list has more
/// than one entry (e.g., a future `ActionCallIntercept` that
/// also reads contacts), the dialog stacks them.
List<PermissionKind> _requiredPermissionsForAction(Action action) {
  return switch (action) {
    // Show a local notification. No runtime gate beyond
    // the global `POST_NOTIFICATIONS` grant (covered by the
    // trigger-side path's `notifications` permission status).
    ActionNotify() => const <PermissionKind>[],
    // Wake the screen with the full-screen-intent activity.
    // v1.5b / Phase 25: mirrors the v1.3c probe — on API 34+
    // the OS suppresses full-screen launches from background
    // apps without `USE_FULL_SCREEN_INTENT`.
    ActionFullscreen() => const <PermissionKind>[
      PermissionKind.fullScreenIntent,
    ],
    // Answer / dismiss an incoming call. v1.5b: reuses the
    // trigger-side `callScreening` role check.
    ActionCallIntercept() => const <PermissionKind>[
      PermissionKind.callScreening,
    ],
    // Toggle the device's silent mode. v1.5b: Android M+
    // requires `ACCESS_NOTIFICATION_POLICY` for any app
    // that toggles DND; the kind is opt-in.
    ActionOverrideSilent() => const <PermissionKind>[
      PermissionKind.notificationPolicy,
    ],
    // Open a route in the app. No runtime gate.
    ActionOpenApp() => const <PermissionKind>[],
  };
}
