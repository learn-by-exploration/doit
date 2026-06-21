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
//
// v1.1 (SYS-080) adds the [routines] registry: a per-template
// map of `RoutineConfig` values, keyed by template id, persisted
// under `doit.routine.<templateId>`. The registry is independent
// of the v1.0 [japanRoutine] config — ADR-025 captures the
// "no migration" decision.

import 'dart:async' show Completer;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart'
    show ChangeNotifier, ValueNotifier, debugPrint, kDebugMode;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:doit/services/japan_routine_config.dart';
import 'package:doit/services/routine_config.dart';
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

  /// v1.1 (SYS-080). The user's template-driven routine
  /// configurations, keyed by template id. Empty at first
  /// launch; populated by [setRoutine]. The map is exposed
  /// as a [ValueNotifier] so widgets / `RoutineExecutor`
  /// can `addListener` on changes. The map value is
  /// unmodifiable; mutations go through [setRoutine] so
  /// the persistence layer stays in sync.
  final ValueNotifier<Map<String, RoutineConfig>> routines =
      ValueNotifier<Map<String, RoutineConfig>>(<String, RoutineConfig>{});

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

  /// v1.1 (SYS-080). Prefix for per-template routine keys. The
  /// full key is `_kRoutinesPrefix + templateId`. One key per
  /// template; each value is the JSON encoding of a
  /// [RoutineConfig] (see `RoutineConfig.toJson`).
  static const String _kRoutinesPrefix = 'doit.routine.';

  /// Idempotent init. Loads the persisted values; safe to call
  /// multiple times (the gate is completed on the first call and
  /// subsequent calls are no-ops).
  Future<void> init() async {
    if (_ready.isCompleted) return;
    _prefs = await SharedPreferences.getInstance();
    firstLaunchCompleted.value =
        _prefs.getBool(_kFirstLaunchCompletedKey) ?? false;
    japanRoutine.value = _loadJapanRoutine();
    routines.value = _loadRoutines();
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

  /// v1.1 (SYS-080). Walk every SharedPreferences key under
  /// [_kRoutinesPrefix] and decode each as a [RoutineConfig].
  /// Malformed payloads are dropped (and `debugPrint`-logged
  /// behind [kDebugMode]) so a single bad row does not
  /// invalidate the whole install.
  Map<String, RoutineConfig> _loadRoutines() {
    final out = <String, RoutineConfig>{};
    for (final k in _prefs.getKeys()) {
      if (!k.startsWith(_kRoutinesPrefix)) continue;
      final raw = _prefs.getString(k);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          throw const FormatException('expected JSON object');
        }
        final cfg = RoutineConfig.fromJson(decoded.cast<String, Object?>());
        out[cfg.templateId] = cfg;
      } on FormatException catch (e) {
        if (kDebugMode) {
          debugPrint(
            'SettingsService._loadRoutines: ignoring malformed '
            'value at $k: $e',
          );
        }
      }
    }
    return Map<String, RoutineConfig>.unmodifiable(out);
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

  /// v1.1 (SYS-080). Persist a template-driven routine
  /// configuration. The [config]'s `templateId` is the
  /// SharedPreferences key suffix; saving the same template
  /// twice overwrites the prior value. The in-memory
  /// [routines] notifier is updated synchronously before the
  /// await on `_prefs.setString` so listeners (e.g., the
  /// `RoutineExecutor`) see the new value immediately.
  Future<void> setRoutine(RoutineConfig config) async {
    await _ready.future;
    final next = <String, RoutineConfig>{
      ...routines.value,
      config.templateId: config,
    };
    routines.value = Map<String, RoutineConfig>.unmodifiable(next);
    await _prefs.setString(
      _kRoutinesPrefix + config.templateId,
      jsonEncode(config.toJson()),
    );
  }

  /// v1.1 (SYS-083). Remove a template-driven routine
  /// configuration. Idempotent: deleting a template id that
  /// was never saved is a no-op. The in-memory [routines]
  /// notifier is updated synchronously, then the backing
  /// store is cleared. Used by the generic apply UX
  /// ([RoutineApplyScreen]) so the user can un-apply a
  /// routine without re-installing the app.
  Future<void> deleteRoutine(String templateId) async {
    await _ready.future;
    if (!routines.value.containsKey(templateId)) return;
    final next = <String, RoutineConfig>{...routines.value}..remove(templateId);
    routines.value = Map<String, RoutineConfig>.unmodifiable(next);
    await _prefs.remove(_kRoutinesPrefix + templateId);
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
    routines.value = const <String, RoutineConfig>{};
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
