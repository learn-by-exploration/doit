// Settings — user-tweakable preferences, persisted via
// `shared_preferences` as of v0.4a.3.
//
// Per .claude/rules/lib-services.md, services are singletons
// with an idempotent `init()` gated by a `Completer<void> _ready`.
// The v0.1 service only stored the theme mode in memory;
// v0.4a.3 adds the `firstLaunchCompleted` flag (SYS-059) and
// routes the persisted read through `_ready.future`.
//
// The settings screen binds to [themeMode] via a
// `ValueListenableBuilder` so changes propagate without
// rebuilding the entire app. The class also implements
// [ChangeNotifier] so it can be exposed via
// `ChangeNotifierProvider` (per .claude/rules/lib-screens.md).

import 'dart:async' show Completer;

import 'package:flutter/foundation.dart' show ChangeNotifier, ValueNotifier;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:doit/services/japan_routine_config.dart';
import 'package:doit/triggers/trigger.dart' show SilentMode;

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

  /// `true` once the user has finished the onboarding flow at
  /// least once on this install. Defaults to `false`. Read by
  /// [DoItApp] to decide whether to show [OnboardingScreen] or
  /// [HomeScreen] as the initial route. Backed by
  /// [SharedPreferences] under [_kFirstLaunchCompletedKey].
  ///
  /// v0.4a.3 (SYS-059) introduces the persisted flag. v0.1..v0.3
  /// had this hard-coded `true` in [DoItApp]'s constructor,
  /// which meant the onboarding screen re-appeared on every
  /// reinstall.
  final ValueNotifier<bool> firstLaunchCompleted = ValueNotifier<bool>(false);

  /// The Android SAF tree URI the user picked for nightly
  /// auto-backups. `null` means "no folder picked yet" —
  /// the onboarding step 3 (SYS-066) sets it via
  /// [setBackupFolderUri] and the Settings → Restore
  /// screen re-picks on revocation. v0.5c / ADR-016.
  ///
  /// In-memory only for v0.5c; persistence to
  /// `SharedPreferences` lands with the v0.5d Settings
  /// tile that reads the URI at backup time. The
  /// `BackupService` reads this notifier at backup
  /// dispatch (a future commit).
  final ValueNotifier<String?> backupFolderUri = ValueNotifier<String?>(null);

  /// Phase F PR 2 (SYS-075 / SYS-079). The user's Japan
  /// silent-mode routine configuration. Defaults to
  /// [JapanRoutineConfig.defaults] (disabled, no contacts,
  /// silent→normal). The [AddRoutineScreen] writes via
  /// [setJapanRoutine]; the [CallInterceptorService]
  /// watches this notifier indirectly (the add screen also
  /// pushes the contacts via [CallInterceptorService.configure]).
  final ValueNotifier<JapanRoutineConfig> japanRoutine =
      ValueNotifier<JapanRoutineConfig>(JapanRoutineConfig.defaults);

  /// Init gate (`Completer<void> _ready`). Public reads wait on
  /// this before touching the underlying [SharedPreferences]
  /// instance. Pattern: see .claude/rules/lib-services.md §2.
  Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;
  late SharedPreferences _prefs;

  /// Key under which the `firstLaunchCompleted` boolean is
  /// persisted. Private to the service — widgets never read or
  /// write `SharedPreferences` directly (.claude/rules/lib-screens.md §5).
  static const String _kFirstLaunchCompletedKey = 'doit.first_launch_completed';

  /// Persisted keys for the Japan silent-mode routine. Three
  /// keys under one logical namespace — the bool is the
  /// master toggle, the string list is the contact-id
  /// whitelist, the string is the `SilentMode.wireName`.
  static const String _kJapanRoutineEnabledKey = 'doit.japan_routine.enabled';
  static const String _kJapanRoutineContactIdsKey =
      'doit.japan_routine.contact_ids';
  static const String _kJapanRoutineTargetModeKey =
      'doit.japan_routine.target_mode';

  /// Idempotent init. Loads the persisted values; safe to call
  /// multiple times (the gate is completed on the first call and
  /// subsequent calls are no-ops).
  Future<void> init() async {
    if (_ready.isCompleted) return;
    _prefs = await SharedPreferences.getInstance();
    firstLaunchCompleted.value =
        _prefs.getBool(_kFirstLaunchCompletedKey) ?? false;
    japanRoutine.value = _loadJapanRoutine();
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Decode the three Japan-routine keys into a
  /// [JapanRoutineConfig]. Missing keys fall back to
  /// [JapanRoutineConfig.defaults]. An unknown `target_mode`
  /// string falls back to [SilentMode.normal].
  JapanRoutineConfig _loadJapanRoutine() {
    final enabled = _prefs.getBool(_kJapanRoutineEnabledKey) ?? false;
    final contactIds =
        _prefs.getStringList(_kJapanRoutineContactIdsKey) ?? const <String>[];
    final modeWire = _prefs.getString(_kJapanRoutineTargetModeKey);
    final targetMode = switch (modeWire) {
      'silent' => SilentMode.silent,
      'vibrate' => SilentMode.vibrate,
      'normal' => SilentMode.normal,
      _ => SilentMode.normal,
    };
    return JapanRoutineConfig(
      enabled: enabled,
      contactIds: List<String>.unmodifiable(contactIds),
      targetMode: targetMode,
    );
  }

  /// Mark the first-launch onboarding as complete. Persists the
  /// value so the next [DoItApp] mount skips the onboarding
  /// screen. Awaiting this is safe in widget tests; in widget
  /// bodies, the [firstLaunchCompleted] [ValueNotifier] updates
  /// synchronously so a `setState` is not required.
  Future<void> markFirstLaunchCompleted() async {
    await _ready.future;
    firstLaunchCompleted.value = true;
    await _prefs.setBool(_kFirstLaunchCompletedKey, true);
  }

  /// Set the Android SAF tree URI the user picked for nightly
  /// auto-backups. v0.5c / ADR-016. The widget layer calls
  /// this from the onboarding step 3 success branch
  /// (SYS-066) and from the Settings → Restore screen when
  /// the user re-picks on revocation. Passing `null` clears
  /// the URI (revocation path).
  ///
  /// In-memory only for v0.5c; persistence to
  /// `SharedPreferences` lands with the v0.5d Settings tile
  /// that reads the URI at backup time.
  void setBackupFolderUri(String? uri) {
    backupFolderUri.value = uri;
  }

  /// Phase F PR 2 (SYS-075 / SYS-079). Persist the Japan
  /// silent-mode routine configuration. Awaiting this
  /// guarantees the keys are flushed before the caller
  /// pushes the contacts to [CallInterceptorService]
  /// (the screening service must already know about the
  /// contacts when an incoming call arrives).
  Future<void> setJapanRoutine(JapanRoutineConfig config) async {
    await _ready.future;
    japanRoutine.value = config;
    await _prefs.setBool(_kJapanRoutineEnabledKey, config.enabled);
    await _prefs.setStringList(
      _kJapanRoutineContactIdsKey,
      List<String>.unmodifiable(config.contactIds),
    );
    await _prefs.setString(_kJapanRoutineTargetModeKey, config.targetMode.name);
  }

  /// Test helper. Resets the singleton's in-memory state so the
  /// next [init()] re-loads from the `SharedPreferences` backing
  /// store. Does **not** touch the backing store itself; tests
  /// that want a wiped install call
  /// `SharedPreferences.setMockInitialValues({})` before the
  /// next [init()]. Tests that want to assert persistence
  /// across a restart call this helper and then re-`init()`.
  // ignore: use_setters_to_change_properties
  void resetForTesting() {
    themeMode.value = ThemeMode.dark;
    firstLaunchCompleted.value = false;
    backupFolderUri.value = null;
    japanRoutine.value = JapanRoutineConfig.defaults;
    // Allow a subsequent init() to re-load from the backing
    // store. Re-creating the completer is the standard pattern
    // when the gate has not yet been awaited in tests.
    _ready = Completer<void>();
  }

  @override
  void dispose() {
    // The singleton lives for the lifetime of the app; dispose
    // is here for ChangeNotifier compliance but the test
    // helper should reset state instead.
    super.dispose();
  }
}
