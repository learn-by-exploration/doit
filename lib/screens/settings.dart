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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:common_games/reminders/alarm_scheduler.dart';
import 'package:common_games/reminders/anchor_detector.dart';
import 'package:common_games/screens/settings_restore.dart';
import 'package:common_games/services/reminder_service.dart';
import 'package:common_games/services/settings_service.dart';
import 'package:common_games/theme/app_theme.dart';
import 'package:common_games/widgets/reliability_banner.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            ReliabilityBanner.fromService(
              key: const ValueKey<String>('settings.reliability_banner'),
            ),
            const SizedBox(height: Spacing.md),
            const _SectionHeader('Appearance'),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: SettingsService.instance.themeMode,
              builder: (_, mode, _) => _ThemeModeTile(
                mode: mode,
                onChanged: (m) => SettingsService.instance.themeMode.value = m,
              ),
            ),
            const SizedBox(height: Spacing.md),
            const _SectionHeader('Wake-up anchor'),
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
            const _SectionHeader('Reliability'),
            _ReliabilityRow(
              reliability: ReminderService.instance.scheduler.reliability,
            ),
            const SizedBox(height: Spacing.md),
            const _SectionHeader('Backup'),
            ListTile(
              key: const ValueKey('settings.restore'),
              leading: const Icon(Icons.restore_outlined),
              title: const Text('Restore from backup'),
              subtitle: const Text('Pick a Streak .json backup file.'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsRestoreScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: Spacing.lg),
            const _SectionHeader('About'),
            const ListTile(
              title: Text('Streak'),
              subtitle: Text('v0.1.0 — local-only.'),
              dense: true,
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
    return RadioGroup<ThemeMode>(
      groupValue: mode,
      onChanged: (m) {
        if (m != null) onChanged(m);
      },
      child: Column(
        children: [
          for (final entry in const [
            (ThemeMode.dark, 'Dark'),
            (ThemeMode.light, 'Light'),
            (ThemeMode.system, 'System'),
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
    return RadioGroup<AnchorMode>(
      groupValue: mode,
      onChanged: (m) {
        if (m != null) onChanged(m);
      },
      child: Column(
        children: [
          for (final entry in const [
            (AnchorMode.manual, 'Manual — I tap "I\'m up"'),
            (AnchorMode.firstUnlock, 'First unlock of the day'),
            (AnchorMode.either, 'Either, with confirmation'),
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
    final label = switch (reliability) {
      Reliability.optimal => 'Optimal — exact alarm granted.',
      Reliability.degraded => 'Degraded — using WorkManager fallback.',
      Reliability.unknown => 'Unknown — first launch, probe pending.',
    };
    return ListTile(
      leading: const Icon(Icons.notifications_active_outlined),
      title: const Text('Reminder reliability'),
      subtitle: Text(label),
      onTap: HapticFeedback.selectionClick,
    );
  }
}
