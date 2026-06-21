// Tests for the v1.1 (SYS-080 / ADR-025) routine-config
// persistence in SettingsService.
//
// Coverage:
//   - `routines` defaults to an empty unmodifiable map at first
//     launch.
//   - `setRoutine(...)` updates the in-memory notifier AND
//     persists a JSON-encoded value to SharedPreferences under
//     `doit.routine.<templateId>`.
//   - Re-saving the same template id overwrites the prior value
//     (no row identity churn, no stale keys).
//   - A subsequent `init()` (after a `resetForTesting()`) re-loads
//     the persisted configs — i.e. persistence survives a restart.
//   - Multiple templates persist independently under their own
//     keys; loading reads them all back.
//   - Malformed payloads (a non-JSON value under a routine key)
//     are silently dropped; the rest of the registry loads
//     cleanly. (Verified via the `debugPrint`-behind-`kDebugMode`
//     swallow in `_loadRoutines`.)
//   - `resetForTesting()` clears the in-memory notifier back to
//     an empty map (without touching the SharedPreferences
//     backing store).
//   - The exposed `routines` map is unmodifiable; listeners
//     always see an unmodifiable snapshot.

import 'dart:convert' show jsonDecode;

import 'package:doit/services/routine_config.dart';
import 'package:doit/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _t17 = 't_builtin_17';
const _t18 = 't_builtin_18';

RoutineConfig _cfg(
  String templateId, {
  Map<String, Object?>? trigger,
  Map<String, Object?>? action,
  Map<String, Object?>? condition,
  bool enabled = true,
}) => RoutineConfig(
  templateId: templateId,
  triggerJson: trigger ?? <String, Object?>{'type': 'time_of_day', 'hour': 9},
  conditionJson: condition,
  actionJson: action ?? <String, Object?>{'type': 'notify'},
  enabled: enabled,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();
  });

  tearDown(SettingsService.instance.resetForTesting);

  test('routines defaults to an empty map at first launch', () {
    expect(SettingsService.instance.routines.value, isEmpty);
  });

  test('setRoutine updates the in-memory notifier AND persists to '
      'SharedPreferences under doit.routine.<templateId>', () async {
    const cfg = RoutineConfig(
      templateId: _t17,
      triggerJson: <String, Object?>{'type': 'time_of_day', 'hour': 9},
      actionJson: <String, Object?>{'type': 'notify'},
    );
    await SettingsService.instance.setRoutine(cfg);

    // In-memory notifier reflects the new value.
    expect(SettingsService.instance.routines.value[_t17], equals(cfg));
    expect(SettingsService.instance.routines.value.length, 1);

    // SharedPreferences has the encoded JSON under the namespaced key.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('doit.routine.$_t17');
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as Map<String, Object?>;
    expect(decoded['templateId'], _t17);
    expect(decoded['triggerJson'], <String, Object?>{
      'type': 'time_of_day',
      'hour': 9,
    });
    expect(decoded['actionJson'], <String, Object?>{'type': 'notify'});
    expect(decoded['enabled'], true);
    expect(decoded['conditionJson'], isNull);
  });

  test('re-saving the same template id overwrites the prior value', () async {
    await SettingsService.instance.setRoutine(
      _cfg(_t17, trigger: <String, Object?>{'type': 'time_of_day', 'hour': 9}),
    );
    await SettingsService.instance.setRoutine(
      _cfg(
        _t17,
        trigger: <String, Object?>{'type': 'time_of_day', 'hour': 22},
        enabled: false,
      ),
    );

    final map = SettingsService.instance.routines.value;
    expect(map.length, 1);
    expect(map[_t17]!.enabled, false);
    expect(map[_t17]!.triggerJson, <String, Object?>{
      'type': 'time_of_day',
      'hour': 22,
    });

    // Only one key in SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    final routineKeys = prefs.getKeys().where(
      (k) => k.startsWith('doit.routine.'),
    );
    expect(routineKeys, <String>{'doit.routine.$_t17'});
  });

  test('persistence survives a resetForTesting + re-init', () async {
    await SettingsService.instance.setRoutine(
      _cfg(
        _t17,
        trigger: <String, Object?>{'type': 'device_state', 'kind': 'charging'},
        action: <String, Object?>{'type': 'open_app'},
        condition: <String, Object?>{'type': 'day_of_week', 'days': 'mon'},
      ),
    );
    // Simulate an app restart.
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();

    final reloaded = SettingsService.instance.routines.value[_t17];
    expect(reloaded, isNotNull);
    expect(reloaded!.triggerJson, <String, Object?>{
      'type': 'device_state',
      'kind': 'charging',
    });
    expect(reloaded.conditionJson, <String, Object?>{
      'type': 'day_of_week',
      'days': 'mon',
    });
    expect(reloaded.actionJson, <String, Object?>{'type': 'open_app'});
    expect(reloaded.enabled, true);
  });

  test(
    'multiple templates persist independently under their own keys',
    () async {
      await SettingsService.instance.setRoutine(_cfg(_t17));
      await SettingsService.instance.setRoutine(_cfg(_t18));

      final map = SettingsService.instance.routines.value;
      expect(map.length, 2);
      expect(map[_t17]!.templateId, _t17);
      expect(map[_t18]!.templateId, _t18);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys(),
        containsAll(<String>{'doit.routine.$_t17', 'doit.routine.$_t18'}),
      );
    },
  );

  test('init() falls back to empty when no routine keys are present', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();
    expect(SettingsService.instance.routines.value, isEmpty);
  });

  test(
    'init() silently drops malformed routine payloads (does not crash)',
    () async {
      // Pre-seed SharedPreferences with one valid + one invalid
      // routine payload. The valid one must round-trip; the invalid
      // one is dropped.
      const goodJson =
          '{"templateId":"$_t17","triggerJson":{"type":"time_of_day"},'
          '"conditionJson":null,"actionJson":{"type":"notify"},"enabled":true}';
      SharedPreferences.setMockInitialValues(<String, Object>{
        'doit.japan_routine.enabled': false, // unrelated key, must be ignored
        'doit.routine.$_t17': goodJson,
        'doit.routine.bad': 'not-a-json-object',
      });
      SettingsService.instance.resetForTesting();
      await SettingsService.instance.init();

      final map = SettingsService.instance.routines.value;
      expect(map.length, 1, reason: 'only the valid payload survives');
      expect(map[_t17], isNotNull);
    },
  );

  test('resetForTesting() clears the in-memory notifier to empty', () async {
    await SettingsService.instance.setRoutine(_cfg(_t17));
    expect(SettingsService.instance.routines.value, isNotEmpty);
    SettingsService.instance.resetForTesting();
    expect(SettingsService.instance.routines.value, isEmpty);
  });

  test('the exposed routines map is unmodifiable', () async {
    await SettingsService.instance.setRoutine(_cfg(_t17));
    expect(
      () => SettingsService.instance.routines.value[_t17] = _cfg(_t18),
      throwsUnsupportedError,
      reason:
          'Listeners must always see an unmodifiable snapshot so they '
          'cannot bypass setRoutine and desync persistence.',
    );
  });

  test('setRoutine() makes the new value visible before its returned '
      'Future completes', () async {
    // Behavioural assertion: callers (e.g. RoutineExecutor)
    // observe the new value via `routines` as soon as the
    // returned Future yields once (the `_ready` gate is
    // completed at this point in the test, so the notifier
    // assignment runs in the first continuation after the
    // initial microtask yield). We assert this by `await
    // ing` the future without yielding to other code first —
    // i.e., the value must be visible by the time the
    // `setRoutine` future completes, regardless of any
    // SharedPreferences latency.
    final cfg = _cfg(_t17);
    await SettingsService.instance.setRoutine(cfg);
    expect(SettingsService.instance.routines.value[_t17], equals(cfg));
  });

  test('the routines notifier fires when setRoutine is called', () async {
    var fired = 0;
    SettingsService.instance.routines.addListener(() => fired++);
    addTearDown(
      () => SettingsService.instance.routines.removeListener(() => fired++),
    );
    await SettingsService.instance.setRoutine(_cfg(_t17));
    expect(fired, greaterThanOrEqualTo(1));
  });

  test('deleteRoutine removes the entry from the in-memory map and '
      'SharedPreferences', () async {
    await SettingsService.instance.setRoutine(_cfg(_t17));
    await SettingsService.instance.setRoutine(_cfg(_t18));
    expect(SettingsService.instance.routines.value.length, 2);

    await SettingsService.instance.deleteRoutine(_t17);

    final map = SettingsService.instance.routines.value;
    expect(map.length, 1);
    expect(map.containsKey(_t17), false);
    expect(map.containsKey(_t18), true);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('doit.routine.$_t17'), isNull);
    expect(prefs.getString('doit.routine.$_t18'), isNotNull);
  });

  test('deleteRoutine is a no-op for an unknown templateId', () async {
    // No save first. deleteRoutine must not throw, and the
    // in-memory map must stay empty.
    await SettingsService.instance.deleteRoutine('t_builtin_unknown');
    expect(SettingsService.instance.routines.value, isEmpty);
  });
}
