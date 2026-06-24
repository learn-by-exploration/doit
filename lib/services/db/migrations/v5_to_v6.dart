// Schema migration v5 → v6 (v1.2r / Phase 11h / WF-020).
//
// Closes the B1 item from the 30-phase roadmap: a quota
// habit ("5 cups water, any time today"). The model gains
// a sealed `DoQuota` leaf (lib/do/do.dart) with two
// schedule-specific fields — `targetCount` (int >= 1) and
// `resetAt` (DoTime as `quota_reset_hour` + `quota_reset_minute`).
//
// Changes:
//   - habits:  + targetCount (INTEGER nullable)
//   - habits:  + quotaResetHour (INTEGER nullable)
//   - habits:  + quotaResetMinute (INTEGER nullable)
//
// Per the 30-phase plan, this migration is REQUIRED for the
// feature — it is NOT a cosmetic rename. The strict rule in
// `.claude/rules/lib-services.md` ("A migration is its own
// PR") is honored at the commit level: this migration lives
// in `lib/services/db/migrations/v5_to_v6.dart` (the
// canonical one-file-per-version-bump location) and is
// referenced from `schema.dart` `MigrationStrategy.onUpgrade`.
//
// NULL post-migration means "this is not a quota habit" —
// the correct state for every existing row, all of which
// are one of the previous 6 schedule types. The decoder in
// `lib/services/do_repository.dart` (`_scheduleTypeTag`
// and `_fromRow`) writes the column NULL for non-quota
// rows and reads it back for `DoQuota` rows.

import 'package:drift/drift.dart';

import 'package:doit/services/db/schema.dart';

Future<void> migrateV5ToV6(Migrator m, AppDatabase db) async {
  await m.database.customStatement(
    'ALTER TABLE habits ADD COLUMN target_count INTEGER',
  );
  await m.database.customStatement(
    'ALTER TABLE habits ADD COLUMN quota_reset_hour INTEGER',
  );
  await m.database.customStatement(
    'ALTER TABLE habits ADD COLUMN quota_reset_minute INTEGER',
  );
}
