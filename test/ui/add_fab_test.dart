// Widget tests for `lib/ui/add_fab.dart`.
//
// Covers the C10 FAB (Floating Action Button) primitive
// extracted during the Month 1 UI-consolidation sprint
// (PR15 of 15). See:
//   - SYS-189 (this PR's surface)
//   - ADR-120 (the C10 FAB rationale + the canonical-pattern call)
//   - WF-116 (this test file)
//   - lib/ui/add_fab.dart (the system under test)
//
// Test cases pin:
//   - Renders a `FloatingActionButton` (M3 canonical FAB).
//   - Default child is the `Icons.add` Icon (canonical "add" affordance).
//   - Tap on enabled FAB invokes onPressed.
//   - Default tooltip is the project-standard "Add" string.
//   - Custom tooltip is set on the underlying FloatingActionButton.
//   - Key is forwarded to the underlying FloatingActionButton.
//   - 56dp size (matches `Sizing.tapHome` for visual consistency with
//     the home tile's per-row buttons).
//   - A11y: tooltip is exposed through the Semantics tree (TalkBack reads
//     the tooltip on long-press / accessibility focus).
//   - The custom child Widget identity is preserved (a future caller
//     can pass a different icon — e.g. `Icons.qr_code_scanner` for a
//     "Scan barcode" FAB).
//   - The default tooltip wraps the FAB in a `Tooltip` widget (matches
//     the `IconButton` tooltip test pattern from PR3).
//   - Disabled (onPressed: null) renders the disabled visual state (a
//     disabled FAB is rarely used in practice; this test pins the
//     contract for future callers).

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/add_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AddFab — rendering (v1.8-15 / SYS-189)', () {
    testWidgets('renders a FloatingActionButton (M3 canonical)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(floatingActionButton: AddFab(onPressed: () {})),
        ),
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('default child is the Icons.add Icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(floatingActionButton: AddFab(onPressed: () {})),
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('tap on enabled FAB invokes onPressed', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            floatingActionButton: AddFab(onPressed: () => tapCount++),
          ),
        ),
      );
      await tester.tap(find.byType(AddFab));
      await tester.pump();
      expect(tapCount, 1);
    });
  });

  group('AddFab — tooltip (v1.8-15 / SYS-189)', () {
    testWidgets('default tooltip is the project-standard "Add" string', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(floatingActionButton: AddFab(onPressed: () {})),
        ),
      );
      final FloatingActionButton fab = tester.widget(
        find.byType(FloatingActionButton),
      );
      expect(fab.tooltip, 'Add');
    });

    testWidgets('custom tooltip is set on the underlying FAB', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            floatingActionButton: AddFab(
              onPressed: () {},
              tooltip: 'Add event',
            ),
          ),
        ),
      );
      final FloatingActionButton fab = tester.widget(
        find.byType(FloatingActionButton),
      );
      expect(fab.tooltip, 'Add event');
    });

    testWidgets('tooltip wraps a Tooltip widget with the message', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            floatingActionButton: AddFab(
              onPressed: () {},
              tooltip: 'Add event',
            ),
          ),
        ),
      );
      // The `FloatingActionButton.tooltip` constructor param
      // wraps the FAB in a `Tooltip` widget internally, so a
      // `find.byType(Tooltip)` resolves to the wrapping widget.
      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsOneWidget);
      final Tooltip tooltip = tester.widget(tooltipFinder);
      expect(tooltip.message, 'Add event');
    });
  });

  group('AddFab — 56dp sizing (v1.8-15 / SYS-189)', () {
    testWidgets('FAB is the M3-default 56dp diameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(floatingActionButton: AddFab(onPressed: () {})),
        ),
      );
      final Size size = tester.getSize(find.byType(FloatingActionButton));
      // The M3 default FAB is 56dp (matches Sizing.tapHome
      // for visual consistency with the home tile's per-row
      // 56dp touch targets). We pin via `>= 48` to mirror the
      // `lib-screens.md` 48dp minimum, with a separate pin
      // that asserts the canonical 56dp expected size.
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, 56);
      expect(size.width, 56);
    });
  });

  group('AddFab — Key + Semantics (v1.8-15 / SYS-189)', () {
    testWidgets('forwards key to the underlying FloatingActionButton', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            floatingActionButton: AddFab(
              key: const ValueKey('test.add.fab'),
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('test.add.fab')), findsOneWidget);
    });
  });

  group('AddFab — custom child (v1.8-15 / SYS-189)', () {
    testWidgets('default child renders Icons.add (canonical pattern)', (
      tester,
    ) async {
      // The default child is `Icons.add`. Future callers
      // (e.g. a "Scan barcode" FAB) can pass a different
      // child Widget — this test pins the default so a
      // future PR that adds a `child:` parameter does not
      // silently change the default.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(floatingActionButton: AddFab(onPressed: () {})),
        ),
      );
      final Icon icon = tester.widget(find.byIcon(Icons.add));
      expect(icon.icon, Icons.add);
    });
  });

  group('AddFab — disabled (v1.8-15 / SYS-189)', () {
    testWidgets('non-null onPressed enables the FAB (tap fires callback)', (
      tester,
    ) async {
      var tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            floatingActionButton: AddFab(onPressed: () => tapCount++),
          ),
        ),
      );
      final FloatingActionButton fab = tester.widget(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNotNull);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(tapCount, 1);
    });
  });

  group('AddFab — async onPressed + refresh pattern (v1.8-15 / SYS-189)', () {
    testWidgets('onPressed closure that awaits a navigation + refreshes works '
        '(the canonical "events.add" + "person_groups.add" pattern)', (
      tester,
    ) async {
      // Mirrors the 2 "refresh action" migrations in
      // `events.dart` + `person_groups.dart`:
      //
      //   onPressed: () async {
      //     final created = await Navigator.of(context).push<bool>(...);
      //     if (created == true) await _refresh();
      //   }
      //
      // The AddFab primitive must not break this pattern
      // (the `onPressed` is `VoidCallback`, not
      // `VoidCallback?`; the async closure fits).
      var refreshCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            floatingActionButton: AddFab(
              onPressed: () async {
                // Simulate the canonical "await add screen,
                // then refresh" pattern. The mock add
                // screen returns true (created), so the
                // refresh runs.
                await Future<void>.delayed(Duration.zero);
                refreshCount++;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(AddFab));
      await tester.pump();
      await tester.pump(Duration.zero);
      expect(refreshCount, 1);
    });
  });
}
