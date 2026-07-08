// do it theme — M3 seed + 4dp grid + spacing tokens.
//
// Extracted from main.dart in Phase 5 so the dark/light pair
// can be reused by widget tests and (in v0.2) swapped at
// runtime by SettingsService.
//
// The pattern is M3's `ColorScheme.fromSeed` with the brand
// seed; the spacing tokens follow the 4dp grid per
// docs/design/03-design-system.md § Spacing tokens.

import 'package:flutter/material.dart';

/// Linear interpolation between two doubles, matching
/// `dart:ui.lerpDouble` semantics. Used by [DoItTypography.lerp]
/// to interpolate the type-rhythm buckets during theme
/// transitions. When either operand is null, the non-null value
/// is returned.
double _lerpDouble(double a, double b, double t) {
  if (a == b || t == 0.0) return a;
  if (t == 1.0) return b;
  return a + (b - a) * t;
}

/// One type-rhythm bucket. The values come from the M3 type
/// scale + the project's "calm but readable" visual language
/// (`docs/v_model/architecture_options.md` § Visual language).
///
/// [letterSpacing] is in logical pixels (the same units as
/// `TextStyle.letterSpacing`). [height] is unitless — Flutter
/// multiplies by the font size to get the line height.
///
/// v1.8-13 / SYS-187 / ADR-118: the values were chosen to read
/// "M3 with a small readability bump" — no dramatic tracking or
/// leading shifts that would diverge from the platform default.
@immutable
class DoItTypographyBucket {
  const DoItTypographyBucket({
    required this.letterSpacing,
    required this.height,
  });

  final double letterSpacing;
  final double height;

  @override
  bool operator ==(Object other) =>
      other is DoItTypographyBucket &&
      other.letterSpacing == letterSpacing &&
      other.height == height;

  @override
  int get hashCode => Object.hash(letterSpacing, height);

  @override
  String toString() =>
      'DoItTypographyBucket(letterSpacing: $letterSpacing, height: $height)';
}

/// The typography ThemeExtension. Holds the letterSpacing + height
/// tokens for each of the 5 M3 type-rhythm categories. Defaults
/// to the values below; a future theme tweak (e.g. an
/// accessibility "larger text" mode) can swap the entire
/// extension in one place.
///
/// Register via `ThemeData(extensions: [DoItTypography()])` —
/// see `AppTheme._build()` below.
///
/// Reading: `Theme.of(context).extension<DoItTypography>()!.body`.
@immutable
class DoItTypography extends ThemeExtension<DoItTypography> {
  const DoItTypography({
    this.display = const DoItTypographyBucket(letterSpacing: 0, height: 1.1),
    this.headline = const DoItTypographyBucket(
      letterSpacing: 0.15,
      height: 1.2,
    ),
    this.title = const DoItTypographyBucket(letterSpacing: 0.15, height: 1.25),
    this.body = const DoItTypographyBucket(letterSpacing: 0.25, height: 1.4),
    this.label = const DoItTypographyBucket(letterSpacing: 0.5, height: 1.2),
  });

  /// Display rhythm (displaySmall / displayMedium / displayLarge).
  final DoItTypographyBucket display;

  /// Headline rhythm (headlineSmall / headlineMedium / headlineLarge).
  final DoItTypographyBucket headline;

  /// Title rhythm (titleSmall / titleMedium / titleLarge).
  final DoItTypographyBucket title;

  /// Body rhythm (bodySmall / bodyMedium / bodyLarge).
  final DoItTypographyBucket body;

  /// Label rhythm (labelSmall / labelMedium / labelLarge).
  final DoItTypographyBucket label;

  @override
  DoItTypography copyWith({
    DoItTypographyBucket? display,
    DoItTypographyBucket? headline,
    DoItTypographyBucket? title,
    DoItTypographyBucket? body,
    DoItTypographyBucket? label,
  }) {
    return DoItTypography(
      display: display ?? this.display,
      headline: headline ?? this.headline,
      title: title ?? this.title,
      body: body ?? this.body,
      label: label ?? this.label,
    );
  }

  @override
  DoItTypography lerp(ThemeExtension<DoItTypography>? other, double t) {
    if (other is! DoItTypography) return this;
    return DoItTypography(
      display: DoItTypographyBucket(
        letterSpacing: _lerpDouble(
          display.letterSpacing,
          other.display.letterSpacing,
          t,
        ),
        height: _lerpDouble(display.height, other.display.height, t),
      ),
      headline: DoItTypographyBucket(
        letterSpacing: _lerpDouble(
          headline.letterSpacing,
          other.headline.letterSpacing,
          t,
        ),
        height: _lerpDouble(headline.height, other.headline.height, t),
      ),
      title: DoItTypographyBucket(
        letterSpacing: _lerpDouble(
          title.letterSpacing,
          other.title.letterSpacing,
          t,
        ),
        height: _lerpDouble(title.height, other.title.height, t),
      ),
      body: DoItTypographyBucket(
        letterSpacing: _lerpDouble(
          body.letterSpacing,
          other.body.letterSpacing,
          t,
        ),
        height: _lerpDouble(body.height, other.body.height, t),
      ),
      label: DoItTypographyBucket(
        letterSpacing: _lerpDouble(
          label.letterSpacing,
          other.label.letterSpacing,
          t,
        ),
        height: _lerpDouble(label.height, other.label.height, t),
      ),
    );
  }
}

// End of `DoItTypography` ThemeExtension definition. The
// `AppTheme._build()` helper below registers the extension on
// both the dark and light `ThemeData` instances.

/// do it brand seed. A muted purple — calm, slightly
/// stubborn. Used by both light and dark.
const Color streakSeed = Color(0xFF6750A4);

/// 4dp grid spacing tokens. Use these instead of raw
/// `SizedBox(height: 13)`.
abstract class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double huge = 64;
}

/// Minimum touch target. Per .claude/rules/lib-screens.md, the
/// mission primary action is ≥ 64dp; the home "Done" button
/// is ≥ 56dp; everything else is ≥ 48dp.
abstract class Sizing {
  static const double tapMin = 48;
  static const double tapPrimary = 64;
  static const double tapHome = 56;
  static const double huge = 64;
}

/// Centralized theme builder. Two static getters: [dark] and
/// [light]. The `DoItApp` widget picks one based on
/// `SettingsService.themeMode`.
abstract class AppTheme {
  /// Dark theme — do it's default per
  /// docs/v_model/architecture_options.md § Early Design
  /// Decisions.
  static ThemeData get dark => _build(Brightness.dark);

  /// Light theme — opt-in via Settings.
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: streakSeed,
      brightness: brightness,
    );
    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        // v1.8-06 / SYS-172 / ADR-103: explicit
        // `scrolledUnderElevation: 1` to calm the M3 default
        // 3dp scroll-under shadow. The lower elevation matches
        // the calm dark-theme visual language (see
        // `docs/v_model/architecture_options.md` § Visual
        // language) and avoids the heavy scrim that flashes
        // when the home / events / person-groups lists scroll
        // under the AppBar.
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, Sizing.tapMin),
        ),
      ),
      // v1.8-13 / SYS-187 / ADR-118: register the typography
      // extension so `Theme.of(context).extension<DoItTypography>()`
      // resolves on both light and dark themes. The default
      // constructor values match `app_text_styles.dart`'s named
      // helpers — see `DoItTypography` for the canonical buckets.
      extensions: const <ThemeExtension<dynamic>>[DoItTypography()],
    );
  }
}
