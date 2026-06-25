// Platform full-screen intent — production wiring.
//
// The Kotlin `ReminderChannelProxy` (Phase 4) launches the
// `FullScreenActivity` (a thin shell that hosts a Flutter
// route to `/mission`). The Dart side records the launch
// intent and the Kotlin side carries it out.
//
// This file is the production-side stub that
// `main.dart` constructs. Widget tests use
// [FakeFullScreenIntent].
//
// v1.3d / Phase 15 / SYS-114 / ADR-044: added the
// `getLaunchIntent` method-channel read so the Dart
// side can recover the launch kind (habit vs overlay)
// for re-entry scenarios. The initial-route query
// string parsed by `MaterialApp.onGenerateRoute` is the
// canonical read on first launch; `getLaunchIntent` is
// the canonical read for re-entry / on-demand use.
// The `_safe` wrapper covers the new method (defense
// in depth per ADR-013).

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';

import 'package:doit/do/do.dart';
import 'package:doit/missions/chain.dart';
import 'package:doit/reminders/full_screen_intent.dart';

/// Production implementation of [FullScreenIntent]. Talks to
/// the Kotlin `ReminderChannelProxy` over the
/// `doit/full_screen` method channel.
class PlatformFullScreenIntent implements FullScreenIntent {
  PlatformFullScreenIntent({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('doit/full_screen');

  final MethodChannel _channel;

  @override
  Future<void> show(Do habit, MissionChain chain) async {
    // The Kotlin side does the actual launch. The Dart side
    // just records the intent. The chain is persisted in the
    // local DB so the activity can re-derive it on resume.
    await _safe('showHabitMission', () async {
      await _channel.invokeMethod<void>('showHabitMission', {
        'habitId': habit.id,
      });
    });
  }

  @override
  Future<void> showRoutineOverlay({String? title, String? body}) async {
    // v1.2f / Phase 6: route the routine-fired overlay
    // request to the Kotlin `ReminderChannelProxy`. The
    // proxy opens a translucent `FullScreenActivity` with
    // `USE_FULL_SCREEN_INTENT` (API 34+). The activity is
    // dismissable; the routine executor only publishes a
    // fire event, so the overlay is one-shot.
    await _safe('showRoutineOverlay', () async {
      final args = <String, Object>{};
      if (title != null) args['title'] = title;
      if (body != null) args['body'] = body;
      await _channel.invokeMethod<void>('showRoutineOverlay', args);
    });
  }

  @override
  Future<LaunchIntent?> getLaunchIntent() async {
    // v1.3d / Phase 15 / SYS-114 / ADR-044: read the
    // launch intent for the current `FullScreenActivity`
    // instance. The Kotlin side does NOT implement this
    // method (it is not in `FullScreenIntentChannel.kt`'s
    // `when` dispatch); the method-channel read returns
    // `MissingPluginException`, the `_safe` wrapper
    // swallows it, and `getLaunchIntent` returns `null`.
    //
    // Production code that needs the launch intent reads
    // it from the initial route query string (parsed by
    // `MaterialApp.onGenerateRoute` in `lib/main.dart`)
    // rather than calling this method. The method exists
    // for symmetry with the [FullScreenIntent] interface
    // and for test fixtures that drive the channel seam
    // directly.
    return _safeResult<LaunchIntent>(
      'getLaunchIntent',
      () => _channel.invokeMethod<LaunchIntent>('getLaunchIntent'),
    );
  }

  /// Swallow `MissingPluginException` and other platform
  /// failures behind [kDebugMode] (ADR-013). A platform-side
  /// failure must NEVER bubble out of the executor's action
  /// dispatch path — the matching engine still publishes
  /// `AutomationFired` and the routine banner still renders.
  Future<void> _safe(String label, Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PlatformFullScreenIntent.$label: $e');
      }
    }
  }

  /// v1.3d / SYS-114: same defense-in-depth policy as
  /// `_safe`, but returns the result (or `null` on a
  /// swallowed exception). Used by `getLaunchIntent` —
  /// the channel seam does not yet implement the read,
  /// so a `MissingPluginException` is the expected
  /// production outcome and must NOT crash the caller.
  Future<T?> _safeResult<T>(String label, Future<T?> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PlatformFullScreenIntent.$label: $e');
      }
      return null;
    }
  }
}
