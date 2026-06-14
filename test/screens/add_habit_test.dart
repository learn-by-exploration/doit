// Tests for the AddHabitScreen.

import 'package:common_games/reminders/alarm_scheduler.dart';
import 'package:common_games/reminders/anchor_detector.dart';
import 'package:common_games/reminders/full_screen_intent.dart';
import 'package:common_games/reminders/notification_service.dart';
import 'package:common_games/reminders/reminder_bridge.dart';
import 'package:common_games/habits/habit.dart' as domain;
import 'package:common_games/screens/add_habit.dart';
import 'package:common_games/services/db.dart';
import 'package:common_games/services/db/schema.dart';
import 'package:common_games/services/habit_repository.dart';
import 'package:common_games/services/reminder_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _resetDb() async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  await AppDatabaseService.instance.ready;
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });
}

Widget _wrap() => const MaterialApp(home: AddHabitScreen());

void main() {
  setUp(() async {
    await _resetDb();
    HabitRepository.instance;
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
    await tester.pumpWidget(_wrap());
    await tester.tap(find.byKey(const ValueKey('add_habit.save')));
    await tester.pump();
    expect(find.text('Name is required'), findsOneWidget);
  });

  testWidgets('Save with valid name pops the route', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byType(TextField), findsOneWidget);
    // Enter text into the EditableText descendant so the
    // TextEditingController picks it up.
    await tester.enterText(find.byType(EditableText), 'Stretch');
    // Use runAsync to let Drift's real timers complete.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('add_habit.save')));
      // Give Drift a chance to write + complete the future.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    // Pump a few frames to let the pop animation settle.
    await tester.pumpAndSettle();
    // The screen pops — AddHabitScreen no longer in tree.
    expect(find.byType(AddHabitScreen), findsNothing);
  });

  testWidgets('Save with valid name persists the habit to the DB', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.enterText(find.byType(EditableText), 'Stretch');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('add_habit.save')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final habits = await tester.runAsync<List<domain.Habit>>(
      HabitRepository.instance.listAll,
    );
    expect(habits?.length, 1);
    expect(habits?.first.name, 'Stretch');
  });
}
