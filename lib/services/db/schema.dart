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

import 'package:drift/drift.dart';

import 'package:common_games/services/db/migrations/v1_to_v2.dart';
import 'package:common_games/services/db/tables.dart';

part 'schema.g.dart';

/// Current schema version. Bump on every column add / drop / type
/// change. The matching migration file MUST land in
/// `lib/services/db/migrations/vN_to_vM.dart` and be referenced from
/// [migrations] below.
const int kCurrentSchemaVersion = 2;

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
    },
    beforeOpen: (details) async {
      // Foreign-key support is on by default in modern Drift,
      // but pin it explicitly so a future Drift bump cannot
      // silently turn it off.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
