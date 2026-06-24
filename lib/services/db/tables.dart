// Drift table definitions for do it's local SQLite database.
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
//
// v0.2 columns (added in migration v2→v3):
//   - habits.category (TEXT, default 'other')
//   - habits.color_seed (INTEGER, default 0)
//   - habits.icon_name (TEXT, nullable)
//   - habits.paused_until_millis (INTEGER, nullable)
//   - people.paused_until_millis (INTEGER, nullable)
//
// New v0.2 tables (added in migration v2→v3):
//   - events
//   - person_groups
//   - person_group_members
//
// v1.0 reframe tables (added in migration v2→v3, Phase B PR 1):
//   - templates (curated bootstrap shapes for dos / events /
//     people / routines; user-saved custom templates on the
//     same row shape).
//
// v1.0 reframe columns (added in migration v3→v4, Phase C PR 1):
//   - habits.automations_json (TEXT nullable)
//   - people.automations_json (TEXT nullable)
//   - events.automations_json (TEXT nullable)
//   The envelope is `{"k":1,"automations":[...]}` and is
//   decoded by `lib/triggers/automation_codec.dart`.

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
///   - `timeWindow`→ `weekdays` (CSV), `hour`, `minute` (start),
///                   `endHour`, `endMinute` (end)
@DataClassName('HabitRow')
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get proofMode => text()(); // 'soft' | 'strong' | 'auto'
  IntColumn get createdAtMillis => integer()();
  IntColumn get restDaysPerMonth => integer().withDefault(const Constant(2))();
  TextColumn get scheduleType => text()();
  TextColumn get weekdays =>
      text().nullable()(); // CSV; for `fixed` / `timeWindow`
  IntColumn get hour =>
      integer().nullable()(); // 0..23; for `fixed` / `timeWindow` start
  IntColumn get minute =>
      integer().nullable()(); // 0..59; for `fixed` / `timeWindow` start
  IntColumn get nDays => integer().nullable()(); // >= 1; for `interval`
  IntColumn get referenceDateMillis => integer().nullable()();
  TextColumn get targetHabitId => text().nullable()(); // for `anchor`
  IntColumn get lastAnchorMillis => integer().nullable()(); // for `anchor`
  IntColumn get dayOfMonth => integer().nullable()(); // for `dayOfX`
  IntColumn get nth => integer().nullable()(); // 1..5; for `dayOfX`
  IntColumn get weekday => integer().nullable()(); // 1..7; for `dayOfX`
  IntColumn get referenceDayOfMonth => integer().nullable()(); // for `dayOfX`
  // v0.2: end time for `timeWindow` schedule.
  IntColumn get endHour => integer().nullable()(); // 0..23; for `timeWindow`
  IntColumn get endMinute => integer().nullable()(); // 0..59; for `timeWindow`
  // v0.2: target duration in hours for fasting windows (12, 14, 16, 18, 20).
  IntColumn get targetHours => integer().nullable()();
  // Mission chain is stored as JSON in [missionChainJson] to keep
  // the schema simple. Strong habits only; Soft/Auto empty.
  TextColumn get missionChainJson => text().nullable()();
  // v0.2: visual identity. category drives the default color and
  // icon; colorSeed overrides the color (0..7); iconName overrides
  // the icon (one of 64 Material Symbols keys; nullable).
  TextColumn get category => text().withDefault(const Constant('other'))();
  IntColumn get colorSeed => integer().withDefault(const Constant(0))();
  TextColumn get iconName => text().nullable()();
  // v0.2: pause state. When set and in the future, the scheduler
  // does not fire reminders for this habit. A paused period does
  // not break the streak.
  IntColumn get pausedUntilMillis => integer().nullable()();
  // v1.0 (Phase C): non-default automation rules. NULL =
  // "no non-default automations" (the default `ActionNotify`
  // is synthesized at dispatch time, not stored).
  TextColumn get automationsJson => text().nullable()();
  // WF-023 (Phase 11f): per-do grace-window override. NULL =
  // "use the global default (3 hours per SYS-019)". A non-null
  // value (millis) is the override; the calculator reads it
  // via `Do.effectiveStreakConfig`.
  IntColumn get graceWindowOverrideMillis => integer().nullable()();

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
  // v0.2: pause state (see Habits.pausedUntilMillis).
  IntColumn get pausedUntilMillis => integer().nullable()();
  // v1.0 (Phase C): non-default automation rules. NULL =
  // "no non-default automations" (the default `ActionNotify`
  // is synthesized at dispatch time, not stored).
  TextColumn get automationsJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A one-off date-specific reminder ("event"). Lives alongside
/// habits but is not a habit: it has no streak, no rest-day budget,
/// no proof mode (an optional mission is allowed, but Soft-default).
///
/// v0.2 (WF-017). Created in migration v2→v3.
@DataClassName('EventRow')
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get atMillis => integer()(); // event time
  IntColumn get leadTimeMillis => integer()(); // notify at (at - leadTime)
  // Optional mission chain (JSON); null = no mission, just a notification.
  TextColumn get missionChainJson => text().nullable()();
  // 'none' | 'annually'
  TextColumn get recurrence => text().withDefault(const Constant('none'))();
  // When archived. Null = active. Auto-set 24h after fire.
  IntColumn get archivedAtMillis => integer().nullable()();
  IntColumn get createdAtMillis => integer()();
  // v1.0 (Phase C): non-default automation rules. NULL =
  // "no non-default automations" (the default `ActionNotify`
  // is synthesized at dispatch time, not stored).
  TextColumn get automationsJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A contact group (v0.2 WF-018). Created in migration v2→v3.
@DataClassName('PersonGroupRow')
class PersonGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  // 'every_n_days' | 'weekly_on' | 'monthly_on' | 'yearly_on'
  TextColumn get cadenceType => text()();
  // 'rotation' | 'any' | 'all'
  TextColumn get semantic => text()();
  TextColumn get channel => text()();
  TextColumn get handle => text()();
  TextColumn get missionChainJson => text().nullable()();
  IntColumn get createdAtMillis => integer()();
  IntColumn get pausedUntilMillis => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Membership of a person in a group, with the
/// `lastContactedMillis` per member (used by the rotation selector
/// and the `All` selector).
///
/// v0.2 (WF-018). Created in migration v2→v3.
@DataClassName('PersonGroupMemberRow')
class PersonGroupMembers extends Table {
  TextColumn get groupId => text()();
  TextColumn get personId => text()();
  IntColumn get addedAtMillis => integer()();
  IntColumn get lastContactedMillis => integer().nullable()();

  @override
  Set<Column> get primaryKey => {groupId, personId};
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

/// A template — a saved shape the user can pick to bootstrap a
/// new do / event / person / routine. Templates are versioned by
/// `payloadJson` format (see `kTemplateFormatVersion` in
/// `lib/templates/template_library.dart`); the repository
/// validates the envelope `k` on save.
///
/// Built-in templates are seeded by `TemplateLibrary.seedBuiltIns`
/// from `main.dart`. The migration only creates the table; it
/// does NOT auto-seed (seeding is idempotent and belongs in the
/// app-init path, not the migration).
///
/// v1.0 reframe (Phase B PR 1). Created in migration v2→v3.
@DataClassName('TemplateRow')
class Templates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get iconName => text()();
  // 'do' | 'event' | 'person' | 'routine' — see TemplateEntityType.
  TextColumn get entityType => text()();
  TextColumn get payloadJson => text()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get createdAtMillis => integer()();
  IntColumn get lastUsedAtMillis => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
