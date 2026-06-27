// Schema migration v4 → v5 (v1.4l / Phase 39 / SYS-126 /
// ADR-056 / WF-053).
//
// Changes:
//   - habits: + deletedAtMillis (INTEGER nullable)
//
// The new column is the soft-delete tombstone. `null` means
// "active"; non-null means "soft-deleted at this epoch
// millisecond". The column is nullable so a fresh row +
// every existing row get `null` (= active) on migration
// without a data rewrite. The Drift `insertOnConflictUpdate`
// path used by `DoRepository.save` does NOT touch this
// column (the repository's `_toRow` does not include it),
// which preserves the "save is content-only" invariant:
//
//   - A row that exists and is tombstoned → save() leaves
//     the tombstone intact (Drift's insertOnConflictUpdate
//     preserves existing column values when the new
//     insertOnConflictUpdate row doesn't specify them).
//   - A row that exists and is active → save() is a no-op
//     for the tombstone column (still null).
//   - A row that's been hard-deleted (the
//     `DoRepository.deleteById` force path) → save()
//     re-inserts as active (null tombstone).
//
// Restoration from a tombstone is the
// `DoRepository.restoreById` method, NOT save().
//
// Per .claude/rules/lib-services.md, migrations live in
// `lib/services/db/migrations/` and are referenced from
// `schema.dart` `MigrationStrategy.onUpgrade`.

import 'package:drift/drift.dart';

import 'package:doit/services/db/schema.dart';

Future<void> migrateV4ToV5(Migrator m, AppDatabase db) async {
  await m.database.customStatement(
    'ALTER TABLE habits ADD COLUMN deleted_at_millis INTEGER',
  );
}
