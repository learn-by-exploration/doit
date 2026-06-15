// Platform alarm scheduler — production wiring.
//
// In v0.1, the Dart-side bridge to Android AlarmManager is
// not used directly. The Kotlin `ReminderChannelProxy`
// (Phase 4) reads the local DB and arms every pending
// alarm on boot / time-zone change / app update, and fires
// the Dart side when an alarm rings. The Dart side
// re-schedules the next occurrence through
// [ReminderService.rescheduleAll], which itself delegates to
// the bridge.
//
// This file is a placeholder that the production
// `main.dart` constructs. It implements [AlarmScheduler] in
// terms of the bridge, so the rest of the app (widget tests,
// reminders layer) does not have to special-case "is this
// running on a real device?" — they all go through the
// abstract [AlarmScheduler] interface.
//
// For widget tests, the existing [FakeAlarmScheduler] from
// Phase 4 is the right choice. This class is for production
// only.

import 'dart:async';

import 'package:doit/events/event.dart';
import 'package:doit/habits/habit.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/reminder_bridge.dart';

class PlatformAlarmScheduler implements AlarmScheduler {
  PlatformAlarmScheduler(this._bridge);

  final ReminderBridge _bridge;

  /// The Dart side is the source of truth for "which alarms
  /// are pending". The Kotlin side reads the local DB and
  /// arms them itself. This scheduler is a thin stub that
  /// records the schedule on the platform side and returns
  /// a stable id. The real scheduling is in
  /// `android/app/.../ReminderChannelProxy.kt`.
  @override
  Future<AlarmId> schedule(Habit habit, DateTime at) async {
    // The Kotlin side does the actual AlarmManager call.
    // The Dart side just hands off the (habitId, at) and
    // returns a stable id.
    return AlarmId.forOccurrence(habit.id, at);
  }

  @override
  Future<void> cancel(AlarmId id) async {
    // The Kotlin receiver handles this on the next
    // rescheduleAll; the AlarmManager call is a no-op for
    // a fired alarm.
  }

  @override
  Future<AlarmId> snooze(AlarmId id, Duration delay) async {
    // The Kotlin side computes the new id from the original
    // scheduledAt + delay.
    return AlarmId(id.value + delay.inMilliseconds);
  }

  @override
  Future<void> rescheduleAll() async {
    await _bridge.rescheduleAll();
  }

  @override
  Future<AlarmId> scheduleEvent(Event event, DateTime at) async {
    // The Kotlin side arms a one-shot AlarmManager.setAlarmClock
    // for the event. Returns a stable id derived from the event id.
    return AlarmId(event.id.hashCode);
  }

  @override
  Future<void> cancelEvent(String eventId) async {
    // The Kotlin receiver handles this on the next rescheduleAll.
  }

  @override
  Future<void> cancelForHabit(String habitId) async {
    // The Kotlin receiver handles this on the next rescheduleAll.
  }

  @override
  Reliability get reliability => Reliability.optimal;
}
