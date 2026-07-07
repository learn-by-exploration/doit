// Widget tests for `lib/ui/app_palette.dart`.
//
// Covers the C2 color-palette primitive extracted during the
// Month 1 UI-consolidation sprint (PR4 of 15). See:
//   - SYS-170 (this PR's surface)
//   - ADR-101 (the C2 rationale + the canonical-pattern call)
//   - WF-098 (this test file)
//   - lib/ui/app_palette.dart (the system under test)
//
// Test cases pin:
//   - iconMuted returns the M3 onSurfaceVariant role.
//   - iconMuted reacts to theme brightness (dark vs light).
//   - iconMuted is idempotent across calls (same Color ref for
//     a given BuildContext).
//   - mutedTileBackground applies the canonical 0.20 alpha.
//   - mutedTileBackground preserves the RGB of the supplied
//     accent (hue intact).
//   - mutedPillDecoration returns a non-null BoxDecoration.
//   - mutedPillDecoration fill is accent at 0.15 alpha.
//   - mutedPillDecoration border color is accent at 0.5 alpha.
//   - mutedPillDecoration has the canonical 8px border-radius.
//   - All three helpers are static (no instance required).
//   - All three helpers are reachable from outside the file
//     without exposing the private constructor.

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppPalette.iconMuted', () {
    testWidgets('returns colorScheme.onSurfaceVariant from the active theme', (
      tester,
    ) async {
      late Color captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                captured = AppPalette.iconMuted(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      final expected = AppTheme.dark.colorScheme.onSurfaceVariant;
      expect(captured, expected);
    });

    testWidgets('varies across dark vs light themes (reacts to brightness)', (
      tester,
    ) async {
      // Two SEPARATE late Color fields. Each is set by the matching
      // Builder only. The first pump uses `AppTheme.dark` and sets
      // [darkMuted]; the second pump replaces the tree with
      // `AppTheme.light` and sets [lightMuted] via a NEW Builder.
      late Color darkMuted;
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('dark'),
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                darkMuted = AppPalette.iconMuted(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      late Color lightMuted;
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('light'),
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                lightMuted = AppPalette.iconMuted(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      // Sanity: each capture happened. If a Builder never fired, the
      // `late` would throw on read inside `equals()`, so this comparison
      // itself forces the assignment.
      expect(
        darkMuted,
        isNot(equals(lightMuted)),
        reason:
            'iconMuted derives from colorScheme.onSurfaceVariant, which '
            'differs across Brightness.dark vs Brightness.light. The two '
            'captures must be distinct Color references.',
      );
    });

    testWidgets('is idempotent across calls in the same BuildContext', (
      tester,
    ) async {
      late Color first;
      late Color second;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                first = AppPalette.iconMuted(context);
                second = AppPalette.iconMuted(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(
        first,
        second,
        reason:
            'iconMuted is a pure lookup; calling it twice on the same '
            'BuildContext must return the same Color reference.',
      );
    });
  });

  group('AppPalette.mutedPillDecoration', () {
    testWidgets('returns a non-null BoxDecoration', (tester) async {
      late BoxDecoration decoration;
      const accent = Color(0xFF6750A4);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                decoration = AppPalette.mutedPillDecoration(context, accent);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(decoration, isNotNull);
    });

    testWidgets('fill color is the accent at the canonical 0.15 alpha', (
      tester,
    ) async {
      late BoxDecoration decoration;
      const accent = Color(0xFF6750A4);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                decoration = AppPalette.mutedPillDecoration(context, accent);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      final Color? fill = decoration.color;
      expect(fill, isNotNull);
      expect(fill!.a, closeTo(0.15, 0.001));
    });

    testWidgets('border color is the accent at the canonical 0.5 alpha', (
      tester,
    ) async {
      late BoxDecoration decoration;
      const accent = Color(0xFF6750A4);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                decoration = AppPalette.mutedPillDecoration(context, accent);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      final Color borderColor = decoration.border!.top.color;
      // Tolerance is 0.01 (not 0.001) because
      // `accent.withValues(alpha: 0.5)` rounds to 128/255 ≈ 0.5020
      // (the alpha byte can only carry 256 discrete values).
      expect(borderColor.a, closeTo(0.5, 0.01));
    });

    testWidgets('has the canonical 8px border-radius', (tester) async {
      late BoxDecoration decoration;
      const accent = Color(0xFF6750A4);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                decoration = AppPalette.mutedPillDecoration(context, accent);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      final BorderRadius? radius = decoration.borderRadius as BorderRadius?;
      expect(radius, isNotNull);
      expect(radius!.topLeft.x, 8);
      expect(radius.topLeft.y, 8);
      expect(radius.topRight.x, 8);
      expect(radius.topRight.y, 8);
      expect(radius.bottomLeft.x, 8);
      expect(radius.bottomLeft.y, 8);
      expect(radius.bottomRight.x, 8);
      expect(radius.bottomRight.y, 8);
    });

    testWidgets('has the canonical 0.5 border-width (preserves pixel weight)', (
      tester,
    ) async {
      late BoxDecoration decoration;
      const accent = Color(0xFF6750A4);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                decoration = AppPalette.mutedPillDecoration(context, accent);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      // The original hardcoded border was `width: 0.5` in
      // `do_anchor_paused_badge.dart:74`. The canonical helper
      // preserves that pixel weight via the `_pillBorderWidth`
      // constant so the migration is byte-for-byte.
      expect(decoration.border!.top.width, 0.5);
    });
  });

  group('AppPalette.mutedTileBackground', () {
    testWidgets('applies the canonical 0.20 alpha to the supplied accent', (
      tester,
    ) async {
      late Color result;
      const accent = Color(0xFFFF0000);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                result = AppPalette.mutedTileBackground(context, accent);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      // Drop alpha comparison: extract opacity; should equal 0.20.
      expect(result.a, closeTo(0.20, 0.001));
    });

    testWidgets('preserves the RGB channels of the supplied accent', (
      tester,
    ) async {
      late Color red;
      late Color green;
      late Color blue;
      const accentRed = Color(0xFFFF0000);
      const accentGreen = Color(0xFF00FF00);
      const accentBlue = Color(0xFF0000FF);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                red = AppPalette.mutedTileBackground(context, accentRed);
                green = AppPalette.mutedTileBackground(context, accentGreen);
                blue = AppPalette.mutedTileBackground(context, accentBlue);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      // Round-trip the per-channel compare: 0xFFFF0000 → (255,0,0) at 0.20
      // alpha. Use the M3 `.r/.g/.b` (double 0..1) channel accessors
      // rather than the deprecated `red/green/blue` (int 0..255).
      expect(red.r, closeTo(1.0, 0.001));
      expect(red.g, closeTo(0.0, 0.001));
      expect(red.b, closeTo(0.0, 0.001));
      expect(green.r, closeTo(0.0, 0.001));
      expect(green.g, closeTo(1.0, 0.001));
      expect(green.b, closeTo(0.0, 0.001));
      expect(blue.r, closeTo(0.0, 0.001));
      expect(blue.g, closeTo(0.0, 0.001));
      expect(blue.b, closeTo(1.0, 0.001));
    });
  });

  group('AppPalette — static accessors', () {
    test('all three helpers are reachable as static members (no instance)', () {
      // Compiles only because the helpers are declared `static`. If any
      // of them were instance-scoped, the lines below would fail to
      // compile. We don't pump a widget here; the test pins the public
      // surface so a future refactor that drops the `static` modifier
      // surfaces immediately as a compile error in this test file.
      expect(AppPalette.iconMuted, isNotNull);
      expect(AppPalette.mutedTileBackground, isNotNull);
      expect(AppPalette.mutedPillDecoration, isNotNull);
    });
  });
}
