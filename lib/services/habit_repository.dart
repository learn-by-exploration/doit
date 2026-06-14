// CRUD + queries for habits. Pure SQL/Dart — no UI imports.
//
// The repository maps the Drift row (the persistence model) to
// and from the domain `Habit` model in `lib/habits/habit.dart`.
// The mapping lives here so the model layer stays free of
// Drift annotations. Strong-habit mission chains are stored as
// JSON in `Habits.missionChainJson`; the repository serializes /
// deserializes via the `Mission` / `MissionChain` types in
// `lib/missions/`.
//
// v0.2 (SYS-042..SYS-047): the repository now maps the
// `category`, `colorSeed`, `iconName`, and `pausedUntilMillis`
// columns, and the new `HabitTimeWindow` schedule type.

import 'dart:async';
import 'dart:convert';

import 'package:common_games/habits/category.dart';
import 'package:common_games/habits/habit.dart' as domain;
import 'package:common_games/habits/proof_mode.dart';
import 'package:common_games/missions/chain.dart';
import 'package:common_games/missions/mission.dart';
import 'package:drift/drift.dart';

import 'package:common_games/services/db.dart';
import 'package:common_games/services/db/schema.dart';

class HabitRepository {
  HabitRepository._();

  static final HabitRepository instance = HabitRepository._();

  Future<void> get _ready => AppDatabaseService.instance.ready;
  AppDatabase get _db => AppDatabaseService.instance.db;

  /// Persist a habit. Throws [DuplicateHabitName] if a habit with
  /// the same trimmed, lower-cased name already exists. The
  /// repository delegates input validation to the model
  /// (`habit.validate()`), which throws
  /// [HabitValidationException] subclasses on bad input.
  Future<void> save(domain.Habit habit) async {
    await _ready;
    habit.validate();
    final existing =
        await (_db.select(_db.habits)
              ..where(
                (t) => t.name.lower().equals(habit.name.trim().toLowerCase()),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null && existing.id != habit.id) {
      throw DuplicateHabitName(habit.name);
    }
    await _db.into(_db.habits).insertOnConflictUpdate(_toRow(habit));
  }

  /// Fetch a habit by id. Returns `null` if not present.
  Future<domain.Habit?> getById(String id) async {
    await _ready;
    final row = await (_db.select(
      _db.habits,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// List all habits, oldest-first. Order is the natural
  /// `createdAtMillis` ascending so the home screen renders in
  /// creation order.
  Future<List<domain.Habit>> listAll() async {
    await _ready;
    final rows = await (_db.select(
      _db.habits,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAtMillis)])).get();
    return rows.map(_fromRow).toList(growable: false);
  }

  /// List habits that are NOT currently paused (pausedUntil
  /// is null OR in the past). v0.2 (SYS-047). The scheduler
  /// uses this to skip paused habits when computing the
  /// "next occurrence" across all active habits.
  Future<List<domain.Habit>> listActive(DateTime now) async {
    await _ready;
    final rows = await (_db.select(
      _db.habits,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAtMillis)])).get();
    return rows
        .map(_fromRow)
        .where((h) => !h.isPausedAt(now))
        .toList(growable: false);
  }

  /// Delete a habit by id. The completion log and rest-day
  /// budget rows are cascade-deleted via the foreign-key pragma
  /// in `schema.dart` (the model itself doesn't enforce this;
  /// the service layer does).
  Future<void> deleteById(String id) async {
    await _ready;
    await (_db.delete(_db.habits)..where((t) => t.id.equals(id))).go();
  }

  // --- mapping ----------------------------------------------------

  HabitRow _toRow(domain.Habit h) {
    return HabitRow(
      id: h.id,
      name: h.name.trim(),
      proofMode: _proofModeTag(h.proofMode),
      createdAtMillis: h.createdAt.millisecondsSinceEpoch,
      restDaysPerMonth: h.restDaysPerMonth,
      scheduleType: _scheduleTypeTag(h),
      weekdays: _weekdaysCsv(h),
      hour: _startHour(h),
      minute: _startMinute(h),
      nDays: _intervalNDays(h),
      referenceDateMillis: _intervalReference(h),
      targetHabitId: _anchorTarget(h),
      lastAnchorMillis: _anchorLastAnchor(h),
      dayOfMonth: _dayOfXDayOfMonth(h),
      nth: _dayOfXNth(h),
      weekday: _dayOfXWeekday(h),
      referenceDayOfMonth: _dayOfXReferenceDom(h),
      endHour: _endHour(h),
      endMinute: _endMinute(h),
      targetHours: _targetHours(h),
      missionChainJson: _missionChainJson(h.missionChain),
      category: h.category.tag,
      colorSeed: h.colorSeed,
      iconName: h.iconName,
      pausedUntilMillis: h.pausedUntil?.millisecondsSinceEpoch,
    );
  }

  domain.Habit _fromRow(HabitRow r) {
    final proofMode = _parseProofMode(r.proofMode, r.missionChainJson);
    final base = (
      id: r.id,
      name: r.name,
      proofMode: proofMode,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAtMillis),
      restDaysPerMonth: r.restDaysPerMonth,
      category: HabitCategory.fromTag(r.category),
      colorSeed: r.colorSeed,
      iconName: r.iconName,
      pausedUntil: r.pausedUntilMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r.pausedUntilMillis!),
    );
    switch (r.scheduleType) {
      case 'fixed':
        return domain.HabitFixed(
          id: base.id,
          name: base.name,
          proofMode: base.proofMode,
          createdAt: base.createdAt,
          restDaysPerMonth: base.restDaysPerMonth,
          weekdays: _parseWeekdays(r.weekdays),
          time: domain.HabitTime(r.hour ?? 9, r.minute ?? 0),
          category: base.category,
          colorSeed: base.colorSeed,
          iconName: base.iconName,
          pausedUntil: base.pausedUntil,
        );
      case 'interval':
        return domain.HabitInterval(
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
        );
      case 'anchor':
        return domain.HabitAnchor(
          id: base.id,
          name: base.name,
          proofMode: base.proofMode,
          createdAt: base.createdAt,
          restDaysPerMonth: base.restDaysPerMonth,
          targetHabitId: r.targetHabitId ?? '',
          lastAnchor: r.lastAnchorMillis == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(r.lastAnchorMillis!),
          category: base.category,
          colorSeed: base.colorSeed,
          iconName: base.iconName,
          pausedUntil: base.pausedUntil,
        );
      case 'dayOfX':
        return domain.HabitDayOfX(
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
        );
      case 'timeWindow':
        return domain.HabitTimeWindow(
          id: base.id,
          name: base.name,
          proofMode: base.proofMode,
          createdAt: base.createdAt,
          restDaysPerMonth: base.restDaysPerMonth,
          weekdays: _parseWeekdays(r.weekdays),
          start: domain.HabitTime(r.hour ?? 12, r.minute ?? 0),
          end: domain.HabitTime(r.endHour ?? 13, r.endMinute ?? 0),
          targetHours: r.targetHours,
          category: base.category,
          colorSeed: base.colorSeed,
          iconName: base.iconName,
          pausedUntil: base.pausedUntil,
        );
      default:
        throw StateError('Unknown scheduleType: ${r.scheduleType}');
    }
  }

  String _proofModeTag(HabitProofMode m) {
    if (m is SoftProof) return 'soft';
    if (m is StrongProof) return 'strong';
    if (m is AutoProof) return 'auto';
    throw ArgumentError('Unknown proof mode: $m');
  }

  HabitProofMode _parseProofMode(String tag, String? chainJson) {
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

  String _scheduleTypeTag(domain.Habit h) {
    if (h is domain.HabitFixed) return 'fixed';
    if (h is domain.HabitInterval) return 'interval';
    if (h is domain.HabitAnchor) return 'anchor';
    if (h is domain.HabitDayOfX) return 'dayOfX';
    if (h is domain.HabitTimeWindow) return 'timeWindow';
    throw ArgumentError('Unknown habit type: $h');
  }

  // Unified weekday/hour/minute column writers. Fixed and
  // TimeWindow share the same set of columns (Habits.weekdays /
  // hour / minute) so the per-type writer is just an `is` check.
  String? _weekdaysCsv(domain.Habit h) {
    if (h is domain.HabitFixed) return (h.weekdays.toList()..sort()).join(',');
    if (h is domain.HabitTimeWindow) {
      return (h.weekdays.toList()..sort()).join(',');
    }
    return null;
  }

  int? _startHour(domain.Habit h) {
    if (h is domain.HabitFixed) return h.time.hour;
    if (h is domain.HabitTimeWindow) return h.start.hour;
    return null;
  }

  int? _startMinute(domain.Habit h) {
    if (h is domain.HabitFixed) return h.time.minute;
    if (h is domain.HabitTimeWindow) return h.start.minute;
    return null;
  }

  int? _endHour(domain.Habit h) =>
      h is domain.HabitTimeWindow ? h.end.hour : null;

  int? _endMinute(domain.Habit h) =>
      h is domain.HabitTimeWindow ? h.end.minute : null;

  int? _targetHours(domain.Habit h) =>
      h is domain.HabitTimeWindow ? h.targetHours : null;

  int? _intervalNDays(domain.Habit h) =>
      h is domain.HabitInterval ? h.nDays : null;

  int? _intervalReference(domain.Habit h) =>
      h is domain.HabitInterval ? h.referenceDate.millisecondsSinceEpoch : null;

  String? _anchorTarget(domain.Habit h) =>
      h is domain.HabitAnchor ? h.targetHabitId : null;

  int? _anchorLastAnchor(domain.Habit h) =>
      h is domain.HabitAnchor ? h.lastAnchor?.millisecondsSinceEpoch : null;

  int? _dayOfXDayOfMonth(domain.Habit h) =>
      h is domain.HabitDayOfX ? h.dayOfMonth : null;
  int? _dayOfXNth(domain.Habit h) => h is domain.HabitDayOfX ? h.nth : null;
  int? _dayOfXWeekday(domain.Habit h) =>
      h is domain.HabitDayOfX ? h.weekday : null;
  int? _dayOfXReferenceDom(domain.Habit h) =>
      h is domain.HabitDayOfX ? h.referenceDayOfMonth : null;

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

/// Thrown by [HabitRepository.save] when the trimmed, lower-cased
/// name matches an existing habit.
class DuplicateHabitName implements Exception {
  DuplicateHabitName(this.name);
  final String name;
  @override
  String toString() => 'DuplicateHabitName: $name';
}
