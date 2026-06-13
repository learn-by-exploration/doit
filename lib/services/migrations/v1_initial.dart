// v1 (initial) migration. The schema is created in
// `lib/services/db/schema.dart` via `MigrationStrategy.onCreate`;
// this file is a placeholder so the directory structure is in
// place and v2 → v1 downgrades can be tested against a v1
// fixture.
//
// When a v2 lands, this directory gains `v1_to_v2.dart` with a
// `Future<void> migrateV1ToV2(Migrator m)` that gets called
// from `AppDatabase.migration.onUpgrade` in `schema.dart`.

import 'package:drift/drift.dart';

/// Marker for the v1 schema. The on-create step in `schema.dart`
/// is the source of truth for the v1 table layout. This function
/// exists so a v1 fixture can be reconstructed by tests without
/// depending on the on-create callback directly.
Future<void> createV1Schema(Migrator m) async {
  await m.createAll();
}
