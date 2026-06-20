// do it — entry point.
//
// Wires up the singletons (DB, reminder, settings) before
// `runApp` and mounts a `MultiProvider` so widgets can read
// them via `context.watch` / `context.read`. The default route
// is decided by [SettingsService.firstLaunchCompleted]; a
// fresh install shows the onboarding screen, a returning user
// sees the home screen directly.

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';

import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/screens/home.dart';
import 'package:doit/screens/onboarding.dart';
import 'package:doit/services/backup_scheduler.dart';
import 'package:doit/services/backup_service.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/geofence_service.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/platform_alarm_scheduler.dart';
import 'package:doit/services/platform_full_screen_intent.dart';
import 'package:doit/services/platform_notification_service.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/services/template_repository.dart';
import 'package:doit/templates/template_library.dart';
import 'package:doit/routines/routine_executor.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Open the database.
  await AppDatabaseService.instance.init();

  // 1a. Seed the curated template library (v1.0 Phase B).
  //    Idempotent: the first call inserts all 25 built-ins; a
  //    subsequent call (e.g., after a restore that re-populated
  //    the templates table) is a no-op. Wired here — not in
  //    `AppDatabaseService.init()` — so the test init() path
  //    does not pollute the in-memory DB.
  await TemplateLibrary.seedBuiltIns(TemplateRepository.instance);

  // 2. Wire the reminder service. The production wiring is
  //    a no-op stub — the Kotlin side does the real
  //    AlarmManager work and pings the Dart side when an
  //    alarm fires.
  final bridge = PlatformReminderBridge()..install();
  await ReminderService.init(
    ReminderService(
      scheduler: PlatformAlarmScheduler(bridge),
      notifications: PlatformNotificationService(bridge),
      fullScreen: PlatformFullScreenIntent(),
      anchor: FakeAnchorDetector(),
      bridge: bridge,
    ),
  );

  // 3. Init settings. The v0.4a.3 (SYS-059) first-launch flag
  //    is loaded here; the gate ensures widgets only read it
  //    after the SharedPreferences read has completed.
  await SettingsService.instance.init();

  // 4. Init the permission service. This probes the three
  //    runtime permissions (POST_NOTIFICATIONS, READ_CONTACTS,
  //    SCHEDULE_EXACT_ALARM, ACCESS_COARSE_LOCATION) and
  //    populates the [PermissionService.statuses] ValueNotifier
  //    that the v0.5d Settings → Permissions tile binds to.
  //    Without this call, the singleton's `_ready` Completer
  //    would never complete and every `requestX()` call
  //    (including the onboarding "Allow" buttons) would block
  //    on `await ready` indefinitely.
  await PermissionService.instance.init();

  // 4a. v1.0 Phase C PR 2 (SYS-072 / ADR-021): init the
  //     geofence service. The service starts the platform
  //     position stream; the executor wires the matching
  //     stream subscription below. Order matters: we init
  //     the geofence service BEFORE the executor so the
  //     executor's `register(...)` calls land on a ready
  //     stream. The permission itself is NOT requested here
  //     — the on-demand `LocationPicker` shows
  //     [PermissionSheet.show] first.
  await GeofenceService.instance.init();

  // 4b. v1.0 Phase C PR 1/2 (SYS-069..072): init the
  //     routine executor. The executor subscribes to
  //     [GeofenceService.events]; the actual automations
  //     are registered by the add-* screens via
  //     [RoutineExecutor.register] when a Do/Event/Person
  //     is saved. Idempotent.
  await RoutineExecutor.instance.init();

  // 5. Init the backup service so the restore screen can
  //    export / import JSON snapshots of the local DB.
  await BackupService.instance.init();

  // 6. Init the WorkManager-backed nightly backup scheduler
  //    (v0.4b / SYS-060). The schedule itself is registered
  //    later, from the settings screen, so users can opt out.
  //
  //    v0.4b release-mode fix: this call MUST NOT block
  //    `runApp`. If the workmanager plugin is missing (a
  //    build without the plugin side wired up, an OEM that
  //    has killed WorkManager, a stale callback handle, etc.)
  //    the app must still launch and the user must still be
  //    able to use every other feature. The service's own
  //    `init()` already swallows the exception and logs it
  //    (debug-only); the outer try/catch is defense in depth.
  //    See ADR-013.
  try {
    await BackupScheduler.instance.init();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('BackupScheduler.init() failed: $e\n$st');
    }
  }

  runApp(const DoItApp());
}

/// Root widget. Reads the current theme and the persisted
/// first-launch flag from [SettingsService].
class DoItApp extends StatelessWidget {
  const DoItApp({super.key, this.firstLaunchOverride});

  /// Test-only override for the persisted first-launch flag.
  /// When `null` (the production default), the widget reads
  /// [SettingsService.firstLaunchCompleted]. When set, the
  /// widget uses the override directly. The override is a
  /// per-mount switch so the widget test does not have to
  /// reach into [SharedPreferences] from a child test.
  final bool? firstLaunchOverride;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(
          value: SettingsService.instance,
        ),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: SettingsService.instance.themeMode,
        builder: (_, mode, _) => ValueListenableBuilder<bool>(
          valueListenable: SettingsService.instance.firstLaunchCompleted,
          builder: (_, firstLaunchDone, _) => MaterialApp(
            title: 'do it',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            home: (firstLaunchOverride ?? !firstLaunchDone)
                ? OnboardingScreen(
                    // v0.4a.3 (SYS-059): persist the flag so the
                    // next mount skips onboarding. The notifier
                    // updates synchronously, so the
                    // ValueListenableBuilder above will rebuild
                    // on the next frame.
                    // ignore: discarded_futures
                    onDone: SettingsService.instance.markFirstLaunchCompleted,
                  )
                : const HomeScreen(),
          ),
        ),
      ),
    );
  }
}
