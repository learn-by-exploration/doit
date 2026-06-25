// Tests for `RoutineOverlayScreen` — the banner widget for
// routine-fired full-screen overlay launches (v1.3d /
// Phase 15 / SYS-114 / ADR-044).
//
// The widget reads `title` / `body` from the constructor
// (which `MaterialApp.onGenerateRoute` populates from the
// `/mission?mode=overlay&title=...&body=...` query
// string). Missing / empty values fall back to a generic
// headline + body. The Dismiss button pops with `null`.

import 'package:doit/screens/routine_overlay_screen.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({String? title, String? body}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: RoutineOverlayScreen(title: title, body: body),
  );
}

void main() {
  testWidgets('renders the title and body from constructor args', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(title: 'Japan silent', body: 'Tap to toggle'),
    );
    await tester.pumpAndSettle();
    // AppBar title shows the headline.
    expect(find.text('Japan silent'), findsOneWidget);
    // Body shows in the detail text.
    expect(find.text('Tap to toggle'), findsOneWidget);
  });

  testWidgets('falls back to generic copy when title and body are null', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.text('Routine alert'), findsOneWidget);
    expect(
      find.text('A routine fired and wants your attention.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'falls back to generic copy when title and body are empty strings',
    (tester) async {
      await tester.pumpWidget(_harness(title: '', body: ''));
      await tester.pumpAndSettle();
      expect(find.text('Routine alert'), findsOneWidget);
      expect(
        find.text('A routine fired and wants your attention.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('the Dismiss button pops the route with null', (tester) async {
    bool? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<bool?>(
                    MaterialPageRoute<bool?>(
                      builder: (_) =>
                          const RoutineOverlayScreen(title: 't', body: 'b'),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutineOverlayScreen), findsOneWidget);
    // Tap the Dismiss button (the only FilledButton).
    await tester.tap(find.byKey(const ValueKey('routineOverlay.dismiss')));
    await tester.pumpAndSettle();
    // The route popped with `null`.
    expect(find.byType(RoutineOverlayScreen), findsNothing);
    expect(popped, isNull);
  });
}
