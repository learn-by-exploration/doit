import 'package:doit/do/do.dart';
import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// Compact, accessible badge that surfaces the v1.4l tombstone
/// semantics (`ADR-056`) at the UI layer for a `DoAnchor` do
/// whose target habit has been soft-deleted (or hard-deleted —
/// the cycle stays screen-correct either way: the anchor fires
/// no reminders and the tile tells the user why).
///
/// **Visibility contract.** The widget self-determines
/// visibility from the resolved `Do` parameter. The home tile
/// at `lib/screens/home.dart` passes the lookup result
/// (`_targetHabit`) and the gate `isDeleted`; the badge does
/// NOT issue its own `DoRepository` call (the lookup is owned
/// by the parent — keeps the badge pure-presentational +
/// trivially testable).
///
/// v1.4-stab-G / Phase 47 / SYS-134 / ADR-065 / WF-062.
class DoAnchorTargetPausedBadge extends StatelessWidget {
  /// Default constructor. The widget takes the *resolved*
  /// target habit (the cached lookup result on
  /// `_HabitTileState._targetHabit`). The widget itself does
  /// NOT call `DoRepository.getById`; the parent does.
  ///
  /// [habitId] is required for the `KeyedSubtree` test seam
  /// (`Key('doAnchorTargetPaused-<id>')`) so widget tests can
  /// locate the badge without exposing the private widget.
  /// **Visibility gate.** Renders only when
  /// [target] is non-null AND `target.isDeleted == true`.
  /// The widget draws NOTHING in the un-paused case — the
  /// tile rebuild path picks up the change in < 1 frame.
  const DoAnchorTargetPausedBadge({
    super.key,
    required this.habitId,
    this.target,
  });

  /// The anchor's habit id (the `DoAnchor.id`, NOT the
  /// target's id). Used by `KeyedSubtree` for the widget-test
  /// seam — see SYS-134 + ADR-065.
  final String habitId;

  /// The resolved target. May be `null` (target row missing
  /// entirely — never existed, hard-deleted from DB, or the
  /// lookup raced the parent's `_refresh()`). The badge
  /// renders when this is non-null AND `isDeleted == true`.
  final Do? target;

  @override
  Widget build(BuildContext context) {
    final t = target;
    if (t == null) return const SizedBox.shrink();
    if (!t.isDeleted) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = theme.colorScheme.tertiary;
    return KeyedSubtree(
      key: Key('doAnchorTargetPaused-$habitId'),
      child: Semantics(
        label: l.doAnchorTargetPaused,
        button: false,
        readOnly: true,
        child: Tooltip(
          message: l.doAnchorTargetPausedHelp,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_off, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  l.doAnchorTargetPaused,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
