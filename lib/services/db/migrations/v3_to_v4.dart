// Schema migration v3 → v4 (v1.0 reframe, Phase C PR 1).
//
// Per the Phase C PR 1 spec:
//
// Changes:
//   - habits:  + automationsJson (TEXT nullable)
//   - people:  + automationsJson (TEXT nullable)
//   - events:  + automationsJson (TEXT nullable)
//
// Per .claude/rules/lib-services.md, migrations live in
// `lib/services/db/migrations/` and are referenced from
// `schema.dart` `MigrationStrategy.onUpgrade`.
//
// The Drift `Migrator` API does not expose a typed
// `addColumn(table, column)`; we use `customStatement` with
// raw `ALTER TABLE ADD COLUMN`. NULL post-migration means
// "no non-default automations" — the correct state for every
// existing row. The decoder in `lib/routines/routine.dart`
// treats null/empty as an empty list.

import 'package:drift/drift.dart';

import 'package:doit/services/db/schema.dart';

Future<void> migrateV3ToV4(Migrator m, AppDatabase db) async {
  await m.database.customStatement(
    'ALTER TABLE habits ADD COLUMN automations_json TEXT',
  );
  await m.database.customStatement(
    'ALTER TABLE people ADD COLUMN automations_json TEXT',
  );
  await m.database.customStatement(
    'ALTER TABLE events ADD COLUMN automations_json TEXT',
  );
}
