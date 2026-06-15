// Tests for PersonGroupRepository (WF-018).

import 'package:doit/people/cadence.dart';
import 'package:doit/people/person_group.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/person_group_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    await AppDatabaseService.instance.closeForTesting();
    db = AppDatabase(NativeDatabase.memory());
    await AppDatabaseService.instance.init(overrideDb: db);
    await AppDatabaseService.instance.ready;
  });

  tearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });

  ContactGroup _group({
    String id = 'g1',
    String name = 'Friends',
    PersonCadence? cadence,
    GroupSemantic semantic = GroupSemantic.rotation,
  }) {
    return ContactGroup(
      id: id,
      name: name,
      cadence: cadence ?? const EveryNDays(7),
      semantic: semantic,
      channel: 'whatsapp',
      handle: 'chat_uri',
      createdAt: DateTime(2026, 6, 1),
    );
  }

  test('save + getById round-trips', () async {
    await PersonGroupRepository.instance.save(_group());
    final got = await PersonGroupRepository.instance.getById('g1');
    expect(got, isNotNull);
    expect(got!.name, 'Friends');
    expect(got.semantic, GroupSemantic.rotation);
  });

  test('listAll returns groups, newest first', () async {
    await PersonGroupRepository.instance.save(
      ContactGroup(
        id: 'g1',
        name: 'First',
        cadence: const EveryNDays(7),
        semantic: GroupSemantic.rotation,
        channel: 'whatsapp',
        handle: 'chat_uri',
        createdAt: DateTime(2026, 6, 1),
      ),
    );
    await PersonGroupRepository.instance.save(
      ContactGroup(
        id: 'g2',
        name: 'Second',
        cadence: const EveryNDays(7),
        semantic: GroupSemantic.rotation,
        channel: 'whatsapp',
        handle: 'chat_uri',
        createdAt: DateTime(2026, 6, 2),
      ),
    );
    final groups = await PersonGroupRepository.instance.listAll();
    expect(groups.map((g) => g.id).toList(), ['g2', 'g1']);
  });

  test('deleteById removes the header and its members', () async {
    await PersonGroupRepository.instance.save(_group());
    await PersonGroupRepository.instance.addMember('g1', 'p1');
    await PersonGroupRepository.instance.addMember('g1', 'p2');
    await PersonGroupRepository.instance.deleteById('g1');
    final got = await PersonGroupRepository.instance.getById('g1');
    expect(got, isNull);
    final members = await PersonGroupRepository.instance.listMembers('g1');
    expect(members, isEmpty);
  });

  test('addMember is idempotent', () async {
    await PersonGroupRepository.instance.save(_group());
    await PersonGroupRepository.instance.addMember('g1', 'p1');
    await PersonGroupRepository.instance.addMember('g1', 'p1');
    final members = await PersonGroupRepository.instance.listMembers('g1');
    expect(members.length, 1);
  });

  test('removeMember drops the row', () async {
    await PersonGroupRepository.instance.save(_group());
    await PersonGroupRepository.instance.addMember('g1', 'p1');
    await PersonGroupRepository.instance.addMember('g1', 'p2');
    await PersonGroupRepository.instance.removeMember('g1', 'p1');
    final members = await PersonGroupRepository.instance.listMembers('g1');
    expect(members.length, 1);
    expect(members.first.personId, 'p2');
  });

  test('markContacted updates lastContactedMillis', () async {
    await PersonGroupRepository.instance.save(_group());
    await PersonGroupRepository.instance.addMember('g1', 'p1');
    final at = DateTime(2026, 6, 14);
    await PersonGroupRepository.instance.markContacted('g1', 'p1', at);
    final members = await PersonGroupRepository.instance.listMembers('g1');
    expect(members.first.lastContactedMillis, at.millisecondsSinceEpoch);
  });

  test('listMembers returns members in addedAtMillis order', () async {
    await PersonGroupRepository.instance.save(_group());
    await db
        .into(db.personGroupMembers)
        .insert(
          PersonGroupMembersCompanion.insert(
            groupId: 'g1',
            personId: 'p2',
            addedAtMillis: 200,
          ),
        );
    await db
        .into(db.personGroupMembers)
        .insert(
          PersonGroupMembersCompanion.insert(
            groupId: 'g1',
            personId: 'p1',
            addedAtMillis: 100,
          ),
        );
    await db
        .into(db.personGroupMembers)
        .insert(
          PersonGroupMembersCompanion.insert(
            groupId: 'g1',
            personId: 'p3',
            addedAtMillis: 300,
          ),
        );
    final members = await PersonGroupRepository.instance.listMembers('g1');
    expect(members.map((m) => m.personId).toList(), ['p1', 'p2', 'p3']);
  });

  test('save validates the group', () async {
    expect(
      () => PersonGroupRepository.instance.save(_group().copyWith(name: '   ')),
      throwsA(isA<PersonGroupNameEmpty>()),
    );
  });
}
