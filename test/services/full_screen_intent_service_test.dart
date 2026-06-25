// Unit tests for `FullScreenIntentService`
// (v1.3c / Phase 14 / SYS-113 / ADR-043).
//
// The service is a thin Dart wrapper over the
// `doit/full_screen` Kotlin method channel
// (`FullScreenIntentChannel.kt`). The wrapper exposes
// `isGranted()` (one-shot probe via
// `NotificationManager.canUseFullScreenIntent()` on API 32+)
// and `openSettings()` (deep-link to
// `Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT` on
// API 34+, falling back to
// `Settings.ACTION_APPLICATION_SETTINGS` on API 32/33).
//
// These tests use `ScriptedFullScreenIntentSource` (the
// hand-driven test seam) so they do not need the platform
// channel. The Kotlin-side probe logic is covered by the
// `FullScreenIntentChannel` integration test (manual device
// check on a real Android 14 device; see CHANGELOG v1.3c
// "Deferred" section).

import 'package:doit/services/full_screen_intent_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isGranted', () {
    test('returns true when the scripted source is granted', () async {
      final svc = FullScreenIntentService.debugInstance(
        source: ScriptedFullScreenIntentSource(initialIsGranted: true),
      );
      await svc.init();
      expect(await svc.isGranted(), isTrue);
    });

    test('returns false when the scripted source is not granted', () async {
      final svc = FullScreenIntentService.debugInstance(
        source: ScriptedFullScreenIntentSource(),
      );
      await svc.init();
      expect(await svc.isGranted(), isFalse);
    });

    test('reflects setGranted() updates (the "user toggled the '
        'permission in Settings" simulation)', () async {
      final source = ScriptedFullScreenIntentSource();
      final svc = FullScreenIntentService.debugInstance(source: source);
      await svc.init();
      expect(await svc.isGranted(), isFalse);
      source.setGranted(granted: true);
      expect(await svc.isGranted(), isTrue);
    });
  });

  group('openSettings', () {
    test('returns true when the system Settings activity resolved', () async {
      final source = ScriptedFullScreenIntentSource();
      final svc = FullScreenIntentService.debugInstance(source: source);
      await svc.init();
      expect(await svc.openSettings(), isTrue);
      expect(source.openSettingsCalls, 1);
    });

    test('returns false when no activity handled the intent', () async {
      final source = ScriptedFullScreenIntentSource(
        initialOpenSettingsResult: false,
      );
      final svc = FullScreenIntentService.debugInstance(source: source);
      await svc.init();
      expect(await svc.openSettings(), isFalse);
      expect(source.openSettingsCalls, 1);
    });

    test('records every call (the AppLifecycleState.resumed '
        're-probe path may invoke it twice)', () async {
      final source = ScriptedFullScreenIntentSource();
      final svc = FullScreenIntentService.debugInstance(source: source);
      await svc.init();
      await svc.openSettings();
      await svc.openSettings();
      expect(source.openSettingsCalls, 2);
    });
  });

  group('singleton lifecycle', () {
    test('init() is idempotent (multiple calls resolve '
        'immediately)', () async {
      final svc = FullScreenIntentService.debugInstance(
        source: ScriptedFullScreenIntentSource(initialIsGranted: true),
      );
      await svc.init();
      // Second call must not throw and must not block.
      await svc.init();
      expect(await svc.isGranted(), isTrue);
    });

    test('resetForTesting() installs a new source + resets '
        'the ready gate', () async {
      final source1 = ScriptedFullScreenIntentSource();
      final svc = FullScreenIntentService.debugInstance(source: source1);
      await svc.init();
      expect(await svc.isGranted(), isFalse);

      final source2 = ScriptedFullScreenIntentSource(initialIsGranted: true);
      svc.resetForTesting(source: source2);
      await svc.init();
      expect(await svc.isGranted(), isTrue);
    });
  });
}
