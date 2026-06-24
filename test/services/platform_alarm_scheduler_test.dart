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
//   - `reliability`                      →
//     `ReliabilityService.instance.value`
//     (v1.3b / Phase 13 / SYS-112 /
//     ADR-042). The bridge probe + the
//     30 s cache used to live here; the
//     new service owns both.

import 'package:doit/events/event.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/missions/chain.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/platform_alarm_scheduler.dart';
import 'package:doit/services/reliability_service.dart';
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

/// A trivial Strong chain (one TypeMission). Used by the
/// `lookupForFire` tests to confirm strong-mode bits are
/// captured. The chain does not need to be valid (no
/// `validate()` is called); the scheduler only inspects
/// `proofMode is StrongProof`.
MissionChain _trivialChain() => MissionChain(const [
  TypeMission(
    id: 'm1',
    label: 'Type OK',
    timeout: Duration(seconds: 5),
    expectedPhrase: 'OK',
  ),
]);

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
      const id = AlarmId(9999);
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
      'rescheduleAll forwards to bridge and refreshes the reliability service',
      () async {
        final bridge = FakeReminderBridge();
        final scheduler = PlatformAlarmScheduler(bridge);
        await bridge.setExactAlarm(alarmId: 1, epochMs: 0);
        // v1.3b / Phase 13: `rescheduleAll` no longer owns
        // a local reliability cache; it delegates to
        // `ReliabilityService.instance.refresh()`. The
        // service may not be init'd in this test, in which
        // case the call is a no-op (the scheduler swallows
        // the StateError). The bridge's rescheduleCount is
        // the load-bearing assertion.
        await scheduler.rescheduleAll();
        expect(bridge.rescheduleCount, 1);
      },
    );

    group('reliability (v1.3b / Phase 13 delegation)', () {
      setUp(() async {
        // Each test in this group drives
        // `ReliabilityService.value` directly to assert the
        // scheduler's getter is a thin pass-through. We
        // init the service against the same bridge the
        // scheduler uses so the bootstrap probe is wired.
        ReliabilityService.resetForTesting();
        PermissionService.instance.resetForTesting();
        await PermissionService.instance.init();
        // v1.3b / Phase 13 / SYS-112: PermissionService.init
        // defaults every runtime permission to `Denied`
        // because the platform channel is missing in the
        // test harness. Grant every kind so the bootstrap
        // derives `optimal`; tests that flip the bridge
        // override `reliability` explicitly.
        PermissionService.instance.statuses.value = {
          for (final k in PermissionKind.values)
            k: const PermissionResultGranted(),
        };
      });

      tearDown(() {
        ReliabilityService.resetForTesting();
        PermissionService.instance.resetForTesting();
      });

      test('delegates to ReliabilityService.instance.value', () async {
        final bridge = FakeReminderBridge();
        final scheduler = PlatformAlarmScheduler(bridge);
        await ReliabilityService.init(
          bridge: bridge,
          permissionService: PermissionService.instance,
        );
        // The service is primed at `optimal`; the getter
        // returns the same value.
        expect(scheduler.reliability, Reliability.optimal);

        // Flip the service value; the getter picks it up
        // on the next read.
        bridge.reliability = Reliability.degraded;
        await ReliabilityService.instance.refresh();
        expect(scheduler.reliability, Reliability.degraded);
      });

      test('returns optimal when ReliabilityService is not init', () {
        // Construct the scheduler standalone (no service).
        // The getter must NOT throw — it falls back to
        // `optimal` (the same default the unified service
        // uses for the first-read race).
        final bridge = FakeReminderBridge();
        final scheduler = PlatformAlarmScheduler(bridge);
        expect(scheduler.reliability, Reliability.optimal);
      });

      test(
        'reflects a permissions change to a gated kind (location → degraded)',
        () async {
          final bridge = FakeReminderBridge();
          final scheduler = PlatformAlarmScheduler(bridge);
          await ReliabilityService.init(
            bridge: bridge,
            permissionService: PermissionService.instance,
          );
          // Drain the bootstrap.
          await Future<void>.delayed(Duration.zero);
          expect(scheduler.reliability, Reliability.optimal);

          // Flip `location` to denied. The service
          // re-derives; the scheduler's getter picks it up.
          final next = <PermissionKind, PermissionResult?>{
            for (final entry
                in PermissionService.instance.statuses.value.entries)
              entry.key: entry.value,
            PermissionKind.location: const PermissionResultDenied(
              canOpenSettings: true,
            ),
          };
          PermissionService.instance.statuses.value = next;
          expect(scheduler.reliability, Reliability.degraded);
        },
      );
    });

    // v1.2e / Phase 5: the inbound `fireAlarm` lookup
    // table. Pinned because a regression here would silently
    // skip the notification render — the Dart side has no
    // other source of truth for "what does this alarmId
    // belong to?".
    group('lookupForFire (v1.2e / Phase 5)', () {
      test('returns null for an unknown id', () async {
        final scheduler = PlatformAlarmScheduler(FakeReminderBridge());
        expect(await scheduler.lookupForFire(const AlarmId(9999)), isNull);
      });

      test(
        'returns the habit entry after schedule (name, strongMode, at)',
        () async {
          final bridge = FakeReminderBridge();
          final scheduler = PlatformAlarmScheduler(bridge);
          final at = DateTime(2026, 6, 20, 9);
          final id = await scheduler.schedule(_makeHabit('h1'), at);

          final entry = await scheduler.lookupForFire(id);
          expect(entry, isNotNull);
          expect(entry!.habitId, 'h1');
          expect(entry.at, at);
          // _makeHabit is SoftProof → strongMode is false.
          expect(entry.strongMode, isFalse);
          expect(entry.eventId, isNull);
          expect(entry.habitName, 'Test habit');
        },
      );

      test('records strongMode=true for StrongProof habits', () async {
        final bridge = FakeReminderBridge();
        final scheduler = PlatformAlarmScheduler(bridge);
        final strong = DoFixed(
          id: 'h-strong',
          name: 'Strong',
          proofMode: StrongProof(_trivialChain()),
          createdAt: DateTime(2026),
          restDaysPerMonth: 2,
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
          time: const DoTime(7, 30),
        );
        final at = DateTime(2026, 6, 20, 7, 30);
        final id = await scheduler.schedule(strong, at);
        final entry = await scheduler.lookupForFire(id);
        expect(entry!.strongMode, isTrue);
      });

      test('event entries carry the eventId and the event name', () async {
        final bridge = FakeReminderBridge();
        final scheduler = PlatformAlarmScheduler(bridge);
        final at = DateTime(2026, 6, 20, 9);
        final event = Event(
          id: 'evt_42',
          name: 'Standup',
          atMillis: at.millisecondsSinceEpoch,
          leadTimeMillis: 0,
          createdAtMillis: at.millisecondsSinceEpoch,
        );
        final id = await scheduler.scheduleEvent(event, at);
        final entry = await scheduler.lookupForFire(id);
        expect(entry, isNotNull);
        expect(entry!.eventId, 'evt_42');
        expect(entry.habitName, 'Standup');
        expect(entry.habitId, 'event:evt_42');
        expect(entry.strongMode, isFalse);
      });

      test('cancel removes the entry', () async {
        final bridge = FakeReminderBridge();
        final scheduler = PlatformAlarmScheduler(bridge);
        final id = await scheduler.schedule(
          _makeHabit('h1'),
          DateTime(2026, 6, 20, 9),
        );
        expect(await scheduler.lookupForFire(id), isNotNull);
        await scheduler.cancel(id);
        expect(await scheduler.lookupForFire(id), isNull);
      });

      test('rescheduleAll clears every entry', () async {
        final bridge = FakeReminderBridge();
        final scheduler = PlatformAlarmScheduler(bridge);
        final id1 = await scheduler.schedule(
          _makeHabit('h1'),
          DateTime(2026, 6, 20, 9),
        );
        final id2 = await scheduler.schedule(
          _makeHabit('h2'),
          DateTime(2026, 6, 21, 9),
        );
        expect(await scheduler.lookupForFire(id1), isNotNull);
        expect(await scheduler.lookupForFire(id2), isNotNull);
        await scheduler.rescheduleAll();
        expect(await scheduler.lookupForFire(id1), isNull);
        expect(await scheduler.lookupForFire(id2), isNull);
      });
    });
  });
}
