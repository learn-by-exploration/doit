// Permission service — the single seam between the widget
// layer and `permission_handler` ^11.3.1 + `file_picker`
// ^8.1.2.
//
// Per .claude/rules/lib-screens.md: "No platform calls in
// widgets." The v0.1 onboarding screen was shipped as a
// visual walkthrough; v0.5 (ADR-016) wires the four runtime
// permission requests to this service. The service is also
// the seam the Settings → Permissions tile (v0.5d) reads
// from to render "Granted" / "Not granted" status text and
// the deep-link to the Android system settings.
//
// v0.6 (ADR-018) adds:
//   - The `batteryOptimization` kind (SYS-068) — the
//     whitelist probe + the per-kind deep-link to
//     `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
//   - The on-demand `ensure(kind)` helper that the
//     [PermissionSheet] widget uses to short-circuit when the
//     permission is already granted.
//
// Layer rules (per .claude/rules/lib-services.md):
// - Singleton with `Completer<void> _ready`.
// - `init()` is idempotent.
// - All public methods are async.
//
// The service depends on `package:permission_handler` (for
// `Permission.notification`, `Permission.contacts`,
// `Permission.scheduleExactAlarm`,
// `Permission.ignoreBatteryOptimizations`) and
// `package:file_picker` (for `FilePicker.platform.getDirectoryPath`
// which uses `ACTION_OPEN_DOCUMENT_TREE` on Android). It
// returns a sealed [PermissionResult] / [BackupFolderResult]
// so the widget layer never sees `PermissionStatus` directly.

import 'dart:async' show Completer, unawaited;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:meta/meta.dart';
import 'package:permission_handler/permission_handler.dart';
// `permission_handler` re-exports `Permission`,
// `PermissionStatus`, etc. but NOT the
// `PermissionHandlerPlatform` interface. The platform
// interface is the only public way to reach the underlying
// `openAppSettings` MethodChannel from a non-widget caller
// (the top-level `openAppSettings()` from `permission_handler`
// is shadowed by this service's own `openAppSettings`
// method, so we cannot call it from inside the class body
// without a rename hack).
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

import 'package:doit/services/call_interceptor.dart';
import 'package:doit/services/full_screen_intent_service.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/usage_stats_service.dart';

/// Identifiers for the runtime permissions / pickers the
/// service manages. Used as keys in [PermissionService.statuses]
/// and as the dispatch key in tests. Mirrors the
/// onboarding-screen step order in
/// [lib/screens/onboarding.dart]: notifications, contacts,
/// exact alarms, backup folder, plus the v0.6
/// battery-optimization kind surfaced in the Settings →
/// Permissions tile (SYS-068).
enum PermissionKind {
  /// `POST_NOTIFICATIONS`. SYS-063.
  notifications,

  /// `READ_CONTACTS`. SYS-064.
  contacts,

  /// `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`. SYS-065.
  exactAlarm,

  /// The SAF folder picker. SYS-066. The runtime status
  /// is `null` (the picker is not a permission; the picked
  /// path lives in `SettingsService.backupFolderUri`).
  backupFolder,

  /// `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (the whitelist
  /// probe, not a runtime grant). SYS-068 / v0.6 (ADR-018).
  /// On Android the system Settings surface is the only
  /// place the user can toggle this; the deep-link target
  /// is `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`,
  /// routed through [ReminderBridge.openIgnoreBatteryOptimizations]
  /// on the Kotlin side.
  batteryOptimization,

  /// `ACCESS_COARSE_LOCATION` (v1.0 / Phase C PR 2 / ADR-021 /
  /// SYS-076). Used by `GeofenceService` to subscribe to the
  /// device position stream and match against registered
  /// `TriggerLocation` circles. Coarse (city-block accuracy)
  /// is sufficient for geofence radius ≥ 50m; fine location
  /// stays out of scope per the v0.1 carve-out (see
  /// `docs/v_model/architecture_options.md`).
  location,

  /// `READ_CALENDAR` (v1.0 / Phase E PR 1 / ADR-023 / SYS-078).
  /// Used by `CalendarService` to read the user's calendar
  /// accounts (for the on-demand account picker) and watch
  /// event transitions for `TriggerCalendarEvent` matching.
  /// Read-only; we never write to the calendar. Event
  /// metadata (id, title, calendar id, time) is the only
  /// data the app reads; no event bodies, attendees, or
  /// notes are stored or transmitted.
  calendar,

  /// `PACKAGE_USAGE_STATS` (v1.1g / ADR-030 / SYS-086). A
  /// special-access permission: Android never shows a runtime
  /// prompt for it; the user MUST navigate to Settings →
  /// Special access → Usage access and toggle do it on
  /// manually. Used in v1.2 by the planned
  /// `TriggerForegroundApp` (a device-state leaf that fires
  /// when the user opens a configured app — e.g., "Open
  /// Instagram → mute ringer for 10 minutes"). v1.1g ships
  /// the rationale UX, the settings tile, and the probe;
  /// v1.2 will wire the trigger itself. The
  /// `canOpenSettings` payload on the sealed result is
  /// always `true` because the deep-link target is well-
  /// defined (`Settings.ACTION_USAGE_ACCESS_SETTINGS`).
  usageStats,

  /// `ROLE_CALL_SCREENING` (v1.2 / SYS-075 + SYS-079 follow-up).
  /// Not a runtime permission in the `permission_handler`
  /// sense — it is a system role held via
  /// `RoleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)`.
  /// The probe goes through
  /// `CallInterceptorService.isCallScreeningRoleHeld` →
  /// Kotlin `doit/call_interceptor.isCallScreeningRoleHeld`
  /// (a `RoleManager.createCallScreeningRole` check).
  /// The reliability badge for `TriggerCallIncoming*`
  /// leaves reads this kind's status (the v1.1f badge
  /// deferred this check to v1.2 with the note "fold in
  /// `PermissionKind.callScreening` once the role is wired
  /// through `PermissionService`"). The `canOpenSettings`
  /// payload is `true` because the deep-link target is
  /// `RoleManager.createRequestRoleIntent` (the OS shows
  /// its own dialog; no app-side Settings path is needed).
  callScreening,

  /// `USE_FULL_SCREEN_INTENT` (v1.3c / Phase 14 / SYS-113
  /// / ADR-043). On Android 14+ (API 34) the OS suppresses
  /// full-screen intents from background-launched apps
  /// that do not hold this permission — the strong-mode
  /// full-screen mission UI fails open to a notification
  /// instead. The probe goes through
  /// `FullScreenIntentService.isGranted` → Kotlin
  /// `doit/full_screen.canUseFullScreenIntent` (an
  /// `NotificationManager.canUseFullScreenIntent()` call
  /// on API 32+; implicit-`true` on API < 32 because the
  /// permission did not exist). The deep-link target is
  /// `Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`
  /// on API 34+ and falls back to
  /// `Settings.ACTION_APPLICATION_SETTINGS` on API 32/33
  /// (where the FSI-specific activity does not exist).
  /// Android never shows a runtime prompt for this; the
  /// user MUST navigate to Settings → Special access.
  /// `canOpenSettings` is hard-coded `true` because the
  /// deep-link target is well-defined on every supported
  /// API. The kind is in the
  /// `ReliabilityService._kReliabilityGatedKinds` set so
  /// the home-screen reliability banner flips to
  /// "may be late" on a denial (matches the v1.1g /
  /// `PACKAGE_USAGE_STATS` opt-in precedent).
  fullScreenIntent,
}

/// Singleton holder for the permission / SAF seam. The
/// public methods ([requestNotifications], [requestContacts],
/// [requestExactAlarm], [requestBackupFolder],
/// [openAppSettings]) all `await ready` before touching the
/// underlying plugins.
class PermissionService {
  PermissionService._();

  /// The single global instance.
  static final PermissionService instance = PermissionService._();

  /// Init gate (`Completer<void> _ready`). Public reads wait
  /// on this before touching the underlying plugins. The
  /// pattern matches `lib-services.md` § Singleton lifecycle.
  Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  /// Current status of the runtime permissions
  /// (notifications, contacts, exact alarms, battery
  /// optimization). Populated by [init] and refreshed by
  /// every `requestX` call. The `backupFolder` entry is
  /// always `null` — the SAF picker is not a permission;
  /// the picked path lives in
  /// `SettingsService.backupFolderUri`.
  ///
  /// The Settings → Permissions tile (v0.5d) binds to this
  /// via `ValueListenableBuilder` so changes propagate
  /// without a full Provider rebuild.
  final ValueNotifier<Map<PermissionKind, PermissionResult?>> statuses =
      ValueNotifier<Map<PermissionKind, PermissionResult?>>({
        PermissionKind.notifications: const PermissionResultDenied(
          canOpenSettings: true,
        ),
        PermissionKind.contacts: const PermissionResultDenied(
          canOpenSettings: true,
        ),
        PermissionKind.exactAlarm: const PermissionResultDenied(
          canOpenSettings: true,
        ),
        PermissionKind.backupFolder: null,
        PermissionKind.batteryOptimization: const PermissionResultDenied(
          canOpenSettings: true,
        ),
        PermissionKind.location: const PermissionResultDenied(
          canOpenSettings: true,
        ),
        PermissionKind.calendar: const PermissionResultDenied(
          canOpenSettings: true,
        ),
        PermissionKind.usageStats: const PermissionResultDenied(
          canOpenSettings: true,
        ),
        PermissionKind.callScreening: const PermissionResultDenied(
          canOpenSettings: true,
        ),
        // v1.3c / Phase 14 / SYS-113: opt-in special-access
        // permission (Android never shows a runtime prompt
        // for it). Declared with `tools:ignore="ProtectedPermissions"`
        // in the manifest — the user is never blocked from
        // using do it for declining.
        PermissionKind.fullScreenIntent: const PermissionResultDenied(
          canOpenSettings: true,
        ),
      });

  /// Idempotent. Probes the runtime permissions and stores
  /// the mapped [PermissionResult] in [statuses]. A
  /// platform-channel error (missing plugin, restricted
  /// device, etc.) is swallowed — the v0.4b-release-fix
  /// lesson is that `main()` must not crash if a plugin is
  /// absent. The service is left in a state where the
  /// default `denied(canOpenSettings: true)` is reported.
  Future<void> init() async {
    if (_ready.isCompleted) return;
    final next = <PermissionKind, PermissionResult?>{
      PermissionKind.notifications: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.contacts: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.exactAlarm: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.backupFolder: null,
      PermissionKind.batteryOptimization: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.location: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.calendar: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.usageStats: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.callScreening: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.fullScreenIntent: const PermissionResultDenied(
        canOpenSettings: true,
      ),
    };
    try {
      next[PermissionKind.notifications] = _mapStatus(
        await Permission.notification.status,
      );
      next[PermissionKind.contacts] = _mapStatus(
        await Permission.contacts.status,
      );
      next[PermissionKind.exactAlarm] = _mapStatus(
        await Permission.scheduleExactAlarm.status,
      );
      next[PermissionKind.batteryOptimization] = _mapStatus(
        await Permission.ignoreBatteryOptimizations.status,
      );
      next[PermissionKind.location] = _mapStatus(
        await Permission.location.status,
      );
      next[PermissionKind.calendar] = _mapStatus(
        await Permission.calendarFullAccess.status,
      );
      // Usage stats is a special-access permission; the
      // `permission_handler` plugin does not expose it. The
      // probe goes through `UsageStatsService` → Kotlin
      // `DeviceStateChannel.isUsageStatsGranted`. We do NOT
      // await it here: `MethodChannel.invokeMethod` returns
      // a real Future that does NOT advance in a widget
      // test's fake-async zone, which would hang `init()`
      // for every test that calls `PermissionService.init()`
      // at the top of a `testWidgets` block. Instead we
      // fire-and-forget the probe so it completes
      // asynchronously on the real-async microtask queue;
      // when it resolves, [refreshUsageStats] merges the
      // result into [statuses] (the Settings tile rebuilds
      // from the ValueNotifier).
      unawaited(_refreshUsageStatsAfterInit());
      // v1.2 follow-up to v1.0/Phase F PR 2 (SYS-075 /
      // SYS-079): `ROLE_CALL_SCREENING` is a system role,
      // not a `permission_handler` permission. The probe
      // goes through `CallInterceptorService
      // .isCallScreeningRoleHeld` → Kotlin
      // `doit/call_interceptor.isCallScreeningRoleHeld`
      // (a `RoleManager.createCallScreeningRole` check).
      // Same fire-and-forget rationale as
      // `usageStats` above.
      unawaited(_refreshCallScreeningAfterInit());
      // v1.3c / Phase 14 / SYS-113 / ADR-043:
      // `USE_FULL_SCREEN_INTENT` is a special-access
      // permission; the `permission_handler` plugin does
      // not expose it. The probe goes through
      // `FullScreenIntentService.isGranted` → Kotlin
      // `doit/full_screen.canUseFullScreenIntent` (a
      // `NotificationManager.canUseFullScreenIntent()` call
      // on API 32+). Same fire-and-forget rationale as
      // the two special-access kinds above.
      unawaited(_refreshFullScreenIntentAfterInit());
    } catch (_) {
      // v0.4b-release-fix / ADR-013 follow-up: a thrown
      // platform-channel error must not crash `main()`. The
      // service still completes `_ready` so the rest of the
      // app proceeds; the statuses remain the default
      // `denied(canOpenSettings: true)` so the Settings →
      // Permissions tile can render a "try again" affordance.
    }
    statuses.value = next;
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Request `POST_NOTIFICATIONS` (Android 13+). On
  /// Android < 13 the runtime grant is automatic and this
  /// returns [PermissionResultGranted] without a system
  /// dialog.
  Future<PermissionResult> requestNotifications() async {
    await ready;
    final raw = await Permission.notification.request();
    return _recordAndReturn(PermissionKind.notifications, raw);
  }

  /// Request `READ_CONTACTS`. Returns
  /// [PermissionResultPermanentlyDenied] on the second
  /// denial (Android 11+ semantics) and
  /// [PermissionResultDenied] on the first.
  Future<PermissionResult> requestContacts() async {
    await ready;
    final raw = await Permission.contacts.request();
    return _recordAndReturn(PermissionKind.contacts, raw);
  }

  /// Request `SCHEDULE_EXACT_ALARM` /
  /// `USE_EXACT_ALARM`. On Android 12+ this is a policy
  /// permission — the system "Allow" dialog does not
  /// appear; the user grants the policy in
  /// Settings → Apps → Special access → Alarms &
  /// reminders. The runtime call returns
  /// [PermissionStatus.denied] until the user has granted
  /// the policy, in which case it returns
  /// [PermissionStatus.granted]. The widget layer surfaces
  /// the deep-link as the primary affordance on `denied`.
  Future<PermissionResult> requestExactAlarm() async {
    await ready;
    final raw = await Permission.scheduleExactAlarm.request();
    return _recordAndReturn(PermissionKind.exactAlarm, raw);
  }

  /// Probe whether the app is whitelisted from battery
  /// optimizations
  /// (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`). The system
  /// Settings surface is the only place the user can toggle
  /// this; the deep-link target
  /// (`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) is
  /// routed through [ReminderBridge.openIgnoreBatteryOptimizations]
  /// on the Kotlin side. SYS-068 / v0.6 (ADR-018).
  ///
  /// Unlike the other `requestX` methods, this call does
  /// not show a system dialog. `permission_handler` returns
  /// `granted` if the app is whitelisted, `denied`
  /// otherwise. The widget layer is expected to surface
  /// the deep-link as the only recovery affordance.
  Future<PermissionResult> requestIgnoreBatteryOptimizations() async {
    await ready;
    final raw = await Permission.ignoreBatteryOptimizations.request();
    return _recordAndReturn(PermissionKind.batteryOptimization, raw);
  }

  /// Request `ACCESS_COARSE_LOCATION` (v1.0 / Phase C PR 2 /
  /// ADR-021 / SYS-076). Used by `GeofenceService` to start
  /// the position stream that drives `TriggerLocationEnter`
  /// and `TriggerLocationExit`. On Android 10+ the user can
  /// downgrade to "approximate" (still granted at coarse
  /// level); on older versions the single runtime prompt
  /// covers both. The widget layer is expected to surface
  /// the deep-link as the recovery affordance on
  /// permanently-denied.
  Future<PermissionResult> requestLocation() async {
    await ready;
    final raw = await Permission.location.request();
    return _recordAndReturn(PermissionKind.location, raw);
  }

  /// Request `READ_CALENDAR` (v1.0 / Phase E PR 1 / ADR-023
  /// / SYS-078). Used by `CalendarService` to read the
  /// user's installed calendar accounts (for the on-demand
  /// account picker) and watch event transitions for
  /// `TriggerCalendarEvent` matching. Read-only; we never
  /// write to the calendar. The widget layer surfaces the
  /// rationale ("used to trigger routines when meetings
  /// start / end / hit their reminder time, or when your
  /// free/busy status changes") in the Settings → Permissions
  /// tile and the on-demand permission sheet.
  Future<PermissionResult> requestCalendar() async {
    await ready;
    final raw = await Permission.calendarFullAccess.request();
    return _recordAndReturn(PermissionKind.calendar, raw);
  }

  /// On-demand check used by [PermissionSheet.show]. Returns
  /// the cached [PermissionResult] for [kind] without
  /// re-prompting the user. The result drives the
  /// short-circuit logic in the sheet — if the permission
  /// is already `granted`, the sheet is not shown at all.
  Future<PermissionResult> ensure(PermissionKind kind) async {
    await ready;
    final cached = statuses.value[kind];
    if (cached != null) return cached;
    // SAF picker case (SYS-066): the picker is not a
    // permission; return a synthetic `granted` so the
    // feature-consumption site can proceed.
    return const PermissionResultGranted();
  }

  /// Open the Android SAF folder picker
  /// (`ACTION_OPEN_DOCUMENT_TREE`). Returns
  /// [BackupFolderPicked] with the SAF tree URI on
  /// success, [BackupFolderCancelled] on user cancel, and
  /// [BackupFolderError] on a thrown exception. The widget
  /// layer is responsible for persisting [BackupFolderPicked.path]
  /// to `SettingsService.backupFolderUri`.
  Future<BackupFolderResult> requestBackupFolder() async {
    await ready;
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null) {
        return const BackupFolderCancelled();
      }
      return BackupFolderPicked(path);
    } catch (e) {
      return BackupFolderError(e.toString());
    }
  }

  /// Open the app's settings page (deep-link to Android
  /// system settings). Returns `true` if the page could be
  /// opened, `false` otherwise. The widget layer uses this
  /// as the recovery affordance for
  /// [PermissionResultPermanentlyDenied] and for
  /// [PermissionResultDenied] where `canOpenSettings` is
  /// `true`.
  Future<bool> openAppSettings() async {
    await ready;
    // The top-level `openAppSettings` from
    // `package:permission_handler` is a thin wrapper over
    // this same call; we go to the platform interface
    // directly to avoid an import-name shadow with this
    // method.
    return PermissionHandlerPlatform.instance.openAppSettings();
  }

  /// Deep-links the user to Settings → Special access →
  /// Usage access so they can toggle `PACKAGE_USAGE_STATS`
  /// on. v1.1g / ADR-030 / SYS-086. Returns `true` if the
  /// OEM Settings activity resolved the intent.
  ///
  /// Unlike the other `requestX` methods, this does NOT
  /// re-probe immediately: the user has to navigate the
  /// system Settings page, toggle do it on, and come back.
  /// The widget that called this method should re-probe
  /// via [PermissionService.instance.init] when the app
  /// resumes (e.g., `WidgetsBindingObserver.didChangeAppLifecycleState`
  /// → `resumed`).
  Future<bool> requestUsageStats() async {
    await ready;
    return UsageStatsService.instance.openSettings();
  }

  /// Re-probes the `PACKAGE_USAGE_STATS` permission. Used
  /// by the app-resume handler so the Settings → Triggers
  /// tile and the `AutomationReliabilityBadge` reflect the
  /// user's most recent toggle without a full restart.
  Future<void> refreshUsageStats() async {
    await ready;
    final granted = await UsageStatsService.instance.isGranted();
    final next = <PermissionKind, PermissionResult?>{
      ...statuses.value,
      PermissionKind.usageStats: granted
          ? const PermissionResultGranted()
          : const PermissionResultDenied(canOpenSettings: true),
    };
    statuses.value = next;
  }

  /// v1.2 / SYS-075 + SYS-079 follow-up. Fires the OS role
  /// request flow for `ROLE_CALL_SCREENING`. The OS dialog
  /// is asynchronous (the user has to navigate the role
  /// picker); callers re-probe via [refreshCallScreening]
  /// when the app resumes. Returns `true` if the role was
  /// already held, or the user just granted it; `false`
  /// otherwise (declined dialog, role unavailable on this
  /// device, missing plugin).
  Future<bool> requestCallScreening() async {
    await ready;
    return CallInterceptorService.instance.requestCallScreeningRole();
  }

  /// v1.2 / SYS-075 + SYS-079 follow-up. Re-probes
  /// `ROLE_CALL_SCREENING`. Used by the app-resume handler
  /// so the per-automation reliability badge for
  /// `TriggerCallIncoming*` leaves reflects the user's
  /// most recent toggle without a full restart.
  Future<void> refreshCallScreening() async {
    await ready;
    final granted = await CallInterceptorService.instance
        .isCallScreeningRoleHeld();
    final next = <PermissionKind, PermissionResult?>{
      ...statuses.value,
      PermissionKind.callScreening: granted
          ? const PermissionResultGranted()
          : const PermissionResultDenied(canOpenSettings: true),
    };
    statuses.value = next;
  }

  /// v1.3c / Phase 14 / SYS-113 / ADR-043. Deep-links the
  /// user to the system Settings surface for
  /// `USE_FULL_SCREEN_INTENT` (Settings →
  /// `ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT` on API 34+,
  /// `ACTION_APPLICATION_SETTINGS` fallback on API 32/33).
  /// Unlike the other `requestX` methods, this does NOT
  /// re-probe immediately: the user has to navigate the
  /// system Settings page, toggle do it on, and come back.
  /// The widget that called this method should re-probe via
  /// [PermissionService.instance.init] or [refresh] when the
  /// app resumes (e.g., the `PermissionLifecycleReProbe`
  /// `WidgetsBindingObserver.didChangeAppLifecycleState` →
  /// `resumed` hook).
  Future<bool> requestFullScreenIntent() async {
    await ready;
    return FullScreenIntentService.instance.openSettings();
  }

  /// v1.3c / Phase 14 / SYS-113 / ADR-043. Re-probes
  /// `USE_FULL_SCREEN_INTENT`. Used by the app-resume
  /// handler so the Settings → Permissions tile and the
  /// `ReliabilityBanner` reflect the user's most recent
  /// toggle without a full restart. A denial flips the
  /// banner to `Reliability.degraded` because
  /// `fullScreenIntent` is in the
  /// `ReliabilityService._kReliabilityGatedKinds` set.
  Future<void> refreshFullScreenIntent() async {
    await ready;
    final granted = await FullScreenIntentService.instance.isGranted();
    final next = <PermissionKind, PermissionResult?>{
      ...statuses.value,
      PermissionKind.fullScreenIntent: granted
          ? const PermissionResultGranted()
          : const PermissionResultDenied(canOpenSettings: true),
    };
    statuses.value = next;
  }

  /// v1.2i / Phase 9: re-probes every permission the
  /// service knows about. Called from the
  /// `WidgetsBindingObserver` `resumed` hook in `main.dart`
  /// so the Settings → Permissions tile and the per-
  /// automation reliability badges reflect the user's most
  /// recent toggle without a full restart.
  ///
  /// ADR-030's lesson: the fire-and-forget probe from
  /// `init()` is stale by the time the user comes back from
  /// toggling a permission in Settings → Special access →
  /// Usage access (the most common flow that needs a
  /// re-probe). The `resumed` hook is the cheapest signal
  /// that the user came back to the app, and a single
  /// re-probe is cheap.
  ///
  /// Parallelism note: each `Permission.X.status` call is
  /// an independent platform-channel round-trip, so we
  /// `Future.wait` over all six `permission_handler` kinds.
  /// The two special-access kinds (`usageStats`,
  /// `callScreening`) are sequenced AFTER the batch because
  /// their `refreshX` methods are not idempotent with the
  /// batch in the existing test mocks (they go through
  /// separate channels and have their own swallow paths).
  ///
  /// A thrown platform-channel error from any single probe
  /// is swallowed at the call site (`_safeProbe`) so a
  /// missing plugin on one kind does NOT abort the others
  /// (ADR-013 follow-up).
  Future<void> refresh() async {
    await ready;
    try {
      final results = await Future.wait<_ProbeOutcome>([
        _safeProbe(
          PermissionKind.notifications,
          Permission.notification.status,
        ),
        _safeProbe(PermissionKind.contacts, Permission.contacts.status),
        _safeProbe(
          PermissionKind.exactAlarm,
          Permission.scheduleExactAlarm.status,
        ),
        _safeProbe(
          PermissionKind.batteryOptimization,
          Permission.ignoreBatteryOptimizations.status,
        ),
        _safeProbe(PermissionKind.location, Permission.location.status),
        _safeProbe(
          PermissionKind.calendar,
          Permission.calendarFullAccess.status,
        ),
      ]);
      final next = Map<PermissionKind, PermissionResult?>.from(statuses.value);
      for (final outcome in results) {
        next[outcome.kind] = outcome.result;
      }
      statuses.value = next;
    } catch (_) {
      // Defense in depth: a throw from `Future.wait` itself
      // (rather than from a single probe — `_safeProbe`
      // already swallows per-probe) is treated as a
      // best-effort no-op. The user can still re-open
      // Settings → Permissions to retry the probe.
    }
    // The two special-access kinds are re-probed
    // independently so a stale role / usage grant
    // refreshes too. Each `refreshX` method swallows its
    // own platform-channel error.
    try {
      await refreshUsageStats();
    } catch (_) {
      /* ADR-013 */
    }
    try {
      await refreshCallScreening();
    } catch (_) {
      /* ADR-013 */
    }
    // v1.3c / Phase 14 / SYS-113 / ADR-043: the third
    // special-access kind — `USE_FULL_SCREEN_INTENT` —
    // joins the sequential bucket. Same swallow pattern.
    try {
      await refreshFullScreenIntent();
    } catch (_) {
      /* ADR-013 */
    }
  }

  /// Probe helper for [init]. Called after `_ready` is
  /// completed so the result merges into [statuses] via
  /// [refreshUsageStats]'s `ValueNotifier` write. Returns
  /// a `Future` but is `unawaited` by the caller (init must
  /// not block on the platform-channel round-trip — see
  /// the inline comment at the call site).
  Future<void> _refreshUsageStatsAfterInit() async {
    await ready;
    // Swallow the platform-channel error here too — the
    // missing-plugin path (test, iOS, desktop) leaves the
    // status at the `denied(canOpenSettings: true)`
    // default set in [init].
    try {
      await refreshUsageStats();
    } catch (_) {
      // v0.4b-release-fix / ADR-013 follow-up: never let a
      // platform-channel error crash the post-init probe.
    }
  }

  /// Probe helper for [init] (v1.2 / SYS-075 follow-up).
  /// Same fire-and-forget rationale as
  /// `_refreshUsageStatsAfterInit` above.
  Future<void> _refreshCallScreeningAfterInit() async {
    await ready;
    try {
      await refreshCallScreening();
    } catch (_) {
      // v0.4b-release-fix / ADR-013 follow-up: never let a
      // platform-channel error crash the post-init probe.
    }
  }

  /// v1.3c / Phase 14 / SYS-113 / ADR-043. Same
  /// fire-and-forget rationale as the other
  /// special-access `*AfterInit` helpers above. Runs the
  /// `FullScreenIntentService.isGranted` probe against
  /// the Kotlin `doit/full_screen` channel.
  Future<void> _refreshFullScreenIntentAfterInit() async {
    await ready;
    try {
      await refreshFullScreenIntent();
    } catch (_) {
      // v0.4b-release-fix / ADR-013 follow-up: never let a
      // platform-channel error crash the post-init probe.
    }
  }

  /// v1.2i / Phase 9 helper. Runs one `permission_handler`
  /// probe and maps the result. Swallows any thrown
  /// platform-channel error (ADR-013 follow-up) so a
  /// missing plugin on one kind does NOT abort the batch
  /// in [refresh].
  Future<_ProbeOutcome> _safeProbe(
    PermissionKind kind,
    Future<PermissionStatus> probe,
  ) async {
    try {
      final result = _mapStatus(await probe);
      return _ProbeOutcome(kind, result);
    } catch (_) {
      // Swallow per-probe; the corresponding key in
      // `statuses` keeps its prior value (a failed
      // re-probe is NOT a downgrade).
      return _ProbeOutcome(kind, statuses.value[kind]);
    }
  }

  // --- internal ----------------------------------------------------

  /// Maps a [PermissionStatus] to the sealed
  /// [PermissionResult] the widget layer sees. See
  /// `lib/services/permission_result.dart` for the fold
  /// rules.
  @visibleForTesting
  static PermissionResult mapStatus(PermissionStatus s) => _mapStatus(s);

  static PermissionResult _mapStatus(PermissionStatus s) {
    switch (s) {
      case PermissionStatus.granted:
        return const PermissionResultGranted();
      case PermissionStatus.denied:
        // One-shot denial — the user can be re-asked.
        return const PermissionResultDenied(canOpenSettings: true);
      case PermissionStatus.permanentlyDenied:
        return const PermissionResultPermanentlyDenied();
      case PermissionStatus.restricted:
        // iOS only (parental controls, etc.). The user
        // cannot recover from inside the app. The deep-link
        // would not help, so the widget hides it.
        return const PermissionResultDenied(canOpenSettings: false);
      case PermissionStatus.limited:
        // Partial access; the user can be re-asked for full.
        return const PermissionResultDenied(canOpenSettings: true);
      case PermissionStatus.provisional:
        // iOS only; treat as granted for our use case
        // (do it does not need full notification access).
        return const PermissionResultGranted();
    }
  }

  /// Records the mapped result into [statuses] and returns
  /// it. The record is what the v0.5d Settings → Permissions
  /// tile reads; the return value is what the v0.5c
  /// onboarding CTA dispatches on.
  PermissionResult _recordAndReturn(PermissionKind kind, PermissionStatus raw) {
    final mapped = _mapStatus(raw);
    final next = Map<PermissionKind, PermissionResult?>.from(statuses.value);
    next[kind] = mapped;
    statuses.value = next;
    return mapped;
  }

  /// Test helper. Resets the singleton's in-memory state
  /// (the `_ready` gate, the [statuses] map) so the next
  /// [init] re-probes. The platform plugin is not touched
  /// — tests that want to script platform responses use
  /// `TestDefaultBinaryMessengerBinding.setMockMethodCallHandler`
  /// on the `flutter.baseflow.com/permissions/methods`
  /// channel.
  // ignore: use_setters_to_change_properties
  void resetForTesting() {
    _ready = Completer<void>();
    statuses.value = {
      PermissionKind.notifications: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.contacts: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.exactAlarm: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.backupFolder: null,
      PermissionKind.batteryOptimization: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.location: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.calendar: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.usageStats: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.callScreening: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.fullScreenIntent: const PermissionResultDenied(
        canOpenSettings: true,
      ),
    };
  }
}

/// v1.2i / Phase 9: a single probe outcome from the
/// parallel batch in [PermissionService.refresh]. Carries
/// the kind so the caller can write the right key into the
/// `statuses` map. The `result` is `null` only for the
/// SAF-picker kind (today the batch does not include
/// `backupFolder` because it is not a permission); kept
/// nullable for forward-compatibility.
class _ProbeOutcome {
  const _ProbeOutcome(this.kind, this.result);
  final PermissionKind kind;
  final PermissionResult? result;
}

// (No top-level helper needed; the platform-interface call
// inside `openAppSettings()` above is the single source of
// truth for the deep-link.)
