// UsageStatsService — Dart-side singleton that probes the
// `PACKAGE_USAGE_STATS` special-access permission and
// deep-links the user to its system Settings page.
//
// v1.1g / ADR-030 / SYS-086. The permission is intentionally
// NOT requested via the runtime prompt flow because
// Android never shows one for it. The user MUST navigate to
// Settings → Special access → Usage access and toggle do
// it on. The rationale UX for that flow lives in
// `lib/widgets/permission_sheet.dart`; this service is the
// platform side of the same flow.
//
// v1.1g ships the permission kind, the probe, the deep-link
// helper, and the rationale copy. v1.2 will wire the
// planned `TriggerForegroundApp` (a device-state leaf that
// fires when the user opens a configured app) on top of
// the same `PermissionKind.usageStats` entry.
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

/// Abstract source the [UsageStatsService] reads from.
/// Production wires [_MethodChannelUsageStatsSource];
/// tests wire [ScriptedUsageStatsSource].
abstract class UsageStatsSource {
  /// Returns true if the `PACKAGE_USAGE_STATS` permission
  /// is currently granted. Returns false on a platform-
  /// channel error (the v0.4b-release-fix lesson: a missing
  /// plugin must not crash the app).
  Future<bool> isGranted();

  /// Deep-links the user to Settings → Special access →
  /// Usage access. Returns true if the launch resolved
  /// (i.e., the OEM Settings activity exists). Returns
  /// false if no activity handled the intent.
  Future<bool> openSettings();
}

/// Production source: talks to the `doit/device_state`
/// method channel (the same one `DeviceStateService` uses).
/// The Kotlin side
/// (`android/.../DeviceStateChannel.kt`, v1.1g addition)
/// handles the `isUsageStatsGranted` and
/// `openUsageAccessSettings` methods.
class _MethodChannelUsageStatsSource implements UsageStatsSource {
  _MethodChannelUsageStatsSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('doit/device_state');

  final MethodChannel _channel;

  @override
  Future<bool> isGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>('isUsageStatsGranted');
      return result ?? false;
    } on MissingPluginException catch (e) {
      if (kDebugMode) debugPrint('UsageStatsSource.isGranted: $e');
      return false;
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('UsageStatsSource.isGranted: $e');
      return false;
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'openUsageAccessSettings',
      );
      return result ?? false;
    } on MissingPluginException catch (e) {
      if (kDebugMode) debugPrint('UsageStatsSource.openSettings: $e');
      return false;
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('UsageStatsSource.openSettings: $e');
      return false;
    }
  }
}

/// Test source: hand-driven, no platform channel.
@visibleForTesting
class ScriptedUsageStatsSource implements UsageStatsSource {
  ScriptedUsageStatsSource({
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

  /// Test hook: simulate an OEM that does not ship the
  /// standard usage-access Settings activity.
  void setOpenSettingsResult({required bool resolved}) {
    _openSettingsResult = resolved;
  }
}

/// Singleton holder for the usage-stats probe. Same shape
/// as the other services in `lib/services/`.
class UsageStatsService {
  UsageStatsService._({UsageStatsSource? source})
    : _source = source ?? _MethodChannelUsageStatsSource();

  /// The single global instance. Tests reach for the
  /// `@visibleForTesting` [debugInstance] factory + the
  /// [resetForTesting] + [init] seam instead.
  static final UsageStatsService instance = UsageStatsService._();

  /// Test-only factory. Production code uses the
  /// [UsageStatsService.instance] singleton; tests
  /// construct isolated instances via this factory and
  /// wire a [ScriptedUsageStatsSource].
  @visibleForTesting
  factory UsageStatsService.debugInstance({required UsageStatsSource source}) =>
      UsageStatsService._(source: source);

  UsageStatsSource _source;
  Completer<void> _ready = Completer<void>()..complete();
  Future<void> get ready => _ready.future;

  /// Idempotent. The default source is the production
  /// method-channel source; tests can swap it before
  /// calling [init] via [resetForTesting].
  ///
  /// Unlike the other services in `lib/services/`, this
  /// service has no async init work — the platform side is
  /// a stateless probe + a deep-link. The `_ready` gate
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

  /// Returns true if `PACKAGE_USAGE_STATS` is currently
  /// granted. Returns false on any platform error (see the
  /// `MissingPluginException` / `PlatformException` catches
  /// in `_MethodChannelUsageStatsSource`).
  Future<bool> isGranted() async {
    await ready;
    return _source.isGranted();
  }

  /// Deep-links the user to Settings → Special access →
  /// Usage access. Returns true if the launch resolved.
  Future<bool> openSettings() async {
    await ready;
    return _source.openSettings();
  }

  /// Test-only: swap the source and reset the `_ready`
  /// gate. Call before [init] in the test's `setUp`.
  @visibleForTesting
  void resetForTesting({UsageStatsSource? source}) {
    _source = source ?? _MethodChannelUsageStatsSource();
    _ready = Completer<void>();
  }
}
