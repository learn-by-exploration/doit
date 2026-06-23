// CallInterceptorService — singleton that turns the Android
// `CallScreeningService` callbacks into a Dart stream of
// call events for the `TriggerCallIncoming` leaves in
// `lib/triggers/trigger.dart`.
//
// Per the v1.0 / Phase F PR 1 / ADR-019 design:
//   - The platform side is a thin `doit/call_interceptor`
//     method channel plus a `CallScreeningService` Kotlin
//     class (`android/.../CallInterceptor.kt`). The OS
//     invokes the service's `onScreenCall(Call.Details)`
//     for every incoming call before the dialer rings;
//     the service returns a synchronous `CallResponse`
//     and (when the contact matches the configured list
//     AND silent mode is on) snaps the ringer to
//     `RINGER_MODE_NORMAL`. The event is forwarded to Dart
//     via `invokeMethod("onCallEvent", map)`.
//   - The `CallSource` abstract class is the seam for
//     tests; production wires a `_MethodChannelCallSource`
//     that talks to the Kotlin side, tests wire a
//     `ScriptedCallSource`.
//   - Library choice: native `CallScreeningService` over
//     `PhoneAccount` self-managed Connection API. See
//     ADR-019 for the full rationale. The native surface
//     requires no `READ_PHONE_STATE`; the bound permission
//     (`BIND_SCREENING_SERVICE`) is signature-protected and
//     granted at install time.
//
// Layer rules (per `.claude/rules/lib-services.md`):
//   - Singleton with `Completer<void> _ready`.
//   - `init()` is idempotent.
//   - All public reads/writes `await _ready.future` first.
//   - No UI imports.

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import 'package:doit/triggers/trigger.dart'
    show
        TriggerCallIncoming,
        TriggerCallIncomingAny,
        TriggerCallIncomingKnownContact,
        TriggerCallIncomingUnknownContact;

import 'package:doit/triggers/action.dart' show CallInterceptDecision;

// ---------------------------------------------------------------------------
// Event surface
// ---------------------------------------------------------------------------

/// Sealed event emitted by [CallInterceptorService] on each
/// `onScreenCall` callback from the platform. The leaves map
/// to the three `TriggerCallIncoming*` shapes.
@immutable
sealed class CallEvent {
  const CallEvent({
    required this.number,
    required this.displayName,
    required this.at,
  });

  /// The caller's number in E.164 form. Empty string =
  /// unknown (the OS sometimes hides the number for private
  /// callers; we treat it as "unknown contact" in the
  /// matching predicate).
  final String number;

  /// The caller's display name from the address book, if
  /// resolved. Empty string = not resolved (the Kotlin side
  /// does not currently resolve contacts; Phase F PR 2 may
  /// add a resolver via the existing `PersonResolver`).
  final String displayName;

  /// Wall-clock time at which the platform pushed the event.
  final DateTime at;
}

/// Fires for every incoming call, regardless of whether the
/// number resolves to a known contact. Matches
/// `TriggerCallIncomingAny`.
@immutable
final class CallIncomingAny extends CallEvent {
  const CallIncomingAny({
    required super.number,
    required super.displayName,
    required super.at,
  });
}

/// Fires for an incoming call from a number that resolves
/// via the user's address book. Matches
/// `TriggerCallIncomingKnownContact`.
@immutable
final class CallIncomingKnownContact extends CallEvent {
  const CallIncomingKnownContact({
    required super.number,
    required super.displayName,
    required super.at,
  });
}

/// Fires for an incoming call from a number NOT in the
/// address book (private / spam). Matches
/// `TriggerCallIncomingUnknownContact`.
@immutable
final class CallIncomingUnknownContact extends CallEvent {
  const CallIncomingUnknownContact({
    required super.number,
    required super.displayName,
    required super.at,
  });
}

/// Fires when the platform reports a successful ringer
/// override (the Japan routine's success path). The executor
/// uses this to chain into the dismiss / restore flow; the
/// matching engine ignores it (no `TriggerCallIncoming*`
/// leaf matches a `RingerOverride` event).
@immutable
final class CallRingerOverridden extends CallEvent {
  const CallRingerOverridden({
    required super.number,
    required super.displayName,
    required super.at,
    required this.priorMode,
    required this.targetMode,
  });

  /// The ringer mode the device was in before the override
  /// (cached on the Kotlin side at the moment of the
  /// `onScreenCall` callback).
  final RingerMode priorMode;

  /// The ringer mode the service snapped the device to.
  final RingerMode targetMode;
}

// ---------------------------------------------------------------------------
// RingerMode enum — mirrors AudioManager.RINGER_MODE_*.
// ---------------------------------------------------------------------------

/// The device's ringer / DnD mode. Mirrors the Android
/// `AudioManager.RINGER_MODE_*` constants. Used by the
/// matching engine to evaluate `ConditionSilentMode` and by
/// the `ActionOverrideSilent` dispatch path.
enum RingerMode {
  /// `RINGER_MODE_SILENT`. No sound, no vibrate.
  silent,

  /// `RINGER_MODE_VIBRATE`. Vibrate but no sound.
  vibrate,

  /// `RINGER_MODE_NORMAL`. Sound + vibrate.
  normal;

  /// Wire-format string the Kotlin side uses
  /// (`AudioManager.ringerMode` ↔ this enum).
  String get wireName => switch (this) {
    RingerMode.silent => 'silent',
    RingerMode.vibrate => 'vibrate',
    RingerMode.normal => 'normal',
  };

  /// Decode a wire-format string. Defaults to `normal` on
  /// an unknown value (the safe fallback — the screening
  /// service never snaps back to `normal` if the wire
  /// string is malformed).
  static RingerMode fromWire(String? wire) => switch (wire) {
    'silent' => RingerMode.silent,
    'vibrate' => RingerMode.vibrate,
    'normal' => RingerMode.normal,
    _ => RingerMode.normal,
  };
}

// ---------------------------------------------------------------------------
// Source seam
// ---------------------------------------------------------------------------

/// Abstract source the [CallInterceptorService] reads
/// events from. Production wires [_MethodChannelCallSource];
/// tests wire [ScriptedCallSource].
abstract class CallSource {
  /// Start the source. After this future resolves the
  /// service may subscribe to [events].
  Future<void> start();

  /// Stop the source. Idempotent.
  Future<void> stop();

  /// Broadcast stream of events. The service is the only
  /// listener; multiple subscribers in app code listen to
  /// [CallInterceptorService.events] instead.
  Stream<CallEvent> get events;

  /// Configure whether the screening service should
  /// intercept incoming calls. Defaults to `false` (the
  /// service is a pass-through). Set to `true` to enable
  /// the Japan routine.
  Future<void> setEnabled(bool enabled);

  /// Configure the phone numbers (E.164) the screening
  /// service should treat as "match". Empty list = no
  /// matches (the service is a pass-through regardless of
  /// [setEnabled]).
  Future<void> setContactIds(List<String> ids);

  /// Snap the device ringer to [mode]. Used by the
  /// `ActionOverrideSilent` dispatch path.
  Future<void> setRingerMode(RingerMode mode);

  /// Read the current ringer mode. The matching engine
  /// uses this to evaluate `ConditionSilentMode`.
  Future<RingerMode> getRingerMode();

  /// Restore the ringer mode the screening service cached
  /// at the moment of the most recent override. Idempotent
  /// — a no-op if no override is in flight.
  Future<void> restorePriorRinger();

  /// Phase F PR 2 (SYS-075 / SYS-079). Returns `true` if
  /// the user has opted into the `ROLE_CALL_SCREENING` role
  /// via `RoleManager`. `false` on Android < Q (the role
  /// does not exist), on missing plugin, or when the role
  /// is not held.
  Future<bool> isCallScreeningRoleHeld();

  /// Phase F PR 2 (SYS-075 / SYS-079). Fires the OS role
  /// request flow. Returns `true` if the role was already
  /// held, or the user just granted it. `false` if the
  /// role is unavailable (Android < Q, no Activity context,
  /// missing plugin), or the user declined the dialog.
  ///
  /// The OS dialog is asynchronous; this method only fires
  /// the intent. Callers re-probe via
  /// [isCallScreeningRoleHeld] when the user returns to the
  /// Settings screen.
  Future<bool> requestCallScreeningRole();

  /// v1.2f / Phase 6: record a routine's
  /// [CallInterceptDecision] for analytics / debug. Called
  /// from `RoutineExecutor._dispatchAction` when an
  /// `ActionCallIntercept` arm fires. The Kotlin
  /// `CallScreeningService` already routed the call (the
  /// decision is a no-op for the ringer); this method is
  /// the post-call hook for the routine engine to surface
  /// what it would have done. Does NOT touch the ringer
  /// (ADR-019).
  Future<void> recordRoutineDecision(CallInterceptDecision decision);
}

/// Production source: talks to the `doit/call_interceptor`
/// method channel. The Kotlin side pushes events via
/// `invokeMethod("onCallEvent", map)`.
class _MethodChannelCallSource implements CallSource {
  _MethodChannelCallSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('doit/call_interceptor');

  final MethodChannel _channel;
  final StreamController<CallEvent> _controller =
      StreamController<CallEvent>.broadcast();
  bool _handlerInstalled = false;

  Future<void> _installHandler() async {
    if (_handlerInstalled) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCallEvent') {
        final args = call.arguments;
        if (args is Map) {
          final ev = _decode(args);
          if (ev != null) _controller.add(ev);
        }
      }
      return null;
    });
    _handlerInstalled = true;
  }

  static CallEvent? _decode(Map<Object?, Object?> m) {
    final kind = m['kind'] as String?;
    final number = (m['number'] as String?) ?? '';
    final displayName = (m['displayName'] as String?) ?? '';
    final atMs = (m['atMs'] as int?) ?? 0;
    final at = DateTime.fromMillisecondsSinceEpoch(atMs);
    switch (kind) {
      case 'incoming':
        // The Kotlin side does not currently resolve
        // contacts (the address-book lookup is on the
        // Dart side via `PersonResolver`). The number
        // alone is enough to pick Any vs Unknown; the
        // matching engine consults `contactIds` to pick
        // Known vs Unknown. Forward as `CallIncomingAny`
        // so the executor can apply the trigger kind
        // explicitly.
        return CallIncomingAny(
          number: number,
          displayName: displayName,
          at: at,
        );
      case 'ringerOverridden':
        final priorMode = RingerMode.fromWire(m['priorMode'] as String?);
        final targetMode = RingerMode.fromWire(m['targetMode'] as String?);
        return CallRingerOverridden(
          number: number,
          displayName: displayName,
          at: at,
          priorMode: priorMode,
          targetMode: targetMode,
        );
      default:
        return null;
    }
  }

  @override
  Future<void> start() async {
    await _installHandler();
    try {
      await _channel.invokeMethod<void>('startStream');
    } on MissingPluginException catch (e) {
      if (kDebugMode) debugPrint('CallSource.start: $e');
    }
  }

  @override
  Future<void> stop() async {
    if (!_handlerInstalled) return;
    try {
      await _channel.invokeMethod<void>('stopStream');
    } on MissingPluginException catch (e) {
      if (kDebugMode) debugPrint('CallSource.stop: $e');
    }
  }

  @override
  Stream<CallEvent> get events => _controller.stream;

  @override
  Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});
    } on MissingPluginException catch (e) {
      if (kDebugMode) debugPrint('CallSource.setEnabled: $e');
    }
  }

  @override
  Future<void> setContactIds(List<String> ids) async {
    try {
      await _channel.invokeMethod<void>('setContactIds', {'ids': ids});
    } on MissingPluginException catch (e) {
      if (kDebugMode) debugPrint('CallSource.setContactIds: $e');
    }
  }

  @override
  Future<void> setRingerMode(RingerMode mode) async {
    try {
      await _channel.invokeMethod<void>('setRingerMode', {
        'mode': mode.wireName,
      });
    } on MissingPluginException catch (e) {
      if (kDebugMode) debugPrint('CallSource.setRingerMode: $e');
    }
  }

  @override
  Future<RingerMode> getRingerMode() async {
    try {
      final raw = await _channel.invokeMethod<String>('getRingerMode');
      return RingerMode.fromWire(raw);
    } on MissingPluginException catch (_) {
      return RingerMode.normal;
    }
  }

  @override
  Future<void> restorePriorRinger() async {
    try {
      await _channel.invokeMethod<void>('restorePriorRinger');
    } on MissingPluginException catch (e) {
      if (kDebugMode) debugPrint('CallSource.restorePriorRinger: $e');
    }
  }

  @override
  Future<bool> isCallScreeningRoleHeld() async {
    try {
      final held = await _channel.invokeMethod<bool>('isCallScreeningRoleHeld');
      return held ?? false;
    } on MissingPluginException catch (e) {
      if (kDebugMode) debugPrint('CallSource.isCallScreeningRoleHeld: $e');
      return false;
    }
  }

  @override
  Future<bool> requestCallScreeningRole() async {
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestCallScreeningRole',
      );
      return granted ?? false;
    } on MissingPluginException catch (e) {
      if (kDebugMode) debugPrint('CallSource.requestCallScreeningRole: $e');
      return false;
    }
  }

  @override
  Future<void> recordRoutineDecision(CallInterceptDecision decision) async {
    try {
      await _channel.invokeMethod<void>('recordRoutineDecision', {
        'decision': decision.name,
      });
    } on MissingPluginException catch (e) {
      if (kDebugMode) {
        debugPrint('CallSource.recordRoutineDecision: $e');
      }
    }
  }
}

/// Test source: a hand-driven [StreamController] the unit
/// test can push scripted events through. Mirrors the
/// Phase E `ScriptedCalendarSource` pattern.
@visibleForTesting
class ScriptedCallSource implements CallSource {
  ScriptedCallSource({StreamController<CallEvent>? controller})
    : _controller = controller ?? StreamController<CallEvent>.broadcast();

  final StreamController<CallEvent> _controller;
  int startCalls = 0;
  int stopCalls = 0;
  Object? startError;

  /// Last value passed to [setEnabled]. `null` = never
  /// called.
  bool? lastEnabled;

  /// Last value passed to [setContactIds]. `null` = never
  /// called.
  List<String>? lastContactIds;

  /// Last value passed to [setRingerMode]. `null` = never
  /// called.
  RingerMode? lastRingerMode;

  /// What the next [getRingerMode] call returns. Defaults
  /// to `RingerMode.normal`.
  RingerMode scriptedRingerMode = RingerMode.normal;

  /// Number of [restorePriorRinger] calls.
  int restorePriorRingerCalls = 0;

  /// What the next [isCallScreeningRoleHeld] call returns.
  /// Defaults to `false`.
  bool scriptedRoleHeld = false;

  /// What the next [requestCallScreeningRole] call returns.
  /// Defaults to `false`. The default mirrors "user declined
  /// the OS dialog".
  bool scriptedRoleRequestGranted = false;

  /// Number of [requestCallScreeningRole] calls.
  int requestCallScreeningRoleCalls = 0;

  /// v1.2f / Phase 6: every
  /// [recordRoutineDecision] call (in invocation order).
  /// `null` = never called.
  final List<CallInterceptDecision> routineDecisions =
      <CallInterceptDecision>[];

  /// Push an event to listeners. Mirrors the Kotlin
  /// `pushCallEvent` path.
  void push(CallEvent ev) => _controller.add(ev);

  @override
  Future<void> start() async {
    startCalls++;
    final e = startError;
    if (e != null) {
      startError = null;
      throw e;
    }
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Stream<CallEvent> get events => _controller.stream;

  @override
  Future<void> setEnabled(bool enabled) async {
    lastEnabled = enabled;
  }

  @override
  Future<void> setContactIds(List<String> ids) async {
    lastContactIds = List<String>.unmodifiable(ids);
  }

  @override
  Future<void> setRingerMode(RingerMode mode) async {
    lastRingerMode = mode;
  }

  @override
  Future<RingerMode> getRingerMode() async => scriptedRingerMode;

  @override
  Future<void> restorePriorRinger() async {
    restorePriorRingerCalls++;
  }

  @override
  Future<bool> isCallScreeningRoleHeld() async => scriptedRoleHeld;

  @override
  Future<bool> requestCallScreeningRole() async {
    requestCallScreeningRoleCalls++;
    return scriptedRoleRequestGranted;
  }

  @override
  Future<void> recordRoutineDecision(CallInterceptDecision decision) async {
    routineDecisions.add(decision);
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Singleton. Owns the source subscription, the broadcast
/// `events` stream the rest of the app listens to, and the
/// cached contact-id list used by the matching engine.
class CallInterceptorService {
  CallInterceptorService._();

  /// The single global instance.
  static final CallInterceptorService instance = CallInterceptorService._();

  Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  final StreamController<CallEvent> _controller =
      StreamController<CallEvent>.broadcast();

  /// Subscribe to receive every [CallEvent] (any / known /
  /// unknown / ringer-overridden). Broadcast; multiple
  /// listeners allowed (RoutineExecutor + future debug
  /// screen).
  Stream<CallEvent> get events => _controller.stream;

  CallSource? _source;
  StreamSubscription<CallEvent>? _sub;

  /// Phone numbers (E.164) the matching engine considers
  /// "known contacts". The executor's `callMatches`
  /// predicate reads this. Synced from the user's routine
  /// configuration (Phase F PR 2). Public (not
  /// `@visibleForTesting`) because the executor is in a
  /// different package and reads it on every call event.
  Set<String> get contactIds => _contactIds;
  Set<String> _contactIds = <String>{};

  /// Test-only setter. Production code uses [configure].
  @visibleForTesting
  set contactIds(Set<String> ids) =>
      _contactIds = Set<String>.unmodifiable(ids);

  /// Initialize the service. Idempotent. Starts the source
  /// and arms the broadcast subscription.
  Future<void> init() async {
    if (_ready.isCompleted) return;
    _source ??= _MethodChannelCallSource();
    await _source!.start();
    _sub = _source!.events.listen(_onEvent, onError: _onError);
    _ready.complete();
  }

  /// Configure the screening service. Called when the user
  /// enables / disables the Japan routine or updates the
  /// configured contact list. Awaiting this is required
  /// before any subsequent source-side call.
  Future<void> configure({
    required bool enabled,
    List<String>? contactIds,
  }) async {
    await ready;
    if (contactIds != null) {
      this.contactIds = Set<String>.unmodifiable(contactIds);
      await _source!.setContactIds(contactIds);
    }
    await _source!.setEnabled(enabled);
  }

  /// Read the device's current ringer mode. Used by the
  /// matching engine to evaluate `ConditionSilentMode`.
  Future<RingerMode> currentRingerMode() async {
    await ready;
    return _source!.getRingerMode();
  }

  /// Snap the ringer to [mode]. Used by the
  /// `ActionOverrideSilent` dispatch path.
  Future<void> setRingerMode(RingerMode mode) async {
    await ready;
    await _source!.setRingerMode(mode);
  }

  /// Restore the ringer mode the screening service cached
  /// at the moment of the most recent override.
  /// Idempotent — a no-op if no override is in flight.
  Future<void> restorePriorRinger() async {
    await ready;
    await _source!.restorePriorRinger();
  }

  /// Phase F PR 2 (SYS-075 / SYS-079): probe whether the
  /// user has granted the `ROLE_CALL_SCREENING` role via
  /// `RoleManager`. Used by the Settings → Call-screening
  /// tile to render "Held" / "Not held" status.
  Future<bool> isCallScreeningRoleHeld() async {
    await ready;
    return _source!.isCallScreeningRoleHeld();
  }

  /// Phase F PR 2 (SYS-075 / SYS-079): fire the OS role
  /// request flow. The OS dialog is asynchronous — callers
  /// re-probe via [isCallScreeningRoleHeld] when the user
  /// returns to the Settings screen.
  Future<bool> requestCallScreeningRole() async {
    await ready;
    return _source!.requestCallScreeningRole();
  }

  /// v1.2f / Phase 6: post-call hook for the routine
  /// engine. `RoutineExecutor._dispatchAction` calls this
  /// when an `ActionCallIntercept` arm fires; the call is
  /// already routed by the Kotlin `CallScreeningService`,
  /// so the executor surfaces its decision for analytics /
  /// debug. Does NOT touch the ringer (ADR-019).
  Future<void> recordRoutineDecision(CallInterceptDecision decision) async {
    await ready;
    await _source!.recordRoutineDecision(decision);
  }

  /// Inject a source for tests. The default constructor
  /// wires the real method channel; tests pass a
  /// [ScriptedCallSource] so they can drive the stream
  /// deterministically.
  @visibleForTesting
  void debugSetSource(CallSource source) {
    _source = source;
  }

  /// Reset for tests. Re-creates the `_ready` Completer,
  /// the broadcast controller, cancels the source
  /// subscription, stops the source, and clears the
  /// contact-id cache.
  void resetForTesting() {
    if (!_ready.isCompleted) _ready.complete();
    _ready = Completer<void>();
    _sub?.cancel();
    _sub = null;
    final src = _source;
    _source = null;
    contactIds = <String>{};
    if (src != null) {
      unawaited(src.stop());
    }
  }

  // --- internal ----------------------------------------------------

  void _onEvent(CallEvent ev) => _controller.add(ev);

  void _onError(Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('CallInterceptorService source error: $error');
    }
  }
}

// ---------------------------------------------------------------------------
// Pure predicate — exposed `@visibleForTesting` so the
// routine executor (lib/routines/routine_executor.dart) and
// unit tests can share the same matching logic.
// ---------------------------------------------------------------------------

/// Does [trigger] match [event] given the configured
/// [contactIds]?
///
///   - `TriggerCallIncomingAny` matches every
///     [CallIncomingAny] (the production source always
///     emits `CallIncomingAny`; the executor's predicate
///     plus the source's contact-id list together decide
///     known vs unknown). It does NOT match
///     [CallRingerOverridden] — that is a side-effect
///     event, not a "call is incoming" event.
///   - `TriggerCallIncomingKnownContact` matches when the
///     event's number is in [contactIds].
///   - `TriggerCallIncomingUnknownContact` matches the
///     complement.
///
/// An empty [contactIds] set means no contact is known —
/// every call matches the unknown-contact trigger and none
/// matches the known-contact trigger.
bool callMatches(
  TriggerCallIncoming trigger,
  CallEvent event, {
  Set<String> contactIds = const <String>{},
}) {
  switch (trigger) {
    case TriggerCallIncomingAny():
      return event is CallIncomingAny;
    case TriggerCallIncomingKnownContact():
      if (event is! CallIncomingAny) return false;
      return contactIds.contains(event.number);
    case TriggerCallIncomingUnknownContact():
      if (event is! CallIncomingAny) return false;
      return !contactIds.contains(event.number);
  }
}
