// Streak recovery card — one-shot card that surfaces when
// the user has missed 3+ consecutive habit completions.
//
// v1.2j / Phase 10 / SYS-106. The home screen is the
// first surface the user sees on app open. When the
// consecutive-counter reports a broken streak with 3 or
// more missed days, this card slides in with a calm, brand-
// voice "I'm back" CTA that resumes the next habit
// occurrence (the schedule engine's `nextOccurrence` from
// the most recent schedule kind — the user does not need
// to pick; the next slot is the obvious one). Tapping
// "Dismiss" hides the card for the rest of the day; the
// next missed-consecutive threshold starts fresh.
//
// The card is purely visual; the consecutive-counter
// computation lives in
// `lib/do/consecutive_counter.dart` (already shipped). The
// widget reads a `StreakRecoveryState` (habit id +
// missed-days count + habit label + next slot) and rebuilds
// on changes via a `ValueListenableBuilder`.

import 'package:flutter/material.dart';

import 'package:doit/theme/app_theme.dart';

/// What the user needs to know to act on the recovery
/// card. Computed by the home-screen binding — the
/// widget itself only renders.
@immutable
class StreakRecoveryState {
  const StreakRecoveryState({
    required this.habitId,
    required this.habitLabel,
    required this.missedDays,
    required this.nextSlotLabel,
  });

  final String habitId;
  final String habitLabel;
  final int missedDays;
  final String nextSlotLabel;

  @override
  bool operator ==(Object other) =>
      other is StreakRecoveryState &&
      other.habitId == habitId &&
      other.habitLabel == habitLabel &&
      other.missedDays == missedDays &&
      other.nextSlotLabel == nextSlotLabel;

  @override
  int get hashCode =>
      Object.hash(habitId, habitLabel, missedDays, nextSlotLabel);
}

/// The visual surface for the streak recovery card. Renders
/// `SizedBox.shrink()` when [state] is `null`.
class StreakRecoveryCard extends StatelessWidget {
  const StreakRecoveryCard({
    super.key,
    required this.state,
    this.onResume,
    this.onDismiss,
  });

  final StreakRecoveryState? state;
  final VoidCallback? onResume;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    return Semantics(
      label:
          'Streak broken: ${s.habitLabel} missed ${s.missedDays} days in a row.',
      container: true,
      child: Material(
        color: scheme.tertiaryContainer,
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
                    Icons.calendar_today_outlined,
                    color: scheme.onTertiaryContainer,
                    semanticLabel: 'Streak broken',
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      'Streak broken on ${s.habitLabel}',
                      style: theme.titleSmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                  if (onDismiss != null)
                    IconButton(
                      key: ValueKey(
                        'streak_recovery_card.dismiss.${s.habitId}',
                      ),
                      icon: Icon(
                        Icons.close,
                        color: scheme.onTertiaryContainer,
                        semanticLabel: 'Dismiss recovery card',
                      ),
                      onPressed: onDismiss,
                    ),
                ],
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                '${s.missedDays} days missed. Jump back in at '
                '${s.nextSlotLabel}.',
                style: theme.bodySmall?.copyWith(
                  color: scheme.onTertiaryContainer,
                ),
              ),
              if (onResume != null) ...[
                const SizedBox(height: Spacing.xs),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton(
                    key: ValueKey('streak_recovery_card.resume.${s.habitId}'),
                    onPressed: onResume,
                    child: const Text("I'm back"),
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
