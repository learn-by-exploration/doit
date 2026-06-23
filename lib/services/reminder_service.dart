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
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/event_repository.dart';
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

  /// v1.2e / Phase 5: handler for the inbound `fireAlarm`
  /// call from the Kotlin `AlarmReceiver`. Looks up the
  /// scheduled entry, renders the notification (or
  /// full-screen intent for strong-mode habits), then
  /// either re-schedules the next habit occurrence or
  /// archives a one-shot event.
  ///
  /// Returns normally if the entry is unknown (the mirror
  /// was cleared by `rescheduleAll` and the Kotlin side
  /// has not round-tripped a re-arming schedule yet — the
  /// notification is silently skipped; reliability is
  /// unaffected).
  Future<void> onFireAlarm(AlarmId id) async {
    await _ready.future;
    final ScheduledAlarm? entry = await scheduler.lookupForFire(id);
    if (entry == null) {
      // Mirror was cleared. The Kotlin side will re-arm
      // via rescheduleAll() on the next boot; nothing to
      // do here.
      return;
    }

    // Event-fired alarms are one-shot: archive and
    // show. The strong-mode bit is unused (events do
    // not have proof modes); the entry's `habitName`
    // carries the event's display name.
    final eventId = entry.eventId;
    if (eventId != null) {
      await notifications.show(
        ReminderEvent(
          habitId: entry.habitId,
          habitName: entry.habitName ?? eventId,
          at: entry.at,
          alarmId: id,
        ),
      );
      await EventRepository.instance.archive(eventId, DateTime.now());
      return;
    }

    // Habit-fired alarm: render the notification (or
    // full-screen intent for strong-mode), then queue
    // the next occurrence.
    final strong = entry.strongMode;
    await notifications.show(
      ReminderEvent(
        habitId: entry.habitId,
        habitName: entry.habitName ?? entry.habitId,
        at: entry.at,
        alarmId: id,
        strongMode: strong,
      ),
    );

    if (strong) {
      // Strong-mode also opens the full-screen mission
      // route. The Kotlin side does the actual launch on
      // a separate signal; this call here is a
      // best-effort hint so the Dart side can preload
      // the mission UI before the activity opens.
      final habit = await DoRepository.instance.getById(entry.habitId);
      final mode = habit?.proofMode;
      if (habit != null && mode is StrongProof) {
        await fullScreen.show(habit, mode.chain);
      }
    }

    final habit = await DoRepository.instance.getById(entry.habitId);
    if (habit != null) {
      final next = habit.nextOccurrence(entry.at);
      if (next != null) {
        await scheduler.schedule(habit, next);
      }
    }
  }

  /// `ReminderInbound` adapter — wires the
  /// [PlatformReminderBridge] dispatch table to
  /// [onFireAlarm]. Used from `main.dart`:
  ///
  /// ```dart
  /// final bridge = PlatformReminderBridge(
  ///   inbound: ReminderService.fireAlarmInbound,
  /// )..install();
  /// ```
  ///
  /// `rescheduleAll` is NOT routed through here; the
  /// service exposes a public [rescheduleAll] the caller
  /// wires to a separate callback if needed. Today the
  /// Kotlin `BootReceiver` triggers rescheduleAll via
  /// the bridge's own public method.
  static Future<void> fireAlarmInbound(int alarmId) async {
    await _instance?.onFireAlarm(AlarmId(alarmId));
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
