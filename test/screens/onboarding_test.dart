// Tests for the OnboardingScreen.

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/screens/onboarding.dart';
import 'package:doit/services/call_interceptor.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  // v0.5c (ADR-016): the onboarding CTAs now call
  // `PermissionService.requestX()` for each step. The
  // existing visual-walkthrough tests in this file do not
  // care about the permission result, but they DO tap
  // through all four steps; without a scripted
  // platform-channel response the `await ready` in
  // `requestX` would block forever. Script the channel
  // here so every test can tap through cleanly.
  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  // `PermissionStatus.granted.value == 1`. The CTA's
  // `requestX` method is a `requestPermissions` call; the
  // probe in `init()` is a `checkPermissionStatus` call.
  // Both return `1` so every step advances on the first
  // tap.
  const grantedStatusValue = 1;
  // The SAF step (step 3) uses `file_picker`. The
  // `FilePicker.platform` field is `late final` and is
  // only initialized by `FilePickerIO.registerWith()` at
  // production plugin registration; in a test environment
  // dereferencing it throws `LateInitializationError`.
  // Register a `_FakeFilePicker` that returns a fixed
  // path on `getDirectoryPath()`. (The new
  // `onboarding_permission_wiring_test.dart` re-uses the
  // same fake; the test for the `BackupFolderCancelled`
  // branch overrides `scriptedPath` to `null`.)
  late _FakeFilePicker fakeFilePicker;

  setUp(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
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

    // Script the permissions channel for `init()`'s three
    // `checkPermissionStatus` probes and the four
    // `requestPermissions` calls (one per step).
    messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
        case 'requestPermissions':
          final requested = (call.arguments as List).cast<int>();
          return <int, int>{for (final v in requested) v: grantedStatusValue};
        default:
          return null;
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(permissionsChannel, null);
    });

    // Register a fake `FilePicker` that always returns the
    // scripted path on `getDirectoryPath()`.
    fakeFilePicker = _FakeFilePicker()
      ..scriptedPath = '/tree/primary:Documents';
    FilePicker.platform = fakeFilePicker;

    // Reset the service singleton (the channel handler
    // above is already in place, so this `init()` will
    // resolve cleanly).
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();

    // v1.0 / Phase F PR 2 (SYS-079): the new step 4
    // (call-screening role) calls
    // `CallInterceptorService.requestCallScreeningRole()`
    // on CTA. Wire a `ScriptedCallSource` so the
    // `requestCallScreeningRole()` Future resolves
    // deterministically; the test then taps 5 times (one
    // per step) to reach the "Last step" screen.
    CallInterceptorService.instance.resetForTesting();
    CallInterceptorService.instance.debugSetSource(ScriptedCallSource());
    await CallInterceptorService.instance.init();
  });

  tearDown(CallInterceptorService.instance.resetForTesting);

  testWidgets('first step shows the welcome title and CTA', (tester) async {
    await tester.pumpWidget(_wrap(onDone: () {}));
    await tester.pump();
    expect(find.text('Welcome to do it'), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget);
  });

  testWidgets('tapping Next advances through the steps', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_wrap(onDone: () {}));
    await tester.pump();
    // Tap Next five times to reach the last step. v0.5c
    // (ADR-016) — the CTA awaits a permission service call.
    // The mock channel handler is set up in `setUp`, but
    // `tester.pump()` runs in a FakeAsync zone and the
    // `BasicMessageChannel` Future does not resolve there.
    // `tester.runAsync` steps out of the fake-async zone
    // so the channel call resolves in real time, then
    // `tester.pump()` flushes the resulting setState. v1.0
    // / Phase F PR 2 (SYS-079) added a fifth step
    // (call-screening role); the source returns
    // `scriptedRoleRequestGranted = false` by default,
    // which leaves the user on that step. Skip past it
    // by tapping the explicit "Skip" affordance.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('onboarding.next')));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
    }
    // Step 4 (call-screening role): scripted source
    // returns `false` → rationale shown, step stays.
    // The user reaches the last step by tapping Skip.
    expect(find.text('Call-screening role'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();
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
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
    }
    // Step 4 (call-screening role): scripted source
    // returns `false` → rationale shown, step stays.
    // Reach the last step via Skip.
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('onboarding.finish')));
    await tester.pump();
    expect(doneCount, 1);
  });
}

/// Hand-rolled `FilePicker` fake. The production
/// `FilePicker` is a `PlatformInterface` whose `platform`
/// field is `late final` and is only set by
/// `FilePickerIO.registerWith()` at plugin registration; in
/// a test environment that registration never happens and
/// dereferencing `FilePicker.platform` throws
/// `LateInitializationError`. The fake extends `FilePicker`
/// so the platform setter's `verifyToken` check (which the
/// parent constructor `super(token: _token)` provides)
/// passes. Tests mutate `scriptedPath` to script the SAF
/// picker's response; `null` simulates a user cancellation.
class _FakeFilePicker extends FilePicker {
  _FakeFilePicker();

  /// The path the next `getDirectoryPath()` returns. `null`
  /// means "the user cancelled the SAF picker".
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
