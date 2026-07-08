// v1.8-14 / SYS-188 / WF-115: 48dp minimum touch target
// assertions for the canonical CTA primitives.
//
// Per `.claude/rules/lib-screens.md` every interactive element
// must be ≥ 48dp × 48dp. This file pins the three primitives
// most likely to regress the rule (icon-only CTA, primary
// CTA, raw `IconButton` w/o our theme). A regression here
// usually means:
//   - the `IconButtonTheme` was removed from `AppTheme._build()`
//   - the `minimumSize` was dropped from `FilledButtonTheme`
//   - a new `TextButton` call site was added that did not
//     route through `SecondaryButton` (which applies the
//     `Size(0, 48)` minimumSize inline).
//
// Test cases pin:
//   - AppIconButton inherits the 48dp minimum from the
//     project `IconButtonTheme` (regression of PR3 / v1.8-03).
//   - PrimaryButton inherits the 48dp minimum from the
//     project `FilledButtonTheme` (regression of PR1 /
//     v1.8-01).
//   - Raw `IconButton` (no wrapper) also gets the 48dp
//     minimum from the project theme — this is the safety
//     net that lets a one-off `IconButton(...)` call site
//     still meet the a11y bar if a future PR adds one
//     outside the AppIconButton migration.

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/icon_button.dart';
import 'package:doit/ui/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppIconButton — 48dp touch target (v1.8-14 / SYS-188)', () {
    testWidgets('icon-only CTA is ≥ 48dp × 48dp via project IconButtonTheme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: AppIconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(IconButton));
      expect(
        size.height,
        greaterThanOrEqualTo(48),
        reason:
            'AppIconButton height ${size.height} dropped below 48dp minimum '
            '— check the IconButtonTheme in AppTheme._build()',
      );
      expect(
        size.width,
        greaterThanOrEqualTo(48),
        reason: 'AppIconButton width ${size.width} dropped below 48dp minimum',
      );
    });

    testWidgets('raw IconButton (no wrapper) inherits 48dp from theme', (
      tester,
    ) async {
      // Regression pin: if a future PR drops the project
      // `IconButtonTheme(minimumSize: Size(48, 48))` from
      // `AppTheme._build()`, raw `IconButton` calls
      // (outside the AppIconButton primitive) would shrink
      // to the M3 default of 40×40 — below the 48dp bar.
      // This test catches that regression loudly.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(IconButton));
      expect(
        size.height,
        greaterThanOrEqualTo(48),
        reason:
            'raw IconButton height ${size.height} dropped below 48dp — the '
            'project IconButtonTheme in AppTheme._build() was likely removed',
      );
      expect(
        size.width,
        greaterThanOrEqualTo(48),
        reason:
            'raw IconButton width ${size.width} dropped below 48dp — the '
            'project IconButtonTheme in AppTheme._build() was likely removed',
      );
    });
  });

  group('PrimaryButton — 48dp touch target (v1.8-14 / SYS-188)', () {
    testWidgets('filled CTA is ≥ 48dp tall via project FilledButtonTheme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: PrimaryButton(onPressed: () {}, label: const Text('Save')),
            ),
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(PrimaryButton));
      expect(
        size.height,
        greaterThanOrEqualTo(48),
        reason:
            'PrimaryButton height ${size.height} dropped below 48dp minimum '
            '— check the FilledButtonTheme in AppTheme._build()',
      );
    });
  });
}
