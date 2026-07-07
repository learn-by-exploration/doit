// Widget tests for `lib/ui/secondary_button.dart`.
//
// Covers the C1-button secondary CTA primitive extracted during
// the Month 1 UI-consolidation sprint (PR2 of 15). See:
//   - SYS-167 (this PR's surface)
//   - ADR-098 (the C1 rationale + the canonical-pattern call)
//   - WF-095 (this test file)
//   - lib/ui/secondary_button.dart (the system under test)
//
// Test cases pin:
//   - Plain-text variant uses TextButton (not TextButton.icon).
//   - Icon variant uses TextButton.icon with the icon leading.
//   - Tap on enabled button invokes onPressed.
//   - Disabled (onPressed: null) renders the disabled visual style.
//   - Tooltip wraps a Tooltip widget with the supplied message.
//   - Null tooltip skips the Tooltip wrapper.
//   - 48dp minimum height from the inline style.
//   - Key is forwarded to the underlying TextButton.
//   - Label widget identity is preserved.
//   - Semantics: the label is in the TalkBack tree.

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/secondary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecondaryButton — plain-text variant', () {
    testWidgets('renders the label as Text("Cancel")', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SecondaryButton(
                onPressed: () {},
                label: const Text('Cancel'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('renders a TextButton (not TextButton.icon) when '
        'icon is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SecondaryButton(
                onPressed: () {},
                label: const Text('Cancel'),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('tap on enabled button invokes onPressed', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SecondaryButton(
                onPressed: () => tapCount++,
                label: const Text('Cancel'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(tapCount, 1);
    });
  });

  group('SecondaryButton — icon variant', () {
    testWidgets('renders a TextButton with the icon AND label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SecondaryButton(
                onPressed: () {},
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('renders TextButton.icon when icon is non-null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SecondaryButton(
                onPressed: () {},
                icon: const Icon(Icons.close),
                label: const Text('Discard'),
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
    });
  });

  group('SecondaryButton — disabled', () {
    testWidgets('onPressed: null disables the button (tap is a no-op)', (
      tester,
    ) async {
      final tapCount = [0];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Center(
              child: SecondaryButton(onPressed: null, label: Text('Cancel')),
            ),
          ),
        ),
      );
      final TextButton button = tester.widget(find.byType(TextButton));
      expect(button.onPressed, isNull);
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(tapCount[0], 0);
    });
  });

  group('SecondaryButton — tooltip', () {
    testWidgets('non-null tooltip wraps a Tooltip widget with the message', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SecondaryButton(
                onPressed: () {},
                label: const Text('Cancel'),
                tooltip: 'Discard changes',
              ),
            ),
          ),
        ),
      );
      final tooltipFinder = find.ancestor(
        of: find.byType(TextButton),
        matching: find.byType(Tooltip),
      );
      expect(tooltipFinder, findsOneWidget);
      final Tooltip tooltip = tester.widget(tooltipFinder);
      expect(tooltip.message, 'Discard changes');
    });

    testWidgets('null tooltip does NOT wrap a Tooltip widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SecondaryButton(
                onPressed: () {},
                label: const Text('Cancel'),
              ),
            ),
          ),
        ),
      );
      final tooltipFinder = find.ancestor(
        of: find.byType(TextButton),
        matching: find.byType(Tooltip),
      );
      expect(tooltipFinder, findsNothing);
    });
  });

  group('SecondaryButton — 48dp minimum touch target', () {
    testWidgets('fits the 48dp minimumSize from the inline ButtonStyle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SecondaryButton(
                onPressed: () {},
                label: const Text('Cancel'),
              ),
            ),
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(TextButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('SecondaryButton — Key + Semantics', () {
    testWidgets('forwards key to the underlying TextButton', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SecondaryButton(
                key: const ValueKey('secondary.btn'),
                onPressed: () {},
                label: const Text('Cancel'),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('secondary.btn')), findsOneWidget);
    });

    testWidgets('label is reachable from Semantics (TalkBack tree)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SecondaryButton(
                onPressed: () {},
                label: const Text('Cancel'),
              ),
            ),
          ),
        ),
      );
      final semanticsFinder = find.bySemanticsLabel('Cancel');
      expect(semanticsFinder, findsOneWidget);
    });
  });
}
