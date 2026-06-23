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

  /// Arm an exact alarm at [epochMs] (Unix milliseconds).
  /// The platform calls `AlarmManager.setExactAndAllowWhileIdle`
  /// (or `setExact` outside Doze) and returns the assigned
  /// alarm id. On `Reliability.degraded` the platform falls
  /// back to `WorkManager` and returns a non-zero id whose
  /// exact value is platform-defined. v0.6 / ADR-018 / SYS-065.
  Future<int> setExactAlarm({required int alarmId, required int epochMs});

  /// Cancel the alarm with [alarmId] (no-op if not armed).
  /// v0.6 / ADR-018.
  Future<void> cancelAlarm(int alarmId);

  /// Launch the full-screen mission activity for [habitId].
  /// The platform opens `FullScreenActivity` (a thin Kotlin
  /// shell that hosts a Flutter route). Out-of-scope for
  /// v0.6; the Dart side calls this for strong-mode habits.
  Future<void> showFullScreen(String habitId);

  /// Show (or update) the notification for [alarmId]. The
  /// platform side builds the `NotificationCompat.Builder`
  /// with [habitName] as the title, [body] as the body (or
  /// a default `Time for <habitName>` when null), and the
  /// `doit.reminders` channel. Strong-mode reminders add
  /// the `Open` action; soft-mode add the `Done` action.
  /// v1.2e / Phase 5.
  Future<void> showNotification({
    required int alarmId,
    required String habitName,
    String? body,
    bool strongMode = false,
  });

  /// Cancel the active notification for [alarmId]. No-op if
  /// no notification is currently showing for this id. The
  /// cancel matches the alarmId, not the most-recent
  /// notification (so canceling alarmId=7 does not also
  /// cancel alarmId=8 if both are visible). v1.2e / Phase 5.
  Future<void> cancelNotification(int alarmId);

  /// Open the system battery-optimization whitelist page
  /// (`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`). The
  /// platform starts the activity synchronously; the result
  /// of the user's choice is re-probed via
  /// [PermissionService.requestIgnoreBatteryOptimizations]
  /// (SYS-068).
  Future<void> openIgnoreBatteryOptimizations();

  /// Schedule a heads-up notification that fires
  /// [leadTimeSeconds] before the matching [alarmId] fires.
  /// The platform enqueues a one-shot `WorkManager` task
  /// (NOT an `AlarmManager` alarm — these are advisory and
  /// exact-on-the-second is not required). When the heads-
  /// up fires, the platform posts a low-importance
  /// notification on the same `doit.reminders` channel
  /// with the habit name + a "coming up in N minutes" body
  /// and a single "Dismiss" action. The actual [alarmId]
  /// alarm fires later as usual; the heads-up is purely
  /// advisory.
  ///
  /// The Dart side enqueues the 5-minute heads-up and the
  /// 1-minute heads-up as two separate `schedulePreAlarm`
  /// calls; the Kotlin side deduplicates by
  /// `(alarmId, leadTimeSeconds)` so a second
  /// `schedulePreAlarm(alarmId, 300)` overwrites the first.
  /// Canceling [alarmId] via [cancelAlarm] also cancels
  /// any pending heads-ups for that alarm.
  ///
  /// v1.2j / Phase 10 / SYS-107.
  Future<void> schedulePreAlarm({
    required int alarmId,
    required int leadTimeSeconds,
  });

  /// Cancel every pending heads-up for [alarmId]. The
  /// platform iterates over the persisted `(alarmId,
  /// leadTimeSeconds)` pairs and cancels each. Called when
  /// the user dismisses the underlying alarm via
  /// `cancelAlarm` or when the habit is completed.
  Future<void> cancelPreAlarms(int alarmId);
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

  @override
  Future<int> setExactAlarm({
    required int alarmId,
    required int epochMs,
  }) async {
    final result = await _channel.invokeMethod<int>('setExactAlarm', {
      'alarmId': alarmId,
      'epochMs': epochMs,
    });
    return result ?? alarmId;
  }

  @override
  Future<void> cancelAlarm(int alarmId) async {
    await _channel.invokeMethod<void>('cancelAlarm', {'alarmId': alarmId});
  }

  @override
  Future<void> showFullScreen(String habitId) async {
    await _channel.invokeMethod<void>('showFullScreen', {'habitId': habitId});
  }

  @override
  Future<void> showNotification({
    required int alarmId,
    required String habitName,
    String? body,
    bool strongMode = false,
  }) async {
    await _channel.invokeMethod<void>('showNotification', {
      'alarmId': alarmId,
      'habitName': habitName,
      'body': body,
      'strongMode': strongMode,
    });
  }

  @override
  Future<void> cancelNotification(int alarmId) async {
    await _channel.invokeMethod<void>('cancelNotification', {
      'alarmId': alarmId,
    });
  }

  @override
  Future<void> openIgnoreBatteryOptimizations() async {
    await _channel.invokeMethod<void>('openIgnoreBatteryOptimizations');
  }

  @override
  Future<void> schedulePreAlarm({
    required int alarmId,
    required int leadTimeSeconds,
  }) async {
    await _channel.invokeMethod<void>('schedulePreAlarm', {
      'alarmId': alarmId,
      'leadTimeSeconds': leadTimeSeconds,
    });
  }

  @override
  Future<void> cancelPreAlarms(int alarmId) async {
    await _channel.invokeMethod<void>('cancelPreAlarms', {'alarmId': alarmId});
  }
}

/// Test bridge — records every call.
class FakeReminderBridge implements ReminderBridge {
  final List<DateTime> anchors = <DateTime>[];
  final List<({int alarmId, int epochMs})> setExactAlarmCalls =
      <({int alarmId, int epochMs})>[];
  final List<int> cancelAlarmCalls = <int>[];
  final List<String> showFullScreenCalls = <String>[];
  final List<({int alarmId, String habitName, String? body, bool strongMode})>
  showNotificationCalls =
      <({int alarmId, String habitName, String? body, bool strongMode})>[];
  final List<int> cancelNotificationCalls = <int>[];

  final List<({int alarmId, int leadTimeSeconds})> schedulePreAlarmCalls =
      <({int alarmId, int leadTimeSeconds})>[];
  final List<int> cancelPreAlarmsCalls = <int>[];
  int openIgnoreBatteryOptimizationsCalls = 0;
  int rescheduleCount = 0;
  Reliability reliability = Reliability.optimal;

  /// What the next [setExactAlarm] call returns. Defaults
  /// to the `alarmId` passed in (mirrors the platform's
  /// identity-mapping behavior). Tests override this to
  /// simulate a platform-assigned id or a degraded fallback.
  int Function(int alarmId)? setExactAlarmResult;

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

  @override
  Future<int> setExactAlarm({
    required int alarmId,
    required int epochMs,
  }) async {
    setExactAlarmCalls.add((alarmId: alarmId, epochMs: epochMs));
    return setExactAlarmResult?.call(alarmId) ?? alarmId;
  }

  @override
  Future<void> cancelAlarm(int alarmId) async {
    cancelAlarmCalls.add(alarmId);
  }

  @override
  Future<void> showFullScreen(String habitId) async {
    showFullScreenCalls.add(habitId);
  }

  @override
  Future<void> showNotification({
    required int alarmId,
    required String habitName,
    String? body,
    bool strongMode = false,
  }) async {
    showNotificationCalls.add((
      alarmId: alarmId,
      habitName: habitName,
      body: body,
      strongMode: strongMode,
    ));
  }

  @override
  Future<void> cancelNotification(int alarmId) async {
    cancelNotificationCalls.add(alarmId);
  }

  @override
  Future<void> openIgnoreBatteryOptimizations() async {
    openIgnoreBatteryOptimizationsCalls++;
  }

  @override
  Future<void> schedulePreAlarm({
    required int alarmId,
    required int leadTimeSeconds,
  }) async {
    schedulePreAlarmCalls.add((
      alarmId: alarmId,
      leadTimeSeconds: leadTimeSeconds,
    ));
  }

  @override
  Future<void> cancelPreAlarms(int alarmId) async {
    cancelPreAlarmsCalls.add(alarmId);
  }
}
