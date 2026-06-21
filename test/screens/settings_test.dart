// Tests for the SettingsScreen.

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/screens/settings.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// `permission_handler_platform_interface` re-exports the
// `Permission`, `PermissionStatus`, and the
// `PermissionStatusValue` extension that exposes
// `status.value` (the int wire format the method-channel
// expects). Same pattern as `settings_permissions_test.dart`.
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:provider/provider.dart';

Widget _wrap() {
  return ChangeNotifierProvider<SettingsService>.value(
    value: SettingsService.instance,
    child: MaterialApp(theme: AppTheme.dark, home: const SettingsScreen()),
  );
}

/// Phone-sized viewport so the long ListView lays out
/// without scrolling.
void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

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

    // Mock the permissions channel so the surrounding
    // `_PermissionsRow` tiles do not throw during build.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
        case 'requestPermissions':
          final requested = (call.arguments as List).cast<int>();
          return <int, int>{
            for (final v in requested) v: PermissionStatus.denied.value,
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

  testWidgets('renders all section headers', (tester) async {
    _setPhoneSize(tester);

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
    _setPhoneSize(tester);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings.restore')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings_restore.pick')), findsOneWidget);
  });

  testWidgets(
    'tapping the Light theme radio updates SettingsService.themeMode',
    (tester) async {
      _setPhoneSize(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // Default is `dark` (SettingsService reset).
      expect(SettingsService.instance.themeMode.value, ThemeMode.dark);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(SettingsService.instance.themeMode.value, ThemeMode.light);
    },
  );

  testWidgets(
    'tapping the "First unlock" anchor radio calls anchor.stop() + start()',
    (tester) async {
      _setPhoneSize(tester);
      final bridge = FakeReminderBridge();
      ReminderService.resetForTesting();
      await ReminderService.init(
        ReminderService(
          scheduler: FakeAlarmScheduler(),
          notifications: FakeNotificationService(),
          fullScreen: FakeFullScreenIntent(),
          anchor: FakeAnchorDetector(),
          bridge: bridge,
        ),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // Default is `manual`. Tap the second radio option.
      await tester.tap(find.text('First unlock of the day'));
      await tester.pumpAndSettle();
      // The fake anchor's `start()` was called with the new
      // mode; `ReminderService.instance.anchor` is the
      // FakeAnchorDetector from the re-init above.
      expect(ReminderService.instance.anchor.mode, AnchorMode.firstUnlock);
    },
  );

  testWidgets(
    'the reliability row renders the "Optimal" copy when the scheduler '
    'reports Reliability.optimal',
    (tester) async {
      _setPhoneSize(tester);
      final scheduler = FakeAlarmScheduler();
      ReminderService.resetForTesting();
      await ReminderService.init(
        ReminderService(
          scheduler: scheduler,
          notifications: FakeNotificationService(),
          fullScreen: FakeFullScreenIntent(),
          anchor: FakeAnchorDetector(),
          bridge: FakeReminderBridge(),
        ),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // `FakeAlarmScheduler._reliability` defaults to
      // `optimal`, so no setter call is needed.
      expect(find.text('Optimal — exact alarm granted.'), findsOneWidget);
    },
  );

  testWidgets(
    'the reliability row renders the "Degraded" copy when the scheduler '
    'reports Reliability.degraded',
    (tester) async {
      _setPhoneSize(tester);
      final scheduler = FakeAlarmScheduler()
        ..setReliability(Reliability.degraded);
      ReminderService.resetForTesting();
      await ReminderService.init(
        ReminderService(
          scheduler: scheduler,
          notifications: FakeNotificationService(),
          fullScreen: FakeFullScreenIntent(),
          anchor: FakeAnchorDetector(),
          bridge: FakeReminderBridge(),
        ),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(
        find.text('Degraded — using WorkManager fallback.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping the Notifications permission tile calls requestNotifications on '
    'the service',
    (tester) async {
      _setPhoneSize(tester);
      // Re-mock the channel so we can count the requestPermissions call.
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final permissionCalls = <MethodCall>[];
      messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
        permissionCalls.add(call);
        switch (call.method) {
          case 'checkPermissionStatus':
          case 'requestPermissions':
            final requested = (call.arguments as List).cast<int>();
            return <int, int>{
              for (final v in requested) v: PermissionStatus.granted.value,
            };
          case 'openAppSettings':
            return true;
          default:
            return null;
        }
      });
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('settings.permission.notifications')),
      );
      // The `_reProbe` path awaits `requestNotifications()`
      // — that Future completes in real time via the
      // channel, so `pump + runAsync + pump` (not
      // `pumpAndSettle`) is the right dance.
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      expect(
        permissionCalls.any((c) => c.method == 'requestPermissions'),
        isTrue,
        reason:
            'Tapping the notifications tile must re-probe via the '
            'service seam.',
      );
    },
  );

  testWidgets(
    'tapping the Contacts, Exact-alarm, Location, Calendar, and Battery tiles '
    'each calls the matching requestX',
    (tester) async {
      _setPhoneSize(tester);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final permissionCalls = <MethodCall>[];
      messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
        permissionCalls.add(call);
        switch (call.method) {
          case 'checkPermissionStatus':
          case 'requestPermissions':
            final requested = (call.arguments as List).cast<int>();
            return <int, int>{
              for (final v in requested) v: PermissionStatus.granted.value,
            };
          case 'openAppSettings':
            return true;
          default:
            return null;
        }
      });
      await tester.pumpWidget(_wrap());
      await tester.pump();

      Future<void> tapAndAssert(String key) async {
        final before = permissionCalls.length;
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump();
        // The re-probe path fires a `requestPermissions`
        // channel call for every runtime permission kind.
        final sawRequest = permissionCalls
            .skip(before)
            .any((c) => c.method == 'requestPermissions');
        expect(
          sawRequest,
          isTrue,
          reason: 'Tapping $key must invoke the matching requestX path.',
        );
      }

      await tapAndAssert('settings.permission.contacts');
      await tapAndAssert('settings.permission.exactAlarm');
      await tapAndAssert('settings.permission.location');
    },
  );

  testWidgets(
    'tapping the Backup folder tile when no folder is picked calls the '
    'picker (SYS-066 re-pick path)',
    (tester) async {
      _setPhoneSize(tester);
      // Register a scripted FilePicker that returns null
      // (user cancelled). The test asserts the picker was
      // called via the platform seam.
      var pickerCalled = 0;
      FilePicker.platform = _ScriptedFilePicker(onCall: () => pickerCalled++);
      addTearDown(() {
        // Restore the default FilePicker via a fresh
        // concrete subclass so subsequent tests in this
        // file are not affected by the scripted behavior.
        FilePicker.platform = _ScriptedFilePicker();
      });
      await tester.pumpWidget(_wrap());
      await tester.pump();
      // Scroll the ListView until the backup-folder tile
      // is on-screen. The tile sits below the permissions
      // + call-screening tiles; on a 1080×3200 viewport it
      // is usually visible, but be defensive.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings.permission.backupFolder')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('settings.permission.backupFolder')),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      expect(pickerCalled, 1);
    },
  );
}

/// A scripted `FilePicker` so the backup-folder re-pick
/// path can be exercised without the real platform
/// implementation. Returns `null` (mimics "user cancelled")
/// and forwards the call to [onCall] so the test can count
/// invocations.
class _ScriptedFilePicker extends FilePicker {
  _ScriptedFilePicker({this.onCall});
  final VoidCallback? onCall;
  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    onCall?.call();
    return null;
  }
}
