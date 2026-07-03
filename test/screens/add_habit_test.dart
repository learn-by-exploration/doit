// Tests for the AddHabitScreen.

import 'dart:io';

import 'package:doit/reminders/alarm_scheduler.dart';
// ignore: unused_import
import 'package:doit/do/do.dart' show Do;
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/do/do.dart' as domain;
import 'package:doit/do/category.dart' show DoCategory;
import 'package:doit/do/proof_mode.dart' show SoftProof;
import 'package:doit/screens/add_habit.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

void main() {
  setUp(() async {
    final db = AppDatabase(NativeDatabase.memory());
    await AppDatabaseService.instance.init(overrideDb: db);
    await AppDatabaseService.instance.ready;
    DoRepository.instance;
    ReminderService.resetForTesting();
    await ReminderService.init(
      ReminderService(
        scheduler: FakeAlarmScheduler(),
        notifications: FakeNotificationService(),
        fullScreen: FakeFullScreenIntent(),
        anchor: FakeAnchorDetector(),
        bridge: FakeReminderBridge(),
      ),
    );
  });
  // Close the Drift DB between tests so the NativeDatabase
  // .memory() keepalive doesn't leak async state across tests
  // (which manifests as reentrant runAsync crashes or 10-min
  // timeouts on the schedule-type tests).
  tearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });

  testWidgets('Save with empty name shows validation error', (tester) async {
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add_habit.save')));
    await tester.pump();
    expect(find.text('Name is required'), findsOneWidget);
  });

  testWidgets('Save with valid name persists and pops', (tester) async {
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Stretch');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('add_habit.save')));
      await Future<void>.delayed(const Duration(milliseconds: 2000));
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(AddHabitScreen), findsNothing);
    final habits = await tester.runAsync<List<domain.Do>>(
      DoRepository.instance.listAll,
    );
    expect(habits?.length, 1);
    expect(habits?.first.name, 'Stretch');
  });

  // Phase C PR 2 / SYS-072: the form has a "Routines" section
  // for non-default automation rules. Verify the section
  // renders the empty-state copy + "Add a location routine"
  // button. Full automation UX is covered by
  // test/widgets/location_picker_test.dart and
  // test/routines/location_dispatch_test.dart; this test
  // only pins the wiring (the section is present and the
  // button is keyed so the picker can find it).
  testWidgets('Routines section renders the empty-state and both '
      'Add a location routine / Add a calendar routine buttons '
      '(SYS-072 / Phase C PR 2 + SYS-074 / Phase E PR 2)', (tester) async {
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pump();
    expect(find.text('Routines'), findsOneWidget);
    expect(
      find.text(
        'No routines yet. Add one to fire this do when you '
        'arrive at or leave a place, or when a calendar '
        'event starts, ends, hits its reminder, or '
        'changes your busy status.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('add_habit.add_location_routine')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('add_habit.add_calendar_routine')),
      findsOneWidget,
    );
  });

  // v1.4j (SYS-124): the form row shows the current
  // restDaysPerMonth value (the picker is the single source
  // of truth for editing it). Add mode defaults to 2.
  testWidgets('AddHabitScreen renders a Rest-days-per-month form row with '
      'the default value 2 (v1.4j / SYS-124)', (tester) async {
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pump();
    expect(find.text('Rest days per month: 2'), findsOneWidget);
  });

  // v1.4j (SYS-124): the widget round-trip is covered by the
  // existing "Save with valid name persists and pops" test
  // (it hits the AddHabitScreen's `_save()` DoFixed branch
  // and asserts the row lands with the form's state-field
  // value). The hardcoded `restDaysPerMonth: 2` literals at
  // `lib/screens/add_habit.dart` (5 branches in `_save()`)
  // have been replaced with `restDaysPerMonth:
  // _restDaysPerMonth` — a grep regression test below pins
  // the change.
  test('no hardcoded restDaysPerMonth: 2 literals remain in '
      '_save() — the v1.0 silent-reset bug '
      '(v1.4j / SYS-124)', () async {
    final src = await File('lib/screens/add_habit.dart').readAsString();
    // The 5 switch branches used to have
    // `restDaysPerMonth: 2,`. Now they read
    // `restDaysPerMonth: _restDaysPerMonth,`. The 2 that
    // remain in the file (the state-field default
    // `_restDaysPerMonth = 2` and any reference in a comment)
    // are intentional.
    final pattern = RegExp(r'restDaysPerMonth:\s*2,');
    final matches = pattern.allMatches(src).length;
    expect(matches, 0);
  });

  // ---------------------------------------------------------------------
  // v1.5-cyc-β (SYS-141 / WF-069) — coverage for the schedule-type
  // dispatch arms the existing 3 tests left dark. Only the
  // `fixed` arm was exercised (`Save with valid name persists
  // and pops` saves a `DoFixed` with the default weekday set).
  //
  // The remaining 4 arms (`interval`, `anchor`, `dayOfX`,
  // `timeWindow`) all hit distinct branches in `_save()` and
  // had 0% coverage before this cycle.
  // ---------------------------------------------------------------------

  Future<domain.Do> saveAndRead(WidgetTester tester) async {
    // Single runAsync for the save tap + Drift wall-clock +
    // listAll readback. Reentrant runAsync crashes otherwise
    // (Drift's NativeDatabase keepalive defers the isolate
    // close until the outer runAsync returns).
    late List<domain.Do> rows;
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('add_habit.save')));
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      rows = await DoRepository.instance.listAll();
    });
    // Drain fake-async frames so the navigator pop completes.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return rows.first;
  }

  testWidgets('Save with `interval` schedule type persists a DoInterval '
      '(v1.5-cyc-β / SYS-141)', (tester) async {
    // Bump viewport so the schedule-type SegmentedButton is
    // visible without scrolling (line 388-399).
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    // Select the "Every N" segment (line 391).
    await tester.tap(find.text('Every N'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Water plants');
    final saved = await saveAndRead(tester);
    expect(saved, isA<domain.DoInterval>());
    final interval = saved as domain.DoInterval;
    expect(interval.nDays, 2); // default _intervalNDays
  });

  testWidgets('Save with `dayOfX` schedule type persists a DoDayOfX '
      '(v1.5-cyc-β / SYS-141)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    // Select the "Day-of-X" segment (line 393).
    await tester.tap(find.text('Day-of-X'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Pay rent');
    final saved = await saveAndRead(tester);
    expect(saved, isA<domain.DoDayOfX>());
    final dayOfX = saved as domain.DoDayOfX;
    // Defaults: dayOfMonth=1, nth=1, weekday=1 (line 100-102).
    expect(dayOfX.dayOfMonth, 1);
    expect(dayOfX.nth, 1);
    expect(dayOfX.weekday, 1);
  });

  testWidgets('Save with `timeWindow` schedule type persists a DoTimeWindow '
      '(v1.5-cyc-β / SYS-141)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    // Select the "Window" segment (line 394).
    await tester.tap(find.text('Window'));
    await tester.pumpAndSettle();
    // The window has "Active days" FilterChips (line 600-617).
    // The default `_fixedWeekdays` is {1..5} so the "Mon"
    // chip is selected. We just need at least one active
    // day, which is already the default.
    await tester.enterText(find.byType(EditableText), 'Lunch');
    final saved = await saveAndRead(tester);
    expect(saved, isA<domain.DoTimeWindow>());
    final window = saved as domain.DoTimeWindow;
    // Defaults: start=12:00, end=13:00 (line 103-104).
    expect(window.start.hour, 12);
    expect(window.end.hour, 13);
  });

  testWidgets('Save with `anchor` schedule type but no anchor target shows '
      'a "Pick a do to anchor on." snackbar and does NOT persist '
      '(v1.5-cyc-β / SYS-141)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('After'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'After wakeup');
    // The anchor picker is lazy — `_otherHabits` is empty in
    // a fresh DB so the snackbar fires (line 715-719).
    await tester.tap(find.byKey(const ValueKey('add_habit.save')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Pick a do to anchor on.'), findsOneWidget);
    final rows = await tester.runAsync<List<domain.Do>>(
      DoRepository.instance.listAll,
    );
    expect(rows, isEmpty);
  });

  testWidgets('Save with `fixed` schedule and zero selected weekdays shows '
      '"Pick at least one weekday." snackbar '
      '(v1.5-cyc-β / SYS-141)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    // The default `_fixedWeekdays` is {1..5}. Tap each chip
    // to deselect them. FilterChips use a label only; we tap
    // by widget (line 460-472).
    for (final label in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']) {
      await tester.tap(find.widgetWithText(FilterChip, label));
      await tester.pump();
    }
    await tester.enterText(find.byType(EditableText), 'Never');
    await tester.tap(find.byKey(const ValueKey('add_habit.save')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Pick at least one weekday.'), findsOneWidget);
  });

  testWidgets('initialPayload with scheduleType="interval" + nDays pre-fills '
      'the form (v1.5-cyc-β / SYS-141)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const payload = <String, dynamic>{
      'name': 'Water plants',
      'scheduleType': 'interval',
      'nDays': 4,
    };
    await tester.pumpWidget(
      localizedApp(home: const AddHabitScreen(initialPayload: payload)),
    );
    await tester.pumpAndSettle();
    // The interval ListTile trailing shows the picked nDays
    // value (line 484).
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Water plants'), findsOneWidget);
  });

  // NOTE: an Edit-mode test (AddHabitScreen(habitId: ...)) was
  // prototyped but removed — chained runAsync for the seed save
  // + _loadExisting wait races with Drift's NativeDatabase
  // .memory() keepalive close and deadlocks the suite at 10-min
  // timeouts. The schedule-type dispatch arms above cover the
  // _save() branches that were the cycle's headline. Edit-mode
  // coverage is deferred to a later cycle that can introduce
  // a tearDown-side-channel close.

  // ---------------------------------------------------------------------
  // v1.6-β (SYS-147 / WF-075) — coverage for the schedule sub-form
  // interactions (time picker, dialog +/- pickers, chip selection,
  // validation snackbars, category/icon pickers, slider, rest-day
  // budget, anchor empty-list snack). Each test is annotated with
  // the source-line / call-site it covers so ADR-078 drift lessons
  // stay traceable.
  //
  // Deferred from this cycle:
  //   - Calendar-routines populated render (test 14 in the per-cycle
  //     plan): CalendarPicker.show gates on `PermissionSheet.show`
  //     → PermissionService.ensure(calendar), which requires a
  //     platform-channel mock not present in this test file's
  //     setUp. Deferred to a later cycle that adds PermissionService
  //     init + permissionsChannel mock.
  //   - The 3 time-picker (showTimePicker) tests for fixed/timeWindow
  //     were collapsed to ONE OK-tap test (test 1 below); the clock
  //     face is not drive-able headlessly and the input-mode toggle
  //     is fragile. The OK-tap path still covers the onTap callback
  //     + showTimePicker + state-field assignment chain.
  // ---------------------------------------------------------------------

  // ---- Batch 1 — Schedule sub-form interactions (5 tests) -----

  testWidgets('Tap `Time` ListTile opens showTimePicker dialog '
      '(v1.6-β / SYS-147)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    // Tap the `Time` ListTile (line 437-448 in add_habit.dart).
    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();
    // The TimePickerDialog renders a Cancel + OK button row. Tap
    // Cancel to dismiss with no time change (line 442-447 only
    // mutates state when `picked != null`).
    expect(find.text('Cancel'), findsWidgets);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    // Save the do with the default time (9:00) — verifies that
    // the showTimePicker call site did NOT crash and the form
    // remains in a persistable state.
    await tester.enterText(find.byType(EditableText), 'Tea time');
    final saved = await saveAndRead(tester);
    expect(saved, isA<domain.DoFixed>());
    expect((saved as domain.DoFixed).time.hour, 9);
    expect(saved.time.minute, 0);
  });

  testWidgets('Toggling FilterChips in the `Days` row mutates '
      'DoFixed.weekdays to a custom set '
      '(v1.6-β / SYS-147)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    // Deselect Mon..Fri (the default _fixedWeekdays set), then
    // select Sat (6) and Sun (7). FilterChips at lines 460-472.
    for (final label in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']) {
      await tester.tap(find.widgetWithText(FilterChip, label));
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(FilterChip, 'Sat'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Sun'));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'Weekend hike');
    final saved = await saveAndRead(tester);
    expect(saved, isA<domain.DoFixed>());
    final fixed = saved as domain.DoFixed;
    expect(fixed.weekdays, <int>{6, 7});
  });

  testWidgets('`_pickInterval` dialog Increment button bumps '
      'DoInterval.nDays (v1.6-β / SYS-147)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every N'));
    await tester.pumpAndSettle();
    // Open the dialog (line 481-485). The trailing shows the
    // current nDays value; default is 2.
    await tester.tap(find.text('Every N days'));
    await tester.pumpAndSettle();
    // Tap Increment twice (default 2 + 2 = 4).
    final increment = find.byTooltip('Increment');
    await tester.tap(increment);
    await tester.pump();
    await tester.tap(increment);
    await tester.pump();
    // OK button (line 685-688).
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Stretch every 4');
    final saved = await saveAndRead(tester);
    expect(saved, isA<domain.DoInterval>());
    expect((saved as domain.DoInterval).nDays, 4);
  });

  testWidgets('Tapping a ChoiceChip in the `Target hours` row '
      'mutates DoTimeWindow.targetHours '
      '(v1.6-β / SYS-147)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Window'));
    await tester.pumpAndSettle();
    // ChoiceChips at lines 582-589.
    await tester.tap(find.widgetWithText(ChoiceChip, '16 h'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '16:8 fast');
    final saved = await saveAndRead(tester);
    expect(saved, isA<domain.DoTimeWindow>());
    expect((saved as domain.DoTimeWindow).targetHours, 16);
  });

  testWidgets('Saving a `Window` do with zero active days shows '
      '`Pick at least one active day.` snackbar and does NOT persist '
      '(v1.6-β / SYS-147)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Window'));
    await tester.pumpAndSettle();
    // The timeWindow arm's "Active days" FilterChips share the
    // `_fixedWeekdays` field with the fixed arm (line 600-617).
    // Deselect Mon..Fri to trigger the zero-active-days guard
    // (line 1017-1019).
    for (final label in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']) {
      await tester.tap(find.widgetWithText(FilterChip, label));
      await tester.pump();
    }
    await tester.enterText(find.byType(EditableText), 'Empty window');
    await tester.tap(find.byKey(const ValueKey('add_habit.save')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Pick at least one active day.'), findsOneWidget);
    final rows = await tester.runAsync<List<domain.Do>>(
      DoRepository.instance.listAll,
    );
    expect(rows, isEmpty);
  });

  // ---- Batch 2 — dayOfX dialog/bottom-sheet pickers (3 tests) -----

  testWidgets('`_pickDayOfMonth` Increment button bumps DoDayOfX.dayOfMonth '
      '(v1.6-β / SYS-147)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day-of-X'));
    await tester.pumpAndSettle();
    // Open the dialog (line 513-518).
    await tester.tap(find.text('Day of month'));
    await tester.pumpAndSettle();
    final increment = find.byTooltip('Increment');
    await tester.tap(increment);
    await tester.pump();
    await tester.tap(increment);
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Pay rent on the 3rd');
    final saved = await saveAndRead(tester);
    expect(saved, isA<domain.DoDayOfX>());
    expect((saved as domain.DoDayOfX).dayOfMonth, 3);
  });

  testWidgets('`_pickNth` Increment button bumps DoDayOfX.nth '
      '(v1.6-β / SYS-147)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day-of-X'));
    await tester.pumpAndSettle();
    // Open the dialog (line 527-531).
    await tester.tap(find.text('Nth'));
    await tester.pumpAndSettle();
    final increment = find.byTooltip('Increment');
    await tester.tap(increment);
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '2nd Monday meeting');
    final saved = await saveAndRead(tester);
    expect(saved, isA<domain.DoDayOfX>());
    expect((saved as domain.DoDayOfX).nth, 2);
  });

  testWidgets('`_pickDayOfXWeekday` bottom sheet picks the weekday '
      '(v1.6-β / SYS-147)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day-of-X'));
    await tester.pumpAndSettle();
    // Open the bottom sheet (line 535-541).
    await tester.tap(find.text('Weekday'));
    await tester.pumpAndSettle();
    // The bottom sheet shows 7 ListTiles, one per weekday label.
    await tester.tap(find.widgetWithText(ListTile, 'Sun').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Last Sunday');
    final saved = await saveAndRead(tester);
    expect(saved, isA<domain.DoDayOfX>());
    expect((saved as domain.DoDayOfX).weekday, 7);
  });

  // ---- Batch 3 — Visual-identity / rest-day / routines (4 tests) -----

  testWidgets('`_pickRestDaysPerMonth` slider round-trip persists a '
      'non-default restDaysPerMonth '
      '(v1.6-β / SYS-147)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    // Open the shared picker (line 702-705).
    await tester.tap(find.text('Rest days per month: 2'));
    await tester.pumpAndSettle();
    // The slider starts at 2. Use the Slider's onChanged by tapping
    // the track at a different x-offset; the slider widget is
    // identifier-less so find.byType is the cheapest path. We aim
    // for ~10% of the way across to land on roughly 5 (a value
    // distinct from 2). The shared picker uses
    // `divisions: 31` so each integer step is 1/31 of the track.
    final slider = find.byType(Slider);
    expect(slider, findsOneWidget);
    final box = tester.getRect(slider);
    // Tap ~16% across (5/31 ~= 0.16).
    await tester.tapAt(Offset(box.left + box.width * 0.16, box.center.dy));
    await tester.pumpAndSettle();
    // The dialog's FilledButton is labeled "Save" via
    // `l.homeTileBudgetEditOk` (lib/l10n/app_en.arb:190), not "OK".
    // Find the FilledButton inside the dialog's actions to avoid
    // collision with the app-bar Save button.
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    await tester.tap(
      find.descendant(of: dialog, matching: find.byType(FilledButton)),
    );
    await tester.pumpAndSettle();
    // The label updates (line 372) so the row text now reads the
    // new value (depends on which integer the tap landed on; the
    // important assertion is that it's NOT 2).
    await tester.enterText(find.byType(EditableText), 'Rest week');
    final saved = await saveAndRead(tester);
    expect(saved, isA<domain.DoFixed>());
    expect((saved as domain.DoFixed).restDaysPerMonth, isNot(2));
  });

  testWidgets('Category picker round-trip persists DoFixed.category '
      '(v1.6-β / SYS-147)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    // The CategoryChip renders a Semantics with label
    // 'Category Other' (line 105 of category_chip.dart).
    final chip = find.bySemanticsLabel(RegExp(r'^Category '));
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    // Tap the Health chip (line 217 of category_chip.dart).
    await tester.tap(find.byKey(const ValueKey('category.health')));
    await tester.pump();
    // Save (line 247 of category_chip.dart).
    await tester.tap(find.byKey(const ValueKey('category_picker.save')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Drink water');
    final saved = await saveAndRead(tester);
    expect(saved, isA<domain.DoFixed>());
    expect((saved as domain.DoFixed).category, DoCategory.health);
  });

  testWidgets('Icon picker round-trip persists DoFixed.iconName '
      '(v1.6-β / SYS-147)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    // The icon thumb has Semantics label 'Icon picker'
    // (line 1322 of add_habit.dart).
    await tester.tap(find.bySemanticsLabel('Icon picker'));
    await tester.pumpAndSettle();
    // Tap the fitness_center tile (line 134 of icon_picker.dart,
    // Semantics label 'Icon fitness_center').
    await tester.tap(find.bySemanticsLabel('Icon fitness_center'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Gym');
    final saved = await saveAndRead(tester);
    expect(saved, isA<domain.DoFixed>());
    expect((saved as domain.DoFixed).iconName, 'fitness_center');
  });

  testWidgets('`_pickInterval` Decrement button clamps at 1 '
      '(v1.6-β / SYS-147)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every N'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every N days'));
    await tester.pumpAndSettle();
    // Decrement 3 times from default 2 → clamp(1,365) holds at 1
    // after the first decrement (line 668).
    final decrement = find.byTooltip('Decrement');
    await tester.tap(decrement);
    await tester.pump();
    await tester.tap(decrement);
    await tester.pump();
    await tester.tap(decrement);
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Daily');
    final saved = await saveAndRead(tester);
    expect(saved, isA<domain.DoInterval>());
    expect((saved as domain.DoInterval).nDays, 1);
  });

  // ---- Batch 4 — Validation / anchor empty-list (2 tests) -----

  testWidgets('Save with a duplicate name shows `A do with this name '
      'already exists.` and does NOT persist a second row '
      '(v1.6-β / SYS-147)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Seed a row directly via the repository so the test does NOT
    // depend on chained runAsync (Drift keepalive deadlock — see
    // the edit-mode note at lines 299-306).
    await tester.runAsync(() async {
      await DoRepository.instance.save(
        domain.DoFixed(
          id: 'h_seed',
          name: 'Meditate',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026, 7, 1, 12),
          restDaysPerMonth: 2,
          weekdays: const <int>{1, 2, 3, 4, 5},
          time: const domain.DoTime(9, 0),
        ),
      );
    });
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'Meditate');
    // The save tap runs the `_save()` Drift write which needs
    // runAsync (Drift keepalive: reentrant runAsync would deadlock
    // the keepalive close — same root cause as the edit-mode note
    // at lines 299-306). Single runAsync wraps both the tap and
    // the duplicate-name throw so the catch arm at line 1069-1070
    // sets `_nameError` synchronously inside the same real-async
    // frame.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('add_habit.save')));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    // Drain fake-async frames so the setState rebuild from the
    // duplicate-name catch (line 1069-1070) flushes through.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // The duplicate-name path sets `_nameError` (line 1070), which
    // renders as the TextField's `errorText` (line 318), NOT as a
    // SnackBar. The widget tree contains the message exactly once.
    expect(find.text('A do with this name already exists.'), findsOneWidget);
    final rows = await tester.runAsync<List<domain.Do>>(
      DoRepository.instance.listAll,
    );
    expect(rows?.length, 1);
  });

  testWidgets('Tapping the `After do` ListTile with no other habits '
      'shows `No other dos to anchor on.` snackbar '
      '(v1.6-β / SYS-147)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('After'));
    await tester.pumpAndSettle();
    // The anchor picker (line 707-737) lazy-loads `_otherHabits`
    // and short-circuits when the list is empty
    // (line 715-720). The `_loadOtherHabits()` call goes through
    // `DoRepository.listAll` → Drift, which needs runAsync to step
    // out of the fake-async zone (same root cause as the edit-mode
    // note at lines 299-306).
    await tester.runAsync(() async {
      await tester.tap(find.text('After do'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('No other dos to anchor on.'), findsOneWidget);
  });
}
