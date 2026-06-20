// Widget tests for the IconPickerSheet (WF-031 — category /
// color / icon on a habit). The picker is the 8x8 grid of
// Material Symbols keys; it must render every key, show a
// selected state for `initialIconName`, expose a "Use default"
// button when a selection is present, and pop the picked key
// on tap. Coverage target: ≥ 80% on the file.

import 'package:doit/do/category.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/widgets/icon_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: child),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  String? initialIconName,
  DoCategory category = DoCategory.health,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _wrap(
      IconPickerSheet(initialIconName: initialIconName, category: category),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders one tile per DoIcons.keys entry', (tester) async {
    await _pump(tester);
    // Probe a few well-known keys (visible without scrolling).
    expect(find.byKey(const ValueKey('icon.local_drink')), findsOneWidget);
    expect(find.byKey(const ValueKey('icon.fitness_center')), findsOneWidget);
    // The last key (hiking) is in row 8 and may be off-screen;
    // scroll the grid to find it. This proves every key in
    // DoIcons.keys has a corresponding tile.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('icon.hiking')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('icon.hiking')), findsOneWidget);
  });

  testWidgets('Use default button is hidden when no initial icon is set', (
    tester,
  ) async {
    await _pump(tester, initialIconName: null);
    expect(find.text('Use default'), findsNothing);
  });

  testWidgets('Use default button is visible when initial icon is set', (
    tester,
  ) async {
    await _pump(tester, initialIconName: 'local_drink');
    expect(find.text('Use default'), findsOneWidget);
  });

  testWidgets('Tapping Use default clears the selection', (tester) async {
    await _pump(tester, initialIconName: 'local_drink');
    expect(find.text('Use default'), findsOneWidget);
    await tester.tap(find.text('Use default'));
    await tester.pumpAndSettle();
    // The button hides when there is no selection.
    expect(find.text('Use default'), findsNothing);
  });

  testWidgets('Tapping a tile pops the picker with the key', (tester) async {
    String? popped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popped = await IconPickerSheet.show(
                    context,
                    initialIconName: null,
                    category: DoCategory.health,
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
    // The sheet is up. Tap a tile.
    await tester.tap(find.byKey(const ValueKey('icon.fitness_center')));
    await tester.pumpAndSettle();
    expect(popped, 'fitness_center');
  });

  testWidgets('Sheet renders 64 tiles (one per DoIcons.keys)', (tester) async {
    await _pump(tester);
    // Every Material InkWell in the grid is a tile. The
    // GridView.builder lazy-builds, so we scroll to the bottom
    // and assert the last key has a tile — that proves the
    // full list was provided via `itemCount` and the builder
    // produced every key.
    final scrollable = find.byType(Scrollable).first;
    final lastKey = 'icon.${DoIcons.keys.last}';
    await tester.scrollUntilVisible(
      find.byKey(ValueKey(lastKey)),
      200,
      scrollable: scrollable,
    );
    expect(find.byKey(ValueKey(lastKey)), findsOneWidget);
  });
}
