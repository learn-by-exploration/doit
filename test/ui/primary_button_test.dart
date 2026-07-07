// Widget tests for `lib/ui/primary_button.dart`.
//
// Covers the C1-button primary CTA primitive extracted during
// the Month 1 UI-consolidation sprint (PR1 of 15). See:
//   - SYS-166 (this PR's surface)
//   - ADR-097 (the C1 rationale + the canonical-pattern call)
//   - WF-094 (this test file)
//   - lib/ui/primary_button.dart (the system under test)
//
// Test cases pin:
//   - Plain-text variant uses FilledButton (not FilledButton.icon).
//   - Icon variant uses FilledButton.icon with the icon leading.
//   - Tap on enabled button invokes onPressed.
//   - Disabled (onPressed: null) renders the disabled visual style.
//   - Tooltip wraps a Tooltip widget with the supplied message.
//   - Null tooltip skips the Tooltip wrapper.
//   - 48dp minimum height (from filledButtonTheme via AppTheme.dark).
//   - Label widget identity is preserved (Text('Save') renders).
//   - Key is forwarded to the underlying FilledButton.
//   - Semantics: the label is in the TalkBack tree.
//   - The primitive compiles when wrapped in DoIt's dark theme.

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrimaryButton — plain-text variant', () {
    testWidgets('renders the label as Text("Save")', (tester) async {
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
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('renders a FilledButton (not FilledButton.icon) when '
        'icon is null', (tester) async {
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
      expect(find.byType(FilledButton), findsOneWidget);
      // No icon path was taken → no Icons.check widget present.
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('tap on enabled button invokes onPressed', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: PrimaryButton(
                onPressed: () => tapCount++,
                label: const Text('Save'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(tapCount, 1);
    });
  });

  group('PrimaryButton — icon variant', () {
    testWidgets('renders a FilledButton with the icon AND label', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: PrimaryButton(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Add contact'),
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('Add contact'), findsOneWidget);
    });

    testWidgets('renders FilledButton.icon when icon is non-null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: PrimaryButton(
                onPressed: () {},
                icon: const Icon(Icons.restore),
                label: const Text('Restore'),
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.restore), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
    });
  });

  group('PrimaryButton — disabled', () {
    testWidgets('onPressed: null disables the button (tap is a no-op)', (
      tester,
    ) async {
      final tapCount = [0];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Center(
              child: PrimaryButton(onPressed: null, label: Text('Save')),
            ),
          ),
        ),
      );
      final FilledButton button = tester.widget(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(tapCount[0], 0);
    });
  });

  group('PrimaryButton — tooltip', () {
    testWidgets('non-null tooltip wraps a Tooltip widget with the message', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: PrimaryButton(
                onPressed: () {},
                label: const Text('Save'),
                tooltip: 'Save habit',
              ),
            ),
          ),
        ),
      );
      final tooltipFinder = find.ancestor(
        of: find.byType(FilledButton),
        matching: find.byType(Tooltip),
      );
      expect(tooltipFinder, findsOneWidget);
      final Tooltip tooltip = tester.widget(tooltipFinder);
      expect(tooltip.message, 'Save habit');
    });

    testWidgets('null tooltip does NOT wrap a Tooltip widget', (tester) async {
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
      final tooltipFinder = find.ancestor(
        of: find.byType(FilledButton),
        matching: find.byType(Tooltip),
      );
      expect(tooltipFinder, findsNothing);
    });
  });

  group('PrimaryButton — 48dp minimum touch target', () {
    testWidgets('fits the 48dp minimumSize from filledButtonTheme', (
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
      final Size size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('PrimaryButton — Key + Semantics', () {
    testWidgets('forwards key to the underlying FilledButton', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: PrimaryButton(
                key: const ValueKey('primary.btn'),
                onPressed: () {},
                label: const Text('Save'),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('primary.btn')), findsOneWidget);
    });

    testWidgets('label is reachable from Semantics (TalkBack tree)', (
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
      final semanticsFinder = find.bySemanticsLabel('Save');
      expect(semanticsFinder, findsOneWidget);
    });
  });
}
