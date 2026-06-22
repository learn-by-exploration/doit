// Tests for GeofenceService (v1.0 / Phase C PR 2 / ADR-021).
//
// Coverage:
//   - computeTransitions: pure-Dart matcher behavior
//     (enter / stay / exit / no-op / multi-circle).
//   - register / unregister / removeAll: registry state.
//   - init() is idempotent.
//   - The broadcast events stream emits GeofenceEntered /
//     GeofenceExited as scripted positions flow through.
//   - Position stream errors do not crash the service.

import 'dart:async';

import 'package:doit/services/geofence_service.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The `GeofenceService.registry` group tests call
  // `service.init()` without injecting a scripted source,
  // so the service falls through to the real
  // `_GeolocatorPositionSource`. That path touches the
  // platform channel, which requires the Flutter binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Reference circle: 1km radius around San Francisco
  // (37.7749, -122.4194).
  const sf = RegisteredGeofence(
    id: 'sf',
    latitude: 37.7749,
    longitude: -122.4194,
    radiusMeters: 1000,
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

  group('computeTransitions (pure-Dart matcher)', () {
    test('emits GeofenceEntered when the first fix is inside', () {
      final inside = <String>{};
      final events = computeTransitions(
        latitude: 37.7749,
        longitude: -122.4194, // exactly at center
        geofences: [sf],
        inside: inside,
      );
      expect(events, [isA<GeofenceEntered>()]);
      expect((events.first as GeofenceEntered).geofenceId, 'sf');
    });

    test('emits nothing when the first fix is outside', () {
      final inside = <String>{};
      final events = computeTransitions(
        latitude: 37.8, // ~2.8 km north of center
        longitude: -122.4194,
        geofences: [sf],
        inside: inside,
      );
      expect(events, isEmpty);
    });

    test('emits GeofenceExited when leaving a previously-inside circle', () {
      final inside = <String>{'sf'};
      final events = computeTransitions(
        latitude: 37.8,
        longitude: -122.4194,
        geofences: [sf],
        inside: inside,
      );
      expect(events, [isA<GeofenceExited>()]);
      expect((events.first as GeofenceExited).geofenceId, 'sf');
    });

    test('emits nothing when staying inside', () {
      final inside = <String>{'sf'};
      final events = computeTransitions(
        latitude: 37.7749,
        longitude: -122.4194,
        geofences: [sf],
        inside: inside,
      );
      expect(events, isEmpty);
    });

    test('multiple circles: each emits independently', () {
      const home = RegisteredGeofence(
        id: 'home',
        latitude: 37.7749,
        longitude: -122.4194,
        radiusMeters: 100,
      );
      const office = RegisteredGeofence(
        id: 'office',
        latitude: 37.7849,
        longitude: -122.4094,
        radiusMeters: 100,
      );
      final inside = <String>{'home', 'office'};
      final events = computeTransitions(
        latitude: 37.7749,
        longitude: -122.4194, // at home, ~1.1km from office
        geofences: [home, office],
        inside: inside,
      );
      // We left office but stayed at home.
      expect(events, hasLength(1));
      expect((events.first as GeofenceExited).geofenceId, 'office');
    });
  });

  group('GeofenceService registry', () {
    late GeofenceService service;

    setUp(() {
      service = GeofenceService.instance;
      service.resetForTesting();
    });

    tearDown(() {
      service.resetForTesting();
    });

    test('init() is idempotent', () async {
      await service.init();
      await service.init(); // second call must not throw
      expect(service.events, isA<Stream<GeofenceEvent>>());
    });

    test('register adds a geofence; registeredIds reflects it', () async {
      await service.init();
      await service.register(
        const TriggerLocationEnter(
          geofenceId: 'g1',
          label: 'Home',
          latitude: 37.7749,
          longitude: -122.4194,
          radiusMeters: 200,
        ),
      );
      expect(service.registeredIds, contains('g1'));
    });

    test('unregister removes a geofence', () async {
      await service.init();
      await service.register(
        const TriggerLocationEnter(
          geofenceId: 'g1',
          label: 'Home',
          latitude: 37.7749,
          longitude: -122.4194,
          radiusMeters: 200,
        ),
      );
      await service.unregister('g1');
      expect(service.registeredIds, isNot(contains('g1')));
    });

    test('unregister on an unknown id is a no-op', () async {
      await service.init();
      await service.unregister('nope');
      expect(service.registeredIds, isEmpty);
    });

    test('removeAll clears every registered geofence', () async {
      await service.init();
      await service.register(
        const TriggerLocationEnter(
          geofenceId: 'g1',
          label: 'Home',
          latitude: 37.7749,
          longitude: -122.4194,
          radiusMeters: 200,
        ),
      );
      await service.register(
        const TriggerLocationExit(
          geofenceId: 'g2',
          label: 'Work',
          latitude: 37.7849,
          longitude: -122.4094,
          radiusMeters: 200,
        ),
      );
      await service.removeAll();
      expect(service.registeredIds, isEmpty);
      expect(service.insideView, isEmpty);
    });

    test(
      'register throws on an invalid geofence (radius out of range)',
      () async {
        await service.init();
        expect(
          () => service.register(
            const TriggerLocationEnter(
              geofenceId: 'g1',
              label: 'Tiny',
              latitude: 0,
              longitude: 0,
              radiusMeters: 10, // below 50m floor
            ),
          ),
          throwsA(isA<TriggerLocationInvalidRadius>()),
        );
      },
    );
  });

  group('GeofenceService events stream', () {
    late GeofenceService service;
    late StreamController<Position> controller;

    setUp(() {
      service = GeofenceService.instance;
      service.resetForTesting();
      controller = StreamController<Position>();
      service.debugSetPositionSource(ScriptedPositionSource(controller));
    });

    tearDown(() async {
      await controller.close();
      service.resetForTesting();
    });

    test('emits GeofenceEntered when a fix lands inside', () async {
      await service.init();
      await service.register(
        const TriggerLocationEnter(
          geofenceId: 'g1',
          label: 'Home',
          latitude: 37.7749,
          longitude: -122.4194,
          radiusMeters: 1000,
        ),
      );
      final fired = <GeofenceEvent>[];
      final sub = service.events.listen(fired.add);

      controller.add(posAt(37.7749, -122.4194));
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(1));
      expect(fired.first, isA<GeofenceEntered>());
      expect((fired.first as GeofenceEntered).geofenceId, 'g1');
      await sub.cancel();
    });

    test('emits GeofenceExited when leaving after an enter', () async {
      await service.init();
      await service.register(
        const TriggerLocationEnter(
          geofenceId: 'g1',
          label: 'Home',
          latitude: 37.7749,
          longitude: -122.4194,
          radiusMeters: 1000,
        ),
      );
      final fired = <GeofenceEvent>[];
      final sub = service.events.listen(fired.add);

      controller.add(posAt(37.7749, -122.4194));
      controller.add(posAt(37.8, -122.4194));
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(2));
      expect(fired[0], isA<GeofenceEntered>());
      expect(fired[1], isA<GeofenceExited>());
      expect(service.insideView, isEmpty);
      await sub.cancel();
    });

    test('does not emit when the fix is outside', () async {
      await service.init();
      await service.register(
        const TriggerLocationEnter(
          geofenceId: 'g1',
          label: 'Home',
          latitude: 37.7749,
          longitude: -122.4194,
          radiusMeters: 100,
        ),
      );
      final fired = <GeofenceEvent>[];
      final sub = service.events.listen(fired.add);

      controller.add(posAt(37.9, -122.4194));
      await Future<void>.delayed(Duration.zero);

      expect(fired, isEmpty);
      await sub.cancel();
    });

    test('position stream errors do not crash the service', () async {
      await service.init();
      // Adding an error to the controller should be handled
      // gracefully. We assert the service is still
      // operational by registering + pushing a position.
      controller.addError(StateError('simulated'));
      await Future<void>.delayed(Duration.zero);

      await service.register(
        const TriggerLocationEnter(
          geofenceId: 'g1',
          label: 'Home',
          latitude: 37.7749,
          longitude: -122.4194,
          radiusMeters: 1000,
        ),
      );
      final fired = <GeofenceEvent>[];
      final sub = service.events.listen(fired.add);

      controller.add(posAt(37.7749, -122.4194));
      await Future<void>.delayed(Duration.zero);
      expect(fired, hasLength(1));
      await sub.cancel();
    });
  });

  // ── v1.2d / Phase 4: PositionSource.dispose contract ──
  group('PositionSource.dispose contract', () {
    test(
      'GeofenceService cancels its own subscription on resetForTesting '
      '(service owns the subscription; source.dispose is independent)',
      () async {
        final controller = StreamController<Position>();
        final source = ScriptedPositionSource(controller);
        // Use the singleton directly. The prior tests in this
        // file leave _sub pending; cancelling here is idempotent.
        final svc = GeofenceService.instance;
        svc.resetForTesting();
        svc.debugSetPositionSource(source);
        await svc.init();
        // Sanity: register works after init.
        await svc.register(
          const TriggerLocationEnter(
            geofenceId: 'g2',
            label: 'Home',
            latitude: 37.7749,
            longitude: -122.4194,
            radiusMeters: 1000,
          ),
        );
        expect(svc.registeredIds, contains('g2'));
        // resetForTesting must cancel _sub and not crash
        // even though the source is mid-listen.
        svc.resetForTesting();
      },
    );
  });
}
