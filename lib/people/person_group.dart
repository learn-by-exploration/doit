// PersonGroup model — a named group of [Person]s with a
// cadence, a shared channel/handle, and a "semantic" that
// controls how the group is satisfied (rotation, any, or all).
//
// WF-018. The group is a cadence-style habit: "Call a friend
// every week" → group of 5 friends, semantic = 'rotation',
// cadence = weekly.
//
// A group member is a (personId, addedAtMillis,
// lastContactedMillis) triple. The rotation selector uses
// `lastContactedMillis` to pick the least-recently-contacted
// member; the 'all' semantic counts the group as complete only
// when every member has been contacted in the current period.
//
// Layer rules (per .claude/rules/lib-people.md):
//   - No Flutter imports.
//   - Immutable; mutations go through [PersonGroup.copyWith].

import 'package:common_games/people/cadence.dart';
import 'package:meta/meta.dart';

/// Stable, opaque group identifier. Same shape as [PersonId].
typedef PersonGroupId = String;

/// How a group is satisfied.
///
/// - [rotation]: pick the least-recently-contacted member.
///   The group is "done" when that one member is contacted.
/// - [any]: any member counts; the group is "done" as soon as
///   one is contacted.
/// - [all]: every member must be contacted in the period. v0.2
///   is rotation-only in practice, but the enum is sealed for
///   v0.3.
enum GroupSemantic { rotation, any, all }

@immutable
sealed class PersonGroup {
  const PersonGroup({
    required this.id,
    required this.name,
    required this.cadence,
    required this.semantic,
    required this.channel,
    required this.handle,
    required this.createdAt,
    this.missionChainJson,
    this.pausedUntil,
  });

  final PersonGroupId id;
  final String name;
  final PersonCadence cadence;
  final GroupSemantic semantic;
  final String channel; // 'dialer' | 'whatsapp' | 'telegram' | 'signal' | 'sms'
  final String handle; // shared handle (e.g., a group chat URI)
  final DateTime createdAt;
  final String? missionChainJson;
  final DateTime? pausedUntil;

  /// `true` when the group is currently paused.
  bool isPausedAt(DateTime now) =>
      pausedUntil != null && pausedUntil!.isAfter(now);

  PersonGroup copyWith({
    String? name,
    PersonCadence? cadence,
    GroupSemantic? semantic,
    String? channel,
    String? handle,
    String? missionChainJson,
    DateTime? pausedUntil,
    bool clearPausedUntil = false,
  });

  void validate() {
    if (name.trim().isEmpty) {
      throw const PersonGroupNameEmpty();
    }
    if (channel.trim().isEmpty) {
      throw const PersonGroupChannelEmpty();
    }
    if (handle.trim().isEmpty) {
      throw const PersonGroupHandleEmpty();
    }
  }
}

/// A group of people, each with a lastContactedMillis used by
/// the rotation selector.
@immutable
final class GroupMember {
  const GroupMember({
    required this.personId,
    required this.addedAtMillis,
    this.lastContactedMillis,
  });

  final String personId;
  final int addedAtMillis;
  final int? lastContactedMillis;

  GroupMember copyWith({
    int? lastContactedMillis,
    bool clearLastContacted = false,
  }) {
    return GroupMember(
      personId: personId,
      addedAtMillis: addedAtMillis,
      lastContactedMillis: clearLastContacted
          ? null
          : (lastContactedMillis ?? this.lastContactedMillis),
    );
  }
}

@immutable
final class ContactGroup extends PersonGroup {
  const ContactGroup({
    required super.id,
    required super.name,
    required super.cadence,
    required super.semantic,
    required super.channel,
    required super.handle,
    required super.createdAt,
    super.missionChainJson,
    super.pausedUntil,
  });

  @override
  ContactGroup copyWith({
    String? name,
    PersonCadence? cadence,
    GroupSemantic? semantic,
    String? channel,
    String? handle,
    String? missionChainJson,
    DateTime? pausedUntil,
    bool clearPausedUntil = false,
  }) {
    return ContactGroup(
      id: id,
      name: name ?? this.name,
      cadence: cadence ?? this.cadence,
      semantic: semantic ?? this.semantic,
      channel: channel ?? this.channel,
      handle: handle ?? this.handle,
      createdAt: createdAt,
      missionChainJson: missionChainJson ?? this.missionChainJson,
      pausedUntil: clearPausedUntil ? null : (pausedUntil ?? this.pausedUntil),
    );
  }

  @override
  bool operator ==(Object other) => other is ContactGroup && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Rotation selector — pure function that picks the
/// least-recently-contacted member from a group. Returns `null`
/// if the group is empty.
///
/// Ties are broken by `addedAtMillis` (the oldest member wins).
String? pickNextMember(List<GroupMember> members) {
  if (members.isEmpty) return null;
  GroupMember? best;
  for (final m in members) {
    if (best == null) {
      best = m;
      continue;
    }
    final bestLast = best.lastContactedMillis;
    final mLast = m.lastContactedMillis;
    if (mLast == null && bestLast != null) {
      best = m; // never-contacted beats contacted
    } else if (mLast != null && bestLast != null) {
      if (mLast < bestLast) best = m;
    } else if (mLast == null && bestLast == null) {
      if (m.addedAtMillis < best.addedAtMillis) best = m;
    }
  }
  return best!.personId;
}

/// Mark a member as contacted at [at]. Returns a new list with
/// the member's `lastContactedMillis` updated.
List<GroupMember> markContacted(
  List<GroupMember> members,
  String personId,
  DateTime at,
) {
  return [
    for (final m in members)
      if (m.personId == personId)
        m.copyWith(lastContactedMillis: at.millisecondsSinceEpoch)
      else
        m,
  ];
}

sealed class PersonGroupValidationException implements Exception {
  const PersonGroupValidationException();
}

final class PersonGroupNameEmpty extends PersonGroupValidationException {
  const PersonGroupNameEmpty();
}

final class PersonGroupChannelEmpty extends PersonGroupValidationException {
  const PersonGroupChannelEmpty();
}

final class PersonGroupHandleEmpty extends PersonGroupValidationException {
  const PersonGroupHandleEmpty();
}
