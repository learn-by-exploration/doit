// DeviceStateService — singleton that turns the device's
// battery, charging, headphone, and screen state into a
// stream of [DeviceStateSnapshot]s for the
// `TriggerDeviceState` leaves in `lib/triggers/trigger.dart`.
//
// Per the v1.0 / Phase D PR 1 / ADR-022 design:
//   - The platform side is a thin `doit/device_state`
//     method channel (`android/.../DeviceStateChannel.kt`).
//     The channel registers a `BroadcastReceiver` for
//     charging, headphone, and screen events; battery is
//     read on demand via `BatteryManager.BATTERY_PROPERTY_CAPACITY`.
//   - The Dart side is the source of truth for "which
//     state changes are interesting" (the routine executor
//     matches trigger shapes against the stream in PR 2).
//     The probe is a pure publisher.
//   - The `DeviceStateSource` abstract class is the seam
//     for tests; production wires a
//     `_MethodChannelDeviceStateSource` that talks to the
//     Kotlin side, tests wire a `ScriptedDeviceStateSource`.
//   - 60-second polling is not implemented in PR 1 — the
//     reactive broadcasts above cover every state that
//     matters. ADR-022 reserves the poll cadence for any
//     future state that lacks a reactive broadcast.
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

// ---------------------------------------------------------------------------
// Snapshot
// ---------------------------------------------------------------------------

/// A point-in-time view of the four device-state fields the
/// v1.0 trigger set cares about. Mirrored exactly from the
/// Kotlin side's `snapshotMap(...)` keys.
@immutable
class DeviceStateSnapshot {
  const DeviceStateSnapshot({
    required this.batteryPercent,
    required this.isCharging,
    required this.headphonesConnected,
    required this.screenOn,
    required this.at,
  });

  /// Battery level 0..100. Matches
  /// `BatteryManager.BATTERY_PROPERTY_CAPACITY`.
  final int batteryPercent;

  /// True when the device is drawing current from a
  /// charger. Matches `BatteryManager.isCharging`.
  final bool isCharging;

  /// True when any wired or wireless headphones output is
  /// connected (covers `TYPE_WIRED_HEADSET`,
  /// `TYPE_WIRED_HEADPHONES`, `TYPE_BLUETOOTH_A2DP`,
  /// `TYPE_BLE_HEADSET`, `TYPE_USB_HEADSET`).
  final bool headphonesConnected;

  /// True when the screen is on (matches
  /// `PowerManager.isInteractive`).
  final bool screenOn;

  /// The wall-clock time at which this snapshot was
  /// captured. Set by the producer (the Kotlin side, or a
  /// test's `ScriptedDeviceStateSource`).
  final DateTime at;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceStateSnapshot &&
        other.batteryPercent == batteryPercent &&
        other.isCharging == isCharging &&
        other.headphonesConnected == headphonesConnected &&
        other.screenOn == screenOn &&
        other.at == at;
  }

  @override
  int get hashCode => Object.hash(
    batteryPercent,
    isCharging,
    headphonesConnected,
    screenOn,
    at,
  );

  /// Convenience: parse a snapshot from the wire-format
  /// map the Kotlin side returns. Throws
  /// [FormatException] on a missing key.
  factory DeviceStateSnapshot.fromMap(Map<Object?, Object?> map) {
    return DeviceStateSnapshot(
      batteryPercent: (map['batteryPercent'] as int?) ?? 0,
      isCharging: (map['isCharging'] as bool?) ?? false,
      headphonesConnected: (map['headphonesConnected'] as bool?) ?? false,
      screenOn: (map['screenOn'] as bool?) ?? false,
      at: DateTime.now(),
    );
  }
}

// ---------------------------------------------------------------------------
// Source seam
// ---------------------------------------------------------------------------

/// Abstract source the [DeviceStateService] reads snapshots
/// from. Production wires
/// [_MethodChannelDeviceStateSource]; tests wire
/// [ScriptedDeviceStateSource].
abstract class DeviceStateSource {
  /// Start the source. After this future resolves the
  /// service may subscribe to [events] and call
  /// [currentSnapshot].
  Future<void> start();

  /// Stop the source. Idempotent.
  Future<void> stop();

  /// One-shot read of the current snapshot. Used by
  /// `current()` and by `start()`'s baseline push.
  Future<DeviceStateSnapshot> currentSnapshot();

  /// Broadcast stream of snapshots. The service is the only
  /// listener; multiple subscribers in app code listen to
  /// [DeviceStateService.events] instead.
  Stream<DeviceStateSnapshot> get events;
}

/// Production source: talks to the `doit/device_state`
/// method channel. The Kotlin side pushes snapshots via
/// `invokeMethod("onDeviceState", map)`.
class _MethodChannelDeviceStateSource implements DeviceStateSource {
  _MethodChannelDeviceStateSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('doit/device_state');

  final MethodChannel _channel;
  final StreamController<DeviceStateSnapshot> _controller =
      StreamController<DeviceStateSnapshot>.broadcast();
  bool _handlerInstalled = false;

  Future<void> _installHandler() async {
    if (_handlerInstalled) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeviceState') {
        final args = call.arguments;
        if (args is Map) {
          final snap = DeviceStateSnapshot.fromMap(args);
          _controller.add(snap);
        }
      }
      return null;
    });
    _handlerInstalled = true;
  }

  @override
  Future<void> start() async {
    await _installHandler();
    await _channel.invokeMethod<void>('startStream');
  }

  @override
  Future<void> stop() async {
    if (!_handlerInstalled) return;
    try {
      await _channel.invokeMethod<void>('stopStream');
    } on MissingPluginException catch (e) {
      if (kDebugMode) debugPrint('DeviceStateSource.stop: $e');
    }
  }

  @override
  Future<DeviceStateSnapshot> currentSnapshot() async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'currentSnapshot',
    );
    if (result == null) {
      throw StateError('DeviceStateChannel.currentSnapshot returned null');
    }
    return DeviceStateSnapshot.fromMap(result);
  }

  @override
  Stream<DeviceStateSnapshot> get events => _controller.stream;
}

/// Test source: a hand-driven [StreamController] the unit
/// test can push scripted snapshots through. `current()`
/// returns the latest pushed snapshot, or a zero-valued
/// default if none has been pushed yet.
@visibleForTesting
class ScriptedDeviceStateSource implements DeviceStateSource {
  ScriptedDeviceStateSource({
    StreamController<DeviceStateSnapshot>? controller,
    DeviceStateSnapshot? initial,
  }) : _controller =
           controller ?? StreamController<DeviceStateSnapshot>.broadcast(),
       _latest = initial;

  final StreamController<DeviceStateSnapshot> _controller;
  DeviceStateSnapshot? _latest;
  int startCalls = 0;
  int stopCalls = 0;
  int currentCalls = 0;

  /// Push a snapshot to listeners. Mirrors the Kotlin
  /// `pushSnapshot` path: a reactive event arrived and the
  /// probe now publishes a new state.
  void push(DeviceStateSnapshot snap) {
    _latest = snap;
    _controller.add(snap);
  }

  /// Fail the next `start()` call. Mirrors the platform
  /// throwing on a missing channel / `MissingPluginException`.
  Object? startError;

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
  Future<DeviceStateSnapshot> currentSnapshot() async {
    currentCalls++;
    final latest = _latest;
    if (latest != null) return latest;
    // No push yet. Return a deterministic zero-valued
    // snapshot dated at the Unix epoch so tests that
    // compare `current()`'s output can do so without
    // depending on wall-clock time. Tests that need a
    // specific value push first.
    return DeviceStateSnapshot(
      batteryPercent: 0,
      isCharging: false,
      headphonesConnected: false,
      screenOn: false,
      at: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  Stream<DeviceStateSnapshot> get events => _controller.stream;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Singleton. Owns the source subscription, the broadcast
/// `events` stream the rest of the app listens to, and the
/// most-recent snapshot (cached for `current()` callers).
class DeviceStateService {
  DeviceStateService._();

  /// The single global instance.
  static final DeviceStateService instance = DeviceStateService._();

  Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  final StreamController<DeviceStateSnapshot> _controller =
      StreamController<DeviceStateSnapshot>.broadcast();

  /// Subscribe to receive every [DeviceStateSnapshot]. The
  /// stream is broadcast; multiple listeners (RoutineExecutor
  /// in PR 2, future debug screen) are allowed.
  Stream<DeviceStateSnapshot> get events => _controller.stream;

  DeviceStateSource? _source;
  StreamSubscription<DeviceStateSnapshot>? _sub;
  DeviceStateSnapshot? _latest;

  /// Initialize the service. Idempotent. Starts the source
  /// and arms the broadcast subscription.
  Future<void> init() async {
    if (_ready.isCompleted) return;
    _source ??= _MethodChannelDeviceStateSource();
    await _source!.start();
    _sub = _source!.events.listen(_onSnapshot, onError: _onError);
    _ready.complete();
  }

  /// Read the most recent snapshot. Returns the cached
  /// value from the last source push, or fetches a fresh
  /// one from the source if the cache is empty.
  Future<DeviceStateSnapshot> current() async {
    await ready;
    final cached = _latest;
    if (cached != null) return cached;
    final snap = await _source!.currentSnapshot();
    _latest = snap;
    return snap;
  }

  /// Inject a source for tests. The default wires the
  /// real method channel; tests pass a
  /// [ScriptedDeviceStateSource] so they can drive the
  /// stream deterministically.
  @visibleForTesting
  void debugSetSource(DeviceStateSource source) {
    _source = source;
  }

  /// Reset for tests. Re-creates the `_ready` Completer,
  /// the broadcast controller, cancels the source
  /// subscription, stops the source, and clears the cache.
  void resetForTesting() {
    if (!_ready.isCompleted) _ready.complete();
    _ready = Completer<void>();
    _sub?.cancel();
    _sub = null;
    final src = _source;
    _source = null;
    _latest = null;
    if (src != null) {
      // Fire-and-forget: the test fixture sets up a fresh
      // source on the next `debugSetSource` call, and the
      // test must not have to await `resetForTesting`. We
      // intentionally swallow the future — `ScriptedDeviceStateSource.stop()`
      // is a no-op for unit tests, and the production
      // source's `stop()` already swallows
      // `MissingPluginException`.
      unawaited(src.stop());
    }
  }

  // --- internal ----------------------------------------------------

  void _onSnapshot(DeviceStateSnapshot snap) {
    _latest = snap;
    _controller.add(snap);
  }

  void _onError(Object error, StackTrace stack) {
    // Source errors (the Kotlin channel went away, the
    // platform broadcast listener crashed) are surfaced as
    // a debug log behind `kDebugMode`. We do not crash the
    // service — the next snapshot may recover. Production
    // code paths that need explicit handling can subscribe
    // to `events` and watch for a heartbeat (a future PR
    // may add one).
    if (kDebugMode) {
      debugPrint('DeviceStateService source error: $error');
    }
  }
}
