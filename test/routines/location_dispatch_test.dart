// Tests for RoutineExecutor's geofence wiring
// (v1.0 / Phase C PR 2 / ADR-021).
//
// The executor subscribes to GeofenceService.instance.events
// in init(). Each enter/exit event is matched against the
// registered automations and dispatched (if shouldFire
// returns true). These tests cover the dispatch path
// end-to-end without a real Geolocator fix — the
// GeofenceService singleton is driven by a scripted
// position source, which feeds events into the executor's
// subscription automatically.

import 'dart:async';

import 'package:doit/routines/routine.dart';
import 'package:doit/routines/routine_executor.dart';
import 'package:doit/services/geofence_service.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RoutineExecutor executor;
  late GeofenceService geofence;
  late StreamController<Position> controller;

  setUp(() async {
    executor = RoutineExecutor.instance;
    executor.resetForTesting();
    geofence = GeofenceService.instance;
    geofence.resetForTesting();
    controller = StreamController<Position>();
    geofence.debugSetPositionSource(ScriptedPositionSource(controller));
    resetAutomationIdCounterForTesting();
    await executor.init();
    await geofence.init();
  });

  tearDown(() async {
    executor.resetForTesting();
    await controller.close();
    geofence.resetForTesting();
  });

  Automation homeEnter({bool enabled = true}) => Automation(
    trigger: const TriggerLocationEnter(
      geofenceId: 'home',
      label: 'Home',
      latitude: 37.7749,
      longitude: -122.4194,
      radiusMeters: 200,
    ),
    action: const ActionNotify(
      title: 'Welcome home',
      body: 'You just arrived at Home.',
    ),
    enabled: enabled,
  );

  Automation homeExit({bool enabled = true}) => Automation(
    trigger: const TriggerLocationExit(
      geofenceId: 'home',
      label: 'Home',
      latitude: 37.7749,
      longitude: -122.4194,
      radiusMeters: 200,
    ),
    action: const ActionNotify(title: 'Left home', body: 'Safe travels.'),
    enabled: enabled,
  );

  Automation officeEnter() => Automation(
    trigger: const TriggerLocationEnter(
      geofenceId: 'office',
      label: 'Office',
      latitude: 37.7849,
      longitude: -122.4094,
      radiusMeters: 200,
    ),
    action: const ActionNotify(
      title: 'At office',
      body: 'You just arrived at Office.',
    ),
  );

  Position posAt(double lat, double lng) => Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime(2026, 6, 20),
    accuracy: 25,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  test('enter event dispatches the matching automation', () async {
    executor.register('do-1', [homeEnter()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    await geofence.register(homeEnter().trigger as TriggerLocation);
    controller.add(posAt(37.7749, -122.4194));
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(1));
    expect(fired.first.automation.trigger, isA<TriggerLocationEnter>());
    expect(
      (fired.first.automation.trigger as TriggerLocation).geofenceId,
      'home',
    );
    await sub.cancel();
  });

  test('exit event dispatches the matching automation', () async {
    // Register BOTH an Enter and an Exit automation so the
    // round-trip (enter → exit) dispatches both.
    executor.register('do-enter', [homeEnter()]);
    executor.register('do-exit', [homeExit()]);
    await geofence.register(homeEnter().trigger as TriggerLocation);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    controller.add(posAt(37.7749, -122.4194)); // enter
    controller.add(posAt(37.8, -122.4194)); // exit
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(2));
    expect(fired[0].automation.trigger, isA<TriggerLocationEnter>());
    expect(fired[1].automation.trigger, isA<TriggerLocationExit>());
    await sub.cancel();
  });

  test('does not dispatch when geofenceId does not match', () async {
    executor.register('do-1', [officeEnter()]);
    await geofence.register(officeEnter().trigger as TriggerLocation);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    controller.add(posAt(37.7749, -122.4194)); // home, not office
    await Future<void>.delayed(Duration.zero);

    expect(fired, isEmpty);
    await sub.cancel();
  });

  test('does not dispatch when automation is disabled', () async {
    executor.register('do-1', [homeEnter(enabled: false)]);
    await geofence.register(homeEnter().trigger as TriggerLocation);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    controller.add(posAt(37.7749, -122.4194));
    await Future<void>.delayed(Duration.zero);

    expect(fired, isEmpty);
    await sub.cancel();
  });

  test(
    'does not dispatch an enter trigger on an exit event (and vice versa)',
    () async {
      executor.register('do-enter', [homeEnter()]);
      executor.register('do-exit', [homeExit()]);
      await geofence.register(homeEnter().trigger as TriggerLocation);
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);

      controller.add(posAt(37.7749, -122.4194)); // enter event
      await Future<void>.delayed(Duration.zero);

      // Only the enter automation fires; the exit automation
      // is registered but its trigger kind (Exit) doesn't
      // match the enter event.
      expect(fired, hasLength(1));
      expect(fired.first.automation.trigger, isA<TriggerLocationEnter>());
      await sub.cancel();
    },
  );

  test(
    'dispatches for every registered entity whose automation matches',
    () async {
      executor.register('do-1', [homeEnter()]);
      executor.register('do-2', [homeEnter()]);
      await geofence.register(homeEnter().trigger as TriggerLocation);
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);

      controller.add(posAt(37.7749, -122.4194));
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(2));
      await sub.cancel();
    },
  );
}
