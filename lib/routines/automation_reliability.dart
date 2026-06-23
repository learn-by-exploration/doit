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
///   - All `Action` leaves → no additional runtime gate at
///     v1.1f (action-side roles — call-screening, contacts —
///     are already covered by the trigger-side checks). A
///     future v1.2+ extension will fold in `ActionOverrideSilent`
///     (`ACCESS_NOTIFICATION_POLICY`) and the contact-requiring
///     actions.
AutomationReliability automationReliability(
  Automation automation, {
  required Map<PermissionKind, PermissionResult?> statuses,
}) {
  // Trigger-side check.
  final triggerKind = _requiredPermissionForTrigger(automation.trigger);
  if (triggerKind != null) {
    final status = statuses[triggerKind];
    if (status == null) return AutomationReliability.unknown;
    if (!_isGranted(status)) return AutomationReliability.degraded;
  }
  // Action-side check (no leaves gate a permission in v1.1f;
  // reserved for v1.2+).
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

// Suppress the unused-import warning for `action.dart`. The
// import is intentional: this file's exhaustive switch is
// the canonical reference for "which leaves gate a
// permission", and `action.dart` is part of that contract
// even though v1.1f does not yet add a case for any action
// leaf.
// ignore: unused_element
const Object _actionGuard = ActionNotify;
