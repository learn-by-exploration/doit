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
}
