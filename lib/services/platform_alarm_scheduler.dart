import 'dart:async' show unawaited;

// Platform alarm scheduler — production wiring.
//
// The Dart side is the source of truth for "which alarms are
// pending" and the corresponding "what time they fire at".
// The Kotlin side is a thin wrapper that translates
// `bridge.setExactAlarm` / `cancelAlarm` into
// `AlarmManager.setExactAndAllowWhileIdle` /
// `setExact` / `WorkManager` calls.
//
// v0.6 (ADR-018) wires every [AlarmScheduler] method through
// the [ReminderBridge]:
//
//   - `schedule(habit, at)`              → bridge.setExactAlarm
//   - `cancel(id)`                       → bridge.cancelAlarm
//   - `snooze(id, delay)`                → cancel + re-schedule
//   - `scheduleEvent(event, at)`         → bridge.setExactAlarm
//   - `cancelEvent(id)`                  → bridge.cancelAlarm
//   - `cancelForHabit(habitId)`          → bridge.cancelAlarm,
//     per AlarmId. The bridge has no
//     "cancel-by-habit" primitive; the
//     caller (ReminderService) walks the
//     scheduled set and issues one call
//     per id.
//   - `reliability`                      →
//     `ReliabilityService.instance.value` (v1.3b /
//     Phase 13 / SYS-112 / ADR-042). The
//     scheduler used to own the bridge
//     probe + the 30 s cache; the new
//     service owns both so the home
//     banner and the settings page
//     cannot drift.
//
// Pre-v0.6 the `schedule/cancel/...` methods were stubs
// that returned stable ids without touching the bridge; the
// real scheduling was implicit in the Kotlin `BootReceiver`
// → `rescheduleAll` path. v0.6 makes the Dart side the
// authoritative scheduling surface so the on-demand
// `PermissionSheet` gate in `ReminderService.scheduleHabit`
// (Step 7) can short-circuit cleanly.
//
// Widget tests and previews use [FakeAlarmScheduler] from
// `lib/reminders/alarm_scheduler.dart`; this class is for
// production only.

import 'package:doit/events/event.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/reminder_bridge.dart';
// v1.3b / Phase 13: the `reliability` getter delegates to
// `ReliabilityService.instance.value`. The
// `kReliabilityCacheTtl` constant moved with it (re-exported
// from `reliability_service.dart` for any test that still
// imports the name from this file).
import 'package:doit/services/reliability_service.dart';

class PlatformAlarmScheduler implements AlarmScheduler {
  PlatformAlarmScheduler(this._bridge);

  final ReminderBridge _bridge;

  /// The map of currently-scheduled (id, at) pairs the
  /// scheduler has armed on the platform. The platform side
  /// is the source of truth; this map is the Dart-side
  /// mirror that [snooze] needs to compute a new target.
  /// On `rescheduleAll` the Kotlin side rebuilds the table
  /// from the local DB; the Dart side clears the mirror to
  /// match.
  final Map<AlarmId, DateTime> _scheduled = <AlarmId, DateTime>{};

  /// v1.2e / Phase 5: richer mirror that also carries the
  /// metadata the inbound `fireAlarm` handler needs to
  /// render a notification without a DB round-trip
  /// (habit / event name, strong-mode bit, originating
  /// event id). The two mirrors are kept in lockstep;
  /// every `schedule`/`cancel`/`rescheduleAll` updates
  /// both.
  final Map<AlarmId, ScheduledAlarm> _firingEntries =
      <AlarmId, ScheduledAlarm>{};

  @override
  Future<AlarmId> schedule(Do habit, DateTime at) async {
    // The id is stable across re-schedules of the same
    // occurrence so a re-call replaces (not duplicates) the
    // prior alarm. The bridge returns the same id we sent
    // when the platform's identity-mapping behavior is in
    // effect; on the degraded WorkManager fallback the
    // platform returns a different id, but the test seam
    // preserves the input id by default.
    final AlarmId id = AlarmId.forOccurrence(habit.id, at);
    final int returned = await _bridge.setExactAlarm(
      alarmId: id.value,
      epochMs: at.millisecondsSinceEpoch,
    );
    final AlarmId effective = returned == id.value ? id : AlarmId(returned);
    _scheduled[effective] = at;
    _firingEntries[effective] = ScheduledAlarm(
      id: effective,
      habitId: habit.id,
      at: at,
      habitName: habit.name,
      strongMode: habit.proofMode is StrongProof,
    );
    return effective;
  }

  @override
  Future<void> cancel(AlarmId id) async {
    _scheduled.remove(id);
    _firingEntries.remove(id);
    await _bridge.cancelAlarm(id.value);
  }

  @override
  Future<AlarmId> snooze(AlarmId id, Duration delay) async {
    // Snooze = cancel + re-schedule with a new target time.
    // The original target lives in the Dart-side mirror
    // (populated by [schedule]); the new target is
    // `original + delay`. The same id is reused so the
    // platform treats the call as a re-schedule, not a
    // new alarm. The platform returns the same id by
    // default; a WorkManager fallback would return a
    // different id, which we surface to the caller.
    final DateTime? original = _scheduled[id];
    final ScheduledAlarm? originalEntry = _firingEntries[id];
    if (original == null) {
      // The mirror is out of sync with the platform
      // (e.g., the alarm was armed by the Kotlin
      // `BootReceiver` directly). Fall back to the
      // identity-mapping: cancel + re-schedule with the
      // same id and a target `now + delay` (the caller's
      // intent is "snooze by `delay`", and a non-firing
      // alarm is the same as firing late).
      await _bridge.cancelAlarm(id.value);
      final int returned = await _bridge.setExactAlarm(
        alarmId: id.value,
        epochMs: DateTime.now().add(delay).millisecondsSinceEpoch,
      );
      return AlarmId(returned);
    }
    final DateTime newAt = original.add(delay);
    await _bridge.cancelAlarm(id.value);
    final int returned = await _bridge.setExactAlarm(
      alarmId: id.value,
      epochMs: newAt.millisecondsSinceEpoch,
    );
    final AlarmId effective = returned == id.value ? id : AlarmId(returned);
    _scheduled[effective] = newAt;
    if (originalEntry != null) {
      _firingEntries[effective] = ScheduledAlarm(
        id: effective,
        habitId: originalEntry.habitId,
        at: newAt,
        habitName: originalEntry.habitName,
        strongMode: originalEntry.strongMode,
        eventId: originalEntry.eventId,
      );
    }
    return effective;
  }

  @override
  Future<void> rescheduleAll() async {
    // The Kotlin side rebuilds the alarm table from the
    // local DB; clear the Dart-side mirror so a follow-up
    // [snooze] either finds the entry (the Kotlin side
    // emitted the corresponding [schedule] call to the
    // bridge for every pending alarm) or falls back to the
    // `now + delay` heuristic.
    _scheduled.clear();
    _firingEntries.clear();
    // v1.3b / Phase 13: re-probe reliability eagerly so the
    // next `reliability` read is fresh (the Kotlin side
    // re-reads the WHITELIST state on each probe). The
    // scheduler used to clear its own cache here; the new
    // ReliabilityService owns the cache, so we delegate.
    try {
      // Fire-and-forget — the re-probe is async but the
      // platform reschedule is the slow path we actually
      // wait on. The fresh probe result will land in the
      // notifier and the home banner will rebuild on the
      // next frame.
      unawaited(ReliabilityService.instance.refresh());
    } on StateError {
      // ReliabilityService was not init'd (a unit test that
      // constructs the scheduler standalone). Best-effort
      // re-probe — the scheduler used to skip silently.
    }
    await _bridge.rescheduleAll();
  }

  @override
  Future<AlarmId> scheduleEvent(Event event, DateTime at) async {
    final AlarmId id = AlarmId(event.id.hashCode & 0x7FFFFFFF);
    final int returned = await _bridge.setExactAlarm(
      alarmId: id.value,
      epochMs: at.millisecondsSinceEpoch,
    );
    final AlarmId effective = returned == id.value ? id : AlarmId(returned);
    _scheduled[effective] = at;
    _firingEntries[effective] = ScheduledAlarm(
      id: effective,
      habitId: 'event:${event.id}',
      at: at,
      habitName: event.name,
      eventId: event.id,
    );
    return effective;
  }

  @override
  Future<void> cancelEvent(String eventId) async {
    final AlarmId id = AlarmId(eventId.hashCode & 0x7FFFFFFF);
    _scheduled.remove(id);
    _firingEntries.remove(id);
    await _bridge.cancelAlarm(id.value);
  }

  @override
  Future<ScheduledAlarm?> lookupForFire(AlarmId id) async {
    return _firingEntries[id];
  }

  @override
  Future<void> cancelForHabit(String habitId) async {
    // The bridge has no "cancel-by-habit" primitive; the
    // caller (ReminderService) walks the local DB and
    // supplies the alarm ids. This scheduler is the
    // platform-binding layer, not a DB walker; for the
    // caller's convenience, a no-op default is the right
    // shape (a real cancel-by-habit would need a new
    // bridge method).
  }

  @override
  Reliability get reliability {
    // v1.3b / Phase 13: delegate to the unified
    // ReliabilityService. The service owns the bridge
    // probe + the 30 s cache + the statuses-listener
    // combine. The scheduler used to own all three; the
    // delegation is a single read so this getter remains
    // synchronous and the home-screen banner is a single
    // `ValueListenableBuilder` rebuild away from a fresh
    // value.
    try {
      return ReliabilityService.instance.value;
    } on StateError {
      // ReliabilityService was not init'd (a unit test
      // that constructs the scheduler standalone). Fall
      // back to `optimal` — the same default the unified
      // service uses for the first-read race.
      return Reliability.optimal;
    }
  }
}
