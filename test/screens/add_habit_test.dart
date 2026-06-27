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
}
