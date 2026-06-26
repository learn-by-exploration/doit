// SharedPreferences-backed cache for the home widget state
// (v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042).
//
// This is the Dart-side mirror of the Kotlin
// `WidgetStateCache.kt`. The two caches are written in
// lockstep — the Dart side writes here, then asks the
// Kotlin side to persist via `WidgetBridge.cacheSnapshot`.
// The Dart cache exists for two reasons:
//   1. Fast in-process reads (no MethodChannel round-trip
//      on every `WidgetService` derive).
//   2. Test parity — widget tests read the cache without
//      touching the platform.
//
// In production both caches always hold the same JSON.
// In tests only the Dart cache is consulted; the Kotlin
// cache is bypassed via [FakeWidgetBridge].

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:doit/widget/doit_widget_state.dart';

class WidgetStateCache {
  WidgetStateCache._();

  /// Singleton instance. Tests reset via [resetForTesting].
  static final WidgetStateCache instance = WidgetStateCache._();

  /// Bump on schema change. v1 = the initial shape.
  static const String cacheKey = 'doit.widget.cached_v1';

  /// In-process snapshot of the last [save] call. `null`
  /// until the first save completes.
  DoitWidgetState? _cached;

  /// Read the cached state, or `null` if no cache has
  /// ever been written. The Dart cache is checked first;
  /// if empty, the SharedPreferences round-trip happens.
  Future<DoitWidgetState?> load() async {
    if (_cached != null) return _cached;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      _cached = DoitWidgetState.fromJson(json);
      return _cached;
    } catch (_) {
      // Corrupt cache: drop it so the next save writes
      // a clean entry.
      await prefs.remove(cacheKey);
      return null;
    }
  }

  /// Synchronous read of the in-process snapshot. Useful
  /// when the caller just computed the state and wants to
  /// consult the same value in the same microtask (no
  /// `await` needed). Returns `null` if [load] or [save]
  /// has not yet been called.
  DoitWidgetState? get cached => _cached;

  /// Write the state to the cache. Overwrites any prior
  /// entry.
  Future<void> save(DoitWidgetState state) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(state.toJson());
    await prefs.setString(cacheKey, raw);
    _cached = state;
  }

  /// Drop the cache. Called from
  /// `DoitWidgetProvider.onDisabled` (last widget removed).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cacheKey);
    _cached = null;
  }

  /// Test hook. Resets the in-process snapshot without
  /// touching SharedPreferences. Tests that use
  /// `SharedPreferences.setMockInitialValues({})` should
  /// pair that with `WidgetStateCache.instance.resetForTesting()`.
  void resetForTesting() {
    _cached = null;
  }
}
