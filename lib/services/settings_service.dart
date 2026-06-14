// Settings — minimal in-memory store for v0.1.
//
// Per .claude/rules/lib-services.md, services are singletons
// with an idempotent `init()`. The v0.1 service only stores
// the theme mode in memory; v0.2 will persist via
// `shared_preferences`.
//
// The settings screen binds to [themeMode] via a
// `ValueListenableBuilder` so changes propagate without
// rebuilding the entire app. The class also implements
// [ChangeNotifier] so it can be exposed via
// `ChangeNotifierProvider` (per .claude/rules/lib-screens.md).

import 'package:flutter/material.dart'
    show ChangeNotifier, ValueNotifier, ThemeMode;

/// Singleton holder for user-tweakable settings. The runtime
/// value lives in a [ValueNotifier] so widgets can listen
/// without going through a Provider rebuild.
class SettingsService extends ChangeNotifier {
  SettingsService._();

  /// The single global instance.
  static final SettingsService instance = SettingsService._();

  /// Theme mode. Defaults to [ThemeMode.dark] per the v0.1
  /// architecture decision.
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.dark,
  );

  /// Idempotent init. The v0.1 in-memory version is a no-op;
  /// v0.2 will load persisted values here.
  Future<void> init() async {}

  /// Test helper. Resets the singleton state.
  // ignore: use_setters_to_change_properties
  void resetForTesting() {
    themeMode.value = ThemeMode.dark;
  }

  @override
  void dispose() {
    // The singleton lives for the lifetime of the app; dispose
    // is here for ChangeNotifier compliance but the test
    // helper should reset state instead.
    super.dispose();
  }
}
