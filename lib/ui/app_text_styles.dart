// `AppTextStyles` — the canonical text-style vocabulary for the
// app. Centralizes the M3 TextTheme + `DoItTypography` extension
// lookups so call sites don't have to repeat the
// `Theme.of(context).textTheme.X?.copyWith(letterSpacing: ...,
// height: ...)` incantation.
//
// Why a static-helper class (not just constants):
//   - The `ThemeExtension<DoItTypography>` needs a `BuildContext`
//     to read. Static constants can't carry context. Each named
//     style takes `context` so the lookup happens once.
//   - The text styles are theme-aware: dark and light themes can
//     have different letterSpacing/height if a future tweak
//     demands it (rare but possible for accessibility modes).
//
// Migration contract:
//   - All call sites that currently use
//     `Theme.of(context).textTheme.<X>` (without copyWith) for
//     structural text (section headers, badges, captions, tile
//     numbers) should switch to the named helper. The result is
//     byte-equivalent at the typography layer but adds the
//     letterSpacing/height from the theme extension.
//   - The few call sites that *do* `copyWith(color: ...)` should
//     keep the `copyWith` for the color override and chain it
//     after the helper: `AppTextStyles.X(context).copyWith(color:
//     scheme.primary)`.
//
// Extracted during the Month 1 UI-consolidation sprint
// (PR13 of 15). See:
//   - SYS-187 (this PR's surface)
//   - ADR-118 (the typography rationale + theme-extension call)
//   - WF-114 (the test file)
//   - lib/ui/app_text_styles.dart (the system under test)

import 'package:flutter/material.dart';

import 'package:doit/theme/app_theme.dart';

/// Named text styles. Every method takes [context] so it can
/// resolve `Theme.of(context).textTheme` and the
/// `DoItTypography` extension.
///
/// The five named categories map to the M3 TextTheme ladder
/// (display / headline / title / body / label) but with the
/// app's letterSpacing + height tokens applied. This is the
/// canonical vocabulary — every primitive and screen should
/// prefer these over raw `Theme.of(context).textTheme.X` access.
abstract class AppTextStyles {
  /// Numeric tile number (streak counters, sparkline values).
  /// Uses M3 `titleLarge` + tabular figures so digits don't
  /// jitter when they change. No letterSpacing/height tweak —
  /// numbers are read positionally.
  static TextStyle streakNumber(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.titleLarge!.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Compact label inside a pill / chip / badge (the
  /// `DoAnchorTargetPausedBadge`, future status chips, etc.).
  /// Uses `labelSmall` + letterSpacing 0.5 + height 1.2 per
  /// the M3 chip-label convention. Pass [color] to override the
  /// inherited foreground.
  ///
  /// **Extension optional.** If the [DoItTypography] theme
  /// extension isn't registered (e.g. in a test that mounts a
  /// plain `MaterialApp()`), the helper falls back to the base
  /// M3 `labelSmall` with no letterSpacing/height tweak.
  static TextStyle badgeLabel(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    final typo = theme.extension<DoItTypography>();
    final base = theme.textTheme.labelSmall!.copyWith(
      letterSpacing: typo?.label.letterSpacing,
      height: typo?.label.height,
    );
    return color == null ? base : base.copyWith(color: color);
  }

  /// Section header title — the default `SectionHeader(compact:
  /// false)` variant. Uses `titleLarge` + letterSpacing 0.15 +
  /// height 1.25. The padding rhythm lives on the primitive
  /// itself (Spacing.sm vertical).
  ///
  /// **Extension optional.** See [badgeLabel] for the fallback
  /// contract.
  static TextStyle sectionHeaderTitle(BuildContext context) {
    final theme = Theme.of(context);
    final typo = theme.extension<DoItTypography>();
    return theme.textTheme.titleLarge!.copyWith(
      letterSpacing: typo?.title.letterSpacing,
      height: typo?.title.height,
    );
  }

  /// Section header title — the compact `SectionHeader(compact:
  /// true)` variant. Uses `titleMedium` + the same letterSpacing
  /// + height as the default. Compact drops the padding, not the
  /// type rhythm.
  static TextStyle sectionHeaderTitleCompact(BuildContext context) {
    final theme = Theme.of(context);
    final typo = theme.extension<DoItTypography>();
    return theme.textTheme.titleMedium!.copyWith(
      letterSpacing: typo?.title.letterSpacing,
      height: typo?.title.height,
    );
  }

  /// Rest-day budget caption + similar small explanatory lines.
  /// Uses `bodySmall` + letterSpacing 0.25 + height 1.4 (the
  /// body rhythm — looser than M3 default 1.0 for readability).
  /// Pass [color] to override the inherited foreground.
  ///
  /// **Extension optional.** See [badgeLabel] for the fallback
  /// contract.
  static TextStyle caption(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    final typo = theme.extension<DoItTypography>();
    final base = theme.textTheme.bodySmall!.copyWith(
      letterSpacing: typo?.body.letterSpacing,
      height: typo?.body.height,
    );
    return color == null ? base : base.copyWith(color: color);
  }
}
