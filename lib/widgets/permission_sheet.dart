// PermissionSheet — on-demand modal bottom sheet that
// requests a runtime permission at the moment a feature
// needs it.
//
// v0.6 / ADR-018 / SYS-067. The pattern replaces the
// v0.5d "ask once at onboarding" with a "ask on demand"
// gate. Every feature that requires a runtime permission
// (`READ_CONTACTS` for the contact picker, `SCHEDULE_EXACT_ALARM`
// for fixed-time reminders, `POST_NOTIFICATIONS` for the
// "send test reminder" button) MUST call
// `PermissionSheet.show(context, kind)` before invoking the
// feature. The sheet:
//
//   1. Short-circuits when the permission is already
//      `granted` (no UI is shown).
//   2. On `denied` (one-shot) shows the rationale + an
//      "Allow" CTA that calls the relevant
//      `PermissionService.requestX()`.
//   3. On `permanentlyDenied` shows the rationale + an
//      "Open settings" CTA that deep-links to the
//      permission-specific system Settings page (the
//      battery-opt case uses
//      `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`; the
//      others fall back to the app's generic Settings page).
//   4. Returns `true` if the user granted the permission
//      by the time the sheet closes; `false` otherwise.
//
// The widget layer imports this file and
// `permission_service.dart` and pattern-matches on the
// sealed `PermissionResult`; `permission_handler`'s
// `PermissionStatus` enum never reaches the widget tree
// (ADR-016).

import 'package:flutter/material.dart';

import 'package:doit/services/permission_kind_meta.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/theme/app_theme.dart';

/// Per-kind metadata. Title and rationale live in
/// `permission_kind_meta.dart` so the
/// `AutomationReliabilityBadge` dialog (v1.2h) can reuse the
/// same copy.

/// Public surface. Returns `true` when the permission is
/// granted by the time the sheet closes (either because it
/// was already granted, the user tapped Allow, or the user
/// navigated to system Settings and came back with it
/// granted). Returns `false` on `denied`, `permanentlyDenied`
/// where the deep-link was not followed, or after the user
/// dismissed the sheet.
///
/// The [bridge] parameter is required for the
/// `batteryOptimization` deep-link (the Kotlin side handles
/// `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`); the other
/// kinds ignore it.
class PermissionSheet {
  const PermissionSheet._();

  /// Show the on-demand permission sheet for [kind]. Returns
  /// `true` if the user grants the permission (or it was
  /// already granted); `false` otherwise.
  ///
  /// The optional [bridge] is required only when [kind] is
  /// [PermissionKind.batteryOptimization]; it must be the
  /// live `ReminderBridge` so the deep-link can be routed to
  /// the Kotlin side. Other kinds ignore it.
  static Future<bool> show(
    BuildContext context,
    PermissionKind kind, {
    Object? bridge,
  }) async {
    final PermissionService svc = PermissionService.instance;
    // Short-circuit when the permission is already granted.
    // The `ensure` helper returns the cached status without
    // re-prompting (ADR-016 "on-demand probe, no auto-request
    // at app boot").
    final cached = await svc.ensure(kind);
    if (cached is PermissionResultGranted) return true;
    if (!context.mounted) return false;

    final result = await showModalBottomSheet<_PermissionSheetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _PermissionSheetBody(kind: kind, bridge: bridge, initial: cached),
    );
    // `null` means the user dismissed without acting.
    return result?.granted ?? false;
  }
}

class _PermissionSheetResult {
  const _PermissionSheetResult({required this.granted});
  final bool granted;
}

class _PermissionSheetBody extends StatefulWidget {
  const _PermissionSheetBody({
    required this.kind,
    required this.bridge,
    required this.initial,
  });

  final PermissionKind kind;
  final Object? bridge;
  final PermissionResult initial;

  @override
  State<_PermissionSheetBody> createState() => _PermissionSheetBodyState();
}

class _PermissionSheetBodyState extends State<_PermissionSheetBody> {
  late PermissionResult _status = widget.initial;
  bool _busy = false;

  Future<void> _onAllow() async {
    setState(() => _busy = true);
    final PermissionResult result;
    switch (widget.kind) {
      case PermissionKind.notifications:
        result = await PermissionService.instance.requestNotifications();
        break;
      case PermissionKind.contacts:
        result = await PermissionService.instance.requestContacts();
        break;
      case PermissionKind.exactAlarm:
        result = await PermissionService.instance.requestExactAlarm();
        break;
      case PermissionKind.batteryOptimization:
        result = await PermissionService.instance
            .requestIgnoreBatteryOptimizations();
        break;
      case PermissionKind.location:
        result = await PermissionService.instance.requestLocation();
        break;
      case PermissionKind.calendar:
        // v1.0 Phase E (SYS-E? / `CalendarContract`): the
        // calendar read permission. Wired into the
        // `PermissionKind` enum + service but the calendar
        // routine templates have not landed yet, so the
        // sheet's `Allow` CTA is a no-op for now.
        result = await PermissionService.instance.requestCalendar();
        break;
      case PermissionKind.usageStats:
        // v1.1g / ADR-030 / SYS-086. There is no runtime
        // prompt for `PACKAGE_USAGE_STATS`; the user MUST
        // navigate to Settings → Special access → Usage
        // access and toggle do it on. The "Allow" CTA on
        // this sheet deep-links to that page; the result is
        // decided after the user comes back via the
        // `_onOpenSettings` flow's re-probe (the
        // `AppLifecycleState.resumed` listener calls
        // `PermissionService.refreshUsageStats`).
        final opened = await PermissionService.instance.requestUsageStats();
        result = opened
            ? const PermissionResultDenied(canOpenSettings: true)
            : const PermissionResultPermanentlyDenied();
        break;
      case PermissionKind.callScreening:
        // v1.2 / SYS-075 + SYS-079 follow-up.
        // `ROLE_CALL_SCREENING` is a system role held via
        // `RoleManager.createRequestRoleIntent`. The "Allow"
        // CTA fires the role-request flow; the OS dialog is
        // asynchronous — callers re-probe via
        // `refreshCallScreening` when the app resumes. The
        // return value is "true if the launch resolved";
        // map the success path to denied(canOpenSettings: true)
        // so the sheet closes and the user sees the role
        // chip on the Settings tile when they come back.
        final opened = await PermissionService.instance.requestCallScreening();
        result = opened
            ? const PermissionResultDenied(canOpenSettings: true)
            : const PermissionResultPermanentlyDenied();
        break;
      case PermissionKind.fullScreenIntent:
        // v1.3c / Phase 14 / SYS-113 / ADR-043.
        // `USE_FULL_SCREEN_INTENT` is a special-access
        // permission — Android does not show a runtime
        // prompt. The "Allow" CTA deep-links to the FSI
        // Settings page (API 34+) or the app-info page
        // (API 32/33); the re-probe on resume decides the
        // final status. Mirrors the `usageStats` pattern.
        final opened = await PermissionService.instance
            .requestFullScreenIntent();
        result = opened
            ? const PermissionResultDenied(canOpenSettings: true)
            : const PermissionResultPermanentlyDenied();
        break;
      case PermissionKind.notificationPolicy:
        // v1.5b / Phase 25: `ACCESS_NOTIFICATION_POLICY` is
        // a special-access permission — Android does not
        // show a runtime prompt. The "Allow" CTA drops the
        // user into the app's notification-policy page
        // (a follow-up to PR #27 will add a dedicated
        // `NotificationPolicyService`; for now we fall back
        // to the generic app-settings page and let the
        // user navigate from there). Mirrors the
        // `fullScreenIntent` pattern.
        final opened = await PermissionService.instance.openAppSettings();
        result = opened
            ? const PermissionResultDenied(canOpenSettings: true)
            : const PermissionResultPermanentlyDenied();
        break;
      case PermissionKind.backupFolder:
        // The SAF picker is handled by `requestBackupFolder`;
        // the sheet is never shown for this kind because
        // `ensure` returns `granted` for it.
        result = const PermissionResultGranted();
        break;
    }
    if (!mounted) return;
    final granted = result is PermissionResultGranted;
    if (granted) {
      Navigator.of(context).pop(const _PermissionSheetResult(granted: true));
    } else {
      setState(() {
        _status = result;
        _busy = false;
      });
    }
  }

  Future<void> _onOpenSettings() async {
    setState(() => _busy = true);
    final PermissionService svc = PermissionService.instance;
    bool opened = false;
    if (widget.kind == PermissionKind.batteryOptimization &&
        widget.bridge != null) {
      // The bridge is the live `ReminderBridge`; cast via
      // dynamic call to avoid importing the reminders layer
      // from this widget (and to keep the seam testable).
      final dynamic b = widget.bridge;
      try {
        await b.openIgnoreBatteryOptimizations();
        opened = true;
      } on NoSuchMethodError {
        opened = false;
      }
    } else {
      opened = await svc.openAppSettings();
    }
    if (!mounted) return;
    // After returning from system Settings the user may
    // have toggled the permission. Re-probe via the
    // service's `requestX` path (which refreshes the cached
    // status) and decide based on the new value.
    final PermissionResult result;
    switch (widget.kind) {
      case PermissionKind.notifications:
        result = await svc.requestNotifications();
        break;
      case PermissionKind.contacts:
        result = await svc.requestContacts();
        break;
      case PermissionKind.exactAlarm:
        result = await svc.requestExactAlarm();
        break;
      case PermissionKind.batteryOptimization:
        result = await svc.requestIgnoreBatteryOptimizations();
        break;
      case PermissionKind.location:
        result = await svc.requestLocation();
        break;
      case PermissionKind.calendar:
        result = await svc.requestCalendar();
        break;
      case PermissionKind.usageStats:
        // `PACKAGE_USAGE_STATS` is a special-access permission;
        // the deep-link target is the Usage Access Settings
        // page, not the generic app Settings page. We call
        // `requestUsageStats()` (which deep-links + returns
        // true if the launch resolved) and then re-probe so
        // the user sees the updated status if they came back
        // having toggled it on.
        await svc.requestUsageStats();
        await svc.refreshUsageStats();
        result =
            svc.statuses.value[PermissionKind.usageStats] ??
            const PermissionResultDenied(canOpenSettings: true);
        break;
      case PermissionKind.callScreening:
        // v1.2 / SYS-075 + SYS-079 follow-up. The OS role
        // picker is asynchronous; we fire the role flow and
        // re-probe. If the role is now held, the result is
        // `granted`; otherwise it stays `denied`.
        await svc.requestCallScreening();
        await svc.refreshCallScreening();
        result =
            svc.statuses.value[PermissionKind.callScreening] ??
            const PermissionResultDenied(canOpenSettings: true);
        break;
      case PermissionKind.fullScreenIntent:
        // v1.3c / Phase 14 / SYS-113 / ADR-043.
        // `USE_FULL_SCREEN_INTENT` is opt-in via the
        // deep-link. Fire the request, then re-probe the
        // platform channel. Mirrors the `usageStats`
        // pattern (request → refresh → read cached status).
        await svc.requestFullScreenIntent();
        await svc.refreshFullScreenIntent();
        result =
            svc.statuses.value[PermissionKind.fullScreenIntent] ??
            const PermissionResultDenied(canOpenSettings: true);
        break;
      case PermissionKind.notificationPolicy:
        // v1.5b / Phase 25: `ACCESS_NOTIFICATION_POLICY` is
        // opt-in via the deep-link (a follow-up to PR #27
        // adds `requestNotificationPolicy` + the Kotlin
        // handler — for now we re-probe the cached state
        // after the generic app-settings deep-link). Mirrors
        // the `fullScreenIntent` pattern.
        await svc.openAppSettings();
        await svc.refreshNotificationPolicy();
        result =
            svc.statuses.value[PermissionKind.notificationPolicy] ??
            const PermissionResultDenied(canOpenSettings: true);
        break;
      case PermissionKind.backupFolder:
        result = const PermissionResultGranted();
        break;
    }
    if (!mounted) return;
    final granted = result is PermissionResultGranted;
    setState(() {
      _status = result;
      _busy = false;
    });
    if (granted) {
      Navigator.of(context).pop(const _PermissionSheetResult(granted: true));
    } else if (!opened) {
      // Could not open system Settings — let the user know
      // and keep the sheet open for another try.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Android settings.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = permissionKindMeta[widget.kind]!;
    final scheme = Theme.of(context).colorScheme;
    final isPermanentlyDenied = _status is PermissionResultPermanentlyDenied;
    final canOpenSettings =
        _status is PermissionResultDenied &&
        (_status as PermissionResultDenied).canOpenSettings;
    // Buttons appear in this order:
    //  - `denied` (one-shot):       primary "Allow" + tonal "Open settings"
    //  - `permanentlyDenied`:       primary "Open settings" only
    //  - `denied(canOpenSettings:false)` (iOS restricted): no buttons —
    //      the user has to lift the restriction out of band.
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Spacing.md,
          right: Spacing.md,
          top: Spacing.sm,
          bottom: Spacing.md + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(meta.icon, color: scheme.primary),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    meta.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Text(meta.rationale),
            if (isPermanentlyDenied) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                "You've blocked this permission. Open Android settings "
                'to grant it.',
                style: TextStyle(color: scheme.error),
              ),
            ],
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                if (canOpenSettings) ...[
                  Expanded(
                    child: FilledButton.tonal(
                      key: const ValueKey('permission_sheet.open_settings'),
                      onPressed: _busy ? null : _onOpenSettings,
                      child: const Text('Open settings'),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                ],
                if (!isPermanentlyDenied)
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('permission_sheet.allow'),
                      onPressed: _busy ? null : _onAllow,
                      child: const Text('Allow'),
                    ),
                  )
                else
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('permission_sheet.open_settings'),
                      onPressed: _busy ? null : _onOpenSettings,
                      child: const Text('Open settings'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
