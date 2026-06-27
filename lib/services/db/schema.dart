// Drift database schema — wires the tables defined in
// `tables.dart` and pins the current schema version.
//
// The schema version is bumped on every column add / drop / type
// change. The matching migration file MUST land in
// `lib/services/db/migrations/vN_to_vM.dart` and be referenced from
// [migrations] below.
//
// Version history:
//   1 — initial schema (habits, people, completions, budgets,
//       settings, event log). 2026-06-13.
//   2 — v0.2 (committed 2026-06-14):
//       + habits.category, colorSeed, iconName, pausedUntilMillis
//       + habits.endHour, endMinute, targetHours (for timeWindow)
//       + people.pausedUntilMillis
//       + events table
//       + person_groups table
//       + person_group_members table
//       The migration is in `migrations/v1_to_v2.dart`.
//   3 — v1.0 reframe (Phase B PR 1, 2026-06-20):
//       + templates table (curated bootstrap shapes for
//         dos / events / people / routines; user-saved
//         custom templates on the same row shape).
//       The migration is in `migrations/v2_to_v3.dart`.
//       Built-in templates are seeded separately from
//       `main.dart` via `TemplateLibrary.seedBuiltIns(...)`.
//   4 — v1.0 reframe (Phase C PR 1, 2026-06-20):
//       + habits.automations_json (TEXT nullable)
//       + people.automations_json (TEXT nullable)
//       + events.automations_json (TEXT nullable)
//       The migration is in `migrations/v3_to_v4.dart`. The
//       envelope is `{"k":1,"automations":[...]}` per
//       `kAutomationFormatVersion` in
//       `lib/triggers/automation_codec.dart`. NULL post-
//       migration means "no non-default automations" (the
//       default `ActionNotify` is synthesized at dispatch
//       time, not stored).
//   5 — v1.4l (Phase 39 / SYS-126 / ADR-056 / WF-053):
//       + habits.deleted_at_millis (INTEGER nullable) —
//       the soft-delete tombstone column. NULL = active,
//       non-null = tombstoned at this epoch millisecond.
//       The migration is in `migrations/v4_to_v5.dart`.
//       Replaces the brittle v1.4h "delete +
//       insertOnConflictUpdate on Undo" path with a true
//       restore (Undelete = `UPDATE … SET deleted_at_millis
//       = NULL WHERE id = ?`). The `Habits` row + its
//       completion-log rows stay in the DB across the
//       delete / Undo cycle, so `ConsecutiveCounter.compute`
//       can rebuild the streak from the log on restore. See
//       ADR-056 for the design rationale (the v1.4h trade-
//       off that motivated v1.4l).

import 'package:drift/drift.dart';

import 'package:doit/services/db/migrations/v1_to_v2.dart';
import 'package:doit/services/db/migrations/v2_to_v3.dart';
import 'package:doit/services/db/migrations/v3_to_v4.dart';
import 'package:doit/services/db/migrations/v4_to_v5.dart';
import 'package:doit/services/db/tables.dart';

part 'schema.g.dart';

/// Current schema version. Bump on every column add / drop / type
/// change. The matching migration file MUST land in
/// `lib/services/db/migrations/vN_to_vM.dart` and be referenced from
/// [migrations] below.
const int kCurrentSchemaVersion = 5;

@DriftDatabase(
  tables: [
    Habits,
    People,
    Completions,
    RestDayBudgets,
    Settings,
    EventLogs,
    // v0.2
    Events,
    PersonGroups,
    PersonGroupMembers,
    // v1.0 reframe (Phase B PR 1)
    Templates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Override point for tests: use an in-memory or temp-file
  /// executor. The default `NativeDatabase` lives in `db.dart`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => kCurrentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await migrateV1ToV2(m, this);
      }
      if (from < 3) {
        await migrateV2ToV3(m, this);
      }
      if (from < 4) {
        await migrateV3ToV4(m, this);
      }
      if (from < 5) {
        await migrateV4ToV5(m, this);
      }
    },
    beforeOpen: (details) async {
      // Foreign-key support is on by default in modern Drift,
      // but pin it explicitly so a future Drift bump cannot
      // silently turn it off.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
