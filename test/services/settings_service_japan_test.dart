// Tests for the Japan-routine persistence in SettingsService
// (v1.0 / Phase F PR 2 / SYS-075 / SYS-079 / ADR-019
// follow-up).
//
// Coverage:
//   - `japanRoutine` defaults to the off + empty + normal config.
//   - `setJapanRoutine(...)` updates the in-memory notifier AND
//     persists the three keys to SharedPreferences.
//   - A subsequent `init()` (after a `resetForTesting()`) re-loads
//     the persisted config — i.e. persistence survives a restart.
//   - Missing / unknown keys fall back to defaults: enabled=false,
//     empty contactIds, targetMode=normal.
//   - `resetForTesting()` clears the notifier back to defaults.

import 'package:doit/services/japan_routine_config.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/triggers/trigger.dart' show SilentMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();
  });

  tearDown(SettingsService.instance.resetForTesting);

  test('japanRoutine defaults to off / empty / normal', () {
    final v = SettingsService.instance.japanRoutine.value;
    expect(v.enabled, false);
    expect(v.contactIds, isEmpty);
    expect(v.targetMode, SilentMode.normal);
    expect(v, JapanRoutineConfig.defaults);
  });

  test('setJapanRoutine updates the notifier AND persists to '
      'SharedPreferences', () async {
    const config = JapanRoutineConfig(
      enabled: true,
      contactIds: <String>['+15551112222', '+15553334444'],
      targetMode: SilentMode.vibrate,
    );
    await SettingsService.instance.setJapanRoutine(config);

    // In-memory notifier reflects the new value.
    expect(SettingsService.instance.japanRoutine.value, equals(config));

    // SharedPreferences has the three keys.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('doit.japan_routine.enabled'), true);
    expect(prefs.getStringList('doit.japan_routine.contact_ids'), <String>[
      '+15551112222',
      '+15553334444',
    ]);
    expect(prefs.getString('doit.japan_routine.target_mode'), 'vibrate');
  });

  test('persistence survives a resetForTesting + re-init', () async {
    const config = JapanRoutineConfig(
      enabled: true,
      contactIds: <String>['+15559998888'],
      targetMode: SilentMode.silent,
    );
    await SettingsService.instance.setJapanRoutine(config);

    // Simulate an app restart.
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();

    final reloaded = SettingsService.instance.japanRoutine.value;
    expect(reloaded.enabled, true);
    expect(reloaded.contactIds, <String>['+15559998888']);
    expect(reloaded.targetMode, SilentMode.silent);
  });

  test('init() falls back to defaults on missing keys', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();
    expect(
      SettingsService.instance.japanRoutine.value,
      JapanRoutineConfig.defaults,
    );
  });

  test(
    'init() falls back to defaults on unknown target_mode wire value',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'doit.japan_routine.enabled': true,
        'doit.japan_routine.contact_ids': <String>['+15550001111'],
        'doit.japan_routine.target_mode': 'unknown_mode_string',
      });
      SettingsService.instance.resetForTesting();
      await SettingsService.instance.init();
      final v = SettingsService.instance.japanRoutine.value;
      expect(v.enabled, true);
      expect(v.contactIds, <String>['+15550001111']);
      // Unknown wire value defaults to normal.
      expect(v.targetMode, SilentMode.normal);
    },
  );

  test('resetForTesting() clears the notifier back to defaults', () async {
    await SettingsService.instance.setJapanRoutine(
      const JapanRoutineConfig(
        enabled: true,
        contactIds: <String>['+1'],
        targetMode: SilentMode.vibrate,
      ),
    );
    SettingsService.instance.resetForTesting();
    expect(
      SettingsService.instance.japanRoutine.value,
      JapanRoutineConfig.defaults,
    );
  });

  test('persisted contactIds list is captured as unmodifiable', () async {
    await SettingsService.instance.setJapanRoutine(
      const JapanRoutineConfig(
        enabled: true,
        contactIds: <String>['+1', '+2'],
        targetMode: SilentMode.normal,
      ),
    );
    expect(
      () => SettingsService.instance.japanRoutine.value.contactIds.add('+3'),
      throwsUnsupportedError,
      reason:
          'The persisted contactIds list must be unmodifiable — the same '
          'contract the routine executor reads from.',
    );
  });
}
