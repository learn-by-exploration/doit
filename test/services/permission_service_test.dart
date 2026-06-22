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

import 'package:doit/services/call_interceptor.dart';
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
    // Clear the v1.2 special-access channel mocks so they
    // don't leak into the next test (each test sets its own
    // scripted handler; without this, the next test's
    // handler would be ignored because the prior handler
    // takes precedence).
    messenger.setMockMethodCallHandler(
      const MethodChannel('doit/device_state'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('doit/call_interceptor'),
      null,
    );
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

  test(
    'requestIgnoreBatteryOptimizations maps granted → granted (SYS-068)',
    () async {
      await PermissionService.instance.init();
      requestScriptedStatuses[Permission.ignoreBatteryOptimizations.value] =
          PermissionStatus.granted;
      final result = await PermissionService.instance
          .requestIgnoreBatteryOptimizations();
      expect(result, isA<PermissionResultGranted>());
      expect(
        PermissionService.instance.statuses.value[PermissionKind
            .batteryOptimization],
        isA<PermissionResultGranted>(),
      );
    },
  );

  test(
    'requestLocation maps granted → granted (SYS-076 / Phase C PR 2 / ADR-021)',
    () async {
      await PermissionService.instance.init();
      requestScriptedStatuses[Permission.location.value] =
          PermissionStatus.granted;
      final result = await PermissionService.instance.requestLocation();
      expect(result, isA<PermissionResultGranted>());
      // The service records the mapped result into
      // `statuses` so the v0.5d Settings → Permissions tile
      // re-renders as "Granted" the next time the user
      // re-opens the screen, and so `GeofenceService` (the
      // service that owns the position stream) reads the
      // same value the next time it is asked.
      expect(
        PermissionService.instance.statuses.value[PermissionKind.location],
        isA<PermissionResultGranted>(),
      );
    },
  );

  test(
    'requestLocation maps denied → PermissionResultDenied (SYS-076)',
    () async {
      await PermissionService.instance.init();
      requestScriptedStatuses[Permission.location.value] =
          PermissionStatus.denied;
      final result = await PermissionService.instance.requestLocation();
      expect(result, isA<PermissionResultDenied>());
      // One-shot denial must keep canOpenSettings: true so
      // the user can be re-asked.
      expect((result as PermissionResultDenied).canOpenSettings, isTrue);
    },
  );

  test('init() probes the five runtime permissions including '
      'battery-optimization (SYS-068) and location (SYS-076)', () async {
    await PermissionService.instance.init();
    final probes = permissionsCalls
        .where((c) => c.method == 'checkPermissionStatus')
        .map((c) => (c.arguments as int))
        .toList();
    expect(
      probes,
      contains(Permission.ignoreBatteryOptimizations.value),
      reason:
          'init() must probe battery-optimization alongside the v0.5d '
          'three (notification, contacts, scheduleExactAlarm) plus the '
          'v1.0 location kind (SYS-076 / Phase C PR 2 / ADR-021).',
    );
    expect(
      probes,
      contains(Permission.location.value),
      reason: 'init() must probe coarse-location for geofence triggers.',
    );
    expect(
      probes,
      contains(Permission.calendarFullAccess.value),
      reason:
          'init() must probe calendar for TriggerCalendarEvent '
          '(SYS-078 / Phase E PR 1 / ADR-023).',
    );
    expect(
      probes.length,
      6,
      reason:
          'init() must probe exactly six runtime permissions exactly '
          'once total.',
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
      6,
      reason:
          'init() must probe exactly the six runtime permissions '
          '(`notification`, `contacts`, `scheduleExactAlarm`, '
          '`ignoreBatteryOptimizations`, `location`, '
          '`calendarFullAccess`) exactly once total. '
          'A second call must short-circuit on the completed gate.',
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

  // ── v1.2: usageStats + callScreening (special-access probes) ──

  test('init() seeds usageStats and callScreening in [statuses] '
      'as denied(canOpenSettings: true)', () async {
    await PermissionService.instance.init();
    expect(
      PermissionService.instance.statuses.value[PermissionKind.usageStats],
      isA<PermissionResultDenied>(),
      reason:
          '`usageStats` defaults to denied(canOpenSettings: true) '
          'because the OS does not show a runtime prompt for it.',
    );
    expect(
      PermissionService.instance.statuses.value[PermissionKind.callScreening],
      isA<PermissionResultDenied>(),
      reason:
          '`callScreening` defaults to denied(canOpenSettings: true) '
          'because the role is not auto-granted at install time.',
    );
  });

  test('requestUsageStats deep-links to the usage-access Settings page '
      'via UsageStatsService (SYS-086 / ADR-030)', () async {
    // Mock the `doit/device_state` method channel that
    // `UsageStatsService`'s method-channel source talks to.
    // Mock MUST be in place before init() so the fire-and-forget
    // probe inside init() doesn't hang waiting on a missing
    // method-channel handler.
    const deviceStateChannel = MethodChannel('doit/device_state');
    var openedCount = 0;
    messenger.setMockMethodCallHandler(deviceStateChannel, (call) async {
      switch (call.method) {
        case 'openUsageAccessSettings':
          openedCount++;
          return true;
        case 'isUsageStatsGranted':
          return false;
        default:
          return null;
      }
    });
    await PermissionService.instance.init();
    final ok = await PermissionService.instance.requestUsageStats();
    expect(ok, isTrue);
    expect(
      openedCount,
      1,
      reason: 'requestUsageStats must invoke exactly once.',
    );
  });

  test('refreshUsageStats merges an "isGranted=true" probe into '
      '[statuses] (SYS-086 / ADR-030)', () async {
    // Mock MUST be in place before init() so the fire-and-forget
    // probe inside init() doesn't hang waiting on a missing
    // method-channel handler.
    const deviceStateChannel = MethodChannel('doit/device_state');
    messenger.setMockMethodCallHandler(deviceStateChannel, (call) async {
      switch (call.method) {
        case 'isUsageStatsGranted':
          return true;
        case 'openUsageAccessSettings':
          return true;
        default:
          return null;
      }
    });
    await PermissionService.instance.init();
    await PermissionService.instance.refreshUsageStats();
    expect(
      PermissionService.instance.statuses.value[PermissionKind.usageStats],
      isA<PermissionResultGranted>(),
    );
  });

  test('refreshUsageStats merges an "isGranted=false" probe into '
      '[statuses]', () async {
    const deviceStateChannel = MethodChannel('doit/device_state');
    messenger.setMockMethodCallHandler(deviceStateChannel, (call) async {
      switch (call.method) {
        case 'isUsageStatsGranted':
          return false;
        case 'openUsageAccessSettings':
          return true;
        default:
          return null;
      }
    });
    await PermissionService.instance.init();
    await PermissionService.instance.refreshUsageStats();
    expect(
      PermissionService.instance.statuses.value[PermissionKind.usageStats],
      isA<PermissionResultDenied>(),
    );
  });

  test('requestCallScreening fires the OS role flow via '
      'CallInterceptorService (SYS-075 + SYS-079 follow-up)', () async {
    // Mock MUST be in place before init() so the fire-and-forget
    // `CallInterceptorService.instance` constructor / init probe
    // doesn't hang waiting on a missing method-channel handler.
    const callInterceptorChannel = MethodChannel('doit/call_interceptor');
    var requestCount = 0;
    messenger.setMockMethodCallHandler(callInterceptorChannel, (call) async {
      switch (call.method) {
        case 'requestCallScreeningRole':
          requestCount++;
          return true;
        // The CallInterceptorService init path probes several
        // sub-methods; mock them all so init doesn't hang.
        case 'startStream':
        case 'stopStream':
        case 'setEnabled':
        case 'setContactIds':
        case 'getRingerMode':
        case 'setRingerMode':
        case 'restorePriorRinger':
        case 'isCallScreeningRoleHeld':
          return false;
        default:
          return null;
      }
    });
    // Init CallInterceptorService so its own `_ready` Completer
    // completes (the service is a separate singleton with its
    // own gate; the v1.2 permission probes await it).
    await CallInterceptorService.instance.init();
    await PermissionService.instance.init();
    final granted = await PermissionService.instance.requestCallScreening();
    expect(granted, isTrue);
    expect(
      requestCount,
      1,
      reason: 'requestCallScreening must invoke the role flow exactly once.',
    );
  });

  test(
    'refreshCallScreening merges "role-held=true" into [statuses]',
    () async {
      const callInterceptorChannel = MethodChannel('doit/call_interceptor');
      messenger.setMockMethodCallHandler(callInterceptorChannel, (call) async {
        switch (call.method) {
          case 'isCallScreeningRoleHeld':
            return true;
          case 'startStream':
          case 'stopStream':
          case 'setEnabled':
          case 'setContactIds':
          case 'getRingerMode':
          case 'setRingerMode':
          case 'restorePriorRinger':
          case 'requestCallScreeningRole':
            return false;
          default:
            return null;
        }
      });
      await CallInterceptorService.instance.init();
      await PermissionService.instance.init();
      await PermissionService.instance.refreshCallScreening();
      expect(
        PermissionService.instance.statuses.value[PermissionKind.callScreening],
        isA<PermissionResultGranted>(),
      );
    },
  );

  test(
    'refreshCallScreening merges "role-held=false" into [statuses]',
    () async {
      const callInterceptorChannel = MethodChannel('doit/call_interceptor');
      messenger.setMockMethodCallHandler(callInterceptorChannel, (call) async {
        switch (call.method) {
          case 'isCallScreeningRoleHeld':
            return false;
          case 'startStream':
          case 'stopStream':
          case 'setEnabled':
          case 'setContactIds':
          case 'getRingerMode':
          case 'setRingerMode':
          case 'restorePriorRinger':
          case 'requestCallScreeningRole':
            return false;
          default:
            return null;
        }
      });
      await CallInterceptorService.instance.init();
      await PermissionService.instance.init();
      await PermissionService.instance.refreshCallScreening();
      expect(
        PermissionService.instance.statuses.value[PermissionKind.callScreening],
        isA<PermissionResultDenied>(),
      );
    },
  );

  // ── refresh() / v1.2i / Phase 9 / SYS-104 ────────────────────

  test(
    'refresh() re-probes every permission_handler kind in parallel',
    () async {
      probeStatus = PermissionStatus.granted;
      // Init runs the first probe; refresh runs a second.
      await PermissionService.instance.init();
      final firstProbeCount = permissionsCalls
          .where((c) => c.method == 'checkPermissionStatus')
          .length;
      expect(firstProbeCount, greaterThan(0));

      // Toggle the probe to denied so we can prove refresh
      // wrote a fresh value.
      probeStatus = PermissionStatus.denied;
      await PermissionService.instance.refresh();

      final secondProbeCount = permissionsCalls
          .where((c) => c.method == 'checkPermissionStatus')
          .length;
      // Exactly six more checkPermissionStatus calls (one
      // per `permission_handler` kind in the batch).
      expect(
        secondProbeCount - firstProbeCount,
        6,
        reason:
            'refresh() must probe every permission_handler '
            'kind (notifications, contacts, exactAlarm, '
            'batteryOptimization, location, calendar).',
      );
      expect(
        PermissionService.instance.statuses.value[PermissionKind.notifications],
        isA<PermissionResultDenied>(),
        reason:
            'After refresh() with the scripted denied probe, '
            'every kind must reflect the fresh value.',
      );
    },
  );

  test('refresh() merges granted status for every kind', () async {
    probeStatus = PermissionStatus.denied;
    await PermissionService.instance.init();
    probeStatus = PermissionStatus.granted;
    await PermissionService.instance.refresh();
    for (final kind in [
      PermissionKind.notifications,
      PermissionKind.contacts,
      PermissionKind.exactAlarm,
      PermissionKind.batteryOptimization,
      PermissionKind.location,
      PermissionKind.calendar,
    ]) {
      expect(
        PermissionService.instance.statuses.value[kind],
        isA<PermissionResultGranted>(),
        reason: 'Kind $kind must reflect the fresh granted probe.',
      );
    }
  });

  test('refresh() swallows a single probe failure without aborting '
      'the batch', () async {
    probeStatus = PermissionStatus.denied;
    await PermissionService.instance.init();
    // Throw on the FIRST checkPermissionStatus call of the
    // refresh batch (the notifications probe). The other
    // five kinds must still complete and merge into
    // statuses.
    var firstCallSeen = false;
    messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
      if (call.method == 'checkPermissionStatus' && !firstCallSeen) {
        firstCallSeen = true;
        throw PlatformException(code: 'TEST_THROWN');
      }
      permissionsCalls.add(call);
      return probeStatus.value;
    });
    probeStatus = PermissionStatus.granted;
    await PermissionService.instance.refresh();
    // The notifications entry kept its prior (denied)
    // value because the probe failed. The other five kinds
    // flipped to granted.
    expect(
      PermissionService.instance.statuses.value[PermissionKind.notifications],
      isA<PermissionResultDenied>(),
      reason:
          'A failed notifications probe must NOT upgrade the '
          'cached status (a failed probe is not a downgrade).',
    );
    expect(
      PermissionService.instance.statuses.value[PermissionKind.calendar],
      isA<PermissionResultGranted>(),
      reason: 'A throw on the first probe must NOT abort the batch.',
    );
  });

  test('refresh() also re-probes usageStats and callScreening', () async {
    // Mock both special-access channels to grant.
    messenger.setMockMethodCallHandler(
      const MethodChannel('doit/device_state'),
      (call) async {
        if (call.method == 'isUsageStatsGranted') return true;
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('doit/call_interceptor'),
      (call) async {
        if (call.method == 'isCallScreeningRoleHeld') return true;
        return false;
      },
    );
    await CallInterceptorService.instance.init();
    await PermissionService.instance.init();
    await PermissionService.instance.refresh();
    expect(
      PermissionService.instance.statuses.value[PermissionKind.usageStats],
      isA<PermissionResultGranted>(),
    );
    expect(
      PermissionService.instance.statuses.value[PermissionKind.callScreening],
      isA<PermissionResultGranted>(),
    );
  });
}
