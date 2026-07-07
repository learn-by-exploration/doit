// Canonical semantic color helpers for the doit design system.
//
// Per UI_ORG_AUDIT.md C2 (color palette misuse), the screen +
// widget layers MUST NOT inline hardcoded color literals
// (`Colors.X`, `Color(0xFF...)`) or arbitrary
// `withValues(alpha: ...)` repetitions. Instead, every color
// flows from one of the canonical helpers exposed here:
//
//   - [AppPalette.iconMuted] — a "decorative icon" that stands
//     out less than the primary content. Replaces `Colors.grey`
//     and the M3 `onSurfaceVariant` semantic. Used by empty
//     states and the widget config screen.
//
//   - [AppPalette.mutedTileBackground] — the soft-tinted circle
//     fill behind a per-tile category icon (48×48 background
//     for the habit tile icon). Replaces the
//     `color.withValues(alpha: 0.20)` pattern from `_TileIcon`
//     in `lib/screens/home.dart`.
//
//   - [AppPalette.mutedPillDecoration] — the translucent fill
//     + outlined border `BoxDecoration` for the muted-pill
//     badge surface (e.g. `DoAnchorTargetPausedBadge`). Replaces
//     the `color.withValues(alpha: 0.15)` (fill) and
//     `color.withValues(alpha: 0.5)` (border) pair.
//
// All helpers read from the active M3 `ColorScheme` so dark +
// light themes stay in sync.
//
// PR4 of 15 (UI consolidation). See SYS-170 / ADR-101 / WF-098.

import 'package:flutter/material.dart';

/// Canonical semantic color helpers for the doit design system.
///
/// **Usage rule (per UI_ORG_AUDIT.md C2):**
/// - **DO** call `AppPalette.iconMuted(context)` /
///   `AppPalette.mutedTileBackground(context, accent)` /
///   `AppPalette.mutedPillDecoration(context, accent)`.
/// - **DO NOT** inline `Colors.grey` (or any `Colors.X`) in
///   the screen / widget layer.
/// - **DO NOT** inline `color.withValues(alpha: 0.20)` (or any
///   other alpha literal) outside this file. The three alpha
///   values used by the canonical helpers (0.20 for the tile
///   circle, 0.15 for the pill fill, 0.5 for the pill border)
///   live here as named constants — change them in one place.
///
/// All helpers are `static`; the class is not instantiable.
class AppPalette {
  AppPalette._();

  /// Canonical alpha for the per-tile category icon's muted
  /// background circle (used by `_TileIcon` in `home.dart`).
  /// Tweak in one place; the helper propagates.
  static const double _tileAlpha = 0.20;

  /// Canonical fill alpha for the muted-pill badge (used by
  /// `DoAnchorTargetPausedBadge` and any future "soft status"
  /// pill).
  static const double _pillFillAlpha = 0.15;

  /// Canonical border alpha for the muted-pill badge outline.
  /// Paired with [_pillFillAlpha] for the pill outline + fill.
  static const double _pillBorderAlpha = 0.5;

  /// Canonical border-width for the muted-pill outline (matches
  /// the previous hardcoded `width: 0.5` in
  /// `do_anchor_paused_badge.dart:74`).
  static const double _pillBorderWidth = 0.5;

  /// Canonical border-radius for the muted-pill (matches the
  /// previous hardcoded `BorderRadius.circular(8)` in
  /// `do_anchor_paused_badge.dart:71`).
  static const double _pillRadius = 8;

  /// A "muted" decorative icon color: visible but de-emphasized
  /// relative to the primary content. Replaces `Colors.grey`
  /// (as used by `lib/widget/widget_config_screen.dart:156`)
  /// with the M3-meaningful `colorScheme.onSurfaceVariant`
  /// role. Reacts to the active theme (dark vs light).
  static Color iconMuted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// Returns the soft-tinted background color for a per-tile
  /// category icon (the 48×48 circle behind the icon on home
  /// tiles). The returned color is [accent] at the canonical
  /// [_tileAlpha] (0.20) opacity — same alpha as the prior
  /// `color.withValues(alpha: 0.20)` pattern in
  /// `lib/screens/home.dart`, but exposed here so any future
  /// alpha tweak lands in one place.
  static Color mutedTileBackground(BuildContext context, Color accent) =>
      accent.withValues(alpha: _tileAlpha);

  /// Returns the translucent fill + outlined-border
  /// `BoxDecoration` for the muted-pill badge surface (e.g. the
  /// `DoAnchorTargetPausedBadge` pill). The fill is [accent] at
  /// [_pillFillAlpha] (0.15); the border is [accent] at
  /// [_pillBorderAlpha] (0.5); the radius is [_pillRadius] (8).
  /// Use this in place of inlining the `color.withValues(...)`
  /// pair.
  static BoxDecoration mutedPillDecoration(
    BuildContext context,
    Color accent,
  ) => BoxDecoration(
    color: accent.withValues(alpha: _pillFillAlpha),
    borderRadius: BorderRadius.circular(_pillRadius),
    border: Border.all(
      color: accent.withValues(alpha: _pillBorderAlpha),
      width: _pillBorderWidth,
    ),
  );
}
