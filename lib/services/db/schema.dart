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
//   5 — v1.2p (Phase 11f / WF-023):
//       + habits.grace_window_override_millis (INTEGER nullable)
//       The migration is in `migrations/v4_to_v5.dart`. NULL
//       post-migration means "no per-do override; use the
//       3-hour global default from SYS-019". Per-do overrides
//       are honored by `ConsecutiveCounter` via
//       `Do.effectiveStreakConfig`.
//   6 — v1.2r (Phase 11h / WF-020):
//       + habits.target_count (INTEGER nullable)
//       + habits.quota_reset_hour (INTEGER nullable)
//       + habits.quota_reset_minute (INTEGER nullable)
//       The migration is in `migrations/v5_to_v6.dart`. NULL
//       post-migration means "this is not a quota habit" —
//       the correct state for every existing row. The
//       decoder in `lib/services/do_repository.dart`
//       (`_scheduleTypeTag` and `_fromRow`) writes the
//       columns NULL for non-quota rows and reads them back
//       for `DoQuota` rows.

import 'package:drift/drift.dart';

import 'package:doit/services/db/migrations/v1_to_v2.dart';
import 'package:doit/services/db/migrations/v2_to_v3.dart';
import 'package:doit/services/db/migrations/v3_to_v4.dart';
import 'package:doit/services/db/migrations/v4_to_v5.dart';
import 'package:doit/services/db/migrations/v5_to_v6.dart';
import 'package:doit/services/db/tables.dart';

part 'schema.g.dart';

/// Current schema version. Bump on every column add / drop / type
/// change. The matching migration file MUST land in
/// `lib/services/db/migrations/vN_to_vM.dart` and be referenced from
/// [migrations] below.
const int kCurrentSchemaVersion = 6;

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
      if (from < 6) {
        await migrateV5ToV6(m, this);
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
