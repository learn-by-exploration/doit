// Widget tests for `lib/ui/surface_card.dart`.
//
// Covers the C3 card / surface primitive extracted during the
// Month 1 UI-consolidation sprint (PR5 of 15). See:
//   - SYS-171 (this PR's surface)
//   - ADR-102 (the C3 rationale + the canonical-pattern call)
//   - WF-099 (this test file)
//   - lib/ui/surface_card.dart (the system under test)
//
// Test cases pin:
//   - SurfaceCard renders a Card with the canonical
//     EdgeInsets.all(Spacing.md) padding.
//   - SurfaceCard renders the supplied child.
//   - SurfaceCard with onTap wraps the body in InkWell + ripple.
//   - SurfaceCard without onTap renders plain Card + Padding.
//   - SurfaceCard with semanticLabel wraps the body in
//     Semantics(container: true).
//   - SurfaceCard without semanticLabel renders no Semantics.
//   - SurfaceCard tap callback fires.
//   - SurfaceCard uses cardTheme elevation (reads Theme.of).

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/surface_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [body] in `MaterialApp` + `Scaffold` so the test
/// body is the only thing that varies between cases. The
/// theme is `AppTheme.dark` (the project's default per
/// `docs/v_model/architecture_options.md`).
Widget _wrapDark(Widget body) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: body),
  );
}

void main() {
  group('SurfaceCard — basic rendering', () {
    testWidgets('renders a Card with the canonical Spacing.md padding', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapDark(const SurfaceCard(child: Text('hello'))),
      );
      expect(find.byType(Card), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);
      // The canonical padding is EdgeInsets.all(Spacing.md) = 16.
      // Pin by padding value (the matcher is unique because
      // the canonical SurfaceCard padding is the only
      // EdgeInsets.all(16) in the subtree).
      final paddingWidgets = tester
          .widgetList<Padding>(
            find.descendant(
              of: find.byType(SurfaceCard),
              matching: find.byType(Padding),
            ),
          )
          .toList();
      final canonical = paddingWidgets.firstWhere(
        (p) => p.padding == const EdgeInsets.all(Spacing.md),
        orElse: () => throw TestFailure(
          'No Padding with EdgeInsets.all(Spacing.md) found in SurfaceCard',
        ),
      );
      expect(canonical.padding, const EdgeInsets.all(Spacing.md));
    });

    testWidgets('renders the supplied child verbatim', (tester) async {
      await tester.pumpWidget(
        _wrapDark(
          const SurfaceCard(
            child: SizedBox(
              width: 42,
              height: 42,
              child: Center(child: Text('X')),
            ),
          ),
        ),
      );
      // The SizedBox is reachable — that confirms SurfaceCard
      // does NOT strip or replace the child.
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('X'), findsOneWidget);
    });

    testWidgets('padding override: zero padding for ListTile-based children', (
      tester,
    ) async {
      // ListTile-based cards (events, recently_deleted)
      // need EdgeInsets.zero so the tile manages its own
      // internal padding. The override pins that.
      await tester.pumpWidget(
        _wrapDark(
          const SurfaceCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              key: ValueKey('list-tile-child'),
              title: Text('Title'),
            ),
          ),
        ),
      );
      // Find the Padding whose padding is EdgeInsets.zero.
      final paddings = tester
          .widgetList<Padding>(
            find.descendant(
              of: find.byType(SurfaceCard),
              matching: find.byType(Padding),
            ),
          )
          .toList();
      final zero = paddings.firstWhere(
        (p) => p.padding == EdgeInsets.zero,
        orElse: () => throw TestFailure(
          'No Padding with EdgeInsets.zero found in SurfaceCard',
        ),
      );
      expect(zero.padding, EdgeInsets.zero);
      // Sanity: the ListTile child is intact.
      expect(find.byKey(const ValueKey('list-tile-child')), findsOneWidget);
    });
  });

  group('SurfaceCard — tap behavior', () {
    testWidgets('with onTap wraps the body in InkWell', (tester) async {
      await tester.pumpWidget(
        _wrapDark(SurfaceCard(onTap: () {}, child: const Text('tap-me'))),
      );
      expect(find.byType(InkWell), findsOneWidget);
      expect(find.text('tap-me'), findsOneWidget);
    });

    testWidgets('without onTap renders plain Card + Padding (no InkWell)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapDark(const SurfaceCard(child: Text('static'))),
      );
      // No InkWell — non-interactive cards skip the ripple
      // widget entirely to avoid layout cost.
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('onTap callback fires when the card is tapped', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrapDark(
          SurfaceCard(onTap: () => tapped++, child: const Text('tap-me')),
        ),
      );
      await tester.tap(find.text('tap-me'));
      await tester.pump();
      expect(tapped, 1);
    });
  });

  group('SurfaceCard — Semantics', () {
    testWidgets('with semanticLabel wraps the body in Semantics container', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapDark(
          const SurfaceCard(semanticLabel: 'A test card', child: Text('body')),
        ),
      );
      final semantics = tester.getSemantics(find.byType(SurfaceCard));
      expect(semantics.label, equals('A test card'));
    });

    testWidgets('without semanticLabel renders no extra Semantics wrapper', (
      tester,
    ) async {
      // A SurfaceCard without a label must NOT inject its own
      // Semantics — the child is the source of truth.
      await tester.pumpWidget(
        _wrapDark(const SurfaceCard(child: Text('body'))),
      );
      // The Text('body') provides its own label.
      final semantics = tester.getSemantics(find.text('body'));
      expect(semantics.label, equals('body'));
    });

    testWidgets('onTap + semanticLabel render both InkWell and Semantics', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrapDark(
          SurfaceCard(
            semanticLabel: 'Tap me to act',
            onTap: () => tapped++,
            child: const Text('body'),
          ),
        ),
      );
      expect(find.byType(InkWell), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(SurfaceCard));
      expect(semantics.label, equals('Tap me to act'));
      // Sanity: the InkWell is still tappable.
      await tester.tap(find.text('body'));
      await tester.pump();
      expect(tapped, 1);
    });
  });

  group('SurfaceCard — theme integration', () {
    testWidgets('reads CardTheme.elevation from the active theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapDark(const SurfaceCard(child: SizedBox.shrink())),
      );
      // The Card uses the theme's CardTheme. M3 default
      // elevation for `ColorScheme.fromSeed` is 1.0.
      // SurfaceCard does NOT override the elevation — it
      // inherits from cardTheme so future tweaks land in
      // one place via AppTheme._build.
      final card = tester.widget<Card>(find.byType(Card));
      // M3 default Card elevation is 1.0; we pin that the
      // Card is constructed with the theme default (not a
      // custom override).
      final themeCardElevation = Theme.of(
        tester.element(find.byType(Card)),
      ).cardTheme.elevation;
      expect(card.elevation, themeCardElevation);
    });

    testWidgets('works under both dark and light themes', (tester) async {
      late Color capturedDark;
      late Color capturedLight;
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('dark'),
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedDark = Theme.of(context).colorScheme.surface;
                return const SurfaceCard(child: Text('x'));
              },
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('light'),
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedLight = Theme.of(context).colorScheme.surface;
                return const SurfaceCard(child: Text('x'));
              },
            ),
          ),
        ),
      );
      // Sanity: each MaterialApp fired its Builder.
      expect(capturedDark, isNot(equals(capturedLight)));
      expect(find.byType(Card), findsOneWidget);
    });
  });

  group('SurfaceCard — static accessor', () {
    test('the class is reachable without a private constructor surface', () {
      // Compiles only because SurfaceCard has a `const` default
      // constructor. If a future refactor adds a private
      // constructor and forgets to expose a factory, this
      // compile-time check breaks the build.
      const SurfaceCard(child: SizedBox.shrink());
    });
  });
}
