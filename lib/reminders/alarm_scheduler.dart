// Reminder scheduling — the only layer that talks to
// `AlarmManager` and `WorkManager` on Android.
//
// Per .claude/rules/lib-reminders.md, this file is the public
// surface for scheduling. The rest of the app calls
// `AlarmScheduler.schedule(Habit h, DateTime at)` and the
// scheduler routes the call to the right platform primitive.
//
// Layer rules:
// - The scheduler is a singleton service (see lib-services.md).
// - All public methods `await _ready.future` before doing work.
// - No `DateTime.now()` inside the scheduler; the caller passes
//   the target time. The scheduler computes the alarm id from
//   the habit and the target.
// - The scheduler exposes a `Reliability` enum that the home
//   screen and settings page read to show the "may be late"
//   badge.

import 'dart:async';

import 'package:common_games/habits/habit.dart';
import 'package:meta/meta.dart';

/// A stable identifier for a scheduled alarm. The alarm id is
/// derived from `(habit.id, scheduledAt)` so re-scheduling the
/// same occurrence replaces (not duplicates) the alarm.
@immutable
class AlarmId {
  const AlarmId(this.value);
  final int value;

  /// `AlarmId` for the (habit, scheduledAt) pair. The id is
  /// stable across re-schedules of the same occurrence.
  factory AlarmId.forOccurrence(String habitId, DateTime scheduledAt) {
    // Combine the habit id's hash with the epoch ms of the
    // scheduled time. The 31-bit mask keeps the value positive
    // (Android `setExact` rejects negative ids).
    final ms = scheduledAt.millisecondsSinceEpoch & 0x7FFFFFFF;
    return AlarmId((habitId.hashCode * 31 + ms) & 0x7FFFFFFF);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AlarmId && other.value == value);

  @override
  int get hashCode => value;
}

/// Reliability state of the alarm system. Read by the home
/// screen and the settings page to render the right banner.
enum Reliability {
  /// Exact alarm is granted and the device is not in Doze.
  optimal,

  /// Exact alarm is denied or Doze is suspected. Reminders may
  /// fire up to 15 min late. UI shows a "may be late" badge.
  degraded,

  /// First launch — no probe has run yet.
  unknown,
}

/// Public surface for alarm scheduling. The default
/// implementation ([PlatformAlarmScheduler]) wraps the
/// `android_alarm_manager_plus` and `workmanager` packages. The
/// [FakeAlarmScheduler] is used in tests and in previews.
abstract class AlarmScheduler {
  /// Schedule `habit` for `at`. The alarm id is derived from
  /// (habitId, at). Re-scheduling replaces the prior alarm.
  Future<AlarmId> schedule(Habit habit, DateTime at);

  /// Cancel the alarm with the given id.
  Future<void> cancel(AlarmId id);

  /// Snooze the alarm by [delay].
  Future<AlarmId> snooze(AlarmId id, Duration delay);

  /// Re-schedule every pending habit. Called by the Kotlin
  /// `BootReceiver` (via a method channel) and on
  /// `ACTION_TIMEZONE_CHANGED`.
  Future<void> rescheduleAll();

  /// Current reliability state.
  Reliability get reliability;
}

/// A scheduled alarm entry. Used by [FakeAlarmScheduler] and
/// exposed read-only for widget tests.
@immutable
class ScheduledAlarm {
  const ScheduledAlarm({
    required this.id,
    required this.habitId,
    required this.at,
  });
  final AlarmId id;
  final String habitId;
  final DateTime at;
}

/// In-memory implementation used by tests and by previews. It
/// records what was scheduled and exposes the list so tests can
/// assert on it.
class FakeAlarmScheduler implements AlarmScheduler {
  final List<ScheduledAlarm> _scheduled = <ScheduledAlarm>[];
  final Set<AlarmId> _cancelled = <AlarmId>{};
  final Map<AlarmId, AlarmId> _snoozed = <AlarmId, AlarmId>{};
  Reliability _reliability = Reliability.optimal;
  int _nextId = 1;

  /// All alarms that are currently scheduled (i.e., not
  /// cancelled). Order is insertion order.
  List<ScheduledAlarm> get scheduled => List.unmodifiable(_scheduled);

  /// All alarm ids that were cancelled.
  Set<AlarmId> get cancelledIds => Set.unmodifiable(_cancelled);

  @override
  Future<AlarmId> schedule(Habit habit, DateTime at) async {
    final id = AlarmId(_nextId++);
    _scheduled.add(ScheduledAlarm(id: id, habitId: habit.id, at: at));
    return id;
  }

  @override
  Future<void> cancel(AlarmId id) async {
    _cancelled.add(id);
    _scheduled.removeWhere((a) => a.id == id);
  }

  @override
  Future<AlarmId> snooze(AlarmId id, Duration delay) async {
    final original = _scheduled.firstWhere((a) => a.id == id);
    final newAt = original.at.add(delay);
    final newId = AlarmId(_nextId++);
    _scheduled.add(
      ScheduledAlarm(id: newId, habitId: original.habitId, at: newAt),
    );
    _snoozed[id] = newId;
    _cancelled.add(id);
    _scheduled.removeWhere((a) => a.id == id);
    return newId;
  }

  @override
  Future<void> rescheduleAll() async {
    // No-op in the fake. A real implementation re-queries the
    // local DB and re-arms every pending alarm.
  }

  @override
  Reliability get reliability => _reliability;

  /// Test helper: simulate exact-alarm denial.
  // ignore: use_setters_to_change_properties
  void setReliability(Reliability value) {
    _reliability = value;
  }
}
