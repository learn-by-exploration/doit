// Platform bridge for the home widget state (v1.4a / Phase
// 28 / SYS-115 / ADR-045 / WF-042).
//
// The Kotlin side (`WidgetChannel.kt`) and the Dart side
// (`PlatformWidgetBridge`) talk over the `doit/widget`
// MethodChannel. The contract:
//   - Dart → Kotlin `markDone(habitId)`: the user tapped
//     the widget's "Done" button. The Kotlin side
//     broadcasts `ACTION_MARK_DONE` to `DoitWidgetProvider`
//     and asks the provider to repaint via
//     `WidgetUpdater.refreshAll`.
//   - Dart → Kotlin `cacheSnapshot(json)`: the Dart side
//     writes the freshly-computed state to the
//     `WidgetStateCache` SharedPreferences so the cold-
//     start fallback has the last-known state.
//
// The Kotlin side does NOT own completion writes. Every
// write goes through Dart's `CompletionLogService` so the
// `CompletionSource` audit is consistent (widget "Done"
// is recorded as `CompletionSource.manual`, matching the
// home-tile "Done" tap).
//
// Tests swap in a [FakeWidgetBridge] that records calls
// without touching the platform.

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';

import 'package:doit/widget/doit_widget_state.dart';

/// Public surface for the home widget bridge.
abstract class WidgetBridge {
  /// Persist the freshly-computed [state] to the platform
  /// cache (SharedPreferences on Android). Returns when
  /// the write completes; the widget host process may be
  /// killed at any time, so this is best-effort but
  /// synchronous.
  Future<void> cacheSnapshot(DoitWidgetState state);

  /// Notify the platform that the widget state has
  /// changed. The Kotlin side broadcasts `ACTION_REFRESH_WIDGET`
  /// so `DoitWidgetProvider.onReceive` repaints every
  /// bound widget id. Defensive: a `MissingPluginException`
  /// (ADR-013) is swallowed — the cache has already been
  /// written, so the next widget update cycle picks up
  /// the new state.
  Future<void> requestRefresh();

  /// Round-trip used by tests + debug surfaces. Returns
  /// the live serialized state. Production code reads
  /// the cached JSON via [cacheSnapshot] + the platform
  /// `WidgetStateCache` directly; this method exists for
  /// test parity with the MethodChannel.
  Future<DoitWidgetState?> snapshot();
}

/// Production implementation of [WidgetBridge]. Wraps a
/// [MethodChannel] for `doit/widget`.
class PlatformWidgetBridge implements WidgetBridge {
  PlatformWidgetBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('doit/widget');

  final MethodChannel _channel;

  @override
  Future<void> cacheSnapshot(DoitWidgetState state) async {
    await _safe('cacheSnapshot', () async {
      await _channel.invokeMethod<void>('cacheSnapshot', state.toJson());
    });
  }

  @override
  Future<void> requestRefresh() async {
    await _safe('requestRefresh', () async {
      await _channel.invokeMethod<void>('requestRefresh');
    });
  }

  @override
  Future<DoitWidgetState?> snapshot() async {
    return _safeResult<DoitWidgetState>('snapshot', () async {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'snapshot',
      );
      if (result == null) return null;
      return DoitWidgetState.fromJson(
        result.map((k, v) => MapEntry(k.toString(), v)),
      );
    });
  }

  /// Defense-in-depth (ADR-013): swallows
  /// `MissingPluginException` and other platform-side
  /// failures behind [kDebugMode]. The widget must never
  /// crash the home screen on a platform-side hiccup.
  Future<void> _safe(String label, Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PlatformWidgetBridge.$label: $e');
      }
    }
  }

  Future<T?> _safeResult<T>(String label, Future<T?> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PlatformWidgetBridge.$label: $e');
      }
      return null;
    }
  }
}

/// Test bridge — records every call without touching the
/// platform.
class FakeWidgetBridge implements WidgetBridge {
  /// Every snapshot the bridge has cached, in order.
  /// Newer snapshots are appended.
  final List<DoitWidgetState> cachedSnapshots = <DoitWidgetState>[];

  /// Number of `requestRefresh` calls.
  int refreshCount = 0;

  /// What the next [snapshot] call returns. Tests
  /// override this to simulate a platform-side read.
  DoitWidgetState? nextSnapshot;

  @override
  Future<void> cacheSnapshot(DoitWidgetState state) async {
    cachedSnapshots.add(state);
  }

  @override
  Future<void> requestRefresh() async {
    refreshCount++;
  }

  @override
  Future<DoitWidgetState?> snapshot() async {
    return nextSnapshot;
  }
}
