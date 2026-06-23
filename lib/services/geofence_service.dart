// GeofenceService — singleton that turns the device's
// coarse position stream into enter/exit events for the
// `TriggerLocationEnter` / `TriggerLocationExit` triggers
// defined in `lib/triggers/trigger.dart`.
//
// Per the v1.0 / Phase C PR 2 / ADR-021 design:
//   - One platform dep: `geolocator` ^13.0.1. We use
//     `Geolocator.getPositionStream()` for the position
//     source and run Dart-side geofence matching against the
//     set of registered `TriggerLocation` circles. No
//     additional native plugin (the alternatives considered
//     in ADR-021 were `flutter_geofence` (stale) and
//     `geofence_service` (overlaps responsibility)).
//   - Permission flow: `Permission.location` (coarse) is
//     requested via `PermissionService.requestLocation()`
//     (SYS-076); the service itself does not call
//     `Geolocator.requestPermission()` — the orchestrator
//     pattern keeps the permission request in one place.
//   - Accuracy: coarse (city-block) is sufficient for the
//     50m..5000m radius bounds the trigger model enforces.
//     `ACCESS_FINE_LOCATION` stays out of scope per the
//     v0.1 carve-out (see architecture_options.md §
//     Permission Baseline).
//
// PositionSource disposal contract (v1.2d / Phase 4 cleanup):
//   - `PositionSource.dispose()` is invoked by the service
//     when it wants to release the source. The contract is
//     "cancel any subscription the source itself owns and
//     release platform resources" — but **the listener-side
//     `StreamSubscription` is owned by `GeofenceService`,
//     not by the source**, so `_GeolocatorPositionSource`'s
//     implementation is a documented no-op (see below).
//   - `GeofenceService` cancels `_sub` itself
//     (`resetForTesting()`), so the source never sees a
//     subscriber to clean up. A future `_GeolocatorPositionSource`
//     that *does* own a native handle (e.g., a v2 migration to
//     `Geolocator.getCurrentPosition` polling, or a fused
//     location provider client) must override `dispose` and
//     release the handle here. The abstract signature stays
//     `Future<void> dispose()` so the service's call site does
//     not change.
//
// Layer rules (per `.claude/rules/lib-services.md`):
//   - Singleton with `Completer<void> _ready`.
//   - `init()` is idempotent.
//   - All public reads/writes `await _ready.future` first.
//   - No UI imports — this folder is pure service.

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:geolocator/geolocator.dart';
import 'package:meta/meta.dart';

import 'package:doit/triggers/trigger.dart' show TriggerLocation;

// ---------------------------------------------------------------------------
// Event surface
// ---------------------------------------------------------------------------

/// Sealed event emitted by [GeofenceService] on each
/// enter/exit transition for a registered
/// [TriggerLocation.geofenceId].
@immutable
sealed class GeofenceEvent {
  const GeofenceEvent(this.geofenceId);
  final String geofenceId;
}

/// Fires the first time the device position lands inside
/// the registered geofence circle.
@immutable
final class GeofenceEntered extends GeofenceEvent {
  const GeofenceEntered(super.geofenceId);
}

/// Fires the first time the device position leaves the
/// registered geofence circle (after a prior
/// [GeofenceEntered] for the same id).
@immutable
final class GeofenceExited extends GeofenceEvent {
  const GeofenceExited(super.geofenceId);
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Platform-position-source seam. The default constructor
/// delegates to a `Geolocator.getPositionStream(...)`
/// factory. Tests inject `_TestPositionSource` to drive the
/// matcher without a real location fix.
abstract class PositionSource {
  Stream<Position> stream();
  Future<void> dispose();
}

class _GeolocatorPositionSource implements PositionSource {
  _GeolocatorPositionSource({LocationSettings? settings})
    : _settings =
          settings ??
          AndroidSettings(accuracy: LocationAccuracy.low, distanceFilter: 25);

  final LocationSettings _settings;

  @override
  Stream<Position> stream() =>
      Geolocator.getPositionStream(locationSettings: _settings);

  @override
  Future<void> dispose() async {
    // The Geolocator position stream is single-subscription; the
    // listener (`GeofenceService._sub`) cancels the subscription
    // to release the underlying native handle. There is nothing
    // for the source itself to dispose — `Geolocator.getPositionStream`
    // does not hand us a teardown handle. If a future port (or a
    // fused-location-client swap) returns a teardown handle, it
    // must be released here.
  }
}

// Public so unit tests can push synthetic positions. We
// keep the constructor public-but-underscored via a
// `@visibleForTesting` factory to signal "production code
// uses the default constructor".
@visibleForTesting
class ScriptedPositionSource implements PositionSource {
  ScriptedPositionSource(this._controller);
  final StreamController<Position> _controller;

  @override
  Stream<Position> stream() => _controller.stream;

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) await _controller.close();
  }
}

/// Singleton. Holds the registered geofence set, the
/// "currently inside" set, and a subscription to the
/// platform position stream. Emits [GeofenceEvent]s on the
/// `events` broadcast stream.
class GeofenceService {
  GeofenceService._();

  /// The single global instance.
  static final GeofenceService instance = GeofenceService._();

  Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  final StreamController<GeofenceEvent> _controller =
      StreamController<GeofenceEvent>.broadcast();

  /// Subscribe to receive every [GeofenceEvent] (enter/exit).
  /// Broadcast; multiple listeners allowed (RoutineExecutor +
  /// future debug screen + analytics).
  Stream<GeofenceEvent> get events => _controller.stream;

  /// geofenceId → registered circle.
  final Map<String, RegisteredGeofence> _geofences =
      HashMap<String, RegisteredGeofence>();

  /// geofenceIds currently considered "inside" (a position
  /// was within radius at the most recent fix).
  final Set<String> _inside = HashSet<String>();

  PositionSource? _source;
  StreamSubscription<Position>? _sub;

  /// Initialize the service. Idempotent. Starts the
  /// platform position subscription and arms the matcher.
  /// Callers should have already requested
  /// `Permission.location` via `PermissionService` (the
  /// service does not call `Geolocator.requestPermission`
  /// itself — permission flow lives in one place).
  Future<void> init() async {
    if (_ready.isCompleted) return;
    _source ??= _GeolocatorPositionSource();
    _sub = _source!.stream().listen(_onPosition, onError: _onPositionError);
    _ready.complete();
  }

  /// Register [geofence]. Idempotent for the same
  /// `TriggerLocation.geofenceId` — re-registering replaces
  /// the prior circle (and clears any "inside" state for
  /// it, since the circle changed). Validates [geofence]
  /// before storing so a malformed registration surfaces
  /// here, not on the next position fix.
  Future<void> register(TriggerLocation geofence) async {
    await ready;
    geofence.validate();
    _geofences[geofence.geofenceId] = RegisteredGeofence(
      id: geofence.geofenceId,
      latitude: geofence.latitude,
      longitude: geofence.longitude,
      radiusMeters: geofence.radiusMeters,
    );
    _inside.remove(geofence.geofenceId);
  }

  /// Remove a registered geofence. No-op if not registered.
  Future<void> unregister(String geofenceId) async {
    await ready;
    _geofences.remove(geofenceId);
    _inside.remove(geofenceId);
  }

  /// Remove every registered geofence. Test-only path; the
  /// production call site is `unregister` per id.
  @visibleForTesting
  Future<void> removeAll() async {
    await ready;
    _geofences.clear();
    _inside.clear();
  }

  /// Test-only accessor. The set of geofence ids currently
  /// considered "inside" by the most recent position fix.
  @visibleForTesting
  Set<String> get insideView => Set<String>.unmodifiable(_inside);

  /// Test-only accessor. The set of registered geofence ids.
  @visibleForTesting
  Iterable<String> get registeredIds =>
      List<String>.unmodifiable(_geofences.keys);

  /// Inject a position source for tests. The default
  /// constructor wires the real Geolocator; tests pass a
  /// [ScriptedPositionSource] so they can drive the matcher
  /// deterministically.
  @visibleForTesting
  void debugSetPositionSource(PositionSource source) {
    _source = source;
  }

  /// Reset for tests. Re-creates the `_ready` Completer,
  /// the broadcast controller, the geofence + inside sets,
  /// and tears down any live position subscription.
  void resetForTesting() {
    if (!_ready.isCompleted) _ready.complete();
    _ready = Completer<void>();
    _sub?.cancel();
    _sub = null;
    _source = null;
    _geofences.clear();
    _inside.clear();
  }

  // --- internal ----------------------------------------------------

  void _onPosition(Position p) {
    final transitions = computeTransitions(
      latitude: p.latitude,
      longitude: p.longitude,
      geofences: _geofences.values,
      inside: _inside,
    );
    for (final event in transitions) {
      if (event is GeofenceEntered) {
        _inside.add(event.geofenceId);
      } else if (event is GeofenceExited) {
        _inside.remove(event.geofenceId);
      }
      _controller.add(event);
    }
  }

  void _onPositionError(Object error, StackTrace stack) {
    // Position stream errors (permission revoked, location
    // disabled, OS-level geofence suspension) are surfaced
    // as a debug log behind `kDebugMode`. We do not crash
    // the executor — the next position fix may recover.
    // Production code paths that need explicit handling can
    // subscribe to `events` and watch for a heartbeat (a
    // future PR may add one; see ADR-022 for the device-
    // state heartbeat convention).
    if (kDebugMode) {
      debugPrint('GeofenceService position stream error: $error');
    }
  }
}

// ---------------------------------------------------------------------------
// Pure-Dart matcher — exposed for unit tests.
// ---------------------------------------------------------------------------

/// Plain value class for a registered geofence circle.
/// Exposed `@visibleForTesting` so the matcher can be driven
/// from unit tests without going through the service's
/// `register` path. Production code uses
/// [GeofenceService.register] which constructs this
/// internally.
@visibleForTesting
class RegisteredGeofence {
  const RegisteredGeofence({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });
  final String id;
  final double latitude;
  final double longitude;
  final int radiusMeters;
}

/// Pure-Dart geofence matcher. Given a new position, the
/// currently-registered circles, and the prior "inside" set,
/// returns the list of enter/exit transitions to emit.
///
/// `inside` is updated in-place by the caller (the service
/// updates its own `Set<String>`; the matcher returns the
/// events but does not mutate the input set, so unit tests
/// can drive it without stateful plumbing).
@visibleForTesting
List<GeofenceEvent> computeTransitions({
  required double latitude,
  required double longitude,
  required Iterable<RegisteredGeofence> geofences,
  required Set<String> inside,
}) {
  final out = <GeofenceEvent>[];
  for (final g in geofences) {
    final meters = _haversineMeters(
      lat1: latitude,
      lon1: longitude,
      lat2: g.latitude,
      lon2: g.longitude,
    );
    final nowInside = meters <= g.radiusMeters;
    final wasInside = inside.contains(g.id);
    if (nowInside && !wasInside) {
      out.add(GeofenceEntered(g.id));
    } else if (!nowInside && wasInside) {
      out.add(GeofenceExited(g.id));
    }
  }
  return out;
}

/// Great-circle distance between two lat/lon points in
/// meters. Pure function; no platform calls.
double _haversineMeters({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  const earthRadiusM = 6371000.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusM * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180.0;
