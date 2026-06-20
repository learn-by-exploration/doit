// Phase F PR 2 (SYS-075 / SYS-079) — tests for the
// `_CallScreeningTile` in `SettingsScreen`.
//
// The tile probes `CallInterceptorService.isCallScreeningRoleHeld`
// on mount; tapping "Grant" / "Change" fires
// `requestCallScreeningRole`; the tile re-probes on
// `AppLifecycleState.resumed` so the OS grant is reflected
// when the user returns from the role dialog.
//
// The tile is a private widget; tests reach it by mounting
// `SettingsScreen` and querying the `ListTile` keyed
// `settings.permission.callScreening`. The `Service` is
// driven by a `ScriptedCallSource` so the platform-channel
// dependencies stay out of the test (mirrors the seam
// used by `add_routine_test.dart`).

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/screens/settings.dart';
import 'package:doit/services/call_interceptor.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _wrap() {
  return ChangeNotifierProvider<SettingsService>.value(
    value: SettingsService.instance,
    child: MaterialApp(theme: AppTheme.dark, home: const SettingsScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ScriptedCallSource source;

  /// Phone-sized viewport so the `_PermissionsRow` tiles
  /// fit without needing to scroll.
  void _setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

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

    // Reset the call interceptor and wire a scripted
    // source. `_CallScreeningTile` reads
    // `isCallScreeningRoleHeld` on mount.
    CallInterceptorService.instance.resetForTesting();
    source = ScriptedCallSource();
    CallInterceptorService.instance.debugSetSource(source);
    await CallInterceptorService.instance.init();

    // The settings screen also touches PermissionService
    // (the existing _PermissionsRow reads from its
    // statuses). Init the service with default values so
    // the surrounding tiles render.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const permissionsChannel = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );
    messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
        case 'requestPermissions':
          final requested = (call.arguments as List).cast<int>();
          return <int, int>{
            for (final v in requested) v: 0, // denied
          };
        case 'openAppSettings':
          return true;
        default:
          return null;
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(permissionsChannel, null);
    });
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();
  });

  tearDown(() {
    SettingsService.instance.resetForTesting();
    CallInterceptorService.instance.resetForTesting();
  });

  testWidgets(
    'the tile renders the "Not held" status when the role is not held',
    (tester) async {
      _setPhoneSize(tester);
      source.scriptedRoleHeld = false;
      await tester.pumpWidget(_wrap());
      // Multiple pump + runAsync cycles to let the
      // initState probe's await chain
      // (CallInterceptorService.ready →
      // ScriptedCallSource.isCallScreeningRoleHeld →
      // setState) actually complete and rebuild.
      for (var i = 0; i < 5; i++) {
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
      }
      await tester.pump();

      expect(
        find.byKey(const ValueKey('settings.permission.callScreening')),
        findsOneWidget,
      );
      expect(
        find.text('Not held — tap "Change" to grant the role.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('the tile renders the "Held" status when the role is held', (
    tester,
  ) async {
    _setPhoneSize(tester);
    source.scriptedRoleHeld = true;
    await tester.pumpWidget(_wrap());
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
    }
    await tester.pump();

    expect(
      find.text('Held — Japan routine can intercept calls.'),
      findsOneWidget,
    );
    // Trailing button label flips to "Change" once held.
    expect(find.text('Change'), findsOneWidget);
  });

  testWidgets('tapping "Grant" calls requestCallScreeningRole', (tester) async {
    _setPhoneSize(tester);
    source.scriptedRoleHeld = false;
    source.scriptedRoleRequestGranted = false;
    await tester.pumpWidget(_wrap());
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
    }
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('settings.permission.callScreening.change')),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
    }
    await tester.pump();

    expect(source.requestCallScreeningRoleCalls, 1);
  });

  testWidgets(
    'the tile re-probes when the lifecycle resumes (returning from the OS '
    'role dialog)',
    (tester) async {
      _setPhoneSize(tester);
      source.scriptedRoleHeld = false;
      await tester.pumpWidget(_wrap());
      for (var i = 0; i < 5; i++) {
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
      }
      await tester.pump();

      // First probe already ran in `initState`. Simulate
      // the user returning from the OS role dialog with
      // the role now granted.
      source.scriptedRoleHeld = true;
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      for (var i = 0; i < 5; i++) {
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
      }
      await tester.pump();

      expect(
        find.text('Held — Japan routine can intercept calls.'),
        findsOneWidget,
      );
    },
  );
}
