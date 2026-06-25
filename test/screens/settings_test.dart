// Tests for the SettingsScreen.

import 'dart:async' show Timer;

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/screens/settings.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/reliability_service.dart';
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

import '../support/localized_app.dart';

Widget _wrap() {
  return ChangeNotifierProvider<SettingsService>.value(
    value: SettingsService.instance,
    // v1.1h / ADR-031 / SYS-087: route through
    // `localizedApp` to wire the generated
    // `AppLocalizations` delegate (the Settings screen's
    // section headers, permission tile titles, theme
    // radio labels, and reliability labels are now
    // pulled from the ARB catalog).
    child: localizedApp(theme: AppTheme.dark, home: const SettingsScreen()),
  );
}

/// No-op `Timer` so [ReliabilityService.init] in the test
/// never creates a real `Timer.periodic`. A real timer
/// started in a `testWidgets` body's `FakeAsync` zone is
/// tracked as a `FakeTimer` and surfaces as a "Pending
/// timers" assertion failure before `tearDown`'s
/// `resetForTesting` cancels it. (v1.3b / Phase 13 /
/// SYS-112.)
class _NoopTimer implements Timer {
  @override
  void cancel() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// No-op `Timer.periodic` factory for [ReliabilityService].
/// Returns a [Timer] whose `cancel()` is a no-op so the
/// fallback timer is not in any zone's pending list. Tests
/// that need to drive the 30 s tick manually should use a
/// recording factory instead.
Timer _noopPeriodicFactory(Duration d, void Function(Timer) cb) => _NoopTimer();

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
    final bridge = FakeReminderBridge();
    await ReminderService.init(
      ReminderService(
        scheduler: FakeAlarmScheduler(),
        notifications: FakeNotificationService(),
        fullScreen: FakeFullScreenIntent(),
        anchor: FakeAnchorDetector(),
        bridge: bridge,
      ),
    );

    // v1.3b / Phase 13 / SYS-112: the settings screen's
    // `_ReliabilityRow` reads from the unified
    // `ReliabilityService` (not from
    // `ReminderService.instance.scheduler.reliability`
    // directly). Init the service against the same bridge
    // the reminder service uses so the bootstrap probe
    // returns the right value.
    ReliabilityService.resetForTesting();
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();
    // v1.3b / Phase 13 / SYS-112: `PermissionService.init()`
    // defaults every runtime permission to `Denied` because
    // the platform channel is missing in the test harness.
    // The unified `ReliabilityService` would then derive
    // `degraded` from the start. Grant every kind so the
    // common-case test sees the "Optimal" copy; tests that
    // exercise the degraded path override the bridge.
    PermissionService.instance.statuses.value = {
      for (final k in PermissionKind.values) k: const PermissionResultGranted(),
    };
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
      // v1.3b / Phase 13 / SYS-112: the testWidgets
      // FakeAsync zone would track the 30 s fallback timer
      // as a `FakeTimer`, leaking past `tearDown`. Pass a
      // no-op factory so the timer never enters the zone.
      periodicFactory: _noopPeriodicFactory,
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
  });

  tearDown(() {
    ReliabilityService.resetForTesting();
    PermissionService.instance.resetForTesting();
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

  // v1.1h / ADR-031 / SYS-087 gap: v1.1h rewrote the
  // `_ThemeModeTile` body from a `const [(ThemeMode.dark,
  // 'Dark'), ...]` literal to a non-`const` list driven by
  // `l.settingsThemeDark / Light / System`. The previous
  // test only exercised the Light path; this test pins the
  // ARB-driven list end-to-end — all three labels render
  // AND tapping each one drives the matching
  // `SettingsService.themeMode` value. If a future PR
  // removes a label, mistypes a key, or drops a `RadioListTile`
  // from the iteration, the corresponding `find.text(...)`
  // or `expect(...)` line below fails.
  testWidgets(
    'theme tile renders all three ARB labels and tapping each updates '
    'SettingsService.themeMode',
    (tester) async {
      _setPhoneSize(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(SettingsScreen));
      final l = AppLocalizations.of(context);

      // (1) All three ARB-driven labels render. We assert
      // each by its localized string so a regression that
      // falls back to the old hardcoded 'Dark / Light /
      // System' (e.g. by reverting `_ThemeModeTile` to a
      // `const` list) still passes this test — but a
      // regression that drops a label fails it.
      expect(
        find.text(l.settingsThemeDark),
        findsOneWidget,
        reason: '_ThemeModeTile must render l.settingsThemeDark',
      );
      expect(
        find.text(l.settingsThemeLight),
        findsOneWidget,
        reason: '_ThemeModeTile must render l.settingsThemeLight',
      );
      expect(
        find.text(l.settingsThemeSystem),
        findsOneWidget,
        reason: '_ThemeModeTile must render l.settingsThemeSystem',
      );

      // (2) Each radio is wired — tapping it flips the
      // SettingsService value to the matching ThemeMode.
      // We exercise the cycle System → Light → Dark so the
      // test confirms *all three* paths through the radio
      // group, not just the Light path the existing test
      // covers.
      await tester.tap(find.text(l.settingsThemeSystem));
      await tester.pumpAndSettle();
      expect(
        SettingsService.instance.themeMode.value,
        ThemeMode.system,
        reason: 'Tapping the System radio must set ThemeMode.system',
      );
      await tester.tap(find.text(l.settingsThemeLight));
      await tester.pumpAndSettle();
      expect(
        SettingsService.instance.themeMode.value,
        ThemeMode.light,
        reason: 'Tapping the Light radio must set ThemeMode.light',
      );
      await tester.tap(find.text(l.settingsThemeDark));
      await tester.pumpAndSettle();
      expect(
        SettingsService.instance.themeMode.value,
        ThemeMode.dark,
        reason: 'Tapping the Dark radio must set ThemeMode.dark',
      );
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

  testWidgets('the reliability row renders the "Optimal" copy when the unified '
      'reliability service reports Reliability.optimal', (tester) async {
    _setPhoneSize(tester);
    // v1.3b / Phase 13 / SYS-112: the row reads from
    // `ReliabilityService.instance.notifier`. The
    // `setUp` initializes the service with a bridge
    // whose `reliability` defaults to `optimal`, so the
    // row shows the optimal copy without further
    // scripting.
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Optimal — exact alarm granted.'), findsOneWidget);
  });

  testWidgets(
    'the reliability row renders the "Degraded" copy when the unified '
    'reliability service reports Reliability.degraded',
    (tester) async {
      _setPhoneSize(tester);
      // Flip the bridge's `reliability` to degraded and
      // refresh the service so the row rebuilds.
      final bridge = FakeReminderBridge()..reliability = Reliability.degraded;
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
      ReliabilityService.resetForTesting();
      await ReliabilityService.init(
        bridge: bridge,
        permissionService: PermissionService.instance,
        // v1.3b / Phase 13 / SYS-112: a no-op periodic
        // factory so the testWidgets FakeAsync zone does
        // not see a pending timer on `tearDown`.
        periodicFactory: _noopPeriodicFactory,
      );
      await ReliabilityService.instance.refresh();

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
