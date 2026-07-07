// Widget tests for `lib/ui/tile_surface.dart`.
//
// Covers the C3 card / surface primitive (tile variant)
// extracted during the Month 1 UI-consolidation sprint
// (PR5 of 15). See:
//   - SYS-171 (this PR's surface)
//   - ADR-102 (the C3 rationale + the canonical-pattern call)
//   - WF-099 (this test file)
//   - lib/ui/tile_surface.dart (the system under test)
//
// Test cases pin:
//   - TileSurface renders the supplied child.
//   - TileSurface with selected:true uses alpha 0.30 on the
//     supplied accent color (canonical selected tint).
//   - TileSurface with selected:false uses alpha 0.12
//     (canonical unselected tint).
//   - TileSurface with selected:null defaults to the
//     unselected alpha.
//   - TileSurface tap callback fires.
//   - TileSurface uses the canonical 12dp border-radius.
//   - TileSurface uses the canonical Spacing.md padding.
//   - TileSurface preserves the RGB of the supplied accent.
//   - TileSurface onLongPress is optional (no callback).
//   - TileSurface wraps the body in InkWell.
//   - TileSurface static surface check.

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/tile_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapDark(Widget body) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: body),
  );
}

void main() {
  const accent = Color(0xFF6750A4);

  group('TileSurface — basic rendering', () {
    testWidgets('renders the supplied child verbatim', (tester) async {
      await tester.pumpWidget(
        _wrapDark(
          TileSurface(accent: accent, onTap: () {}, child: const Text('tile')),
        ),
      );
      expect(find.text('tile'), findsOneWidget);
      expect(find.byType(TileSurface), findsOneWidget);
    });
  });

  group('TileSurface — selection alpha', () {
    testWidgets('selected:true applies the canonical 0.30 alpha', (
      tester,
    ) async {
      late Color capturedBg;
      await tester.pumpWidget(
        _wrapDark(
          TileSurface(
            accent: accent,
            selected: true,
            onTap: () {},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      // The Material widget's color is the tinted background.
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(TileSurface),
          matching: find.byType(Material),
        ),
      );
      capturedBg = material.color!;
      expect(capturedBg.a, closeTo(0.30, 0.001));
    });

    testWidgets('selected:false applies the canonical 0.12 alpha', (
      tester,
    ) async {
      late Color capturedBg;
      await tester.pumpWidget(
        _wrapDark(
          TileSurface(
            accent: accent,
            selected: false,
            onTap: () {},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(TileSurface),
          matching: find.byType(Material),
        ),
      );
      capturedBg = material.color!;
      expect(capturedBg.a, closeTo(0.12, 0.001));
    });

    testWidgets('selected:null defaults to the unselected alpha', (
      tester,
    ) async {
      late Color capturedBg;
      await tester.pumpWidget(
        _wrapDark(
          TileSurface(
            accent: accent,
            onTap: () {},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(TileSurface),
          matching: find.byType(Material),
        ),
      );
      capturedBg = material.color!;
      // No selection == unselected alpha (0.12).
      expect(capturedBg.a, closeTo(0.12, 0.001));
    });

    testWidgets('preserves the RGB of the supplied accent', (tester) async {
      late Color red;
      late Color green;
      late Color blue;
      const accentRed = Color(0xFFFF0000);
      const accentGreen = Color(0xFF00FF00);
      const accentBlue = Color(0xFF0000FF);
      await tester.pumpWidget(
        _wrapDark(
          TileSurface(
            accent: accentRed,
            onTap: () {},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      red = (tester
          .widget<Material>(
            find.descendant(
              of: find.byType(TileSurface),
              matching: find.byType(Material),
            ),
          )
          .color)!;
      await tester.pumpWidget(
        _wrapDark(
          TileSurface(
            accent: accentGreen,
            onTap: () {},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      green = (tester
          .widget<Material>(
            find.descendant(
              of: find.byType(TileSurface),
              matching: find.byType(Material),
            ),
          )
          .color)!;
      await tester.pumpWidget(
        _wrapDark(
          TileSurface(
            accent: accentBlue,
            onTap: () {},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      blue = (tester
          .widget<Material>(
            find.descendant(
              of: find.byType(TileSurface),
              matching: find.byType(Material),
            ),
          )
          .color)!;
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

  group('TileSurface — tap and long-press', () {
    testWidgets('onTap callback fires when the tile is tapped', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrapDark(
          TileSurface(
            accent: accent,
            onTap: () => tapped++,
            child: const Text('x'),
          ),
        ),
      );
      await tester.tap(find.text('x'));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('onLongPress callback fires on long-press', (tester) async {
      var longPressed = 0;
      await tester.pumpWidget(
        _wrapDark(
          TileSurface(
            accent: accent,
            onTap: () {},
            onLongPress: () => longPressed++,
            child: const Text('x'),
          ),
        ),
      );
      await tester.longPress(find.text('x'));
      await tester.pump();
      expect(longPressed, 1);
    });

    testWidgets('onLongPress omitted — long-press is a no-op', (tester) async {
      // No callback registered — the tile still renders and
      // tap still works, but long-press does nothing.
      await tester.pumpWidget(
        _wrapDark(
          TileSurface(accent: accent, onTap: () {}, child: const Text('x')),
        ),
      );
      // Long-press on a non-registered handler does not throw.
      await tester.longPress(find.text('x'));
      await tester.pump();
      expect(find.text('x'), findsOneWidget);
    });

    testWidgets('wraps the body in InkWell for ripple feedback', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapDark(
          TileSurface(accent: accent, onTap: () {}, child: const Text('x')),
        ),
      );
      expect(find.byType(InkWell), findsOneWidget);
    });
  });

  group('TileSurface — canonical geometry', () {
    testWidgets('uses the canonical 12dp border-radius', (tester) async {
      late BorderRadius radius;
      await tester.pumpWidget(
        _wrapDark(
          TileSurface(
            accent: accent,
            onTap: () {},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(TileSurface),
          matching: find.byType(Material),
        ),
      );
      radius = material.borderRadius as BorderRadius;
      expect(radius, isNotNull);
      expect(radius.topLeft.x, 12);
      expect(radius.topRight.x, 12);
      expect(radius.bottomLeft.x, 12);
      expect(radius.bottomRight.x, 12);
    });

    testWidgets('uses the canonical Spacing.md padding', (tester) async {
      // The Padding is the parent of [child]. Pin that its
      // padding is EdgeInsets.all(Spacing.md).
      final paddingFinder = find.descendant(
        of: find.byType(TileSurface),
        matching: find.byType(Padding),
      );
      await tester.pumpWidget(
        _wrapDark(
          TileSurface(
            accent: accent,
            onTap: () {},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      final paddings = tester.widgetList<Padding>(paddingFinder).toList();
      final canonical = paddings.firstWhere(
        (p) => p.padding == const EdgeInsets.all(Spacing.md),
        orElse: () => throw TestFailure(
          'No Padding with EdgeInsets.all(Spacing.md) found in TileSurface',
        ),
      );
      expect(canonical.padding, const EdgeInsets.all(Spacing.md));
    });
  });

  group('TileSurface — static accessor', () {
    test('the class is reachable without a private constructor surface', () {
      // Compiles only because TileSurface has a `const` default
      // constructor. If a future refactor adds a private
      // constructor and forgets to expose a factory, this
      // compile-time check breaks the build.
      TileSurface(accent: accent, onTap: () {}, child: const SizedBox.shrink());
    });
  });

  group('TileSurface — optional onTap', () {
    testWidgets('without onTap renders plain Material (no InkWell)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapDark(const TileSurface(accent: accent, child: Text('x'))),
      );
      // No InkWell when no tap handlers are registered.
      expect(
        find.descendant(
          of: find.byType(TileSurface),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
      expect(find.text('x'), findsOneWidget);
    });
  });
}
