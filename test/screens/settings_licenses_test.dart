// Widget tests for the Settings → About "Open source licenses" tile
// (WF-032 / SYS-054). The tile is a tappable ListTile that opens the
// standard Flutter `showLicensePage` route. We assert:
//   1. The tile renders with the v0.3 `kAppVersion` in the static row.
//   2. Tapping the tile pushes a new route (the licenses page).
//
// We use a `NavigatorObserver` to confirm a push happens; the
// license page's contents are Flutter-material and not part of the
// Streak contract.

import 'package:common_games/build_info.dart';
import 'package:common_games/reminders/alarm_scheduler.dart';
import 'package:common_games/reminders/anchor_detector.dart';
import 'package:common_games/reminders/full_screen_intent.dart';
import 'package:common_games/reminders/notification_service.dart';
import 'package:common_games/reminders/reminder_bridge.dart';
import 'package:common_games/screens/settings.dart';
import 'package:common_games/services/reminder_service.dart';
import 'package:common_games/services/settings_service.dart';
import 'package:common_games/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _PushObserver extends NavigatorObserver {
  Route<dynamic>? pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed = route;
    super.didPush(route, previousRoute);
  }
}

Widget _wrap({NavigatorObserver? observer}) {
  return ChangeNotifierProvider<SettingsService>.value(
    value: SettingsService.instance,
    child: MaterialApp(
      theme: AppTheme.dark,
      navigatorObservers: observer == null ? const [] : [observer],
      home: const SettingsScreen(),
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

  testWidgets('Settings → About renders the static version row with '
      'kAppVersion', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // The static row reads kAppVersion; assert the version string
    // appears in the About section.
    expect(find.textContaining(kAppVersion), findsWidgets);
  });

  testWidgets('Settings → About renders the "Open source licenses" tile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings.licenses')), findsOneWidget);
    expect(find.text('Open source licenses'), findsOneWidget);
  });

  testWidgets('Tapping "Open source licenses" pushes the licenses route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final observer = _PushObserver();
    await tester.pumpWidget(_wrap(observer: observer));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings.licenses')));
    await tester.pumpAndSettle();

    // showLicensePage pushes a MaterialPageRoute; our observer
    // captured it. The route's title is the application name.
    expect(observer.pushed, isNotNull);
    expect(observer.pushed, isA<MaterialPageRoute<dynamic>>());
  });
}
