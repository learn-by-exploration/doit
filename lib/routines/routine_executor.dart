// RoutineExecutor — singleton that dispatches [Automation]s.
//
// Phase C PR 1 (v1.0) ships the skeleton. The skeleton's
// contract per spec:
//
//   - `register(entityId, automations)` — attach a list of
//     automations to a Do/Event/Person row.
//   - `unregister(entityId)` — detach an entity's automations.
//   - `registeredFor(entityId)` — `@visibleForTesting`
//     accessor used by unit tests.
//   - `shouldFire(automation, now)` — `@visibleForTesting`
//     pure function: the predicate the dispatch loop will
//     use to decide whether to fire. PR C1 returns `true`
//     whenever the trigger's own `validate()` passes; the
//     full condition-evaluation lands in PR C2.
//
// The "real" dispatch loop (subscribe to AlarmScheduler +
// GeofenceService + NotificationService + ...) lands in
// PR C2. PR C1 keeps the surface testable in pure-Dart
// unit tests (no Flutter harness required).

import 'dart:async';
import 'dart:collection';

import 'package:doit/routines/routine.dart';
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

  /// Initialize the executor. Idempotent; multiple calls
  /// resolve the same `ready` future.
  Future<void> init() async {
    if (_ready.isCompleted) return;
    _ready.complete();
  }

  /// Reset for tests. Re-creates the `_ready` Completer,
  /// closes the broadcast stream, and clears the registry.
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
}
