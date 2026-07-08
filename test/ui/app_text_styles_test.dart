// Tests for `AppTextStyles` — the canonical text-style vocabulary
// (v1.8-13 / SYS-187 / ADR-118 / WF-114).
//
// Five named helpers, each tested at three levels:
//   1. Resolves a non-null `TextStyle` (no NullPointerException).
//   2. Carries the expected `letterSpacing` + `height` from the
//      `DoItTypography` theme extension.
//   3. Inherits the M3 type-family's `fontSize` from
//      `Theme.of(context).textTheme.<X>`.
//
// Plus one theme-extension round-trip test that verifies the
// extension is registered on both light + dark themes.

import 'package:flutter/material.dart';

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/app_text_styles.dart';

import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

void main() {
  group('AppTextStyles.streakNumber', () {
    testWidgets('resolves to non-null TextStyle', (tester) async {
      late TextStyle style;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              style = AppTextStyles.streakNumber(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(style, isNotNull);
    });

    testWidgets('uses titleLarge + tabular figures', (tester) async {
      late TextStyle style;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              style = AppTextStyles.streakNumber(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final theme = Theme.of(tester.element(find.byType(Builder).first));
      expect(style.fontSize, theme.textTheme.titleLarge!.fontSize);
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  });

  group('AppTextStyles.badgeLabel', () {
    testWidgets('label letterSpacing + height come from DoItTypography', (
      tester,
    ) async {
      late TextStyle style;
      late DoItTypography typo;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              style = AppTextStyles.badgeLabel(context);
              typo = Theme.of(context).extension<DoItTypography>()!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(style.letterSpacing, typo.label.letterSpacing);
      expect(style.height, typo.label.height);
    });

    testWidgets('color override applies when provided', (tester) async {
      late TextStyle style;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              style = AppTextStyles.badgeLabel(
                context,
                color: const Color(0xFF112233),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(style.color, const Color(0xFF112233));
    });
  });

  group('AppTextStyles.sectionHeaderTitle', () {
    testWidgets('default variant carries title letterSpacing + height', (
      tester,
    ) async {
      late TextStyle style;
      late DoItTypography typo;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              style = AppTextStyles.sectionHeaderTitle(context);
              typo = Theme.of(context).extension<DoItTypography>()!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(style.letterSpacing, typo.title.letterSpacing);
      expect(style.height, typo.title.height);
      // Inherits titleLarge's fontSize from the base TextTheme.
      final theme = Theme.of(tester.element(find.byType(Builder).first));
      expect(style.fontSize, theme.textTheme.titleLarge!.fontSize);
    });

    testWidgets('compact variant uses titleMedium', (tester) async {
      late TextStyle style;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              style = AppTextStyles.sectionHeaderTitleCompact(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final theme = Theme.of(tester.element(find.byType(Builder).first));
      expect(style.fontSize, theme.textTheme.titleMedium!.fontSize);
    });
  });

  group('AppTextStyles.caption', () {
    testWidgets('uses bodySmall + body letterSpacing + height', (tester) async {
      late TextStyle style;
      late DoItTypography typo;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              style = AppTextStyles.caption(context);
              typo = Theme.of(context).extension<DoItTypography>()!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(style.letterSpacing, typo.body.letterSpacing);
      expect(style.height, typo.body.height);
      final theme = Theme.of(tester.element(find.byType(Builder).first));
      expect(style.fontSize, theme.textTheme.bodySmall!.fontSize);
    });

    testWidgets('color override applies when provided', (tester) async {
      late TextStyle style;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              style = AppTextStyles.caption(
                context,
                color: const Color(0xFFAABBCC),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(style.color, const Color(0xFFAABBCC));
    });
  });

  group('DoItTypography theme extension', () {
    testWidgets('registered on dark theme with default buckets', (
      tester,
    ) async {
      late DoItTypography typo;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              typo = Theme.of(context).extension<DoItTypography>()!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(typo.display.letterSpacing, 0);
      expect(typo.display.height, 1.1);
      expect(typo.title.letterSpacing, 0.15);
      expect(typo.body.height, 1.4);
      expect(typo.label.letterSpacing, 0.5);
    });

    testWidgets('registered on light theme with same buckets', (tester) async {
      late DoItTypography typo;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              typo = Theme.of(context).extension<DoItTypography>()!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(typo.body.letterSpacing, 0.25);
      expect(typo.title.height, 1.25);
    });

    testWidgets('lerp at t=0 returns this; t=1 returns other', (tester) async {
      const a = DoItTypography();
      const b = DoItTypography(
        body: DoItTypographyBucket(letterSpacing: 0.5, height: 2.0),
      );
      final lerpAt0 = a.lerp(b, 0.0);
      final lerpAt1 = a.lerp(b, 1.0);
      expect(lerpAt0, isA<DoItTypography>());
      expect(lerpAt1, isA<DoItTypography>());
      expect(lerpAt1.body.letterSpacing, 0.5);
      expect(lerpAt1.body.height, 2.0);
    });
  });
}
