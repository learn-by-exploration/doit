// Drift table definitions for Streak's local SQLite database.
//
// The schema is deliberately normalized: a habit's schedule-type
// discriminator lives in `Habits.scheduleType`; the type-specific
// parameters live in JSON columns (weekdays, nDays, dayOfMonth,
// etc.). This keeps the table count low and makes migrations
// simpler — adding a schedule type or mission type in v0.2 is a
// matter of a new discriminator value + a new column, not a new
// table.
//
// All `DateTime` columns store millis since epoch (UTC). The
// domain layer is responsible for converting to local-day for
// dedupe / display.

import 'package:drift/drift.dart';

/// A habit record. The schedule discriminator is `scheduleType`;
/// the payload columns are nullable and only filled for their
/// matching type.
///
/// JSON layout per `scheduleType`:
///   - `fixed`     → `weekdays` (CSV of 1..7), `hour`, `minute`
///   - `interval`  → `nDays` (int), `referenceDateMillis` (long)
///   - `anchor`    → `targetHabitId` (text), `lastAnchorMillis` (long, nullable)
///   - `dayOfX`    → `dayOfMonth` (int, nullable),
///                   `nth` (int, nullable), `weekday` (int, nullable),
///                   `referenceDayOfMonth` (int, nullable)
@DataClassName('HabitRow')
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get proofMode => text()(); // 'soft' | 'strong' | 'auto'
  IntColumn get createdAtMillis => integer()();
  IntColumn get restDaysPerMonth => integer().withDefault(const Constant(2))();
  TextColumn get scheduleType => text()();
  TextColumn get weekdays => text().nullable()(); // CSV; for `fixed`
  IntColumn get hour => integer().nullable()(); // 0..23; for `fixed`
  IntColumn get minute => integer().nullable()(); // 0..59; for `fixed`
  IntColumn get nDays => integer().nullable()(); // >= 1; for `interval`
  IntColumn get referenceDateMillis => integer().nullable()();
  TextColumn get targetHabitId => text().nullable()(); // for `anchor`
  IntColumn get lastAnchorMillis => integer().nullable()(); // for `anchor`
  IntColumn get dayOfMonth => integer().nullable()(); // for `dayOfX`
  IntColumn get nth => integer().nullable()(); // 1..5; for `dayOfX`
  IntColumn get weekday => integer().nullable()(); // 1..7; for `dayOfX`
  IntColumn get referenceDayOfMonth => integer().nullable()(); // for `dayOfX`
  // Mission chain is stored as JSON in [missionChainJson] to keep
  // the schema simple. Strong habits only; Soft/Auto empty.
  TextColumn get missionChainJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A person record (cadence-style habit). Cadence is a sealed
/// shape; the discriminator is `cadenceType`; the payload columns
/// are nullable and only filled for their matching type.
@DataClassName('PersonRow')
class People extends Table {
  TextColumn get id => text()();
  TextColumn get lookupKey => text()();
  TextColumn get displayName => text()();
  TextColumn get channel =>
      text()(); // 'dialer' | 'whatsapp' | 'telegram' | 'signal' | 'sms'
  TextColumn get handle => text()(); // phone number or @handle
  IntColumn get createdAtMillis => integer()();
  TextColumn get cadenceType =>
      text()(); // 'every_n_days' | 'weekly_on' | 'monthly_on' | 'yearly_on'
  IntColumn get nDays => integer().nullable()(); // for `every_n_days`
  IntColumn get weekday => integer().nullable()(); // 1..7; for `weekly_on`
  IntColumn get dayOfMonth =>
      integer().nullable()(); // 1..31; for `monthly_on` and `yearly_on`
  IntColumn get monthOfYear => integer().nullable()(); // 1..12; for `yearly_on`
  // Optional: anchor on a wake-up event vs an absolute date.
  BoolColumn get anchoredToWakeup =>
      boolean().withDefault(const Constant(false))();
  TextColumn get missionChainJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per (habit, calendar-day, completion-action). The
/// `(habitId, dayMillis)` unique index is the dedupe key — a
/// double-tap of "Done" produces one row, not two.
@DataClassName('CompletionRow')
class Completions extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text()();
  // Day bucket in local time, stored at midnight UTC. The service
  // layer is responsible for normalization.
  IntColumn get dayMillis => integer()();
  IntColumn get completedAtMillis => integer()();
  TextColumn get source =>
      text()(); // 'manual' | 'notification' | 'mission' | 'rest_day'
  TextColumn get proofModeAtTime => text()(); // 'soft' | 'strong' | 'auto'
  TextColumn get note => text().nullable()();
  TextColumn get missionResultsJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Rest-day budget per habit, per calendar month. The model layer
/// treats this as derived state (computed from the completion log
/// `source = 'rest_day'`), but the persistent snapshot allows a
/// fast read on the home screen without re-scanning the log.
@DataClassName('RestDayBudgetRow')
class RestDayBudgets extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text()();
  IntColumn get yearMonth => integer()(); // YYYYMM as int (e.g., 202606)
  IntColumn get used => integer().withDefault(const Constant(0))();
  IntColumn get monthlyLimit => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Key-value settings (theme mode, anchor mode, etc.). The values
/// are stored as text; the service layer is responsible for
/// parsing. The key namespace is `app.<dot.separated>`.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Audit log of state-changing events. Not user-visible; used for
/// debugging and for the `last_diagnostic` settings entry.
@DataClassName('EventLogRow')
class EventLogs extends Table {
  TextColumn get id => text()();
  IntColumn get atMillis => integer()();
  TextColumn get kind =>
      text()(); // 'boot' | 'tz_change' | 'dst' | 'app_update' | 'migration'
  TextColumn get detailJson => text().nullable()();
}
