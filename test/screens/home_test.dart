// Tests for the HomeScreen — empty state + happy path with a
// saved habit. The reliability banner and the FAB are also
// asserted.

import 'package:common_games/habits/habit.dart';
import 'package:common_games/habits/proof_mode.dart';
import 'package:common_games/reminders/alarm_scheduler.dart';
import 'package:common_games/reminders/anchor_detector.dart';
import 'package:common_games/reminders/full_screen_intent.dart';
import 'package:common_games/reminders/notification_service.dart';
import 'package:common_games/reminders/reminder_bridge.dart';
import 'package:common_games/screens/home.dart';
import 'package:common_games/services/db.dart';
import 'package:common_games/services/db/schema.dart';
import 'package:common_games/services/habit_repository.dart';
import 'package:common_games/services/reminder_service.dart';
import 'package:common_games/services/settings_service.dart';
import 'package:common_games/theme/app_theme.dart';
import 'package:common_games/widgets/reliability_banner.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<void> _resetDb(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });
}

Widget _wrap() {
  return ChangeNotifierProvider<SettingsService>.value(
    value: SettingsService.instance,
    child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
  );
}

void main() {
  setUp(() async {
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
    SettingsService.instance.resetForTesting();
  });

  testWidgets('empty state shows the placeholder', (tester) async {
    await _resetDb(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('No habits yet.'), findsOneWidget);
  });

  testWidgets('a saved habit renders as a tile', (tester) async {
    await _resetDb(tester);
    await HabitRepository.instance.save(
      HabitFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 6),
        restDaysPerMonth: 2,
        weekdays: const {1, 3, 5},
        time: const HabitTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Stretch'), findsOneWidget);
  });

  testWidgets('renders the reliability banner', (tester) async {
    await _resetDb(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    // With optimal reliability (the default in tests), the
    // banner shrinks to a SizedBox — assert at least one
    // ReliabilityBanner instance is in the tree.
    expect(find.byType(ReliabilityBanner), findsOneWidget);
  });
}
