// Tests for the Habit model: validation, immutability, copyWith.

import 'package:doit/habits/habit.dart';
import 'package:doit/habits/proof_mode.dart';
import 'package:doit/missions/chain.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _createdAt() => DateTime(2026);

HabitFixed _fixed() {
  return HabitFixed(
    id: 'h1',
    name: 'Drink water',
    proofMode: const SoftProof(),
    createdAt: _createdAt(),
    restDaysPerMonth: 2,
    weekdays: const {1, 3, 5},
    time: const HabitTime(9, 0),
  );
}

HabitInterval _interval() {
  return HabitInterval(
    id: 'h1',
    name: 'Read',
    proofMode: const SoftProof(),
    createdAt: _createdAt(),
    restDaysPerMonth: 2,
    nDays: 3,
    referenceDate: DateTime(2026, 6),
  );
}

HabitAnchor _anchor() {
  return HabitAnchor(
    id: 'h1',
    name: 'Follow up',
    proofMode: const SoftProof(),
    createdAt: _createdAt(),
    restDaysPerMonth: 2,
    targetHabitId: 'h0',
    lastAnchor: null,
  );
}

HabitDayOfX _dayOfMonth({required int day}) {
  return HabitDayOfX(
    id: 'h1',
    name: 'Pay rent',
    proofMode: const SoftProof(),
    createdAt: _createdAt(),
    restDaysPerMonth: 2,
    dayOfMonth: day,
  );
}

StrongProof _strong() {
  return StrongProof(
    MissionChain.from(const [
      ShakeMission(
        id: 'm1',
        label: 'Shake 14',
        timeout: Duration(seconds: 30),
        targetCount: 14,
      ),
    ]),
  );
}

void main() {
  group('Habit.validate', () {
    test('a fresh Soft habit validates', () {
      expect(_fixed().validate, returnsNormally);
    });

    test('a fresh Interval habit validates', () {
      expect(_interval().validate, returnsNormally);
    });

    test('a fresh Anchor habit validates', () {
      expect(_anchor().validate, returnsNormally);
    });

    test('a fresh DayOfX habit validates', () {
      expect(_dayOfMonth(day: 15).validate, returnsNormally);
    });

    test('empty name throws HabitNameEmpty', () {
      final h = _fixed().copyWith(name: '   ');
      expect(h.validate, throwsA(isA<HabitNameEmpty>()));
    });

    test('invalid time throws HabitInvalidTime', () {
      final h = _fixed().copyWith(time: const HabitTime(25, 0));
      expect(h.validate, throwsA(isA<HabitInvalidTime>()));
    });

    test('negative restDaysPerMonth throws', () {
      final h = _fixed().copyWith(restDaysPerMonth: -1);
      expect(h.validate, throwsA(isA<HabitInvalidRestDays>()));
    });

    test('empty weekday set throws HabitNoWeekdaysSelected', () {
      final h = _fixed().copyWith(weekdays: <Weekday>{});
      expect(h.validate, throwsA(isA<HabitNoWeekdaysSelected>()));
    });

    test('weekday out of range throws HabitInvalidWeekday', () {
      final h = _fixed().copyWith(weekdays: <Weekday>{0, 1});
      expect(h.validate, throwsA(isA<HabitInvalidWeekday>()));
    });

    test('interval nDays < 1 throws HabitInvalidInterval', () {
      final h = _interval().copyWith(nDays: 0);
      expect(h.validate, throwsA(isA<HabitInvalidInterval>()));
    });

    test('anchor self-reference throws HabitAnchorSelfReference', () {
      final h = _anchor().copyWith(targetHabitId: 'h1');
      expect(h.validate, throwsA(isA<HabitAnchorSelfReference>()));
    });

    test('dayOfMonth out of range throws HabitInvalidDayOfMonth', () {
      final h = _dayOfMonth(day: 0);
      expect(h.validate, throwsA(isA<HabitInvalidDayOfMonth>()));
    });

    test('dayOfMonth = 32 throws HabitInvalidDayOfMonth', () {
      final h = _dayOfMonth(day: 32);
      expect(h.validate, throwsA(isA<HabitInvalidDayOfMonth>()));
    });

    test('strong proof with empty chain throws StrongChainInvalid', () {
      final h = _fixed().copyWith(proofMode: StrongProof(MissionChain.empty));
      expect(h.validate, throwsA(isA<StrongChainInvalid>()));
    });

    test(
      'strong proof with chain timeout > 5 min throws StrongChainInvalid',
      () {
        final h = _fixed().copyWith(
          proofMode: StrongProof(
            MissionChain.from(const [
              HoldMission(
                id: 'm1',
                label: 'Hold',
                timeout: Duration(minutes: 6),
                holdDuration: Duration(minutes: 6),
              ),
            ]),
          ),
        );
        expect(h.validate, throwsA(isA<StrongChainInvalid>()));
      },
    );

    test('Auto proof is rejected in v0.1', () {
      final h = _fixed().copyWith(proofMode: const AutoProof());
      expect(h.validate, throwsA(isA<AutoProofNotSupported>()));
    });
  });

  group('Habit.copyWith immutability', () {
    test(
      'copyWith on a Fixed habit returns a new instance with the change',
      () {
        final h = _fixed();
        final h2 = h.copyWith(name: 'Drink water (2)');
        expect(identical(h, h2), isFalse);
        expect(h.name, 'Drink water');
        expect(h2.name, 'Drink water (2)');
      },
    );

    test('missionChain on a Soft habit is empty', () {
      expect(_fixed().missionChain, MissionChain.empty);
    });

    test('missionChain on a Strong habit returns the proof chain', () {
      final h = _fixed().copyWith(proofMode: _strong());
      expect(h.missionChain.length, 1);
      expect(h.missionChain.first, isA<ShakeMission>());
    });
  });

  group('MemoryMission grid shape', () {
    test('rows*cols must be even', () {
      expect(
        () => MemoryMission(
          id: 'm1',
          label: 'Memory',
          timeout: const Duration(minutes: 2),
          rows: 3,
          cols: 3,
          theme: 'animals',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('even grid is allowed', () {
      const m = MemoryMission(
        id: 'm1',
        label: 'Memory',
        timeout: Duration(minutes: 2),
        rows: 2,
        cols: 4,
        theme: 'animals',
      );
      expect(m.rows * m.cols, 8);
    });
  });
}
