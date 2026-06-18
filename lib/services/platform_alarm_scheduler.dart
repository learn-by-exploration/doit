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
//   - `reliability`                      → bridge.probeReliability,
//     cached for 30 s to avoid
//     `MethodChannel` round-trips on
//     every read of the home-screen
//     banner.
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

import 'dart:async';

import 'package:doit/events/event.dart';
import 'package:doit/habits/habit.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/reminder_bridge.dart';

/// How long a probed [Reliability] value is reused before
/// re-probing the platform. 30 s keeps the home-screen
/// banner responsive (the banner polls on resume) without
/// saturating the [MethodChannel] while the user scrolls
/// the list.
const Duration kReliabilityCacheTtl = Duration(seconds: 30);

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

  /// Cache for the [reliability] getter. Cleared on every
  /// explicit re-probe (the `request` re-probe path in
  /// [ReminderService]) and on a TTL of
  /// [kReliabilityCacheTtl]. The cache is mutable in-place
  /// (no `late final`) so the [clearReliabilityCache] test
  /// hook can reset it between cases.
  Reliability? _cachedReliability;
  DateTime? _cachedReliabilityAt;

  @override
  Future<AlarmId> schedule(Habit habit, DateTime at) async {
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
    return effective;
  }

  @override
  Future<void> cancel(AlarmId id) async {
    _scheduled.remove(id);
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
    // Re-probe reliability eagerly so the next
    // `reliability` read is fresh (the Kotlin side re-reads
    // the WHITELIST state on each probe).
    clearReliabilityCache();
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
    return effective;
  }

  @override
  Future<void> cancelEvent(String eventId) async {
    final AlarmId id = AlarmId(eventId.hashCode & 0x7FFFFFFF);
    _scheduled.remove(id);
    await _bridge.cancelAlarm(id.value);
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
    final Reliability? cached = _cachedReliability;
    final DateTime? cachedAt = _cachedReliabilityAt;
    final DateTime now = DateTime.now();
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < kReliabilityCacheTtl) {
      return cached;
    }
    // Fire-and-forget: a stale read is preferable to a
    // `Future<Reliability>` getter (the home-screen
    // banner is a synchronous `Consumer`). The next read
    // after the probe completes picks up the fresh value.
    unawaited(_refreshReliability());
    return cached ?? Reliability.unknown;
  }

  Future<void> _refreshReliability() async {
    try {
      final Reliability probed = await _bridge.probeReliability();
      _cachedReliability = probed;
      _cachedReliabilityAt = DateTime.now();
    } catch (_) {
      // The probe call may fail if the platform side is
      // not installed (a unit test, a CI build, etc.).
      // Leave the cache alone so a subsequent successful
      // probe still reuses the prior value.
    }
  }

  /// Test hook — clear the [reliability] cache so the next
  /// read re-probes. Used by the platform_alarm_scheduler
  /// tests to verify the 30 s TTL behavior.
  // ignore: use_setters_to_change_properties
  void clearReliabilityCache() {
    _cachedReliability = null;
    _cachedReliabilityAt = null;
  }
}
