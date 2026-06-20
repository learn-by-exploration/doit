// Onboarding screen — permission-first UX for first launch.
//
// Per WF-001. The screen requests, in order:
//   1. POST_NOTIFICATIONS (Android 13+). SYS-063.
//   2. READ_CONTACTS (cadence-style habits). SYS-064.
//   3. SCHEDULE_EXACT_ALARM (best-effort; gracefully degrades).
//      SYS-065.
//   4. The backup folder (SAF). SYS-066.
//   5. The anchor mode selection.
//
// v0.5c (ADR-016) wires the four runtime permission
// requests to `PermissionService`. The order follows
// ADR-014. Each step's CTA calls the corresponding
// `requestX()` method and advances on `granted`. The
// `Skip` button remains as a user choice.
//
// Layer rules (per .claude/rules/lib-screens.md): no platform
// calls in widgets — every `requestX` goes through the
// `PermissionService` seam, never directly to
// `permission_handler` or `file_picker`. The service
// returns a sealed `PermissionResult` (or
// `BackupFolderResult`) which the screen pattern-matches
// on to decide whether to advance, show a one-shot
// re-ask affordance, or surface a "Go to Android
// Settings" deep-link for the `permanentlyDenied` case.

import 'package:flutter/material.dart';

import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  AnchorMode _anchorMode = AnchorMode.manual;
  ThemeMode _themeMode = ThemeMode.dark;

  // v0.5c (ADR-016) state for the permission-step UX.
  // - `_inFlight` blocks double-taps while a system dialog or
  //   SAF picker is open. The CTA's `onPressed` consults
  //   this so the user can't fire a second `requestX` while
  //   the first is awaiting.
  // - `_rationaleText` is the inline message shown after a
  //   `denied` / `permanentlyDenied` result, or after a
  //   `BackupFolderError`. `null` when the step is at rest.
  // - `_goToSettingsVisible` drives the secondary "Open
  //   Android settings" `FilledButton.tonal`. It is `true`
  //   whenever the service reports `canOpenSettings: true`
  //   AND the user has not yet granted the permission.
  bool _inFlight = false;
  String? _rationaleText;
  bool _goToSettingsVisible = false;

  static const _steps = <_OnboardingStep>[
    _OnboardingStep(
      title: 'Notifications',
      body:
          'do it sends a daily reminder for each do. Android '
          'asks for the notification permission once.',
      cta: 'Allow',
    ),
    _OnboardingStep(
      title: 'Contacts',
      body:
          'If you add a "cadence" do — call Mom every Sunday — '
          'do it reads the contact you pick. It never imports the '
          'whole address book.',
      cta: 'Allow',
    ),
    _OnboardingStep(
      title: 'Exact alarms',
      body:
          'Exact alarms fire reminders on the minute, not up to '
          '15 minutes late. If you decline, do it falls back to a '
          'best-effort schedule.',
      cta: 'Allow',
    ),
    _OnboardingStep(
      title: 'Backup folder',
      body:
          'Pick a folder on your phone (or SD card) for nightly '
          'auto-backups. do it writes a single encrypted file; the '
          'folder stays yours.',
      cta: 'Pick folder',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_step < _steps.length) {
      final s = _steps[_step];
      return Scaffold(
        appBar: AppBar(title: const Text('Welcome to do it')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Spacing.lg),
                Icon(
                  Icons.bolt_outlined,
                  size: Sizing.huge,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: Spacing.lg),
                Text(
                  s.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  s.body,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey('onboarding.next'),
                  onPressed: _inFlight ? null : _handleStepCta,
                  child: Text(s.cta),
                ),
                const SizedBox(height: Spacing.sm),
                if (_rationaleText != null) ...[
                  Text(
                    _rationaleText!,
                    key: const ValueKey('onboarding.rationale'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Spacing.sm),
                ],
                if (_goToSettingsVisible) ...[
                  FilledButton.tonal(
                    key: const ValueKey('onboarding.openAndroidSettings'),
                    onPressed: _inFlight ? null : _openAndroidSettings,
                    child: const Text('Open Android settings'),
                  ),
                  const SizedBox(height: Spacing.sm),
                ],
                TextButton(onPressed: widget.onDone, child: const Text('Skip')),
              ],
            ),
          ),
        ),
      );
    }
    // Last step — anchor mode + theme + finish.
    return Scaffold(
      appBar: AppBar(title: const Text('Last step')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How should do it detect your morning?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Spacing.md),
              RadioGroup<AnchorMode>(
                groupValue: _anchorMode,
                onChanged: (m) {
                  if (m == null) return;
                  setState(() => _anchorMode = m);
                },
                child: Column(
                  children: [
                    for (final entry in const [
                      (AnchorMode.manual, 'Manual — I tap "I\'m up"'),
                      (AnchorMode.firstUnlock, 'First unlock of the day'),
                      (AnchorMode.either, 'Either, with confirmation'),
                    ])
                      RadioListTile<AnchorMode>(
                        title: Text(entry.$2),
                        value: entry.$1,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text('Theme', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Spacing.sm),
              RadioGroup<ThemeMode>(
                groupValue: _themeMode,
                onChanged: (m) {
                  if (m == null) return;
                  setState(() => _themeMode = m);
                },
                child: Column(
                  children: [
                    for (final entry in const [
                      (ThemeMode.dark, 'Dark'),
                      (ThemeMode.light, 'Light'),
                      (ThemeMode.system, 'System'),
                    ])
                      RadioListTile<ThemeMode>(
                        title: Text(entry.$2),
                        value: entry.$1,
                      ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                key: const ValueKey('onboarding.finish'),
                onPressed: _finish,
                child: const Text('Done'),
              ),
              const SizedBox(height: Spacing.md),
            ],
          ),
        ),
      ),
    );
  }

  /// Dispatch the per-step CTA to the right `requestX` method
  /// on [PermissionService]. The order is fixed by ADR-014 /
  /// ADR-016 and matches the `_steps` order:
  ///
  ///   _step == 0  → [PermissionService.requestNotifications]   (SYS-063)
  ///   _step == 1  → [PermissionService.requestContacts]        (SYS-064)
  ///   _step == 2  → [PermissionService.requestExactAlarm]      (SYS-065)
  ///   _step == 3  → [PermissionService.requestBackupFolder]    (SYS-066)
  ///
  /// The `_inFlight` guard at the top blocks double-taps
  /// while a system dialog or SAF picker is open. On
  /// [PermissionResultGranted] the step advances; on
  /// [PermissionResultDenied] / [PermissionResultPermanentlyDenied]
  /// the inline rationale text and the "Open Android
  /// settings" button (when `canOpenSettings` is `true`) are
  /// revealed. For the backup-folder step,
  /// [BackupFolderPicked] persists the treeUri to
  /// [SettingsService.setBackupFolderUri] and advances;
  /// [BackupFolderCancelled] advances without persisting
  /// (per ADR-014 step 6: the backup folder is skippable);
  /// [BackupFolderError] surfaces the message and stays on
  /// the step.
  Future<void> _handleStepCta() async {
    if (_inFlight) return;
    setState(() {
      _inFlight = true;
      _rationaleText = null;
      _goToSettingsVisible = false;
    });
    final service = PermissionService.instance;
    if (_step < 3) {
      final PermissionResult result = switch (_step) {
        0 => await service.requestNotifications(),
        1 => await service.requestContacts(),
        // The `_step < 3` guard above guarantees this is
        // reachable only for `_step == 2`.
        _ => await service.requestExactAlarm(),
      };
      if (!mounted) return;
      setState(() {
        _inFlight = false;
        switch (result) {
          case PermissionResultGranted():
            _step++;
          case PermissionResultDenied(:final canOpenSettings):
            _rationaleText =
                'You can grant this later — tap Allow again, or '
                'open Android settings.';
            _goToSettingsVisible = canOpenSettings;
          case PermissionResultPermanentlyDenied():
            _rationaleText =
                "You've blocked this permission. Open Android "
                'settings to grant it.';
            _goToSettingsVisible = true;
        }
      });
      return;
    }
    // _step == 3: backup folder (SYS-066). The dispatch is
    // intentionally outside the switch above because the
    // return type changes (`BackupFolderResult` instead of
    // `PermissionResult`).
    final BackupFolderResult folderResult = await service.requestBackupFolder();
    if (!mounted) return;
    setState(() {
      _inFlight = false;
      switch (folderResult) {
        case BackupFolderPicked(:final path):
          SettingsService.instance.setBackupFolderUri(path);
          _step++;
        case BackupFolderCancelled():
          // Per ADR-014 step 6: the backup folder is
          // skippable. Advance without persisting so the
          // user can still proceed to the anchor-mode step.
          _step++;
        case BackupFolderError(:final message):
          _rationaleText = 'Folder picker error: $message';
      }
    });
  }

  /// Open the system app-settings page so the user can grant
  /// a permission they previously denied. Called from the
  /// "Open Android settings" `FilledButton.tonal` shown
  /// after a `denied(canOpenSettings: true)` or
  /// `permanentlyDenied` result. The result is observed
  /// implicitly — when the user returns from the system
  /// settings and re-taps the CTA, the service re-probes
  /// and advances if the grant succeeded.
  Future<void> _openAndroidSettings() async {
    await PermissionService.instance.openAppSettings();
  }

  void _finish() {
    ReminderService.instance.anchor
      ..stop()
      ..start(mode: _anchorMode);
    SettingsService.instance.themeMode.value = _themeMode;
    widget.onDone();
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.title,
    required this.body,
    required this.cta,
  });
  final String title;
  final String body;
  final String cta;
}
