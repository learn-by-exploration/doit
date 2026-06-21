// Tests for RoutineConfig (v1.1 / SYS-080 / ADR-025).
//
// RoutineConfig is the persisted value class for a single
// template-driven routine (templates #17–#21). One row per
// template id, stored under `doit.routine.<templateId>` in
// SharedPreferences (managed by `SettingsService.setRoutine`).
//
// Coverage:
//   - Constructor defaults: `enabled = true`, `conditionJson =
//     null`.
//   - Structural equality across all five fields, including the
//     `conditionJson == null` vs `{}` distinction.
//   - `hashCode` agrees with `==` (a separate re-hashed instance
//     in the same hash bucket) so a fresh `copyWith` round-trips
//     through `Set` / `Map` keys.
//   - `hashCode` is stable across repeated reads (Dart 3.12's
//     `Object.hashAllUnordered` is non-deterministic, so the
//     implementation must not use it — see ADR-025).
//   - `copyWith` replaces only the named fields; omitted fields
//     preserve the prior value.
//   - `toJson` / `fromJson` codec round-trip across enabled/disabled,
//     with vs without conditionJson.
//   - `fromJson` rejects malformed payloads (templateId not a
//     string, triggerJson / actionJson / conditionJson not an
//     object, enabled not a bool).
//   - `toString` carries the discriminator types for debug print.

import 'package:doit/services/routine_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoutineConfig.constructor', () {
    test('defaults enabled to true and conditionJson to null', () {
      const c = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      expect(c.enabled, true);
      expect(c.conditionJson, isNull);
    });
  });

  group('equality + hashCode', () {
    test('two configs with the same fields are equal', () {
      const a = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day', 'hour': 9},
        conditionJson: <String, Object?>{'type': 'day_of_week', 'days': 'mon'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      const b = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day', 'hour': 9},
        conditionJson: <String, Object?>{'type': 'day_of_week', 'days': 'mon'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('two configs that differ on templateId are not equal', () {
      const a = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      const b = RoutineConfig(
        templateId: 't_builtin_18',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      expect(a, isNot(equals(b)));
    });

    test('two configs that differ on enabled are not equal', () {
      const a = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      const b = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        actionJson: <String, Object?>{'type': 'notify'},
        enabled: false,
      );
      expect(a, isNot(equals(b)));
    });

    test('two configs that differ on triggerJson are not equal', () {
      const a = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day', 'hour': 9},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      const b = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day', 'hour': 10},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      expect(a, isNot(equals(b)));
    });

    test('two configs that differ on actionJson are not equal', () {
      const a = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      const b = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        actionJson: <String, Object?>{'type': 'open_app'},
      );
      expect(a, isNot(equals(b)));
    });

    test('null conditionJson is not equal to empty conditionJson', () {
      const a = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      const b = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        conditionJson: <String, Object?>{},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('two configs that differ on conditionJson contents are not equal', () {
      const a = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        conditionJson: <String, Object?>{'type': 'day_of_week', 'days': 'mon'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      const b = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        conditionJson: <String, Object?>{'type': 'day_of_week', 'days': 'tue'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      expect(a, isNot(equals(b)));
    });

    test('hashCode is stable across repeated reads', () {
      const c = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        conditionJson: <String, Object?>{'type': 'day_of_week', 'days': 'mon'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      expect(c.hashCode, c.hashCode);
    });

    test('a config can be a Map key and round-trips through a Set', () {
      const a = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      const b = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      const c = RoutineConfig(
        templateId: 't_builtin_18',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      // Force `b` to a fresh non-canonicalized instance so the
      // Set test exercises runtime equality, not const
      // canonicalization.
      final set = <RoutineConfig>{a, b.copyWith(), c};
      expect(set.length, 2); // a and b collapse; c stays separate
    });
  });

  group('copyWith', () {
    test('omitting every field returns a structurally-equal config', () {
      const original = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        conditionJson: <String, Object?>{'type': 'day_of_week'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      final copy = original.copyWith();
      expect(copy, equals(original));
    });

    test('replaces only the named field', () {
      const original = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      final copy = original.copyWith(enabled: false);
      expect(copy.enabled, false);
      expect(copy.templateId, original.templateId);
      expect(copy.triggerJson, original.triggerJson);
      expect(copy.actionJson, original.actionJson);
    });

    test('replaces triggerJson and actionJson wholesale', () {
      const original = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      final newTrigger = <String, Object?>{
        'type': 'device_state',
        'kind': 'charging',
      };
      const newAction = <String, Object?>{'type': 'open_app'};
      final copy = original.copyWith(
        triggerJson: newTrigger,
        actionJson: newAction,
      );
      expect(copy.triggerJson, newTrigger);
      expect(copy.actionJson, newAction);
    });

    test('replaces a null conditionJson with a present one', () {
      const original = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      expect(original.conditionJson, isNull);
      final copy = original.copyWith(
        conditionJson: <String, Object?>{'type': 'day_of_week'},
      );
      expect(copy.conditionJson, isNotNull);
      expect(copy.conditionJson, <String, Object?>{'type': 'day_of_week'});
    });
  });

  group('toJson / fromJson codec', () {
    test('round-trips a config with no condition', () {
      const original = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day', 'hour': 9},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      final j = original.toJson();
      expect(j['conditionJson'], isNull);
      final decoded = RoutineConfig.fromJson(j);
      expect(decoded, equals(original));
    });

    test('round-trips a config with a present condition', () {
      const original = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day', 'hour': 9},
        conditionJson: <String, Object?>{'type': 'day_of_week', 'days': 'mon'},
        actionJson: <String, Object?>{'type': 'notify'},
        enabled: false,
      );
      final j = original.toJson();
      expect(j['enabled'], false);
      expect(j['conditionJson'], isNotNull);
      final decoded = RoutineConfig.fromJson(j);
      expect(decoded, equals(original));
    });

    test('fromJson throws on missing templateId type', () {
      const payload = <String, Object?>{
        'triggerJson': <String, Object?>{'type': 'time_of_day'},
        'actionJson': <String, Object?>{'type': 'notify'},
      };
      expect(
        () => RoutineConfig.fromJson(payload),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('templateId must be a string'),
          ),
        ),
      );
    });

    test('fromJson throws on missing triggerJson object', () {
      const payload = <String, Object?>{
        'templateId': 't_builtin_17',
        'triggerJson': 'not-an-object',
        'actionJson': <String, Object?>{'type': 'notify'},
      };
      expect(
        () => RoutineConfig.fromJson(payload),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('triggerJson must be a JSON object'),
          ),
        ),
      );
    });

    test('fromJson throws when triggerJson is a list (not a map)', () {
      const payload = <String, Object?>{
        'templateId': 't_builtin_17',
        'triggerJson': <Object?>['not-an-object'],
        'actionJson': <String, Object?>{'type': 'notify'},
      };
      expect(
        () => RoutineConfig.fromJson(payload),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('triggerJson must be a JSON object'),
          ),
        ),
      );
    });

    test('fromJson throws on missing actionJson object', () {
      const payload = <String, Object?>{
        'templateId': 't_builtin_17',
        'triggerJson': <String, Object?>{'type': 'time_of_day'},
        'actionJson': 'not-an-object',
      };
      expect(
        () => RoutineConfig.fromJson(payload),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('actionJson must be a JSON object'),
          ),
        ),
      );
    });

    test('fromJson throws when conditionJson is non-null and not a map', () {
      const payload = <String, Object?>{
        'templateId': 't_builtin_17',
        'triggerJson': <String, Object?>{'type': 'time_of_day'},
        'conditionJson': 'still-not-an-object',
        'actionJson': <String, Object?>{'type': 'notify'},
      };
      expect(
        () => RoutineConfig.fromJson(payload),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('conditionJson must be a JSON object or null'),
          ),
        ),
      );
    });

    test('fromJson throws on missing enabled bool', () {
      const payload = <String, Object?>{
        'templateId': 't_builtin_17',
        'triggerJson': <String, Object?>{'type': 'time_of_day'},
        'actionJson': <String, Object?>{'type': 'notify'},
        'enabled': 'yes',
      };
      expect(
        () => RoutineConfig.fromJson(payload),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('enabled must be a bool'),
          ),
        ),
      );
    });
  });

  group('toString', () {
    test('carries templateId, enabled, and the three discriminator types', () {
      const c = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        conditionJson: <String, Object?>{'type': 'day_of_week'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      final s = c.toString();
      expect(s, contains('t_builtin_17'));
      expect(s, contains('enabled: true'));
      expect(s, contains('trigger: time_of_day'));
      expect(s, contains('condition: day_of_week'));
      expect(s, contains('action: notify'));
    });

    test('condition field renders "none" when conditionJson is null', () {
      const c = RoutineConfig(
        templateId: 't_builtin_17',
        triggerJson: <String, Object?>{'type': 'time_of_day'},
        actionJson: <String, Object?>{'type': 'notify'},
      );
      final s = c.toString();
      expect(s, contains('condition: none'));
    });
  });
}
