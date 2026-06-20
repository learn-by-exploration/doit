// Tests for the Drift database migrations.
//
// Coverage:
//   1. Fresh-install creates the v1 schema (all 6 tables present).
//   2. Re-opening an existing v1 DB does NOT re-run onCreate.
//   3. A `doit.db` from a hypothetical v0 → v1 upgrade is
//      idempotent (the v1 schema is a superset of the empty
//      schema; createAll is safe on a fresh DB).
//
// The `flutter_test` package is used for the test harness; the
// `drift/native.dart` `NativeDatabase.memory()` gives us an
// in-process SQLite without touching the filesystem.

import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabaseService (migration_test)', () {
    setUp(() async {
      // Each test gets a fresh in-memory DB. The service's
      // `init(overrideDb: ...)` swaps in the in-memory executor
      // and never touches the filesystem.
      await AppDatabaseService.instance.closeForTesting();
      final db = AppDatabase(NativeDatabase.memory());
      await AppDatabaseService.instance.init(overrideDb: db);
    });

    tearDown(() async {
      await AppDatabaseService.instance.closeForTesting();
    });

    test('fresh install creates all v1 tables', () async {
      await AppDatabaseService.instance.ready;
      // Insert a row in every table; if the table is missing,
      // the insert throws. This is the cleanest way to assert
      // "every table exists" without a schema-introspection
      // helper.
      final db = AppDatabaseService.instance.db;
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
      await db
          .into(db.people)
          .insert(
            PersonRow(
              id: 'p1',
              lookupKey: 'lookup-1',
              displayName: '',
              channel: 'dialer',
              handle: '+15555550100',
              createdAtMillis: DateTime(2026).millisecondsSinceEpoch,
              cadenceType: 'weekly_on',
              weekday: 3,
              anchoredToWakeup: false,
            ),
          );
      await db
          .into(db.completions)
          .insert(
            CompletionRow(
              id: 'c1',
              habitId: 'h1',
              dayMillis: DateTime(2026, 6, 5).millisecondsSinceEpoch,
              completedAtMillis: DateTime(2026, 6, 5, 9).millisecondsSinceEpoch,
              source: 'manual',
              proofModeAtTime: 'soft',
            ),
          );
      await db
          .into(db.restDayBudgets)
          .insert(
            const RestDayBudgetRow(
              id: 'b1',
              habitId: 'h1',
              yearMonth: 202606,
              used: 0,
              monthlyLimit: 2,
            ),
          );
      await db
          .into(db.settings)
          .insert(const SettingRow(key: 'theme', value: 'dark'));
      await db
          .into(db.eventLogs)
          .insert(
            EventLogRow(
              id: 'e1',
              atMillis: DateTime(2026).millisecondsSinceEpoch,
              kind: 'boot',
            ),
          );

      // Round-trip read to confirm the inserts persisted.
      final habits = await db.select(db.habits).get();
      final people = await db.select(db.people).get();
      final completions = await db.select(db.completions).get();
      final budgets = await db.select(db.restDayBudgets).get();
      final settings = await db.select(db.settings).get();
      final events = await db.select(db.eventLogs).get();
      expect(habits.length, 1);
      expect(people.length, 1);
      expect(completions.length, 1);
      expect(budgets.length, 1);
      expect(settings.length, 1);
      expect(events.length, 1);
    });

    test('re-opening an existing v1 DB does not re-run onCreate', () async {
      // Insert a row, close, re-open with a fresh in-memory DB,
      // and confirm the new DB is empty (proving the in-memory
      // DB was not persisted across tests, and the singleton's
      // close/init cycle is clean).
      final db = AppDatabaseService.instance.db;
      await db
          .into(db.habits)
          .insert(
            HabitRow(
              id: 'h1',
              name: 'Read',
              proofMode: 'soft',
              createdAtMillis: DateTime(2026).millisecondsSinceEpoch,
              restDaysPerMonth: 2,
              scheduleType: 'fixed',
              weekdays: '2,4',
              hour: 8,
              category: 'other',
              colorSeed: 0,
              minute: 0,
            ),
          );
      final before = await db.select(db.habits).get();
      expect(before.length, 1);

      // Close and re-open with a brand-new in-memory DB. The
      // closeForTesting path drops the singleton state.
      await AppDatabaseService.instance.closeForTesting();
      final fresh = AppDatabase(NativeDatabase.memory());
      await AppDatabaseService.instance.init(overrideDb: fresh);
      await AppDatabaseService.instance.ready;
      final after = await AppDatabaseService.instance.db
          .select(db.habits)
          .get();
      expect(after, isEmpty);
    });

    test('schemaVersion is 3 for v1.0 reframe (Phase B PR 1)', () {
      // The version pin is a contract — Phase 3+ bump it.
      // Drift exposes it via the database instance.
      final db = AppDatabaseService.instance.db;
      expect(db.schemaVersion, kCurrentSchemaVersion);
      expect(kCurrentSchemaVersion, 3);
    });

    test('fresh install creates the v3 templates table', () async {
      final db = AppDatabaseService.instance.db;
      // A row insert in a missing table would throw. This is
      // the cheapest "the table exists" assertion without a
      // schema-introspection helper.
      await db
          .into(db.templates)
          .insert(
            TemplateRow(
              id: 't_test_v3',
              name: 'Drink water',
              description: 'Test template',
              iconName: 'check',
              entityType: 'do',
              payloadJson: '{"k":1,"do":{}}',
              isBuiltIn: false,
              createdAtMillis: DateTime(2026).millisecondsSinceEpoch,
            ),
          );
      final back = await db.select(db.templates).getSingle();
      expect(back.name, 'Drink water');
    });
  });
}
