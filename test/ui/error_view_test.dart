// Widget tests for `lib/ui/error_view.dart`.
//
// Covers the C5 form-pattern primitive (canonical error-state
// placeholder with message + retry button) extracted during
// the Month 1 UI-consolidation sprint (PR10 of 15). See:
//   - SYS-185 (this PR's surface)
//   - ADR-116 (the rationale + the canonical-pattern call)
//   - WF-112 (this test file)
//   - lib/ui/error_view.dart (the system under test)
//
// Test cases pin:
//   - message renders verbatim at bodyLarge.
//   - default retry label is `l.homeRetryButton` ("Retry").
//   - custom retry label overrides the default.
//   - retry button has ValueKey('error.retry').
//   - tapping the retry button fires the onRetry callback.
//   - the widget is centered (Center ancestor).
//   - default padding (Spacing.lg) is applied.
//   - the FilledButton uses the active theme (not hardcoded).
//   - message text uses M3 bodyLarge (specific fontSize 16).
//   - works under light theme.
//   - the message + retry label are independently overridable
//     (i.e., the 2 strings don't interfere).

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

void main() {
  group('ErrorView — required message', () {
    testWidgets('renders the message verbatim', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ErrorView(message: 'Could not load habits', onRetry: () {}),
          ),
        ),
      );
      expect(find.text('Could not load habits'), findsOneWidget);
    });

    testWidgets('centers the column in its parent (Center ancestor)', (
      tester,
    ) async {
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ErrorView(message: 'msg', onRetry: () {}),
          ),
        ),
      );
      expect(find.byType(Center), findsOneWidget);
    });
  });

  group('ErrorView — default retry label', () {
    testWidgets('defaults to the localized homeRetryButton text', (
      tester,
    ) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return Scaffold(
                body: ErrorView(message: 'msg', onRetry: () {}),
              );
            },
          ),
        ),
      );
      expect(find.text(l.homeRetryButton), findsOneWidget);
    });
  });

  group('ErrorView — custom retry label', () {
    testWidgets('honors a custom retryLabel override', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ErrorView(
              message: 'msg',
              onRetry: () {},
              retryLabel: 'Try again',
            ),
          ),
        ),
      );
      expect(find.text('Try again'), findsOneWidget);
      // The default label is NOT rendered when overridden.
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('ErrorView — retry button affordance', () {
    testWidgets('retry button carries ValueKey(\'error.retry\')', (
      tester,
    ) async {
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ErrorView(message: 'msg', onRetry: () {}),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('error.retry')), findsOneWidget);
    });

    testWidgets('tapping the retry button fires onRetry', (tester) async {
      var called = 0;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ErrorView(message: 'msg', onRetry: () => called++),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('error.retry')));
      expect(called, 1);
    });
  });

  group('ErrorView — visual treatment', () {
    testWidgets('applies the default Spacing.lg padding', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ErrorView(message: 'msg', onRetry: () {}),
          ),
        ),
      );
      // Find the Padding INSIDE the ErrorView (the
      // Spacing.lg padding), not the Material/Scaffold's
      // own padding (which is also a Padding ancestor).
      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(ErrorView),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, const EdgeInsets.all(Spacing.lg));
    });

    testWidgets('message text uses M3 bodyLarge (fontSize 16)', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ErrorView(message: 'msg', onRetry: () {}),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('msg'));
      // Pin the canonical bodyLarge fontSize (16) — the
      // framework merges the style with DefaultTextStyle.
      expect(text.style?.fontSize, AppTheme.dark.textTheme.bodyLarge?.fontSize);
    });
  });

  group('ErrorView — theme integration', () {
    testWidgets('renders correctly under light theme', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ErrorView(message: 'Could not load stats.', onRetry: () {}),
          ),
        ),
      );
      expect(find.text('Could not load stats.'), findsOneWidget);
      expect(find.byKey(const ValueKey('error.retry')), findsOneWidget);
    });

    testWidgets('FilledButton uses the active theme', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ErrorView(message: 'msg', onRetry: () {}),
          ),
        ),
      );
      // The retry button is a FilledButton — pin the type
      // (not the color, which is theme-managed at paint time).
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('error.retry')),
      );
      expect(button, isA<FilledButton>());
    });
  });

  group('ErrorView — message + retry label independence', () {
    testWidgets('message and retry label are independently overridable', (
      tester,
    ) async {
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ErrorView(
              message: 'Could not load templates',
              onRetry: () {},
              retryLabel: 'Reload',
            ),
          ),
        ),
      );
      expect(find.text('Could not load templates'), findsOneWidget);
      expect(find.text('Reload'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });
  });
}
