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
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/screens/home.dart';
import 'package:doit/screens/mission_launcher.dart';
import 'package:doit/screens/onboarding.dart';
import 'package:doit/screens/routine_overlay_screen.dart';
import 'package:doit/services/backup_scheduler.dart';
import 'package:doit/services/backup_service.dart';
import 'package:doit/services/call_interceptor.dart';
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/geofence_service.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/permission_lifecycle_observer.dart';
import 'package:doit/services/platform_alarm_scheduler.dart';
import 'package:doit/services/platform_full_screen_intent.dart';
import 'package:doit/services/platform_notification_service.dart';
import 'package:doit/widget/widget_bridge.dart';
import 'package:doit/services/reliability_service.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/widget_service.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/services/template_repository.dart';
import 'package:doit/templates/template_library.dart';
import 'package:doit/routines/routine_executor.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/l10n/gen/app_localizations.dart';
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
  //
  //    v1.2e / Phase 5: the bridge now carries an inbound
  //    callback that the Kotlin `AlarmReceiver` invokes
  //    via `ReminderChannelProxy.fireAlarm(alarmId)`. The
  //    callback looks up the scheduled entry, renders
  //    the notification (or full-screen intent for
  //    strong-mode habits), then either re-schedules the
  //    next habit occurrence or archives a one-shot event.
  final bridge = PlatformReminderBridge(
    inbound: const _ReminderInboundAdapter(),
  )..install();
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

  // 4a-bis. v1.2i / Phase 9 / SYS-104: register a
  //    lifecycle observer that re-probes permissions when
  //    the app resumes (the user just came back from
  //    Settings → Special access → Usage access or the
  //    OS role picker). The observer is process-scoped;
  //    there is no dispose path. See
  //    `lib/services/permission_lifecycle_observer.dart`.
  WidgetsBinding.instance.addObserver(PermissionLifecycleReProbe());

  // 4a-ter. v1.3b / Phase 13 / SYS-112 / ADR-042: init
  //    the unified `ReliabilityService`. The service
  //    merges `PermissionService.statuses` with the
  //    alarm-system bridge probe and exposes a single
  //    `Stream<Reliability>` (mirror: `ValueListenable`)
  //    for the home-screen banner and the settings page.
  //    Must be wired AFTER `PermissionService.instance.init`
  //    so the first derive step sees a populated statuses
  //    map, and AFTER the bridge is constructed (so
  //    `probeReliability` is available). The
  //    `PermissionLifecycleReProbe` above calls
  //    `ReliabilityService.refresh()` on every non-cold-
  //    start resume, so the banner does not need a
  //    separate observer.
  await ReliabilityService.init(
    bridge: bridge,
    permissionService: PermissionService.instance,
  );

  // v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042: init
  //    the home widget service. The service subscribes to
  //    `ReliabilityService.instance.reliability` and re-
  //    derives the widget state on every change. The
  //    bridge writes the freshly-computed state to the
  //    Kotlin `WidgetStateCache` so the cold-start
  //    fallback has the last-known state. Order matters:
  //    `ReliabilityService.init` must run BEFORE
  //    `WidgetService.init` so the first derive step
  //    reads a populated reliability value. The do
  //    repository + completion-log singleton are already
  //    ready by this point (the Drift init at step 1
  //    primed them).
  await WidgetService.init(
    bridge: PlatformWidgetBridge(),
    doRepository: DoRepository.instance,
    completionLog: CompletionLogService.instance,
    reliabilityService: ReliabilityService.instance,
  );

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

  // 4b. v1.0 Phase F PR 1 (SYS-075 / ADR-019): init the
  //     call-interceptor service. The service installs the
  //     `doit/call_interceptor` method-channel handler and
  //     primes the source. The screening service itself is
  //     bound by the OS — `init()` is a no-op on the
  //     Kotlin side; the Dart side just subscribes to the
  //     future `onCallEvent` pushes. Idempotent.
  await CallInterceptorService.instance.init();

  // 4c. v1.0 Phase C PR 1/2 (SYS-069..072) + Phase F PR 1
  //     (SYS-075): init the routine executor. The executor
  //     subscribes to [GeofenceService.events],
  //     [CalendarService.events], and
  //     [CallInterceptorService.events]; the actual
  //     automations are registered by the add-* screens via
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
            // v1.1h / ADR-031 / SYS-087: wire the
            // generated `AppLocalizations` delegate into
            // MaterialApp. The delegate is a
            // `LocalizationsDelegate<AppLocalizations>`
            // that loads the right ARB on
            // `Locale` change; the supported list is
            // `[en, es]` today (mirrored by
            // `AppLocalizations.supportedLocales`). The
            // AppBar titles, snackbars, and onboarding
            // copy are pulled from this delegate instead
            // of hardcoded `Text('...')`.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // v1.3d / Phase 15 / SYS-114 / ADR-044:
            // resolves the `/mission` route set by the
            // Kotlin `FullScreenActivity.getInitialRoute()`.
            // The route query string carries the launch
            // mode (`habit` | `overlay`) and the
            // matching payload (`habitId` | `title` /
            // `body`). The router picks the right widget
            // — `MissionLauncherScreen` for habit
            // launches (loads the habit from the DB and
            // iterates the mission chain), or
            // `RoutineOverlayScreen` for routine-fired
            // overlay launches (banner-style dismissable
            // surface). Unknown `/mission` shapes fall
            // through to `onUnknownRoute` so the app
            // does not crash on a malformed query.
            //
            // The `home:` switch below is unchanged —
            // this router is additive and is only
            // consulted when the Kotlin-side
            // `FullScreenActivity` provides a non-null
            // initial route (the embedding routes that
            // through `onGenerateRoute` on the first
            // frame).
            onGenerateRoute: _buildMissionRoute,
            onUnknownRoute: _unknownMissionRoute,
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

/// v1.3d / Phase 15 / SYS-114 / ADR-044. Resolves the
/// `/mission` route. Returns `null` for non-`/mission`
/// routes so `MaterialApp` falls back to the `home:`
/// switch above.
Route<dynamic>? _buildMissionRoute(RouteSettings settings) {
  if (settings.name != '/mission') return null;
  final args =
      (settings.arguments as Map<String, Object?>?) ??
      const <String, Object?>{};
  final mode = (args['mode'] as String?) ?? 'habit';
  switch (mode) {
    case 'overlay':
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => RoutineOverlayScreen(
          title: args['title'] as String?,
          body: args['body'] as String?,
        ),
      );
    case 'habit':
    default:
      final habitId = (args['habitId'] as String?) ?? '';
      return MaterialPageRoute<bool?>(
        settings: settings,
        builder: (_) => MissionLauncherScreen(habitId: habitId),
      );
  }
}

/// v1.3d / Phase 15 / SYS-114 / ADR-044. Catch-all for
/// malformed `/mission` query strings (e.g., empty
/// `habitId`, missing `mode`). Returns a blank scaffold
/// that pops immediately so the activity does not show
/// a broken UI.
Route<dynamic> _unknownMissionRoute(RouteSettings settings) {
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) {
      return const Scaffold(body: SizedBox.shrink());
    },
  );
}

/// v1.2e / Phase 5: inbound adapter that wires the
/// [PlatformReminderBridge] dispatch table to the
/// `ReminderService.onFireAlarm` instance method. The
/// `PlatformReminderBridge` constructor takes a
/// `ReminderInbound?`; this class is the production
/// implementation.
///
/// The adapter is a thin class (no state, just a method)
/// so the bridge can hold it without creating a circular
/// init dependency: `main.dart` constructs the adapter,
/// the bridge, and the `ReminderService` in order, then
/// sets the service on the adapter via a late-initialized
/// reference. By the time the first `fireAlarm` arrives,
/// the service is initialized.
class _ReminderInboundAdapter implements ReminderInbound {
  const _ReminderInboundAdapter();

  @override
  Future<void> onRescheduleAll() async {
    await ReminderService.instance.rescheduleAll();
  }

  @override
  Future<void> onFireAlarm(int alarmId) async {
    await ReminderService.instance.onFireAlarm(AlarmId(alarmId));
  }
}
