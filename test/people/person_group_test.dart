// Tests for the PersonGroup model and rotation selector (WF-018).

import 'package:doit/people/cadence.dart';
import 'package:doit/people/person_group.dart';
import 'package:flutter_test/flutter_test.dart';

PersonGroup _group({
  GroupSemantic semantic = GroupSemantic.rotation,
  PersonCadence? cadence,
}) {
  return ContactGroup(
    id: 'g1',
    name: 'Friends',
    cadence: cadence ?? const EveryNDays(7),
    semantic: semantic,
    channel: 'whatsapp',
    handle: 'chat_uri',
    createdAt: DateTime(2026, 6),
  );
}

void main() {
  group('PersonGroup.validate', () {
    test('accepts a valid group', () {
      expect(() => _group().validate(), returnsNormally);
    });

    test('rejects empty name', () {
      expect(
        () => _group().copyWith(name: '   ').validate(),
        throwsA(isA<PersonGroupNameEmpty>()),
      );
    });

    test('rejects empty channel', () {
      expect(
        () => _group().copyWith(channel: '').validate(),
        throwsA(isA<PersonGroupChannelEmpty>()),
      );
    });

    test('rejects empty handle', () {
      expect(
        () => _group().copyWith(handle: ' ').validate(),
        throwsA(isA<PersonGroupHandleEmpty>()),
      );
    });
  });

  group('PersonGroup.copyWith', () {
    test('preserves id and createdAt; replaces name and cadence', () {
      final g = _group();
      final g2 = g.copyWith(name: 'Close friends', semantic: GroupSemantic.any);
      expect(g2.id, 'g1');
      expect(g2.createdAt, g.createdAt);
      expect(g2.name, 'Close friends');
      expect(g2.semantic, GroupSemantic.any);
    });

    test('clearPausedUntil sets pausedUntil to null', () {
      final g = _group().copyWith(pausedUntil: DateTime(2030));
      expect(g.pausedUntil, isNotNull);
      final g2 = g.copyWith(clearPausedUntil: true);
      expect(g2.pausedUntil, isNull);
    });
  });

  group('PersonGroup.isPausedAt', () {
    test('returns false when not paused', () {
      expect(_group().isPausedAt(DateTime(2026, 6, 14)), isFalse);
    });

    test('returns true when pausedUntil is in the future', () {
      final g = _group().copyWith(pausedUntil: DateTime(2027));
      expect(g.isPausedAt(DateTime(2026, 6, 14)), isTrue);
    });

    test('returns false when pausedUntil is in the past', () {
      final g = _group().copyWith(pausedUntil: DateTime(2026));
      expect(g.isPausedAt(DateTime(2026, 6, 14)), isFalse);
    });
  });

  group('pickNextMember', () {
    test('returns null for empty list', () {
      expect(pickNextMember([]), isNull);
    });

    test('returns the only member when there is one', () {
      final m = GroupMember(
        personId: 'p1',
        addedAtMillis: DateTime(2026).millisecondsSinceEpoch,
      );
      expect(pickNextMember([m]), 'p1');
    });

    test('prefers a never-contacted member over a contacted one', () {
      final never = GroupMember(
        personId: 'p1',
        addedAtMillis: DateTime(2026).millisecondsSinceEpoch,
      );
      final contacted = GroupMember(
        personId: 'p2',
        addedAtMillis: DateTime(2026, 1, 2).millisecondsSinceEpoch,
        lastContactedMillis: DateTime(2026, 5).millisecondsSinceEpoch,
      );
      expect(pickNextMember([contacted, never]), 'p1');
    });

    test('picks the least-recently-contacted among contacted', () {
      final p1 = GroupMember(
        personId: 'p1',
        addedAtMillis: 1,
        lastContactedMillis: DateTime(2026, 5).millisecondsSinceEpoch,
      );
      final p2 = GroupMember(
        personId: 'p2',
        addedAtMillis: 2,
        lastContactedMillis: DateTime(2026, 3).millisecondsSinceEpoch,
      );
      final p3 = GroupMember(
        personId: 'p3',
        addedAtMillis: 3,
        lastContactedMillis: DateTime(2026, 6).millisecondsSinceEpoch,
      );
      expect(pickNextMember([p1, p2, p3]), 'p2');
    });

    test('breaks ties by addedAtMillis (oldest wins)', () {
      final p1 = GroupMember(
        personId: 'p1',
        addedAtMillis: DateTime(2026).millisecondsSinceEpoch,
      );
      final p2 = GroupMember(
        personId: 'p2',
        addedAtMillis: DateTime(2026, 2).millisecondsSinceEpoch,
      );
      final p3 = GroupMember(
        personId: 'p3',
        addedAtMillis: DateTime(2026, 3).millisecondsSinceEpoch,
      );
      expect(pickNextMember([p3, p2, p1]), 'p1');
    });
  });

  group('markContacted', () {
    test('updates lastContactedMillis for the matching member', () {
      const m1 = GroupMember(personId: 'p1', addedAtMillis: 1);
      final m2 = GroupMember(
        personId: 'p2',
        addedAtMillis: 2,
        lastContactedMillis: DateTime(2026, 5).millisecondsSinceEpoch,
      );
      final updated = markContacted([m1, m2], 'p1', DateTime(2026, 6, 14));
      expect(
        updated[0].lastContactedMillis,
        DateTime(2026, 6, 14).millisecondsSinceEpoch,
      );
      expect(updated[1].lastContactedMillis, m2.lastContactedMillis);
    });

    test('preserves the length and order of the list', () {
      const m1 = GroupMember(personId: 'p1', addedAtMillis: 1);
      const m2 = GroupMember(personId: 'p2', addedAtMillis: 2);
      const m3 = GroupMember(personId: 'p3', addedAtMillis: 3);
      final updated = markContacted([m1, m2, m3], 'p2', DateTime(2026, 6, 14));
      expect(updated.length, 3);
      expect(updated.map((m) => m.personId).toList(), ['p1', 'p2', 'p3']);
    });
  });
}
