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
// The [iconSize] parameter overrides the M3 default 24dp icon
// size. The home tile's per-row buttons (Done / Edit / Delete /
// Skip / Undo) use `Sizing.tapHome / 2` (28dp) for visual
// weight that matches the 56dp touch target. Per the M3 type
// scale, this is a deliberate "primary action in a small
// space" — the 28dp icon in a 56dp target gives a comfortable
// 14dp breathing room on each side.
//
// The [busy] parameter swaps the icon for a 20×20
// `CircularProgressIndicator(strokeWidth: 2)` and disables
// the button. This is the canonical in-flight pattern for
// async ops triggered from an icon button (DB writes, network
// calls, file ops). Callers that need a different busy
// affordance can pass a custom [icon] — `busy` is just
// sugar for the common case.
//
// The tooltip parameter wraps the icon in the standard
// `IconButton` `tooltip:` affordance (long-press / TalkBack
// reads the message).
//
// v1.8-14 / SYS-188 / ADR-119 / WF-115: extended with
// [iconSize] and [busy] parameters. The 4 a11y fixes in PR14
// (adding `tooltip:` to IconButtons that previously had
// none) all migrate to AppIconButton + add the missing
// tooltip in one step.

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
    this.iconSize,
    this.busy = false,
  });

  /// The icon widget. Typically `Icon(Icons.xxx)`. When [busy]
  /// is true, this is replaced with a 20×20
  /// `CircularProgressIndicator(strokeWidth: 2)` regardless of
  /// the supplied icon (the caller can still pass an icon for
  /// the non-busy state).
  final Widget icon;

  /// Tap handler. `null` disables the button. When [busy] is
  /// true, the onPressed is treated as `null` regardless of the
  /// caller's value (defensive: prevents re-entry during an
  /// in-flight async op).
  final VoidCallback? onPressed;

  /// Tooltip shown on long-press (and read by TalkBack).
  /// If null, no tooltip is rendered. **Required for a11y
  /// compliance** on any icon-only CTA (per `.claude/rules/
  /// lib-screens.md:34-39`).
  final String? tooltip;

  /// Optional icon size override. Default is M3's 24dp. The
  /// home tile's per-row buttons use `Sizing.tapHome / 2` (28dp)
  /// for visual weight that matches the 56dp touch target.
  final double? iconSize;

  /// When true, swaps the [icon] for a 20×20 spinner and
  /// disables the button (sets onPressed to null). Use for
  /// in-flight async ops (DB writes, file saves, network
  /// calls). Defaults to false.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final effectiveIcon = busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : icon;
    final effectiveOnPressed = busy ? null : onPressed;
    return IconButton(
      icon: effectiveIcon,
      onPressed: effectiveOnPressed,
      tooltip: tooltip,
      iconSize: iconSize,
    );
  }
}
