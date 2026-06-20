// Tests for [Do.nextOccurrence] across the 4 schedule types.
//
// Schedule engine contract: same input → same output. No
// `DateTime.now()`. Reference times are explicit in every
// test. The tests use UTC offsets to keep dates stable across
// CI machines; `.toLocal()` happens inside the engine.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:flutter_test/flutter_test.dart';

DoFixed _fixed({
  Set<Weekday> weekdays = const {1, 3, 5}, // Mon, Wed, Fri
  DoTime time = const DoTime(9, 0),
}) {
  return DoFixed(
    id: 'h1',
    name: 'Drink water',
    proofMode: const SoftProof(),
    createdAt: DateTime(2026),
    restDaysPerMonth: 2,
    weekdays: weekdays,
    time: time,
  );
}

DoInterval _interval({int nDays = 3, DateTime? ref}) {
  return DoInterval(
    id: 'h1',
    name: 'Read',
    proofMode: const SoftProof(),
    createdAt: DateTime(2026),
    restDaysPerMonth: 2,
    nDays: nDays,
    referenceDate: ref ?? DateTime(2026, 6),
  );
}

DoAnchor _anchor({DateTime? lastAnchor}) {
  return DoAnchor(
    id: 'h1',
    name: 'Follow up',
    proofMode: const SoftProof(),
    createdAt: DateTime(2026),
    restDaysPerMonth: 2,
    targetDoId: 'h0',
    lastAnchor: lastAnchor,
  );
}

DoDayOfX _dayOfMonth({required int day}) {
  return DoDayOfX(
    id: 'h1',
    name: 'Pay rent',
    proofMode: const SoftProof(),
    createdAt: DateTime(2026),
    restDaysPerMonth: 2,
    dayOfMonth: day,
  );
}

DoDayOfX _nthWeekday({required int nth, required Weekday weekday}) {
  return DoDayOfX(
    id: 'h1',
    name: 'Family dinner',
    proofMode: const SoftProof(),
    createdAt: DateTime(2026),
    restDaysPerMonth: 2,
    nth: nth,
    weekday: weekday,
  );
}

void main() {
  group('DoFixed.nextOccurrence', () {
    test('returns the same day at the configured time if weekday matches '
        'and time is later in the day', () {
      // 2026-06-15 is a Monday (weekday 1).
      final h = _fixed();
      final from = DateTime(2026, 6, 15, 7);
      final next = h.nextOccurrence(from);
      expect(next, DateTime(2026, 6, 15, 9));
    });

    test('skips to the next matching weekday if the time has passed', () {
      // 2026-06-15 is a Monday. 10:00 is past the 09:00 time.
      final h = _fixed();
      final from = DateTime(2026, 6, 15, 10);
      final next = h.nextOccurrence(from);
      // Next is Wednesday 2026-06-17.
      expect(next, DateTime(2026, 6, 17, 9));
    });

    test('skips to the next matching weekday if today is not in the set', () {
      // 2026-06-16 is a Tuesday; the set is {Mon, Wed, Fri}.
      final h = _fixed();
      final from = DateTime(2026, 6, 16, 8);
      final next = h.nextOccurrence(from);
      expect(next, DateTime(2026, 6, 17, 9));
    });

    test('returns the same time on the next week when from is past the last '
        'matching weekday', () {
      // 2026-06-21 is a Sunday; set is {Mon, Wed, Fri}.
      final h = _fixed();
      final from = DateTime(2026, 6, 21, 23, 59);
      final next = h.nextOccurrence(from);
      expect(next, DateTime(2026, 6, 22, 9));
    });
  });

  group('DoInterval.nextOccurrence', () {
    test('returns the reference day if from is before it', () {
      final h = _interval(ref: DateTime(2026, 6, 10));
      final from = DateTime(2026, 6, 5);
      expect(h.nextOccurrence(from), DateTime(2026, 6, 10));
    });

    test('returns reference + nDays when from is on the reference day', () {
      final h = _interval(ref: DateTime(2026, 6, 10));
      final from = DateTime(2026, 6, 10, 8);
      expect(h.nextOccurrence(from), DateTime(2026, 6, 13));
    });

    test('walks forward in n-day steps to find the next strictly-after '
        'occurrence', () {
      final h = _interval(ref: DateTime(2026, 6));
      // 2026-06-01, 06-04, 06-07, 06-10.
      final from = DateTime(2026, 6, 5);
      expect(h.nextOccurrence(from), DateTime(2026, 6, 7));
    });

    test('handles from exactly on a tick (skips to next tick)', () {
      final h = _interval(ref: DateTime(2026, 6));
      final from = DateTime(2026, 6, 4, 12);
      // Strictly after 06-04 12:00, so the next is 06-07.
      expect(h.nextOccurrence(from), DateTime(2026, 6, 7));
    });
  });

  group('DoAnchor.nextOccurrence', () {
    test('returns the day after the last anchor', () {
      final h = _anchor(lastAnchor: DateTime(2026, 6, 10));
      final from = DateTime(2026, 6, 11, 8);
      expect(h.nextOccurrence(from), DateTime(2026, 6, 11));
    });

    test('returns from + 1 day when no last anchor is set', () {
      final h = _anchor();
      final from = DateTime(2026, 6, 10, 8);
      expect(h.nextOccurrence(from), DateTime(2026, 6, 11));
    });

    test('handles the case where the last anchor is in the past', () {
      final h = _anchor(lastAnchor: DateTime(2026, 5));
      final from = DateTime(2026, 6, 10, 8);
      // base is the anchor; tomorrow is 2026-05-02, which is
      // before from, so we fall back to from + 1 day.
      expect(h.nextOccurrence(from), DateTime(2026, 6, 11));
    });
  });

  group('DoDayOfX.nextOccurrence (dayOfMonth)', () {
    test('returns this month on dayOfMonth when the day has not passed', () {
      final h = _dayOfMonth(day: 15);
      final from = DateTime(2026, 6, 10);
      expect(h.nextOccurrence(from), DateTime(2026, 6, 15));
    });

    test('rolls to next month when dayOfMonth has passed', () {
      final h = _dayOfMonth(day: 5);
      final from = DateTime(2026, 6, 10);
      expect(h.nextOccurrence(from), DateTime(2026, 7, 5));
    });

    test('rolls to last day of month when dayOfMonth > days in month', () {
      // 2026-06 has 30 days; dom=31 clamps to 30.
      final h = _dayOfMonth(day: 31);
      // From May 31 (after May's 31st-day match), the next
      // occurrence is June 30 (clamped from 31).
      final from = DateTime(2026, 5, 31);
      final next = h.nextOccurrence(from);
      expect(next, DateTime(2026, 6, 30));
    });

    test('rolls Feb 31 to Feb 28 in non-leap year', () {
      final h = _dayOfMonth(day: 31);
      // From Jan 31, the next occurrence is Feb 28.
      final from = DateTime(2026, 1, 31);
      final next = h.nextOccurrence(from);
      // 2026 is not a leap year. Feb has 28 days.
      expect(next, DateTime(2026, 2, 28));
    });

    test('rolls Feb 29 to Feb 28 in non-leap year and Feb 29 in leap year', () {
      final h = _dayOfMonth(day: 29);
      // 2027 is not a leap year; 2028 is. From after Jan 29
      // 2027, the next dom=29 attempt is in Feb 2027 (clamped
      // to 28).
      final from = DateTime(2027, 1, 30);
      final next = h.nextOccurrence(from);
      expect(next, DateTime(2027, 2, 28));
    });
  });

  group('DoDayOfX.nextOccurrence (nth weekday)', () {
    test('returns the 2nd Tuesday of the month', () {
      // 2026-06-02 is a Tuesday. The 2nd Tuesday is 2026-06-09.
      final h = _nthWeekday(nth: 2, weekday: 2);
      final from = DateTime(2026, 5, 30);
      final next = h.nextOccurrence(from);
      expect(next, DateTime(2026, 6, 9));
    });

    test('skips to next month if the nth weekday does not exist', () {
      // 2026-06 has Fridays: 5, 12, 19, 26 — no 5th Friday.
      // From May 30 (after May's 5th Friday on the 29th),
      // the next 5th-Friday is July 31.
      final h = _nthWeekday(nth: 5, weekday: 5);
      final from = DateTime(2026, 5, 30);
      final next = h.nextOccurrence(from);
      // 2026-07: 3, 10, 17, 24, 31 — 5th Friday is 2026-07-31.
      expect(next, DateTime(2026, 7, 31));
    });
  });
}
