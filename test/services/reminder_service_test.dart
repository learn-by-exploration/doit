// Tests for the ReminderService (WF-028 — test reminder button).
//
// The "Send a test reminder" button on the settings screen
// schedules a synthetic alarm 5 seconds from now. This file
// pins the behavior so the button cannot regress silently.
//
// v1.2e / Phase 5: also covers `onFireAlarm` — the
// inbound path from the Kotlin `AlarmReceiver` to the
// Dart notification render.

import 'package:doit/events/event.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/event_repository.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/missions/chain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeAlarmScheduler scheduler;
  late FakeNotificationService notifs;
  late FakeFullScreenIntent fullScreen;
  late ReminderService service;

  setUp(() async {
    await AppDatabaseService.instance.closeForTesting();
    final db = AppDatabase(NativeDatabase.memory());
    await AppDatabaseService.instance.init(overrideDb: db);
    scheduler = FakeAlarmScheduler();
    notifs = FakeNotificationService();
    fullScreen = FakeFullScreenIntent();
    service = ReminderService(
      scheduler: scheduler,
      notifications: notifs,
      fullScreen: fullScreen,
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

  // ── v1.2e / Phase 5: onFireAlarm inbound ────────────────────
  group('onFireAlarm (v1.2e / Phase 5)', () {
    test('unknown id is a silent no-op (mirror cleared)', () async {
      // No schedule; lookupForFire returns null.
      await service.onFireAlarm(const AlarmId(9999));
      expect(notifs.shown, isEmpty);
    });

    test(
      'habit alarm shows notification and re-schedules next occurrence',
      () async {
        final h = DoFixed(
          id: 'h1',
          name: 'Drink water',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026),
          restDaysPerMonth: 2,
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
          time: const DoTime(9, 0),
        );
        await DoRepository.instance.save(h);
        final at = DateTime(2026, 6, 20, 9); // a Saturday
        final id = await scheduler.schedule(h, at);

        await service.onFireAlarm(id);

        expect(notifs.shown, hasLength(1));
        final event = notifs.shown.first;
        expect(event.habitId, 'h1');
        expect(event.habitName, 'Drink water');
        expect(event.alarmId, id);
        expect(event.strongMode, isFalse);

        // Next occurrence for a daily Fixed is the next day at
        // the same time. The scheduler should have a fresh
        // scheduled entry for that.
        expect(scheduler.scheduled.length, greaterThanOrEqualTo(2));
        // The most-recent schedule is the re-fire.
        final last = scheduler.scheduled.last;
        expect(last.habitId, 'h1');
        expect(last.at, DateTime(2026, 6, 21, 9));
      },
    );

    test('strong-mode habit also launches the full-screen intent', () async {
      final h = DoFixed(
        id: 'h-strong',
        name: 'Tighten bolts',
        proofMode: StrongProof(_trivialChain()),
        createdAt: DateTime(2026),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      );
      await DoRepository.instance.save(h);
      final at = DateTime(2026, 6, 20, 9);
      final id = await scheduler.schedule(h, at);

      await service.onFireAlarm(id);

      expect(notifs.shown, hasLength(1));
      expect(notifs.shown.first.strongMode, isTrue);
      expect(fullScreen.launches, hasLength(1));
      expect(fullScreen.launches.first.habit.id, 'h-strong');
    });

    test('event alarm shows notification and archives the event', () async {
      final event = Event(
        id: 'evt_42',
        name: 'Standup',
        atMillis: DateTime(2026, 6, 20, 9).millisecondsSinceEpoch,
        leadTimeMillis: 0,
        createdAtMillis: DateTime(2026, 6, 20, 9).millisecondsSinceEpoch,
      );
      await EventRepository.instance.save(event);
      final at = DateTime(2026, 6, 20, 9);
      final id = await scheduler.scheduleEvent(event, at);

      await service.onFireAlarm(id);

      expect(notifs.shown, hasLength(1));
      expect(notifs.shown.first.habitName, 'Standup');
      expect(notifs.shown.first.alarmId, id);

      // The event should be archived in the DB.
      final back = await EventRepository.instance.getById('evt_42');
      expect(back, isNotNull);
      expect(back!.isArchived, isTrue);
    });

    test(
      'missing habit in the DB: shows notification but does not re-schedule',
      () async {
        // Schedule against a non-existent habit id (e.g.,
        // the alarm was armed by the Kotlin side before the
        // user opened the app for the first time).
        final entry = ScheduledAlarm(
          id: const AlarmId(7777),
          habitId: 'phantom-habit',
          at: DateTime(2026, 6, 20, 9),
          habitName: 'Phantom',
        );
        // Inject via the fake's internal list. We use a
        // throwaway FakeAlarmScheduler subclass to keep the
        // surface narrow.
        final phantomScheduler = _PhantomScheduler(entry);
        final svc = ReminderService(
          scheduler: phantomScheduler,
          notifications: notifs,
          fullScreen: fullScreen,
          anchor: FakeAnchorDetector(),
          bridge: FakeReminderBridge(),
        );
        ReminderService.resetForTesting();
        await ReminderService.init(svc);

        await svc.onFireAlarm(const AlarmId(7777));

        expect(notifs.shown, hasLength(1));
        expect(phantomScheduler.scheduleCalls, isEmpty);
      },
    );
  });
}

class _PhantomScheduler implements AlarmScheduler {
  _PhantomScheduler(this._entry);
  final ScheduledAlarm _entry;
  final List<ScheduledAlarm> scheduleCalls = <ScheduledAlarm>[];

  @override
  Future<ScheduledAlarm?> lookupForFire(AlarmId id) async => _entry;

  @override
  Future<AlarmId> schedule(Do habit, DateTime at) async {
    final id = AlarmId(scheduleCalls.length + 1);
    scheduleCalls.add(ScheduledAlarm(id: id, habitId: habit.id, at: at));
    return id;
  }

  @override
  Future<void> cancel(AlarmId id) async {}

  @override
  Future<AlarmId> snooze(AlarmId id, Duration delay) async => id;

  @override
  Future<void> rescheduleAll() async {}

  @override
  Future<AlarmId> scheduleEvent(Event event, DateTime at) async =>
      const AlarmId(1);

  @override
  Future<void> cancelEvent(String eventId) async {}

  @override
  Future<void> cancelForHabit(String habitId) async {}

  @override
  Reliability get reliability => Reliability.optimal;
}

/// Tiny chain builder so the strong-mode test stays self-contained.
MissionChain _trivialChain() => MissionChain(const [
  TypeMission(
    id: 'm1',
    label: 'Type OK',
    timeout: Duration(seconds: 5),
    expectedPhrase: 'OK',
  ),
]);
