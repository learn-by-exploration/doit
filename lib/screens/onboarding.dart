// Onboarding screen — permission-first UX for first launch.
//
// Per WF-001. The screen requests, in order:
//   1. POST_NOTIFICATIONS (Android 13+).
//   2. READ_CONTACTS (cadence-style habits).
//   3. SCHEDULE_EXACT_ALARM (best-effort; gracefully degrades).
//   4. The backup folder (SAF — Phase 6).
//   5. The anchor mode selection.
//
// v0.1 ships this screen as a visual walkthrough; the actual
// platform-channel permission requests land in Phase 6 once
// the SAF + WorkManager plumbing is wired. The screen is
// skippable (it can be re-opened from Settings in v0.2).
//
// Layer rules (per .claude/rules/lib-screens.md): no platform
// calls in widgets — `requestPermission` is invoked through a
// future service seam (`PermissionService`); for v0.1 the
// `requestX` methods are no-op stubs that return `true` and
// the screen is a presentational walkthrough.

import 'package:flutter/material.dart';

import 'package:doit/reminders/anchor_detector.dart';
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

  static const _steps = <_OnboardingStep>[
    _OnboardingStep(
      title: 'Notifications',
      body:
          'do it sends a daily reminder for each habit. Android '
          'asks for the notification permission once.',
      cta: 'Allow',
    ),
    _OnboardingStep(
      title: 'Contacts',
      body:
          'If you add a "cadence" habit — call Mom every Sunday — '
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
                  onPressed: () => setState(() => _step++),
                  child: Text(s.cta),
                ),
                const SizedBox(height: Spacing.sm),
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
