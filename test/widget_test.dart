// Root widget tests. Pumps the Streak entry and verifies the
// initial route. v0.4a.3 (SYS-059) adds the second test:
// after `markFirstLaunchCompleted()` the next mount skips
// onboarding and lands on `HomeScreen`.

import 'package:common_games/main.dart';
import 'package:common_games/reminders/alarm_scheduler.dart';
import 'package:common_games/reminders/anchor_detector.dart';
import 'package:common_games/reminders/full_screen_intent.dart';
import 'package:common_games/reminders/notification_service.dart';
import 'package:common_games/reminders/reminder_bridge.dart';
import 'package:common_games/services/db.dart';
import 'package:common_games/services/db/schema.dart';
import 'package:common_games/services/reminder_service.dart';
import 'package:common_games/services/settings_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wipe-install helper: re-seed the SharedPreferences mock,
/// reset the in-memory services (settings, reminder, database),
/// and re-init with the test fakes + an in-memory Drift
/// database so `HomeScreen` can resolve
/// `ReminderService.instance` and `HabitRepository.instance`.
/// Mirrors the v0.3d `fresh_install_test.dart` setup.
Future<void> _setUpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  SettingsService.instance.resetForTesting();
  // init() must be awaited BEFORE any test calls
  // `markFirstLaunchCompleted()` (or any other method that
  // awaits the `_ready` Completer). Without this,
  // `markFirstLaunchCompleted` blocks forever on
  // `await _ready.future` because the gate is left
  // uncompleted by `resetForTesting()`.
  await SettingsService.instance.init();
  ReminderService.resetForTesting();
  await AppDatabaseService.instance.closeForTesting();
  await AppDatabaseService.instance.init(
    overrideDb: AppDatabase(NativeDatabase.memory()),
  );
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });
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

void main() {
  testWidgets('Streak app boots into onboarding on a wiped install', (
    tester,
  ) async {
    // Wiped-install precondition: empty SharedPreferences,
    // in-memory services in the default state. The widget reads
    // the flag from `SettingsService.firstLaunchCompleted`,
    // which defaults to `false`.
    await _setUpApp(tester);
    await tester.pumpWidget(const StreakApp());
    await tester.pump();

    expect(
      find.text('Welcome to Streak'),
      findsOneWidget,
      reason: 'Onboarding must render on a wiped install',
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets(
    'Streak app skips onboarding after markFirstLaunchCompleted() (SYS-059)',
    (tester) async {
      await _setUpApp(tester);

      // First mount: flag is false -> Onboarding.
      await tester.pumpWidget(const StreakApp());
      await tester.pump();
      expect(
        find.text('Welcome to Streak'),
        findsOneWidget,
        reason: 'Onboarding renders while the flag is false',
      );

      // Mark the flag complete. The write is a real `Future`
      // (SharedPreferences hits a platform channel), so step
      // out of the fake-async zone for the write to land.
      // The ValueNotifier updates synchronously inside
      // `markFirstLaunchCompleted`, but the listener
      // notification is scheduled as a microtask that we
      // need to drain by re-pumping the widget tree.
      await tester.runAsync(() async {
        await SettingsService.instance.markFirstLaunchCompleted();
      });
      // Re-mount: the ValueListenableBuilder rebuilds, and
      // OnboardingScreen is gone. We then assert the
      // OnboardingScreen "Welcome to Streak" header is gone.
      //
      // We deliberately do NOT use `pumpAndSettle` here.
      // `HomeScreen._habitsFuture` is a real `Future` from
      // `HabitRepository.instance.listAll()`. Even with an
      // in-memory Drift DB the future resolves on the real
      // event loop (not the fake-async zone), and a pending
      // `Future` in the widget tree prevents the framework
      // from ever going idle, so `pumpAndSettle` blocks until
      // its 10-minute timeout. A single `pump()` rebuilds the
      // route switch (which is the change we actually care
      // about) without trying to settle the entire future
      // chain. The contract under test is the route decision,
      // not the home screen's habit list.
      await tester.pumpWidget(const StreakApp());
      await tester.pump();
      expect(
        find.text('Welcome to Streak'),
        findsNothing,
        reason:
            'After markFirstLaunchCompleted, the next mount must skip Onboarding',
      );
    },
  );

  testWidgets('Streak app firstLaunchOverride=true forces onboarding', (
    tester,
  ) async {
    // The override is a per-mount switch the widget exposes
    // for tests. Even if the persisted flag is `true`, the
    // override wins.
    await _setUpApp(tester);
    await tester.runAsync(() async {
      await SettingsService.instance.markFirstLaunchCompleted();
    });
    await tester.pump();

    await tester.pumpWidget(const StreakApp(firstLaunchOverride: true));
    await tester.pump();
    expect(
      find.text('Welcome to Streak'),
      findsOneWidget,
      reason:
          'firstLaunchOverride=true forces the OnboardingScreen, regardless of the persisted flag',
    );
  });
}
