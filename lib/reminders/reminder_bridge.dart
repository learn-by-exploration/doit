// Platform bridge for reminders.
//
// The Kotlin side (BootReceiver, MainActivity) talks to Dart
// through a single [MethodChannel] named `doit/reminders`.
// The Dart side is the source of truth for "what to schedule";
// the Kotlin side is a thin wrapper that just calls into
// `AlarmManager` and `WorkManager`.
//
// Methods invoked from Kotlin → Dart:
//   - `rescheduleAll`: re-arm every pending habit. Called on
//     `BOOT_COMPLETED`, `LOCKED_BOOT_COMPLETED`,
//     `MY_PACKAGE_REPLACED`, and `TIMEZONE_CHANGED`.
//   - `recordAnchor(at: ISO8601)`: record a wake-up anchor.
//     Called by the Kotlin `UserPresentReceiver`.
//
// Methods invoked from Dart → Kotlin:
//   - `setExactAlarm(alarmId: int, epochMs: long)`: arm an exact
//     alarm. Returns the alarm id.
//   - `cancelAlarm(alarmId: int)`: cancel.
//   - `showFullScreen(habitId: String)`: launch the full-screen
//     activity.
//
// Tests can swap in a [FakeReminderBridge] that records calls
// without touching the platform.

import 'dart:async';

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:flutter/services.dart';

/// Public surface for the Kotlin ↔ Dart bridge.
abstract class ReminderBridge {
  /// Hand off a "reschedule all pending habits" call to the
  /// platform. The platform side reads the local DB and arms
  /// every pending alarm.
  Future<void> rescheduleAll();

  /// Hand off an anchor event to the platform.
  Future<void> recordAnchor(DateTime at);

  /// Probe the platform for the current reliability state.
  Future<Reliability> probeReliability();
}

/// Inbound callbacks from Kotlin to Dart. The Dart side
/// implements this and the bridge dispatches.
abstract class ReminderInbound {
  /// The Kotlin side (BootReceiver, AlarmReceiver) is asking
  /// the Dart side to re-arm every pending habit.
  Future<void> onRescheduleAll();

  /// The Kotlin AlarmReceiver fired an alarm. The Dart side
  /// shows the notification and queues the next occurrence.
  Future<void> onFireAlarm(int alarmId);
}

/// The default bridge — wraps a [MethodChannel] for
/// `doit/reminders`. Constructed in `main.dart` after
/// `WidgetsFlutterBinding.ensureInitialized()`.
class PlatformReminderBridge implements ReminderBridge {
  PlatformReminderBridge({this.inbound});

  static const _channel = MethodChannel('doit/reminders');

  /// Optional inbound handler. Set after construction.
  final ReminderInbound? inbound;

  /// Wire the inbound handler. Called once from `main.dart`
  /// after constructing the bridge.
  void install() {
    _channel.setMethodCallHandler(_dispatch);
  }

  Future<dynamic> _dispatch(MethodCall call) async {
    final handler = inbound;
    switch (call.method) {
      case 'rescheduleAll':
        if (handler == null) return null;
        await handler.onRescheduleAll();
        return null;
      case 'fireAlarm':
        if (handler == null) return null;
        final args = call.arguments as Map<dynamic, dynamic>?;
        final id = args?['alarmId'] as int? ?? -1;
        if (id == -1) return null;
        await handler.onFireAlarm(id);
        return null;
      default:
        throw MissingPluginException(
          'doit/reminders has no method ${call.method}',
        );
    }
  }

  @override
  Future<void> rescheduleAll() async {
    await _channel.invokeMethod<void>('rescheduleAll');
  }

  @override
  Future<void> recordAnchor(DateTime at) async {
    await _channel.invokeMethod<void>('recordAnchor', {
      'atIso': at.toIso8601String(),
    });
  }

  @override
  Future<Reliability> probeReliability() async {
    final result = await _channel.invokeMethod<String>('probeReliability');
    switch (result) {
      case 'optimal':
        return Reliability.optimal;
      case 'degraded':
        return Reliability.degraded;
      default:
        return Reliability.unknown;
    }
  }
}

/// Test bridge — records every call.
class FakeReminderBridge implements ReminderBridge {
  final List<DateTime> anchors = <DateTime>[];
  int rescheduleCount = 0;
  Reliability reliability = Reliability.optimal;

  @override
  Future<void> rescheduleAll() async {
    rescheduleCount++;
  }

  @override
  Future<void> recordAnchor(DateTime at) async {
    anchors.add(at);
  }

  @override
  Future<Reliability> probeReliability() async => reliability;
}
