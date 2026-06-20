// Unit tests for the RoutineExecutor skeleton.

import 'package:doit/routines/routine.dart';
import 'package:doit/routines/routine_executor.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/condition.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RoutineExecutor executor;

  setUp(() async {
    executor = RoutineExecutor.instance;
    executor.resetForTesting();
    await executor.init();
    resetAutomationIdCounterForTesting();
  });

  Automation sampleAutomation({Condition? condition, bool enabled = true}) {
    return Automation(
      trigger: const TriggerTimeOfDay(hour: 8, minute: 30),
      condition: condition,
      action: const ActionNotify(title: 'Wake', body: 'Morning!'),
      enabled: enabled,
    );
  }

  group('register / unregister / registeredFor', () {
    test('register stores automations for an entity', () {
      final a = sampleAutomation();
      executor.register('do-1', [a]);
      expect(executor.registeredFor('do-1'), equals([a]));
    });

    test('register replaces prior registration for same id', () {
      final a1 = sampleAutomation();
      final a2 = sampleAutomation();
      executor.register('do-1', [a1]);
      executor.register('do-1', [a2]);
      expect(executor.registeredFor('do-1'), equals([a2]));
    });

    test('unregister removes the entry', () {
      executor.register('do-1', [sampleAutomation()]);
      executor.unregister('do-1');
      expect(executor.registeredFor('do-1'), isNull);
    });

    test('registeredFor returns null for unknown entity', () {
      expect(executor.registeredFor('nope'), isNull);
    });

    test('registeredFor returns an unmodifiable view', () {
      executor.register('do-1', [sampleAutomation()]);
      final list = executor.registeredFor('do-1')!;
      expect(() => list.add(sampleAutomation()), throwsUnsupportedError);
    });

    test('registeredEntityIds lists every registered entity', () {
      executor.register('a', [sampleAutomation()]);
      executor.register('b', [sampleAutomation()]);
      expect(executor.registeredEntityIds, equals({'a', 'b'}));
    });
  });

  group('shouldFire (test-only pure predicate)', () {
    test('enabled + valid → true', () {
      expect(
        executor.shouldFire(sampleAutomation(), DateTime(2026, 6, 19)),
        isTrue,
      );
    });

    test('disabled → false', () {
      expect(
        executor.shouldFire(sampleAutomation(enabled: false), DateTime(2026)),
        isFalse,
      );
    });

    test('invalid trigger → throws', () {
      final bad = Automation(
        trigger: const TriggerBatteryLow(150),
        action: const ActionNotify(title: 'x', body: 'y'),
      );
      expect(
        () => executor.shouldFire(bad, DateTime(2026)),
        throwsA(isA<TriggerBatteryInvalidPercent>()),
      );
    });

    test('invalid action → throws', () {
      final bad = Automation(
        trigger: const TriggerTimeOfDay(hour: 8, minute: 0),
        action: const ActionNotify(title: '', body: 'y'),
      );
      expect(
        () => executor.shouldFire(bad, DateTime(2026)),
        throwsA(isA<ActionNotifyEmptyTitle>()),
      );
    });

    test('invalid condition → throws', () {
      final bad = Automation(
        trigger: const TriggerTimeOfDay(hour: 8, minute: 0),
        condition: ConditionDayOfWeek(const <int>{}),
        action: const ActionNotify(title: 'x', body: 'y'),
      );
      expect(
        () => executor.shouldFire(bad, DateTime(2026)),
        throwsA(isA<ConditionDayOfWeekEmpty>()),
      );
    });
  });

  group('dispatch (test-only)', () {
    test('emits AutomationFired for an enabled automation', () async {
      final a = sampleAutomation();
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);
      final now = DateTime(2026, 6, 19, 8, 30);
      executor.dispatch(a, entityId: 'do-1', now: now);
      // Yield once so the broadcast event lands.
      await Future<void>.delayed(Duration.zero);
      expect(fired.length, 1);
      expect(fired.first.automation, equals(a));
      expect(fired.first.at, now);
      await sub.cancel();
    });

    test('does NOT emit when disabled', () async {
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);
      executor.dispatch(
        sampleAutomation(enabled: false),
        entityId: 'do-1',
        now: DateTime(2026),
      );
      await Future<void>.delayed(Duration.zero);
      expect(fired, isEmpty);
      await sub.cancel();
    });
  });
}
