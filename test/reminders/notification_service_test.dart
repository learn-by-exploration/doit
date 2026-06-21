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

    test('body defaults to null (Phase A habit-reminder path)', () {
      final ev = ReminderEvent(
        habitId: 'h1',
        habitName: 'Stretch',
        at: DateTime(2026, 6, 13, 9),
        alarmId: const AlarmId(1),
      );
      expect(ev.body, isNull);
    });

    test('body carries a routine-fired verbatim body when set', () {
      // v1.1 (SYS-080 / ADR-025): a Phase C/D/E routine whose
      // action is `ActionNotify` builds the notification body in
      // Dart (not on the Kotlin side), so the RoutineExecutor
      // hands the body to the notification service via this
      // field. The platform side uses `body` verbatim when it is
      // non-null.
      final ev = ReminderEvent(
        habitId: 'h_routine',
        habitName: 'Drink water',
        at: DateTime(2026, 6, 13, 9),
        alarmId: const AlarmId(2),
        body: 'Time to drink a glass of water.',
      );
      expect(ev.body, 'Time to drink a glass of water.');
    });

    test('show records an event with a non-null body', () async {
      // Round-trip: a routine-fired notification with a body
      // records the full event in `FakeNotificationService.shown`
      // so widget tests can assert the rendered copy.
      final n = FakeNotificationService();
      final ev = ReminderEvent(
        habitId: 'h_routine',
        habitName: 'Drink water',
        at: DateTime(2026, 6, 13, 9),
        alarmId: const AlarmId(3),
        body: 'Time to drink a glass of water.',
      );
      await n.show(ev);
      expect(n.shown, hasLength(1));
      expect(n.shown.first.body, ev.body);
    });
  });
}
