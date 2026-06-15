// Fresh-install integration test (SYS-055). Simulates a wiped-device
// install: empty Drift DB -> OnboardingScreen renders -> the "Skip"
// CTA is tapped -> HomeScreen renders with the empty-state placeholder
// -> a HabitFixed is saved -> ReminderService.scheduleTestReminder is
// fired and the FakeAlarmScheduler records exactly one alarm.
//
// The test is the contract that the v0.3 sideloaders will hit on a
// real wiped phone. It is the in-test counterpart to the user's
// hands-on "Wiped-device smoke" step documented in
// docs/v_model/v0_3_release_checklist.md.

import 'package:common_games/habits/habit.dart';
import 'package:common_games/habits/proof_mode.dart';
import 'package:common_games/reminders/alarm_scheduler.dart';
import 'package:common_games/reminders/anchor_detector.dart';
import 'package:common_games/reminders/full_screen_intent.dart';
import 'package:common_games/reminders/notification_service.dart';
import 'package:common_games/reminders/reminder_bridge.dart';
import 'package:common_games/screens/home.dart';
import 'package:common_games/screens/onboarding.dart';
import 'package:common_games/services/db.dart';
import 'package:common_games/services/db/schema.dart';
import 'package:common_games/services/habit_repository.dart';
import 'package:common_games/services/reminder_service.dart';
import 'package:common_games/services/settings_service.dart';
import 'package:common_games/theme/app_theme.dart';
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

Widget _wrapHome() {
  return ChangeNotifierProvider<SettingsService>.value(
    value: SettingsService.instance,
    child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
  );
}

Widget _wrapOnboarding({required VoidCallback onDone}) {
  return ChangeNotifierProvider<SettingsService>.value(
    value: SettingsService.instance,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: OnboardingScreen(onDone: onDone),
    ),
  );
}

void main() {
  testWidgets('fresh install: empty DB -> Onboarding -> Home empty-state -> '
      'save HabitFixed -> test reminder lands in the scheduler', (
    tester,
  ) async {
    // Wipe the in-memory DB and reset services.
    await _resetDb(tester);
    HabitRepository.instance;
    ReminderService.resetForTesting();
    final fakeScheduler = FakeAlarmScheduler();
    await ReminderService.init(
      ReminderService(
        scheduler: fakeScheduler,
        notifications: FakeNotificationService(),
        fullScreen: FakeFullScreenIntent(),
        anchor: FakeAnchorDetector(),
        bridge: FakeReminderBridge(),
      ),
    );
    SettingsService.instance.resetForTesting();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1) Onboarding renders on a fresh install.
    var onboardingDone = false;
    await tester.pumpWidget(
      _wrapOnboarding(onDone: () => onboardingDone = true),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Notifications'),
      findsOneWidget,
      reason: 'Onboarding should show the Notifications step on first launch',
    );
    expect(
      find.text('Skip'),
      findsOneWidget,
      reason: 'Onboarding should expose a Skip CTA',
    );

    // 2) Tapping Skip fires onDone.
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(onboardingDone, isTrue);

    // 3) HomeScreen renders the empty-state placeholder.
    await tester.pumpWidget(_wrapHome());
    await tester.pumpAndSettle();
    expect(
      find.text('No habits yet.'),
      findsOneWidget,
      reason: 'A wiped-device install should land on the empty state',
    );

    // 4) Save a HabitFixed. The minimum-viable payload is an id,
    //    a name, a proof mode, weekdays, and a time. The habit id
    //    'streak.test_reminder' is reserved by ReminderService;
    //    pick something distinct.
    await HabitRepository.instance.save(
      HabitFixed(
        id: 'fresh-install-h1',
        name: 'Drink water',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 6, 14, 9),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const HabitTime(9, 0),
      ),
    );

    // 5) Fire the test reminder. scheduleTestReminder uses a real
    //    Future (DateTime.now().add + scheduler.schedule), so step
    //    out of the fake-async zone.
    await tester.runAsync(() async {
      await ReminderService.instance.scheduleTestReminder();
    });

    // 6) The scheduler received exactly one alarm with the
    //    well-known test id. This is the contract the v0.3
    //    sideloaders will see when they tap the test button.
    expect(fakeScheduler.scheduled.length, 1);
    expect(fakeScheduler.scheduled.first.habitId, 'streak.test_reminder');
  });
}
