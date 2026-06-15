// Widget tests for the settings "Test reminder" button (WF-028).

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/screens/settings.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _wrap() {
  return ChangeNotifierProvider<SettingsService>.value(
    value: SettingsService.instance,
    child: MaterialApp(theme: AppTheme.dark, home: const SettingsScreen()),
  );
}

void main() {
  setUp(() async {
    SettingsService.instance.resetForTesting();
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

  testWidgets('Settings screen renders the test-reminder tile', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings.test_reminder')),
      findsOneWidget,
    );
    expect(find.text('Send a test reminder'), findsOneWidget);
  });

  testWidgets('Tapping the test-reminder tile schedules a test alarm', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('settings.test_reminder')));
      // Yield to the async tap handler so the SnackBar is queued.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    // After tap, the SnackBar copy confirms the test was scheduled.
    expect(find.textContaining('Test reminder scheduled'), findsOneWidget);
    // And the scheduler recorded exactly one alarm.
    final fake = ReminderService.instance.scheduler as FakeAlarmScheduler;
    expect(fake.scheduled.length, 1);
    expect(fake.scheduled.first.habitId, 'doit.test_reminder');
  });
}
