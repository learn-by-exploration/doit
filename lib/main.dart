// Streak — entry point.
//
// Wires up the singletons (DB, reminder, settings) before
// `runApp` and mounts a `MultiProvider` so widgets can read
// them via `context.watch` / `context.read`. The default route
// is decided by [SettingsService.firstLaunchCompleted]; a
// fresh install shows the onboarding screen, a returning user
// sees the home screen directly.

import 'package:flutter/material.dart';

import 'package:common_games/reminders/anchor_detector.dart';
import 'package:common_games/reminders/reminder_bridge.dart';
import 'package:common_games/screens/home.dart';
import 'package:common_games/screens/onboarding.dart';
import 'package:common_games/services/backup_scheduler.dart';
import 'package:common_games/services/backup_service.dart';
import 'package:common_games/services/db.dart';
import 'package:common_games/services/platform_alarm_scheduler.dart';
import 'package:common_games/services/platform_full_screen_intent.dart';
import 'package:common_games/services/platform_notification_service.dart';
import 'package:common_games/services/reminder_service.dart';
import 'package:common_games/services/settings_service.dart';
import 'package:common_games/theme/app_theme.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Open the database.
  await AppDatabaseService.instance.init();

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

  // 4. Init the backup service so the restore screen can
  //    export / import JSON snapshots of the local DB.
  await BackupService.instance.init();

  // 5. Init the WorkManager-backed nightly backup scheduler
  //    (v0.4b / SYS-060). The schedule itself is registered
  //    later, from the settings screen, so users can opt out.
  await BackupScheduler.instance.init();

  runApp(const StreakApp());
}

/// Root widget. Reads the current theme and the persisted
/// first-launch flag from [SettingsService].
class StreakApp extends StatelessWidget {
  const StreakApp({super.key, this.firstLaunchOverride});

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
            title: 'Streak',
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
