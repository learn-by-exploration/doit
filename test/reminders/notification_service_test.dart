// Tests for [NotificationService] and the [FakeNotificationService].

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeNotificationService', () {
    test('show records the event', () async {
      final n = FakeNotificationService();
      final ev = ReminderEvent(
        habitId: 'h1',
        habitName: 'Stretch',
        at: DateTime(2026, 6, 13, 9),
        alarmId: const AlarmId(1),
      );
      await n.show(ev);
      expect(n.shown, [ev]);
    });

    test('dismiss records the alarm id', () async {
      final n = FakeNotificationService();
      await n.dismiss(const AlarmId(7));
      expect(n.dismissed, contains(const AlarmId(7)));
    });

    test('strong mode defaults to false', () {
      final ev = ReminderEvent(
        habitId: 'h1',
        habitName: 'Run',
        at: DateTime(2026, 6, 13, 9),
        alarmId: const AlarmId(1),
      );
      expect(ev.strongMode, isFalse);
    });
  });
}
