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

import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/theme/app_theme.dart';

/// Per-kind metadata. Title and rationale are kept in sync
/// with the onboarding step bodies (`lib/screens/onboarding.dart`).
class _KindMeta {
  const _KindMeta({
    required this.title,
    required this.icon,
    required this.rationale,
  });

  final String title;
  final IconData icon;
  final String rationale;
}

const Map<PermissionKind, _KindMeta> _meta = <PermissionKind, _KindMeta>{
  PermissionKind.notifications: _KindMeta(
    title: 'Notifications',
    icon: Icons.notifications_outlined,
    rationale:
        'do it sends a daily reminder for each habit. Android asks for '
        'the notification permission once.',
  ),
  PermissionKind.contacts: _KindMeta(
    title: 'Contacts',
    icon: Icons.contacts_outlined,
    rationale:
        'If you add a "cadence" habit — call Mom every Sunday — do it '
        'reads the contact you pick. It never imports the whole address '
        'book.',
  ),
  PermissionKind.exactAlarm: _KindMeta(
    title: 'Exact alarms',
    icon: Icons.alarm_outlined,
    rationale:
        'Exact alarms fire reminders on the minute, not up to 15 '
        'minutes late. If you decline, do it falls back to a '
        'best-effort schedule.',
  ),
  PermissionKind.batteryOptimization: _KindMeta(
    title: 'Battery optimization',
    icon: Icons.battery_saver_outlined,
    rationale:
        'Allowing do it to run in the background ensures your '
        'reminders fire on time, even when your phone is in Doze mode.',
  ),
};

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
    final meta = _meta[widget.kind]!;
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
