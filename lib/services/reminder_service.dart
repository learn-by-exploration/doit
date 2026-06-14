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

import 'package:common_games/habits/habit.dart';
import 'package:common_games/habits/proof_mode.dart';
import 'package:common_games/reminders/alarm_scheduler.dart';
import 'package:common_games/reminders/anchor_detector.dart';
import 'package:common_games/reminders/full_screen_intent.dart';
import 'package:common_games/reminders/notification_service.dart';
import 'package:common_games/reminders/reminder_bridge.dart';
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
  Future<AlarmId> scheduleHabit(Habit habit, DateTime at) async {
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
}
