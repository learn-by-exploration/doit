// Drift database schema — wires the tables defined in
// `tables.dart` and pins the current schema version.
//
// The schema version is bumped on every column add / drop / type
// change. v0.1 ships at version 1. The matching migration file
// for v1 → v1 (no-op) lives at
// `lib/services/migrations/v1_initial.dart` per
// .claude/rules/lib-services.md.

import 'package:drift/drift.dart';

import 'package:common_games/services/db/tables.dart';

part 'schema.g.dart';

/// Current schema version. Bump on every column add / drop / type
/// change. The matching migration file MUST land in
/// `lib/services/migrations/vN_to_vM.dart` and be referenced from
/// [migrations] below.
///
/// Version history:
///   1 — initial schema (habits, people, completions, budgets,
///       settings, event log). 2026-06-13.
const int kCurrentSchemaVersion = 1;

@DriftDatabase(
  tables: [Habits, People, Completions, RestDayBudgets, Settings, EventLogs],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Override point for tests: use an in-memory or temp-file
  /// executor. The default `NativeDatabase` lives in `db.dart`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => kCurrentSchemaVersion;

  // No data migrations for v1. Future versions append to this
  // list; see .claude/rules/lib-services.md for the migration
  // file naming convention.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Migrations are added here as v2, v3, etc. land. v1
      // is the initial schema; nothing to do.
    },
    beforeOpen: (details) async {
      // Foreign-key support is on by default in modern Drift,
      // but pin it explicitly so a future Drift bump cannot
      // silently turn it off.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
