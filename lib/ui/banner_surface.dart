// `BannerSurface` — the canonical full-width banner surface.
//
// Wraps `Material + Padding` with the project's
// `tone: BannerTone` palette mapping. Centralizes the
// `scheme.<container> / scheme.on<Container>` background /
// foreground color pair that was previously inlined in
// `ReliabilityBanner`, `StreakRecoveryCard`, and
// `RoutineBanner`.
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
// Sibling primitives:
//   - `SurfaceCard` — generic `Card + Padding` body for non-tile
//     list/grid items.
//   - `TileSurface` — per-tile accent-color tint.

import 'package:flutter/material.dart';

import 'package:doit/theme/app_theme.dart';

/// The four banner tones. Each tone maps to an M3 color role
/// pair (`<X>Container` / `on<X>Container`).
///
/// Why an enum rather than a raw `Color`:
///   - The tone is semantic, not visual. A future brand-tweak
///     to the "error" tone must propagate everywhere; a raw
///     color would silently diverge.
///   - The M3 role pair (`errorContainer` / `onErrorContainer`,
///     `tertiaryContainer` / `onTertiaryContainer`, etc.) is
///     brightness-aware — using the role (not the raw color)
///     means the dark and light themes get the right pair
///     automatically.
enum BannerTone {
  /// Error / reliability-degraded banner. Maps to
  /// `errorContainer` + `onErrorContainer`.
  error,

  /// Info / recovery banner. Maps to
  /// `tertiaryContainer` + `onTertiaryContainer`.
  info,

  /// Primary / routine-action banner. Maps to
  /// `primaryContainer` + `onPrimaryContainer`.
  primary,

  /// Neutral / secondary banner. Maps to
  /// `secondaryContainer` + `onSecondaryContainer`.
  neutral,
}

/// The canonical full-width banner surface. Renders
/// `Material + Padding` with the tone's color pair, an
/// optional leading icon, an optional `Semantics` wrapper, and
/// an optional `InkWell` ripple for tappable banners.
///
/// **Semantics.** When [semanticLabel] is non-null, the body
/// is wrapped in `Semantics(label: ..., container: true)` so
/// TalkBack reads the banner as a single element. When null,
/// the [child] supplies its own semantics (the canonical case
/// when the child already provides row-level semantics).
///
/// **Tap behavior.** [onTap] is the canonical entry point for
/// tappable banners (e.g. reliability banner -> settings). When
/// null, the banner is non-interactive.
class BannerSurface extends StatelessWidget {
  /// Creates a full-width banner surface.
  const BannerSurface({
    super.key,
    required this.tone,
    required this.child,
    this.icon,
    this.onTap,
    this.semanticLabel,
    this.padding,
  });

  /// The banner tone. Drives the background + foreground
  /// color pair.
  final BannerTone tone;

  /// The banner body. Typically a `Row` with an icon, label,
  /// and optional trailing widget.
  final Widget child;

  /// Optional leading icon. When non-null, the body is
  /// wrapped in a `Row` with the icon as the first child
  /// separated by a `Spacing.sm` gap. When null, the [child]
  /// is rendered as-is.
  final Widget? icon;

  /// Optional tap handler. When non-null, the banner
  /// responds to taps with a ripple.
  final VoidCallback? onTap;

  /// Optional `Semantics` label. When non-null, the banner
  /// is wrapped in `Semantics(label: ..., container: true)`
  /// so TalkBack reads it as a single element.
  final String? semanticLabel;

  /// Optional padding override. When null, the canonical
  /// `EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm)`
  /// is used.
  final EdgeInsetsGeometry? padding;

  /// Resolves the tone's color pair to `(background, foreground)`.
  Color _foreground(ColorScheme scheme) {
    switch (tone) {
      case BannerTone.error:
        return scheme.onErrorContainer;
      case BannerTone.info:
        return scheme.onTertiaryContainer;
      case BannerTone.primary:
        return scheme.onPrimaryContainer;
      case BannerTone.neutral:
        return scheme.onSecondaryContainer;
    }
  }

  Color _background(ColorScheme scheme) {
    switch (tone) {
      case BannerTone.error:
        return scheme.errorContainer;
      case BannerTone.info:
        return scheme.tertiaryContainer;
      case BannerTone.primary:
        return scheme.primaryContainer;
      case BannerTone.neutral:
        return scheme.secondaryContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = _background(scheme);
    final fg = _foreground(scheme);
    final p =
        padding ??
        const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        );
    final body = icon == null
        ? Padding(padding: p, child: child)
        : Padding(
            padding: p,
            child: Row(
              children: [
                IconTheme(
                  data: IconThemeData(color: fg),
                  child: icon!,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(child: child),
              ],
            ),
          );
    final interactive = onTap == null
        ? Material(color: bg, child: body)
        : Material(
            color: bg,
            child: InkWell(onTap: onTap, child: body),
          );
    if (semanticLabel == null) return interactive;
    return Semantics(label: semanticLabel, container: true, child: interactive);
  }
}
