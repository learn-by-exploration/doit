// CRUD + queries for dos. Pure SQL/Dart — no UI imports.
//
// The repository maps the Drift row (the persistence model) to
// and from the domain `Do` model in `lib/do/do.dart`. The
// mapping lives here so the model layer stays free of Drift
// annotations. Strong-do mission chains are stored as JSON in
// `Habits.missionChainJson`; the repository serializes /
// deserializes via the `Mission` / `MissionChain` types in
// `lib/missions/`.
//
// v0.2 (SYS-042..SYS-047): the repository maps the `category`,
// `colorSeed`, `iconName`, and `pausedUntilMillis` columns, and
// the `DoTimeWindow` schedule type.
//
// v1.0 reframe (Phase A): renamed from `DoRepository` to
// `DoRepository`. The DB table stays `Habits` and the column
// names stay the same — no schema migration.

import 'dart:async';
import 'dart:convert';

import 'package:doit/do/category.dart';
import 'package:doit/do/do.dart' as domain;
import 'package:doit/do/proof_mode.dart';
import 'package:doit/do/proof_mode_tag.dart';
import 'package:doit/missions/chain.dart';
import 'package:doit/missions/mission.dart';
import 'package:doit/routines/routine.dart'
    show decodeAutomationList, encodeAutomationList;
import 'package:drift/drift.dart';

import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';

class DoRepository {
  DoRepository._();

  static final DoRepository instance = DoRepository._();

  Future<void> get _ready => AppDatabaseService.instance.ready;
  AppDatabase get _db => AppDatabaseService.instance.db;

  /// Persist a do. Throws [DuplicateDoName] if a do with the
  /// same trimmed, lower-cased name already exists. The
  /// repository delegates input validation to the model
  /// (`do.validate()`), which throws [DoValidationException]
  /// subclasses on bad input.
  ///
  /// v1.4l (SYS-126 / ADR-056): `save` is **content-only** —
  /// it does NOT touch the tombstone column (`deletedAtMillis`).
  /// The [_toRow] mapping omits `deletedAtMillis` so Drift's
  /// `insertOnConflictUpdate` semantics leave the existing
  /// column value alone (per the Drift docs: "on conflict,
  /// the values you specified override the existing row's
  /// values for those columns; unspecified columns keep the
  /// existing row's value"). This is the invariant that
  /// keeps a tombstone alive across Save clicks — only
  /// [restoreById] can resurrect a tombstoned do.
  ///
  /// Cycle B (SYS-129 / ADR-060): `save` is also
  /// **pause-preserving** — the `pausedUntilMillis` column
  /// is omitted from [_toRow] for the same reason. A Save
  /// click that doesn't explicitly pause/resume must not
  /// silently resume a paused habit. Pause and resume go
  /// through [PauseService.pauseHabit] /
  /// [PauseService.resumeHabit], which use direct
  /// `HabitsCompanion` UPDATEs that explicitly set or clear
  /// the column.
  Future<void> save(domain.Do d) async {
    await _ready;
    d.validate();
    final existing =
        await (_db.select(_db.habits)
              ..where((t) => t.name.lower().equals(d.name.trim().toLowerCase()))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null && existing.id != d.id) {
      throw DuplicateDoName(d.name);
    }
    await _db.into(_db.habits).insertOnConflictUpdate(_toRow(d));
  }

  /// Fetch a do by id. Returns `null` if not present.
  /// **Tombstones are returned** — callers that should never
  /// see tombstoned dos must use [getActiveById] or filter
  /// with [Do.isDeleted]. `getById` is used by the restore
  /// path to fetch a tombstoned row and the by-id widget
  /// deep-link (the widget deep-link clears the cache if the
  /// picked habit is tombstoned — see v1.4k / SYS-125).
  Future<domain.Do?> getById(String id) async {
    await _ready;
    final row = await (_db.select(
      _db.habits,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Fetch an active (non-tombstoned) do by id. Returns `null`
  /// if not present OR tombstoned. UI listings that should
  /// never see tombstones use this. v1.4l (SYS-126 / ADR-056).
  Future<domain.Do?> getActiveById(String id) async {
    final d = await getById(id);
    if (d == null) return null;
    return d.isDeleted ? null : d;
  }

  /// List all dos, oldest-first. Order is the natural
  /// `createdAtMillis` ascending so the home screen renders in
  /// creation order.
  ///
  /// v1.4l (SYS-126 / ADR-056): tombstoned dos are filtered
  /// out at the SQL level (`deletedAtMillis IS NULL`). UI
  /// listings never see tombstones; the restore path uses
  /// [getById] to fetch a specific tombstoned row by id.
  Future<List<domain.Do>> listAll() async {
    await _ready;
    final rows =
        await (_db.select(_db.habits)
              ..where((t) => t.deletedAtMillis.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.createdAtMillis)]))
            .get();
    return rows.map(_fromRow).toList(growable: false);
  }

  /// List dos that are NOT currently paused (pausedUntil is
  /// null OR in the past) AND NOT tombstoned. v0.2 (SYS-047)
  /// for the pause filter; v1.4l (SYS-126) for the tombstone
  /// filter. The scheduler uses this to skip paused +
  /// tombstoned dos when computing the "next occurrence"
  /// across all active dos.
  Future<List<domain.Do>> listActive(DateTime now) async {
    await _ready;
    final rows =
        await (_db.select(_db.habits)
              ..where((t) => t.deletedAtMillis.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.createdAtMillis)]))
            .get();
    return rows
        .map(_fromRow)
        .where((d) => !d.isPausedAt(now))
        .toList(growable: false);
  }

  /// Soft-delete a do. Sets `deletedAtMillis = at` on the
  /// matching row. The `Habits` row + `Completions` +
  /// `RestDayBudgets` rows stay in the table (no FK
  /// declared, no cascade); the do is filtered out of
  /// [listAll] / [listActive] / [getActiveById] until
  /// [restoreById] is called.
  ///
  /// This is the default delete path for the home tile
  /// (v1.4l / SYS-126). The tile's Undo SnackBar calls
  /// [restoreById] with the same id.
  ///
  /// Returns `true` if a row was updated, `false` if no
  /// matching row exists (or was already tombstoned). The
  /// home tile treats `false` as "the helper should not
  /// remove the tile from the UI list" — the user gets the
  /// error snackbar.
  Future<bool> softDeleteById(String id, {required DateTime at}) async {
    await _ready;
    final affected =
        await (_db.update(
          _db.habits,
        )..where((t) => t.id.equals(id) & t.deletedAtMillis.isNull())).write(
          HabitsCompanion(deletedAtMillis: Value(at.millisecondsSinceEpoch)),
        );
    return affected > 0;
  }

  /// Restore a tombstoned do. Sets `deletedAtMillis = NULL`
  /// on the matching row (idempotent — calling on an active
  /// row is a no-op). The `Completions` + `RestDayBudgets`
  /// rows stay attached through the tombstone (no FK
  /// declared, no cascade), so [ConsecutiveCounter.compute]
  /// can rebuild the streak from the log on restore.
  ///
  /// This is the Undo path for the home tile (v1.4l /
  /// SYS-126). v1.4h's Undo path called [save] which
  /// re-inserted via `insertOnConflictUpdate` — that worked
  /// for the row but lost the user's automations (separate
  /// bug, tracked for a v1.4l+ follow-up). v1.4l's
  /// `restoreById` is a single UPDATE so it cannot collide
  /// with `DuplicateDoName`.
  ///
  /// Returns `true` if a row was updated (was tombstoned),
  /// `false` if no matching tombstoned row exists.
  Future<bool> restoreById(String id) async {
    await _ready;
    final affected =
        await (_db.update(_db.habits)
              ..where((t) => t.id.equals(id) & t.deletedAtMillis.isNotNull()))
            .write(const HabitsCompanion(deletedAtMillis: Value(null)));
    return affected > 0;
  }

  /// Force-delete a do by id. Reserved for the
  /// `BackupService.importFrom` wipe path (and any future
  /// admin / debug tools). The completion-log and rest-day
  /// budget rows for a force-deleted do are NOT touched —
  /// the Drift schema declares no FK constraints
  /// (`lib/services/db/tables.dart`), so a force-delete
  /// leaves orphan rows in `Completions` and
  /// `RestDayBudgets` (they are inert; no UI surface
  /// queries by `habitId` against a hard-deleted habit).
  ///
  /// The home tile does NOT call this — it goes through
  /// [softDeleteById] so Undo is a true restore (see
  /// ADR-056 §"Alternatives considered").
  Future<void> deleteById(String id) async {
    await _ready;
    await (_db.delete(_db.habits)..where((t) => t.id.equals(id))).go();
  }

  /// List tombstoned dos, newest-deleted first. Used by the
  /// v1.4m (SYS-127) "Recently deleted" surface and the
  /// v1.4m `purgeDeletedOlderThan` auto-purge. The order is
  /// `deletedAtMillis DESC` so the UI shows the most
  /// recently deleted at the top.
  ///
  /// Tombstones are a transient undo affordance (v1.4l /
  /// ADR-056); the surface should auto-purge after a TTL
  /// (default 30 days) to bound the table. The `limit`
  /// parameter caps the result set so the surface stays
  /// O(1)-render regardless of how many tombstones
  /// accumulate between purges.
  Future<List<domain.Do>> listDeleted({int? limit}) async {
    await _ready;
    final query = _db.select(_db.habits)
      ..where((t) => t.deletedAtMillis.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.deletedAtMillis)]);
    if (limit != null) {
      query.limit(limit);
    }
    final rows = await query.get();
    return rows.map(_fromRow).toList(growable: false);
  }

  /// Hard-delete tombstones older than `age` relative to
  /// `at`. Returns the count of rows removed. v1.4m
  /// (SYS-127) — the `RecentlyDeletedPurgeService` (planned
  /// v1.4n+) calls this on a periodic background task with
  /// `age = Duration(days: 30)` to bound the tombstone
  /// table.
  ///
  /// Completion-log and rest-day-budget rows for a purged
  /// do are NOT touched (no FK declared). The orphaned rows
  /// are inert — no UI surface queries by `habitId` against
  /// a hard-deleted habit — but they remain in the DB until
  /// a future migration cycle explicitly cleans them. The
  /// 30-day TTL is deliberately chosen so a "force-purge"
  /// never surprises a user mid-restore; the inline Undo
  /// SnackBar in v1.4l is a 4-second window, but the user
  /// might come back days later via the (planned)
  /// "Recently deleted" surface.
  Future<int> purgeDeletedOlderThan(
    Duration age, {
    required DateTime at,
  }) async {
    await _ready;
    final cutoffMillis = at.subtract(age).millisecondsSinceEpoch;
    final affected =
        await (_db.delete(_db.habits)..where(
              (t) =>
                  t.deletedAtMillis.isNotNull() &
                  t.deletedAtMillis.isSmallerThanValue(cutoffMillis),
            ))
            .go();
    return affected;
  }

  // --- mapping ----------------------------------------------------

  HabitRow _toRow(domain.Do d) {
    // v1.4l / SYS-126 / ADR-056 §"save doesn't touch
    // tombstones": the `deletedAtMillis` column is INTENTIONALLY
    // omitted from the returned `HabitRow`. Drift's
    // `insertOnConflictUpdate` semantics preserve the existing
    // column value when the new row doesn't specify it, so a
    // Save click on a tombstoned do leaves the tombstone
    // intact. Restoration goes through [restoreById]. If a
    // future change adds `deletedAtMillis: d.deletedAt?.…`
    // here, the invariant breaks — pin in
    // `test/services/do_repository_test.dart`.
    //
    // Cycle B / SYS-129 / ADR-060 §"BUG-002 fix": the
    // `pausedUntilMillis` column is INTENTIONALLY omitted for
    // the same reason. The AddHabitScreen Save path
    // reconstructs the `Do` from form fields (which have no
    // pause picker), so writing `pausedUntilMillis: null` on
    // every Save would silently resume a paused habit. The
    // omission preserves the existing column value across
    // Save clicks. Pause and resume go through
    // [PauseService.pauseHabit] / [PauseService.resumeHabit],
    // which use direct `HabitsCompanion` UPDATEs to set /
    // clear the column explicitly (see `pause_service.dart`).
    // If a future change adds `pausedUntilMillis:
    // d.pausedUntil?.…` here, BUG-002 resurfaces — pin in
    // `test/services/do_repository_test.dart` (Cycle B group).
    //
    // Cycle B / SYS-129 / ADR-060 §"BUG-001 fix": the
    // `automationsJson` column IS written here (the inverse
    // of the omission pattern above). Automations are part of
    // the do's content — every Save should overwrite them
    // with the user's latest edits. The empty-list case maps
    // to SQL NULL (matches the [EventRepository] /
    // [PersonRepository] convention). The read path
    // [_fromRow] decodes the column back into
    // `d.automations` for every `Do` subclass.
    return HabitRow(
      id: d.id,
      name: d.name.trim(),
      proofMode: proofModeTag(d.proofMode),
      createdAtMillis: d.createdAt.millisecondsSinceEpoch,
      restDaysPerMonth: d.restDaysPerMonth,
      scheduleType: _scheduleTypeTag(d),
      weekdays: _weekdaysCsv(d),
      hour: _startHour(d),
      minute: _startMinute(d),
      nDays: _intervalNDays(d),
      referenceDateMillis: _intervalReference(d),
      targetHabitId: _anchorTarget(d),
      lastAnchorMillis: _anchorLastAnchor(d),
      dayOfMonth: _dayOfXDayOfMonth(d),
      nth: _dayOfXNth(d),
      weekday: _dayOfXWeekday(d),
      referenceDayOfMonth: _dayOfXReferenceDom(d),
      endHour: _endHour(d),
      endMinute: _endMinute(d),
      targetHours: _targetHours(d),
      missionChainJson: _missionChainJson(d.missionChain),
      category: d.category.tag,
      colorSeed: d.colorSeed,
      iconName: d.iconName,
      automationsJson: d.automations.isEmpty
          ? null
          : encodeAutomationList(d.automations),
    );
  }

  domain.Do _fromRow(HabitRow r) {
    final proofMode = _parseProofMode(r.proofMode, r.missionChainJson);
    // v1.4l / SYS-126: read the tombstone column once and
    // thread it through every subclass constructor. NULL =
    // active; non-null = tombstoned at this epoch millisecond.
    final deletedAt = r.deletedAtMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r.deletedAtMillis!);
    // Cycle B / SYS-129 / ADR-060 §"BUG-001 fix": decode the
    // `automationsJson` column once and thread the resulting
    // list through every subclass constructor. NULL/empty
    // JSON maps to `const <Automation>[]` (the default
    // "no non-default automations" state — the
    // `ActionNotify` is synthesized at dispatch time, not
    // stored).
    final automations = decodeAutomationList(r.automationsJson);
    final base = (
      id: r.id,
      name: r.name,
      proofMode: proofMode,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAtMillis),
      restDaysPerMonth: r.restDaysPerMonth,
      category: DoCategory.fromTag(r.category),
      colorSeed: r.colorSeed,
      iconName: r.iconName,
      pausedUntil: r.pausedUntilMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r.pausedUntilMillis!),
      automations: automations,
    );
    switch (r.scheduleType) {
      case 'fixed':
        return domain.DoFixed(
          id: base.id,
          name: base.name,
          proofMode: base.proofMode,
          createdAt: base.createdAt,
          restDaysPerMonth: base.restDaysPerMonth,
          weekdays: _parseWeekdays(r.weekdays),
          time: domain.DoTime(r.hour ?? 9, r.minute ?? 0),
          category: base.category,
          colorSeed: base.colorSeed,
          iconName: base.iconName,
          pausedUntil: base.pausedUntil,
          automations: base.automations,
          deletedAt: deletedAt,
        );
      case 'interval':
        return domain.DoInterval(
          id: base.id,
          name: base.name,
          proofMode: base.proofMode,
          createdAt: base.createdAt,
          restDaysPerMonth: base.restDaysPerMonth,
          nDays: r.nDays ?? 1,
          referenceDate: DateTime.fromMillisecondsSinceEpoch(
            r.referenceDateMillis ?? base.createdAt.millisecondsSinceEpoch,
          ),
          category: base.category,
          colorSeed: base.colorSeed,
          iconName: base.iconName,
          pausedUntil: base.pausedUntil,
          automations: base.automations,
          deletedAt: deletedAt,
        );
      case 'anchor':
        return domain.DoAnchor(
          id: base.id,
          name: base.name,
          proofMode: base.proofMode,
          createdAt: base.createdAt,
          restDaysPerMonth: base.restDaysPerMonth,
          targetDoId: r.targetHabitId ?? '',
          lastAnchor: r.lastAnchorMillis == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(r.lastAnchorMillis!),
          category: base.category,
          colorSeed: base.colorSeed,
          iconName: base.iconName,
          pausedUntil: base.pausedUntil,
          automations: base.automations,
          deletedAt: deletedAt,
        );
      case 'dayOfX':
        return domain.DoDayOfX(
          id: base.id,
          name: base.name,
          proofMode: base.proofMode,
          createdAt: base.createdAt,
          restDaysPerMonth: base.restDaysPerMonth,
          dayOfMonth: r.dayOfMonth,
          nth: r.nth,
          weekday: r.weekday,
          referenceDayOfMonth: r.referenceDayOfMonth,
          category: base.category,
          colorSeed: base.colorSeed,
          iconName: base.iconName,
          pausedUntil: base.pausedUntil,
          automations: base.automations,
          deletedAt: deletedAt,
        );
      case 'timeWindow':
        return domain.DoTimeWindow(
          id: base.id,
          name: base.name,
          proofMode: base.proofMode,
          createdAt: base.createdAt,
          restDaysPerMonth: base.restDaysPerMonth,
          weekdays: _parseWeekdays(r.weekdays),
          start: domain.DoTime(r.hour ?? 12, r.minute ?? 0),
          end: domain.DoTime(r.endHour ?? 13, r.endMinute ?? 0),
          targetHours: r.targetHours,
          category: base.category,
          colorSeed: base.colorSeed,
          iconName: base.iconName,
          pausedUntil: base.pausedUntil,
          automations: base.automations,
          deletedAt: deletedAt,
        );
      default:
        throw StateError('Unknown scheduleType: ${r.scheduleType}');
    }
  }

  DoProofMode _parseProofMode(String tag, String? chainJson) {
    switch (tag) {
      case 'soft':
        return const SoftProof();
      case 'strong':
        return StrongProof(_parseMissionChain(chainJson));
      case 'auto':
        return const AutoProof();
      default:
        throw ArgumentError('Unknown proof mode tag: $tag');
    }
  }

  String _scheduleTypeTag(domain.Do d) {
    if (d is domain.DoFixed) return 'fixed';
    if (d is domain.DoInterval) return 'interval';
    if (d is domain.DoAnchor) return 'anchor';
    if (d is domain.DoDayOfX) return 'dayOfX';
    if (d is domain.DoTimeWindow) return 'timeWindow';
    throw ArgumentError('Unknown do type: $d');
  }

  // Unified weekday/hour/minute column writers. Fixed and
  // TimeWindow share the same set of columns (Habits.weekdays /
  // hour / minute) so the per-type writer is just an `is` check.
  String? _weekdaysCsv(domain.Do d) {
    if (d is domain.DoFixed) return (d.weekdays.toList()..sort()).join(',');
    if (d is domain.DoTimeWindow) {
      return (d.weekdays.toList()..sort()).join(',');
    }
    return null;
  }

  int? _startHour(domain.Do d) {
    if (d is domain.DoFixed) return d.time.hour;
    if (d is domain.DoTimeWindow) return d.start.hour;
    return null;
  }

  int? _startMinute(domain.Do d) {
    if (d is domain.DoFixed) return d.time.minute;
    if (d is domain.DoTimeWindow) return d.start.minute;
    return null;
  }

  int? _endHour(domain.Do d) => d is domain.DoTimeWindow ? d.end.hour : null;

  int? _endMinute(domain.Do d) =>
      d is domain.DoTimeWindow ? d.end.minute : null;

  int? _targetHours(domain.Do d) =>
      d is domain.DoTimeWindow ? d.targetHours : null;

  int? _intervalNDays(domain.Do d) => d is domain.DoInterval ? d.nDays : null;

  int? _intervalReference(domain.Do d) =>
      d is domain.DoInterval ? d.referenceDate.millisecondsSinceEpoch : null;

  String? _anchorTarget(domain.Do d) =>
      d is domain.DoAnchor ? d.targetDoId : null;

  int? _anchorLastAnchor(domain.Do d) =>
      d is domain.DoAnchor ? d.lastAnchor?.millisecondsSinceEpoch : null;

  int? _dayOfXDayOfMonth(domain.Do d) =>
      d is domain.DoDayOfX ? d.dayOfMonth : null;
  int? _dayOfXNth(domain.Do d) => d is domain.DoDayOfX ? d.nth : null;
  int? _dayOfXWeekday(domain.Do d) => d is domain.DoDayOfX ? d.weekday : null;
  int? _dayOfXReferenceDom(domain.Do d) =>
      d is domain.DoDayOfX ? d.referenceDayOfMonth : null;

  Set<int> _parseWeekdays(String? csv) {
    if (csv == null || csv.isEmpty) return <int>{};
    return csv.split(',').map(int.parse).toSet();
  }

  String? _missionChainJson(MissionChain chain) {
    if (chain.isEmpty) return null;
    final list = chain.map(_missionToJson).toList(growable: false);
    return jsonEncode(list);
  }

  MissionChain _parseMissionChain(String? json) {
    if (json == null || json.isEmpty) return MissionChain.empty;
    final list = (jsonDecode(json) as List).cast<Map<String, Object?>>();
    return MissionChain.from(
      list.map(_missionFromJson).toList(growable: false),
    );
  }

  Map<String, Object?> _missionToJson(Mission m) {
    return switch (m) {
      ShakeMission(
        :final id,
        :final label,
        :final timeout,
        :final targetCount,
      ) =>
        {
          'type': 'shake',
          'id': id,
          'label': label,
          'timeoutMs': timeout.inMilliseconds,
          'targetCount': targetCount,
        },
      TypeMission(
        :final id,
        :final label,
        :final timeout,
        :final expectedPhrase,
      ) =>
        {
          'type': 'type',
          'id': id,
          'label': label,
          'timeoutMs': timeout.inMilliseconds,
          'phrase': expectedPhrase,
        },
      HoldMission(
        :final id,
        :final label,
        :final timeout,
        :final holdDuration,
      ) =>
        {
          'type': 'hold',
          'id': id,
          'label': label,
          'timeoutMs': timeout.inMilliseconds,
          'holdDurationMs': holdDuration.inMilliseconds,
        },
      MathMission(:final id, :final label, :final timeout, :final difficulty) =>
        {
          'type': 'math',
          'id': id,
          'label': label,
          'timeoutMs': timeout.inMilliseconds,
          'difficulty': difficulty.name,
        },
      MemoryMission(
        :final id,
        :final label,
        :final timeout,
        :final rows,
        :final cols,
        :final theme,
      ) =>
        {
          'type': 'memory',
          'id': id,
          'label': label,
          'timeoutMs': timeout.inMilliseconds,
          'rows': rows,
          'cols': cols,
          'theme': theme,
        },
    };
  }

  Mission _missionFromJson(Map<String, Object?> j) {
    final type = j['type'] as String;
    final id = j['id'] as String;
    final label = j['label'] as String;
    final timeout = Duration(milliseconds: (j['timeoutMs'] as num).toInt());
    switch (type) {
      case 'shake':
        return ShakeMission(
          id: id,
          label: label,
          timeout: timeout,
          targetCount: (j['targetCount'] as num).toInt(),
        );
      case 'type':
        return TypeMission(
          id: id,
          label: label,
          timeout: timeout,
          expectedPhrase: j['phrase'] as String,
        );
      case 'hold':
        return HoldMission(
          id: id,
          label: label,
          timeout: timeout,
          holdDuration: Duration(
            milliseconds: (j['holdDurationMs'] as num).toInt(),
          ),
        );
      case 'math':
        return MathMission(
          id: id,
          label: label,
          timeout: timeout,
          difficulty: MathDifficulty.values.byName(j['difficulty'] as String),
        );
      case 'memory':
        return MemoryMission(
          id: id,
          label: label,
          timeout: timeout,
          rows: (j['rows'] as num).toInt(),
          cols: (j['cols'] as num).toInt(),
          theme: j['theme'] as String,
        );
      default:
        throw ArgumentError('Unknown mission type: $type');
    }
  }
}

/// Thrown by [DoRepository.save] when the trimmed, lower-cased
/// name matches an existing do.
class DuplicateDoName implements Exception {
  DuplicateDoName(this.name);
  final String name;
  @override
  String toString() => 'DuplicateDoName: $name';
}
