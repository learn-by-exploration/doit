// Tests for [HabitRepository] — round-trips for all 4 schedule
// types and proof modes, dedupe-by-name, mission-chain JSON.

import 'package:doit/habits/habit.dart';
import 'package:doit/habits/proof_mode.dart';
import 'package:doit/missions/chain.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/habit_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _init() async {
  await AppDatabaseService.instance.closeForTesting();
  await AppDatabaseService.instance.init(
    overrideDb: AppDatabase(NativeDatabase.memory()),
  );
  await AppDatabaseService.instance.ready;
}

Future<void> _tearDown() => AppDatabaseService.instance.closeForTesting();

void main() {
  setUp(_init);
  tearDown(_tearDown);

  group('HabitRepository', () {
    test('round-trips a HabitFixed', () async {
      final h = HabitFixed(
        id: 'h1',
        name: 'Drink water',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026),
        restDaysPerMonth: 2,
        weekdays: const {1, 3, 5},
        time: const HabitTime(9, 0),
      );
      await HabitRepository.instance.save(h);
      final back = await HabitRepository.instance.getById('h1');
      expect(back, isA<HabitFixed>());
      final fixed = back! as HabitFixed;
      expect(fixed.weekdays, {1, 3, 5});
      expect(fixed.time.hour, 9);
      expect(fixed.time.minute, 0);
      expect(fixed.proofMode, isA<SoftProof>());
    });

    test('round-trips a HabitInterval', () async {
      final h = HabitInterval(
        id: 'h2',
        name: 'Read',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026),
        restDaysPerMonth: 2,
        nDays: 3,
        referenceDate: DateTime(2026, 6),
      );
      await HabitRepository.instance.save(h);
      final back = await HabitRepository.instance.getById('h2');
      expect(back, isA<HabitInterval>());
      final iv = back! as HabitInterval;
      expect(iv.nDays, 3);
      expect(iv.referenceDate, DateTime(2026, 6));
    });

    test('round-trips a HabitAnchor (lastAnchor null and set)', () async {
      final h1 = HabitAnchor(
        id: 'h3',
        name: 'Follow up',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026),
        restDaysPerMonth: 2,
        targetHabitId: 'h0',
        lastAnchor: null,
      );
      await HabitRepository.instance.save(h1);
      final back1 = await HabitRepository.instance.getById('h3') as HabitAnchor;
      expect(back1.lastAnchor, isNull);

      final h2 = back1.copyWith(lastAnchor: DateTime(2026, 6, 10));
      await HabitRepository.instance.save(h2);
      final back2 = await HabitRepository.instance.getById('h3') as HabitAnchor;
      expect(back2.lastAnchor, DateTime(2026, 6, 10));
    });

    test('round-trips a HabitDayOfX (dayOfMonth)', () async {
      final h = HabitDayOfX(
        id: 'h4',
        name: 'Pay rent',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026),
        restDaysPerMonth: 2,
        dayOfMonth: 15,
      );
      await HabitRepository.instance.save(h);
      final back = await HabitRepository.instance.getById('h4') as HabitDayOfX;
      expect(back.dayOfMonth, 15);
      expect(back.nth, isNull);
    });

    test('round-trips a HabitDayOfX (nth + weekday)', () async {
      final h = HabitDayOfX(
        id: 'h5',
        name: 'Family dinner',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026),
        restDaysPerMonth: 2,
        nth: 2,
        weekday: 2,
      );
      await HabitRepository.instance.save(h);
      final back = await HabitRepository.instance.getById('h5') as HabitDayOfX;
      expect(back.nth, 2);
      expect(back.weekday, 2);
      expect(back.dayOfMonth, isNull);
    });

    test('round-trips a Strong habit with a multi-mission chain', () async {
      final chain = MissionChain.from(const [
        ShakeMission(
          id: 'm1',
          label: 'Shake',
          timeout: Duration(seconds: 30),
          targetCount: 14,
        ),
        TypeMission(
          id: 'm2',
          label: 'Type',
          timeout: Duration(seconds: 60),
          expectedPhrase: 'I did the thing',
        ),
      ]);
      final h = HabitFixed(
        id: 'h6',
        name: 'Wake up',
        proofMode: StrongProof(chain),
        createdAt: DateTime(2026),
        restDaysPerMonth: 0,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const HabitTime(7, 0),
      );
      await HabitRepository.instance.save(h);
      final back = await HabitRepository.instance.getById('h6');
      expect(back, isA<HabitFixed>());
      final fixed = back! as HabitFixed;
      final pm = fixed.proofMode;
      expect(pm, isA<StrongProof>());
      final strong = pm as StrongProof;
      expect(strong.chain.length, 2);
      expect(strong.chain[0], isA<ShakeMission>());
      expect(strong.chain[1], isA<TypeMission>());
      expect(
        (strong.chain[1] as TypeMission).expectedPhrase,
        'I did the thing',
      );
    });

    test('listAll returns habits in createdAt order', () async {
      await HabitRepository.instance.save(
        HabitFixed(
          id: 'h1',
          name: 'A',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026),
          restDaysPerMonth: 2,
          weekdays: const {1},
          time: const HabitTime(8, 0),
        ),
      );
      await HabitRepository.instance.save(
        HabitFixed(
          id: 'h2',
          name: 'B',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026, 2),
          restDaysPerMonth: 2,
          weekdays: const {2},
          time: const HabitTime(8, 0),
        ),
      );
      final list = await HabitRepository.instance.listAll();
      expect(list.map((h) => h.id), ['h1', 'h2']);
    });

    test('duplicate name (case + trim insensitive) is rejected', () async {
      await HabitRepository.instance.save(
        HabitFixed(
          id: 'h1',
          name: 'Drink water',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026),
          restDaysPerMonth: 2,
          weekdays: const {1},
          time: const HabitTime(8, 0),
        ),
      );
      expect(
        () => HabitRepository.instance.save(
          HabitFixed(
            id: 'h2',
            name: '  drink WATER  ',
            proofMode: const SoftProof(),
            createdAt: DateTime(2026),
            restDaysPerMonth: 2,
            weekdays: const {2},
            time: const HabitTime(9, 0),
          ),
        ),
        throwsA(isA<DuplicateHabitName>()),
      );
    });

    test('same name on update is allowed (no self-duplicate)', () async {
      final h1 = HabitFixed(
        id: 'h1',
        name: 'Drink water',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026),
        restDaysPerMonth: 2,
        weekdays: const {1},
        time: const HabitTime(8, 0),
      );
      await HabitRepository.instance.save(h1);
      // Saving again with the same id + same name is a no-op
      // (the dedupe check is `existing.id != habit.id`).
      final h2 = h1.copyWith(time: const HabitTime(9, 0));
      await HabitRepository.instance.save(h2);
      final back = await HabitRepository.instance.getById('h1') as HabitFixed;
      expect(back.time.hour, 9);
    });

    test('deleteById removes the row', () async {
      await HabitRepository.instance.save(
        HabitFixed(
          id: 'h1',
          name: 'X',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026),
          restDaysPerMonth: 2,
          weekdays: const {1},
          time: const HabitTime(8, 0),
        ),
      );
      await HabitRepository.instance.deleteById('h1');
      final back = await HabitRepository.instance.getById('h1');
      expect(back, isNull);
    });

    test('invalid habit (empty name) throws HabitNameEmpty', () async {
      final h = HabitFixed(
        id: 'h1',
        name: '   ',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026),
        restDaysPerMonth: 2,
        weekdays: const {1},
        time: const HabitTime(8, 0),
      );
      expect(
        () => HabitRepository.instance.save(h),
        throwsA(isA<HabitNameEmpty>()),
      );
    });
  });
}
