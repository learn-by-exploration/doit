// Tests for the permission / SAF service seam (v0.5b /
// SYS-063..066). The service wraps `permission_handler`
// ^11.3.1 and `file_picker` ^8.1.2; the tests mock both
// plugin channels and assert:
//
//   1. `requestNotifications` maps `PermissionStatus.granted`
//      to `PermissionResultGranted`.
//   2. `requestNotifications` maps `PermissionStatus.denied`
//      to `PermissionResultDenied(canOpenSettings: true)`
//      (one-shot denial — the user can be re-asked).
//   3. `requestNotifications` maps
//      `PermissionStatus.permanentlyDenied` to
//      `PermissionResultPermanentlyDenied`.
//   4. `requestContacts` returns the mapped
//      `PermissionResultGranted` (sample path; the
//      `requestX` methods are uniform on the `kind`).
//   5. `requestExactAlarm` returns `PermissionResultGranted`
//      when `Permission.scheduleExactAlarm` reports
//      `PermissionStatus.granted`. (On Android 12+ the
//      system dialog does not appear; the runtime call
//      returns the current policy status.)
//   6. `requestBackupFolder` returns `BackupFolderPicked`
//      when the SAF picker returns a non-null path.
//   7. `requestBackupFolder` returns `BackupFolderCancelled`
//      when the SAF picker returns `null`.
//   8. `init()` is idempotent — a second call resolves
//      immediately and does not re-probe the channels.
//   9. `init()` swallows a thrown platform-channel error
//      (the v0.4b-release-fix / ADR-013 follow-up: `main()`
//      must not crash if a plugin is missing or restricted).
//
// Wire format references:
// - `package:permission_handler_platform_interface` v4.3.0:
//   the method channel is `flutter.baseflow.com/permissions/methods`.
//   `requestPermissions` takes a `List<int>` (encoded
//   permission values) and returns a `Map<int, int>`
//   (permission value → status value). `checkPermissionStatus`
//   takes an `int` (permission value) and returns an `int`
//   (status value). `openAppSettings` takes nothing and
//   returns a `bool`.
// - `package:file_picker` v8.3.7: the public `FilePicker`
//   abstract class is a `PlatformInterface` (via
//   `package:plugin_platform_interface`) and is dispatched
//   through a `late` static field that the production
//   `FilePickerIO.registerWith()` sets at plugin
//   registration time. In a test environment that
//   registration is never called, so dereferencing
//   `FilePicker.platform` throws `LateInitializationError`.
//   The test registers a `FakeFilePicker` via
//   `FilePicker.platform = FakeFilePicker()` — the fake
//   extends `FilePicker` (which forwards the private
//   `_token` to its superclass `PlatformInterface` via
//   `super(token: _token)`), so the platform setter's
//   `verifyToken` check passes.

import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// `permission_handler_platform_interface` re-exports
// `Permission`, `PermissionStatus`, and the
// `PermissionStatusValue` extension that exposes
// `status.value` (the integer wire format the
// `requestPermissions` MethodChannel expects). Importing
// only this package (rather than the higher-level
// `permission_handler`) keeps the linter happy and the
// test self-contained.
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

/// Hand-rolled `FilePicker` fake. Records the number of
/// `getDirectoryPath` calls and returns a scripted path.
class _FakeFilePicker extends FilePicker {
  _FakeFilePicker();

  /// The path the next `getDirectoryPath()` returns. `null`
  /// means "the user cancelled".
  String? scriptedPath;

  /// If non-null, the next `getDirectoryPath()` throws this
  /// exception. Used to test the service's
  /// `BackupFolderError` branch.
  Object? scriptedError;

  int getDirectoryPathCalls = 0;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    getDirectoryPathCalls++;
    if (scriptedError != null) {
      throw scriptedError!;
    }
    return scriptedPath;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `permission_handler` ^11.3.1 routes through this channel.
  // The constant is private to the package; we hard-code
  // the same string so `setMockMethodCallHandler` can
  // intercept the calls.
  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// All method calls received on the permissions channel
  /// since the last [setUp]. Tests assert on this list to
  /// verify the service issued the right
  /// `Permission.X.request()` calls.
  final permissionsCalls = <MethodCall>[];

  /// Scripted response for the next `checkPermissionStatus`
  /// call (used by `init()` probes). Defaults to
  /// `PermissionStatus.denied` for every permission.
  PermissionStatus probeStatus = PermissionStatus.denied;

  /// Scripted response for the next `requestPermissions`
  /// call (used by `requestX()`). Keyed by the encoded
  /// `Permission.value` of the requested permission; the
  /// first matching entry wins.
  final requestScriptedStatuses = <int, PermissionStatus>{};

  /// Scripted response for the next `openAppSettings`
  /// call. Defaults to `true`.
  bool openAppSettingsResult = true;

  /// If non-null, the next call to the permissions channel
  /// throws this exception (used by the
  /// platform-error-swallow test).
  Object? throwOnNext;

  /// The fake `FilePicker` registered for the duration of
  /// the test. Tests mutate its `scriptedPath` /
  /// `scriptedError` to script the SAF picker's response.
  late _FakeFilePicker fakeFilePicker;

  setUp(() {
    permissionsCalls.clear();
    probeStatus = PermissionStatus.denied;
    requestScriptedStatuses.clear();
    openAppSettingsResult = true;
    throwOnNext = null;
    PermissionService.instance.resetForTesting();

    fakeFilePicker = _FakeFilePicker();
    FilePicker.platform = fakeFilePicker;

    messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
      permissionsCalls.add(call);
      if (throwOnNext != null) {
        final e = throwOnNext!;
        throwOnNext = null;
        throw e;
      }
      switch (call.method) {
        case 'checkPermissionStatus':
          // `call.arguments` is the encoded `Permission.value` (int).
          // We ignore the arg; the test scripts one response for
          // all three probed permissions.
          return probeStatus.value;
        case 'requestPermissions':
          // `call.arguments` is a `List<int>` of encoded
          // permission values (e.g., `[17]` for
          // `Permission.notification`).
          final List<int> requested = (call.arguments as List).cast<int>();
          // Use the first scripted entry that matches; fall back
          // to `denied` so un-scripted permissions have a
          // deterministic response.
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
          return openAppSettingsResult;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(permissionsChannel, null);
  });

  // ── requestX → sealed PermissionResult mapping ───────────────

  test('requestNotifications maps PermissionStatus.granted to '
      'PermissionResultGranted (SYS-063)', () async {
    await PermissionService.instance.init();
    requestScriptedStatuses[Permission.notification.value] =
        PermissionStatus.granted;
    final result = await PermissionService.instance.requestNotifications();
    expect(result, isA<PermissionResultGranted>());
    // The service records the mapped result into
    // `statuses` so the v0.5d Settings → Permissions tile
    // sees the same answer.
    expect(
      PermissionService.instance.statuses.value[PermissionKind.notifications],
      isA<PermissionResultGranted>(),
    );
  });

  test('requestNotifications maps PermissionStatus.denied to '
      'PermissionResultDenied(canOpenSettings: true) (SYS-063)', () async {
    await PermissionService.instance.init();
    requestScriptedStatuses[Permission.notification.value] =
        PermissionStatus.denied;
    final result = await PermissionService.instance.requestNotifications();
    expect(result, isA<PermissionResultDenied>());
    expect(
      (result as PermissionResultDenied).canOpenSettings,
      isTrue,
      reason:
          'One-shot denial must keep canOpenSettings: true so the '
          'CTA stays enabled for a re-ask.',
    );
  });

  test('requestNotifications maps PermissionStatus.permanentlyDenied to '
      'PermissionResultPermanentlyDenied (SYS-063)', () async {
    await PermissionService.instance.init();
    requestScriptedStatuses[Permission.notification.value] =
        PermissionStatus.permanentlyDenied;
    final result = await PermissionService.instance.requestNotifications();
    expect(result, isA<PermissionResultPermanentlyDenied>());
  });

  test('requestContacts maps PermissionStatus.granted to '
      'PermissionResultGranted (SYS-064)', () async {
    await PermissionService.instance.init();
    requestScriptedStatuses[Permission.contacts.value] =
        PermissionStatus.granted;
    final result = await PermissionService.instance.requestContacts();
    expect(result, isA<PermissionResultGranted>());
    expect(
      PermissionService.instance.statuses.value[PermissionKind.contacts],
      isA<PermissionResultGranted>(),
    );
  });

  test('requestExactAlarm returns PermissionResultGranted when the policy '
      'is already granted (SYS-065)', () async {
    // On Android 12+ the system "Allow" dialog does not
    // appear for `SCHEDULE_EXACT_ALARM`; the runtime call
    // returns the current policy status. If the user
    // already granted the policy in system Settings, the
    // service returns `granted` without further UI.
    await PermissionService.instance.init();
    requestScriptedStatuses[Permission.scheduleExactAlarm.value] =
        PermissionStatus.granted;
    final result = await PermissionService.instance.requestExactAlarm();
    expect(result, isA<PermissionResultGranted>());
    expect(
      PermissionService.instance.statuses.value[PermissionKind.exactAlarm],
      isA<PermissionResultGranted>(),
    );
  });

  // ── requestBackupFolder → sealed BackupFolderResult mapping ──

  test('requestBackupFolder returns BackupFolderPicked on a non-null SAF '
      'path (SYS-066)', () async {
    await PermissionService.instance.init();
    fakeFilePicker.scriptedPath = '/tree/primary:Documents';
    final result = await PermissionService.instance.requestBackupFolder();
    expect(result, isA<BackupFolderPicked>());
    expect((result as BackupFolderPicked).path, '/tree/primary:Documents');
    // The widget layer is responsible for persisting
    // `path` to `SettingsService.backupFolderUri`; the
    // service does NOT do that (separation of concerns).
    expect(
      fakeFilePicker.getDirectoryPathCalls,
      1,
      reason: 'The service must invoke getDirectoryPath exactly once.',
    );
  });

  test('requestBackupFolder returns BackupFolderCancelled on SAF '
      'cancellation (SYS-066)', () async {
    await PermissionService.instance.init();
    fakeFilePicker.scriptedPath = null;
    final result = await PermissionService.instance.requestBackupFolder();
    expect(
      result,
      isA<BackupFolderCancelled>(),
      reason:
          'SAF cancellation must be a distinct result so the '
          'onboarding step can advance without an error affordance '
          '(per ADR-014 step 6: the backup folder is skippable).',
    );
  });

  // ── init() lifecycle ────────────────────────────────────────

  test('init() is idempotent: a second call does not re-probe', () async {
    await PermissionService.instance.init();
    await PermissionService.instance.init();
    final probes = permissionsCalls
        .where((c) => c.method == 'checkPermissionStatus')
        .toList();
    expect(
      probes.length,
      3,
      reason:
          'init() must probe exactly the three runtime permissions '
          '(`notification`, `contacts`, `scheduleExactAlarm`) exactly '
          'once total. A second call must short-circuit on the '
          'completed gate.',
    );
  });

  test('init() swallows a thrown platform-channel error '
      '(v0.4b-release-fix / ADR-013 follow-up)', () async {
    // Simulate the plugin being missing / restricted at
    // process start. `init()` must not rethrow — the rest
    // of `main()` proceeds with the default
    // `denied(canOpenSettings: true)` for every permission.
    throwOnNext = PlatformException(
      code: 'PLUGIN_NOT_REGISTERED',
      message: 'permission_handler is not registered',
    );
    await PermissionService.instance.init();
    // The gate is completed even though the probes threw.
    expect(PermissionService.instance.ready, completes);
    expect(
      PermissionService.instance.statuses.value[PermissionKind.notifications],
      isA<PermissionResultDenied>(),
      reason:
          'A thrown probe leaves the default denied in place; the '
          'v0.5d Settings → Permissions tile can render a "try '
          'again" affordance.',
    );
  });
}
