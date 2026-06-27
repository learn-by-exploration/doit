// Top-level route table for the do it app (v1.3d / Phase
// 15 / SYS-114 / ADR-044, extended in v1.4k / Phase 38 /
// SYS-125 / ADR-055 / WF-052).
//
// Extracted from `lib/main.dart` so widget tests can
// import the builders directly (the top-level `_private`
// functions in `main.dart` are not reachable across
// library boundaries). The dispatch shape is unchanged;
// the original `_buildMissionRoute` + the new
// `_buildHabitRoute` + `_buildWidgetConfigRoute` are all
// routed through a single top-level
// [buildAppRoute(RouteSettings)] function. `MaterialApp`
// passes `onGenerateRoute: buildAppRoute`.

import 'package:flutter/material.dart';

import 'package:doit/screens/add_habit.dart';
import 'package:doit/screens/home.dart';
import 'package:doit/screens/mission_launcher.dart';
import 'package:doit/screens/routine_overlay_screen.dart';
import 'package:doit/widget/widget_config_screen.dart';

/// Top-level router. Dispatches on the route name to the
/// matching builder. Returns `null` for non-matching
/// routes so `MaterialApp` falls back to its `home:`
/// switch.
Route<dynamic>? buildAppRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/mission':
      return buildMissionRoute(settings);
    case '/habit':
      return buildHabitRoute(settings);
    case '/widget-config':
      return buildWidgetConfigRoute(settings);
    default:
      return null;
  }
}

/// v1.3d / Phase 15 / SYS-114 / ADR-044. Resolves the
/// `/mission` route. Returns `null` for non-`/mission`
/// routes so `MaterialApp` falls back to the `home:`
/// switch above.
Route<dynamic>? buildMissionRoute(RouteSettings settings) {
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

/// v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052.
/// Resolves the `/habit?habitId=...` route used by the
/// widget body-tap PendingIntent. The route query string
/// carries the picked habit id (mirrors the
/// [buildMissionRoute] shape). An empty / missing
/// `habitId` falls back to [HomeScreen] so a stale tap
/// (the user deleted the do while the widget was bound)
/// does not surface a broken edit screen — matches the
/// `_unknownMissionRoute` empty-scaffold fallback.
Route<dynamic>? buildHabitRoute(RouteSettings settings) {
  if (settings.name != '/habit') return null;
  final args =
      (settings.arguments as Map<String, Object?>?) ??
      const <String, Object?>{};
  final habitId = (args['habitId'] as String?) ?? '';
  if (habitId.isEmpty) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const HomeScreen(),
    );
  }
  return MaterialPageRoute<bool?>(
    settings: settings,
    builder: (_) => AddHabitScreen(habitId: habitId),
  );
}

/// v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052.
/// Resolves the `/widget-config?widgetId=...` route used
/// by the Android AppWidget configuration activity
/// (`DoitWidgetConfigureActivity`). The picker is
/// read-only against `DoRepository.instance.listAll()` —
/// no `setSelectedHabitId` round-trip needed (the live
/// `WidgetService` singleton is reachable from the same
/// process via `WidgetServiceProxy`). A missing
/// `widgetId` falls back to `null` for tests.
Route<dynamic>? buildWidgetConfigRoute(RouteSettings settings) {
  if (settings.name != '/widget-config') return null;
  final args =
      (settings.arguments as Map<String, Object?>?) ??
      const <String, Object?>{};
  final widgetId = (args['widgetId'] as int?);
  return MaterialPageRoute<String?>(
    settings: settings,
    builder: (_) => WidgetConfigScreen(widgetId: widgetId),
  );
}
