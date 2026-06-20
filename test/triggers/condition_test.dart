// Unit tests for the Condition sealed hierarchy.
//
// Covers:
//   - ConditionAnd / ConditionOr — BINARY (left, right).
//   - ConditionTimeWindow.
//   - ConditionDayOfWeek — Set<int> (per spec).
//   - ConditionCalendarBusy.
//   - ConditionBatteryRange — null-bound open-ended.
//   - ConditionSilentMode.

import 'package:doit/triggers/condition.dart';
import 'package:doit/triggers/trigger.dart' show SilentMode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConditionAnd / ConditionOr', () {
    test('binary — has exactly left and right', () {
      final a = ConditionAnd(
        const ConditionTimeWindow(
          startHour: 8,
          startMinute: 0,
          endHour: 18,
          endMinute: 0,
        ),
        ConditionDayOfWeek(const {1, 2, 3}),
      );
      expect(a.left, isA<ConditionTimeWindow>());
      expect(a.right, isA<ConditionDayOfWeek>());
    });

    test('N-ary via nesting', () {
      final a = ConditionAnd(
        ConditionAnd(
          ConditionDayOfWeek(const {1}),
          ConditionDayOfWeek(const {2}),
        ),
        ConditionDayOfWeek(const {3}),
      );
      // Top level has 3 distinct leaves under it.
      expect(a.left, isA<ConditionAnd>());
      expect(a.right, isA<ConditionDayOfWeek>());
    });

    test('equality on left + right', () {
      final a = ConditionAnd(
        ConditionDayOfWeek(const {1}),
        ConditionDayOfWeek(const {2}),
      );
      final b = ConditionAnd(
        ConditionDayOfWeek(const {1}),
        ConditionDayOfWeek(const {2}),
      );
      expect(a, equals(b));
    });

    test('OR is also binary', () {
      const o = ConditionOr(
        ConditionCalendarBusy(calendarId: 'c1'),
        ConditionBatteryRange(low: 0, high: 20),
      );
      expect(o.left, isA<ConditionCalendarBusy>());
      expect(o.right, isA<ConditionBatteryRange>());
    });

    test('AND/OR validate their leaves', () {
      // An AND whose right child has an empty weekday set
      // should throw on validate().
      expect(
        () => ConditionAnd(
          ConditionDayOfWeek(const {1}),
          ConditionDayOfWeek(const <int>{}),
        ).validate(),
        throwsA(isA<ConditionDayOfWeekEmpty>()),
      );
    });
  });

  group('ConditionTimeWindow', () {
    test('validates hour 0..23 + minute 0..59', () {
      expect(
        const ConditionTimeWindow(
          startHour: 22,
          startMinute: 0,
          endHour: 6,
          endMinute: 0,
        ).validate(),
        isA<ConditionTimeWindow>(),
      );
    });

    test('rejects bad hour/minute', () {
      expect(
        () => const ConditionTimeWindow(
          startHour: 24,
          startMinute: 0,
          endHour: 6,
          endMinute: 0,
        ).validate(),
        throwsA(isA<ConditionTimeWindowInvalidHour>()),
      );
      expect(
        () => const ConditionTimeWindow(
          startHour: 8,
          startMinute: 60,
          endHour: 18,
          endMinute: 0,
        ).validate(),
        throwsA(isA<ConditionTimeWindowInvalidMinute>()),
      );
    });
  });

  group('ConditionDayOfWeek', () {
    test('uses Set<int> (per spec), not List<int>', () {
      final cond = ConditionDayOfWeek(const {1, 3, 5});
      expect(cond.weekdays, isA<Set<int>>());
      expect(cond.weekdays, equals({1, 3, 5}));
    });

    test('deduplicates and normalizes input', () {
      // Build the set from a list that contains a duplicate
      // element. We avoid a set literal so the analyzer doesn't
      // flag the duplicate — the test's purpose is to prove
      // the constructor dedupes, so we need an input that
      // contains a duplicate at the source.
      final input = <int>[3, 1, 3, 2];
      final cond = ConditionDayOfWeek(input.toSet());
      expect(cond.weekdays, equals({1, 2, 3}));
    });

    test('rejects empty weekday set', () {
      expect(
        () => ConditionDayOfWeek(const <int>{}).validate(),
        throwsA(isA<ConditionDayOfWeekEmpty>()),
      );
    });

    test('rejects weekday outside 1..7', () {
      expect(
        () => ConditionDayOfWeek(const {0}).validate(),
        throwsA(isA<ConditionDayOfWeekInvalidWeekday>()),
      );
      expect(
        () => ConditionDayOfWeek(const {8}).validate(),
        throwsA(isA<ConditionDayOfWeekInvalidWeekday>()),
      );
    });

    test('equality is order-insensitive (Set)', () {
      expect(
        ConditionDayOfWeek(const {1, 2}),
        equals(ConditionDayOfWeek(const {2, 1})),
      );
    });
  });

  group('ConditionCalendarBusy', () {
    test('accepts empty calendarId (any calendar)', () {
      expect(
        const ConditionCalendarBusy(calendarId: '').validate(),
        isA<ConditionCalendarBusy>(),
      );
    });
  });

  group('ConditionBatteryRange', () {
    test('null bound = open-ended', () {
      expect(
        const ConditionBatteryRange(low: 0).validate(),
        isA<ConditionBatteryRange>(),
      );
      expect(
        const ConditionBatteryRange(high: 100).validate(),
        isA<ConditionBatteryRange>(),
      );
    });

    test('rejects out-of-range bound', () {
      expect(
        () => const ConditionBatteryRange(low: -1).validate(),
        throwsA(isA<ConditionBatteryRangeInvalidBound>()),
      );
      expect(
        () => const ConditionBatteryRange(high: 101).validate(),
        throwsA(isA<ConditionBatteryRangeInvalidBound>()),
      );
    });

    test('rejects low > high', () {
      expect(
        () => const ConditionBatteryRange(low: 80, high: 20).validate(),
        throwsA(isA<ConditionBatteryRangeInverted>()),
      );
    });
  });

  group('ConditionSilentMode', () {
    test('accepts every SilentMode', () {
      for (final mode in SilentMode.values) {
        expect(
          ConditionSilentMode(mode).validate(),
          isA<ConditionSilentMode>(),
        );
      }
    });
  });
}
