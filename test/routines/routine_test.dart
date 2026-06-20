// Unit tests for the Automation aggregate and per-shape
// toJson / fromJson (no central envelope codec per spec).

import 'package:doit/routines/routine.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/condition.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(resetAutomationIdCounterForTesting);

  Automation sampleAutomation({Condition? condition, bool enabled = true}) {
    return Automation(
      trigger: const TriggerTimeOfDay(hour: 8, minute: 30),
      condition: condition,
      action: const ActionNotify(title: 'Wake', body: 'Morning!'),
      enabled: enabled,
    );
  }

  group('Automation construction', () {
    test('auto-mints a stable id when not provided', () {
      final a1 = sampleAutomation();
      final a2 = sampleAutomation();
      expect(a1.id, isNot(a2.id));
      expect(a1.id, startsWith('auto_'));
    });

    test('respects caller-provided id', () {
      final a = Automation(
        id: 'mine',
        trigger: const TriggerTimeOfDay(hour: 8, minute: 30),
        action: const ActionNotify(title: 'Wake', body: 'Morning!'),
      );
      expect(a.id, 'mine');
    });

    test('enabled defaults to true', () {
      expect(sampleAutomation().enabled, isTrue);
    });

    test('equality is by full payload', () {
      final a = sampleAutomation();
      final b = Automation(
        id: a.id,
        trigger: a.trigger,
        condition: a.condition,
        action: a.action,
        enabled: a.enabled,
      );
      expect(a, equals(b));
    });

    test('validate() walks trigger → condition → action', () {
      // Happy path
      expect(sampleAutomation().validate(), isA<Automation>());
      // Bad action (empty body) → throws
      expect(
        () => Automation(
          trigger: const TriggerTimeOfDay(hour: 8, minute: 30),
          action: const ActionNotify(title: 'x', body: ''),
        ).validate(),
        throwsA(isA<ActionNotifyEmptyBody>()),
      );
    });
  });

  group('Per-shape toJson / fromJson round-trip', () {
    test('TimeOfDay trigger', () {
      const t = TriggerTimeOfDay(hour: 8, minute: 30);
      final j = triggerToJson(t);
      expect(j['type'], 'timeOfDay');
      expect(triggerFromJson(j), equals(t));
    });

    test('LocationEnter and LocationExit', () {
      const enter = TriggerLocationEnter(
        geofenceId: 'g1',
        label: 'Home',
        latitude: 1,
        longitude: 2,
        radiusMeters: 100,
      );
      const exit = TriggerLocationExit(
        geofenceId: 'g1',
        label: 'Home',
        latitude: 1,
        longitude: 2,
        radiusMeters: 100,
      );
      expect(triggerFromJson(triggerToJson(enter)), equals(enter));
      expect(triggerFromJson(triggerToJson(exit)), equals(exit));
    });

    test('BatteryLow with percent', () {
      const t = TriggerBatteryLow(15);
      expect(triggerFromJson(triggerToJson(t)), equals(t));
    });

    test('Parameterless device-state leaves', () {
      for (final t in <TriggerDeviceState>[
        const TriggerBatteryFull(),
        const TriggerChargingStarted(),
        const TriggerChargingStopped(),
        const TriggerHeadphoneConnected(),
        const TriggerHeadphoneDisconnected(),
        const TriggerScreenOn(),
        const TriggerScreenOff(),
      ]) {
        expect(triggerFromJson(triggerToJson(t)), equals(t));
      }
    });

    test('Calendar event leaves', () {
      for (final t in <TriggerCalendarEvent>[
        const TriggerCalendarEventStart(
          calendarId: 'c1',
          eventTitle: 'Standup',
        ),
        const TriggerCalendarEventEnd(calendarId: 'c1', eventTitle: 'Standup'),
        const TriggerCalendarReminder(calendarId: 'c1', eventTitle: 'Standup'),
        const TriggerFreeBusy(calendarId: 'c1', eventTitle: 'Standup'),
      ]) {
        expect(triggerFromJson(triggerToJson(t)), equals(t));
      }
    });

    test('Call-incoming leaves', () {
      for (final t in <TriggerCallIncoming>[
        const TriggerCallIncomingAny(),
        const TriggerCallIncomingKnownContact(),
        const TriggerCallIncomingUnknownContact(),
      ]) {
        expect(triggerFromJson(triggerToJson(t)), equals(t));
      }
    });

    test('Condition And/Or are binary', () {
      final c = ConditionAnd(
        ConditionDayOfWeek(const {1, 2}),
        const ConditionOr(
          ConditionCalendarBusy(calendarId: 'c1'),
          ConditionBatteryRange(low: 0, high: 20),
        ),
      );
      expect(conditionFromJson(conditionToJson(c)), equals(c));
    });

    test('ConditionTimeWindow', () {
      const c = ConditionTimeWindow(
        startHour: 8,
        startMinute: 0,
        endHour: 18,
        endMinute: 0,
      );
      expect(conditionFromJson(conditionToJson(c)), equals(c));
    });

    test('ConditionDayOfWeek Set round-trip', () {
      final c = ConditionDayOfWeek(const {1, 3, 5});
      final back = conditionFromJson(conditionToJson(c));
      expect(back, isA<ConditionDayOfWeek>());
      expect((back as ConditionDayOfWeek).weekdays, equals({1, 3, 5}));
    });

    test('ConditionBatteryRange with null bounds', () {
      const c = ConditionBatteryRange();
      expect(conditionFromJson(conditionToJson(c)), equals(c));
    });

    test('ConditionSilentMode', () {
      const c = ConditionSilentMode(SilentMode.vibrate);
      expect(conditionFromJson(conditionToJson(c)), equals(c));
    });

    test('All Action leaves round-trip', () {
      const actions = <Action>[
        ActionNotify(title: 't', body: 'b'),
        ActionFullscreen(),
        ActionCallIntercept(decision: CallInterceptDecision.mute),
        ActionOverrideSilent(targetMode: SilentMode.silent),
        ActionOpenApp(route: 'do/abc'),
      ];
      for (final a in actions) {
        expect(actionFromJson(actionToJson(a)), equals(a));
      }
    });
  });

  group('Automation.toJson / fromJson round-trip', () {
    test('round-trips with no condition', () {
      final a = sampleAutomation();
      final j = a.toJson();
      expect(j['id'], a.id);
      expect(j['enabled'], isTrue);
      expect(j['condition'], isNull);
      expect(Automation.fromJson(j), equals(a));
    });

    test('round-trips with a binary AND condition', () {
      final a = sampleAutomation(
        condition: ConditionAnd(
          ConditionDayOfWeek(const {1, 2}),
          const ConditionBatteryRange(low: 0, high: 30),
        ),
      );
      expect(Automation.fromJson(a.toJson()), equals(a));
    });

    test('round-trips with enabled=false', () {
      final a = sampleAutomation(enabled: false);
      expect(Automation.fromJson(a.toJson()).enabled, isFalse);
    });
  });

  group('List-level codec', () {
    test('encodes and decodes a list', () {
      final list = <Automation>[
        sampleAutomation(),
        sampleAutomation(condition: ConditionDayOfWeek(const {6, 7})),
      ];
      final raw = encodeAutomationList(list);
      final back = decodeAutomationList(raw);
      expect(back, equals(list));
    });

    test('null/empty decodes to empty list', () {
      expect(decodeAutomationList(null), isEmpty);
      expect(decodeAutomationList(''), isEmpty);
    });

    test('malformed JSON throws FormatException', () {
      expect(
        () => decodeAutomationList('not json'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
