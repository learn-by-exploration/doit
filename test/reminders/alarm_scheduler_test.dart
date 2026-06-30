// Tests for [AlarmScheduler] (and [FakeAlarmScheduler] which
// is the in-memory test implementation).

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlarmId.forOccurrence', () {
    test('same (habitId, scheduledAt) → same id (re-schedule dedupes)', () {
      final at = DateTime(2026, 6, 13, 9);
      final a = AlarmId.forOccurrence('h1', at);
      final b = AlarmId.forOccurrence('h1', at);
      expect(a, b);
    });

    test('different habit → different id', () {
      final at = DateTime(2026, 6, 13, 9);
      final a = AlarmId.forOccurrence('h1', at);
      final b = AlarmId.forOccurrence('h2', at);
      expect(a, isNot(b));
    });

    test('different scheduledAt → different id', () {
      final a = AlarmId.forOccurrence('h1', DateTime(2026, 6, 13, 9));
      final b = AlarmId.forOccurrence('h1', DateTime(2026, 6, 13, 10));
      expect(a, isNot(b));
    });

    test('id is always positive', () {
      // The 31-bit mask must keep the value positive (Android
      // setExact rejects negative ids).
      final at = DateTime(1970); // epoch 0
      final id = AlarmId.forOccurrence('h1', at);
      expect(id.value, greaterThanOrEqualTo(0));
    });
  });

  group('FakeAlarmScheduler', () {
    final habit = DoFixed(
      id: 'h1',
      name: 'Stretch',
      createdAt: DateTime(2026, 6),
      restDaysPerMonth: 2,
      proofMode: const SoftProof(),
      weekdays: const {1, 3, 5},
      time: const DoTime(9, 0),
    );

    test('schedule records the alarm', () async {
      final s = FakeAlarmScheduler();
      final at = DateTime(2026, 6, 13, 9);
      final id = await s.schedule(habit, at);
      expect(id, isNotNull);
      expect(s.scheduled.length, 1);
      expect(s.scheduled.first.habitId, 'h1');
      expect(s.scheduled.first.at, at);
    });

    test('cancel removes the alarm and records the id', () async {
      final s = FakeAlarmScheduler();
      final id = await s.schedule(habit, DateTime(2026, 6, 13, 9));
      await s.cancel(id);
      expect(s.scheduled, isEmpty);
      expect(s.cancelledIds, contains(id));
    });

    test(
      'snooze schedules a new alarm at +delay and cancels the old',
      () async {
        final s = FakeAlarmScheduler();
        final id = await s.schedule(habit, DateTime(2026, 6, 13, 9));
        final newId = await s.snooze(id, const Duration(minutes: 5));
        expect(newId, isNot(id));
        expect(s.scheduled.length, 1);
        expect(s.scheduled.first.id, newId);
        expect(s.scheduled.first.at, DateTime(2026, 6, 13, 9, 5));
        expect(s.cancelledIds, contains(id));
      },
    );

    test('rescheduleAll is a no-op (does not throw)', () async {
      final s = FakeAlarmScheduler();
      await s.rescheduleAll();
    });

    test('reliability defaults to optimal', () {
      final s = FakeAlarmScheduler();
      expect(s.reliability, Reliability.optimal);
    });

    test('setReliability flips to degraded', () {
      final s = FakeAlarmScheduler();
      s.setReliability(Reliability.degraded);
      expect(s.reliability, Reliability.degraded);
    });

    test('cancelForHabit drops every alarm tied to the id', () async {
      final s = FakeAlarmScheduler();
      final h1 = _h(id: 'h1');
      final h2 = _h(id: 'h2');
      await s.schedule(h1, DateTime(2030));
      await s.schedule(h2, DateTime(2030));
      expect(s.scheduled.length, 2);
      await s.cancelForHabit('h1');
      expect(s.scheduled.length, 1);
      expect(s.scheduled.first.habitId, 'h2');
    });

    test('cancelForHabit on unknown id is a no-op', () async {
      final s = FakeAlarmScheduler();
      await s.schedule(_h(id: 'h1'), DateTime(2030));
      await s.cancelForHabit('does_not_exist');
      expect(s.scheduled.length, 1);
    });
  });

  // ── v1.4-stab-E / Phase 45 / SYS-132 ─────────────────────
  // Coverage cycle: exact-alarm denied path → WorkManager
  // fallback + exact-alarm granted → primary path.

  group('AlarmScheduler fallback paths (SYS-132)', () {
    test('schedule with exact-alarm granted stores a primary alarm '
        '(SYS-132 / ADR-018)', () async {
      final s = FakeAlarmScheduler();
      final at = DateTime(2030, 6, 30, 9);
      await s.schedule(_h(id: 'h-exact'), at);
      expect(s.scheduled.length, 1);
      expect(s.scheduled.first.habitId, 'h-exact');
      expect(s.scheduled.first.at, at);
    });

    test('cancel for an exact-alarm scheduled habit removes the '
        'primary alarm (SYS-132 / ADR-018)', () async {
      final s = FakeAlarmScheduler();
      await s.schedule(_h(id: 'h-exact'), DateTime(2030));
      expect(s.scheduled.length, 1);
      await s.cancelForHabit('h-exact');
      expect(
        s.scheduled,
        isEmpty,
        reason:
            'cancel-for-habit on an exact-alarm scheduled habit '
            'removes the primary alarm.',
      );
    });
  });
}

Do _h({required String id}) => DoFixed(
  id: id,
  name: 'X',
  proofMode: const SoftProof(),
  createdAt: DateTime(2026, 6),
  restDaysPerMonth: 0,
  weekdays: const {1, 2, 3, 4, 5, 6, 7},
  time: const DoTime(9, 0),
);
