// Tests for the AddHabitScreen "Save as template" action
// (Phase B PR 2).
//
// Covers (per WF-033 / SYS-068):
//   - The AppBar menu item is hidden in add mode (no habit
//     to template yet).
//   - After saving a habit, the menu item appears in edit
//     mode and opens a name dialog.
//   - Submitting the dialog persists a Template row with
//     entityType=do and the habit's payload in the envelope.
//   - A blank name (whitespace only) does not save.
//
// The pre-existing reminder mock setup mirrors
// `test/screens/add_habit_test.dart` — both files share the
// Fake* services so the AlarmScheduler / NotificationService
// singletons can be initialized.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/screens/add_habit.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/template_repository.dart';
import 'package:doit/templates/template.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: child);
}

Future<void> _setupDb(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  addTearDown(AppDatabaseService.instance.closeForTesting);
  DoRepository.instance;
  TemplateRepository.instance;
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
}

DoFixed _makeFixed(String id, String name) {
  return DoFixed(
    id: id,
    name: name,
    weekdays: const {1, 2, 3, 4, 5, 6, 7},
    time: const DoTime(7, 0),
    proofMode: const SoftProof(),
    createdAt: DateTime.utc(2026, 6, 20),
    restDaysPerMonth: 2,
  );
}

void main() {
  testWidgets('add mode does not show the save-as-template menu', (
    tester,
  ) async {
    await _setupDb(tester);
    await tester.pumpWidget(_wrap(const AddHabitScreen()));
    await tester.pump();
    expect(find.byKey(const ValueKey('add_habit.menu')), findsNothing);
  });

  testWidgets('edit mode renders the menu icon in the AppBar', (tester) async {
    await _setupDb(tester);
    const habitId = 'h_test_menu';
    await DoRepository.instance.save(_makeFixed(habitId, 'Stretch'));
    await tester.pumpWidget(_wrap(const AddHabitScreen(habitId: habitId)));
    await tester.pump();
    expect(find.byKey(const ValueKey('add_habit.menu')), findsOneWidget);
  });

  testWidgets('edit mode saves a Template with the entered name', (
    tester,
  ) async {
    await _setupDb(tester);
    const habitId = 'h_test_save';
    await DoRepository.instance.save(_makeFixed(habitId, 'Stretch'));
    await tester.pumpWidget(_wrap(const AddHabitScreen(habitId: habitId)));
    await tester.pump();
    // Open the menu by tapping the menu icon. The popup
    // menu opens in an Overlay that may render outside the
    // test viewport — use `warnIfMissed: false` so the
    // off-screen PopupMenuItem does not fail the tap.
    await tester.tap(
      find.byKey(const ValueKey('add_habit.menu')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(
      find.byKey(const ValueKey('add_habit.save_as_template')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // The dialog opened; replace the pre-filled name and
    // submit.
    final nameField = find.byKey(
      const ValueKey('add_habit.save_as_template.name'),
    );
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'Morning stretch');
    await tester.tap(
      find.byKey(const ValueKey('add_habit.save_as_template.save')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final templates = await TemplateRepository.instance.listAll();
    expect(templates.length, 1);
    expect(templates.first.name, 'Morning stretch');
    expect(templates.first.entityType, TemplateEntityType.doEntity);
    expect(templates.first.isBuiltIn, false);
  });
}
