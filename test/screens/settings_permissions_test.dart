// v0.5d (ADR-016) — tests for the new `Permissions`
// section in `SettingsScreen`.
//
// The v0.1 settings screen had no permissions tile; if a
// user tapped "Don't allow" or "Don't ask again" during
// onboarding there was no in-app recovery affordance.
// v0.5d adds a `_PermissionsRow` between `Wake-up anchor`
// and `Reliability` that reads from
// `PermissionService.instance.statuses` and renders one
// `ListTile` per permission / picker. The tests pin:
//
//   1. The section renders all four tiles (notifications,
//      contacts, exact alarms, backup folder) with
//      "Granted" / "Not asked yet" status text on the
//      initial state.
//   2. The "Settings" `TextButton` is rendered only on
//      rows whose status is `permanentlyDenied` — the
//      "Don't ask again" state. Rows with `granted` or
//      `denied(canOpenSettings: true)` show the
//      `chevron_right` affordance instead, so the user
//      re-asks via the system dialog (or the row's
//      `onTap`).
//   3. Tapping the "Settings" `TextButton` calls
//      `PermissionService.openAppSettings()`. The mock
//      platform channel returns `true`; the test asserts
//      the channel saw the call.
//   4. Tapping a `granted` row (the `onTap` of the row,
//      not the trailing `TextButton`) re-probes via
//      `requestX()`. The mock returns `granted` and the
//      status display stays "Granted" — no system dialog
//      is shown when the permission is already granted.
//
// All tests script the permission platform channel via
// `TestDefaultBinaryMessengerBinding` on
// `flutter.baseflow.com/permissions/methods`; the SAF
// picker is replaced by a `_FakeFilePicker` registered
// via `FilePicker.platform = ...` so the test can
// script the picked path / cancellation without
// `LateInitializationError`.

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
// `permission_handler_platform_interface` re-exports
// `Permission`, `PermissionStatus`, and the
// `PermissionStatusValue` extension that exposes
// `status.value` (the integer wire format the
// `requestPermissions` MethodChannel expects). Same
// pattern as `test/services/permission_service_test.dart`
// and `test/screens/onboarding_permission_wiring_test.dart`.
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:provider/provider.dart';

import '../support/localized_app.dart';

Widget _wrap() {
  return ChangeNotifierProvider<SettingsService>.value(
    value: SettingsService.instance,
    // v1.1h / ADR-031 / SYS-087: route through
    // `localizedApp` to wire the generated
    // `AppLocalizations` delegate (the permission tile
    // titles + status labels are now pulled from the ARB
    // catalog).
    child: localizedApp(theme: AppTheme.dark, home: const SettingsScreen()),
  );
}

class _FakeFilePicker extends FilePicker {
  _FakeFilePicker();
  String? scriptedPath;
  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    return scriptedPath;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  /// Scripted response for `requestPermissions` calls,
  /// keyed by `Permission.value` (int). Tests set entries
  /// before tapping a row.
  final requestScriptedStatuses = <int, PermissionStatus>{};

  /// Scripted response for `checkPermissionStatus` calls
  /// (used by `PermissionService.init()`'s probes), keyed
  /// by `Permission.value` (int). Tests set entries
  /// before pumping the screen so the service's `init()`
  /// populates `statuses` with the right values.
  /// Un-scripted probes fall back to
  /// `PermissionStatus.denied`.
  final probeScriptedStatuses = <int, PermissionStatus>{};

  /// All method calls received on the permissions channel
  /// since the last setUp. Tests assert on this list to
  /// verify the service issued the right
  /// `requestX` / `openAppSettings` calls.
  final permissionsCalls = <MethodCall>[];

  /// If non-null, the next call to the permissions channel
  /// throws this exception.
  Object? throwOnNext;

  late _FakeFilePicker fakeFilePicker;

  setUp(() async {
    requestScriptedStatuses.clear();
    probeScriptedStatuses.clear();
    permissionsCalls.clear();
    throwOnNext = null;
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

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
      permissionsCalls.add(call);
      if (throwOnNext != null) {
        final e = throwOnNext!;
        throwOnNext = null;
        throw e;
      }
      switch (call.method) {
        case 'checkPermissionStatus':
          // `call.arguments` is the encoded
          // `Permission.value` (int). The test scripts a
          // per-permission response so each row can
          // exercise a different status branch.
          final v = call.arguments as int;
          return (probeScriptedStatuses[v] ?? PermissionStatus.denied).value;
        case 'requestPermissions':
          final List<int> requested = (call.arguments as List).cast<int>();
          var response = PermissionStatus.denied;
          for (final v in requested) {
            final scripted = requestScriptedStatuses[v];
            if (scripted != null) {
              response = scripted;
              break;
            }
          }
          return <int, int>{for (final v in requested) v: response.value};
        case 'openAppSettings':
          return true;
        default:
          return null;
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(permissionsChannel, null);
    });

    fakeFilePicker = _FakeFilePicker();
    FilePicker.platform = fakeFilePicker;

    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();
  });

  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // ── Behavior contract ─────────────────────────────────────

  testWidgets('renders all four permission tiles with the initial status '
      'text (SYS-063..066)', (tester) async {
    // All four start in the `PermissionResultDenied` (the
    // service's `init()`-time default after a clean probe
    // with `denied` from the channel mock).
    await setPhoneSize(tester);
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(
      find.byKey(const ValueKey('settings.permission.notifications')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings.permission.contacts')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings.permission.exactAlarm')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings.permission.location')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings.permission.backupFolder')),
      findsOneWidget,
    );
    // The status text on the row is "Not granted — tap
    // to ask again" for the runtime permissions. v1.0
    // Phase C PR 2 (SYS-076) added the coarse-location
    // tile, so the count is 4 not 3.
    expect(find.text('Not granted — tap to ask again'), findsNWidgets(4));
    // The backup folder shows "Not picked — tap to pick"
    // because the service's `init()` does not set a
    // `BackupFolderResult`; the `SettingsService` is the
    // source of truth for the picked path.
    expect(find.text('Not picked — tap to pick'), findsOneWidget);
  });

  testWidgets('Settings button renders only on the permanentlyDenied row '
      '(SYS-064)', (tester) async {
    // Script the `init()` probes so the service populates
    // `statuses` with the right values. Grant
    // notifications + exactAlarm; leave contacts
    // permanently denied; backup folder defaults to
    // "Not picked".
    probeScriptedStatuses[Permission.notification.value] =
        PermissionStatus.granted;
    probeScriptedStatuses[Permission.scheduleExactAlarm.value] =
        PermissionStatus.granted;
    probeScriptedStatuses[Permission.contacts.value] =
        PermissionStatus.permanentlyDenied;
    // `init()` has already been called in setUp; re-init
    // so the new probe script takes effect.
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();
    await setPhoneSize(tester);
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    // The contacts row shows the "Settings" button.
    expect(
      find.byKey(const ValueKey('settings.permission.settings.contacts')),
      findsOneWidget,
      reason:
          "A 'permanentlyDenied' row is the only place the Settings "
          '`TextButton` is rendered — the deep-link to the Android '
          'system app-settings page is the only recovery affordance '
          "after the user taps 'Don't ask again'.",
    );
    // The granted rows do NOT show the Settings button.
    expect(
      find.byKey(const ValueKey('settings.permission.settings.notifications')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('settings.permission.settings.exactAlarm')),
      findsNothing,
    );
  });

  testWidgets('tapping Settings on a permanentlyDenied row calls '
      'openAppSettings (SYS-064)', (tester) async {
    probeScriptedStatuses[Permission.contacts.value] =
        PermissionStatus.permanentlyDenied;
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();
    await setPhoneSize(tester);
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    final before = permissionsCalls.length;
    await tester.tap(
      find.byKey(const ValueKey('settings.permission.settings.contacts')),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    // The mock channel saw at least one `openAppSettings`
    // call after the tap.
    final after = permissionsCalls.length;
    final newCalls = permissionsCalls.sublist(before, after);
    expect(
      newCalls.any((c) => c.method == 'openAppSettings'),
      isTrue,
      reason:
          'The Settings `TextButton` on a `permanentlyDenied` row must '
          'deep-link to the Android system app-settings page via '
          '`PermissionService.openAppSettings()`.',
    );
  });

  testWidgets('tapping a granted row re-probes via requestX without a '
      'system dialog (SYS-063)', (tester) async {
    // The probe in `init()` returns `granted` for
    // notifications; the row's `onTap` should call
    // `requestNotifications` again, which returns
    // `granted` without a system dialog (the permission
    // is already granted, so no UI is shown).
    probeScriptedStatuses[Permission.notification.value] =
        PermissionStatus.granted;
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();
    await setPhoneSize(tester);
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    // After `init()` the channel has 3 `checkPermissionStatus`
    // calls. Tap the row and assert the channel saw an
    // additional `requestPermissions` call for
    // `Permission.notification`.
    final before = permissionsCalls.length;
    await tester.tap(
      find.byKey(const ValueKey('settings.permission.notifications')),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    final newCalls = permissionsCalls.sublist(before);
    final requestCalls = newCalls
        .where((c) => c.method == 'requestPermissions')
        .toList();
    expect(
      requestCalls.length,
      1,
      reason:
          'Tapping a granted row must issue exactly one '
          '`requestPermissions` call (the re-probe). The mock '
          'returns `granted` without a system dialog because the '
          'permission is already granted.',
    );
    // The requested permission is `notification` (encoded
    // as `Permission.notification.value`).
    final requested = (requestCalls.single.arguments as List).cast<int>();
    expect(
      requested,
      [Permission.notification.value],
      reason:
          'The re-probe must target the same permission as the row '
          'the user tapped; otherwise the status display would '
          'reflect the wrong state.',
    );
  });
}
