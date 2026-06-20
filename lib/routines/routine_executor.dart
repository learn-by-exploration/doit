// RoutineExecutor — singleton that dispatches [Automation]s.
//
// Phase C PR 1 (v1.0) ships the skeleton. Phase C PR 2 wires
// the geofence path: `GeofenceService.events` is subscribed
// in `init()`; every GeofenceEntered / GeofenceExited event
// is matched against the registered automations and
// dispatched (if `shouldFire` returns true).
//
// The skeleton's contract per spec:
//
//   - `register(entityId, automations)` — attach a list of
//     automations to a Do/Event/Person row.
//   - `unregister(entityId)` — detach an entity's automations.
//   - `registeredFor(entityId)` — `@visibleForTesting`
//     accessor used by unit tests.
//   - `shouldFire(automation, now)` — pure predicate: returns
//     `true` when the trigger's own `validate()` passes AND
//     the runtime condition (geofence membership, time
//     window, weekday match, ...) holds. PR C2 covers
//     geofence state matching; calendar / device-state
//     matching land in Phase D / Phase E.
//
// Future PRs in this phase:
//   - Phase D: device-state probes (battery / headphones / ...).
//   - Phase E: calendar probe (event-start, event-end, busy).
//   - Phase F: call interceptor (incoming-call trigger).
//
// Layer rules (per `.claude/rules/lib-services.md`):
//   - Singleton with `Completer<void> _ready`.
//   - `init()` is idempotent.
//   - Public methods `await _ready.future` first.

import 'dart:async';
import 'dart:collection';

import 'package:doit/routines/routine.dart';
import 'package:doit/services/geofence_service.dart';
import 'package:doit/triggers/trigger.dart'
    show TriggerLocation, TriggerLocationEnter, TriggerLocationExit;
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:meta/meta.dart';

/// The executor singleton. One per app process; lives for
/// the lifetime of the app.
class RoutineExecutor {
  RoutineExecutor._();

  static final RoutineExecutor instance = RoutineExecutor._();

  Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  StreamController<AutomationFired> _controller =
      StreamController<AutomationFired>.broadcast();

  /// Subscribe to receive every [AutomationFired] event. The
  /// stream is broadcast; multiple listeners (home screen,
  /// settings debug, future analytics) are allowed.
  Stream<AutomationFired> get events => _controller.stream;

  // entityId → automations
  final Map<String, List<Automation>> _registry = HashMap();

  StreamSubscription<GeofenceEvent>? _geofenceSub;

  /// Initialize the executor. Idempotent; multiple calls
  /// resolve the same `ready` future. On the first init,
  /// subscribes to `GeofenceService.instance.events` so
  /// enter/exit events are dispatched to the matching
  /// automations.
  Future<void> init() async {
    if (_ready.isCompleted) return;
    _geofenceSub = GeofenceService.instance.events.listen(_onGeofence);
    _ready.complete();
  }

  /// Reset for tests. Re-creates the `_ready` Completer,
  /// closes the broadcast stream, cancels any live
  /// geofence subscription, and clears the registry.
  void resetForTesting() {
    if (!_ready.isCompleted) {
      _ready.complete();
    }
    _ready = Completer<void>();
    // Replace the broadcast stream so the next test gets a
    // fresh, open controller. Closing the previous one means
    // future `add` calls would throw "Cannot add new events
    // after calling close".
    _controller = StreamController<AutomationFired>.broadcast();
    _geofenceSub?.cancel();
    _geofenceSub = null;
    _registry.clear();
  }

  /// Attach [automations] to [entityId] (a Do/Event/Person
  /// id). Replaces any prior registration for the same id.
  void register(String entityId, List<Automation> automations) {
    _registry[entityId] = List<Automation>.unmodifiable(automations);
  }

  /// Detach [entityId]'s automations. No-op if not
  /// registered.
  void unregister(String entityId) {
    _registry.remove(entityId);
  }

  /// Test-only accessor. Returns the automations registered
  /// for [entityId], or `null` if the entity is not
  /// registered.
  @visibleForTesting
  List<Automation>? registeredFor(String entityId) {
    final list = _registry[entityId];
    return list == null ? null : List<Automation>.unmodifiable(list);
  }

  /// Test-only accessor. Returns the entity ids currently
  /// registered.
  @visibleForTesting
  Iterable<String> get registeredEntityIds =>
      List<String>.unmodifiable(_registry.keys);

  /// Test-only pure predicate. PR C1 returns `true` for any
  /// automation whose trigger, condition, and action all
  /// pass `validate()`, regardless of `now`. The runtime
  /// semantics (time-of-day match, weekday match, geofence
  /// state, battery range, ...) land in PR C2.
  @visibleForTesting
  bool shouldFire(Automation automation, DateTime now) {
    if (!automation.enabled) return false;
    automation.trigger.validate();
    automation.condition?.validate();
    automation.action.validate();
    return true;
  }

  /// Manually dispatch [automation] for [entityId] now. PR
  /// C1 only emits the `AutomationFired` event; the actual
  /// action side-effect (notification / full-screen / ...)
  /// lands in PR C2. Used by tests and by the future
  /// dispatch loop.
  void dispatch(
    Automation automation, {
    required String entityId,
    required DateTime now,
  }) {
    if (!shouldFire(automation, now)) return;
    _controller.add(AutomationFired(automation: automation, at: now));
  }

  /// Geofence stream handler. Iterates the registry and
  /// fires every automation whose trigger matches the
  /// event kind (enter/exit) and geofence id.
  ///
  /// Each automation's [shouldFire] call is wrapped in a
  /// try/catch so a single invalid automation (e.g. an
  /// `ActionNotify` with an empty body — the trigger model
  /// validates it, but a stale persisted row might still
  /// sneak in) does not break the chain and silently
  /// cancel the broadcast listener. The exception is
  /// surfaced as a debug log behind `kDebugMode` and the
  /// automation is skipped.
  void _onGeofence(GeofenceEvent event) {
    final isEnter = event is GeofenceEntered;
    final isExit = event is GeofenceExited;
    if (!isEnter && !isExit) return;
    final now = DateTime.now();
    _registry.forEach((entityId, automations) {
      for (final a in automations) {
        if (!a.enabled) continue;
        final trigger = a.trigger;
        final matches =
            (isEnter && trigger is TriggerLocationEnter) ||
            (isExit && trigger is TriggerLocationExit);
        if (!matches) continue;
        if ((trigger as TriggerLocation).geofenceId != event.geofenceId) {
          continue;
        }
        try {
          if (!shouldFire(a, now)) continue;
        } catch (e) {
          // Validation failure on a stale row. Skip this
          // automation; let the rest fire.
          if (kDebugMode) {
            debugPrint(
              'RoutineExecutor._onGeofence: skipped invalid automation '
              'on $entityId: $e',
            );
          }
          continue;
        }
        _controller.add(AutomationFired(automation: a, at: now));
      }
    });
  }
}
