// PersonGroupRepository — CRUD for cadence-style contact groups
// (WF-018).
//
// A group is a habit-shaped bundle: name, cadence, channel, and
// a set of members. The repository owns the persistence of the
// group header (`PersonGroups` table) and the membership table
// (`PersonGroupMembers`).
//
// Rotation is computed at read time via [pickNextMember] from
// the model — the repository only persists the
// `lastContactedMillis` per member. Marking a member as
// contacted writes a new `addedAtMillis`-preserving row.

import 'package:doit/people/cadence.dart';
import 'package:doit/people/person_group.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:drift/drift.dart';

class PersonGroupRepository {
  PersonGroupRepository._();

  static final PersonGroupRepository instance = PersonGroupRepository._();

  Future<void> get _ready => AppDatabaseService.instance.ready;
  AppDatabase get _db => AppDatabaseService.instance.db;

  /// Persist a group header. Validation is delegated to the model.
  Future<void> save(PersonGroup group) async {
    await _ready;
    group.validate();
    await _db
        .into(_db.personGroups)
        .insertOnConflictUpdate(
          PersonGroupsCompanion.insert(
            id: group.id,
            name: group.name,
            cadenceType: _cadenceToString(group.cadence),
            semantic: group.semantic.name,
            channel: group.channel,
            handle: group.handle,
            missionChainJson: Value(group.missionChainJson),
            createdAtMillis: group.createdAt.millisecondsSinceEpoch,
            pausedUntilMillis: Value(group.pausedUntil?.millisecondsSinceEpoch),
          ),
        );
  }

  /// Fetch a single group header by id (members are NOT loaded —
  /// call [listMembers] for that).
  Future<PersonGroup?> getById(String id) async {
    await _ready;
    final row = await (_db.select(
      _db.personGroups,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// List all group headers, ordered by createdAt desc.
  Future<List<PersonGroup>> listAll() async {
    await _ready;
    final rows = await (_db.select(
      _db.personGroups,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAtMillis)])).get();
    return rows.map(_fromRow).toList(growable: false);
  }

  /// Hard-delete a group and all of its memberships.
  Future<void> deleteById(String id) async {
    await _ready;
    await _db.transaction(() async {
      await (_db.delete(
        _db.personGroupMembers,
      )..where((t) => t.groupId.equals(id))).go();
      await (_db.delete(_db.personGroups)..where((t) => t.id.equals(id))).go();
    });
  }

  // ---------------- members ----------------

  /// Add [personId] to [groupId]. If the member already exists,
  /// the row is left as-is (the rotation selector preserves
  /// their `lastContactedMillis`).
  Future<void> addMember(String groupId, String personId) async {
    await _ready;
    final existing =
        await (_db.select(_db.personGroupMembers)..where(
              (t) => t.groupId.equals(groupId) & t.personId.equals(personId),
            ))
            .getSingleOrNull();
    if (existing != null) return;
    await _db
        .into(_db.personGroupMembers)
        .insert(
          PersonGroupMembersCompanion.insert(
            groupId: groupId,
            personId: personId,
            addedAtMillis: DateTime.now().millisecondsSinceEpoch,
            lastContactedMillis: const Value(null),
          ),
        );
  }

  /// Remove [personId] from [groupId]. No-op if the membership
  /// does not exist.
  Future<void> removeMember(String groupId, String personId) async {
    await _ready;
    await (_db.delete(_db.personGroupMembers)..where(
          (t) => t.groupId.equals(groupId) & t.personId.equals(personId),
        ))
        .go();
  }

  /// List the members of a group, ordered by addedAtMillis asc.
  Future<List<GroupMember>> listMembers(String groupId) async {
    await _ready;
    final rows =
        await (_db.select(_db.personGroupMembers)
              ..where((t) => t.groupId.equals(groupId))
              ..orderBy([(t) => OrderingTerm.asc(t.addedAtMillis)]))
            .get();
    return rows
        .map(
          (r) => GroupMember(
            personId: r.personId,
            addedAtMillis: r.addedAtMillis,
            lastContactedMillis: r.lastContactedMillis,
          ),
        )
        .toList(growable: false);
  }

  /// Mark a member as contacted at [at]. The
  /// `lastContactedMillis` is updated in place; `addedAtMillis`
  /// is preserved (the rotation tie-breaker is the older
  /// `addedAtMillis`).
  Future<void> markContacted(
    String groupId,
    String personId,
    DateTime at,
  ) async {
    await _ready;
    await (_db.update(_db.personGroupMembers)..where(
          (t) => t.groupId.equals(groupId) & t.personId.equals(personId),
        ))
        .write(
          PersonGroupMembersCompanion(
            lastContactedMillis: Value(at.millisecondsSinceEpoch),
          ),
        );
  }

  // ---------------- mapping ----------------

  PersonGroup _fromRow(PersonGroupRow r) {
    return ContactGroup(
      id: r.id,
      name: r.name,
      cadence: _cadenceFromString(r.cadenceType, r.id),
      semantic: _semanticFromString(r.semantic),
      channel: r.channel,
      handle: r.handle,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAtMillis),
      missionChainJson: r.missionChainJson,
      pausedUntil: r.pausedUntilMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r.pausedUntilMillis!),
    );
  }

  // The cadence persisted in the row is a string token. The
  // payload parameters (n, day-of-week, day-of-month, etc.) are
  // not yet stored in v0.2 (we default to EveryNDays(7) for
  // 'weekly_on' tokens etc.). v0.3 will add a payload column.
  String _cadenceToString(PersonCadence c) {
    return switch (c) {
      EveryNDays() => 'every_n_days',
      WeeklyOn() => 'weekly_on',
      MonthlyOn() => 'monthly_on',
      YearlyOn() => 'yearly_on',
    };
  }

  PersonCadence _cadenceFromString(String s, String groupId) {
    switch (s) {
      case 'every_n_days':
        return const EveryNDays(7);
      case 'weekly_on':
        return const WeeklyOn(DateTime.monday);
      case 'monthly_on':
        return const MonthlyOn(1);
      case 'yearly_on':
        return const YearlyOn(1, 1);
      default:
        return const EveryNDays(7);
    }
  }

  GroupSemantic _semanticFromString(String s) {
    return switch (s) {
      'any' => GroupSemantic.any,
      'all' => GroupSemantic.all,
      _ => GroupSemantic.rotation,
    };
  }
}
