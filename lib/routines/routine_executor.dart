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
import 'package:doit/services/call_interceptor.dart';
import 'package:doit/services/calendar_service.dart';
import 'package:doit/services/device_state_probe.dart';
import 'package:doit/services/geofence_service.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart'
    show
        SilentMode,
        TriggerBatteryFull,
        TriggerBatteryLow,
        TriggerCalendarEvent,
        TriggerCalendarEventEnd,
        TriggerCalendarEventStart,
        TriggerCalendarReminder,
        TriggerCallIncoming,
        TriggerChargingStarted,
        TriggerChargingStopped,
        TriggerDeviceState,
        TriggerFreeBusy,
        TriggerHeadphoneConnected,
        TriggerHeadphoneDisconnected,
        TriggerLocation,
        TriggerLocationEnter,
        TriggerLocationExit,
        TriggerScreenOff,
        TriggerScreenOn;
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
  StreamSubscription<DeviceStateSnapshot>? _deviceStateSub;
  StreamSubscription<CalendarEvent>? _calendarSub;
  StreamSubscription<CallEvent>? _callSub;

  /// Most recent device-state snapshot. Edge-trigger leaves
  /// (`TriggerChargingStarted`, `TriggerScreenOff`, ...)
  /// need the previous snapshot to detect a transition;
  /// state-comparison leaves (`TriggerBatteryLow`,
  /// `TriggerBatteryFull`) do not.
  @visibleForTesting
  DeviceStateSnapshot? lastDeviceState;

  /// Most recent busy state for `TriggerFreeBusy` matching.
  /// `null` = unknown / first launch; edge detection compares
  /// the current `CalendarBusyChange` to this cached value.
  @visibleForTesting
  bool? lastIsBusy;

  /// Initialize the executor. Idempotent; multiple calls
  /// resolve the same `ready` future. On the first init,
  /// subscribes to `GeofenceService.instance.events`,
  /// `DeviceStateService.instance.events`,
  /// `CalendarService.instance.events`, and
  /// `CallInterceptorService.instance.events` so the
  /// matching automations are dispatched.
  Future<void> init() async {
    if (_ready.isCompleted) return;
    _geofenceSub = GeofenceService.instance.events.listen(_onGeofence);
    _deviceStateSub = DeviceStateService.instance.events.listen(_onDeviceState);
    _calendarSub = CalendarService.instance.events.listen(_onCalendar);
    _callSub = CallInterceptorService.instance.events.listen(_onCall);
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
    _deviceStateSub?.cancel();
    _deviceStateSub = null;
    _calendarSub?.cancel();
    _calendarSub = null;
    _callSub?.cancel();
    _callSub = null;
    lastDeviceState = null;
    lastIsBusy = null;
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

  /// Device-state stream handler. Iterates the registry and
  /// fires every automation whose `TriggerDeviceState`
  /// matches the snapshot.
  ///
  /// Edge triggers (charging started/stopped, headphone
  /// connected/disconnected, screen on/off) compare the
  /// current snapshot to [lastDeviceState]. State-comparison
  /// triggers (`TriggerBatteryLow`, `TriggerBatteryFull`)
  /// look at the current snapshot only.
  ///
  /// Each automation's [shouldFire] call is wrapped in a
  /// try/catch so a single invalid automation does not break
  /// the chain and silently cancel the broadcast listener.
  void _onDeviceState(DeviceStateSnapshot current) {
    final previous = lastDeviceState;
    lastDeviceState = current;
    final now = DateTime.now();
    _registry.forEach((entityId, automations) {
      for (final a in automations) {
        if (!a.enabled) continue;
        final trigger = a.trigger;
        if (trigger is! TriggerDeviceState) continue;
        try {
          if (!shouldFire(a, now)) continue;
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'RoutineExecutor._onDeviceState: skipped invalid automation '
              'on $entityId: $e',
            );
          }
          continue;
        }
        if (!_deviceStateMatches(trigger, current, previous)) continue;
        _controller.add(AutomationFired(automation: a, at: now));
      }
    });
  }

  /// Pure predicate: does [trigger] match the
  /// ([previous], [current]) snapshot pair? Exposed
  /// `@visibleForTesting` so unit tests can drive the
  /// matching logic without going through the stream.
  @visibleForTesting
  bool deviceStateMatches(
    TriggerDeviceState trigger,
    DeviceStateSnapshot current, [
    DeviceStateSnapshot? previous,
  ]) => _deviceStateMatches(trigger, current, previous);

  bool _deviceStateMatches(
    TriggerDeviceState trigger,
    DeviceStateSnapshot current,
    DeviceStateSnapshot? previous,
  ) {
    switch (trigger) {
      case TriggerBatteryLow():
        return current.batteryPercent <= trigger.percent;
      case TriggerBatteryFull():
        return current.batteryPercent >= 100;
      case TriggerChargingStarted():
        return (previous?.isCharging ?? false) == false &&
            current.isCharging == true;
      case TriggerChargingStopped():
        return (previous?.isCharging ?? false) == true &&
            current.isCharging == false;
      case TriggerHeadphoneConnected():
        return (previous?.headphonesConnected ?? false) == false &&
            current.headphonesConnected == true;
      case TriggerHeadphoneDisconnected():
        return (previous?.headphonesConnected ?? false) == true &&
            current.headphonesConnected == false;
      case TriggerScreenOn():
        return (previous?.screenOn ?? false) == false &&
            current.screenOn == true;
      case TriggerScreenOff():
        return (previous?.screenOn ?? false) == true &&
            current.screenOn == false;
    }
  }

  /// Calendar-event stream handler. Iterates the registry
  /// and fires every automation whose `TriggerCalendarEvent`
  /// matches the event leaf (start / end / reminder /
  /// free-busy transition) and the configured
  /// `calendarId` / `eventTitle` filter.
  ///
  /// `TriggerFreeBusy` is edge-detected: it fires on the
  /// `false → true` and `true → false` transitions of the
  /// `CalendarBusyChange` events; a single busy event with
  /// no prior state is treated as a `false → true` edge.
  ///
  /// Each automation's [shouldFire] call is wrapped in a
  /// try/catch so a single invalid automation does not break
  /// the chain and silently cancel the broadcast listener.
  void _onCalendar(CalendarEvent event) {
    final previousIsBusy = lastIsBusy;
    if (event is CalendarBusyChange) {
      lastIsBusy = event.isBusy;
    }
    final now = DateTime.now();
    _registry.forEach((entityId, automations) {
      for (final a in automations) {
        if (!a.enabled) continue;
        final trigger = a.trigger;
        if (trigger is! TriggerCalendarEvent) continue;
        try {
          if (!shouldFire(a, now)) continue;
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'RoutineExecutor._onCalendar: skipped invalid automation '
              'on $entityId: $e',
            );
          }
          continue;
        }
        if (!_calendarMatches(trigger, event, previousIsBusy)) continue;
        _controller.add(AutomationFired(automation: a, at: now));
      }
    });
  }

  /// Pure predicate: does [trigger] match the [event] given
  /// the prior busy state? Exposed `@visibleForTesting` so
  /// unit tests can drive the matching logic without going
  /// through the stream.
  @visibleForTesting
  bool calendarMatches(
    TriggerCalendarEvent trigger,
    CalendarEvent event, [
    bool? previousIsBusy,
  ]) => _calendarMatches(trigger, event, previousIsBusy);

  bool _calendarMatches(
    TriggerCalendarEvent trigger,
    CalendarEvent event,
    bool? previousIsBusy,
  ) {
    // Calendar-id filter: empty trigger.eventTitle = match any
    // title; non-empty trigger.calendarId must equal the
    // event's calendar id (or empty = match any calendar).
    if (trigger.calendarId.isNotEmpty &&
        event.calendarId.isNotEmpty &&
        trigger.calendarId != event.calendarId) {
      return false;
    }
    if (trigger.eventTitle.isNotEmpty &&
        event.title.isNotEmpty &&
        trigger.eventTitle != event.title) {
      return false;
    }
    switch (trigger) {
      case TriggerCalendarEventStart():
        return event is CalendarEventStarted;
      case TriggerCalendarEventEnd():
        return event is CalendarEventEnded;
      case TriggerCalendarReminder():
        return event is CalendarEventReminder;
      case TriggerFreeBusy():
        if (event is! CalendarBusyChange) return false;
        // Edge detection: fire on transition. A null prior
        // state with a true busy event still counts as an
        // edge (the user just went busy).
        if (event.isBusy) {
          return previousIsBusy != true;
        }
        return previousIsBusy == true;
    }
  }

  /// Call-event stream handler. Iterates the registry and
  /// fires every automation whose `TriggerCallIncoming`
  /// matches the event (delegated to the pure predicate
  /// in `lib/services/call_interceptor.dart`'s
  /// `callMatches`).
  ///
  /// Each automation's [shouldFire] call is wrapped in a
  /// try/catch so a single invalid automation does not break
  /// the chain and silently cancel the broadcast listener.
  void _onCall(CallEvent event) {
    final now = DateTime.now();
    _registry.forEach((entityId, automations) {
      for (final a in automations) {
        if (!a.enabled) continue;
        final trigger = a.trigger;
        if (trigger is! TriggerCallIncoming) continue;
        try {
          if (!shouldFire(a, now)) continue;
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'RoutineExecutor._onCall: skipped invalid automation '
              'on $entityId: $e',
            );
          }
          continue;
        }
        if (!callMatches(
          trigger,
          event,
          contactIds: CallInterceptorService.instance.contactIds,
        )) {
          continue;
        }
        _controller.add(AutomationFired(automation: a, at: now));
        // Phase F PR 1 wires `ActionCallIntercept` and
        // `ActionOverrideSilent` to the live
        // [CallInterceptorService] side-effects. The two
        // action leaves are dispatched inline (in addition
        // to the AutomationFired event for any debug
        // subscribers) so a configured Japan routine
        // actually does something at runtime.
        unawaited(_dispatchCallAction(a));
      }
    });
  }

  /// Pure predicate: does [trigger] match [event] given
  /// the service's configured [contactIds]? Exposed
  /// `@visibleForTesting` so unit tests can drive the
  /// matching logic without going through the stream.
  /// Delegates to the `callMatches` top-level in
  /// `lib/services/call_interceptor.dart`.
  @visibleForTesting
  bool callMatchesFor(TriggerCallIncoming trigger, CallEvent event) =>
      callMatches(
        trigger,
        event,
        contactIds: CallInterceptorService.instance.contactIds,
      );

  /// Dispatch a call-related action's side-effect. The
  /// matching engine already emitted an `AutomationFired`
  /// event on the broadcast stream; this method is the
  /// actual platform invocation.
  ///
  ///   - `ActionOverrideSilent` snaps the ringer to the
  ///     configured target mode.
  ///   - `ActionCallIntercept` is currently a no-op on
  ///     the executor side (the Kotlin `CallScreeningService`
  ///     already routed the call); it exists so the
  ///     routine UI can light up a "Japan routine fired"
  ///     affordance. Phase F PR 2 wires the dismiss
  ///     → `restorePriorRinger()` path.
  Future<void> _dispatchCallAction(Automation a) async {
    final action = a.action;
    if (action is ActionOverrideSilent) {
      try {
        await CallInterceptorService.instance.setRingerMode(
          _toRingerMode(action.targetMode),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'RoutineExecutor._dispatchCallAction: '
            'setRingerMode failed: $e',
          );
        }
      }
    }
    // ActionCallIntercept is a no-op on the executor side:
    // the Kotlin service already routed the call. The
    // matching engine's AutomationFired event drives the
    // UI feedback (a debug "Japan routine fired" chip on
    // the home screen / settings debug screen).
  }

  /// Map the model's `SilentMode` enum to the
  /// `CallInterceptorService.RingerMode` enum. Kept in one
  /// place so the model stays decoupled from the service.
  static RingerMode _toRingerMode(SilentMode m) => switch (m) {
    SilentMode.silent => RingerMode.silent,
    SilentMode.vibrate => RingerMode.vibrate,
    SilentMode.normal => RingerMode.normal,
  };
}
