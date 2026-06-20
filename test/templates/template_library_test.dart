// Tests for the hand-curated [TemplateLibrary].
//
// Coverage:
//   - kTemplateFormatVersion pinned at 1
//   - builtIns has exactly 25 entries
//   - all ids are unique
//   - all payloadJson parse as JSON and have k == 1
//   - per-entity envelope key matches the entityType tag
//     (routine uses the 'routine' key)
//   - all iconName resolve via DoIcons.resolveFor without
//     throwing
//   - seedBuiltIns is idempotent (second call inserts 0)

import 'dart:convert';

import 'package:doit/do/category.dart';
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

void main() {
  group('TemplateLibrary (curated catalog)', () {
    test('kTemplateFormatVersion is pinned at 1', () {
      expect(TemplateLibrary.kTemplateFormatVersion, 1);
    });

    test('builtIns has exactly 25 entries', () {
      expect(TemplateLibrary.builtIns.length, 25);
    });

    test('all built-in ids are unique', () {
      final ids = TemplateLibrary.builtIns.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every payloadJson parses as JSON with k == 1', () {
      for (final t in TemplateLibrary.builtIns) {
        final parsed = jsonDecode(t.payloadJson);
        expect(parsed, isA<Map<String, dynamic>>());
        final k = (parsed as Map<String, dynamic>)['k'];
        expect(k, 1, reason: 'template ${t.id} has wrong k: $k');
      }
    });

    test('envelope key matches entityType tag (routine uses "routine")', () {
      for (final t in TemplateLibrary.builtIns) {
        final parsed = jsonDecode(t.payloadJson) as Map<String, dynamic>;
        // The non-'k' keys are the entity envelope. For a do
        // template, the only non-'k' key must be 'do'; for a
        // person, 'person'; etc.
        final otherKeys = parsed.keys.where((k) => k != 'k').toList();
        expect(
          otherKeys.length,
          1,
          reason:
              'template ${t.id} has unexpected envelope keys: '
              '$otherKeys',
        );
        expect(
          otherKeys.first,
          t.entityType.tag,
          reason:
              'template ${t.id} entityType=${t.entityType.tag} but '
              'envelope key=${otherKeys.first}',
        );
      }
    });

    test('entityType coverage matches the curated split', () {
      final counts = <TemplateEntityType, int>{};
      for (final t in TemplateLibrary.builtIns) {
        counts[t.entityType] = (counts[t.entityType] ?? 0) + 1;
      }
      expect(counts[TemplateEntityType.doEntity], 12);
      expect(counts[TemplateEntityType.person], 3);
      expect(counts[TemplateEntityType.event], 4);
      expect(counts[TemplateEntityType.routine], 6);
    });

    test('every iconName resolves via DoIcons.resolveFor without throwing', () {
      // We synthesize a DoCategory.fromTag so we don't have to
      // parse it from the payload. The category is only used
      // for the fallback default; any value works.
      for (final t in TemplateLibrary.builtIns) {
        // Should not throw — resolveFor returns the iconName if
        // known, or the category default if not.
        final resolved = DoIcons.resolveFor(
          category: DoCategory.other,
          iconName: t.iconName,
        );
        expect(
          resolved,
          isNotEmpty,
          reason: 'template ${t.id} resolved to empty icon',
        );
      }
    });

    test('isBuiltIn is true for every built-in', () {
      for (final t in TemplateLibrary.builtIns) {
        expect(t.isBuiltIn, true, reason: 'template ${t.id} not built-in');
      }
    });

    test('createdAt is deterministic (DateTime.utc(2026))', () {
      // The spec pins the createdAt so the picker sorts
      // deterministically across re-seeds.
      for (final t in TemplateLibrary.builtIns) {
        expect(t.createdAt.year, 2026);
      }
    });

    group('seedBuiltIns (idempotency)', () {
      setUp(_initDb);
      tearDown(_tearDown);

      test('inserts 25 rows on first call, 0 on second call', () async {
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

      test('rows are persisted with isBuiltIn=true', () async {
        await TemplateLibrary.seedBuiltIns(TemplateRepository.instance);
        final all = await TemplateRepository.instance.listAll();
        for (final t in all) {
          expect(t.isBuiltIn, true);
        }
      });
    });
  });

  group('Template model', () {
    test('copyWith returns a new instance with the patched field', () {
      final t = Template(
        id: 't1',
        name: 'Original',
        description: 'd',
        iconName: 'check',
        entityType: TemplateEntityType.doEntity,
        payloadJson: '{"k":1,"do":{}}',
        isBuiltIn: false,
        createdAt: DateTime.utc(2026),
      );
      final t2 = t.copyWith(name: 'Renamed');
      expect(t2.name, 'Renamed');
      expect(t2.id, t.id);
      expect(t2.description, t.description);
      expect(t2.iconName, t.iconName);
      expect(t2.entityType, t.entityType);
      expect(t2.payloadJson, t.payloadJson);
      expect(t2.isBuiltIn, t.isBuiltIn);
      expect(t2.createdAt, t.createdAt);
      // Original is unchanged.
      expect(t.name, 'Original');
    });

    test('copyWith with lastUsedAt sets the field', () {
      final t = Template(
        id: 't1',
        name: 'n',
        description: 'd',
        iconName: 'check',
        entityType: TemplateEntityType.doEntity,
        payloadJson: '{"k":1,"do":{}}',
        isBuiltIn: false,
        createdAt: DateTime.utc(2026),
      );
      final when = DateTime.utc(2026, 6, 20);
      final t2 = t.copyWith(lastUsedAt: when);
      expect(t2.lastUsedAt, when);
    });

    test('equality and hashCode match on every field', () {
      final when = DateTime.utc(2026, 6, 20);
      Template make() => Template(
        id: 't1',
        name: 'n',
        description: 'd',
        iconName: 'check',
        entityType: TemplateEntityType.doEntity,
        payloadJson: '{"k":1,"do":{}}',
        isBuiltIn: false,
        createdAt: DateTime.utc(2026),
        lastUsedAt: when,
      );
      final a = make();
      final b = make();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      // Differ on name → not equal.
      expect(a, isNot(equals(b.copyWith(name: 'other'))));
      // Differ on lastUsedAt → not equal.
      expect(a, isNot(equals(b.copyWith(lastUsedAt: DateTime.utc(2027)))));
    });

    test('toString is human-readable', () {
      final t = Template(
        id: 't_builtin_01',
        name: 'Drink water',
        description: 'd',
        iconName: 'check',
        entityType: TemplateEntityType.doEntity,
        payloadJson: '{}',
        isBuiltIn: true,
        createdAt: DateTime.utc(2026),
      );
      final s = t.toString();
      expect(s, contains('t_builtin_01'));
      expect(s, contains('Drink water'));
      expect(s, contains('do'));
    });
  });

  group('TemplateValidationException', () {
    test('toString prefixes the class name', () {
      const e = TemplateValidationException('bad envelope');
      expect(e.toString(), contains('TemplateValidationException'));
      expect(e.toString(), contains('bad envelope'));
      expect(e.message, 'bad envelope');
    });
  });
}
