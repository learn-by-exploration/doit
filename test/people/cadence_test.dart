// Tests for the PersonCadence sealed hierarchy.

import 'package:common_games/people/cadence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EveryNDays.nextOccurrence', () {
    test('nDays = 1 → from + 1 day (whole day)', () {
      const c = EveryNDays(1);
      final from = DateTime(2026, 6, 13, 10);
      expect(c.nextOccurrence(from), DateTime(2026, 6, 14));
    });

    test('nDays = 7 → from + 7 days', () {
      const c = EveryNDays(7);
      final from = DateTime(2026, 6, 13);
      expect(c.nextOccurrence(from), DateTime(2026, 6, 20));
    });

    test('nDays < 1 → null (invalid)', () {
      const c = EveryNDays(0);
      expect(c.nextOccurrence(DateTime(2026, 6, 13)), isNull);
    });
  });

  group('WeeklyOn.nextOccurrence', () {
    test('returns the next occurrence of the weekday strictly after from', () {
      // 2026-06-13 is a Saturday (weekday 6). Next Wednesday
      // is 2026-06-17.
      const c = WeeklyOn(3);
      final from = DateTime(2026, 6, 13);
      expect(c.nextOccurrence(from), DateTime(2026, 6, 17));
    });

    test('skips 7 days when from is the day before the weekday', () {
      // 2026-06-13 is Saturday. Next Saturday is 2026-06-20.
      const c = WeeklyOn(6);
      final from = DateTime(2026, 6, 13);
      expect(c.nextOccurrence(from), DateTime(2026, 6, 20));
    });

    test('invalid weekday returns null', () {
      const c = WeeklyOn(0);
      expect(c.nextOccurrence(DateTime(2026, 6, 13)), isNull);
      const c2 = WeeklyOn(8);
      expect(c2.nextOccurrence(DateTime(2026, 6, 13)), isNull);
    });
  });

  group('MonthlyOn.nextOccurrence', () {
    test('returns this month on the dayOfMonth when not yet passed', () {
      const c = MonthlyOn(15);
      final from = DateTime(2026, 6, 10);
      expect(c.nextOccurrence(from), DateTime(2026, 6, 15));
    });

    test('rolls to next month when dayOfMonth has passed', () {
      const c = MonthlyOn(5);
      final from = DateTime(2026, 6, 10);
      expect(c.nextOccurrence(from), DateTime(2026, 7, 5));
    });

    test('dayOfMonth = 31 rolls to last day of February (28 days)', () {
      const c = MonthlyOn(31);
      // From Jan 31 (after Jan's 31st-day match), the next
      // occurrence is Feb 28 (clamped from 31).
      final from = DateTime(2026, 1, 31);
      // 2026 is not a leap year.
      expect(c.nextOccurrence(from), DateTime(2026, 2, 28));
    });

    test('dayOfMonth = 31 in April (30 days) clamps to 30', () {
      const c = MonthlyOn(31);
      // From Mar 31 (after Mar's 31st-day match), the next
      // occurrence is Apr 30 (clamped from 31).
      final from = DateTime(2026, 3, 31);
      expect(c.nextOccurrence(from), DateTime(2026, 4, 30));
    });

    test('dayOfMonth = 29 in February on a leap year stays at 29', () {
      // 2024 is a leap year; from after Jan 29, the next
      // dom=29 is Feb 29 2024.
      const c = MonthlyOn(29);
      final from = DateTime(2024, 1, 30);
      expect(c.nextOccurrence(from), DateTime(2024, 2, 29));
    });

    test('invalid dayOfMonth returns null', () {
      const c = MonthlyOn(0);
      expect(c.nextOccurrence(DateTime(2026, 6, 13)), isNull);
      const c2 = MonthlyOn(32);
      expect(c2.nextOccurrence(DateTime(2026, 6, 13)), isNull);
    });
  });

  group('YearlyOn.nextOccurrence', () {
    test('returns this year on (month, day) when not yet passed', () {
      const c = YearlyOn(7, 4);
      final from = DateTime(2026);
      expect(c.nextOccurrence(from), DateTime(2026, 7, 4));
    });

    test('rolls to next year when the date has passed', () {
      const c = YearlyOn(3, 1);
      final from = DateTime(2026, 6, 13);
      expect(c.nextOccurrence(from), DateTime(2027, 3));
    });

    test('Feb 29 rolls to Feb 28 in non-leap year', () {
      // 2024 is a leap year; 2025 is not. From Jun 2024, the
      // next Feb occurrence is 2025-02-28 (non-leap clamp).
      // From Jan 2025, the next leap-year Feb 29 is 2028.
      const c = YearlyOn(2, 29);
      final from = DateTime(2023, 6);
      expect(c.nextOccurrence(from), DateTime(2024, 2, 29));
      final from2 = DateTime(2024, 6);
      expect(c.nextOccurrence(from2), DateTime(2025, 2, 28));
    });

    test('invalid month/day returns null', () {
      const c = YearlyOn(0, 1);
      expect(c.nextOccurrence(DateTime(2026, 6, 13)), isNull);
      const c2 = YearlyOn(13, 1);
      expect(c2.nextOccurrence(DateTime(2026, 6, 13)), isNull);
      const c3 = YearlyOn(1, 0);
      expect(c3.nextOccurrence(DateTime(2026, 6, 13)), isNull);
      const c4 = YearlyOn(1, 32);
      expect(c4.nextOccurrence(DateTime(2026, 6, 13)), isNull);
    });
  });
}
