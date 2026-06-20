// Tests for [TemplateRepository] — round-trips, validation,
// filtering, ordering, built-in protection.

import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/template_repository.dart';
import 'package:doit/templates/template.dart';
import 'package:doit/templates/template_library.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _initDb() async {
  await AppDatabaseService.instance.closeForTesting();
  await AppDatabaseService.instance.init(
    overrideDb: AppDatabase(NativeDatabase.memory()),
  );
  await AppDatabaseService.instance.ready;
}

Future<void> _tearDown() => AppDatabaseService.instance.closeForTesting();

const String _kEnvelopeV1Do = '{"k":1,"do":{"name":"Drink water"}}';

Template _userTemplate({
  String id = 't_user_01',
  String name = 'My template',
  TemplateEntityType entityType = TemplateEntityType.doEntity,
  String payloadJson = _kEnvelopeV1Do,
  bool isBuiltIn = false,
  DateTime? createdAt,
  DateTime? lastUsedAt,
}) {
  return Template(
    id: id,
    name: name,
    description: 'Test template',
    iconName: 'check',
    entityType: entityType,
    payloadJson: payloadJson,
    isBuiltIn: isBuiltIn,
    createdAt: createdAt ?? DateTime.utc(2026, 6, 20),
    lastUsedAt: lastUsedAt,
  );
}

void main() {
  setUp(_initDb);
  tearDown(_tearDown);

  group('TemplateRepository.save', () {
    test('round-trips a template via getById', () async {
      final t = _userTemplate(id: 't1', name: 'Drink water');
      await TemplateRepository.instance.save(t);
      final back = await TemplateRepository.instance.getById('t1');
      expect(back, isNotNull);
      expect(back!.name, 'Drink water');
      expect(back.description, 'Test template');
      expect(back.iconName, 'check');
      expect(back.entityType, TemplateEntityType.doEntity);
      expect(back.payloadJson, _kEnvelopeV1Do);
      expect(back.isBuiltIn, false);
      expect(back.createdAt.toUtc(), DateTime.utc(2026, 6, 20));
      expect(back.lastUsedAt, isNull);
    });

    test('assigns id when input id is empty', () async {
      final t = _userTemplate(id: '');
      final returned = await TemplateRepository.instance.save(t);
      expect(returned, isNotEmpty);
      expect(returned, startsWith('t_'));
      final back = await TemplateRepository.instance.getById(returned);
      expect(back, isNotNull);
      expect(back!.id, returned);
    });

    test('insertOnConflictUpdate overwrites an existing row', () async {
      final t1 = _userTemplate(id: 't1', name: 'First');
      await TemplateRepository.instance.save(t1);
      final t2 = _userTemplate(id: 't1', name: 'Second');
      await TemplateRepository.instance.save(t2);
      final back = await TemplateRepository.instance.getById('t1');
      expect(back!.name, 'Second');
    });

    test('throws TemplateValidationException for malformed JSON', () async {
      final t = _userTemplate(payloadJson: 'not json at all');
      await expectLater(
        () => TemplateRepository.instance.save(t),
        throwsA(isA<TemplateValidationException>()),
      );
    });

    test('throws TemplateValidationException for non-object JSON', () async {
      final t = _userTemplate(payloadJson: '[1,2,3]');
      await expectLater(
        () => TemplateRepository.instance.save(t),
        throwsA(isA<TemplateValidationException>()),
      );
    });

    test('throws TemplateValidationException for wrong k', () async {
      final t = _userTemplate(payloadJson: '{"k":99,"do":{}}');
      await expectLater(
        () => TemplateRepository.instance.save(t),
        throwsA(isA<TemplateValidationException>()),
      );
    });

    test('throws TemplateValidationException for missing k', () async {
      final t = _userTemplate(payloadJson: '{"do":{}}');
      await expectLater(
        () => TemplateRepository.instance.save(t),
        throwsA(isA<TemplateValidationException>()),
      );
    });
  });

  group('TemplateRepository.listAll', () {
    test('orders by createdAtMillis ASC, then id ASC', () async {
      final older = _userTemplate(
        id: 't_a',
        name: 'Older',
        createdAt: DateTime.utc(2026),
      );
      final newer = _userTemplate(
        id: 't_b',
        name: 'Newer',
        createdAt: DateTime.utc(2026, 7),
      );
      await TemplateRepository.instance.save(newer);
      await TemplateRepository.instance.save(older);
      final all = await TemplateRepository.instance.listAll();
      expect(all.map((t) => t.id).toList(), ['t_a', 't_b']);
    });

    test('filters by entityType', () async {
      await TemplateRepository.instance.save(_userTemplate(id: 't_do'));
      await TemplateRepository.instance.save(
        _userTemplate(id: 't_person', entityType: TemplateEntityType.person),
      );
      await TemplateRepository.instance.save(
        _userTemplate(id: 't_event', entityType: TemplateEntityType.event),
      );
      final persons = await TemplateRepository.instance.listAll(
        entityType: TemplateEntityType.person,
      );
      expect(persons.length, 1);
      expect(persons.first.id, 't_person');
    });

    test('filters by builtInOnly', () async {
      await TemplateRepository.instance.save(
        _userTemplate(id: 't_builtin', isBuiltIn: true),
      );
      await TemplateRepository.instance.save(_userTemplate(id: 't_user'));
      final builtIns = await TemplateRepository.instance.listAll(
        builtInOnly: true,
      );
      expect(builtIns.length, 1);
      expect(builtIns.first.id, 't_builtin');
      final all = await TemplateRepository.instance.listAll();
      expect(all.length, 2);
    });

    test('returns empty list when no rows match', () async {
      final all = await TemplateRepository.instance.listAll();
      expect(all, isEmpty);
    });
  });

  group('TemplateRepository.getById', () {
    test('returns null for missing id', () async {
      final back = await TemplateRepository.instance.getById('missing');
      expect(back, isNull);
    });
  });

  group('TemplateRepository.delete', () {
    test('removes a user-saved template', () async {
      await TemplateRepository.instance.save(_userTemplate(id: 't1'));
      await TemplateRepository.instance.delete('t1');
      final back = await TemplateRepository.instance.getById('t1');
      expect(back, isNull);
    });

    test('throws TemplateValidationException for a built-in', () async {
      await TemplateRepository.instance.save(
        _userTemplate(id: 't_builtin', isBuiltIn: true),
      );
      await expectLater(
        () => TemplateRepository.instance.delete('t_builtin'),
        throwsA(isA<TemplateValidationException>()),
      );
      final back = await TemplateRepository.instance.getById('t_builtin');
      expect(back, isNotNull);
    });

    test('is a no-op when id is missing', () async {
      await TemplateRepository.instance.delete('missing');
    });
  });

  group('TemplateRepository.markUsed', () {
    test('updates lastUsedAt on a saved template', () async {
      await TemplateRepository.instance.save(_userTemplate(id: 't1'));
      final when = DateTime.utc(2026, 6, 20, 12, 30);
      await TemplateRepository.instance.markUsed('t1', when);
      final back = await TemplateRepository.instance.getById('t1');
      // Round-trip via millisecondsSinceEpoch normalizes to
      // local time on read; compare via toUtc().
      expect(back!.lastUsedAt!.toUtc(), when);
    });

    test('is a no-op when id is missing (no throw)', () async {
      await TemplateRepository.instance.markUsed(
        'missing',
        DateTime.utc(2026, 6, 20),
      );
    });
  });

  group('TemplateEntityType.fromTag', () {
    test('round-trips every known tag', () {
      for (final e in TemplateEntityType.values) {
        expect(TemplateEntityType.fromTag(e.tag), e);
      }
    });

    test('throws on unknown tag', () {
      expect(
        () => TemplateEntityType.fromTag('unknown'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('TemplateLibrary integration', () {
    test('seedBuiltIns writes 25 rows and is idempotent', () async {
      final inserted1 = await TemplateLibrary.seedBuiltIns(
        TemplateRepository.instance,
      );
      expect(inserted1, 25);
      final inserted2 = await TemplateLibrary.seedBuiltIns(
        TemplateRepository.instance,
      );
      expect(inserted2, 0);
      final all = await TemplateRepository.instance.listAll();
      expect(all.length, 25);
    });

    test('cannot delete a seeded built-in', () async {
      await TemplateLibrary.seedBuiltIns(TemplateRepository.instance);
      await expectLater(
        () => TemplateRepository.instance.delete('t_builtin_01'),
        throwsA(isA<TemplateValidationException>()),
      );
    });

    test('markUsed on a built-in updates lastUsedAt', () async {
      await TemplateLibrary.seedBuiltIns(TemplateRepository.instance);
      final when = DateTime.utc(2026, 6, 20, 8);
      await TemplateRepository.instance.markUsed('t_builtin_01', when);
      final back = await TemplateRepository.instance.getById('t_builtin_01');
      expect(back!.lastUsedAt!.toUtc(), when);
    });
  });
}
