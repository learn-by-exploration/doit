// Schema migration v5 → v6 (v2.0 retention / PR-E1 / SYS-194).
//
// Changes:
//   - new table: scheduled_messages
//     (one-shot scheduled contact reminders — person + channel
//     + exact fire time + optional pre-filled message body +
//     status lifecycle + audit-fired-at timestamp). Created to
//     unblock the "remind me to message this person at this
//     exact time" feature shipped in PR-E2 (url_launcher wire +
//     Schedule-a-message screen). See
//     `lib/services/db/tables.dart` `ScheduledMessages` for the
//     full column reference.
//
// Per .claude/rules/lib-services.md, migrations live in
// `lib/services/db/migrations/` and are referenced from
// `schema.dart` `MigrationStrategy.onUpgrade`.
//
// The Drift `Migrator` API requires a `TableInfo<Table, dynamic>`
// for `createTable`, not a `Table` `Type`. We pass the typed
// [AppDatabase] through so we can reach the table-accessor
// (db.scheduledMessages).
//
// The scheduler / notification wire for this table is
// scheduled for PR-E2. The migration only creates the table —
// no service layer, no UI, no seed data. A fresh-DB install
// (`onCreate` → `createAll`) creates the table in lockstep
// with the rest of the schema; an upgrade from a v5 DB
// (`onUpgrade` → `if (from < 6) await migrateV5ToV6`) creates
// just the new table on top of the v5 schema.
//
// No `DateTime.now()` inside the migration (the test fixture
// uses fixed millis). The Drift `Migrator` API itself is pure
// relative to the reference time.

import 'package:drift/drift.dart';

import 'package:doit/services/db/schema.dart';

Future<void> migrateV5ToV6(Migrator m, AppDatabase db) async {
  // --- New table (typed, using the database accessor).
  await m.createTable(db.scheduledMessages);
}
