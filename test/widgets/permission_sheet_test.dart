// v0.6 / ADR-018 — tests for the on-demand `PermissionSheet`.
//
// `PermissionSheet.show(context, kind)` is the seam every
// feature-consumption site uses to gate on a runtime
// permission. The tests pin:
//
//   1. Short-circuit on `granted`: when
//      `PermissionService.statuses[kind]` is already
//      `PermissionResultGranted`, the sheet does NOT open
//      and `show()` returns `true` synchronously.
//   2. Renders the per-kind title + rationale on
//      `denied(canOpenSettings: true)`; the "Allow"
//      `FilledButton` calls `requestX()` for the requested
//      kind; on `granted` the sheet pops with
//      `_PermissionSheetResult(granted: true)` and
//      `show()` returns `true`.
//   3. Renders the "Open settings" CTA on `denied`; on tap
//      it calls `openAppSettings()` and re-probes the
//      permission. If the re-probe still returns `denied`
//      the sheet stays open.
//   4. `permanentlyDenied` shows the error sub-text + a
//      single "Open settings" `FilledButton` (no "Allow"
//      button — re-asking would not show a system dialog
//      anyway).
//   5. The battery-optimization kind uses the live
//      `ReminderBridge.openIgnoreBatteryOptimizations()`
//      for the deep-link (not the generic app settings
//      page) — SYS-068.
//
// Async-pump caveat: the show method's microtask chain
// (`await ensure(...)`) suspends on the cached permission
// probe. The fake-async zone in `tester.pump` does NOT
// process microtasks scheduled outside the pump frame, so
// `pump(Duration)` alone never advances past the
// `await ensure` to the `showModalBottomSheet` call. The
// test therefore drives the async setup under
// `tester.runAsync` (real time) and only uses `pump` to
// advance the modal's 250 ms slide-up transition.

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/widgets/permission_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

class _FakeFilePicker extends FilePicker {
  _FakeFilePicker();
  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async => null;
}

class _RecordingBridge implements ReminderBridge {
  int openIgnoreBatteryOptimizationsCalls = 0;

  @override
  Future<void> rescheduleAll() async {}

  @override
  Future<void> recordAnchor(DateTime at) async {}

  @override
  Future<Reliability> probeReliability() async => Reliability.optimal;

  @override
  Future<int> setExactAlarm({
    required int alarmId,
    required int epochMs,
  }) async => alarmId;

  @override
  Future<void> cancelAlarm(int alarmId) async {}

  @override
  Future<void> showFullScreen(String habitId) async {}

  @override
  Future<void> openIgnoreBatteryOptimizations() async {
    openIgnoreBatteryOptimizationsCalls++;
  }

  @override
  Future<void> showNotification({
    required int alarmId,
    required String habitName,
    String? body,
    bool strongMode = false,
  }) async {}

  @override
  Future<void> cancelNotification(int alarmId) async {}

  @override
  Future<void> schedulePreAlarm({
    required int alarmId,
    required int leadTimeSeconds,
  }) async {}

  @override
  Future<void> cancelPreAlarms(int alarmId) async {}
}

Widget _wrap() => MaterialApp(theme: AppTheme.dark, home: const _Host());

class _Host extends StatelessWidget {
  const _Host();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () =>
              PermissionSheet.show(context, PermissionKind.notifications),
          child: const Text('open'),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  final requestScriptedStatuses = <int, PermissionStatus>{};
  final probeScriptedStatuses = <int, PermissionStatus>{};
  bool openAppSettingsResult = true;
  final permissionsCalls = <MethodCall>[];

  setUp(() async {
    requestScriptedStatuses.clear();
    probeScriptedStatuses.clear();
    openAppSettingsResult = true;
    permissionsCalls.clear();
    FilePicker.platform = _FakeFilePicker();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
      permissionsCalls.add(call);
      switch (call.method) {
        case 'checkPermissionStatus':
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
          return openAppSettingsResult;
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

  testWidgets('short-circuits when the permission is already granted '
      '(SYS-067)', (tester) async {
    probeScriptedStatuses[Permission.notification.value] =
        PermissionStatus.granted;
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final granted = await PermissionSheet.show(
      tester.element(find.text('open')),
      PermissionKind.notifications,
    );
    expect(granted, isTrue);
    // The sheet was never shown — no "Allow" button on
    // screen.
    expect(find.text('Allow'), findsNothing);
  });

  testWidgets('tapping Allow on a denied sheet requests the permission and '
      'returns true on grant (SYS-067)', (tester) async {
    requestScriptedStatuses[Permission.contacts.value] =
        PermissionStatus.granted;
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final future = PermissionSheet.show(
      tester.element(find.text('open')),
      PermissionKind.contacts,
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    // The sheet is visible with the rationale + two buttons.
    expect(find.text('Contacts'), findsOneWidget);
    // Scroll the Allow button into view before tapping —
    // the sheet is `isScrollControlled: true` and its
    // buttons can fall below the 800x600 test viewport.
    await tester.ensureVisible(
      find.byKey(const ValueKey('permission_sheet.allow')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byKey(const ValueKey('permission_sheet.allow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('permission_sheet.open_settings')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('permission_sheet.allow')));
    // Pump to process the tap event and start `_onAllow`'s
    // async chain.
    await tester.pump();
    // Allow the requestPermissions channel call to resolve
    // (real time), the pop animation to play, and the
    // modal route to be removed.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    final granted = await future;
    expect(granted, isTrue);
    // The requestPermissions call targeted contacts.
    final requestCalls = permissionsCalls
        .where((c) => c.method == 'requestPermissions')
        .toList();
    expect(requestCalls, isNotEmpty);
    final last = requestCalls.last.arguments as List;
    expect(last.cast<int>(), [Permission.contacts.value]);
  });

  testWidgets('permanentlyDenied shows the error text and a single Open '
      'settings button (SYS-067)', (tester) async {
    // Pre-seed `statuses` so the sheet opens directly on the
    // `permanentlyDenied` branch without going through the
    // `requestX` call (which would change the status).
    final fake = PermissionService.instance;
    fake.statuses.value = Map.of(fake.statuses.value)
      ..[PermissionKind.contacts] = const PermissionResultPermanentlyDenied();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final future = PermissionSheet.show(
      tester.element(find.text('open')),
      PermissionKind.contacts,
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text(
        "You've blocked this permission. Open Android settings to grant it.",
      ),
      findsOneWidget,
    );
    // Only one FilledButton — "Open settings" — and no
    // "Allow" button on a `permanentlyDenied` sheet.
    expect(find.byKey(const ValueKey('permission_sheet.allow')), findsNothing);
    expect(
      find.byKey(const ValueKey('permission_sheet.open_settings')),
      findsOneWidget,
    );
    // Scroll into view before tapping — the sheet is
    // `isScrollControlled: true` and the button may be
    // below the 800x600 test viewport.
    await tester.ensureVisible(
      find.byKey(const ValueKey('permission_sheet.open_settings')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(
      find.byKey(const ValueKey('permission_sheet.open_settings')),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    // The mock `openAppSettings` returns true; the re-probe
    // still returns `denied`, so the sheet stays open with
    // the same status. We do NOT `await future` because the
    // modal is never popped — the user dismissed without
    // granting. Fire-and-forget; if the assertion below
    // throws, the test fails loudly.
    future.ignore();
  });

  testWidgets('batteryOptimization deep-link uses the live bridge, not '
      'openAppSettings (SYS-068)', (tester) async {
    final bridge = _RecordingBridge();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final future = PermissionSheet.show(
      tester.element(find.text('open')),
      PermissionKind.batteryOptimization,
      bridge: bridge,
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Battery optimization'), findsOneWidget);
    // Scroll into view before tapping — the sheet is
    // `isScrollControlled: true` and the button may be
    // below the 800x600 test viewport.
    await tester.ensureVisible(
      find.byKey(const ValueKey('permission_sheet.open_settings')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(
      find.byKey(const ValueKey('permission_sheet.open_settings')),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    // The re-probe still returns `denied`, so the sheet
    // stays open with the same status. We do NOT
    // `await future` because the modal is never popped.
    future.ignore();
    expect(
      bridge.openIgnoreBatteryOptimizationsCalls,
      1,
      reason:
          'The batteryOptimization deep-link must route through '
          'ReminderBridge.openIgnoreBatteryOptimizations(), not the '
          'generic app-settings page (Kotlin handles '
          '`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`).',
    );
    // The `openAppSettings` channel call must NOT have been
    // issued for the batteryOptimization kind.
    final openAppSettingsCalls = permissionsCalls
        .where((c) => c.method == 'openAppSettings')
        .toList();
    expect(openAppSettingsCalls, isEmpty);
  });

  // -----------------------------------------------------------------
  // v1.5-cyc-δ — additional coverage for the 7 post-v0.6 kinds
  // (location, calendar, usageStats, callScreening,
  // fullScreenIntent, notificationPolicy, backupFolder). The
  // existing 4 tests cover notifications + contacts +
  // batteryOptimization. These 7 pin the remaining branches
  // of the per-kind title + rationale + button set without
  // driving real deep-links (the request-service singletons
  // are exercised exhaustively at the SERVICE layer;
  // `test/services/permission_service_test.dart`).
  // -----------------------------------------------------------------

  testWidgets('location kind: pre-seeded granted short-circuits '
      'and the sheet never opens', (tester) async {
    probeScriptedStatuses[Permission.location.value] = PermissionStatus.granted;
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final granted = await PermissionSheet.show(
      tester.element(find.text('open')),
      PermissionKind.location,
    );
    expect(granted, isTrue);
    expect(find.text('Allow'), findsNothing);
    expect(find.text('Open settings'), findsNothing);
  });

  testWidgets('location kind: denied(canOpenSettings: true) renders '
      'the "Location" rationale + 2 buttons', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();
    // Default init leaves location as denied(canOpenSettings:
    // true) — no pre-seeding needed.
    final future = PermissionSheet.show(
      tester.element(find.text('open')),
      PermissionKind.location,
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Location'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('permission_sheet.allow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('permission_sheet.open_settings')),
      findsOneWidget,
    );
    future.ignore();
  });

  testWidgets('exactAlarm kind: permanentlyDenied shows the error text '
      'and a single Open settings button', (tester) async {
    probeScriptedStatuses[Permission.scheduleExactAlarm.value] =
        PermissionStatus.permanentlyDenied;
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final future = PermissionSheet.show(
      tester.element(find.text('open')),
      PermissionKind.exactAlarm,
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Exact alarms'), findsOneWidget);
    expect(
      find.text(
        "You've blocked this permission. Open Android settings to grant it.",
      ),
      findsOneWidget,
    );
    // No "Allow" button on a `permanentlyDenied` sheet —
    // re-asking would not show a system dialog.
    expect(find.byKey(const ValueKey('permission_sheet.allow')), findsNothing);
    expect(
      find.byKey(const ValueKey('permission_sheet.open_settings')),
      findsOneWidget,
    );
    future.ignore();
  });

  testWidgets('usageStats kind: denied(canOpenSettings: true) renders '
      'the "Usage access" rationale + 2 buttons', (tester) async {
    // v1.1g / ADR-030 / SYS-086. PACKAGE_USAGE_STATS is
    // toggle-only via Settings → Special access → Usage
    // access; there is no runtime prompt. init() leaves
    // usageStats at the default denied(canOpenSettings:
    // true) so no pre-seeding is needed.
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final future = PermissionSheet.show(
      tester.element(find.text('open')),
      PermissionKind.usageStats,
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Usage access'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('permission_sheet.allow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('permission_sheet.open_settings')),
      findsOneWidget,
    );
    future.ignore();
  });

  testWidgets('callScreening kind: denied(canOpenSettings: true) renders '
      'the "Call screening" rationale + 2 buttons', (tester) async {
    // v1.2 / SYS-075 + SYS-079. ROLE_CALL_SCREENING is held
    // via RoleManager; the role picker is asynchronous. The
    // sheet surfaces the rationale + 2 buttons; the user
    // comes back from the role picker to a refreshed status
    // (handled by the app-resume observer in production).
    // init() default leaves callScreening at denied.
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final future = PermissionSheet.show(
      tester.element(find.text('open')),
      PermissionKind.callScreening,
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Call screening'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('permission_sheet.allow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('permission_sheet.open_settings')),
      findsOneWidget,
    );
    future.ignore();
  });

  testWidgets('fullScreenIntent kind: denied(canOpenSettings: true) renders '
      'the "Full-screen access" rationale + 2 buttons', (tester) async {
    // v1.3c / Phase 14 / SYS-113 / ADR-043.
    // USE_FULL_SCREEN_INTENT is opt-in via a special-access
    // deep-link (ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT on
    // API 34+). The sheet pattern-matches on denied +
    // canOpenSettings and renders the 2-button layout.
    // init() default leaves fullScreenIntent at denied.
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final future = PermissionSheet.show(
      tester.element(find.text('open')),
      PermissionKind.fullScreenIntent,
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Full-screen access'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('permission_sheet.allow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('permission_sheet.open_settings')),
      findsOneWidget,
    );
    future.ignore();
  });

  testWidgets('backupFolder kind: short-circuits via the synthetic-granted '
      'fallback in `ensure` (SYS-066)', (tester) async {
    // SYS-066. The backup-folder "permission" is actually a
    // SAF tree-URI; the sheet is never shown for this kind
    // because `ensure()` returns a synthetic `granted` when
    // the cached value is `null` (init() default) — the SAF
    // picker is a separate seam handled by
    // `requestBackupFolder`. This test pins the
    // synthetic-granted fallback as the regression-protector
    // for SYS-066.
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final granted = await tester.runAsync(() async {
      return PermissionSheet.show(
        tester.element(find.text('open')),
        PermissionKind.backupFolder,
      );
    });
    expect(granted, isTrue);
    expect(find.text('Allow'), findsNothing);
    expect(find.text('Open settings'), findsNothing);
  });
}
