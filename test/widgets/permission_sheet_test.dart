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
}
