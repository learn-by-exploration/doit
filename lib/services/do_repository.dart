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
  Future<domain.Do?> getById(String id) async {
    await _ready;
    final row = await (_db.select(
      _db.habits,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// List all dos, oldest-first. Order is the natural
  /// `createdAtMillis` ascending so the home screen renders in
  /// creation order.
  Future<List<domain.Do>> listAll() async {
    await _ready;
    final rows = await (_db.select(
      _db.habits,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAtMillis)])).get();
    return rows.map(_fromRow).toList(growable: false);
  }

  /// List dos that are NOT currently paused (pausedUntil is
  /// null OR in the past). v0.2 (SYS-047). The scheduler uses
  /// this to skip paused dos when computing the "next
  /// occurrence" across all active dos.
  Future<List<domain.Do>> listActive(DateTime now) async {
    await _ready;
    final rows = await (_db.select(
      _db.habits,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAtMillis)])).get();
    return rows
        .map(_fromRow)
        .where((d) => !d.isPausedAt(now))
        .toList(growable: false);
  }

  /// Delete a do by id. The completion log and skip-day budget
  /// rows are cascade-deleted via the foreign-key pragma in
  /// `schema.dart` (the model itself doesn't enforce this; the
  /// service layer does).
  Future<void> deleteById(String id) async {
    await _ready;
    await (_db.delete(_db.habits)..where((t) => t.id.equals(id))).go();
  }

  // --- mapping ----------------------------------------------------

  HabitRow _toRow(domain.Do d) {
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
      pausedUntilMillis: d.pausedUntil?.millisecondsSinceEpoch,
    );
  }

  domain.Do _fromRow(HabitRow r) {
    final proofMode = _parseProofMode(r.proofMode, r.missionChainJson);
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
