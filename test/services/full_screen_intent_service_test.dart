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
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The MethodChannel mock handler tests below touch
  // `TestDefaultBinaryMessengerBinding.instance` directly,
  // so the test binding must be initialized up front.
  TestWidgetsFlutterBinding.ensureInitialized();

  // v1.4-stab-C / Phase 43 / SYS-130 / ADR-061 / WF-058:
  // pin the defense-in-depth behavior on the production
  // MethodChannelFullScreenIntentSource. The kDebugMode
  // branch triggers the `debugPrint` call inside the
  // catches — we redirect it to silence the test output.
  // The restore is a no-op until setUp() installs the
  // captured `original`; tearDown is guarded so a
  // setUp failure does not throw on a stale late field.
  VoidCallback restoreDebugPrint = () {};
  setUp(() {
    final original = debugPrint;
    debugPrint = (_, {wrapWidth}) {};
    restoreDebugPrint = () => debugPrint = original;
  });
  tearDown(restoreDebugPrint);

  group('MethodChannelFullScreenIntentSource (production source)', () {
    const channel = MethodChannel('doit/full_screen');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('isGranted returns false when the platform throws PlatformException '
        '(defense-in-depth per ADR-061)', () async {
      // Arrange — a device whose NotificationManager
      // throws on the canUseFullScreenIntent query (a
      // known OEM quirk on some Android 12-13 builds).
      // The v1.4-stab-C audit asserts the production
      // source treats this as "not granted" rather than
      // propagating the exception to the caller.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(
              code: 'TEST_PLATFORM_ERROR',
              message: 'simulated NotificationManager failure',
            );
          });

      // Act
      final source = MethodChannelFullScreenIntentSource();
      final result = await source.isGranted();

      // Assert
      expect(result, isFalse);
    });

    test(
      'openSettings returns false when the platform throws PlatformException '
      '(defense-in-depth per ADR-061)',
      () async {
        // Arrange — a device whose
        // ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT activity
        // is missing (the fallback path on Android 12-13
        // goes to ACTION_APPLICATION_SETTINGS; some OEMs
        // strip both). The production source MUST treat
        // this as "did not resolve" so the caller can offer
        // an alternative Settings entry-point.
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              throw PlatformException(
                code: 'TEST_PLATFORM_ERROR',
                message: 'simulated Settings activity missing',
              );
            });

        // Act
        final source = MethodChannelFullScreenIntentSource();
        final result = await source.openSettings();

        // Assert
        expect(result, isFalse);
      },
    );

    test(
      'isGranted returns false when the platform throws MissingPluginException '
      '(no Kotlin arm — defense-in-depth per ADR-061)',
      () async {
        // Arrange — the v0.4b-release-fix lesson: a missing
        // plugin MUST NOT crash the app. The
        // v1.4-stab-C audit extends the same posture to
        // the production FSI source.
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              throw MissingPluginException(
                'No implementation found for method '
                'canUseFullScreenIntent on channel doit/full_screen',
              );
            });

        // Act
        final source = MethodChannelFullScreenIntentSource();
        final result = await source.isGranted();

        // Assert
        expect(result, isFalse);
      },
    );
  });

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
