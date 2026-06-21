// Tests for the v1.1 (SYS-083) RoutineTemplatePayload codec.
//
// Coverage:
//   - fromTemplate decodes a well-formed envelope into a
//     RoutineTemplatePayload.
//   - fromTemplate returns null on each defect path:
//     malformed JSON, non-object envelope, missing
//     `routine` key, non-string trigger / condition /
//     action / note, empty trigger / action.
//   - toRoutineConfig produces a RoutineConfig whose
//     triggerJson / actionJson carry the placeholder
//     sentinel and the per-template kind / note fields.
//   - The trigger / action placeholders are round-tripped
//     through the RoutineConfig codec (so a saved config
//     can be re-decoded without losing information).
//   - Structural == + hashCode + toString.

import 'dart:convert' show jsonEncode;

import 'package:doit/routines/routine_template_payload.dart';
import 'package:doit/services/routine_config.dart';
import 'package:doit/templates/template.dart';
import 'package:flutter_test/flutter_test.dart';

Template _t({
  String id = 't_builtin_17',
  String name = 'Focus block',
  String description = 'Silence notifications on focus block start.',
  String payload =
      '{"k":1,"routine":{"trigger":"calendar","condition":"event:FocusBlock","action":"dn:on","note":"Phase C+ apply UX"}}',
}) => Template(
  id: id,
  name: name,
  description: description,
  iconName: 'work',
  entityType: TemplateEntityType.routine,
  isBuiltIn: true,
  createdAt: DateTime(2026, 6, 21),
  payloadJson: payload,
);

void main() {
  group('RoutineTemplatePayload.fromTemplate', () {
    test('decodes a well-formed envelope', () {
      final p = RoutineTemplatePayload.fromTemplate(_t());
      expect(p, isNotNull);
      expect(p!.templateId, 't_builtin_17');
      expect(p.name, 'Focus block');
      expect(p.description, 'Silence notifications on focus block start.');
      expect(p.trigger, 'calendar');
      expect(p.condition, 'event:FocusBlock');
      expect(p.action, 'dn:on');
      expect(p.note, 'Phase C+ apply UX');
    });

    test('returns null on malformed JSON', () {
      final t = _t(payload: '{not json');
      expect(RoutineTemplatePayload.fromTemplate(t), isNull);
    });

    test('returns null on a non-object envelope', () {
      final t = _t(payload: '"just a string"');
      expect(RoutineTemplatePayload.fromTemplate(t), isNull);
    });

    test('returns null on a missing `routine` key', () {
      final t = _t(payload: '{"k":1}');
      expect(RoutineTemplatePayload.fromTemplate(t), isNull);
    });

    test('returns null when `routine` is not a JSON object', () {
      final t = _t(payload: '{"k":1,"routine":"oops"}');
      expect(RoutineTemplatePayload.fromTemplate(t), isNull);
    });

    test('returns null when `trigger` is empty', () {
      final t = _t(
        payload: jsonEncode(<String, Object?>{
          'k': 1,
          'routine': <String, Object?>{
            'trigger': '   ',
            'condition': 'event:X',
            'action': 'dn:on',
            'note': '',
          },
        }),
      );
      expect(RoutineTemplatePayload.fromTemplate(t), isNull);
    });

    test('returns null when `action` is empty', () {
      final t = _t(
        payload: jsonEncode(<String, Object?>{
          'k': 1,
          'routine': <String, Object?>{
            'trigger': 'calendar',
            'condition': 'event:X',
            'action': '',
            'note': '',
          },
        }),
      );
      expect(RoutineTemplatePayload.fromTemplate(t), isNull);
    });

    test('returns null when `condition` is not a string', () {
      final t = _t(
        payload: jsonEncode(<String, Object?>{
          'k': 1,
          'routine': <String, Object?>{
            'trigger': 'calendar',
            'condition': 42,
            'action': 'dn:on',
            'note': '',
          },
        }),
      );
      expect(RoutineTemplatePayload.fromTemplate(t), isNull);
    });

    test('tolerates an empty `condition` and `note`', () {
      final t = _t(
        payload: jsonEncode(<String, Object?>{
          'k': 1,
          'routine': <String, Object?>{
            'trigger': 'location',
            'condition': '',
            'action': 'timer:workout',
            'note': '',
          },
        }),
      );
      final p = RoutineTemplatePayload.fromTemplate(t);
      expect(p, isNotNull);
      expect(p!.condition, '');
      expect(p.note, '');
    });
  });

  group('RoutineTemplatePayload.toRoutineConfig', () {
    test('produces a config with placeholder sentinel trigger / action', () {
      final cfg = RoutineTemplatePayload.fromTemplate(
        _t(),
      )!.toRoutineConfig(enabled: true);
      expect(cfg.templateId, 't_builtin_17');
      expect(cfg.enabled, true);
      expect(cfg.triggerJson['type'], 'routine_placeholder.v1');
      expect(cfg.triggerJson['kind'], 'calendar');
      expect(cfg.triggerJson['raw'], 'event:FocusBlock');
      expect(cfg.actionJson['type'], 'routine_placeholder.v1');
      expect(cfg.actionJson['kind'], 'dn:on');
      expect(cfg.actionJson['note'], 'Phase C+ apply UX');
    });

    test('round-trips through RoutineConfig.toJson / fromJson', () {
      final cfg = RoutineTemplatePayload.fromTemplate(
        _t(),
      )!.toRoutineConfig(enabled: false);
      final json = cfg.toJson();
      final decoded = RoutineConfig.fromJson(json);
      expect(decoded, equals(cfg));
      expect(decoded.enabled, false);
    });
  });

  group('RoutineTemplatePayload equality', () {
    test('two decodes of the same template are equal', () {
      final a = RoutineTemplatePayload.fromTemplate(_t());
      final b = RoutineTemplatePayload.fromTemplate(_t());
      expect(a, equals(b));
      expect(a.hashCode, equals(b!.hashCode));
    });

    test('decodes of different templates are not equal', () {
      final a = RoutineTemplatePayload.fromTemplate(_t());
      final b = RoutineTemplatePayload.fromTemplate(
        _t(id: 't_builtin_19', name: 'At the gym'),
      );
      expect(a, isNot(equals(b)));
    });

    test('toString does not throw and includes the templateId', () {
      final s = RoutineTemplatePayload.fromTemplate(_t())!.toString();
      expect(s, contains('t_builtin_17'));
    });
  });
}
