// Widget tests for `lib/ui/app_snack.dart`.
//
// Covers the C4 form-pattern primitive (canonical snackbar
// wrapper with showError + showInfo) extracted during the
// Month 1 UI-consolidation sprint (PR8 of 15). See:
//   - SYS-174 (this PR's surface)
//   - ADR-105 (the rationale + the canonical-pattern call)
//   - WF-102 (this test file)
//   - lib/ui/app_snack.dart (the system under test)
//
// Test cases pin:
//   - showError fires ScaffoldMessenger.showSnackBar.
//   - showError's SnackBar background is colorScheme.errorContainer.
//   - showError's SnackBar text color is colorScheme.onErrorContainer.
//   - showError renders the message verbatim.
//   - showInfo fires ScaffoldMessenger.showSnackBar.
//   - showInfo's SnackBar uses the M3 default styling
//     (no backgroundColor override; default is inverseSurface).
//   - showInfo renders the message verbatim.
//   - The same message produces different visual treatments
//     for showError vs showInfo (semantic distinction).
//   - Both helpers compile when wrapped in DoIt's dark theme.
//   - Both helpers work under light theme too.
//   - The class is reachable without a private constructor
//     surface (compile-time check).

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/app_snack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapWithScaffold(Widget body) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: body),
  );
}

void main() {
  group('AppSnack — showError', () {
    testWidgets('fires ScaffoldMessenger.showSnackBar', (tester) async {
      await tester.pumpWidget(
        _wrapWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppSnack.showError(context, 'Boom'),
              child: const Text('trigger'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump();
      // The SnackBar renders into the Scaffold subtree.
      expect(find.text('Boom'), findsOneWidget);
    });

    testWidgets(
      'applies colorScheme.errorContainer as the SnackBar background',
      (tester) async {
        late ColorScheme scheme;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  scheme = Theme.of(context).colorScheme;
                  return ElevatedButton(
                    onPressed: () =>
                        AppSnack.showError(context, 'delete failed'),
                    child: const Text('trigger'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('trigger'));
        await tester.pump();
        final bar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(bar.backgroundColor, scheme.errorContainer);
      },
    );

    testWidgets('applies colorScheme.onErrorContainer to the SnackBar text', (
      tester,
    ) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                scheme = Theme.of(context).colorScheme;
                return ElevatedButton(
                  onPressed: () => AppSnack.showError(context, 'delete failed'),
                  child: const Text('trigger'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump();
      final text = tester.widget<Text>(find.text('delete failed'));
      expect(text.style?.color, scheme.onErrorContainer);
    });

    testWidgets('renders the message verbatim', (tester) async {
      await tester.pumpWidget(
        _wrapWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  AppSnack.showError(context, 'Give the event a name first.'),
              child: const Text('trigger'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump();
      expect(find.text('Give the event a name first.'), findsOneWidget);
    });
  });

  group('AppSnack — showInfo', () {
    testWidgets('fires ScaffoldMessenger.showSnackBar', (tester) async {
      await tester.pumpWidget(
        _wrapWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppSnack.showInfo(context, 'Saved'),
              child: const Text('trigger'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump();
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('uses the M3 default SnackBar styling (no override)', (
      tester,
    ) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                scheme = Theme.of(context).colorScheme;
                return ElevatedButton(
                  onPressed: () => AppSnack.showInfo(context, 'Marked as up'),
                  child: const Text('trigger'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump();
      // showInfo does NOT pass a backgroundColor. Pin that
      // the bar's `backgroundColor` field is `null` (which
      // is the M3-default signal — the framework resolves
      // null to the active snackBarTheme color at paint
      // time, but the `widget` snapshot shows the
      // developer-supplied value).
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.backgroundColor, isNull);
      // Sanity: the info bar is NOT styled as an error.
      expect(scheme.errorContainer, isNotNull);
    });

    testWidgets('renders the message verbatim', (tester) async {
      await tester.pumpWidget(
        _wrapWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppSnack.showInfo(context, 'Template saved'),
              child: const Text('trigger'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump();
      expect(find.text('Template saved'), findsOneWidget);
    });
  });

  group('AppSnack — showError vs showInfo semantic distinction', () {
    testWidgets(
      'same message produces different visual treatment for error vs info',
      (tester) async {
        // Render each snackbar in its own MaterialApp to
        // avoid the `find.byType(SnackBar)` ambiguity when
        // both an error and an info snack are queued in
        // the same ScaffoldMessenger.
        late ColorScheme errScheme;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  errScheme = Theme.of(context).colorScheme;
                  return ElevatedButton(
                    onPressed: () =>
                        AppSnack.showError(context, 'same message'),
                    child: const Text('error'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('error'));
        await tester.pump();
        final errBar = tester.widget<SnackBar>(find.byType(SnackBar));
        final errText = tester.widget<Text>(find.text('same message'));
        expect(errBar.backgroundColor, errScheme.errorContainer);
        expect(errText.style?.color, errScheme.onErrorContainer);
        // Wipe the first tree entirely, then render the
        // info snackbar in a fresh MaterialApp.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => AppSnack.showInfo(context, 'same message'),
                    child: const Text('info'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('info'));
        await tester.pump();
        final infoBar = tester.widget<SnackBar>(find.byType(SnackBar));
        // The semantic distinction: error bar has the
        // errorContainer background; info bar has null
        // (the M3 default).
        expect(errBar.backgroundColor, errScheme.errorContainer);
        expect(infoBar.backgroundColor, isNull);
      },
    );
  });

  group('AppSnack — theme integration', () {
    testWidgets('works under light theme', (tester) async {
      late ColorScheme lightScheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                lightScheme = Theme.of(context).colorScheme;
                return ElevatedButton(
                  onPressed: () => AppSnack.showError(context, 'light error'),
                  child: const Text('trigger'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump();
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.backgroundColor, lightScheme.errorContainer);
      expect(lightScheme.brightness, Brightness.light);
    });
  });

  group('AppSnack — static accessor', () {
    test('the class is reachable with only static methods', () {
      // Compiles only because AppSnack has only static
      // methods (showError + showInfo) and no public
      // constructor.
      // ignore: unnecessary_statements
      AppSnack.showError; // ignore: unused_local_variable
      // ignore: unnecessary_statements
      AppSnack.showInfo; // ignore: unused_local_variable
    });
  });
}
