// `TileSurface` — the canonical per-tile accent-color surface.
//
// Wraps `Material + InkWell + Padding` with the project's
// per-tile accent-color tint. Centralizes the
// `selected ? 0.30 : 0.12` alpha math that was previously
// inlined in `_HabitTileState._build` and similar tiles.
//
// This is the third-of-three primitives extracted during the
// UI-consolidation sprint (Month 1 / 2026-07-20..08-03) per the
// 3-month launch roadmap. See:
//   - SYS-171 (this PR)
//   - ADR-102 (the C3-card rationale + the surface-pattern call)
//   - WF-099 (this cycle's batch + coverage closure)
//   - docs/v_model/plan.md § Month 1 Week 3-4
//   - docs/wireframes/UI_ORG_AUDIT.md § C3 (the upstream audit)
//
// Sibling primitives:
//   - `SurfaceCard` — generic `Card + Padding` body for non-tile
//     list/grid items.
//   - `BannerSurface` — full-width banner with `tone: BannerTone`
//     (error / info / tertiary / primary). Adds the missing
//     `Semantics` wrapper.

import 'package:flutter/material.dart';

import 'package:doit/theme/app_theme.dart';

/// Canonical alpha values for the selected vs. unselected
/// per-tile tint. The values match the home-tile's pre-PR5
/// inline literals (`0.30` when selected, `0.12` when not) so
/// the migration is byte-for-byte.
abstract class _TileAlphas {
  static const double selected = 0.30;
  static const double unselected = 0.12;
}

/// The canonical per-tile accent-color surface. Renders
/// `Material + InkWell + Padding` with the accent color tinted
/// to [_TileAlphas.selected] when [selected] and
/// [_TileAlphas.unselected] otherwise.
///
/// **Border radius.** The `12dp` radius matches the home
/// tile's pre-PR5 inline literal (and the M3 chip-tile
/// radius family).
///
/// **Padding.** The `Spacing.md` padding matches the home
/// tile's pre-PR5 inline literal.
///
/// **Selection.** [selected] toggles the background alpha.
/// When null (the rare no-selection case), the unselected
/// alpha is used.
///
/// **Tap behavior.** [onTap] is required for the canonical
/// selectable-tile use. [onLongPress] is optional.
class TileSurface extends StatelessWidget {
  /// Creates a per-tile accent-color surface.
  ///
  /// [accent] is the category color (from `CategoryChipResolver`).
  /// [child] is the body. [onTap] adds a tap ripple.
  /// [selected] toggles the background alpha.
  const TileSurface({
    super.key,
    required this.accent,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.selected,
  });

  /// The accent color used to tint the background.
  final Color accent;

  /// The tile body. Typically a `Row` with an icon, label, and
  /// trailing widget.
  final Widget child;

  /// Tap handler. Optional — pass null to render a
  /// non-interactive tile.
  final VoidCallback? onTap;

  /// Optional long-press handler.
  final VoidCallback? onLongPress;

  /// Whether the tile is in the selected state. When null,
  /// the unselected alpha is used.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected ?? false;
    final alpha = isSelected ? _TileAlphas.selected : _TileAlphas.unselected;
    final padding = Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: child,
    );
    final body = (onTap == null && onLongPress == null)
        ? padding
        : InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            onLongPress: onLongPress,
            child: padding,
          );
    return Material(
      color: accent.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(12),
      child: body,
    );
  }
}
