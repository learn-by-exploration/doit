// Schema migration v1 → v2 (v0.2 foundation).
//
// Changes:
//   - habits: + category (TEXT default 'other'),
//             colorSeed (INTEGER default 0),
//             iconName (TEXT nullable),
//             pausedUntilMillis (INTEGER nullable),
//             endHour (INTEGER nullable),
//             endMinute (INTEGER nullable),
//             targetHours (INTEGER nullable)
//   - people: + pausedUntilMillis (INTEGER nullable)
//   - new table: events
//   - new table: person_groups
//   - new table: person_group_members
//
// Per .claude/rules/lib-services.md, migrations live in
// `lib/services/db/migrations/` and are referenced from
// `schema.dart` `MigrationStrategy.onUpgrade`.
//
// The Drift `Migrator` API requires a `TableInfo<Table, dynamic>`
// for `createTable`, not a `Table` `Type`. We pass the typed
// [AppDatabase] through so we can reach the table-accessors
// (db.events, db.personGroups, etc.). Column adds use raw SQL
// since Drift's migrator doesn't expose a typed `addColumn`.

import 'package:drift/drift.dart';

import 'package:common_games/services/db/schema.dart';

Future<void> migrateV1ToV2(Migrator m, AppDatabase db) async {
  // --- Column adds on existing tables (raw SQL — Drift's
  // Migrator API is SQL-based for column adds, not type-driven).
  await m.database.customStatement(
    'ALTER TABLE habits ADD COLUMN category TEXT NOT NULL DEFAULT \'other\'',
  );
  await m.database.customStatement(
    'ALTER TABLE habits ADD COLUMN color_seed INTEGER NOT NULL DEFAULT 0',
  );
  await m.database.customStatement(
    'ALTER TABLE habits ADD COLUMN icon_name TEXT',
  );
  await m.database.customStatement(
    'ALTER TABLE habits ADD COLUMN paused_until_millis INTEGER',
  );
  await m.database.customStatement(
    'ALTER TABLE habits ADD COLUMN end_hour INTEGER',
  );
  await m.database.customStatement(
    'ALTER TABLE habits ADD COLUMN end_minute INTEGER',
  );
  await m.database.customStatement(
    'ALTER TABLE habits ADD COLUMN target_hours INTEGER',
  );
  await m.database.customStatement(
    'ALTER TABLE people ADD COLUMN paused_until_millis INTEGER',
  );
  // --- New tables (typed, using the database accessors).
  await m.createTable(db.events);
  await m.createTable(db.personGroups);
  await m.createTable(db.personGroupMembers);
}
