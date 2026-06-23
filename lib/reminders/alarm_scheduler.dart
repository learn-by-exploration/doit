// Reminder scheduling — the only layer that talks to
// `AlarmManager` and `WorkManager` on Android.
//
// Per .claude/rules/lib-reminders.md, this file is the public
// surface for scheduling. The rest of the app calls
// `AlarmScheduler.schedule(Do h, DateTime at)` and the
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

import 'package:doit/events/event.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
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
  Future<AlarmId> schedule(Do habit, DateTime at);

  /// Cancel the alarm with the given id.
  Future<void> cancel(AlarmId id);

  /// Snooze the alarm by [delay].
  Future<AlarmId> snooze(AlarmId id, Duration delay);

  /// Re-schedule every pending habit. Called by the Kotlin
  /// `BootReceiver` (via a method channel) and on
  /// `ACTION_TIMEZONE_CHANGED`.
  Future<void> rescheduleAll();

  /// Schedule a one-shot event reminder. The alarm id is derived
  /// from the event id. Fires once at `at` and is unscheduled.
  Future<AlarmId> scheduleEvent(Event event, DateTime at);

  /// Cancel a one-shot event reminder.
  Future<void> cancelEvent(String eventId);

  /// Cancel every alarm tied to a given habit id (any
  /// occurrence). Used by the "Cancel test reminder" button.
  Future<void> cancelForHabit(String habitId);

  /// Look up the scheduled entry for [id]. The
  /// `fireAlarm` inbound handler (Kotlin AlarmReceiver →
  /// Dart `ReminderService.onFireAlarm`) uses this to
  /// build a `ReminderEvent` without a DB round-trip.
  /// Returns `null` if the id is not in the mirror
  /// (e.g., the alarm was armed by the Kotlin side and
  /// the Dart mirror was cleared by `rescheduleAll`).
  /// v1.2e / Phase 5.
  Future<ScheduledAlarm?> lookupForFire(AlarmId id);

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
    this.habitName,
    this.strongMode = false,
    this.eventId,
  });
  final AlarmId id;

  /// The owning habit id, or `'event:<eventId>'` for
  /// event-scheduled alarms (mirrors the v0.2
  /// `FakeAlarmScheduler.scheduleEvent` convention).
  final String habitId;

  /// Optional human-readable name. Populated by the
  /// production [PlatformAlarmScheduler] so the
  /// `fireAlarm` inbound handler can render a notification
  /// without a round-trip to the DB.
  final String? habitName;

  /// v1.2e / Phase 5: the strong-mode bit from the owning
  /// habit. Drives the `Open` vs `Done` action on the
  /// fired notification.
  final bool strongMode;

  /// The originating event id when this alarm belongs to
  /// an event (not a habit). `null` for habits.
  final String? eventId;
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
  Future<AlarmId> schedule(Do habit, DateTime at) async {
    final id = AlarmId(_nextId++);
    _scheduled.add(
      ScheduledAlarm(
        id: id,
        habitId: habit.id,
        at: at,
        habitName: habit.name,
        strongMode: habit.proofMode is StrongProof,
      ),
    );
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
      ScheduledAlarm(
        id: newId,
        habitId: original.habitId,
        at: newAt,
        habitName: original.habitName,
        strongMode: original.strongMode,
        eventId: original.eventId,
      ),
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
  Future<AlarmId> scheduleEvent(Event event, DateTime at) async {
    final id = AlarmId(_nextId++);
    _scheduled.add(
      ScheduledAlarm(
        id: id,
        habitId: 'event:${event.id}',
        at: at,
        habitName: event.name,
        eventId: event.id,
      ),
    );
    return id;
  }

  @override
  Future<void> cancelEvent(String eventId) async {
    _scheduled.removeWhere((a) => a.habitId == 'event:$eventId');
  }

  @override
  Future<ScheduledAlarm?> lookupForFire(AlarmId id) async {
    for (final entry in _scheduled) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  Future<void> cancelForHabit(String habitId) async {
    _scheduled.removeWhere((a) => a.habitId == habitId);
    for (final id
        in _scheduled
            .where((a) => a.habitId == habitId)
            .map((a) => a.id)
            .toList()) {
      _cancelled.add(id);
    }
  }

  @override
  Reliability get reliability => _reliability;

  /// Test helper: simulate exact-alarm denial.
  // ignore: use_setters_to_change_properties
  void setReliability(Reliability value) {
    _reliability = value;
  }
}
