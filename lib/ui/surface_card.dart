// `SurfaceCard` — the canonical elevated Card surface.
//
// Wraps `Card` with the project's M3 defaults: standard
// `CardTheme.elevation` (so future tweaks land in one place),
// canonical `EdgeInsets.all(Spacing.md)` padding for non-`ListTile`
// content, and an `InkWell` ripple when `onTap` is non-null.
//
// This is the third primitive extracted during the
// UI-consolidation sprint (Month 1 / 2026-07-20..08-03) per the
// 3-month launch roadmap. See:
//   - SYS-171 (this PR)
//   - ADR-102 (the C3-card rationale + the surface-pattern call)
//   - WF-099 (this cycle's batch + coverage closure)
//   - docs/v_model/plan.md § Month 1 Week 3-4
//   - docs/wireframes/UI_ORG_AUDIT.md § C3 (the upstream audit)
//
// Why three card primitives instead of one:
//   - `SurfaceCard` (this file) — generic `Card + Padding` body.
//     Used by list/grid items that DO NOT manage selection state.
//   - `TileSurface` — the per-tile accent-color tint (Material +
//     InkWell + Padding + accent-color background). Used by home
//     tiles + category chips.
//   - `BannerSurface` — full-width banner with `tone: BannerTone`
//     (error / info / tertiary / primary). Adds the missing
//     `Semantics` wrapper that `_Banner*` widgets inconsistently
//     provide today.

import 'package:flutter/material.dart';

import 'package:doit/theme/app_theme.dart';

/// The canonical elevated surface card. Renders a `Card`
/// with a uniform `EdgeInsets.all(Spacing.md)` padding and an
/// optional tap ripple.
///
/// **Sizing.** Reads `cardTheme.elevation` for the elevation
/// (so future tweaks land in one place via `AppTheme._build`
/// rather than at every site).
///
/// **Tap behavior.** When [onTap] is non-null, the body is
/// wrapped in `InkWell` with the canonical border-radius
/// (so the ripple follows the card's shape). When null, the
/// body is plain `Card + Padding` with no ripple cost.
///
/// **Accessibility.** Optional [semanticLabel] wraps the body
/// in `Semantics(label: ..., container: true)`. When null,
/// the child supplies its own semantics (the canonical case
/// for `ListTile`-based cards).
class SurfaceCard extends StatelessWidget {
  /// Creates a surface card.
  ///
  /// [child] is the body. [onTap] adds an `InkWell` ripple.
  /// [semanticLabel] wraps the body in `Semantics` (use for
  /// non-`ListTile` cards that need a screen-reader label).
  /// [padding] overrides the canonical `EdgeInsets.all(Spacing.md)`
  /// (use `EdgeInsets.zero` for `ListTile`-based cards where the
  /// tile manages its own internal padding).
  const SurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.padding,
  });

  /// The card body. Typically a `Column`, `Row`, `ListTile`,
  /// or a custom layout.
  final Widget child;

  /// Optional tap handler. When non-null, the card responds
  /// to taps with a ripple. When null, the card is
  /// non-interactive.
  final VoidCallback? onTap;

  /// Optional `Semantics` label. Use for non-`ListTile` cards
  /// that need a screen-reader label. When null, the child
  /// supplies its own semantics.
  final String? semanticLabel;

  /// Optional padding override. When null, the canonical
  /// `EdgeInsets.all(Spacing.md)` is used. Use
  /// `EdgeInsets.zero` for `ListTile`-based cards where the
  /// tile manages its own internal padding.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = padding ?? const EdgeInsets.all(Spacing.md);
    final card = Card(
      child: Padding(padding: p, child: child),
    );
    final body = onTap == null
        ? card
        : Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(padding: p, child: child),
            ),
          );
    if (semanticLabel == null) return body;
    return Semantics(label: semanticLabel, container: true, child: body);
  }
}
