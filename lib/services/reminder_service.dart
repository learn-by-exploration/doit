// Reminder service — the singleton that wires the alarm
// scheduler, the notification service, the full-screen
// intent, the anchor detector, and the platform bridge into a
// single `init()` entry point.
//
// Per .claude/rules/lib-services.md:
// - One singleton per process.
// - `Completer<void> _ready`.
// - `init()` is idempotent.
// - All public methods `await _ready.future` first.

import 'dart:async';

import 'package:doit/events/event.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:meta/meta.dart';

@immutable
class ReminderService {
  const ReminderService({
    required this.scheduler,
    required this.notifications,
    required this.fullScreen,
    required this.anchor,
    required this.bridge,
  });

  final AlarmScheduler scheduler;
  final NotificationService notifications;
  final FullScreenIntent fullScreen;
  final AnchorDetector anchor;
  final ReminderBridge bridge;

  static ReminderService? _instance;
  static Completer<void> _ready = Completer<void>();

  /// Initialize the singleton. Idempotent. The first call
  /// wins; subsequent calls resolve immediately.
  static Future<void> init(ReminderService service) async {
    if (_instance == null) {
      _instance = service;
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  /// The initialized service. Throws if [init] was not called.
  static ReminderService get instance {
    final s = _instance;
    if (s == null) {
      throw StateError('ReminderService.init() was not called.');
    }
    return s;
  }

  /// Reset for tests.
  static void resetForTesting() {
    _instance = null;
    _ready = Completer<void>();
  }

  /// Schedule a reminder for a habit at the given wall-clock
  /// time.
  Future<AlarmId> scheduleHabit(Do habit, DateTime at) async {
    await _ready.future;
    final id = await scheduler.schedule(habit, at);
    final mode = habit.proofMode;
    if (mode is StrongProof) {
      // Strong mode: also arm the full-screen intent. The
      // actual launch happens when the alarm fires.
      await fullScreen.show(habit, mode.chain);
    }
    return id;
  }

  /// Schedule a one-shot reminder for an event. Fires once at
  /// `event.notifyAtMillis`. The alarm is unscheduled on fire
  /// (handled by the scheduler for one-shot IDs).
  Future<AlarmId> scheduleEvent(Event event) async {
    await _ready.future;
    return scheduler.scheduleEvent(
      event,
      DateTime.fromMillisecondsSinceEpoch(event.notifyAtMillis),
    );
  }

  /// Cancel a scheduled event reminder.
  Future<void> cancelEvent(String eventId) async {
    await _ready.future;
    await scheduler.cancelEvent(eventId);
  }

  /// Cancel a scheduled reminder.
  Future<void> cancel(AlarmId id) async {
    await _ready.future;
    await scheduler.cancel(id);
  }

  /// Snooze a reminder by [delay].
  Future<AlarmId> snooze(AlarmId id, Duration delay) async {
    await _ready.future;
    return scheduler.snooze(id, delay);
  }

  /// Re-schedule every pending habit. Called by the Kotlin
  /// `BootReceiver` (via a method channel) and on
  /// `ACTION_TIMEZONE_CHANGED`.
  Future<void> rescheduleAll() async {
    await _ready.future;
    await bridge.rescheduleAll();
    await scheduler.rescheduleAll();
  }

  /// v1.2j / Phase 10 / SYS-107. Schedules the 5-minute +
  /// 1-minute pre-alarm heads-up pair for a reminder that
  /// will fire at [fireAt]. Each pre-alarm is a one-shot
  /// `WorkManager` task on the platform side that posts a
  /// low-importance notification on the same
  /// `doit.reminders` channel. The actual [alarmId] alarm
  /// fires later as usual; the heads-up is purely
  /// advisory.
  ///
  /// The caller passes the `alarmId` (assigned by the
  /// scheduler) and the absolute `fireAt` epoch ms. The
  /// service derives the lead times from `fireAt` minus
  /// `now` and only enqueues heads-ups that land in the
  /// future (a heads-up at `fireAt - 5 minutes` is a no-op
  /// if `fireAt` is only 3 minutes away — the 5-minute
  /// heads-up is silently skipped). The Dart side does NOT
  /// call `DateTime.now()` directly — the caller passes
  /// the reference time so this method is testable.
  Future<void> schedulePreAlarms({
    required AlarmId alarmId,
    required DateTime fireAt,
    required DateTime now,
  }) async {
    await _ready.future;
    final lead5 = fireAt.difference(now);
    final lead1 = lead5;
    if (lead5.inSeconds > 5 * 60) {
      try {
        await bridge.schedulePreAlarm(
          alarmId: alarmId.value,
          leadTimeSeconds: 5 * 60,
        );
      } catch (_) {
        /* ADR-013 */
      }
    }
    if (lead1.inSeconds > 60) {
      try {
        await bridge.schedulePreAlarm(
          alarmId: alarmId.value,
          leadTimeSeconds: 60,
        );
      } catch (_) {
        /* ADR-013 */
      }
    }
  }

  /// v1.2j / Phase 10 / SYS-107. Cancel every pending
  /// pre-alarm heads-up for [alarmId]. Called from
  /// [cancel] (the user dismissed the underlying alarm)
  /// and from the habit-completion flow.
  Future<void> cancelPreAlarms(AlarmId alarmId) async {
    await _ready.future;
    try {
      await bridge.cancelPreAlarms(alarmId.value);
    } catch (_) {
      /* ADR-013 */
    }
  }

  /// Probe and cache the current reliability state.
  Future<Reliability> probeReliability() async {
    await _ready.future;
    return bridge.probeReliability();
  }

  /// Fire a synthetic test reminder [delay] from now (default 5
  /// seconds). Used by the settings "Test reminder" button to
  /// verify the notification pipeline end-to-end. The id is a
  /// stable, well-known string so the user can also tap
  /// "Cancel test reminder" to abort.
  Future<AlarmId> scheduleTestReminder({
    Duration delay = const Duration(seconds: 5),
  }) async {
    await _ready.future;
    final at = DateTime.now().add(delay);
    return scheduler.schedule(_testHabit, at);
  }

  /// Cancel a previously scheduled test reminder (if any). Safe
  /// to call when no test reminder is pending.
  Future<void> cancelTestReminder() async {
    await _ready.future;
    await scheduler.cancelForHabit('doit.test_reminder');
  }

  /// A synthetic [DoFixed] used by the "Test reminder" button.
  /// The id is a stable, well-known string so the test alarm
  /// can be cancelled. The schedule is "every day at 00:00" but
  /// since the test alarm is fired manually by the settings
  /// button, the schedule itself is irrelevant.
  static final DoFixed _testHabit = DoFixed(
    id: 'doit.test_reminder',
    name: 'do it test reminder',
    proofMode: const SoftProof(),
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    restDaysPerMonth: 0,
    weekdays: const {1, 2, 3, 4, 5, 6, 7},
    time: const DoTime(0, 0),
  );
}
