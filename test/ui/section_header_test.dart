// Widget tests for `lib/ui/section_header.dart`.
//
// Covers the C3 section-header primitive extracted during the
// Month 1 UI-consolidation sprint (PR6 of 15). See:
//   - SYS-172 (this PR's surface)
//   - ADR-103 (the rationale + the canonical-pattern call)
//   - WF-100 (this test file)
//   - lib/ui/section_header.dart (the system under test)
//
// Test cases pin:
//   - SectionHeader renders the supplied title verbatim.
//   - Default variant applies textTheme.titleLarge.
//   - Compact variant applies textTheme.titleMedium.
//   - Default variant wraps the title in a Padding with the
//     canonical EdgeInsets.symmetric(vertical: Spacing.sm).
//   - Compact variant renders no outer Padding.
//   - The Key is forwarded to the underlying widget.
//   - SectionHeader is reachable without a private
//     constructor (compile-time check).
//   - SectionHeader compiles when wrapped in DoIt's dark theme.
//   - SectionHeader works under both dark and light themes
//     (the theme-aware style is applied correctly per theme).
//   - Default variant: titleLarge is non-null in both themes.
//   - Compact variant: titleMedium is non-null in both themes.
//   - The text widget exposes the title through the Semantics
//     tree (TalkBack reads the title).

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/app_text_styles.dart';
import 'package:doit/ui/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapDark(Widget body) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: body),
  );
}

void main() {
  group('SectionHeader — default variant', () {
    testWidgets('renders the supplied title verbatim', (tester) async {
      await tester.pumpWidget(_wrapDark(const SectionHeader('Appearance')));
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.byType(SectionHeader), findsOneWidget);
    });

    testWidgets('applies textTheme.titleLarge from the active theme', (
      tester,
    ) async {
      late TextStyle expected;
      late TextStyle actual;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                // v1.8-13 / SYS-187 / ADR-118: SectionHeader
                // routes through AppTextStyles.sectionHeaderTitle
                // which adds the DoItTypography letterSpacing +
                // height tweaks on top of titleLarge.
                expected = AppTextStyles.sectionHeaderTitle(context);
                return const SectionHeader('Appearance');
              },
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('Appearance'));
      actual = text.style!;
      expect(actual, equals(expected));
    });

    testWidgets(
      'wraps the title in a Padding with the canonical vertical Spacing.sm',
      (tester) async {
        await tester.pumpWidget(_wrapDark(const SectionHeader('Appearance')));
        final paddings = tester
            .widgetList<Padding>(
              find.descendant(
                of: find.byType(SectionHeader),
                matching: find.byType(Padding),
              ),
            )
            .toList();
        final canonical = paddings.firstWhere(
          (p) => p.padding == const EdgeInsets.symmetric(vertical: Spacing.sm),
          orElse: () => throw TestFailure(
            'No Padding with EdgeInsets.symmetric(vertical: '
            'Spacing.sm) found in SectionHeader default variant',
          ),
        );
        expect(
          canonical.padding,
          const EdgeInsets.symmetric(vertical: Spacing.sm),
        );
      },
    );
  });

  group('SectionHeader — compact variant', () {
    testWidgets('applies textTheme.titleMedium from the active theme', (
      tester,
    ) async {
      late TextStyle expected;
      late TextStyle actual;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                // v1.8-13 / SYS-187 / ADR-118: SectionHeader
                // (compact) routes through
                // AppTextStyles.sectionHeaderTitleCompact which adds
                // the DoItTypography letterSpacing + height tweaks on
                // top of titleMedium.
                expected = AppTextStyles.sectionHeaderTitleCompact(context);
                return const SectionHeader('Channel', compact: true);
              },
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('Channel'));
      actual = text.style!;
      expect(actual, equals(expected));
    });

    testWidgets('renders no outer Padding wrapper (compact)', (tester) async {
      await tester.pumpWidget(
        _wrapDark(const SectionHeader('Channel', compact: true)),
      );
      // The compact variant is the bare Text — no Padding
      // ancestor inside the SectionHeader subtree.
      expect(
        find.descendant(
          of: find.byType(SectionHeader),
          matching: find.byType(Padding),
        ),
        findsNothing,
      );
      expect(find.text('Channel'), findsOneWidget);
    });

    testWidgets('compact variant still renders the title verbatim', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapDark(const SectionHeader('Members', compact: true)),
      );
      expect(find.text('Members'), findsOneWidget);
      expect(find.byType(SectionHeader), findsOneWidget);
    });
  });

  group('SectionHeader — Key + Semantics', () {
    testWidgets('Key is forwarded to the widget tree', (tester) async {
      const key = ValueKey<String>('section.appearance');
      await tester.pumpWidget(
        _wrapDark(const SectionHeader('Appearance', key: key)),
      );
      expect(find.byKey(key), findsOneWidget);
    });

    testWidgets('title is exposed through the Semantics tree', (tester) async {
      await tester.pumpWidget(_wrapDark(const SectionHeader('Appearance')));
      // The Text widget provides its own label.
      final semantics = tester.getSemantics(find.text('Appearance'));
      expect(semantics.label, equals('Appearance'));
    });
  });

  group('SectionHeader — theme integration', () {
    testWidgets('default variant renders titleLarge under light theme too', (
      tester,
    ) async {
      late TextStyle lightTitleLarge;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                // v1.8-13 / SYS-187 / ADR-118: the light theme
                // registers the same DoItTypography extension, so
                // SectionHeader resolves the same letterSpacing +
                // height tokens as on dark.
                lightTitleLarge = AppTextStyles.sectionHeaderTitle(context);
                return const SectionHeader('Appearance');
              },
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('Appearance'));
      expect(text.style, equals(lightTitleLarge));
    });

    testWidgets('compact variant renders titleMedium under light theme too', (
      tester,
    ) async {
      late TextStyle lightTitleMedium;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                lightTitleMedium = AppTextStyles.sectionHeaderTitleCompact(
                  context,
                );
                return const SectionHeader('Channel', compact: true);
              },
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('Channel'));
      expect(text.style, equals(lightTitleMedium));
    });
  });

  group('SectionHeader — static accessor', () {
    test('the class is reachable without a private constructor surface', () {
      // Compiles only because SectionHeader has a `const` default
      // constructor. If a future refactor adds a private
      // constructor and forgets to expose a factory, this
      // compile-time check breaks the build.
      const SectionHeader('x');
    });
  });
}
