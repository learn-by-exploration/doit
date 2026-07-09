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
import 'package:doit/services/scheduled_message_repository.dart';
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

    test('scheduled-message alarm (v1.8-pr-e2 / SYS-196 / ADR-126) '
        'marks the row fired and shows a notification', () async {
      // Insert a pending scheduled-message row + arm the
      // corresponding alarm on the fake scheduler. Then
      // fire it via the inbound path and assert the row
      // is marked `fired` + a notification is shown.
      await ScheduledMessageRepository.instance.insert(
        id: 'sm-fire-1',
        personId: 'p1',
        channelTag: 'whatsapp',
        channelHandle: '+15555550100',
        messageBody: 'hi there',
        fireAt: DateTime.fromMillisecondsSinceEpoch(1735689600000),
        createdAt: DateTime.fromMillisecondsSinceEpoch(1735603200000),
      );
      final id = await scheduler.scheduleScheduledMessage(
        scheduledMessageId: 'sm-fire-1',
        at: DateTime.fromMillisecondsSinceEpoch(1735689600000),
      );

      await service.onFireAlarm(id);

      // Notification rendered.
      expect(notifs.shown, hasLength(1));
      expect(notifs.shown.first.alarmId, id);
      expect(notifs.shown.first.habitId, 'scheduled_message:sm-fire-1');
      // v1.8-pr-e2 / SYS-195 / ADR-126: the body-tap
      // PendingIntent is wired to the WhatsApp deep link
      // with the pre-filled body. The Kotlin side reads
      // `event.tapUri` and switches on the scheme to
      // build the right Intent.ACTION_VIEW.
      expect(
        notifs.shown.first.tapUri,
        'https://wa.me/15555550100?text=hi+there',
      );

      // Row marked fired (status flipped, firedAt set).
      final back = await ScheduledMessageRepository.instance.getById(
        'sm-fire-1',
      );
      expect(back, isNotNull);
      expect(back!.status, ScheduledMessageStatus.fired);
      expect(back.firedAt, isNotNull);
    });

    test(
      'scheduled-message alarm with sms channel builds a sms: tapUri',
      () async {
        await ScheduledMessageRepository.instance.insert(
          id: 'sm-sms-1',
          personId: 'p1',
          channelTag: 'sms',
          channelHandle: '+15555550100',
          messageBody: 'hello',
          fireAt: DateTime.fromMillisecondsSinceEpoch(1735689600000),
          createdAt: DateTime.fromMillisecondsSinceEpoch(1735603200000),
        );
        final id = await scheduler.scheduleScheduledMessage(
          scheduledMessageId: 'sm-sms-1',
          at: DateTime.fromMillisecondsSinceEpoch(1735689600000),
        );
        await service.onFireAlarm(id);
        expect(notifs.shown, hasLength(1));
        // The sms: scheme goes through ACTION_SENDTO on
        // the Kotlin side; the Dart side just hands the
        // URI string through.
        expect(notifs.shown.first.tapUri, 'sms:+15555550100?body=hello');
      },
    );

    test('scheduled-message alarm with dialer channel builds a tel: tapUri '
        '(body is ignored)', () async {
      await ScheduledMessageRepository.instance.insert(
        id: 'sm-dial-1',
        personId: 'p1',
        channelTag: 'dialer',
        channelHandle: '+15555550100',
        messageBody: 'body-ignored',
        fireAt: DateTime.fromMillisecondsSinceEpoch(1735689600000),
        createdAt: DateTime.fromMillisecondsSinceEpoch(1735603200000),
      );
      final id = await scheduler.scheduleScheduledMessage(
        scheduledMessageId: 'sm-dial-1',
        at: DateTime.fromMillisecondsSinceEpoch(1735689600000),
      );
      await service.onFireAlarm(id);
      expect(notifs.shown, hasLength(1));
      // The dialer's launch(body) is a no-op for body
      // (per PersonChannel contract). URI is
      // `tel:+15555550100`.
      expect(notifs.shown.first.tapUri, 'tel:+15555550100');
    });

    test(
      'scheduled-message alarm with null body omits ?text= / ?body=',
      () async {
        await ScheduledMessageRepository.instance.insert(
          id: 'sm-nobody-1',
          personId: 'p1',
          channelTag: 'whatsapp',
          channelHandle: '+15555550100',
          messageBody: null,
          fireAt: DateTime.fromMillisecondsSinceEpoch(1735689600000),
          createdAt: DateTime.fromMillisecondsSinceEpoch(1735603200000),
        );
        final id = await scheduler.scheduleScheduledMessage(
          scheduledMessageId: 'sm-nobody-1',
          at: DateTime.fromMillisecondsSinceEpoch(1735689600000),
        );
        await service.onFireAlarm(id);
        expect(notifs.shown, hasLength(1));
        // The no-body case is the "just open the
        // conversation" path; the URI has no `?text=`.
        expect(notifs.shown.first.tapUri, 'https://wa.me/15555550100');
      },
    );

    test(
      'scheduled-message alarm with a missing row is a silent no-op',
      () async {
        // The row was deleted (cancelled + purged from
        // history) between schedule and fire. The fake
        // scheduler still has the entry (the inbound
        // handler may race the cancel path); the row is
        // gone. The handler should skip the notification
        // and not throw.
        final id = await scheduler.scheduleScheduledMessage(
          scheduledMessageId: 'sm-orphan',
          at: DateTime.fromMillisecondsSinceEpoch(1735689600000),
        );

        await service.onFireAlarm(id);

        expect(notifs.shown, isEmpty);
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
  Future<AlarmId> scheduleScheduledMessage({
    required String scheduledMessageId,
    required DateTime at,
  }) async => AlarmId(scheduledMessageId.hashCode & 0x7FFFFFFF);

  @override
  Future<void> cancelScheduledMessage(String scheduledMessageId) async {}

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
