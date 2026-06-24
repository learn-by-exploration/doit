// Migration test for the v3 → v4 step (Phase C PR 1).
//
// Asserts:
//   - The schema version is bumped to 4.
//   - The habits / people / events tables gain an
//     `automations_json` (TEXT, nullable) column.

import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('migrateV3ToV4', () {
    late AppDatabase db;

    setUp(() async {
      await AppDatabaseService.instance.closeForTesting();
      db = AppDatabase(NativeDatabase.memory());
      await AppDatabaseService.instance.init(overrideDb: db);
      await AppDatabaseService.instance.ready;
    });

    tearDown(() async {
      await AppDatabaseService.instance.closeForTesting();
    });

    test('schemaVersion is 5 (Phase 11f / WF-023 pin)', () {
      // WF-023 (Phase 11f) bumped the schema to 5 to add
      // habits.grace_window_override_millis. The v3→v4
      // pin test now asserts the post-migration state.
      expect(db.schemaVersion, 5);
      expect(kCurrentSchemaVersion, 5);
    });

    test('habits / people / events have automations_json column', () async {
      Future<List<String>> columns(String table) async {
        final rows = await db.customSelect("PRAGMA table_info('$table')").get();
        return rows
            .map((r) => r.data['name'] as String)
            .toList(growable: false);
      }

      final habitCols = await columns('habits');
      final personCols = await columns('people');
      final eventCols = await columns('events');

      expect(habitCols, contains('automations_json'));
      expect(personCols, contains('automations_json'));
      expect(eventCols, contains('automations_json'));
    });

    test('automations_json column is nullable', () async {
      // A row with NULL automations_json should insert
      // cleanly — the column is nullable.
      await db
          .into(db.habits)
          .insert(
            HabitRow(
              id: 'h1',
              name: 'Drink water',
              proofMode: 'soft',
              createdAtMillis: DateTime(2026).millisecondsSinceEpoch,
              restDaysPerMonth: 2,
              scheduleType: 'fixed',
              weekdays: '1,3,5',
              hour: 9,
              minute: 0,
              category: 'other',
              colorSeed: 0,
            ),
          );
      final back = await (db.select(
        db.habits,
      )..where((t) => t.id.equals('h1'))).getSingle();
      expect(back.automationsJson, isNull);
    });

    test('automations_json round-trips a JSON payload', () async {
      const payload =
          '[{"id":"a1","trigger":{"type":"timeOfDay","hour":8,"minute":0},'
          '"condition":null,'
          '"action":{"type":"notify","title":"t","body":"b"},'
          '"enabled":true}]';
      await db
          .into(db.habits)
          .insert(
            HabitRow(
              id: 'h1',
              name: 'Drink water',
              proofMode: 'soft',
              createdAtMillis: DateTime(2026).millisecondsSinceEpoch,
              restDaysPerMonth: 2,
              scheduleType: 'fixed',
              weekdays: '1,3,5',
              hour: 9,
              minute: 0,
              category: 'other',
              colorSeed: 0,
              automationsJson: payload,
            ),
          );
      final back = await (db.select(
        db.habits,
      )..where((t) => t.id.equals('h1'))).getSingle();
      expect(back.automationsJson, payload);
    });
  });
}
