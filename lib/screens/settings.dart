// Settings screen — permissions, alarm reliability, theme, and
// the restore-from-backup stub.
//
// Per WF-012 (permissions), WF-013 (alarm reliability), WF-015
// (theme), WF-016 (anchor mode).
//
// v0.1 inlines the most common knobs:
//   - Theme mode (dark / light / system).
//   - Anchor mode (manual / first-unlock / either).
//   - The reliability banner, with deep links to the OS
//     settings pages (best-effort; not all OEMs expose them).
//   - A "Restore from backup" placeholder that hands off to
//     `BackupService` once Phase 6 lands.
//
// v0.5d (ADR-016) adds a new `Permissions` section between
// `Wake-up anchor` and `Reliability`. The section surfaces
// the current `PermissionService.statuses` map as four
// `ListTile`s (notifications, contacts, exact alarms,
// backup folder) with a "Settings" `TextButton` for any
// permission that is `permanentlyDenied`. Tapping the row
// re-probes the relevant permission via the service's
// `requestX()` method; the "Settings" button deep-links to
// the Android system app-settings page.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:doit/build_info.dart';
import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/screens/settings_restore.dart';
import 'package:doit/services/call_interceptor.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/widgets/device_state_row.dart';
import 'package:doit/widgets/reliability_banner.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Anchor mode is held in widget state for v0.1; v0.2 will
  // persist via SettingsService.
  AnchorMode _anchorMode = AnchorMode.manual;

  @override
  void initState() {
    super.initState();
    _anchorMode = ReminderService.instance.anchor.mode;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsAppBarTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            ReliabilityBanner.fromService(
              key: const ValueKey<String>('settings.reliability_banner'),
            ),
            const SizedBox(height: Spacing.md),
            _SectionHeader(l.settingsSectionAppearance),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: SettingsService.instance.themeMode,
              builder: (_, mode, _) => _ThemeModeTile(
                mode: mode,
                onChanged: (m) => SettingsService.instance.themeMode.value = m,
              ),
            ),
            const SizedBox(height: Spacing.md),
            _SectionHeader(l.settingsSectionAnchor),
            _AnchorModeTile(
              mode: _anchorMode,
              onChanged: (m) {
                setState(() => _anchorMode = m);
                ReminderService.instance.anchor
                  ..stop()
                  ..start(mode: m);
              },
            ),
            const SizedBox(height: Spacing.md),
            _SectionHeader(l.settingsSectionPermissions),
            const _PermissionsRow(),
            const SizedBox(height: Spacing.md),
            _SectionHeader(l.settingsSectionReliability),
            _ReliabilityRow(
              reliability: ReminderService.instance.scheduler.reliability,
            ),
            ListTile(
              key: const ValueKey('settings.test_reminder'),
              leading: const Icon(Icons.notifications_outlined),
              title: Text(l.settingsTestReminderTitle),
              subtitle: Text(l.settingsTestReminderSubtitle),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ReminderService.instance.scheduleTestReminder();
                if (!context.mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(l.settingsTestReminderSnackbar)),
                );
              },
            ),
            const SizedBox(height: Spacing.md),
            _SectionHeader(l.settingsSectionDeviceState),
            const DeviceStateRow(),
            const SizedBox(height: Spacing.md),
            _SectionHeader(l.settingsSectionBackup),
            ListTile(
              key: const ValueKey('settings.restore'),
              leading: const Icon(Icons.restore_outlined),
              title: Text(l.settingsRestoreTitle),
              subtitle: Text(l.settingsRestoreSubtitle),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsRestoreScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: Spacing.lg),
            _SectionHeader(l.settingsSectionAbout),
            ListTile(
              title: Text(l.appTitle),
              subtitle: Text(l.settingsAboutAppVersion(kAppVersion)),
              dense: true,
            ),
            ListTile(
              key: const ValueKey('settings.licenses'),
              leading: const Icon(Icons.description_outlined),
              title: Text(l.settingsLicensesTitle),
              subtitle: Text(l.settingsLicensesSubtitle),
              onTap: () => showLicensePage(
                context: context,
                applicationName: l.appTitle,
                applicationVersion: kAppVersion,
                applicationLegalese: 'Local-only. No telemetry. No accounts.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({required this.mode, required this.onChanged});
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return RadioGroup<ThemeMode>(
      groupValue: mode,
      onChanged: (m) {
        if (m != null) onChanged(m);
      },
      child: Column(
        children: [
          for (final entry in <(ThemeMode, String)>[
            (ThemeMode.dark, l.settingsThemeDark),
            (ThemeMode.light, l.settingsThemeLight),
            (ThemeMode.system, l.settingsThemeSystem),
          ])
            RadioListTile<ThemeMode>(title: Text(entry.$2), value: entry.$1),
        ],
      ),
    );
  }
}

class _AnchorModeTile extends StatelessWidget {
  const _AnchorModeTile({required this.mode, required this.onChanged});
  final AnchorMode mode;
  final ValueChanged<AnchorMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return RadioGroup<AnchorMode>(
      groupValue: mode,
      onChanged: (m) {
        if (m != null) onChanged(m);
      },
      child: Column(
        children: [
          for (final entry in <(AnchorMode, String)>[
            (AnchorMode.manual, l.settingsAnchorManual),
            (AnchorMode.firstUnlock, l.settingsAnchorFirstUnlock),
            (AnchorMode.either, l.settingsAnchorEither),
          ])
            RadioListTile<AnchorMode>(title: Text(entry.$2), value: entry.$1),
        ],
      ),
    );
  }
}

class _ReliabilityRow extends StatelessWidget {
  const _ReliabilityRow({required this.reliability});
  final Reliability reliability;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = switch (reliability) {
      Reliability.optimal => l.settingsReminderReliabilityOptimal,
      Reliability.degraded => l.settingsReminderReliabilityDegraded,
      Reliability.unknown => l.settingsReminderReliabilityUnknown,
    };
    return ListTile(
      leading: const Icon(Icons.notifications_active_outlined),
      title: Text(l.settingsReminderReliabilityTitle),
      subtitle: Text(label),
      onTap: HapticFeedback.selectionClick,
    );
  }
}

/// v0.5d (ADR-016): the four `PermissionService`-backed
/// permission rows. Reads from
/// [PermissionService.instance.statuses] (a
/// `ValueNotifier<Map<PermissionKind, PermissionResult?>>`
/// exposed by the service) and renders one `ListTile` per
/// runtime permission plus the backup-folder picker. The
/// row is tappable as a "Tap to fix" affordance: the
/// `requestX()` call re-probes the permission (and shows
/// the system dialog if not yet granted). The "Settings"
/// `TextButton` on `permanentlyDenied` rows deep-links to
/// the Android system app-settings page so the user can
/// grant the policy permission that the system dialog no
/// longer surfaces.
//
// v1.0 (Phase C, SYS-076, ADR-021): adds the coarse-
// location tile between exact-alarm and battery-
// optimization. The tile is rendered the same way as the
// other runtime kinds; tapping it calls
// [PermissionService.requestLocation] which surfaces the
// system dialog (and re-probes the platform stream so
// [GeofenceService] picks up the grant).
class _PermissionsRow extends StatelessWidget {
  const _PermissionsRow();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<Map<PermissionKind, PermissionResult?>>(
      valueListenable: PermissionService.instance.statuses,
      builder: (context, statuses, _) {
        return Column(
          children: [
            _PermissionTile(
              key: const ValueKey('settings.permission.notifications'),
              kind: PermissionKind.notifications,
              icon: Icons.notifications_outlined,
              title: l.permissionNotificationsTitle,
              result: statuses[PermissionKind.notifications],
            ),
            _PermissionTile(
              key: const ValueKey('settings.permission.contacts'),
              kind: PermissionKind.contacts,
              icon: Icons.contacts_outlined,
              title: l.permissionContactsTitle,
              result: statuses[PermissionKind.contacts],
            ),
            _PermissionTile(
              key: const ValueKey('settings.permission.exactAlarm'),
              kind: PermissionKind.exactAlarm,
              icon: Icons.alarm_outlined,
              title: l.permissionExactAlarmTitle,
              result: statuses[PermissionKind.exactAlarm],
            ),
            _PermissionTile(
              key: const ValueKey('settings.permission.location'),
              kind: PermissionKind.location,
              icon: Icons.location_on_outlined,
              title: l.permissionLocationTitle,
              result: statuses[PermissionKind.location],
            ),
            const _CallScreeningTile(),
            const _BackupFolderTile(),
          ],
        );
      },
    );
  }
}

/// One row in the v0.5d Permissions section. Maps a
/// [PermissionKind] to a `ListTile` with the right icon,
/// status text, and (on `permanentlyDenied`) a "Settings"
/// `TextButton` for the deep-link to the system
/// app-settings page. Tapping the row re-probes the
/// permission via [PermissionService.requestNotifications]
/// / [PermissionService.requestContacts] /
/// [PermissionService.requestExactAlarm]; the system
/// dialog appears only if the permission is denied and
/// not yet permanently denied.
class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    super.key,
    required this.kind,
    required this.icon,
    required this.title,
    required this.result,
  });

  final PermissionKind kind;
  final IconData icon;
  final String title;
  final PermissionResult? result;

  @override
  Widget build(BuildContext context) {
    final permanentlyDenied = result is PermissionResultPermanentlyDenied;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(_statusText(context, result)),
      // The "Settings" `TextButton` is rendered only for
      // `permanentlyDenied` because that is the only
      // state where the system dialog will not re-appear;
      // the user has to go to the system app-settings
      // page to grant the permission. For one-shot
      // denials (`denied(canOpenSettings: true)`) the
      // row's `onTap` re-probes via `requestX()`, which
      // shows the system dialog without needing a
      // deep-link. For `granted` and `null` (not asked
      // yet) the row's `onTap` is still the primary
      // affordance.
      trailing: permanentlyDenied
          ? TextButton(
              key: ValueKey('settings.permission.settings.${kind.name}'),
              onPressed: PermissionService.instance.openAppSettings,
              child: Text(
                AppLocalizations.of(context).permissionSettingsButton,
              ),
            )
          : const Icon(Icons.chevron_right),
      onTap: _reProbe,
    );
  }

  /// Re-probe the permission via the service. For
  /// already-granted permissions `requestX()` returns
  /// `granted` without a system dialog. For one-shot
  /// denials the dialog re-appears. For
  /// `permanentlyDenied` (where the system dialog will
  /// not re-appear) the user can still tap the row to
  /// re-probe; the call returns `permanentlyDenied` and
  /// the status display is unchanged. The "Settings"
  /// `TextButton` is the deeper recovery path for that
  /// state.
  Future<void> _reProbe() async {
    final service = PermissionService.instance;
    switch (kind) {
      case PermissionKind.notifications:
        await service.requestNotifications();
      case PermissionKind.contacts:
        await service.requestContacts();
      case PermissionKind.exactAlarm:
        await service.requestExactAlarm();
      case PermissionKind.batteryOptimization:
        // SYS-068: battery-opt whitelist probe. Unlike the
        // other runtime permissions, this does not show a
        // system dialog — it just re-reads the current
        // whitelist state.
        await service.requestIgnoreBatteryOptimizations();
      case PermissionKind.location:
        // SYS-076: coarse-location runtime permission
        // (Phase C PR 2 / ADR-021). The re-prompt flow
        // matches the other runtime kinds.
        await service.requestLocation();
      case PermissionKind.calendar:
        // SYS-078: READ_CALENDAR runtime permission
        // (Phase E PR 1 / ADR-023). Used by
        // `CalendarService` to watch event transitions for
        // `TriggerCalendarEvent` matching.
        await service.requestCalendar();
      case PermissionKind.usageStats:
        // v1.1g / ADR-030 / SYS-086: PACKAGE_USAGE_STATS
        // is a special-access permission. There is no
        // runtime prompt; the user MUST navigate to
        // Settings → Special access → Usage access. The
        // re-probe re-reads the current AppOpsManager mode
        // and refreshes the cached status so the tile
        // updates when the user toggles it on in the
        // background.
        await service.refreshUsageStats();
      case PermissionKind.backupFolder:
        // The backup folder is not a runtime permission;
        // it's a SAF picker. The re-pick is handled in
        // `_BackupFolderTile` separately, so this branch
        // is unreachable from the row's `onTap`.
        break;
    }
  }

  static String _statusText(BuildContext context, PermissionResult? r) {
    final l = AppLocalizations.of(context);
    return switch (r) {
      PermissionResultGranted() => l.permissionStatusGranted,
      PermissionResultDenied() => l.permissionStatusDenied,
      PermissionResultPermanentlyDenied() => l.permissionStatusBlocked,
      null => l.permissionStatusNotAsked,
    };
  }
}

/// v0.5d (ADR-016) / SYS-066: the backup-folder tile.
/// Reads [SettingsService.instance.backupFolderUri] and
/// surfaces the picked path (or "Not picked" if null).
/// Tapping the tile re-picks via
/// [PermissionService.requestBackupFolder]; on
/// [BackupFolderPicked] the path is persisted to
/// [SettingsService.setBackupFolderUri]. The re-pick
/// path is the recovery affordance for users who revoked
/// the SAF grant from system settings — without it, a
/// missed /revoke would silently break nightly backups.
class _BackupFolderTile extends StatelessWidget {
  const _BackupFolderTile();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<String?>(
      valueListenable: SettingsService.instance.backupFolderUri,
      builder: (context, uri, _) {
        return ListTile(
          key: const ValueKey('settings.permission.backupFolder'),
          leading: const Icon(Icons.folder_outlined),
          title: Text(l.permissionBackupFolderTitle),
          subtitle: Text(uri ?? l.permissionBackupFolderNotPicked),
          trailing: uri == null
              ? const Icon(Icons.chevron_right)
              : TextButton(
                  key: const ValueKey(
                    'settings.permission.backupFolder.repick',
                  ),
                  onPressed: () => _rePick(context),
                  child: Text(l.permissionBackupFolderRePick),
                ),
          onTap: uri == null ? () => _rePick(context) : null,
        );
      },
    );
  }

  Future<void> _rePick(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await PermissionService.instance.requestBackupFolder();
    if (!context.mounted) return;
    switch (result) {
      case BackupFolderPicked(:final path):
        SettingsService.instance.setBackupFolderUri(path);
        messenger.showSnackBar(
          SnackBar(content: Text(l.permissionBackupFolderSet(path))),
        );
      case BackupFolderCancelled():
        // Silent: the user cancelled, the previous URI
        // (if any) is unchanged. The empty case body
        // needs an explicit `break` to keep the cases
        // disjoint — Dart 3's switch-statement case
        // bodies share if no break / return / throw
        // ends them, and `BackupFolderError.message` is
        // only bound in its own case.
        break;
      case BackupFolderError(:final message):
        messenger.showSnackBar(
          SnackBar(content: Text(l.permissionBackupFolderError(message))),
        );
    }
  }
}

/// Phase F PR 2 (SYS-075 / SYS-079): the call-screening
/// role tile. Probes
/// [CallInterceptorService.isCallScreeningRoleHeld] on every
/// mount; tapping "Change" fires
/// [CallInterceptorService.requestCallScreeningRole] (the
/// OS role-request dialog). The probe re-runs after the
/// user returns from the dialog so the status reflects the
/// current OS state.
class _CallScreeningTile extends StatefulWidget {
  const _CallScreeningTile();

  @override
  State<_CallScreeningTile> createState() => _CallScreeningTileState();
}

class _CallScreeningTileState extends State<_CallScreeningTile>
    with WidgetsBindingObserver {
  bool? _held;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _probe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The OS role dialog lives in a separate Activity.
    // When the user returns from that dialog to do it, the
    // lifecycle resumes — re-probe so the tile's status
    // text reflects the actual grant.
    if (state == AppLifecycleState.resumed) {
      _probe();
    }
  }

  Future<void> _probe() async {
    final held = await CallInterceptorService.instance
        .isCallScreeningRoleHeld();
    if (!mounted) return;
    setState(() => _held = held);
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    await CallInterceptorService.instance.requestCallScreeningRole();
    if (!mounted) return;
    setState(() => _busy = false);
    // The role dialog is asynchronous — re-probe after a
    // short delay so the post-grant state shows up if the
    // user has already accepted. The lifecycle observer
    // handles the typical case (user returns to the app);
    // this is the fallback for an instant-grant path.
    await _probe();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final held = _held;
    final subtitle = switch (held) {
      null => l.permissionCallScreeningChecking,
      true => l.permissionCallScreeningHeld,
      false => l.permissionCallScreeningNotHeld,
    };
    return ListTile(
      key: const ValueKey('settings.permission.callScreening'),
      leading: const Icon(Icons.call_outlined),
      title: Text(l.permissionCallScreeningTitle),
      subtitle: Text(subtitle),
      trailing: _busy
          ? const SizedBox(
              key: ValueKey('settings.permission.callScreening.busy'),
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              key: const ValueKey('settings.permission.callScreening.change'),
              onPressed: _request,
              child: Text(
                held == true
                    ? l.permissionCallScreeningChange
                    : l.permissionCallScreeningGrant,
              ),
            ),
      onTap: _busy ? null : _request,
    );
  }
}
