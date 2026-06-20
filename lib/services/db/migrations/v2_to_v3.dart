// Schema migration v2 → v3 (v1.0 reframe, Phase B PR 1).
//
// Changes:
//   - new table: templates
//     (curated bootstrap shapes for dos / events / people /
//     routines; user-saved custom templates on the same row
//     shape; see `lib/templates/template.dart` and
//     `lib/templates/template_library.dart`).
//
// Per .claude/rules/lib-services.md, migrations live in
// `lib/services/db/migrations/` and are referenced from
// `schema.dart` `MigrationStrategy.onUpgrade`.
//
// The Drift `Migrator` API requires a `TableInfo<Table, dynamic>`
// for `createTable`, not a `Table` `Type`. We pass the typed
// [AppDatabase] through so we can reach the table-accessor
// (db.templates).
//
// The curated library is seeded separately via
// `TemplateLibrary.seedBuiltIns(...)`, called from `main.dart`
// or `AppDatabaseService.init()`. The migration only creates
// the table; it does NOT auto-seed (seeding is idempotent and
// belongs in the app-init path, not the migration).
// TODO Phase B PR 2: wire `TemplateLibrary.seedBuiltIns(...)` from
// `main.dart` / `AppDatabaseService.init()`.

import 'package:drift/drift.dart';

import 'package:doit/services/db/schema.dart';

Future<void> migrateV2ToV3(Migrator m, AppDatabase db) async {
  // --- New table (typed, using the database accessor).
  await m.createTable(db.templates);
}
