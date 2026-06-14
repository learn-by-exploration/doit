// Tests for the OnboardingScreen.

import 'package:common_games/reminders/alarm_scheduler.dart';
import 'package:common_games/reminders/anchor_detector.dart';
import 'package:common_games/reminders/full_screen_intent.dart';
import 'package:common_games/reminders/notification_service.dart';
import 'package:common_games/reminders/reminder_bridge.dart';
import 'package:common_games/screens/onboarding.dart';
import 'package:common_games/services/reminder_service.dart';
import 'package:common_games/services/settings_service.dart';
import 'package:common_games/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _wrap({required VoidCallback onDone}) {
  return ChangeNotifierProvider<SettingsService>.value(
    value: SettingsService.instance,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: OnboardingScreen(onDone: onDone),
    ),
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

  testWidgets('first step shows the welcome title and CTA', (tester) async {
    await tester.pumpWidget(_wrap(onDone: () {}));
    await tester.pump();
    expect(find.text('Welcome to Streak'), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget);
  });

  testWidgets('tapping Next advances through the steps', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_wrap(onDone: () {}));
    await tester.pump();
    // Tap Next four times to reach the last step.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('onboarding.next')));
      await tester.pump();
    }
    expect(find.text('Last step'), findsOneWidget);
  });

  testWidgets('tapping Done fires onDone', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var doneCount = 0;
    await tester.pumpWidget(_wrap(onDone: () => doneCount++));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('onboarding.next')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('onboarding.finish')));
    await tester.pump();
    expect(doneCount, 1);
  });
}
