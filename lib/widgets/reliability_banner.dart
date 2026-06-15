// Reliability banner — a small widget that shows the current
// alarm-system reliability state. Used on the home screen
// and the settings page.
//
// The banner is hidden when reliability is `optimal`. It
// shows a calm, brand-voice line ("Reminders may be late")
// when degraded, with an optional tap-to-fix deep link to
// the settings page.

import 'package:flutter/material.dart';

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/theme/app_theme.dart';

/// The visual surface for the reliability banner. Tap
/// behavior is configurable via [onTap]; if null, the
/// banner is non-interactive.
class ReliabilityBanner extends StatelessWidget {
  const ReliabilityBanner({super.key, required this.reliability, this.onTap});

  final Reliability reliability;
  final VoidCallback? onTap;

  /// Convenience: reads the current reliability from the
  /// initialized [ReminderService] and rebuilds when the
  /// user changes a setting that affects it.
  factory ReliabilityBanner.fromService({Key? key, VoidCallback? onTap}) {
    return ReliabilityBanner(
      key: key,
      reliability: ReminderService.instance.scheduler.reliability,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (reliability == Reliability.optimal) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Reminder reliability degraded',
      button: onTap != null,
      child: Material(
        color: scheme.errorContainer,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    'Reminders may be late. Tap to fix.',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, color: scheme.onErrorContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
