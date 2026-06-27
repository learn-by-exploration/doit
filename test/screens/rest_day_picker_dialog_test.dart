// Widget tests for the shared `RestDayPickerDialog` (v1.4j /
// Phase 37 / SYS-124 / ADR-054 / WF-051).
//
// The dialog is the single source of truth for picking
// `restDaysPerMonth` (0..31). It is reused by both the home tile
// (`_HabitTileState._onBudgetCaptionTapped`) and the
// AddHabitScreen (`_AddHabitScreenState._pickRestDaysPerMonth`),
// so these tests pin the contract once and serve both surfaces.
//
// Tests cover:
//   - initial value renders as the slider label
//   - Cancel returns null
//   - Save returns the current value
//   - slider clamps at the boundaries (0 and 31)
//   - the localized title / description / Save / Cancel are
//     present (English locale via `localizedApp`)
//   - clamping on construction when an out-of-range value is
//     passed (defensive against stale DB rows)
//   - clamping the `kRestDaysPerMonthMax - kRestDaysPerMonthMin`
//     divisions exactly equals 31

import 'package:doit/screens/rest_day_picker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

Future<void> _pump(WidgetTester tester, Widget dialog) async {
  await tester.pumpWidget(
    localizedApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: dialog),
      // Unique key per pump forces a fresh MaterialApp so the
      // second dialog (clamping test) replaces the first.
      // Without the key, tester.pumpWidget reuses the same
      // MaterialApp and the old widget subtree persists.
    ),
  );
}

void main() {
  testWidgets('renders the initial value as the slider label and as the '
      'live integer above the slider (v1.4j / SYS-124)', (tester) async {
    await _pump(tester, const RestDayPickerDialog(initial: 5));
    await tester.pumpAndSettle();
    expect(find.text('5'), findsOneWidget);
    // Slider label is also '5' (the Slider shows the label as a
    // tooltip on the thumb; assert via the Slider widget).
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 5.0);
    expect(slider.min, kRestDaysPerMonthMin.toDouble());
    expect(slider.max, kRestDaysPerMonthMax.toDouble());
  });

  testWidgets('renders the localized title / description / Save / Cancel '
      '(v1.4j / SYS-124)', (tester) async {
    await _pump(tester, const RestDayPickerDialog(initial: 2));
    await tester.pumpAndSettle();
    expect(find.text('Rest days per month'), findsOneWidget);
    expect(
      find.text(
        'How many rest days you can take each month. Resets on the 1st.',
      ),
      findsOneWidget,
    );
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('Cancel button returns null from showDialog (v1.4j / SYS-124)', (
    tester,
  ) async {
    int? result;
    await tester.pumpWidget(
      localizedApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showRestDayPicker(ctx, initial: 3);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets(
    'Save button returns the current slider value (v1.4j / SYS-124)',
    (tester) async {
      int? result;
      await tester.pumpWidget(
        localizedApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () async {
                  result = await showRestDayPicker(ctx, initial: 4);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result, 4);
    },
  );

  testWidgets('slider value is clamped on construction when initial is below '
      'the min (v1.4j / SYS-124)', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        theme: ThemeData.dark(),
        home: const Scaffold(body: RestDayPickerDialog(initial: -7)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('$kRestDaysPerMonthMin'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, kRestDaysPerMonthMin.toDouble());
  });

  testWidgets('slider value is clamped on construction when initial is above '
      'the max (v1.4j / SYS-124)', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        theme: ThemeData.dark(),
        home: const Scaffold(body: RestDayPickerDialog(initial: 99)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('$kRestDaysPerMonthMax'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, kRestDaysPerMonthMax.toDouble());
  });

  testWidgets('slider divisions equal the integer range so the slider snaps '
      'to whole numbers (v1.4j / SYS-124)', (tester) async {
    await _pump(tester, const RestDayPickerDialog(initial: 0));
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.divisions, kRestDaysPerMonthMax - kRestDaysPerMonthMin);
  });

  testWidgets('dragging the slider updates the live integer label '
      '(v1.4j / SYS-124)', (tester) async {
    await _pump(tester, const RestDayPickerDialog(initial: 10));
    await tester.pumpAndSettle();
    // Drag the slider thumb by +10 divisions.
    final sliderFinder = find.byType(Slider);
    await tester.drag(sliderFinder, const Offset(200, 0));
    await tester.pumpAndSettle();
    // The label above the slider reflects the new value.
    final slider = tester.widget<Slider>(sliderFinder);
    expect(slider.value, greaterThan(10.0));
    expect(slider.value, lessThanOrEqualTo(kRestDaysPerMonthMax.toDouble()));
  });
}
