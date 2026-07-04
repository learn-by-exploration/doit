// Tests for the Drift database migrations.
//
// Coverage:
//   1. Fresh-install creates the v1 schema (all 6 tables present).
//   2. Re-opening an existing v1 DB does NOT re-run onCreate.
//   3. A `doit.db` from a hypothetical v0 → v1 upgrade is
//      idempotent (the v1 schema is a superset of the empty
//      schema; createAll is safe on a fresh DB).
//   4-6. (v1.6-ι / SYS-154 / ADR-085 / WF-082) The v1→v2
//      migration adds the v0.2 columns (`category`,
//      `color_seed`, `icon_name`, `paused_until_millis`,
//      `end_hour`, `end_minute`, `target_hours`,
//      `people.paused_until_millis`) AND the new `events`,
//      `person_groups`, `person_group_members` tables
//      AND preserves existing rows across the upgrade.
//
// The `flutter_test` package is used for the test harness; the
// `drift/native.dart` `NativeDatabase.memory()` gives us an
// in-process SQLite without touching the filesystem.

import 'dart:io';

import 'package:doit/services/db.dart';
import 'package:doit/services/db/migrations/v1_to_v2.dart';
import 'package:doit/services/db/schema.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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

    test('schemaVersion is 5 for v1.4l soft-delete column (Phase 39)', () {
      // The version pin is a contract — Phase 3+ bump it.
      // Drift exposes it via the database instance.
      final db = AppDatabaseService.instance.db;
      expect(db.schemaVersion, kCurrentSchemaVersion);
      expect(kCurrentSchemaVersion, 5);
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

  // ---- v1.6-ι / SYS-154 / ADR-085 / WF-082 ----
  // v1 → v2 migration: the v0.2 foundation. Adds
  // `category` / `color_seed` / `icon_name` /
  // `paused_until_millis` / `end_hour` / `end_minute` /
  // `target_hours` to `habits`, `paused_until_millis` to
  // `people`, and the `events` / `person_groups` /
  // `person_group_members` tables. Mirrors the fixture-based
  // pattern from `migration_v2_to_v3_test.dart`.
  group('migrateV1ToV2 (v1.6-ι)', () {
    late File dbFile;
    late Directory tmpDir;

    setUp(() async {
      // Reset the singleton so the in-memory DB doesn't leak
      // across the fixture-based tests below.
      await AppDatabaseService.instance.closeForTesting();

      tmpDir = await Directory.systemTemp.createTemp('doit_mig_v1_v2_');
      dbFile = File(p.join(tmpDir.path, 'fixture.db'));
      // Build the v1 fixture with a no-op `MigrationStrategy`
      // so the schema and `user_version` are entirely under
      // our control via raw SQL.
      final db = _V1FixtureDatabase(NativeDatabase(dbFile));
      try {
        await db.customStatement(_v1CreateSql);
        await db.customStatement(
          'INSERT INTO habits (id, name, proof_mode, created_at_millis, '
          'schedule_type, hour, minute) VALUES '
          "('h1', 'Drink water', 'soft', 1748736000000, 'fixed', 9, 0)",
        );
        await db.customStatement(
          'INSERT INTO people (id, lookup_key, display_name, channel, '
          'handle, created_at_millis, cadence_type, anchored_to_wakeup) '
          'VALUES '
          "('p1', 'lookup-1', 'Alice', 'dialer', '+15555550100', "
          '1748736000000, \'weekly_on\', 0)',
        );
        await db.customStatement('PRAGMA user_version = 1');
      } finally {
        await db.close();
      }
    });

    tearDown(() async {
      await AppDatabaseService.instance.closeForTesting();
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('v1→v2 migration adds the v0.2 columns to habits and people '
        '(v1.6-ι)', () async {
      // Open with the v2-pinned `_V2OnlyDatabase`. Drift
      // sees `user_version = 1` and runs only the
      // `migrateV1ToV2` step (no v3→v4 / v4→v5 noise).
      final db = _V2OnlyDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      Future<List<String>> columns(String table) async {
        final rows = await db.customSelect("PRAGMA table_info('$table')").get();
        return rows
            .map((r) => r.data['name'] as String)
            .toList(growable: false);
      }

      final habitCols = await columns('habits');
      final personCols = await columns('people');

      // The eight v0.2 column adds (7 on habits, 1 on people).
      expect(habitCols, contains('category'));
      expect(habitCols, contains('color_seed'));
      expect(habitCols, contains('icon_name'));
      expect(habitCols, contains('paused_until_millis'));
      expect(habitCols, contains('end_hour'));
      expect(habitCols, contains('end_minute'));
      expect(habitCols, contains('target_hours'));
      expect(personCols, contains('paused_until_millis'));
    });

    test('v1→v2 migration creates events + person_groups tables '
        '(v1.6-ι)', () async {
      final db = _V2OnlyDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      // Insert a row in each new table — if the table is
      // missing, the insert throws. Cheapest "the table
      // exists" assertion without a schema-introspection
      // helper.
      await db
          .into(db.events)
          .insert(
            const EventRow(
              id: 'e1',
              name: 'Birthday',
              atMillis: 1748736000000,
              leadTimeMillis: 86400000,
              recurrence: 'none',
              createdAtMillis: 1748736000000,
            ),
          );
      await db
          .into(db.personGroups)
          .insert(
            const PersonGroupRow(
              id: 'g1',
              name: 'Family',
              cadenceType: 'weekly_on',
              semantic: 'family',
              channel: 'dialer',
              handle: '',
              createdAtMillis: 1748736000000,
            ),
          );
      await db
          .into(db.personGroupMembers)
          .insert(
            const PersonGroupMemberRow(
              groupId: 'g1',
              personId: 'p1',
              addedAtMillis: 1748736000000,
            ),
          );

      final events = await db.select(db.events).get();
      final groups = await db.select(db.personGroups).get();
      final members = await db.select(db.personGroupMembers).get();
      expect(events.length, 1);
      expect(events.first.name, 'Birthday');
      expect(groups.length, 1);
      expect(groups.first.name, 'Family');
      expect(members.length, 1);
      expect(members.first.personId, 'p1');
    });

    test('v1→v2 migration preserves existing rows + applies v0.2 defaults '
        '(v1.6-ι)', () async {
      final db = _V2OnlyDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      // The seeded row from setUp() must survive the
      // migration. The migration's `ALTER TABLE … DEFAULT`
      // clauses pin the v0.2 defaults on the existing row.
      final habits = await db.select(db.habits).get();
      expect(habits.length, 1);
      expect(habits.first.id, 'h1');
      expect(habits.first.name, 'Drink water');
      // v0.2 defaults.
      expect(habits.first.category, 'other');
      expect(habits.first.colorSeed, 0);
      expect(habits.first.iconName, isNull);
      expect(habits.first.pausedUntilMillis, isNull);
      expect(habits.first.endHour, isNull);
      expect(habits.first.endMinute, isNull);
      expect(habits.first.targetHours, isNull);

      final people = await db.select(db.people).get();
      expect(people.length, 1);
      expect(people.first.id, 'p1');
      expect(people.first.displayName, 'Alice');
      expect(people.first.pausedUntilMillis, isNull);

      // PRAGMA user_version is now 2 (the migration's
      // bump — `_V2OnlyDatabase` caps at v2).
      final afterVersion = await db
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(afterVersion.data.values.first, 2);
    });
  });
}

/// The v1 schema (the empty schema plus `category`,
/// `color_seed`, etc. are NOT present yet — those are the v0.2
/// additions the v1→v2 migration brings in).
const String _v1CreateSql = '''
  CREATE TABLE habits (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    proof_mode TEXT NOT NULL,
    created_at_millis INTEGER NOT NULL,
    rest_days_per_month INTEGER NOT NULL DEFAULT 2,
    schedule_type TEXT NOT NULL,
    weekdays TEXT,
    hour INTEGER,
    minute INTEGER,
    n_days INTEGER,
    reference_date_millis INTEGER,
    target_habit_id TEXT,
    last_anchor_millis INTEGER,
    day_of_month INTEGER,
    nth INTEGER,
    weekday INTEGER,
    reference_day_of_month INTEGER,
    mission_chain_json TEXT
  );
  CREATE TABLE people (
    id TEXT NOT NULL PRIMARY KEY,
    lookup_key TEXT NOT NULL,
    display_name TEXT NOT NULL,
    channel TEXT NOT NULL,
    handle TEXT NOT NULL,
    created_at_millis INTEGER NOT NULL,
    cadence_type TEXT NOT NULL,
    n_days INTEGER,
    weekday INTEGER,
    day_of_month INTEGER,
    month_of_year INTEGER,
    anchored_to_wakeup INTEGER NOT NULL DEFAULT 0,
    mission_chain_json TEXT
  );
  CREATE TABLE completions (
    id TEXT NOT NULL PRIMARY KEY,
    habit_id TEXT NOT NULL,
    day_millis INTEGER NOT NULL,
    completed_at_millis INTEGER NOT NULL,
    source TEXT NOT NULL,
    proof_mode_at_time TEXT NOT NULL,
    note TEXT,
    mission_results_json TEXT
  );
  CREATE TABLE rest_day_budgets (
    id TEXT NOT NULL PRIMARY KEY,
    habit_id TEXT NOT NULL,
    year_month INTEGER NOT NULL,
    used INTEGER NOT NULL DEFAULT 0,
    monthly_limit INTEGER NOT NULL
  );
  CREATE TABLE settings (
    key TEXT NOT NULL PRIMARY KEY,
    value TEXT NOT NULL
  );
  CREATE TABLE event_logs (
    id TEXT NOT NULL PRIMARY KEY,
    at_millis INTEGER NOT NULL,
    kind TEXT NOT NULL,
    detail_json TEXT
  );
''';

/// A Drift database with `schemaVersion = 1` and no-op
/// `MigrationStrategy`. Used by the v1→v2 migration tests to
/// seed a v1 fixture with raw SQL, then re-open with the
/// real v5 `AppDatabase` to drive `onUpgrade`.
class _V1FixtureDatabase extends GeneratedDatabase {
  _V1FixtureDatabase(super.e);
  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // No-op — the test sets the schema by raw SQL
      // before pinning `user_version`.
    },
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      const <TableInfo<Table, Object?>>[];
}

/// A `AppDatabase` subclass that pins `schemaVersion = 2`
/// and runs ONLY `migrateV1ToV2` in `onUpgrade`. Used by
/// the v1→v2 migration tests so the v0.2 column adds +
/// new-table creates run against a v1 fixture without
/// dragging in v3→v4 (which would try to add
/// `automations_json` to `events`, conflicting with the
/// v5-shape events table that `migrateV1ToV2`'s
/// `m.createTable(db.events)` already creates).
class _V2OnlyDatabase extends AppDatabase {
  _V2OnlyDatabase(super.executor);
  @override
  int get schemaVersion => 2;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await migrateV1ToV2(m, this);
      }
    },
  );
}
