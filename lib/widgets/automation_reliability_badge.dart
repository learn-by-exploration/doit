// AutomationReliabilityBadge — small icon-only badge for the
// trailing slot of a routine list row.
//
// v1.1f / SYS-085. Visual sibling of `ReliabilityBanner`: the
// app-wide banner answers "is the alarm system reliable
// device-wide?"; this badge answers "is THIS specific
// routine's trigger able to fire, given the current runtime
// permissions?".
//
// The badge:
//   - Reads the live `PermissionService.instance.statuses`
//     `ValueNotifier` via `ValueListenableBuilder` so the
//     row reactively updates after the user grants a
//     permission.
//   - Re-uses the same icon + color tokens as
//     `ReliabilityBanner` so the two surfaces share visual
//     language (see `Reliability` enum).
//   - For `optimal` (the common case) renders nothing —
//     keeps the trailing slot uncluttered when there's
//     nothing to say. This matches the `ReliabilityBanner`
//     convention of hiding itself when optimal.
//   - For `degraded` / `unknown` renders a small
//     `IconButton` (≥ 40 × 40 dp touch target) with a
//     Semantics label. Tapping opens a one-line rationale
//     dialog (no navigation; the user is mid-form).

import 'package:flutter/material.dart';

import 'package:doit/routines/automation_reliability.dart';
import 'package:doit/routines/routine.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';

/// Small icon-only badge for the trailing slot of a routine
/// list row. Hides itself for `optimal` routines.
class AutomationReliabilityBadge extends StatelessWidget {
  const AutomationReliabilityBadge({
    super.key,
    required this.automation,
    this.onTap,
  });

  /// The automation whose reliability should be rendered.
  final Automation automation;

  /// Optional callback. If null, the badge is non-interactive
  /// (still shows the icon, just doesn't open a dialog).
  /// In practice the three `_RoutineRow`s pass a callback
  /// that opens an `AlertDialog` with the rationale.
  final VoidCallback? onTap;

  /// The key used in the three add screens (matches the
  /// `ValueKey` convention from `reliability_banner.dart` and
  /// `device_state_row.dart`: `'<screen>.<element>'`).
  static const ValueKey<String> widgetKey = ValueKey<String>(
    'automation.reliability_badge',
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<PermissionKind, PermissionResult?>>(
      valueListenable: PermissionService.instance.statuses,
      builder: (context, statuses, _) {
        final reliability = automationReliability(
          automation,
          statuses: statuses,
        );
        if (reliability == AutomationReliability.optimal) {
          return const SizedBox.shrink();
        }
        final scheme = Theme.of(context).colorScheme;
        final (
          IconData icon,
          Color color,
          String semanticsLabel,
        ) = switch (reliability) {
          AutomationReliability.degraded => (
            Icons.warning_amber_rounded,
            scheme.onErrorContainer,
            'Routine reliability degraded; tap to fix',
          ),
          AutomationReliability.unknown => (
            Icons.info_outline,
            scheme.onSecondaryContainer,
            'Routine reliability unknown; tap to learn more',
          ),
          AutomationReliability.optimal => (
            Icons.check_circle,
            scheme.primary,
            'Routine reliability optimal',
          ),
        };
        return Semantics(
          label: semanticsLabel,
          button: onTap != null,
          child: SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              key: widgetKey,
              tooltip: semanticsLabel,
              icon: Icon(icon, color: color),
              onPressed: onTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ),
        );
      },
    );
  }
}
