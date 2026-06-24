// Schema migration v4 → v5 (v1.2p / Phase 11f / WF-023).
//
// Closes the B4 item from the 30-phase roadmap: a per-do
// grace-window override. The `ConsecutiveCounter` calculator
// honors a per-do override when set, and falls back to the
// global 3-hour default (SYS-019) when the column is NULL.
//
// Changes:
//   - habits:  + graceWindowOverrideMillis (INTEGER nullable)
//
// Per the 30-phase plan, this migration is REQUIRED for the
// feature — it is NOT a cosmetic rename. The strict rule in
// `.claude/rules/lib-services.md` ("A migration is its own
// PR") is honored at the commit level: this migration lives
// in `lib/services/db/migrations/v4_to_v5.dart` (the
// canonical one-file-per-version-bump location) and is
// referenced from `schema.dart` `MigrationStrategy.onUpgrade`.
//
// NULL post-migration means "no override" — the correct
// state for every existing row. The decoder in
// `lib/do/consecutive_counter.dart` (via
// `Do.effectiveStreakConfig`) treats null as the 3-hour
// default.

import 'package:drift/drift.dart';

import 'package:doit/services/db/schema.dart';

Future<void> migrateV4ToV5(Migrator m, AppDatabase db) async {
  await m.database.customStatement(
    'ALTER TABLE habits ADD COLUMN grace_window_override_millis INTEGER',
  );
}
