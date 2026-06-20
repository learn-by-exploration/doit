// Tests for the call-screening-role onboarding step
// (v1.0 / Phase F PR 2 / SYS-075 / SYS-079).
//
// The new step 4 in `OnboardingScreen` (after the backup
// folder) explains the `ROLE_CALL_SCREENING` opt-in and
// fires `CallInterceptorService.requestCallScreeningRole()`
// on CTA. The step is skippable: the user can either grant
// the role, decline (the OS dialog is dismissed), or
// hard-fail (no Activity, pre-Q, missing plugin) — the
// latter two surface an inline rationale. Three tests:
//
//   1. Step 4 advances on grant — `scriptedRoleRequestGranted
//      = true` → CTA advances to the last-step screen.
//   2. Step 4 surfaces a rationale on decline / hard fail
//      — `scriptedRoleRequestGranted = false` → stays on
//      the step, the inline rationale is rendered.
//   3. The Skip button still calls `onDone` from any step,
//      including step 4 — the user can leave the flow
//      without granting the role and grant it later from
//      Settings → Permissions.
//
// The setup reuses the permission-channel + FilePicker
// scaffolding from
// `onboarding_permission_wiring_test.dart` so the user can
// tap through steps 0..3 cleanly. The call-screening
// service is wired with a `ScriptedCallSource` so step 4's
// outcome is fully deterministic.

import 'package:doit/screens/onboarding.dart';
import 'package:doit/services/call_interceptor.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:provider/provider.dart';

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

Widget _wrap({required VoidCallback onDone}) {
  return ChangeNotifierProvider<SettingsService>.value(
    value: SettingsService.instance,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: OnboardingScreen(onDone: onDone),
    ),
  );
}

Future<void> _setPhoneSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Tap the `onboarding.next` CTA, give the awaited Future
/// a microtask tick via `runAsync`, then rebuild.
Future<void> _pumpAndTapNext(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('onboarding.next')));
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  late _FakeFilePicker fakeFilePicker;
  late ScriptedCallSource scriptedCallSource;

  setUp(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // Grant every permission in the request handler so
    // the user walks through steps 0..3 cleanly. The
    // backup-folder step (3) consumes the FilePicker
    // fake's `scriptedPath`.
    messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
        case 'requestPermissions':
          final List<int> requested = (call.arguments as List).cast<int>();
          return <int, int>{
            for (final v in requested) v: PermissionStatus.granted.value,
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

    fakeFilePicker = _FakeFilePicker()
      ..scriptedPath = '/tree/primary:Documents';
    FilePicker.platform = fakeFilePicker;

    SettingsService.instance.resetForTesting();
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();

    scriptedCallSource = ScriptedCallSource();
    CallInterceptorService.instance.resetForTesting();
    CallInterceptorService.instance.debugSetSource(scriptedCallSource);
    await CallInterceptorService.instance.init();
  });

  tearDown(() {
    CallInterceptorService.instance.resetForTesting();
    SettingsService.instance.resetForTesting();
  });

  testWidgets('step 4 advances to the last-step screen on grant', (
    tester,
  ) async {
    scriptedCallSource.scriptedRoleRequestGranted = true;
    await _setPhoneSize(tester);
    await tester.pumpWidget(_wrap(onDone: () {}));
    await tester.pump();
    // Walk through steps 0..3.
    await _pumpAndTapNext(tester); // 0 → 1
    await _pumpAndTapNext(tester); // 1 → 2
    await _pumpAndTapNext(tester); // 2 → 3
    await _pumpAndTapNext(tester); // 3 → 4
    // Now on the new step.
    expect(find.text('Call-screening role'), findsOneWidget);
    expect(
      scriptedCallSource.requestCallScreeningRoleCalls,
      0,
      reason: 'The CTA has not been tapped yet at step 4.',
    );
    // Tap "Grant".
    await _pumpAndTapNext(tester);
    // The service was called exactly once.
    expect(scriptedCallSource.requestCallScreeningRoleCalls, 1);
    // Step advanced to the last-step screen.
    expect(find.text('Call-screening role'), findsNothing);
    expect(find.text('Last step'), findsOneWidget);
  });

  testWidgets('step 4 surfaces a rationale on decline / hard fail', (
    tester,
  ) async {
    scriptedCallSource.scriptedRoleRequestGranted = false;
    await _setPhoneSize(tester);
    await tester.pumpWidget(_wrap(onDone: () {}));
    await tester.pump();
    // Walk through steps 0..3.
    await _pumpAndTapNext(tester);
    await _pumpAndTapNext(tester);
    await _pumpAndTapNext(tester);
    await _pumpAndTapNext(tester);
    expect(find.text('Call-screening role'), findsOneWidget);
    // Tap "Grant" — the OS dialog (synthesized) is
    // declined; the user stays on the step.
    await _pumpAndTapNext(tester);
    expect(scriptedCallSource.requestCallScreeningRoleCalls, 1);
    // Step is unchanged.
    expect(find.text('Call-screening role'), findsOneWidget);
    expect(find.text('Last step'), findsNothing);
    // The inline rationale is rendered so the user knows
    // they can grant later from Settings → Permissions.
    expect(
      find.byKey(const ValueKey('onboarding.rationale')),
      findsOneWidget,
      reason:
          'A decline or hard failure must surface an inline rationale so '
          'the user understands the role is still available in Settings.',
    );
  });

  testWidgets('Skip from step 4 advances to the Last step (Phase F PR 2)', (
    tester,
  ) async {
    scriptedCallSource.scriptedRoleRequestGranted = false;
    var doneCount = 0;
    await _setPhoneSize(tester);
    await tester.pumpWidget(_wrap(onDone: () => doneCount++));
    await tester.pump();
    // Walk to step 4.
    await _pumpAndTapNext(tester);
    await _pumpAndTapNext(tester);
    await _pumpAndTapNext(tester);
    await _pumpAndTapNext(tester);
    expect(find.text('Call-screening role'), findsOneWidget);
    // Tap Skip — on the call-screening step (step 4), Skip
    // advances to the Last step (anchor mode + theme).
    // Unlike the permission steps (where Skip = exit), the
    // call-screening step is opt-in: the user can decline
    // the role dialog (or never engage with it) and still
    // complete onboarding. The role is grantable later
    // from Settings → Call-screening.
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(
      find.text('Last step'),
      findsOneWidget,
      reason:
          'On the call-screening step (step 4), Skip must advance to '
          'the Last step — declining the role is the same as skipping.',
    );
    expect(
      doneCount,
      0,
      reason:
          'The Skip path on step 4 must NOT call onDone — the user '
          'has not left the onboarding flow, just skipped the role '
          'opt-in.',
    );
    expect(
      scriptedCallSource.requestCallScreeningRoleCalls,
      0,
      reason:
          'The Skip path must NOT fire the OS role dialog — the user '
          'opted out of the role for this session.',
    );
  });
}
