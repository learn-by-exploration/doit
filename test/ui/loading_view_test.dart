// Widget tests for `lib/ui/loading_view.dart`.
//
// Covers the C5 form-pattern primitive (canonical loading
// indicator with full-area + inline variants) extracted
// during the Month 1 UI-consolidation sprint (PR9 of 15).
// See:
//   - SYS-184 (this PR's surface)
//   - ADR-115 (the rationale + the canonical-pattern call)
//   - WF-111 (this test file)
//   - lib/ui/loading_view.dart (the system under test)
//
// Test cases pin:
//   - full-area variant renders a CircularProgressIndicator.
//   - full-area variant centers the indicator in its parent.
//   - default size is 36dp; default stroke is 4dp.
//   - custom size + stroke parameters are honored.
//   - inline variant renders at 20dp / 2dp by default.
//   - inline variant renders at the requested size + stroke.
//   - the SizedBox wrapper carries the size dimensions.
//   - the widget does NOT impose a dark/light theme of its
//     own (theme is inherited from MaterialApp).
//   - works under light theme (the progress indicator is
//     theme-agnostic at the widget level).
//   - multiple LoadingViews in a single tree render
//     independently (no shared state).
//   - no padding or background wrapper added by the
//     primitive — the caller controls layout.

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget body) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: body),
  );
}

void main() {
  group('LoadingView — full-area default', () {
    testWidgets('renders a CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingView()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('centers the indicator in its parent (Center ancestor)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoadingView()));
      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('defaults to 36dp size and 4dp stroke', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingView()));
      final box = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(LoadingView),
          matching: find.byType(SizedBox),
        ),
      );
      expect(box.width, 36);
      expect(box.height, 36);
      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.strokeWidth, 4);
    });
  });

  group('LoadingView — custom size + stroke', () {
    testWidgets('honors custom size and stroke parameters', (tester) async {
      await tester.pumpWidget(
        _wrap(const LoadingView(size: 48, strokeWidth: 6)),
      );
      final box = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(LoadingView),
          matching: find.byType(SizedBox),
        ),
      );
      expect(box.width, 48);
      expect(box.height, 48);
      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.strokeWidth, 6);
    });

    testWidgets('honors non-default non-inline custom size and stroke', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LoadingView(size: 24, strokeWidth: 3)),
      );
      final box = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(LoadingView),
          matching: find.byType(SizedBox),
        ),
      );
      expect(box.width, 24);
      expect(box.height, 24);
      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.strokeWidth, 3);
    });
  });

  group('LoadingView.inline — in-row variant', () {
    testWidgets('defaults to 20dp size and 2dp stroke', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingView.inline()));
      final box = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(LoadingView),
          matching: find.byType(SizedBox),
        ),
      );
      expect(box.width, 20);
      expect(box.height, 20);
      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.strokeWidth, 2);
    });

    testWidgets('honors custom size and stroke on the inline variant', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LoadingView.inline(size: 16, strokeWidth: 1.5)),
      );
      final box = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(LoadingView),
          matching: find.byType(SizedBox),
        ),
      );
      expect(box.width, 16);
      expect(box.height, 16);
      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.strokeWidth, 1.5);
    });
  });

  group('LoadingView — tree composition', () {
    testWidgets('renders independently when stacked in the same tree', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const Column(children: [LoadingView(), LoadingView.inline()])),
      );
      expect(find.byType(LoadingView), findsNWidgets(2));
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    });

    testWidgets(
      'does NOT add a Padding or background wrapper — caller controls layout',
      (tester) async {
        await tester.pumpWidget(_wrap(const LoadingView()));
        // No Padding above the Center.
        expect(
          find.descendant(
            of: find.byType(LoadingView),
            matching: find.byType(Padding),
          ),
          findsNothing,
        );
        // No Container (no background).
        expect(
          find.descendant(
            of: find.byType(LoadingView),
            matching: find.byType(Container),
          ),
          findsNothing,
        );
      },
    );
  });

  group('LoadingView — theme integration', () {
    testWidgets('renders under light theme (no theme lock-in)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: LoadingView()),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The indicator inherits colorScheme.primary from
      // the active theme; we pin that the spinner is present
      // and the widget compiles — the color itself is
      // framework-managed at paint time.
    });
  });
}
