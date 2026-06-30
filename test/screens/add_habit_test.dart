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
}
