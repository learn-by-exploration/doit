// Full-screen intent — the high-importance notification
// surface for Strong-mode habits.
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

import 'dart:async';

import 'package:common_games/habits/habit.dart';
import 'package:common_games/missions/chain.dart';
import 'package:meta/meta.dart';

/// A launch request for the full-screen mission UI.
@immutable
class FullScreenLaunch {
  const FullScreenLaunch({required this.habit, required this.chain});
  final Habit habit;
  final MissionChain chain;
}

abstract class FullScreenIntent {
  /// Show the full-screen mission UI for the given habit and
  /// mission chain.
  Future<void> show(Habit habit, MissionChain chain);
}

/// In-memory implementation used by tests.
class FakeFullScreenIntent implements FullScreenIntent {
  final List<FullScreenLaunch> launches = <FullScreenLaunch>[];

  @override
  Future<void> show(Habit habit, MissionChain chain) async {
    launches.add(FullScreenLaunch(habit: habit, chain: chain));
  }
}
