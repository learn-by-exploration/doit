// DST transition banner — one-shot card that surfaces
// habit times that get silently dropped during a clock
// change.
//
// v1.2j / Phase 10 / SYS-105. When the device enters or
// leaves DST (e.g., 02:30 on spring-forward morning in
// America/Los_Angeles never exists), the schedule engine
// computes a `nextOccurrence` that lands on a different
// hour — usually the nearest valid local time after the
// drop. The user has no in-app signal that this happened
// unless they happen to look at the home screen. v1.2j
// adds a single dismissable banner that names the dropped
// times and the action taken (rescheduled to <next valid
// local time>).
//
// The banner is purely visual; the actual reschedule lives
// in `ReminderService.rescheduleAll` (invoked by the
// Kotlin `BootReceiver` on `ACTION_TIMEZONE_CHANGED` per
// the v0.5e / notification-reliability doc). The widget
// reads from a small `DstTransitionState` `ValueListenable`
// on the reminder service; the service writes the state
// once when it computes the dropped-times list and clears
// it when the user taps "Dismiss" or when the reschedule
// has been acknowledged.

import 'package:flutter/material.dart';

import 'package:doit/theme/app_theme.dart';

/// One dropped habit time. The label is what the user sees
/// on the home tile (e.g., "02:30 AM"); `rescheduledTo` is
/// the nearest valid local time after the drop (e.g.,
/// "03:30 AM" — i.e., the offset is preserved across the
/// spring-forward).
@immutable
class DstDroppedTime {
  const DstDroppedTime({
    required this.habitId,
    required this.label,
    required this.rescheduledTo,
  });

  final String habitId;
  final String label;
  final String rescheduledTo;

  @override
  bool operator ==(Object other) =>
      other is DstDroppedTime &&
      other.habitId == habitId &&
      other.label == label &&
      other.rescheduledTo == rescheduledTo;

  @override
  int get hashCode => Object.hash(habitId, label, rescheduledTo);
}

/// The visual surface for the DST transition banner. Renders
/// `SizedBox.shrink()` when [drops] is empty. Tap "Dismiss"
/// to clear the banner; tap "Reschedule now" to force the
/// reminder service to re-run `rescheduleAll` (rare — the
/// Kotlin side does this on `ACTION_TIMEZONE_CHANGED`
/// automatically).
class DstTransitionBanner extends StatelessWidget {
  const DstTransitionBanner({
    super.key,
    required this.drops,
    this.onDismiss,
    this.onRescheduleNow,
  });

  final List<DstDroppedTime> drops;
  final VoidCallback? onDismiss;
  final VoidCallback? onRescheduleNow;

  @override
  Widget build(BuildContext context) {
    if (drops.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    return Semantics(
      label:
          'Daylight saving time changed. ${drops.length} habit time(s) '
          'were rescheduled.',
      container: true,
      child: Material(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: scheme.onSecondaryContainer,
                    semanticLabel: 'Daylight saving time',
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      'Daylight saving changed',
                      style: theme.titleSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  if (onDismiss != null)
                    IconButton(
                      key: const ValueKey('dst_transition_banner.dismiss'),
                      icon: Icon(
                        Icons.close,
                        color: scheme.onSecondaryContainer,
                        semanticLabel: 'Dismiss DST banner',
                      ),
                      onPressed: onDismiss,
                    ),
                ],
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                drops.length == 1
                    ? 'Your "${drops.first.label}" habit was rescheduled '
                          'to ${drops.first.rescheduledTo}.'
                    : '${drops.length} habit times were silently '
                          'rescheduled. Tap a row to review.',
                style: theme.bodySmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              ...drops.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• ${d.label} → ${d.rescheduledTo}',
                    style: theme.bodySmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
              if (onRescheduleNow != null) ...[
                const SizedBox(height: Spacing.xs),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: const ValueKey('dst_transition_banner.reschedule_now'),
                    onPressed: onRescheduleNow,
                    child: const Text('Reschedule now'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
