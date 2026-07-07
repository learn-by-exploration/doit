// Widget tests for `lib/ui/empty_state.dart`.
//
// Covers the C5 form-pattern primitive (canonical empty-state
// placeholder with title + optional message/icon/action)
// extracted during the Month 1 UI-consolidation sprint
// (PR9 of 15). See:
//   - SYS-184 (this PR's surface)
//   - ADR-115 (the rationale + the canonical-pattern call)
//   - WF-111 (this test file)
//   - lib/ui/empty_state.dart (the system under test)
//
// Test cases pin:
//   - title renders verbatim at titleLarge.
//   - message renders verbatim at bodyMedium (when supplied).
//   - icon renders when supplied (at Sizing.huge in
//     colorScheme.outline).
//   - icon is omitted (no Icon widget) when not supplied.
//   - action renders when supplied.
//   - action is omitted (no widget) when not supplied.
//   - default padding (Spacing.lg) is applied.
//   - the widget is centered (Center ancestor).
//   - both text widgets have textAlign: TextAlign.center.
//   - light theme renders the same way (no theme-specific
//     conditional).
//   - title-only variant (no icon, no message, no action)
//     renders the single line (templates.dart use case).

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget body) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: body),
  );
}

void main() {
  group('EmptyState — required title', () {
    testWidgets('renders the title verbatim at titleLarge', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyState(title: 'No habits yet')));
      expect(find.text('No habits yet'), findsOneWidget);
      // The framework merges the title's style with the
      // surrounding DefaultTextStyle; pin the canonical
      // titleLarge fontSize (22) instead of reference
      // equality on the (merged) TextStyle.
      final text = tester.widget<Text>(find.text('No habits yet'));
      expect(
        text.style?.fontSize,
        AppTheme.dark.textTheme.titleLarge?.fontSize,
      );
    });

    testWidgets('centers the column in its parent (Center ancestor)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const EmptyState(title: 'centered')));
      expect(find.byType(Center), findsOneWidget);
    });
  });

  group('EmptyState — optional message', () {
    testWidgets('renders the message verbatim at bodyMedium when supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const EmptyState(
            title: 'No stats yet.',
            message: 'Add a do to start tracking consecutive runs.',
          ),
        ),
      );
      expect(find.text('No stats yet.'), findsOneWidget);
      expect(
        find.text('Add a do to start tracking consecutive runs.'),
        findsOneWidget,
      );
      final body = tester.widget<Text>(
        find.text('Add a do to start tracking consecutive runs.'),
      );
      // Pin the canonical bodyMedium fontSize (14) — the
      // framework merges the style with DefaultTextStyle.
      expect(
        body.style?.fontSize,
        AppTheme.dark.textTheme.bodyMedium?.fontSize,
      );
    });

    testWidgets('omits the message widget when not supplied', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyState(title: 'No templates for this filter.')),
      );
      // The only Text widget is the title.
      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('EmptyState — optional icon', () {
    testWidgets('renders the icon at Sizing.huge in colorScheme.outline', (
      tester,
    ) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              scheme = Theme.of(context).colorScheme;
              return const Scaffold(
                body: EmptyState(
                  title: 'No habits yet',
                  icon: Icons.bolt_outlined,
                ),
              );
            },
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.bolt_outlined));
      expect(icon.size, 64); // Sizing.huge
      expect(icon.color, scheme.outline);
    });

    testWidgets('omits the Icon widget when not supplied', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyState(title: 'No templates for this filter.')),
      );
      expect(find.byType(Icon), findsNothing);
    });
  });

  group('EmptyState — optional action', () {
    testWidgets('renders the action widget when supplied', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EmptyState(
            title: 'No habits yet',
            action: ElevatedButton(
              onPressed: () {},
              child: const Text('Add your first do'),
            ),
          ),
        ),
      );
      expect(find.text('Add your first do'), findsOneWidget);
    });

    testWidgets('omits the action widget when not supplied', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyState(title: 'quiet')));
      // Only the title Text — no ElevatedButton, no action
      // slot in the tree.
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('EmptyState — visual treatment', () {
    testWidgets('both Text widgets have textAlign: TextAlign.center', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const EmptyState(
            title: 'No habits yet',
            message: 'Tap the + to add a do.',
          ),
        ),
      );
      final titleText = tester.widget<Text>(find.text('No habits yet'));
      final bodyText = tester.widget<Text>(find.text('Tap the + to add a do.'));
      expect(titleText.textAlign, TextAlign.center);
      expect(bodyText.textAlign, TextAlign.center);
    });

    testWidgets('applies the default Spacing.lg padding', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyState(title: 'padded')));
      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(Center),
          matching: find.byType(Padding),
        ),
      );
      expect(padding.padding, const EdgeInsets.all(Spacing.lg));
    });
  });

  group('EmptyState — theme integration', () {
    testWidgets('renders correctly under light theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: EmptyState(
              title: 'No stats yet.',
              message: 'Add a do to start tracking.',
              icon: Icons.bar_chart_outlined,
            ),
          ),
        ),
      );
      expect(find.text('No stats yet.'), findsOneWidget);
      expect(find.text('Add a do to start tracking.'), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_outlined), findsOneWidget);
    });
  });
}
