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
/// [light]. The `StreakApp` widget picks one based on
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
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, Sizing.tapMin),
        ),
      ),
    );
  }
}
