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

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/services/call_interceptor.dart';
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

  /// Total number of permission-step screens in the
  /// onboarding flow. Pinned as a constant because the
  /// step list is rebuilt from `AppLocalizations.of(context)`
  /// inside `build` (we cannot keep a `static const` of
  /// localized strings), and `_handleSkip` /
  /// `_handleStepCta` consult the count outside the
  /// `build` context. Mirrors the length of
  /// `_buildSteps(...)` (5 steps: Notifications, Contacts,
  /// Exact alarms, Backup folder, Call-screening role).
  /// If a future PR adds or removes a step, this constant
  /// MUST be updated in lockstep.
  static const int _kStepCount = 5;

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

  static List<_OnboardingStep> _buildSteps(AppLocalizations l) =>
      <_OnboardingStep>[
        _OnboardingStep(
          title: l.onboardingStepNotificationsTitle,
          body: l.onboardingStepNotificationsBody,
          cta: l.onboardingStepNotificationsCta,
        ),
        _OnboardingStep(
          title: l.onboardingStepContactsTitle,
          body: l.onboardingStepContactsBody,
          cta: l.onboardingStepContactsCta,
        ),
        _OnboardingStep(
          title: l.onboardingStepExactAlarmsTitle,
          body: l.onboardingStepExactAlarmsBody,
          cta: l.onboardingStepExactAlarmsCta,
        ),
        _OnboardingStep(
          title: l.onboardingStepBackupFolderTitle,
          body: l.onboardingStepBackupFolderBody,
          cta: l.onboardingStepBackupFolderCta,
        ),
        // Phase F PR 2 (SYS-075 / SYS-079). Opt-in to the
        // call-screening role so the Japan routine can intercept
        // matched contacts. The role is opt-in on Android Q+;
        // older OS versions silently skip the grant. The step
        // is skippable: a user who declines stays on the next
        // step (anchor mode) and can grant the role later from
        // Settings.
        _OnboardingStep(
          title: l.onboardingStepCallScreeningTitle,
          body: l.onboardingStepCallScreeningBody,
          cta: l.onboardingStepCallScreeningCta,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final steps = _buildSteps(l);
    if (_step < steps.length) {
      final s = steps[_step];
      return Scaffold(
        appBar: AppBar(title: Text(l.onboardingAppBarTitle)),
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
                    child: Text(l.onboardingOpenAndroidSettingsCta),
                  ),
                  const SizedBox(height: Spacing.sm),
                ],
                TextButton(
                  onPressed: _handleSkip,
                  child: Text(l.onboardingSkipCta),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Last step — anchor mode + theme + finish.
    return Scaffold(
      appBar: AppBar(title: Text(l.onboardingLastStepAppBarTitle)),
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
  ///   _step == 4  → call-screening role opt-in                  (SYS-079)
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
  /// the step. The call-screening step (Phase F PR 2) is
  /// skippable: declining advances without persisting, so
  /// the user can grant later from Settings.
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
    if (_step == 3) {
      // Backup folder (SYS-066). The dispatch is
      // intentionally outside the switch above because the
      // return type changes (`BackupFolderResult` instead of
      // `PermissionResult`).
      final BackupFolderResult folderResult = await service
          .requestBackupFolder();
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
            // user can still proceed to the next step.
            _step++;
          case BackupFolderError(:final message):
            _rationaleText = 'Folder picker error: $message';
        }
      });
      return;
    }
    // _step == 4: call-screening role opt-in (Phase F PR 2
    // / SYS-079). Fire the OS role dialog; advance on
    // either grant OR decline (the user can grant later
    // from Settings). On a hard failure (no Activity
    // context, OS pre-Q, missing plugin) surface an inline
    // rationale and let the user skip via the Skip button.
    final granted = await CallInterceptorService.instance
        .requestCallScreeningRole();
    if (!mounted) return;
    setState(() {
      _inFlight = false;
      if (granted) {
        _step++;
      } else {
        _rationaleText =
            "Couldn't open the role dialog. You can grant the "
            'role later from Settings → Permissions.';
        _goToSettingsVisible = false;
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

  /// Phase F PR 2 (SYS-075 / SYS-079): Skip semantics.
  /// On the call-screening step (the last `_OnboardingStep`),
  /// Skip advances to the Last step (the user can grant the
  /// role later from Settings). On every earlier step, Skip
  /// exits the onboarding flow entirely — that split is
  /// regression-tested by `onboarding_permission_wiring_test.dart`.
  void _handleSkip() {
    if (_step >= _kStepCount - 1) {
      setState(() => _step++);
    } else {
      widget.onDone();
    }
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
