// Tests for the Drift database v2→v3 migration (Phase B PR 1).
//
// Sets the precedent for a real fixture-based migration test:
//   1. Create a v2-schema DB manually (raw SQL), seed a few
//      rows in `habits`, `completions`, `settings`, and
//      `events`, and pin `PRAGMA user_version = 2`.
//   2. Close the file-backed DB and re-open it with the v3
//      `AppDatabase` (kCurrentSchemaVersion = 3).
//   3. Assert:
//      - `onUpgrade(from: 2, to: 3)` ran cleanly
//        (schemaVersion is 3).
//      - The v2 tables still hold the seeded rows
//        (no data loss).
//      - The new `templates` table exists and is empty
//        (the migration does NOT auto-seed — seeding lives
//        in `TemplateLibrary.seedBuiltIns`, called separately
//        from `main.dart`).
//
// Why a raw-SQL fixture instead of building a separate v2
// `AppDatabase`? `kCurrentSchemaVersion` is a `const int`; it
// cannot be overridden per test. Building a parallel v2 class
// would duplicate the schema. The raw-SQL approach keeps the
// fixture small and the assertion tight.

import 'dart:io';

import 'package:doit/services/db/schema.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const String _v2CreateSql = '''
  -- The v2 schema. Created at v0.2 by the v1→v2 migration;
  -- the v2→v3 migration only adds the templates table on top.
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
    end_hour INTEGER,
    end_minute INTEGER,
    target_hours INTEGER,
    mission_chain_json TEXT,
    category TEXT NOT NULL DEFAULT 'other',
    color_seed INTEGER NOT NULL DEFAULT 0,
    icon_name TEXT,
    paused_until_millis INTEGER
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
    mission_chain_json TEXT,
    paused_until_millis INTEGER
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
  CREATE TABLE events (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    at_millis INTEGER NOT NULL,
    lead_time_millis INTEGER NOT NULL,
    mission_chain_json TEXT,
    recurrence TEXT NOT NULL DEFAULT 'none',
    archived_at_millis INTEGER,
    created_at_millis INTEGER NOT NULL
  );
  CREATE TABLE person_groups (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    cadence_type TEXT NOT NULL,
    semantic TEXT NOT NULL,
    channel TEXT NOT NULL,
    handle TEXT NOT NULL,
    mission_chain_json TEXT,
    created_at_millis INTEGER NOT NULL,
    paused_until_millis INTEGER
  );
  CREATE TABLE person_group_members (
    group_id TEXT NOT NULL,
    person_id TEXT NOT NULL,
    added_at_millis INTEGER NOT NULL,
    last_contacted_millis INTEGER,
    PRIMARY KEY (group_id, person_id)
  );
''';

void main() {
  // Silence the Drift "multiple databases on same executor"
  // warning: this test legitimately opens AppDatabase multiple
  // times on the same file (once to trigger the migration,
  // once to assert no re-run). Serial lifecycle prevents races.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late File dbFile;
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('doit_mig_v2_v3_');
    dbFile = File(p.join(tmpDir.path, 'fixture.db'));
    // Build the v2 fixture with a Drift database that has NO
    // onCreate / onUpgrade — so the schema and user_version are
    // entirely under our control via raw SQL.
    final db = _RawSqliteDatabase(NativeDatabase(dbFile));
    try {
      await db.customStatement(_v2CreateSql);
      await db.customStatement(
        'INSERT INTO habits (id, name, proof_mode, created_at_millis, '
        'schedule_type, hour, minute) VALUES '
        "('h1', 'Drink water', 'soft', 1748736000000, 'fixed', 9, 0)",
      );
      await db.customStatement(
        'INSERT INTO completions (id, habit_id, day_millis, '
        'completed_at_millis, source, proof_mode_at_time) VALUES '
        "('c1', 'h1', 1748736000000, 1748736000000, 'manual', 'soft')",
      );
      await db.customStatement(
        "INSERT INTO settings (key, value) VALUES ('theme', 'dark')",
      );
      await db.customStatement(
        'INSERT INTO events (id, name, at_millis, lead_time_millis, '
        'created_at_millis) VALUES '
        "('e1', 'Birthday', 1748736000000, 86400000, 1748736000000)",
      );
      await db.customStatement('PRAGMA user_version = 2');
    } finally {
      await db.close();
    }
  });

  tearDown(() async {
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('v2→v3 migration upgrades schema and preserves rows', () async {
    // Open with the v5 AppDatabase. Drift sees user_version = 2
    // (set in setUp) and kCurrentSchemaVersion = 5, so
    // onUpgrade runs migrateV2ToV3 + migrateV3ToV4 + migrateV4ToV5.
    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    // (1) Schema version is now 5 (current).
    expect(db.schemaVersion, 5);

    // (2) The v2 rows survive.
    final habits = await db.select(db.habits).get();
    expect(habits.length, 1);
    expect(habits.first.name, 'Drink water');
    final completions = await db.select(db.completions).get();
    expect(completions.length, 1);
    expect(completions.first.habitId, 'h1');
    final settings = await db.select(db.settings).get();
    expect(settings.length, 1);
    expect(settings.first.value, 'dark');
    final events = await db.select(db.events).get();
    expect(events.length, 1);
    expect(events.first.name, 'Birthday');

    // (3) The new templates table exists and is empty (the
    // migration does NOT auto-seed).
    final templates = await db.select(db.templates).get();
    expect(templates, isEmpty);

    // (4) PRAGMA user_version is now 5 (the bump is what
    //     prevents the migration from re-running on next open).
    //     Phase C PR 1 stacked migrateV3ToV4 on top of v2→v3;
    //     v1.4l stacked migrateV4ToV5 on top of that, so the
    //     live schema is v5 even for an entity whose first
    //     non-trivial migration was v2→v3.
    final afterVersion = await db
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(afterVersion.data.values.first, 5);
  });

  test('re-opening after migration does not re-run onUpgrade', () async {
    // First open: triggers migration.
    final db1 = AppDatabase(NativeDatabase(dbFile));
    await db1.select(db1.templates).get(); // force schema work
    await db1.close();
    // Second open on the same file: must be a no-op.
    final db2 = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db2.close);
    expect(db2.schemaVersion, 5);
    final templates = await db2.select(db2.templates).get();
    expect(templates, isEmpty);
  });

  test(
    'inserting a template post-migration works (table is writable)',
    () async {
      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      await db
          .into(db.templates)
          .insert(
            const TemplateRow(
              id: 't_user_post_mig',
              name: 'Post-migration template',
              description: 'Inserted after the v2→v3 migration.',
              iconName: 'check',
              entityType: 'do',
              payloadJson: '{"k":1,"do":{}}',
              isBuiltIn: false,
              createdAtMillis: 1748736000000,
            ),
          );
      final back = await db.select(db.templates).getSingle();
      expect(back.name, 'Post-migration template');
    },
  );
}

/// A Drift database that runs no schema management on open.
/// We use it to seed the v2 fixture with raw SQL: open, run
/// customStatement, close. The next open with the real
/// [AppDatabase] (v3) sees `user_version = 2` and runs the
/// v2→v3 migration on top of the existing schema.
class _RawSqliteDatabase extends GeneratedDatabase {
  _RawSqliteDatabase(super.e);
  @override
  int get schemaVersion => 2;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // Intentionally empty: the test sets the schema by raw
      // SQL before pinning user_version. Drift will run
      // onUpgrade(from: 0, to: 2) — but our migration strategy
      // is a no-op, so nothing changes.
    },
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      const <TableInfo<Table, Object?>>[];
}
