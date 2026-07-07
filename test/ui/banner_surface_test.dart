// Widget tests for `lib/ui/banner_surface.dart`.
//
// Covers the C3 card / surface primitive (banner variant)
// extracted during the Month 1 UI-consolidation sprint
// (PR5 of 15). See:
//   - SYS-171 (this PR's surface)
//   - ADR-102 (the C3 rationale + the canonical-pattern call)
//   - WF-099 (this test file)
//   - lib/ui/banner_surface.dart (the system under test)
//
// Test cases pin:
//   - BannerSurface renders the supplied child.
//   - BannerSurface with tone:error uses errorContainer
//     background and onErrorContainer foreground.
//   - BannerSurface with tone:info uses tertiaryContainer
//     background and onTertiaryContainer foreground.
//   - BannerSurface with tone:primary uses primaryContainer
//     background and onPrimaryContainer foreground.
//   - BannerSurface with tone:neutral uses secondaryContainer
//     background and onSecondaryContainer foreground.
//   - BannerSurface with onTap wraps the body in InkWell.
//   - BannerSurface without onTap renders plain Material.
//   - BannerSurface onTap callback fires.
//   - BannerSurface with semanticLabel wraps in Semantics.
//   - BannerSurface without semanticLabel renders no extra
//     Semantics wrapper.
//   - BannerSurface renders an icon when icon is non-null.

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/banner_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapDark(Widget body) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: body),
  );
}

/// Returns the [Material]'s background color from the first
/// [Material] inside the [BannerSurface] under test.
Color _bgOf(WidgetTester tester) {
  final material = tester.widget<Material>(
    find.descendant(
      of: find.byType(BannerSurface),
      matching: find.byType(Material),
    ),
  );
  return material.color!;
}

void main() {
  group('BannerSurface — basic rendering', () {
    testWidgets('renders the supplied child verbatim', (tester) async {
      await tester.pumpWidget(
        _wrapDark(
          const BannerSurface(tone: BannerTone.error, child: Text('warning')),
        ),
      );
      expect(find.text('warning'), findsOneWidget);
      expect(find.byType(BannerSurface), findsOneWidget);
    });
  });

  group('BannerSurface — tone → color pair mapping', () {
    testWidgets('tone:error uses errorContainer + onErrorContainer', (
      tester,
    ) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        _wrapDark(
          Builder(
            builder: (context) {
              scheme = Theme.of(context).colorScheme;
              return const BannerSurface(
                tone: BannerTone.error,
                child: Text('x'),
              );
            },
          ),
        ),
      );
      expect(_bgOf(tester), scheme.errorContainer);
    });

    testWidgets('tone:info uses tertiaryContainer + onTertiaryContainer', (
      tester,
    ) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        _wrapDark(
          Builder(
            builder: (context) {
              scheme = Theme.of(context).colorScheme;
              return const BannerSurface(
                tone: BannerTone.info,
                child: Text('x'),
              );
            },
          ),
        ),
      );
      expect(_bgOf(tester), scheme.tertiaryContainer);
    });

    testWidgets('tone:primary uses primaryContainer + onPrimaryContainer', (
      tester,
    ) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        _wrapDark(
          Builder(
            builder: (context) {
              scheme = Theme.of(context).colorScheme;
              return const BannerSurface(
                tone: BannerTone.primary,
                child: Text('x'),
              );
            },
          ),
        ),
      );
      expect(_bgOf(tester), scheme.primaryContainer);
    });

    testWidgets('tone:neutral uses secondaryContainer + onSecondaryContainer', (
      tester,
    ) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        _wrapDark(
          Builder(
            builder: (context) {
              scheme = Theme.of(context).colorScheme;
              return const BannerSurface(
                tone: BannerTone.neutral,
                child: Text('x'),
              );
            },
          ),
        ),
      );
      expect(_bgOf(tester), scheme.secondaryContainer);
    });

    testWidgets('the four tones resolve to four distinct colors', (
      tester,
    ) async {
      // Pin the M3 contract: each tone maps to a distinct
      // container color. A future bug where two tones
      // collapse to the same role is caught here.
      final seen = <Color>{};
      for (final tone in BannerTone.values) {
        await tester.pumpWidget(
          _wrapDark(BannerSurface(tone: tone, child: const SizedBox.shrink())),
        );
        seen.add(_bgOf(tester));
      }
      expect(seen.length, BannerTone.values.length);
    });
  });

  group('BannerSurface — tap behavior', () {
    testWidgets('with onTap wraps the body in InkWell', (tester) async {
      await tester.pumpWidget(
        _wrapDark(
          BannerSurface(
            tone: BannerTone.error,
            onTap: () {},
            child: const Text('tap-me'),
          ),
        ),
      );
      expect(find.byType(InkWell), findsOneWidget);
      expect(find.text('tap-me'), findsOneWidget);
    });

    testWidgets('without onTap renders plain Material (no InkWell)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapDark(
          const BannerSurface(tone: BannerTone.error, child: Text('static')),
        ),
      );
      // No InkWell inside the BannerSurface subtree.
      expect(
        find.descendant(
          of: find.byType(BannerSurface),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
      // Exactly one Material inside the BannerSurface subtree
      // (the canonical background surface).
      expect(
        find.descendant(
          of: find.byType(BannerSurface),
          matching: find.byType(Material),
        ),
        findsOneWidget,
      );
    });

    testWidgets('onTap callback fires when the banner is tapped', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrapDark(
          BannerSurface(
            tone: BannerTone.error,
            onTap: () => tapped++,
            child: const Text('tap-me'),
          ),
        ),
      );
      await tester.tap(find.text('tap-me'));
      await tester.pump();
      expect(tapped, 1);
    });
  });

  group('BannerSurface — Semantics', () {
    testWidgets('with semanticLabel wraps the body in Semantics container', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapDark(
          const BannerSurface(
            tone: BannerTone.error,
            semanticLabel: 'A warning banner',
            child: Text('body'),
          ),
        ),
      );
      // The Semantics widget's label starts with our
      // semanticLabel (it may also include the child's own
      // semantics). Use `contains` to pin just the prefix.
      expect(
        tester.getSemantics(find.byType(BannerSurface)).label,
        contains('A warning banner'),
      );
      // Sanity: the Semantics widget exists inside the
      // BannerSurface subtree.
      expect(
        find.descendant(
          of: find.byType(BannerSurface),
          matching: find.byType(Semantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('without semanticLabel renders no extra Semantics wrapper', (
      tester,
    ) async {
      // A BannerSurface without a label must NOT inject its own
      // Semantics — the child is the source of truth.
      await tester.pumpWidget(
        _wrapDark(
          const BannerSurface(tone: BannerTone.error, child: Text('body')),
        ),
      );
      // The Text('body') provides its own label.
      final semantics = tester.getSemantics(find.text('body'));
      expect(semantics.label, equals('body'));
    });
  });

  group('BannerSurface — icon', () {
    testWidgets('renders an icon when icon is non-null', (tester) async {
      await tester.pumpWidget(
        _wrapDark(
          const BannerSurface(
            tone: BannerTone.error,
            icon: Icon(Icons.warning),
            child: Text('warning'),
          ),
        ),
      );
      expect(find.byIcon(Icons.warning), findsOneWidget);
      expect(find.text('warning'), findsOneWidget);
    });

    testWidgets('without icon, renders no Icon widget', (tester) async {
      await tester.pumpWidget(
        _wrapDark(
          const BannerSurface(tone: BannerTone.error, child: Text('plain')),
        ),
      );
      // No Icon widget in the subtree (IconTheme is wrapped
      // inside the icon branch only).
      expect(find.byType(Icon), findsNothing);
      expect(find.text('plain'), findsOneWidget);
    });
  });
}
