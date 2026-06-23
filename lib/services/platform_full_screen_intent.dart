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
}
