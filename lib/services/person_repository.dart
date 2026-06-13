// CRUD + queries for people (cadence-style habits). Mirror of
// `habit_repository.dart`. Maps Drift rows ↔ the domain
// `Person` / `PersonCadence` models.

import 'dart:async';
import 'dart:convert';

import 'package:common_games/missions/chain.dart';
import 'package:common_games/missions/mission.dart';
import 'package:common_games/people/cadence.dart' as domain;
import 'package:common_games/people/person.dart' as domain;
import 'package:drift/drift.dart';

import 'package:common_games/services/db.dart';
import 'package:common_games/services/db/schema.dart';

class PersonRepository {
  PersonRepository._();

  static final PersonRepository instance = PersonRepository._();

  Future<void> get _ready => AppDatabaseService.instance.ready;
  AppDatabase get _db => AppDatabaseService.instance.db;

  Future<void> save(domain.Person person) async {
    await _ready;
    await _db.into(_db.people).insertOnConflictUpdate(_toRow(person));
  }

  Future<domain.Person?> getById(String id) async {
    await _ready;
    final row = await (_db.select(
      _db.people,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<List<domain.Person>> listAll() async {
    await _ready;
    final rows = await (_db.select(
      _db.people,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAtMillis)])).get();
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<void> deleteById(String id) async {
    await _ready;
    await (_db.delete(_db.people)..where((t) => t.id.equals(id))).go();
  }

  // --- mapping ----------------------------------------------------

  PersonRow _toRow(domain.Person p) {
    final (tag, handle) = _channelTagAndHandle(p.channel);
    return PersonRow(
      id: p.id,
      lookupKey: p.lookupKey,
      displayName: '',
      channel: tag,
      handle: handle,
      createdAtMillis: p.createdAt.millisecondsSinceEpoch,
      cadenceType: _cadenceTypeTag(p.cadence),
      nDays: _everyNDaysN(p.cadence),
      weekday: _weeklyOnWeekday(p.cadence),
      dayOfMonth: _monthlyDay(p.cadence) ?? _yearlyDay(p.cadence),
      monthOfYear: _yearlyMonth(p.cadence),
      anchoredToWakeup: false,
    );
  }

  domain.Person _fromRow(PersonRow r) {
    return domain.ContactPerson(
      id: r.id,
      lookupKey: r.lookupKey,
      channel: _parseChannel(r.channel, r.handle),
      cadence: _parseCadence(r),
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAtMillis),
    );
  }

  (String, String) _channelTagAndHandle(domain.PersonChannel c) {
    return switch (c) {
      domain.ChannelDialer(:final phoneNumber) => ('dialer', phoneNumber),
      domain.ChannelWhatsApp(:final phoneNumber) => ('whatsapp', phoneNumber),
      domain.ChannelTelegram(:final username) => ('telegram', username),
      domain.ChannelSignal(:final phoneNumber) => ('signal', phoneNumber),
      domain.ChannelSms(:final phoneNumber) => ('sms', phoneNumber),
    };
  }

  domain.PersonChannel _parseChannel(String tag, String handle) {
    return switch (tag) {
      'dialer' => domain.ChannelDialer(handle),
      'whatsapp' => domain.ChannelWhatsApp(handle),
      'telegram' => domain.ChannelTelegram(handle),
      'signal' => domain.ChannelSignal(handle),
      'sms' => domain.ChannelSms(handle),
      _ => throw ArgumentError('Unknown channel: $tag'),
    };
  }

  String _cadenceTypeTag(domain.PersonCadence c) {
    return switch (c) {
      domain.EveryNDays() => 'every_n_days',
      domain.WeeklyOn() => 'weekly_on',
      domain.MonthlyOn() => 'monthly_on',
      domain.YearlyOn() => 'yearly_on',
    };
  }

  int? _everyNDaysN(domain.PersonCadence c) =>
      c is domain.EveryNDays ? c.nDays : null;
  int? _weeklyOnWeekday(domain.PersonCadence c) =>
      c is domain.WeeklyOn ? c.weekday : null;
  int? _monthlyDay(domain.PersonCadence c) =>
      c is domain.MonthlyOn ? c.dayOfMonth : null;
  int? _yearlyDay(domain.PersonCadence c) =>
      c is domain.YearlyOn ? c.day : null;
  int? _yearlyMonth(domain.PersonCadence c) =>
      c is domain.YearlyOn ? c.month : null;

  domain.PersonCadence _parseCadence(PersonRow r) {
    switch (r.cadenceType) {
      case 'every_n_days':
        return domain.EveryNDays(r.nDays ?? 1);
      case 'weekly_on':
        return domain.WeeklyOn(r.weekday ?? 1);
      case 'monthly_on':
        return domain.MonthlyOn(r.dayOfMonth ?? 1);
      case 'yearly_on':
        return domain.YearlyOn(r.monthOfYear ?? 1, r.dayOfMonth ?? 1);
      default:
        throw ArgumentError('Unknown cadence: ${r.cadenceType}');
    }
  }

  // Mission chain and anchoredToWakeup are persisted on the
  // People table for forward-compatibility, but the v0.1 model
  // does not yet use them. The repository keeps the columns
  // nullable; the JSON helpers below are kept so a future
  // v0.2 person schema can wire them in without re-deriving the
  // JSON envelope.
  // ignore: unused_element
  String? _missionChainJson(MissionChain chain) {
    if (chain.isEmpty) return null;
    final list = chain.map(_missionToJson).toList(growable: false);
    return jsonEncode(list);
  }

  // ignore: unused_element
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
