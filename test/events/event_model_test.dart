// Tests for the Event model (WF-017).

import 'package:doit/events/event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Event.validate', () {
    test('accepts a valid event', () {
      const e = Event(
        id: 'e1',
        name: 'Doctor appointment',
        atMillis: 1735689600000, // 2025-01-01T00:00:00Z
        leadTimeMillis: 900000, // 15 min
        createdAtMillis: 1735600000000,
      );
      expect(() => e.validate(), returnsNormally);
    });

    test('rejects empty name', () {
      const e = Event(
        id: 'e1',
        name: '   ',
        atMillis: 1735689600000,
        leadTimeMillis: 0,
        createdAtMillis: 0,
      );
      expect(() => e.validate(), throwsA(isA<EventNameEmpty>()));
    });

    test('rejects non-positive atMillis', () {
      const e = Event(
        id: 'e1',
        name: 'X',
        atMillis: 0,
        leadTimeMillis: 0,
        createdAtMillis: 0,
      );
      expect(() => e.validate(), throwsA(isA<EventInvalidAtMillis>()));
    });

    test('rejects negative lead time', () {
      const e = Event(
        id: 'e1',
        name: 'X',
        atMillis: 1735689600000,
        leadTimeMillis: -1,
        createdAtMillis: 0,
      );
      expect(() => e.validate(), throwsA(isA<EventInvalidLeadTime>()));
    });
  });

  group('Event.nextOccurrence', () {
    test('none: returns atMillis if after from', () {
      final e = Event(
        id: 'e1',
        name: 'X',
        atMillis: DateTime(2026, 6, 15).millisecondsSinceEpoch,
        leadTimeMillis: 0,
        createdAtMillis: 0,
      );
      final next = e.nextOccurrence(DateTime(2026, 6));
      expect(next, DateTime(2026, 6, 15));
    });

    test('none: returns null if atMillis is in the past', () {
      final e = Event(
        id: 'e1',
        name: 'X',
        atMillis: DateTime(2026, 6).millisecondsSinceEpoch,
        leadTimeMillis: 0,
        createdAtMillis: 0,
      );
      final next = e.nextOccurrence(DateTime(2026, 6, 15));
      expect(next, isNull);
    });

    test(
      'annually: returns next-year occurrence when this year has passed',
      () {
        final e = Event(
          id: 'e1',
          name: 'Birthday',
          atMillis: DateTime(2025, 3, 15).millisecondsSinceEpoch,
          leadTimeMillis: 0,
          createdAtMillis: 0,
          recurrence: EventRecurrence.annually,
        );
        // From after the birthday in 2025: next is 2026-03-15.
        final next = e.nextOccurrence(DateTime(2025, 4));
        expect(next, DateTime(2026, 3, 15));
      },
    );

    test('annually: returns this-year occurrence when not yet passed', () {
      final e = Event(
        id: 'e1',
        name: 'Birthday',
        atMillis: DateTime(2025, 3, 15).millisecondsSinceEpoch,
        leadTimeMillis: 0,
        createdAtMillis: 0,
        recurrence: EventRecurrence.annually,
      );
      final next = e.nextOccurrence(DateTime(2026));
      expect(next, DateTime(2026, 3, 15));
    });
  });

  group('Event.copyWith', () {
    test('copies with new fields', () {
      const e = Event(
        id: 'e1',
        name: 'X',
        atMillis: 1735689600000,
        leadTimeMillis: 0,
        createdAtMillis: 0,
      );
      final e2 = e.copyWith(name: 'Y', leadTimeMillis: 60000);
      expect(e2.name, 'Y');
      expect(e2.leadTimeMillis, 60000);
      expect(e2.id, 'e1');
      expect(e2.atMillis, 1735689600000);
    });
  });
}
