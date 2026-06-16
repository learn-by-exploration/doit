// Tests for the SettingsScreen.

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

  testWidgets('renders all section headers', (tester) async {
    // The settings screen has many radio tiles; give it a
    // tall viewport so the entire list lays out.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Wake-up anchor'), findsOneWidget);
    // v0.5d (ADR-016) adds the `Permissions` section
    // between `Wake-up anchor` and `Reliability`.
    expect(find.text('Permissions'), findsOneWidget);
    expect(find.text('Reliability'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('restore button navigates to the restore screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings.restore')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings_restore.pick')), findsOneWidget);
  });
}
