// FullScreenIntentService — Dart-side singleton that probes
// the `USE_FULL_SCREEN_INTENT` special-access permission
// (v1.3c / Phase 14 / SYS-113 / ADR-043) and deep-links the
// user to its system Settings page.
//
// On Android 14+ (API 34+) the OS suppresses full-screen
// intents from background-launched apps that don't hold
// `USE_FULL_SCREEN_INTENT`. The probe goes through
// `NotificationManager.canUseFullScreenIntent()` (added in
// API 32); on API < 32 the permission is implicit-granted
// (the Kotlin handler short-circuits with `true`). The
// deep-link target is `Settings
// .ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT` on API 34+;
// on API 32/33 (where the dedicated activity does not
// exist) the Kotlin side falls back to
// `Settings.ACTION_APPLICATION_SETTINGS`.
//
// The permission is intentionally NOT requested via the
// runtime prompt flow because Android never shows one for
// it. The user MUST navigate to Settings → Special access
// and toggle do it on. The rationale UX for that flow
// lives in `lib/widgets/permission_sheet.dart` (the
// `permissionKindMeta.fullScreenIntent` entry); this
// service is the platform side of the same flow.
//
// Layer rules (per `.claude/rules/lib-services.md`):
//   - Singleton with `Completer<void> _ready`.
//   - `init()` is idempotent.
//   - All public reads/writes `await _ready.future` first.
//   - No UI imports.

import 'dart:async' show Completer;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

/// Abstract source the [FullScreenIntentService] reads from.
/// Production wires [MethodChannelFullScreenIntentSource];
/// tests wire [ScriptedFullScreenIntentSource].
abstract class FullScreenIntentSource {
  /// Returns true if `USE_FULL_SCREEN_INTENT` is currently
  /// granted. Returns false on a platform-channel error
  /// (the v0.4b-release-fix lesson: a missing plugin must
  /// not crash the app).
  Future<bool> isGranted();

  /// Deep-links the user to the system Settings surface for
  /// `USE_FULL_SCREEN_INTENT`. Returns true if the launch
  /// resolved (i.e., a Settings activity handled the
  /// intent). Returns false if no activity handled the
  /// intent.
  Future<bool> openSettings();
}

/// Production source: talks to the `doit/full_screen`
/// method channel. The Kotlin side
/// (`android/.../FullScreenIntentChannel.kt`, v1.3c
/// addition) handles the `canUseFullScreenIntent` and
/// `openFullScreenIntentSettings` methods. The API-32 vs
/// API-34 asymmetry is resolved on the Kotlin side so the
/// Dart source is platform-agnostic.
///
/// **Defense-in-depth swallow (v1.4-stab-C / ADR-061 /
/// SYS-130 / WF-058).** Both [isGranted] and [openSettings]
/// wrap the `invokeMethod` call in `try`/`catch` and treat
/// ANY error — `MissingPluginException` (no Kotlin arm)
/// or `PlatformException` (channel-level failure, e.g., a
/// device whose `NotificationManager` throws on the
/// `canUseFullScreenIntent` query) — as `false`. This is
/// **intentional** per ADR-013: the v0.4b-release-fix lesson
/// was that a missing plugin MUST NOT crash the app; the
/// v1.4-stab-C audit extended this posture to all channel
/// errors because the home-screen reliability banner and
/// the Settings-tile deep-link both degrade gracefully to
/// `false`. The `ReliabilityService._safeProbe` wrapper at
/// `lib/services/reliability_service.dart` makes the same
/// choice; the patterns are deliberately identical.
///
/// A reader who is tempted to "fix" this by removing the
/// catches should first read ADR-013 + ADR-061 and then
/// audit every caller of [isGranted] and [openSettings] for
/// `null`-safety (the contract is `Future<bool>`, not
/// `Future<bool?>` — there is no error path).
@visibleForTesting
class MethodChannelFullScreenIntentSource implements FullScreenIntentSource {
  MethodChannelFullScreenIntentSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('doit/full_screen');

  final MethodChannel _channel;

  @override
  Future<bool> isGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'canUseFullScreenIntent',
      );
      return result ?? false;
    } on MissingPluginException catch (e) {
      // Defense-in-depth per ADR-013 / ADR-061: a missing
      // Kotlin arm MUST NOT crash the app. Returns false so
      // the reliability banner + Settings tile degrade
      // gracefully. See class-level KDoc above.
      if (kDebugMode) debugPrint('FullScreenIntentSource.isGranted: $e');
      return false;
    } on PlatformException catch (e) {
      // Defense-in-depth per ADR-013 / ADR-061: any
      // channel-level error (device-specific quirks in
      // NotificationManager.canUseFullScreenIntent, etc.)
      // is treated as "not granted" so the user can still
      // reach Settings via the openSettings() path.
      if (kDebugMode) debugPrint('FullScreenIntentSource.isGranted: $e');
      return false;
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'openFullScreenIntentSettings',
      );
      return result ?? false;
    } on MissingPluginException catch (e) {
      // Defense-in-depth per ADR-013 / ADR-061: a missing
      // Kotlin arm MUST NOT crash the app. Returns false so
      // the caller can fall back to a generic Settings
      // entry-point.
      if (kDebugMode) debugPrint('FullScreenIntentSource.openSettings: $e');
      return false;
    } on PlatformException catch (e) {
      // Defense-in-depth per ADR-013 / ADR-061: any
      // channel-level error (e.g., ACTION_MANAGE_APP_USE_
      // FULL_SCREEN_INTENT is not present on this device's
      // OEM Android version) is treated as "did not
      // resolve" so the caller can offer an alternative.
      if (kDebugMode) debugPrint('FullScreenIntentSource.openSettings: $e');
      return false;
    }
  }
}

/// Test source: hand-driven, no platform channel.
@visibleForTesting
class ScriptedFullScreenIntentSource implements FullScreenIntentSource {
  ScriptedFullScreenIntentSource({
    bool initialIsGranted = false,
    bool initialOpenSettingsResult = true,
  }) : _isGranted = initialIsGranted,
       _openSettingsResult = initialOpenSettingsResult;

  bool _isGranted;
  bool _openSettingsResult;

  /// Recorded every time [openSettings] is called. Tests
  /// assert on this list length.
  int openSettingsCalls = 0;

  @override
  Future<bool> isGranted() async => _isGranted;

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return _openSettingsResult;
  }

  /// Test hook: simulate the user toggling the permission
  /// on or off in system Settings.
  void setGranted({required bool granted}) {
    _isGranted = granted;
  }

  /// Test hook: simulate a device that does not ship the
  /// `ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT` activity.
  void setOpenSettingsResult({required bool resolved}) {
    _openSettingsResult = resolved;
  }
}

/// Singleton holder for the full-screen-intent probe. Same
/// shape as the other services in `lib/services/`.
class FullScreenIntentService {
  FullScreenIntentService._({FullScreenIntentSource? source})
    : _source = source ?? MethodChannelFullScreenIntentSource();

  /// The single global instance. Tests reach for the
  /// `@visibleForTesting` [debugInstance] factory + the
  /// [resetForTesting] + [init] seam instead.
  static final FullScreenIntentService instance = FullScreenIntentService._();

  /// Test-only factory. Production code uses the
  /// [FullScreenIntentService.instance] singleton; tests
  /// construct isolated instances via this factory and
  /// wire a [ScriptedFullScreenIntentSource].
  @visibleForTesting
  factory FullScreenIntentService.debugInstance({
    required FullScreenIntentSource source,
  }) => FullScreenIntentService._(source: source);

  FullScreenIntentSource _source;
  Completer<void> _ready = Completer<void>()..complete();
  Future<void> get ready => _ready.future;

  /// Idempotent. The default source is the production
  /// method-channel source; tests can swap it before
  /// calling [init] via [resetForTesting].
  ///
  /// Unlike some services in `lib/services/`, this service
  /// has no async init work — the platform side is a
  /// stateless probe + a deep-link. The `_ready` gate
  /// therefore starts in the completed state so production
  /// callers (e.g., [PermissionService.init]) can read
  /// `isGranted()` without first calling `init()`.
  /// [resetForTesting] is the only path that resets the
  /// gate (to give the test seam control of timing).
  Future<void> init() async {
    // No-op when already completed (the production path).
    if (_ready.isCompleted) return;
    _ready.complete();
  }

  /// Returns true if `USE_FULL_SCREEN_INTENT` is currently
  /// granted. Returns false on any platform error (see the
  /// `MissingPluginException` / `PlatformException` catches
  /// in `MethodChannelFullScreenIntentSource`).
  Future<bool> isGranted() async {
    await ready;
    return _source.isGranted();
  }

  /// Deep-links the user to the system Settings surface for
  /// `USE_FULL_SCREEN_INTENT`. Returns true if the launch
  /// resolved.
  Future<bool> openSettings() async {
    await ready;
    return _source.openSettings();
  }

  /// Test-only: swap the source and reset the `_ready`
  /// gate. Call before [init] in the test's `setUp`.
  @visibleForTesting
  void resetForTesting({FullScreenIntentSource? source}) {
    _source = source ?? MethodChannelFullScreenIntentSource();
    _ready = Completer<void>();
  }
}
