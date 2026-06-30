// Full-screen intent — the high-importance notification
// surface for Strong-mode habits and routine-fired overlays.
//
// On a strong-mode habit, the notification's
// `AndroidNotificationDetails.fullScreenIntent` flag is set so
// the OS launches the app's `FullScreenActivity` (a thin Kotlin
// shell) which hosts the mission UI. The wake-lock is held
// at the Android Window level via `FLAG_KEEP_SCREEN_ON` on
// the activity (`android/app/src/main/kotlin/com/doit/
// FullScreenActivity.kt`); the flag is released automatically
// when the activity is destroyed. NO `wakelock_plus` package
// is in `pubspec.yaml` — this matches the v1.2e precedent
// (`docs/v_model/notification_reliability.md` §5).
//
// v1.2f / Phase 6: added [showRoutineOverlay] so the routine
// engine's `ActionFullscreen` arm has a typed seam. The
// habit-side `show(Do, MissionChain)` continues to be used by
// the reminder service for Strong-mode habit fires.
//
// v1.3d / Phase 15 / SYS-114 / ADR-044: added
// [LaunchIntent] / [LaunchMode] / [getLaunchIntent] so the
// Dart side can ask the Kotlin `FullScreenActivity` which
// kind of launch the current activity was opened for (the
// initial route carries the same info, but a follow-up
// `getLaunchIntent` read is the right shape for the
// routine-overlay path where the activity may also be
// re-entered while the user is on the lockscreen).

import 'dart:async';

import 'package:doit/do/do.dart';
import 'package:doit/missions/chain.dart';
import 'package:meta/meta.dart';

/// A launch request for the full-screen mission UI.
@immutable
class FullScreenLaunch {
  const FullScreenLaunch({required this.habit, required this.chain});
  final Do habit;
  final MissionChain chain;
}

/// A routine-fired full-screen overlay request (v1.2f / Phase
/// 6). Distinct from [FullScreenLaunch] because routine
/// actions carry no Do/MissionChain — the payload is a free-
/// form title/body pair from the matching engine.
@immutable
class RoutineOverlayLaunch {
  const RoutineOverlayLaunch({this.title, this.body});

  /// Optional headline shown on the overlay (e.g. the
  /// routine's name).
  final String? title;

  /// Optional body text (e.g. a one-line instruction).
  final String? body;

  @override
  bool operator ==(Object other) =>
      other is RoutineOverlayLaunch &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(title, body);
}

/// v1.3d / Phase 15 / SYS-114 / ADR-044. The launch kind
/// for the current `FullScreenActivity` instance. The
/// Kotlin `FullScreenIntentChannel.showHabitMission` /
/// `showRoutineOverlay` handlers write the matching Intent
/// extras; the Dart side either parses them out of the
/// initial route query string (via
/// `MaterialApp.onGenerateRoute`) or — for re-entries where
/// the initial route is no longer relevant — reads them via
/// `FullScreenIntent.getLaunchIntent()`.
enum LaunchMode {
  /// Strong-mode habit mission UI. Pairs with a
  /// non-null [LaunchIntent.habitId] pointing at the
  /// habit in the local DB.
  habit,

  /// Routine-fired overlay banner. Pairs with optional
  /// [LaunchIntent.title] / [LaunchIntent.body] copy.
  overlay,
}

/// v1.3d / Phase 15 / SYS-114 / ADR-044. The launch
/// intent for the current `FullScreenActivity` instance.
/// Read once at activity entry (via the route query
/// string parsed by `MaterialApp.onGenerateRoute`) or on
/// demand via [FullScreenIntent.getLaunchIntent]. The
/// Dart side uses the kind to dispatch between
/// `MissionLauncherScreen` (habit mode) and
/// `RoutineOverlayScreen` (overlay mode).
@immutable
class LaunchIntent {
  const LaunchIntent({required this.mode, this.habitId, this.title, this.body});

  /// The launch kind. See [LaunchMode].
  final LaunchMode mode;

  /// The habit id, populated iff [mode] is [LaunchMode.habit].
  final String? habitId;

  /// The overlay title, populated iff [mode] is
  /// [LaunchMode.overlay] AND the routine overlay caller
  /// supplied a title.
  final String? title;

  /// The overlay body, populated iff [mode] is
  /// [LaunchMode.overlay] AND the routine overlay caller
  /// supplied a body.
  final String? body;

  @override
  bool operator ==(Object other) =>
      other is LaunchIntent &&
      other.mode == mode &&
      other.habitId == habitId &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(mode, habitId, title, body);
}

abstract class FullScreenIntent {
  /// Show the full-screen mission UI for the given habit and
  /// mission chain.
  Future<void> show(Do habit, MissionChain chain);

  /// v1.2f / Phase 6: show a routine-fired full-screen
  /// overlay. The overlay is driven by an `ActionFullscreen`
  /// arm in the routine engine; the production wiring opens
  /// a translucent activity that floats above the lockscreen.
  /// On API 34+, the activity uses the
  /// `USE_FULL_SCREEN_INTENT` permission to bypass the
  /// keyguard; on lower APIs the overlay still renders but
  /// the user must unlock first.
  Future<void> showRoutineOverlay({String? title, String? body});

  /// v1.3d / Phase 15 / SYS-114 / ADR-044: read the launch
  /// intent for the current `FullScreenActivity` instance.
  /// Returns `null` if the activity was not launched as a
  /// full-screen intent (e.g., the activity is being shown
  /// for an unrelated reason in a future version).
  ///
  /// The Dart side typically parses the initial route query
  /// string for this data instead of calling this method
  /// (the route is set by `FullScreenActivity.getInitialRoute`).
  /// This method is the canonical read for re-entry scenarios
  /// and for tests that exercise the platform seam directly.
  Future<LaunchIntent?> getLaunchIntent();
}

/// In-memory implementation used by tests.
class FakeFullScreenIntent implements FullScreenIntent {
  final List<FullScreenLaunch> launches = <FullScreenLaunch>[];

  /// v1.2f / Phase 6: every routine-fired overlay request
  /// (in invocation order).
  final List<RoutineOverlayLaunch> routineOverlays = <RoutineOverlayLaunch>[];

  /// v1.3d / Phase 15 / SYS-114 / ADR-044: every
  /// `getLaunchIntent` return value, in invocation order.
  /// Tests that drive the launch path push to this list to
  /// simulate a Kotlin-side launch; tests that exercise the
  /// widget code read it to confirm the chain / overlay
  /// widget received the right launch data.
  final List<LaunchIntent?> launchIntents = <LaunchIntent?>[];

  /// What `getLaunchIntent()` should return on the next
  /// (and every subsequent) call. `null` means the activity
  /// has no launch intent (returns `null`). Tests set this
  /// in `setUp` to drive the widget test fixture.
  LaunchIntent? scriptedLaunchIntent;

  @override
  Future<void> show(Do habit, MissionChain chain) async {
    launches.add(FullScreenLaunch(habit: habit, chain: chain));
  }

  @override
  Future<void> showRoutineOverlay({String? title, String? body}) async {
    routineOverlays.add(RoutineOverlayLaunch(title: title, body: body));
  }

  @override
  Future<LaunchIntent?> getLaunchIntent() async {
    final intent = scriptedLaunchIntent;
    launchIntents.add(intent);
    return intent;
  }
}
