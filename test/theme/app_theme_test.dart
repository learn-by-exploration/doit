// Widget tests for `lib/theme/app_theme.dart`.
//
// Covers the C6 nav theme tweak added during the Month 1
// UI-consolidation sprint (PR6 of 15). See:
//   - SYS-172 (this PR's surface)
//   - ADR-103 (the rationale + the canonical-pattern call)
//   - WF-100 (this test file)
//   - lib/theme/app_theme.dart (the system under test)
//
// Test cases pin:
//   - `AppTheme.dark` returns a `ThemeData` with
//     `appBarTheme.scrolledUnderElevation == 1` (the canonical
//     calmer-than-M3-default value per ADR-103).
//   - `AppTheme.light` returns the same scrolledUnderElevation
//     value (the project default applies to both themes).
//   - `AppTheme.dark` returns a `ThemeData` with
//     `appBarTheme.elevation == 0` (the project's long-standing
//     flat AppBar per the v0.1 working assumptions).
//   - `appBarTheme.backgroundColor` resolves to the active
//     ColorScheme's `surface` (the project canonical surface
//     token).
//   - `appBarTheme.foregroundColor` resolves to the active
//     ColorScheme's `onSurface` (the project canonical on-surface
//     token).
//   - `Spacing.sm == 8` (the 4dp grid sanity pin).
//   - `Sizing.tapMin == 48` (the touch-target minimum sanity
//     pin).
//   - `Spacing.md == 16` (the 4dp grid sanity pin).
//   - `streakSeed` is a non-null Color (brand sanity pin).
//   - `AppTheme.dark.useMaterial3 == true` (M3 sanity pin).
//   - `AppTheme.dark.colorScheme.brightness == Brightness.dark`
//     (dark scheme sanity pin).
//   - `AppTheme.light.colorScheme.brightness == Brightness.light`
//     (light scheme sanity pin).

import 'package:doit/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme — AppBar theme', () {
    test('AppTheme.dark.scrolledUnderElevation is 1 (C6 nav tweak)', () {
      expect(AppTheme.dark.appBarTheme.scrolledUnderElevation, 1);
    });

    test('AppTheme.light.scrolledUnderElevation is also 1', () {
      expect(AppTheme.light.appBarTheme.scrolledUnderElevation, 1);
    });

    test('AppTheme.dark.appBarTheme.elevation is 0 (flat AppBar)', () {
      expect(AppTheme.dark.appBarTheme.elevation, 0);
    });

    test(
      'AppTheme.dark.appBarTheme.backgroundColor resolves to scheme.surface',
      () {
        expect(
          AppTheme.dark.appBarTheme.backgroundColor,
          AppTheme.dark.colorScheme.surface,
        );
      },
    );

    test('AppTheme.dark.appBarTheme.foregroundColor resolves to '
        'scheme.onSurface', () {
      expect(
        AppTheme.dark.appBarTheme.foregroundColor,
        AppTheme.dark.colorScheme.onSurface,
      );
    });
  });

  group('AppTheme — scheme sanity', () {
    test('AppTheme.dark uses Brightness.dark', () {
      expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
    });

    test('AppTheme.light uses Brightness.light', () {
      expect(AppTheme.light.colorScheme.brightness, Brightness.light);
    });

    test('AppTheme.dark uses Material 3 (useMaterial3 == true)', () {
      expect(AppTheme.dark.useMaterial3, isTrue);
    });

    test('AppTheme.light uses Material 3 (useMaterial3 == true)', () {
      expect(AppTheme.light.useMaterial3, isTrue);
    });
  });

  group('AppTheme — spacing + sizing tokens (4dp grid)', () {
    test('Spacing.sm == 8', () {
      expect(Spacing.sm, 8);
    });

    test('Spacing.md == 16', () {
      expect(Spacing.md, 16);
    });

    test('Sizing.tapMin == 48', () {
      expect(Sizing.tapMin, 48);
    });

    test('Sizing.tapPrimary == 64 (mission primary action)', () {
      expect(Sizing.tapPrimary, 64);
    });

    test('Sizing.tapHome == 56 (home Done button)', () {
      expect(Sizing.tapHome, 56);
    });
  });

  group('AppTheme — brand sanity', () {
    test('streakSeed is a non-null Color (brand sanity pin)', () {
      // Compile-time check that the brand seed is present.
      // We don't pin the exact RGB because the brand may evolve;
      // the contract is "the seed is a Color, not a placeholder".
      expect(streakSeed, isA<Color>());
    });
  });
}
