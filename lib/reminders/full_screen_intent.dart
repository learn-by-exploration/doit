// Full-screen intent — the high-importance notification
// surface for Strong-mode habits and routine-fired overlays.
//
// On a strong-mode habit, the notification's
// `AndroidNotificationDetails.fullScreenIntent` flag is set so
// the OS launches the app's `FullScreenActivity` (a thin Kotlin
// shell) which hosts the mission UI. The activity holds a
// `wakelock_plus` lock while the mission is on screen; the
// lock is released on close.
//
// This file is a thin Dart-side wrapper that records the
// intent-to-show. The actual platform call lives in the Kotlin
// `MainActivity` (or a dedicated `FullScreenLauncher`). Tests
// use [FakeFullScreenIntent].
//
// v1.2f / Phase 6: added [showRoutineOverlay] so the routine
// engine's `ActionFullscreen` arm has a typed seam. The
// habit-side `show(Do, MissionChain)` continues to be used by
// the reminder service for Strong-mode habit fires.

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
}

/// In-memory implementation used by tests.
class FakeFullScreenIntent implements FullScreenIntent {
  final List<FullScreenLaunch> launches = <FullScreenLaunch>[];

  /// v1.2f / Phase 6: every routine-fired overlay request
  /// (in invocation order).
  final List<RoutineOverlayLaunch> routineOverlays = <RoutineOverlayLaunch>[];

  @override
  Future<void> show(Do habit, MissionChain chain) async {
    launches.add(FullScreenLaunch(habit: habit, chain: chain));
  }

  @override
  Future<void> showRoutineOverlay({String? title, String? body}) async {
    routineOverlays.add(RoutineOverlayLaunch(title: title, body: body));
  }
}
