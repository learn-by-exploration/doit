// Migration test for the v4 → v5 step (v1.4l / Phase 39 /
// SYS-126 / ADR-056 / WF-053).
//
// Asserts:
//   - The schema version is bumped to 5.
//   - The `habits` table gains a `deleted_at_millis`
//     (INTEGER, nullable) column.
//   - Existing rows survive the migration unchanged
//     (their `deleted_at_millis` is NULL after migration).
//   - The new column round-trips both NULL and an int.

import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('migrateV4ToV5', () {
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

    test('schemaVersion is 5 (v1.4l pin)', () {
      expect(db.schemaVersion, 5);
      expect(kCurrentSchemaVersion, 5);
    });

    test('habits table has deleted_at_millis column', () async {
      final rows = await db.customSelect("PRAGMA table_info('habits')").get();
      final cols = rows
          .map((r) => r.data['name'] as String)
          .toList(growable: false);
      expect(cols, contains('deleted_at_millis'));
    });

    test(
      'deleted_at_millis column is nullable (accepts NULL and an int)',
      () async {
        // NULL first
        await db
            .into(db.habits)
            .insert(
              HabitRow(
                id: 'h-null',
                name: 'Null tombstone',
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
        final nullBack = await (db.select(
          db.habits,
        )..where((t) => t.id.equals('h-null'))).getSingle();
        expect(nullBack.deletedAtMillis, isNull);

        // Then a real int (soft-delete timestamp).
        final ts = DateTime(2026, 6, 27, 10).millisecondsSinceEpoch;
        await db
            .into(db.habits)
            .insert(
              HabitRow(
                id: 'h-ts',
                name: 'Tombstoned',
                proofMode: 'soft',
                createdAtMillis: DateTime(2026).millisecondsSinceEpoch,
                restDaysPerMonth: 2,
                scheduleType: 'fixed',
                weekdays: '1,3,5',
                hour: 9,
                minute: 0,
                category: 'other',
                colorSeed: 0,
                deletedAtMillis: ts,
              ),
            );
        final tsBack = await (db.select(
          db.habits,
        )..where((t) => t.id.equals('h-ts'))).getSingle();
        expect(tsBack.deletedAtMillis, ts);
      },
    );

    test(
      'existing rows survive the migration with NULL deleted_at_millis',
      () async {
        // Insert a row in the v4 schema (no deleted_at_millis
        // specified), then verify it survives with NULL.
        await db
            .into(db.habits)
            .insert(
              HabitRow(
                id: 'h-pre-existing',
                name: 'Pre-existing',
                proofMode: 'soft',
                createdAtMillis: DateTime(2026, 6).millisecondsSinceEpoch,
                restDaysPerMonth: 2,
                scheduleType: 'fixed',
                weekdays: '2,4',
                hour: 8,
                minute: 0,
                category: 'other',
                colorSeed: 0,
              ),
            );
        final back = await (db.select(
          db.habits,
        )..where((t) => t.id.equals('h-pre-existing'))).getSingle();
        expect(back.deletedAtMillis, isNull);
        // Other columns are untouched.
        expect(back.name, 'Pre-existing');
        expect(back.automationsJson, isNull);
      },
    );
  });
}
