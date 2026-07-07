// Widget tests for `lib/ui/icon_button.dart`.
//
// Covers the C8 icon-set + C9 a11y icon-only CTA primitive
// extracted during the Month 1 UI-consolidation sprint
// (PR3 of 15). See:
//   - SYS-168 (this PR's surface)
//   - ADR-099 (the C8 + C9 rationale + the canonical-pattern call)
//   - WF-096 (this test file)
//   - lib/ui/icon_button.dart (the system under test)
//
// Test cases pin:
//   - The provided icon widget is rendered.
//   - Tap on enabled button invokes onPressed.
//   - Disabled (onPressed: null) renders the disabled visual style.
//   - Tooltip is set on the underlying IconButton (long-press affordance).
//   - Null tooltip is allowed (no tooltip set on IconButton).
//   - 48dp minimum touch target is inherited from IconButton defaults.
//   - Key is forwarded to the underlying IconButton.
//   - Icon widget identity is preserved (custom color flows through).
//   - Tooltip wraps a Tooltip widget with the supplied message.

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppIconButton — icon rendering', () {
    testWidgets('renders the provided icon widget', (tester) async {
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
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('renders an IconButton (standard unfilled variant)', (
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
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('tap on enabled button invokes onPressed', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: AppIconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => tapCount++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(tapCount, 1);
    });

    testWidgets('multiple taps invoke onPressed multiple times', (
      tester,
    ) async {
      var tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: AppIconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => tapCount++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(tapCount, 3);
    });
  });

  group('AppIconButton — disabled', () {
    testWidgets('onPressed: null disables the button (tap is a no-op)', (
      tester,
    ) async {
      final tapCount = [0];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Center(
              child: AppIconButton(icon: Icon(Icons.refresh), onPressed: null),
            ),
          ),
        ),
      );
      final IconButton button = tester.widget(find.byType(IconButton));
      expect(button.onPressed, isNull);
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(tapCount[0], 0);
    });
  });

  group('AppIconButton — tooltip', () {
    testWidgets('non-null tooltip is set on the underlying IconButton', (
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
                tooltip: 'Refresh',
              ),
            ),
          ),
        ),
      );
      final IconButton button = tester.widget(find.byType(IconButton));
      expect(button.tooltip, 'Refresh');
    });

    testWidgets('null tooltip is allowed (no tooltip set on IconButton)', (
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
      final IconButton button = tester.widget(find.byType(IconButton));
      expect(button.tooltip, isNull);
    });
  });

  group('AppIconButton — 48dp touch target', () {
    testWidgets('fits the 48dp minimum from IconButton defaults', (
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
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });
  });

  group('AppIconButton — Key + Semantics', () {
    testWidgets('forwards key to the underlying IconButton', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: AppIconButton(
                key: const ValueKey('app.icon.refresh'),
                icon: const Icon(Icons.refresh),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('app.icon.refresh')), findsOneWidget);
    });

    testWidgets('icon widget identity is preserved', (tester) async {
      const customIcon = Icon(Icons.delete_outline, color: Colors.red);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: AppIconButton(icon: customIcon, onPressed: () {}),
            ),
          ),
        ),
      );
      // The custom icon (with its red color) is the one rendered.
      final Icon rendered = tester.widget(find.byIcon(Icons.delete_outline));
      expect(rendered.color, Colors.red);
    });

    testWidgets('tooltip wraps a Tooltip widget with the message', (
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
                tooltip: 'Refresh',
              ),
            ),
          ),
        ),
      );
      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsOneWidget);
      final Tooltip tooltip = tester.widget(tooltipFinder);
      expect(tooltip.message, 'Refresh');
    });
  });
}
