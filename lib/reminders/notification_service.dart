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
// - Notification channel is `doit.reminders`, high importance.
// - The action button is "Done" (or "Open" for strong-mode
//   habits).
// - A custom monochrome icon `ic_doit_notification` is used.

import 'dart:async';

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:meta/meta.dart';

/// A reminder to surface. The widget layer composes this; the
/// service renders it.
///
/// v1.1 adds an optional [body] field used by routine-fired
/// notifications (Phase C/D/E routines whose action is
/// `ActionNotify`). The field defaults to `null` and the
/// existing habit-reminder path (Phase A) keeps the
/// Kotlin-side body derivation.
@immutable
class ReminderEvent {
  const ReminderEvent({
    required this.habitId,
    required this.habitName,
    required this.at,
    required this.alarmId,
    this.strongMode = false,
    this.body,
  });
  final String habitId;
  final String habitName;
  final DateTime at;
  final AlarmId alarmId;
  final bool strongMode;

  /// Optional body text. When `null` (the default), the
  /// platform side derives the body from the habit. When
  /// non-null (routine fires), the value is used as the
  /// notification body verbatim.
  final String? body;
}

/// Public surface for the notification service.
abstract class NotificationService {
  /// Show [event] on the doit.reminders channel.
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

/// The Android notification channel id for reminder
/// notifications. v0.5a renamed this from `streak.reminders` to
/// `doit.reminders` to match the renamed app id. The id is the
/// Android-side key used by `NotificationManager` to group
/// notifications and is preserved across app updates, so it
/// MUST match the value used by the platform-side channel
/// registration. Pinned by a static-analysis test in
/// `test/release_signing_test.dart`.
const String kNotificationChannelId = 'doit.reminders';
