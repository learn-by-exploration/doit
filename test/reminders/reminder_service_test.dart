// Tests for [ReminderService] — the singleton that wires
// scheduler, notifications, full-screen intent, anchor
// detector, and bridge.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/missions/chain.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

DoFixed _habit() {
  return DoFixed(
    id: 'h1',
    name: 'Stretch',
    createdAt: DateTime(2026, 6),
    restDaysPerMonth: 2,
    proofMode: const SoftProof(),
    weekdays: const {1, 3, 5},
    time: const DoTime(9, 0),
  );
}

DoFixed _strong() {
  return DoFixed(
    id: 'h2',
    name: 'Run',
    createdAt: DateTime(2026, 6),
    restDaysPerMonth: 2,
    proofMode: StrongProof(
      MissionChain.from([
        const HoldMission(
          id: 'm1',
          label: 'Hold',
          timeout: Duration(seconds: 5),
          holdDuration: Duration(seconds: 2),
        ),
      ]),
    ),
    weekdays: const {1},
    time: const DoTime(7, 0),
  );
}

void main() {
  setUp(ReminderService.resetForTesting);

  test('init() makes instance accessible and is idempotent', () async {
    final s = ReminderService(
      scheduler: FakeAlarmScheduler(),
      notifications: FakeNotificationService(),
      fullScreen: FakeFullScreenIntent(),
      anchor: FakeAnchorDetector(),
      bridge: FakeReminderBridge(),
    );
    await ReminderService.init(s);
    expect(ReminderService.instance, same(s));
    // Second call: no-op, same instance.
    final s2 = ReminderService(
      scheduler: FakeAlarmScheduler(),
      notifications: FakeNotificationService(),
      fullScreen: FakeFullScreenIntent(),
      anchor: FakeAnchorDetector(),
      bridge: FakeReminderBridge(),
    );
    await ReminderService.init(s2);
    expect(ReminderService.instance, same(s));
  });

  test('instance throws when init was not called', () {
    expect(() => ReminderService.instance, throwsStateError);
  });

  test('scheduleHabit routes to the scheduler', () async {
    final scheduler = FakeAlarmScheduler();
    final s = ReminderService(
      scheduler: scheduler,
      notifications: FakeNotificationService(),
      fullScreen: FakeFullScreenIntent(),
      anchor: FakeAnchorDetector(),
      bridge: FakeReminderBridge(),
    );
    await ReminderService.init(s);
    final at = DateTime(2026, 6, 13, 9);
    final id = await ReminderService.instance.scheduleHabit(_habit(), at);
    expect(id, isNotNull);
    expect(scheduler.scheduled.length, 1);
    expect(scheduler.scheduled.first.at, at);
  });

  test('scheduleHabit for a strong habit also launches full-screen', () async {
    final fsi = FakeFullScreenIntent();
    final s = ReminderService(
      scheduler: FakeAlarmScheduler(),
      notifications: FakeNotificationService(),
      fullScreen: fsi,
      anchor: FakeAnchorDetector(),
      bridge: FakeReminderBridge(),
    );
    await ReminderService.init(s);
    final at = DateTime(2026, 6, 13, 7);
    await ReminderService.instance.scheduleHabit(_strong(), at);
    expect(fsi.launches.length, 1);
    expect(fsi.launches.first.habit.id, 'h2');
  });

  test('cancel routes to the scheduler', () async {
    final scheduler = FakeAlarmScheduler();
    final s = ReminderService(
      scheduler: scheduler,
      notifications: FakeNotificationService(),
      fullScreen: FakeFullScreenIntent(),
      anchor: FakeAnchorDetector(),
      bridge: FakeReminderBridge(),
    );
    await ReminderService.init(s);
    final id = await scheduler.schedule(_habit(), DateTime(2026, 6, 13, 9));
    await ReminderService.instance.cancel(id);
    expect(scheduler.cancelledIds, contains(id));
  });

  test('snooze returns a new id from the scheduler', () async {
    final scheduler = FakeAlarmScheduler();
    final s = ReminderService(
      scheduler: scheduler,
      notifications: FakeNotificationService(),
      fullScreen: FakeFullScreenIntent(),
      anchor: FakeAnchorDetector(),
      bridge: FakeReminderBridge(),
    );
    await ReminderService.init(s);
    final id = await scheduler.schedule(_habit(), DateTime(2026, 6, 13, 9));
    final newId = await ReminderService.instance.snooze(
      id,
      const Duration(minutes: 5),
    );
    expect(newId, isNot(id));
  });

  test('rescheduleAll routes to both bridge and scheduler', () async {
    final scheduler = FakeAlarmScheduler();
    final bridge = FakeReminderBridge();
    final s = ReminderService(
      scheduler: scheduler,
      notifications: FakeNotificationService(),
      fullScreen: FakeFullScreenIntent(),
      anchor: FakeAnchorDetector(),
      bridge: bridge,
    );
    await ReminderService.init(s);
    await ReminderService.instance.rescheduleAll();
    expect(bridge.rescheduleCount, 1);
  });

  // ── v1.2j / Phase 10 / SYS-107 ─────────────────────────────

  test('schedulePreAlarms enqueues both 5-min and 1-min heads-ups when '
      'fireAt is 10 min away', () async {
    final bridge = FakeReminderBridge();
    final s = ReminderService(
      scheduler: FakeAlarmScheduler(),
      notifications: FakeNotificationService(),
      fullScreen: FakeFullScreenIntent(),
      anchor: FakeAnchorDetector(),
      bridge: bridge,
    );
    await ReminderService.init(s);
    final now = DateTime(2026, 6, 23, 9);
    final fireAt = now.add(const Duration(minutes: 10));
    await ReminderService.instance.schedulePreAlarms(
      alarmId: const AlarmId(42),
      fireAt: fireAt,
      now: now,
    );
    expect(bridge.schedulePreAlarmCalls, hasLength(2));
    expect(bridge.schedulePreAlarmCalls[0].alarmId, 42);
    expect(bridge.schedulePreAlarmCalls[0].leadTimeSeconds, 5 * 60);
    expect(bridge.schedulePreAlarmCalls[1].alarmId, 42);
    expect(bridge.schedulePreAlarmCalls[1].leadTimeSeconds, 60);
  });

  test(
    'schedulePreAlarms skips the 5-min heads-up when fireAt is 3 min away',
    () async {
      final bridge = FakeReminderBridge();
      final s = ReminderService(
        scheduler: FakeAlarmScheduler(),
        notifications: FakeNotificationService(),
        fullScreen: FakeFullScreenIntent(),
        anchor: FakeAnchorDetector(),
        bridge: bridge,
      );
      await ReminderService.init(s);
      final now = DateTime(2026, 6, 23, 9);
      final fireAt = now.add(const Duration(minutes: 3));
      await ReminderService.instance.schedulePreAlarms(
        alarmId: const AlarmId(42),
        fireAt: fireAt,
        now: now,
      );
      expect(bridge.schedulePreAlarmCalls, hasLength(1));
      expect(bridge.schedulePreAlarmCalls.single.leadTimeSeconds, 60);
    },
  );

  test(
    'schedulePreAlarms skips both heads-ups when fireAt is 30 s away',
    () async {
      final bridge = FakeReminderBridge();
      final s = ReminderService(
        scheduler: FakeAlarmScheduler(),
        notifications: FakeNotificationService(),
        fullScreen: FakeFullScreenIntent(),
        anchor: FakeAnchorDetector(),
        bridge: bridge,
      );
      await ReminderService.init(s);
      final now = DateTime(2026, 6, 23, 9);
      final fireAt = now.add(const Duration(seconds: 30));
      await ReminderService.instance.schedulePreAlarms(
        alarmId: const AlarmId(42),
        fireAt: fireAt,
        now: now,
      );
      expect(bridge.schedulePreAlarmCalls, isEmpty);
    },
  );

  test('cancelPreAlarms forwards to bridge.cancelPreAlarms', () async {
    final bridge = FakeReminderBridge();
    final s = ReminderService(
      scheduler: FakeAlarmScheduler(),
      notifications: FakeNotificationService(),
      fullScreen: FakeFullScreenIntent(),
      anchor: FakeAnchorDetector(),
      bridge: bridge,
    );
    await ReminderService.init(s);
    await ReminderService.instance.cancelPreAlarms(const AlarmId(42));
    expect(bridge.cancelPreAlarmsCalls, [42]);
  });

  test('schedulePreAlarms swallows a bridge failure per ADR-013', () async {
    final bridge = _ThrowingPreAlarmBridge();
    final s = ReminderService(
      scheduler: FakeAlarmScheduler(),
      notifications: FakeNotificationService(),
      fullScreen: FakeFullScreenIntent(),
      anchor: FakeAnchorDetector(),
      bridge: bridge,
    );
    await ReminderService.init(s);
    final now = DateTime(2026, 6, 23, 9);
    final fireAt = now.add(const Duration(minutes: 10));
    // Must not throw.
    await ReminderService.instance.schedulePreAlarms(
      alarmId: const AlarmId(42),
      fireAt: fireAt,
      now: now,
    );
  });
}

/// Test bridge variant whose `schedulePreAlarm` throws —
/// used to pin the ADR-013 swallow path in
/// `ReminderService.schedulePreAlarms`.
class _ThrowingPreAlarmBridge extends FakeReminderBridge {
  @override
  Future<void> schedulePreAlarm({
    required int alarmId,
    required int leadTimeSeconds,
  }) async {
    throw Exception('simulated platform-channel error');
  }
}
