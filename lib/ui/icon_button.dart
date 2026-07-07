// `AppIconButton` — the canonical icon-only CTA.
//
// Wraps `Material.IconButton` with the project's M3 defaults.
// Per `.claude/rules/lib-screens.md` every interactive element
// is ≥ 48dp × 48dp; `Material.IconButton` already provides the
// 48dp `minimumSize` by default (via `IconButtonThemeData`),
// so AppIconButton inherits it free (unlike SecondaryButton
// which needs inline `ButtonStyle(minimumSize: Size(0, 48))`
// because `textButtonTheme` is NOT set in `AppTheme._build()`).
//
// The tooltip parameter wraps the icon in the standard
// `IconButton` `tooltip:` affordance (long-press / TalkBack
// reads the message).
//
// Third primitive extracted during the UI-consolidation
// sprint (Month 1 / 2026-07-20..08-03), following
// `PrimaryButton` (PR1) and `SecondaryButton` (PR2). See:
//   - SYS-168 (this PR)
//   - ADR-099 (the C8 icon-set + C9 a11y rationale)
//   - WF-096 (this cycle's batch + coverage closure)
//   - lib/ui/primary_button.dart (sibling — Save/OK)
//   - lib/ui/secondary_button.dart (sibling — Cancel/Back)

import 'package:flutter/material.dart';

/// The canonical icon-only CTA. Use for AppBar action buttons
/// (Refresh, Search, Settings) and per-row list actions
/// (Restore, Delete, Edit) — anywhere a screen renders a tappable
/// icon as the primary affordance.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  /// The icon widget. Typically `Icon(Icons.xxx)`.
  final Widget icon;

  /// Tap handler. `null` disables the button.
  final VoidCallback? onPressed;

  /// Tooltip shown on long-press (and read by TalkBack).
  /// If null, no tooltip is rendered.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: icon, onPressed: onPressed, tooltip: tooltip);
  }
}
