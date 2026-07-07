// `PrimaryButton` — the canonical "Save" / "OK" / "Add contact" CTA.
//
// Wraps `FilledButton` (or `FilledButton.icon` when an icon is
// provided) with the project's M3 defaults. Per
// `.claude/rules/lib-screens.md` every interactive element is
// ≥ 48dp × 48dp; the project's `AppTheme.dark` / `AppTheme.light`
// already enforce the 48dp `minimumSize` via
// `filledButtonTheme`. PrimaryButton therefore inherits the
// size and only standardizes:
//
//   1. The `icon → FilledButton.icon` vs `no icon → FilledButton`
//      branch (so callers don't have to know the constructors).
//   2. The enabled-state transition (`onPressed: null` ⟹ gray).
//   3. A consistent `tooltip` pass-through (for TalkBack).
//
// This is the first primitive extracted during the
// UI-consolidation sprint (Month 1 / 2026-07-20..08-03) per the
// 3-month launch roadmap. See:
//   - SYS-166 (this PR)
//   - ADR-097 (the 15-PR roadmap + the C1-button rationale)
//   - WF-094 (this cycle's batch + coverage closure)
//   - docs/v_model/plan.md § Month 1 Week 3-4
//   - docs/wireframes/UI_ORG_AUDIT.md (the upstream audit)

import 'package:flutter/material.dart';

/// The canonical primary CTA. Use for "Save", "OK", "Add contact",
/// and similar form-submit / destructive-but-confirmable actions.
///
/// Renders [icon] (if non-null) as a leading icon, with [label]
/// as the button text. Disabled when [onPressed] is null.
///
/// Sizing: 48dp minimum (inherited from `filledButtonTheme` in
/// `lib/theme/app_theme.dart`). For 64dp+ mission-CTAs, use
/// the screen-local `SizedBox(height: Sizing.tapPrimary, child: PrimaryButton(...))`.
class PrimaryButton extends StatelessWidget {
  /// Creates a primary CTA. Pass [icon] = null for a plain
  /// text-only "Save" / "OK" / "Add contact"; pass a non-null
  /// [icon] (typically `Icons.add`, `Icons.check`,
  /// `Icons.restore`) for the icon-leading variant.
  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.tooltip,
  });

  /// Tap handler. `null` disables the button.
  final VoidCallback? onPressed;

  /// Button label widget. Typically a `Text('Save' | 'OK')`.
  final Widget label;

  /// Optional leading icon. Renders as `FilledButton.icon`.
  /// When null, renders as plain `FilledButton`.
  final Widget? icon;

  /// Tooltip shown on long-press (and read by TalkBack).
  /// If [tooltip] is null, the [label] is used as the
  /// accessibility label via FilledButton's `Semantics` ancestor.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = icon == null
        ? FilledButton(
            onPressed: onPressed,
            child: label,
          )
        : FilledButton.icon(
            onPressed: onPressed,
            icon: icon!,
            label: label,
          );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
