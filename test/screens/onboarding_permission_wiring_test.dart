// v0.5c (ADR-016) — tests for the runtime-permission
// wiring in `OnboardingScreen`.
//
// The v0.1 onboarding was a "visual walkthrough" — the
// four CTAs at lines 106-110 of
// `lib/screens/onboarding.dart` did
// `setState(() => _step++)`. v0.5c replaces that with a
// dispatch on `_step` to `PermissionService.requestX()`,
// matching the ADR-014 / ADR-016 order:
//
//   step 0  → requestNotifications()    (SYS-063)
//   step 1  → requestContacts()         (SYS-064)
//   step 2  → requestExactAlarm()       (SYS-065)
//   step 3  → requestBackupFolder()     (SYS-066)
//
// The six tests pin the behavior contract the widget layer
// promises the service layer:
//
//   1. step 0 advances on `granted` (SYS-063).
//   2. step 0 does NOT advance on `denied` (one-shot) and
//      shows the inline rationale text (SYS-063).
//   3. step 2 reveals the "Open Android settings" button
//      on `permanentlyDenied` for `SCHEDULE_EXACT_ALARM`
//      (SYS-065). This is the most common Android 12+
//      case for the exact-alarm policy permission.
//   4. step 3 advances on a non-null SAF treeUri AND
//      persists the path to
//      `SettingsService.backupFolderUri` (SYS-066).
//   5. step 3 advances on SAF cancellation (per
//      ADR-014 step 6: the backup folder is skippable)
//      and does NOT set `backupFolderUri` (SYS-066).
//   6. The `Skip` button still calls `onDone` immediately
//      — a regression guard for the user choice.
//
// The tests script the permission platform channel via
// `TestDefaultBinaryMessengerBinding` on
// `flutter.baseflow.com/permissions/methods`; the SAF
// picker is replaced by a `_FakeFilePicker` registered
// via `FilePicker.platform = ...` so the test can script
// the picked path / cancellation without
// `LateInitializationError`.

import 'package:doit/screens/onboarding.dart';
import 'package:doit/services/permission_service.dart';
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
// `requestPermissions` MethodChannel expects). Importing
// only this package (rather than the higher-level
// `permission_handler`) keeps the linter happy and the
// test self-contained — the same pattern as
// `test/services/permission_service_test.dart`.
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:provider/provider.dart';

import '../support/localized_app.dart';

Widget _wrap({required VoidCallback onDone}) {
  return ChangeNotifierProvider<SettingsService>.value(
    value: SettingsService.instance,
    // v1.1h / ADR-031 / SYS-087: route through
    // `localizedApp` so the generated `AppLocalizations`
    // delegate is wired. The plain `MaterialApp` below
    // would have made `AppLocalizations.of(context)`
    // return null and the new OnboardingScreen build
    // would crash.
    child: localizedApp(
      theme: AppTheme.dark,
      home: OnboardingScreen(onDone: onDone),
    ),
  );
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // v0.5b channel name; the same constant the service uses.
  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  /// Scripted response for `requestPermissions` calls,
  /// keyed by `Permission.value` (int). Tests set entries
  /// before tapping the CTA. The mock scans the requested
  /// list and returns the first matching entry; un-scripted
  /// permissions fall back to `PermissionStatus.denied` so
  /// the tests stay deterministic.
  final requestScriptedStatuses = <int, PermissionStatus>{};

  /// Scripted response for `checkPermissionStatus` calls
  /// (used by `PermissionService.init()`'s three probes).
  /// Defaults to `PermissionStatus.denied` so the service
  /// initialises cleanly.
  PermissionStatus probeStatus = PermissionStatus.denied;

  /// The fake `FilePicker` registered for the duration of
  /// the test. Tests mutate `scriptedPath` to script the
  /// SAF picker's response.
  late _FakeFilePicker fakeFilePicker;

  setUp(() async {
    SettingsService.instance.resetForTesting();
    requestScriptedStatuses.clear();
    probeStatus = PermissionStatus.denied;

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          return probeStatus.value;
        case 'requestPermissions':
          // `call.arguments` is a `List<int>` of encoded
          // `Permission.value`s. The service uses
          // `requestPermissions` for a single permission at
          // a time, so the list has length 1 in practice;
          // we scan the list anyway to be robust.
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

    // The service is reset and re-`init()`'d so the
    // channel handler above is in place. The 3 probe
    // calls (checkPermissionStatus for notifications,
    // contacts, scheduleExactAlarm) all return
    // `PermissionStatus.denied` by default.
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();
  });

  /// Pump the onboarding screen, tap the CTA at
  /// `onboarding.next`, and pump until the
  /// service-async resolves. The mock channel handler
  /// returns synchronously but the Future machinery still
  /// needs a microtask tick to complete the await chain
  /// and the subsequent `setState` to flush a frame. The
  /// standard pattern: `pump` (start the future),
  /// `runAsync + Future.delayed(Duration.zero)` (resolve in
  /// real async), `pump` (rebuild).
  Future<void> pumpAndTapNext(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('onboarding.next')));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
  }

  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // ── Behavior contract ─────────────────────────────────────────

  testWidgets('step 0 advances on granted (SYS-063)', (tester) async {
    requestScriptedStatuses[Permission.notification.value] =
        PermissionStatus.granted;
    await setPhoneSize(tester);
    await tester.pumpWidget(_wrap(onDone: () {}));
    await tester.pump();
    expect(find.text('Notifications'), findsOneWidget);
    await pumpAndTapNext(tester);
    // After the grant, step 1 (Contacts) is now showing.
    expect(find.text('Notifications'), findsNothing);
    expect(find.text('Contacts'), findsOneWidget);
  });

  testWidgets('step 0 does not advance on denied and shows the rationale '
      '(SYS-063)', (tester) async {
    requestScriptedStatuses[Permission.notification.value] =
        PermissionStatus.denied;
    await setPhoneSize(tester);
    await tester.pumpWidget(_wrap(onDone: () {}));
    await tester.pump();
    expect(find.text('Notifications'), findsOneWidget);
    await pumpAndTapNext(tester);
    // After the one-shot denial, step 0 is still showing
    // and the inline rationale text is rendered.
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Contacts'), findsNothing);
    expect(
      find.byKey(const ValueKey('onboarding.rationale')),
      findsOneWidget,
      reason:
          'A one-shot denial must surface an inline rationale so the '
          'user understands they can re-tap to grant.',
    );
  });

  testWidgets('step 2 reveals the Open Android settings button on '
      'permanentlyDenied for SCHEDULE_EXACT_ALARM (SYS-065)', (tester) async {
    // Walk the user through steps 0 and 1 with granted,
    // then hit step 2 (exact alarm) with permanentlyDenied
    // — the most common Android 12+ case for the
    // exact-alarm policy permission. The runtime call
    // returns `denied` / `permanentlyDenied` until the
    // user has granted the policy via the system
    // Alarms & reminders settings; the widget surfaces
    // the deep-link as the primary affordance.
    requestScriptedStatuses[Permission.notification.value] =
        PermissionStatus.granted;
    requestScriptedStatuses[Permission.contacts.value] =
        PermissionStatus.granted;
    requestScriptedStatuses[Permission.scheduleExactAlarm.value] =
        PermissionStatus.permanentlyDenied;
    await setPhoneSize(tester);
    await tester.pumpWidget(_wrap(onDone: () {}));
    await tester.pump();
    // Step 0 → 1 → 2.
    await pumpAndTapNext(tester);
    await pumpAndTapNext(tester);
    expect(find.text('Exact alarms'), findsOneWidget);
    // Step 2 with permanentlyDenied.
    await pumpAndTapNext(tester);
    // Step stays on Exact alarms; rationale + Open Android
    // settings button both shown.
    expect(find.text('Exact alarms'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding.rationale')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding.openAndroidSettings')),
      findsOneWidget,
      reason:
          'On permanentlyDenied the deep-link to Android system '
          'settings is the only recovery affordance for '
          'SCHEDULE_EXACT_ALARM. The widget layer must surface it.',
    );
  });

  testWidgets('step 3 advances on a non-null SAF treeUri and persists the '
      'path to SettingsService.backupFolderUri (SYS-066)', (tester) async {
    requestScriptedStatuses[Permission.notification.value] =
        PermissionStatus.granted;
    requestScriptedStatuses[Permission.contacts.value] =
        PermissionStatus.granted;
    requestScriptedStatuses[Permission.scheduleExactAlarm.value] =
        PermissionStatus.granted;
    const pickedPath = '/tree/primary:Documents';
    fakeFilePicker.scriptedPath = pickedPath;
    await setPhoneSize(tester);
    await tester.pumpWidget(_wrap(onDone: () {}));
    await tester.pump();
    // Tap through notifications + contacts + exact alarms.
    await pumpAndTapNext(tester);
    await pumpAndTapNext(tester);
    await pumpAndTapNext(tester);
    // Now on step 3 (Backup folder).
    expect(find.text('Backup folder'), findsOneWidget);
    expect(
      SettingsService.instance.backupFolderUri.value,
      isNull,
      reason:
          'No folder picked yet — the notifier is null until the user '
          'confirms a folder at step 3.',
    );
    await pumpAndTapNext(tester);
    // After picking, the step advances to the call-screening
    // step (the new v1.0/Phase F PR 2 step 4 / SYS-079) AND
    // the URI is persisted for the future `BackupService` to
    // read. v1.0 added the call-screening step between
    // backup-folder and the last-step screen; the SAF
    // contract is still "step 3 → next step on a non-null
    // treeUri".
    expect(
      SettingsService.instance.backupFolderUri.value,
      pickedPath,
      reason:
          'The widget layer must persist the picked treeUri to '
          'SettingsService so the BackupService (future commit) '
          'and the v0.5d Settings tile can read it.',
    );
    expect(find.text('Call-screening role'), findsOneWidget);
  });

  testWidgets('step 3 advances on SAF cancellation and does NOT set '
      'backupFolderUri (SYS-066, ADR-014 step 6: skippable)', (tester) async {
    requestScriptedStatuses[Permission.notification.value] =
        PermissionStatus.granted;
    requestScriptedStatuses[Permission.contacts.value] =
        PermissionStatus.granted;
    requestScriptedStatuses[Permission.scheduleExactAlarm.value] =
        PermissionStatus.granted;
    // `null` = the user cancelled the SAF picker.
    fakeFilePicker.scriptedPath = null;
    await setPhoneSize(tester);
    await tester.pumpWidget(_wrap(onDone: () {}));
    await tester.pump();
    await pumpAndTapNext(tester);
    await pumpAndTapNext(tester);
    await pumpAndTapNext(tester);
    expect(find.text('Backup folder'), findsOneWidget);
    await pumpAndTapNext(tester);
    // After cancellation, the step still advances (the
    // backup folder is skippable per ADR-014 step 6) to
    // the new call-screening step (SYS-079) AND the
    // notifier stays null so the v0.5d Settings tile can
    // render the "Pick folder" affordance later.
    expect(find.text('Call-screening role'), findsOneWidget);
    expect(
      SettingsService.instance.backupFolderUri.value,
      isNull,
      reason:
          'A user cancellation must NOT persist a folder — '
          'otherwise the v0.5d tile would show a "picked" state '
          'for a folder the user never confirmed.',
    );
  });

  testWidgets('Skip button calls onDone (regression)', (tester) async {
    // No channel scripting needed — the Skip button is a
    // pure callback. The setUp still initialises the
    // service + SAF fake so the screen renders.
    var doneCount = 0;
    await tester.pumpWidget(_wrap(onDone: () => doneCount++));
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(
      doneCount,
      1,
      reason:
          'The Skip button must call onDone immediately so the user '
          'can leave onboarding without granting any permission. '
          'v0.5c preserves the v0.1 behavior here.',
    );
  });
}
