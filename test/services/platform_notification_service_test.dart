// Tests for [PlatformNotificationService] — the production
// wiring that delegates `NotificationService.show` and
// `NotificationService.dismiss` to the Kotlin
// `ReminderChannelProxy` (v1.2e / Phase 5).
//
// The "full chain" being pinned is:
//
//   `NotificationService.dismiss(id)`
//      → `PlatformNotificationService.dismiss(id)`
//      → `ReminderBridge.cancelNotification(id.value)`
//      → `NotificationManager.cancel(id.value)` (platform-side)
//
// The Dart side ends at the bridge; the platform-side cancel is
// covered by a static-analysis test on the Kotlin handler
// (`ReminderChannelProxy.showNotification` / `cancelNotification`)
// plus the on-device verification listed in the v1.2
// release-checklist. The `FakeReminderBridge` records every
// call so a Dart regression is observable here.

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/services/platform_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlatformNotificationService', () {
    late FakeReminderBridge bridge;
    late PlatformNotificationService service;

    setUp(() {
      bridge = FakeReminderBridge();
      service = PlatformNotificationService(bridge);
    });

    test(
      'show forwards (alarmId, habitName, body, strongMode) to bridge.showNotification',
      () async {
        final event = ReminderEvent(
          habitId: 'h1',
          habitName: 'Drink water',
          at: DateTime(2026, 6, 20, 9),
          alarmId: const AlarmId(42),
          body: 'Routine says: drink now.',
        );
        await service.show(event);
        expect(bridge.showNotificationCalls, hasLength(1));
        final call = bridge.showNotificationCalls.single;
        expect(call.alarmId, 42);
        expect(call.habitName, 'Drink water');
        expect(call.body, 'Routine says: drink now.');
        expect(call.strongMode, isFalse);
      },
    );

    test('show passes strongMode=true for StrongProof habits', () async {
      final event = ReminderEvent(
        habitId: 'h2',
        habitName: 'Tighten bolts',
        at: DateTime(2026, 6, 20, 9),
        alarmId: const AlarmId(7),
        strongMode: true,
      );
      await service.show(event);
      final call = bridge.showNotificationCalls.single;
      expect(call.strongMode, isTrue);
    });

    test(
      'dismiss forwards the alarmId value to bridge.cancelNotification',
      () async {
        await service.dismiss(const AlarmId(99));
        expect(bridge.cancelNotificationCalls, [99]);
      },
    );

    test(
      'dismiss does not call show (the cancel and show paths are independent)',
      () async {
        await service.dismiss(const AlarmId(99));
        expect(bridge.showNotificationCalls, isEmpty);
        expect(bridge.cancelNotificationCalls, [99]);
      },
    );

    test(
      'show swallows bridge exceptions and never throws (ADR-013 contract)',
      () async {
        // Replace the bridge with one whose showNotification
        // throws to simulate a missing platform handler.
        final brokenBridge = _ThrowingReminderBridge();
        final svc = PlatformNotificationService(brokenBridge);
        // Must not throw — `main()` already ran and we cannot
        // let a notification failure crash the app.
        await svc.show(
          ReminderEvent(
            habitId: 'h1',
            habitName: 'X',
            at: DateTime(2026, 6, 20, 9),
            alarmId: const AlarmId(1),
          ),
        );
        await svc.dismiss(const AlarmId(1));
      },
    );
  });
}

/// Bridge stub that throws on every call. Used to verify the
/// production service's defensive try/catch (ADR-013).
class _ThrowingReminderBridge implements ReminderBridge {
  @override
  Future<void> cancelNotification(int alarmId) async {
    throw StateError('simulated platform handler missing');
  }

  @override
  Future<void> showNotification({
    required int alarmId,
    required String habitName,
    String? body,
    bool strongMode = false,
  }) async {
    throw StateError('simulated platform handler missing');
  }

  @override
  Future<void> rescheduleAll() async => throw UnimplementedError();

  @override
  Future<void> recordAnchor(DateTime at) async => throw UnimplementedError();

  @override
  Future<Reliability> probeReliability() async => throw UnimplementedError();

  @override
  Future<int> setExactAlarm({
    required int alarmId,
    required int epochMs,
  }) async => throw UnimplementedError();

  @override
  Future<void> cancelAlarm(int alarmId) async => throw UnimplementedError();

  @override
  Future<void> showFullScreen(String habitId) async =>
      throw UnimplementedError();

  @override
  Future<void> openIgnoreBatteryOptimizations() async =>
      throw UnimplementedError();

  @override
  Future<void> schedulePreAlarm({
    required int alarmId,
    required int leadTimeSeconds,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> cancelPreAlarms(int alarmId) async =>
      throw UnimplementedError();
}
