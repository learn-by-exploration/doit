// `SecondaryButton` — the canonical cancel/dismiss CTA.
//
// Wraps `TextButton` (or `TextButton.icon` when an icon is
// provided) with the project's M3 defaults. Per
// `.claude/rules/lib-screens.md` every interactive element is
// ≥ 48dp × 48dp; the project's `AppTheme.dark` / `AppTheme.light`
// already enforce the 48dp `minimumSize` on filled-button
// themes. `TextButton` does NOT have a theme-level
// minimumSize default, so SecondaryButton applies
// `ButtonStyle(minimumSize: Size(0, 48))` explicitly.
//
// Second primitive extracted during the UI-consolidation
// sprint (Month 1 / 2026-07-20..08-03), following
// `PrimaryButton` (PR1). See:
//   - SYS-167 (this PR)
//   - ADR-098 (the C1-button rationale)
//   - WF-095 (this cycle's batch + coverage closure)
//   - lib/ui/primary_button.dart (the sibling primitive)

import 'package:flutter/material.dart';

/// The canonical cancel/dismiss CTA. Use for "Cancel", "Back",
/// "Discard", and similar dismiss-without-commit actions in
/// `AlertDialog.actions` lists.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.tooltip,
  });

  /// Tap handler. `null` disables the button.
  final VoidCallback? onPressed;

  /// Button label widget. Typically `Text('Cancel' | 'Back' |
  /// 'Discard')`.
  final Widget label;

  /// Optional leading icon. Renders as `TextButton.icon`.
  /// When null, renders as plain `TextButton`.
  final Widget? icon;

  /// Tooltip shown on long-press (and read by TalkBack).
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(minimumSize: const Size(0, 48));
    final button = icon == null
        ? TextButton(onPressed: onPressed, style: style, child: label)
        : TextButton.icon(
            onPressed: onPressed,
            style: style,
            icon: icon!,
            label: label,
          );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
