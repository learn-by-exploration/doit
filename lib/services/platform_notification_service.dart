// Platform notification service — production wiring.
//
// In v0.1, the Dart side does not call
// `flutter_local_notifications` directly. The Kotlin
// `ReminderChannelProxy` (Phase 4) takes care of building
// and showing notifications on the OS thread. The Dart
// side is invoked when an alarm fires via the channel's
// inbound `fireAlarm` method.
//
// This file is the production-side stub for
// [NotificationService] that the production `main.dart`
// constructs. Widget tests use [FakeNotificationService].
//
// Implementation: a no-op that just hands the event off to
// the bridge as a record. The Kotlin side re-derives the
// notification body from the habit.

import 'dart:async';

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';

class PlatformNotificationService implements NotificationService {
  PlatformNotificationService(this.bridge);

  // Reserved for future use — the bridge receives the event
  // shape that the Kotlin side will turn into a
  // `flutter_local_notifications` call. v0.1's Kotlin side
  // derives the body from the habitId.
  final ReminderBridge bridge;

  @override
  Future<void> show(ReminderEvent event) async {
    // The Kotlin side re-derives the body from the habit.
    // This method is a placeholder; the real show happens
    // on the platform side when the alarm fires.
  }

  @override
  Future<void> dismiss(AlarmId id) async {
    // No-op in v0.1; v0.2 cancels the active notification.
  }
}
