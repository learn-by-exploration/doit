// Unit tests for `UsageStatsService` (v1.1g / ADR-030 /
// SYS-086).
//
// The service is a thin Dart wrapper over the
// `doit/device_state` Kotlin method channel
// (`DeviceStateChannel.kt`). The wrapper exposes
// `isGranted()` (one-shot probe) and `openSettings()`
// (deep-link to Settings → Special access → Usage access).
//
// These tests use `ScriptedUsageStatsSource` (the
// hand-driven test seam) so they do not need the platform
// channel. The Kotlin-side probe logic is covered by the
// device-state integration tests.

import 'package:doit/services/usage_stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isGranted', () {
    test('returns true when the scripted source is granted', () async {
      final svc = UsageStatsService.debugInstance(
        source: ScriptedUsageStatsSource(initialIsGranted: true),
      );
      await svc.init();
      expect(await svc.isGranted(), isTrue);
    });

    test('returns false when the scripted source is not granted', () async {
      final svc = UsageStatsService.debugInstance(
        source: ScriptedUsageStatsSource(),
      );
      await svc.init();
      expect(await svc.isGranted(), isFalse);
    });

    test('reflects setGranted() updates (the "user toggled the '
        'permission in Settings" simulation)', () async {
      final source = ScriptedUsageStatsSource();
      final svc = UsageStatsService.debugInstance(source: source);
      await svc.init();
      expect(await svc.isGranted(), isFalse);
      source.setGranted(granted: true);
      expect(await svc.isGranted(), isTrue);
    });
  });

  group('openSettings', () {
    test('returns true when the OEM Settings activity resolved', () async {
      final source = ScriptedUsageStatsSource();
      final svc = UsageStatsService.debugInstance(source: source);
      await svc.init();
      expect(await svc.openSettings(), isTrue);
      expect(source.openSettingsCalls, 1);
    });

    test('returns false when no activity handled the intent', () async {
      final source = ScriptedUsageStatsSource(initialOpenSettingsResult: false);
      final svc = UsageStatsService.debugInstance(source: source);
      await svc.init();
      expect(await svc.openSettings(), isFalse);
      expect(source.openSettingsCalls, 1);
    });

    test('records every call (the AppLifecycleState.resumed '
        're-probe path may invoke it twice)', () async {
      final source = ScriptedUsageStatsSource();
      final svc = UsageStatsService.debugInstance(source: source);
      await svc.init();
      await svc.openSettings();
      await svc.openSettings();
      expect(source.openSettingsCalls, 2);
    });
  });

  group('singleton lifecycle', () {
    test('init() is idempotent (multiple calls resolve '
        'immediately)', () async {
      final svc = UsageStatsService.debugInstance(
        source: ScriptedUsageStatsSource(initialIsGranted: true),
      );
      await svc.init();
      // Second call must not throw and must not block.
      await svc.init();
      expect(await svc.isGranted(), isTrue);
    });

    test('resetForTesting() installs a new source + resets '
        'the ready gate', () async {
      final source1 = ScriptedUsageStatsSource();
      final svc = UsageStatsService.debugInstance(source: source1);
      await svc.init();
      expect(await svc.isGranted(), isFalse);

      final source2 = ScriptedUsageStatsSource(initialIsGranted: true);
      svc.resetForTesting(source: source2);
      await svc.init();
      expect(await svc.isGranted(), isTrue);
    });
  });
}
