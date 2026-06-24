// Tests for the AddHabitScreen.

import 'package:doit/reminders/alarm_scheduler.dart';
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

  testWidgets('Save with empty name shows validation error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AddHabitScreen()));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add_habit.save')));
    await tester.pump();
    expect(find.text('Name is required'), findsOneWidget);
  });

  testWidgets('Save with valid name persists and pops', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AddHabitScreen()));
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

  // WF-021 (Phase 11d). The schedule-type SegmentedButton
  // gains a sixth "Per day" segment. This widget test pins
  // the segment's presence in the picker — the persistence
  // round-trip is covered by the unit test in
  // `test/services/habit_repository_test.dart`.
  testWidgets('Picker renders the "Per day" schedule-type segment '
      '(WF-021 / Phase 11d)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AddHabitScreen()));
    await tester.pump();
    // All six segment labels are present, including "Per day".
    expect(find.text('Fixed'), findsOneWidget);
    expect(find.text('Every N'), findsOneWidget);
    expect(find.text('After'), findsOneWidget);
    expect(find.text('Day-of-X'), findsOneWidget);
    expect(find.text('Window'), findsOneWidget);
    expect(find.text('Per day'), findsOneWidget);
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
    await tester.pumpWidget(const MaterialApp(home: AddHabitScreen()));
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

  // WF-024 (Phase 11g). The add-habit screen exposes a
  // per-do rest-day budget stepper. These tests pin:
  //  (1) the stepper is visible in add mode with the
  //      global default value (kDefaultRestDaysPerMonth),
  //  (2) the inc button increments,
  //  (3) the dec button decrements,
  //  (4) the bounds-disable behavior at 0 (dec disabled)
  //      and 31 (inc disabled).
  group('WF-024 rest-day stepper (Phase 11g)', () {
    testWidgets('renders with the kDefaultRestDaysPerMonth value', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: AddHabitScreen()));
      await tester.pump();
      // The Row that hosts the stepper is keyed.
      expect(
        find.byKey(const ValueKey('add_habit.rest_days_stepper')),
        findsOneWidget,
      );
      // The numeric value text reads as the default (2).
      final valueFinder = find.byKey(
        const ValueKey('add_habit.rest_days_value'),
      );
      expect(valueFinder, findsOneWidget);
      expect(tester.widget<Text>(valueFinder).data, '2');
      // The explanatory copy is present so the user knows
      // what the number means.
      expect(find.text('Rest days per month'), findsOneWidget);
    });

    testWidgets('inc increments the displayed value', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AddHabitScreen()));
      await tester.pump();
      // The stepper sits below the schedule-type picker; the
      // default 800×600 test surface scrolls it off-screen.
      // Use `ensureVisible` so the button is actually inside
      // the viewport before the tap.
      await tester.ensureVisible(
        find.byKey(const ValueKey('add_habit.rest_days_inc')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('add_habit.rest_days_inc')));
      await tester.pump();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('add_habit.rest_days_value')),
            )
            .data,
        '3',
      );
    });

    testWidgets('dec decrements the displayed value', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AddHabitScreen()));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('add_habit.rest_days_dec')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('add_habit.rest_days_dec')));
      await tester.pump();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('add_habit.rest_days_value')),
            )
            .data,
        '1',
      );
    });

    testWidgets('at the 0-day lower bound, dec is disabled; at 31-day '
        'upper bound, inc is disabled', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AddHabitScreen()));
      await tester.pump();

      // Walk down to 0 (dec four times: 2 -> 1 -> 0).
      await tester.ensureVisible(
        find.byKey(const ValueKey('add_habit.rest_days_dec')),
      );
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const ValueKey('add_habit.rest_days_dec')));
        await tester.pump();
      }
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('add_habit.rest_days_value')),
            )
            .data,
        '0',
      );
      final decBtn = tester.widget<IconButton>(
        find.byKey(const ValueKey('add_habit.rest_days_dec')),
      );
      expect(decBtn.onPressed, isNull);

      // Walk up to 31 (inc 31 times: 0 -> 31). Re-ensure
      // visibility once after the form re-lays out.
      await tester.ensureVisible(
        find.byKey(const ValueKey('add_habit.rest_days_inc')),
      );
      await tester.pump();
      for (var i = 0; i < 32; i++) {
        await tester.tap(find.byKey(const ValueKey('add_habit.rest_days_inc')));
        await tester.pump();
      }
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('add_habit.rest_days_value')),
            )
            .data,
        '31',
      );
      final incBtn = tester.widget<IconButton>(
        find.byKey(const ValueKey('add_habit.rest_days_inc')),
      );
      expect(incBtn.onPressed, isNull);
    });
  });
}
