// Platform notification service — production wiring.
//
// v0.1 left both `show` and `dismiss` as no-ops; v1.2e /
// Phase 5 wires them through to the Kotlin `ReminderChannelProxy`
// (which owns the `NotificationCompat.Builder` and the
// `NotificationManager.cancel` call). The Dart side is now
// a thin pass-through over the bridge; tests use
// [FakeNotificationService].
//
// Layer rules (per .claude/rules/lib-reminders.md):
//   - No `DateTime.now()` inside the service.
//   - No model imports.
//   - No `print()` — debug logs behind `kDebugMode`.
//   - The body field is forwarded verbatim when non-null
//     (routine-fired notifications, v1.1b / SYS-085) and
//     omitted when null (the Kotlin side derives the body
//     from `habitName`).

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';

class PlatformNotificationService implements NotificationService {
  PlatformNotificationService(this.bridge);

  final ReminderBridge bridge;

  @override
  Future<void> show(ReminderEvent event) async {
    try {
      await bridge.showNotification(
        alarmId: event.alarmId.value,
        habitName: event.habitName,
        body: event.body,
        strongMode: event.strongMode,
      );
    } catch (e, st) {
      // Defensive: a missing platform handler must not crash
      // `main()`. The v0.4b-release-fix / ADR-013 contract.
      if (kDebugMode) {
        debugPrint('PlatformNotificationService.show failed: $e\n$st');
      }
    }
  }

  @override
  Future<void> dismiss(AlarmId id) async {
    try {
      await bridge.cancelNotification(id.value);
    } catch (e, st) {
      // Same defensive contract as `show`.
      if (kDebugMode) {
        debugPrint('PlatformNotificationService.dismiss failed: $e\n$st');
      }
    }
  }
}
