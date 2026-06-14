// Streak — entry point.
//
// Wires up the singletons (DB, reminder, settings) before
// `runApp` and mounts a `MultiProvider` so widgets can read
// them via `context.watch` / `context.read`. The default route
// is the Home screen; onboarding is shown only on first
// launch (the `firstLaunch` flag is hard-coded `true` in v0.1
// — the persisted flag is a v0.2 line item).

import 'package:flutter/material.dart';

import 'package:common_games/reminders/anchor_detector.dart';
import 'package:common_games/reminders/reminder_bridge.dart';
import 'package:common_games/screens/home.dart';
import 'package:common_games/screens/onboarding.dart';
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

  // 3. Init settings (no-op in v0.1; persisted in v0.2).
  await SettingsService.instance.init();

  runApp(const StreakApp());
}

/// Root widget. Reads the current theme from
/// [SettingsService] and shows the home screen.
class StreakApp extends StatelessWidget {
  const StreakApp({super.key, this.firstLaunch = true});

  /// True on the first launch. In v0.1 this is hard-coded —
  /// the persisted flag is a v0.2 follow-up.
  final bool firstLaunch;

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
        builder: (_, mode, _) => MaterialApp(
          title: 'Streak',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: firstLaunch
              ? OnboardingScreen(
                  onDone: () {
                    // In v0.1 we just rebuild without
                    // onboarding. v0.2 persists the flag.
                  },
                )
              : const HomeScreen(),
        ),
      ),
    );
  }
}
