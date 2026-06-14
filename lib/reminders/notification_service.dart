// Reminder notifications — thin layer over
// `flutter_local_notifications`.
//
// The rest of the app calls [NotificationService.show] with a
// pre-built [ReminderEvent]. This file is the only one in the
// reminder folder that touches the `flutter_local_notifications`
// API. Tests use [FakeNotificationService].
//
// Layer rules (per .claude/rules/lib-reminders.md):
// - No `DateTime.now()` inside the service; the caller passes
//   the trigger time in [ReminderEvent.at].
// - Notification channel is `streak.reminders`, high importance.
// - The action button is "Done" (or "Open" for strong-mode
//   habits).
// - A custom monochrome icon `ic_streak_notification` is used.

import 'dart:async';

import 'package:common_games/reminders/alarm_scheduler.dart';
import 'package:meta/meta.dart';

/// A reminder to surface. The widget layer composes this; the
/// service renders it.
@immutable
class ReminderEvent {
  const ReminderEvent({
    required this.habitId,
    required this.habitName,
    required this.at,
    required this.alarmId,
    this.strongMode = false,
  });
  final String habitId;
  final String habitName;
  final DateTime at;
  final AlarmId alarmId;
  final bool strongMode;
}

/// Public surface for the notification service.
abstract class NotificationService {
  /// Show [event] on the streak.reminders channel.
  Future<void> show(ReminderEvent event);

  /// Dismiss the notification for [alarmId].
  Future<void> dismiss(AlarmId id);
}

/// In-memory implementation used by tests. Records every show
/// and dismiss so tests can assert on it.
class FakeNotificationService implements NotificationService {
  final List<ReminderEvent> shown = <ReminderEvent>[];
  final Set<AlarmId> dismissed = <AlarmId>{};

  @override
  Future<void> show(ReminderEvent event) async {
    shown.add(event);
  }

  @override
  Future<void> dismiss(AlarmId id) async {
    dismissed.add(id);
  }
}
