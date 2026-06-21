// Tests for the per-automation reliability derivation
// (v1.1f / SYS-085).
//
// Covers:
//   - Every Trigger leaf × each permission state (granted /
//     denied / permanentlyDenied / null).
//   - Each Action leaf is ignored (no runtime gate at v1.1f).
//   - Optimal / degraded / unknown mapping.
//
// The exhaustive switch in `_requiredPermissionForTrigger`
// (lib/routines/automation_reliability.dart) is the
// canonical reference for "which triggers gate a permission".
// Adding a new Trigger leaf without updating that switch is a
// compile-time error; these tests cover the runtime side.

import 'package:doit/routines/automation_reliability.dart';
import 'package:doit/routines/routine.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Trigger fixtures
// ---------------------------------------------------------------------------

const _locationTrigger = TriggerLocationEnter(
  geofenceId: 'g1',
  label: 'Home',
  latitude: 37.7749,
  longitude: -122.4194,
  radiusMeters: 100,
);

const _calendarTrigger = TriggerCalendarEventStart(
  calendarId: 'primary',
  eventTitle: 'Standup',
);

const _deviceStateTrigger = TriggerChargingStarted();

const _callIncomingTrigger = TriggerCallIncomingAny();

const _timeOfDayTrigger = TriggerTimeOfDay(hour: 9, minute: 0);

// ---------------------------------------------------------------------------
// Statuses fixtures
// ---------------------------------------------------------------------------

const _granted = PermissionResultGranted();
const _denied = PermissionResultDenied(canOpenSettings: true);
const _permanentlyDenied = PermissionResultPermanentlyDenied();

Map<PermissionKind, PermissionResult?> _statuses({
  PermissionResult? location = _granted,
  PermissionResult? calendar = _granted,
  PermissionResult? notifications = _granted,
  PermissionResult? contacts = _granted,
  PermissionResult? exactAlarm = _granted,
  PermissionResult? backupFolder = _granted,
  PermissionResult? batteryOptimization = _granted,
}) => {
  PermissionKind.notifications: notifications,
  PermissionKind.contacts: contacts,
  PermissionKind.exactAlarm: exactAlarm,
  PermissionKind.backupFolder: backupFolder,
  PermissionKind.batteryOptimization: batteryOptimization,
  PermissionKind.location: location,
  PermissionKind.calendar: calendar,
};

Automation _automation(Trigger trigger) => Automation(
  trigger: trigger,
  action: const ActionNotify(title: 't', body: 'b'),
);

void main() {
  group('TriggerLocationEnter', () {
    test('granted location → optimal', () {
      expect(
        automationReliability(
          _automation(_locationTrigger),
          statuses: _statuses(),
        ),
        AutomationReliability.optimal,
      );
    });

    test('denied location → degraded', () {
      expect(
        automationReliability(
          _automation(_locationTrigger),
          statuses: _statuses(location: _denied),
        ),
        AutomationReliability.degraded,
      );
    });

    test('permanentlyDenied location → degraded', () {
      expect(
        automationReliability(
          _automation(_locationTrigger),
          statuses: _statuses(location: _permanentlyDenied),
        ),
        AutomationReliability.degraded,
      );
    });

    test('null location (unprobed) → unknown', () {
      expect(
        automationReliability(
          _automation(_locationTrigger),
          statuses: _statuses(location: null),
        ),
        AutomationReliability.unknown,
      );
    });

    test('location denied but calendar granted → still degraded '
        '(only the relevant permission matters)', () {
      expect(
        automationReliability(
          _automation(_locationTrigger),
          statuses: _statuses(location: _denied),
        ),
        AutomationReliability.degraded,
      );
    });
  });

  group('TriggerLocationExit', () {
    const exitTrigger = TriggerLocationExit(
      geofenceId: 'g2',
      label: 'Office',
      latitude: 37.7849,
      longitude: -122.4094,
      radiusMeters: 200,
    );

    test('granted location → optimal', () {
      expect(
        automationReliability(_automation(exitTrigger), statuses: _statuses()),
        AutomationReliability.optimal,
      );
    });

    test('denied location → degraded', () {
      expect(
        automationReliability(
          _automation(exitTrigger),
          statuses: _statuses(location: _denied),
        ),
        AutomationReliability.degraded,
      );
    });
  });

  group('TriggerCalendarEvent*', () {
    test('granted calendar → optimal', () {
      expect(
        automationReliability(
          _automation(_calendarTrigger),
          statuses: _statuses(),
        ),
        AutomationReliability.optimal,
      );
    });

    test('denied calendar → degraded', () {
      expect(
        automationReliability(
          _automation(_calendarTrigger),
          statuses: _statuses(calendar: _denied),
        ),
        AutomationReliability.degraded,
      );
    });

    test('null calendar → unknown', () {
      expect(
        automationReliability(
          _automation(_calendarTrigger),
          statuses: _statuses(calendar: null),
        ),
        AutomationReliability.unknown,
      );
    });
  });

  group('TriggerDeviceState (no runtime gate)', () {
    test('any statuses → optimal', () {
      expect(
        automationReliability(
          _automation(_deviceStateTrigger),
          statuses: _statuses(location: _denied, calendar: _denied),
        ),
        AutomationReliability.optimal,
      );
    });

    test('all-null statuses → still optimal (no gate to probe)', () {
      expect(
        automationReliability(
          _automation(_deviceStateTrigger),
          statuses: const <PermissionKind, PermissionResult?>{},
        ),
        AutomationReliability.optimal,
      );
    });
  });

  group('TriggerCallIncoming (role, deferred to v1.2)', () {
    test('any statuses → optimal (no runtime gate at v1.1f)', () {
      expect(
        automationReliability(
          _automation(_callIncomingTrigger),
          statuses: _statuses(location: _denied, calendar: _denied),
        ),
        AutomationReliability.optimal,
      );
    });
  });

  group('TriggerTimeOfDay (alarm-system gate)', () {
    test('any statuses → optimal (pure function cannot see '
        'AlarmScheduler.reliability; badge falls back to banner)', () {
      expect(
        automationReliability(
          _automation(_timeOfDayTrigger),
          statuses: _statuses(),
        ),
        AutomationReliability.optimal,
      );
    });
  });

  group('Action-side checks (no runtime gate at v1.1f)', () {
    test('ActionNotify with denied location → still degraded '
        '(trigger-side check wins)', () {
      final a = Automation(
        trigger: _locationTrigger,
        action: const ActionNotify(title: 't', body: 'b'),
      );
      expect(
        automationReliability(a, statuses: _statuses(location: _denied)),
        AutomationReliability.degraded,
      );
    });

    test('ActionOpenApp with no trigger gate → optimal', () {
      final a = Automation(
        trigger: _timeOfDayTrigger,
        action: const ActionOpenApp(route: '/home'),
      );
      expect(
        automationReliability(a, statuses: _statuses()),
        AutomationReliability.optimal,
      );
    });
  });
}
