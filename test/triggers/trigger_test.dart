// Unit tests for the Trigger sealed hierarchy.
//
// Covers the six top-level kinds and their inner leaves:
//   - TriggerTimeOfDay
//   - TriggerLocationEnter / TriggerLocationExit
//   - TriggerDeviceState (7 leaves)
//   - TriggerCalendarEvent (4 leaves)
//   - TriggerCallIncoming (3 leaves)
// Plus the SilentMode enum.

import 'package:doit/triggers/trigger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TriggerTimeOfDay', () {
    test('validates hour 0..23 and minute 0..59', () {
      expect(const TriggerTimeOfDay(hour: 0, minute: 0).validate().hour, 0);
      expect(
        const TriggerTimeOfDay(hour: 23, minute: 59).validate().minute,
        59,
      );
    });

    test('rejects out-of-range hour and minute', () {
      expect(
        () => const TriggerTimeOfDay(hour: 24, minute: 0).validate(),
        throwsA(isA<TriggerTimeOfDayInvalidHour>()),
      );
      expect(
        () => const TriggerTimeOfDay(hour: -1, minute: 0).validate(),
        throwsA(isA<TriggerTimeOfDayInvalidHour>()),
      );
      expect(
        () => const TriggerTimeOfDay(hour: 0, minute: 60).validate(),
        throwsA(isA<TriggerTimeOfDayInvalidMinute>()),
      );
      expect(
        () => const TriggerTimeOfDay(hour: 0, minute: -1).validate(),
        throwsA(isA<TriggerTimeOfDayInvalidMinute>()),
      );
    });

    test('equality is by hour + minute', () {
      expect(
        const TriggerTimeOfDay(hour: 8, minute: 30),
        equals(const TriggerTimeOfDay(hour: 8, minute: 30)),
      );
      expect(
        const TriggerTimeOfDay(hour: 8, minute: 30),
        isNot(equals(const TriggerTimeOfDay(hour: 8, minute: 31))),
      );
    });
  });

  group('TriggerLocationEnter / Exit', () {
    TriggerLocationEnter makeEnter() => const TriggerLocationEnter(
      geofenceId: 'g1',
      label: 'Home',
      latitude: 12.34,
      longitude: 56.78,
      radiusMeters: 100,
    );

    test('validates geofenceId + label + lat/lng + radius', () {
      expect(makeEnter().validate(), isA<TriggerLocationEnter>());
      expect(
        const TriggerLocationExit(
          geofenceId: 'g1',
          label: 'Home',
          latitude: 0,
          longitude: 0,
          radiusMeters: 50,
        ).validate(),
        isA<TriggerLocationExit>(),
      );
    });

    test('rejects empty id, empty label, bad lat/lng/radius', () {
      expect(
        () => const TriggerLocationEnter(
          geofenceId: '',
          label: 'Home',
          latitude: 0,
          longitude: 0,
          radiusMeters: 100,
        ).validate(),
        throwsA(isA<TriggerLocationEmptyId>()),
      );
      expect(
        () => const TriggerLocationEnter(
          geofenceId: 'g1',
          label: '  ',
          latitude: 0,
          longitude: 0,
          radiusMeters: 100,
        ).validate(),
        throwsA(isA<TriggerLocationEmptyLabel>()),
      );
      expect(
        () => const TriggerLocationEnter(
          geofenceId: 'g1',
          label: 'Home',
          latitude: 91,
          longitude: 0,
          radiusMeters: 100,
        ).validate(),
        throwsA(isA<TriggerLocationInvalidLatitude>()),
      );
      expect(
        () => const TriggerLocationEnter(
          geofenceId: 'g1',
          label: 'Home',
          latitude: 0,
          longitude: 181,
          radiusMeters: 100,
        ).validate(),
        throwsA(isA<TriggerLocationInvalidLongitude>()),
      );
      expect(
        () => const TriggerLocationEnter(
          geofenceId: 'g1',
          label: 'Home',
          latitude: 0,
          longitude: 0,
          radiusMeters: 49,
        ).validate(),
        throwsA(isA<TriggerLocationInvalidRadius>()),
      );
      expect(
        () => const TriggerLocationEnter(
          geofenceId: 'g1',
          label: 'Home',
          latitude: 0,
          longitude: 0,
          radiusMeters: 5001,
        ).validate(),
        throwsA(isA<TriggerLocationInvalidRadius>()),
      );
    });

    test('equality is by full payload', () {
      expect(makeEnter(), equals(makeEnter()));
      expect(
        makeEnter(),
        isNot(
          equals(
            const TriggerLocationEnter(
              geofenceId: 'g1',
              label: 'Work',
              latitude: 12.34,
              longitude: 56.78,
              radiusMeters: 100,
            ),
          ),
        ),
      );
    });
  });

  group('TriggerDeviceState', () {
    test('all 8 leaves validate', () {
      const leaves = <TriggerDeviceState>[
        TriggerBatteryLow(50),
        TriggerBatteryFull(),
        TriggerChargingStarted(),
        TriggerChargingStopped(),
        TriggerHeadphoneConnected(),
        TriggerHeadphoneDisconnected(),
        TriggerScreenOn(),
        TriggerScreenOff(),
      ];
      for (final l in leaves) {
        expect(l.validate(), same(l));
      }
    });

    test('battery percent 0..100 only', () {
      expect(
        () => const TriggerBatteryLow(-1).validate(),
        throwsA(isA<TriggerBatteryInvalidPercent>()),
      );
      expect(
        () => const TriggerBatteryLow(101).validate(),
        throwsA(isA<TriggerBatteryInvalidPercent>()),
      );
      expect(const TriggerBatteryLow(0).validate().percent, 0);
      expect(const TriggerBatteryLow(100).validate().percent, 100);
    });
  });

  group('TriggerCalendarEvent', () {
    test('all 4 leaves validate', () {
      const leaves = <TriggerCalendarEvent>[
        TriggerCalendarEventStart(calendarId: 'c1', eventTitle: 'Standup'),
        TriggerCalendarEventEnd(calendarId: 'c1', eventTitle: 'Standup'),
        TriggerCalendarReminder(calendarId: 'c1', eventTitle: 'Standup'),
        TriggerFreeBusy(calendarId: 'c1', eventTitle: 'Standup'),
      ];
      for (final l in leaves) {
        expect(l.validate(), same(l));
      }
    });

    // Empty `calendarId` is a valid sentinel — the executor's
    // `_calendarMatches` predicate treats it as "match any
    // calendar". Phase E may tighten this when the picker
    // lands and calendar accounts are picked explicitly.
  });

  group('TriggerCallIncoming', () {
    test('all 3 leaves validate', () {
      const leaves = <TriggerCallIncoming>[
        TriggerCallIncomingAny(),
        TriggerCallIncomingKnownContact(),
        TriggerCallIncomingUnknownContact(),
      ];
      for (final l in leaves) {
        expect(l.validate(), same(l));
      }
    });
  });

  group('SilentMode', () {
    test('has 3 values', () {
      expect(SilentMode.values.length, 3);
      expect(SilentMode.values, contains(SilentMode.silent));
      expect(SilentMode.values, contains(SilentMode.vibrate));
      expect(SilentMode.values, contains(SilentMode.normal));
    });
  });
}
