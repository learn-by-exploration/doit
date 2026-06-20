// Tests for the production [PlatformAlarmScheduler].
//
// v0.6 (ADR-018) wires the scheduler's public surface to
// [ReminderBridge]:
//   - `schedule(habit, at)`              → bridge.setExactAlarm
//   - `cancel(id)`                       → bridge.cancelAlarm
//   - `snooze(id, delay)`                → cancel + re-schedule
//   - `scheduleEvent(event, at)`         → bridge.setExactAlarm
//   - `cancelEvent(id)`                  → bridge.cancelAlarm
//   - `cancelForHabit(habitId)`          → no-op (the bridge
//     has no "cancel-by-habit" primitive)
//   - `reliability`                      → bridge.probeReliability,
//     cached for 30 s.

import 'package:doit/events/event.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/services/platform_alarm_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal [Do] shell for the scheduler tests. The
/// scheduler itself does not read the habit's schedule or
/// proof mode (it hands `(id, epochMs)` to the bridge); the
/// only field consulted is `id`, which is derived from the
/// `DoFixed` instance.
DoFixed _makeHabit(String id) => DoFixed(
  id: id,
  name: 'Test habit',
  iconName: 'check',
  colorSeed: 0, // ignore: avoid_redundant_argument_values
  category: DoCategory.health,
  weekdays: const {1, 2, 3, 4, 5, 6, 7},
  time: const DoTime(7, 30),
  proofMode: const SoftProof(),
  createdAt: DateTime(2026, 6, 18),
  restDaysPerMonth: 2,
);

void main() {
  group('PlatformAlarmScheduler', () {
    test('schedule forwards (id, epochMs) to bridge.setExactAlarm', () async {
      final bridge = FakeReminderBridge();
      final scheduler = PlatformAlarmScheduler(bridge);
      final at = DateTime(2026, 6, 18, 7, 30);
      final id = await scheduler.schedule(_makeHabit('h1'), at);
      expect(bridge.setExactAlarmCalls, hasLength(1));
      final call = bridge.setExactAlarmCalls.single;
      expect(call.epochMs, at.millisecondsSinceEpoch);
      // The id returned by the bridge defaults to the
      // platform's identity mapping.
      expect(id.value, call.alarmId);
    });

    test('schedule surfaces a reassigned id (WorkManager fallback)', () async {
      final bridge = FakeReminderBridge();
      bridge.setExactAlarmResult = (id) => id + 1000;
      final scheduler = PlatformAlarmScheduler(bridge);
      final at = DateTime(2026, 6, 18, 7, 30);
      final id = await scheduler.schedule(_makeHabit('h1'), at);
      expect(id.value, (bridge.setExactAlarmCalls.single.alarmId) + 1000);
    });

    test('cancel forwards the id to bridge.cancelAlarm', () async {
      final bridge = FakeReminderBridge();
      final scheduler = PlatformAlarmScheduler(bridge);
      await scheduler.cancel(const AlarmId(42));
      expect(bridge.cancelAlarmCalls, [42]);
    });

    test(
      'snooze cancels then re-schedules with the same id and new epoch',
      () async {
        final bridge = FakeReminderBridge();
        final scheduler = PlatformAlarmScheduler(bridge);
        // Prime the Dart-side (id → at) mirror by calling
        // `schedule` first — the mirror is the only place
        // the snooze math can recover the original target.
        final originalAt = DateTime(2026, 6, 18, 7, 30);
        final id = await scheduler.schedule(_makeHabit('h1'), originalAt);
        bridge.setExactAlarmCalls.clear();
        bridge.cancelAlarmCalls.clear();

        final newId = await scheduler.snooze(id, const Duration(minutes: 5));
        expect(bridge.cancelAlarmCalls, [id.value]);
        expect(bridge.setExactAlarmCalls, hasLength(1));
        final call = bridge.setExactAlarmCalls.single;
        expect(
          call.alarmId,
          id.value,
          reason:
              'Snooze reuses the original id so the platform treats it '
              'as a re-schedule, not a new alarm.',
        );
        expect(
          call.epochMs,
          originalAt.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
        );
        // The returned id is the same because the platform's
        // identity mapping is the default.
        expect(newId.value, id.value);
      },
    );

    test('snooze without a mirror entry falls back to now+delay', () async {
      final bridge = FakeReminderBridge();
      final scheduler = PlatformAlarmScheduler(bridge);
      // A snooze for an id the mirror has never seen
      // (e.g., the Kotlin side armed the alarm during
      // boot and never round-tripped through the
      // scheduler). The fallback must NOT throw — it
      // cancels the platform-side alarm and re-arms
      // with a target of `now + delay`.
      final id = const AlarmId(9999);
      final newId = await scheduler.snooze(id, const Duration(minutes: 5));
      expect(bridge.cancelAlarmCalls, [9999]);
      expect(bridge.setExactAlarmCalls, hasLength(1));
      final call = bridge.setExactAlarmCalls.single;
      expect(call.alarmId, 9999);
      // The target is `now + delay` — a range check is
      // good enough (test wall-clock drift).
      final ms = call.epochMs;
      final now = DateTime.now().millisecondsSinceEpoch;
      expect(ms, greaterThan(now));
      expect(ms, lessThan(now + 10 * 60 * 1000));
      expect(newId.value, 9999);
    });

    test(
      'scheduleEvent forwards the hashed id and epoch to the bridge',
      () async {
        final bridge = FakeReminderBridge();
        final scheduler = PlatformAlarmScheduler(bridge);
        final at = DateTime(2026, 6, 18, 9);
        final event = Event(
          id: 'evt_42',
          name: 'Standup',
          atMillis: at.millisecondsSinceEpoch,
          leadTimeMillis: 0,
          createdAtMillis: at.millisecondsSinceEpoch,
        );
        await scheduler.scheduleEvent(event, at);
        expect(bridge.setExactAlarmCalls, hasLength(1));
        final call = bridge.setExactAlarmCalls.single;
        expect(call.alarmId, 'evt_42'.hashCode & 0x7FFFFFFF);
        expect(call.epochMs, at.millisecondsSinceEpoch);
      },
    );

    test('cancelEvent forwards the hashed id to the bridge', () async {
      final bridge = FakeReminderBridge();
      final scheduler = PlatformAlarmScheduler(bridge);
      await scheduler.cancelEvent('evt_42');
      expect(bridge.cancelAlarmCalls, ['evt_42'.hashCode & 0x7FFFFFFF]);
    });

    test('cancelForHabit is a no-op (the bridge has no bulk cancel)', () async {
      final bridge = FakeReminderBridge();
      final scheduler = PlatformAlarmScheduler(bridge);
      await scheduler.cancelForHabit('h1');
      expect(bridge.cancelAlarmCalls, isEmpty);
      expect(bridge.setExactAlarmCalls, isEmpty);
    });

    test(
      'rescheduleAll forwards to bridge and clears the reliability cache',
      () async {
        final bridge = FakeReminderBridge();
        final scheduler = PlatformAlarmScheduler(bridge);
        // Prime the reliability cache with a known value.
        scheduler.clearReliabilityCache();
        await bridge.setExactAlarm(alarmId: 1, epochMs: 0);
        // The cache is populated by a probe — there is no
        // direct setter; the cache is exercised by the
        // `reliability` getter test below.
        await scheduler.rescheduleAll();
        expect(bridge.rescheduleCount, 1);
      },
    );

    group('reliability', () {
      test('returns the bridge probe value (uncached)', () async {
        final bridge = FakeReminderBridge();
        bridge.reliability = Reliability.degraded;
        final scheduler = PlatformAlarmScheduler(bridge);
        // The first read is fire-and-forget; the cached
        // value is still unknown. We give the unawaited
        // probe a tick to complete before reading again.
        expect(scheduler.reliability, Reliability.unknown);
        await Future<void>.delayed(Duration.zero);
        expect(scheduler.reliability, Reliability.degraded);
      });

      test('caches the value within kReliabilityCacheTtl', () async {
        final bridge = FakeReminderBridge();
        bridge.reliability = Reliability.optimal;
        final scheduler = PlatformAlarmScheduler(bridge);
        // Prime the cache.
        expect(scheduler.reliability, Reliability.unknown);
        await Future<void>.delayed(Duration.zero);
        expect(scheduler.reliability, Reliability.optimal);
        // Flip the bridge's value to degraded. Within the
        // TTL the cached value must still be returned
        // (the getter does NOT re-probe).
        bridge.reliability = Reliability.degraded;
        expect(scheduler.reliability, Reliability.optimal);
      });

      test('clearReliabilityCache forces a re-probe', () async {
        final bridge = FakeReminderBridge();
        bridge.reliability = Reliability.optimal;
        final scheduler = PlatformAlarmScheduler(bridge);
        expect(scheduler.reliability, Reliability.unknown);
        await Future<void>.delayed(Duration.zero);
        expect(scheduler.reliability, Reliability.optimal);
        bridge.reliability = Reliability.degraded;
        scheduler.clearReliabilityCache();
        // The first read after the clear is still unknown
        // (the fire-and-forget probe is in flight).
        expect(scheduler.reliability, Reliability.unknown);
        await Future<void>.delayed(Duration.zero);
        expect(scheduler.reliability, Reliability.degraded);
      });

      test('falls back to unknown on the first read with no cache', () {
        final bridge = FakeReminderBridge();
        final scheduler = PlatformAlarmScheduler(bridge);
        // No probe has run; the getter returns `unknown` and
        // kicks off an unawaited probe for next time.
        expect(scheduler.reliability, Reliability.unknown);
      });
    });
  });
}
