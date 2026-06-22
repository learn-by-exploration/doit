// Tests for `describeDo` (lib/do/do_description.dart) — the
// one-line label rendered under each habit name on the
// home-screen tile.
//
// v1.2f / Phase 6e / SYS-102: the prior version only rendered
// the time, dropping the weekday set on `DoFixed`. The new
// version renders the weekday set in shorthand before the
// time, so the user can see at a glance whether a habit is
// weekdays-only, weekends-only, every day, or some other
// subset.

import 'package:doit/do/do.dart';
import 'package:doit/do/do_description.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:flutter_test/flutter_test.dart';

DoFixed _fixed(Set<int> weekdays, [int hour = 6, int minute = 30]) {
  return DoFixed(
    id: 'h1',
    name: 'Stretch',
    proofMode: const SoftProof(),
    createdAt: DateTime(2026, 6),
    restDaysPerMonth: 2,
    weekdays: weekdays,
    time: DoTime(hour, minute),
  );
}

void main() {
  group('describeDo / DoFixed weekday set', () {
    test('every day renders "Every day · HH:MM"', () {
      expect(describeDo(_fixed({1, 2, 3, 4, 5, 6, 7})), 'Every day · 06:30');
    });

    test('weekdays only renders "Weekdays · HH:MM"', () {
      expect(describeDo(_fixed({1, 2, 3, 4, 5}, 9, 0)), 'Weekdays · 09:00');
    });

    test('weekends only renders "Weekends · HH:MM"', () {
      expect(describeDo(_fixed({6, 7}, 10, 0)), 'Weekends · 10:00');
    });

    test('single weekday renders the abbreviation alone', () {
      expect(describeDo(_fixed({1}, 7, 0)), 'Mon · 07:00');
      expect(describeDo(_fixed({7}, 21, 15)), 'Sun · 21:15');
    });

    test('arbitrary subset renders comma-separated ascending order', () {
      // Input set is unsorted; output must be Mon..Sun order
      // regardless of the caller's set literal.
      expect(describeDo(_fixed({5, 1, 3}, 18, 0)), 'Mon, Wed, Fri · 18:00');
    });

    test('Sunday-only Friday-only boundary cases', () {
      expect(describeDo(_fixed({5}, 5, 0)), 'Fri · 05:00');
      expect(describeDo(_fixed({6}, 5, 0)), 'Sat · 05:00');
    });
  });

  group('describeDo / non-DoFixed branches', () {
    test('DoInterval renders the nDays count', () {
      final h = DoInterval(
        id: 'h1',
        name: 'Run',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 6),
        restDaysPerMonth: 2,
        nDays: 3,
        referenceDate: DateTime(2026, 6),
      );
      expect(describeDo(h), 'Every 3 days');
    });

    test('DoAnchor renders "Anchor"', () {
      final h = DoAnchor(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 6),
        restDaysPerMonth: 2,
        targetDoId: 'h0',
        lastAnchor: null,
      );
      expect(describeDo(h), 'Anchor');
    });

    test('DoDayOfX renders "Day-of-X"', () {
      final h = DoDayOfX(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 6),
        restDaysPerMonth: 2,
        dayOfMonth: 15,
      );
      expect(describeDo(h), 'Day-of-X');
    });

    test('DoTimeWindow renders start–end', () {
      final h = DoTimeWindow(
        id: 'h1',
        name: 'Fasting',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 6),
        restDaysPerMonth: 0,
        weekdays: const {1, 2, 3, 4, 5},
        start: const DoTime(8, 0),
        end: const DoTime(20, 0),
      );
      expect(describeDo(h), 'Window — 08:00–20:00');
    });
  });
}
