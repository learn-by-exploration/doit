// Tests for the ReminderService (WF-028 — test reminder button).
//
// The "Send a test reminder" button on the settings screen
// schedules a synthetic alarm 5 seconds from now. This file
// pins the behavior so the button cannot regress silently.

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeAlarmScheduler scheduler;
  late ReminderService service;

  setUp(() async {
    await AppDatabaseService.instance.closeForTesting();
    final db = AppDatabase(NativeDatabase.memory());
    await AppDatabaseService.instance.init(overrideDb: db);
    scheduler = FakeAlarmScheduler();
    service = ReminderService(
      scheduler: scheduler,
      notifications: FakeNotificationService(),
      fullScreen: FakeFullScreenIntent(),
      anchor: FakeAnchorDetector(),
      bridge: FakeReminderBridge(),
    );
    ReminderService.resetForTesting();
    await ReminderService.init(service);
  });

  tearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });

  test('scheduleTestReminder schedules an alarm ~5s in the future', () async {
    final before = DateTime.now();
    await service.scheduleTestReminder();
    final after = DateTime.now();
    expect(scheduler.scheduled.length, 1);
    final at = scheduler.scheduled.first.at;
    // The scheduled time must be between (before + 5s) and (after + 5s).
    expect(
      at.isAfter(before.add(const Duration(seconds: 4))),
      isTrue,
      reason: 'expected $at > ${before.add(const Duration(seconds: 4))}',
    );
    expect(
      at.isBefore(after.add(const Duration(seconds: 6))),
      isTrue,
      reason: 'expected $at < ${after.add(const Duration(seconds: 6))}',
    );
  });

  test('scheduleTestReminder accepts a custom delay', () async {
    await service.scheduleTestReminder(delay: const Duration(seconds: 1));
    expect(scheduler.scheduled.length, 1);
    final at = scheduler.scheduled.first.at;
    final diff = at.difference(DateTime.now());
    expect(diff.inSeconds, lessThanOrEqualTo(2));
    expect(diff.inSeconds, greaterThanOrEqualTo(0));
  });

  test('cancelTestReminder drops the test alarm', () async {
    await service.scheduleTestReminder();
    expect(scheduler.scheduled.length, 1);
    await service.cancelTestReminder();
    expect(scheduler.scheduled, isEmpty);
  });

  test('cancelTestReminder is a no-op when no test alarm is pending', () async {
    // No schedule call first.
    await service.cancelTestReminder();
    expect(scheduler.scheduled, isEmpty);
  });

  test('scheduled test alarm has the well-known test habit id', () async {
    await service.scheduleTestReminder();
    expect(scheduler.scheduled.length, 1);
    expect(scheduler.scheduled.first.habitId, 'doit.test_reminder');
  });
}
