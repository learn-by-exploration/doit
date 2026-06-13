// Tests for the Person model and PersonChannel hierarchy.

import 'package:common_games/people/cadence.dart';
import 'package:common_games/people/person.dart';
import 'package:flutter_test/flutter_test.dart';

ContactPerson _person({PersonChannel? channel, PersonCadence? cadence}) {
  return ContactPerson(
    id: 'p1',
    lookupKey: 'lookup-abc',
    channel: channel ?? const ChannelDialer('+15551234567'),
    cadence: cadence ?? const EveryNDays(7),
    createdAt: DateTime(2026),
  );
}

void main() {
  group('PersonChannel equality', () {
    test('ChannelDialer is value-equal on the phone number', () {
      const a = ChannelDialer('+15551234567');
      const b = ChannelDialer('+15551234567');
      const c = ChannelDialer('+15559999999');
      expect(a, b);
      expect(a, isNot(c));
    });

    test('ChannelWhatsApp and ChannelDialer with the same number are '
        'not equal (different channel types)', () {
      const a = ChannelWhatsApp('+15551234567');
      const b = ChannelDialer('+15551234567');
      expect(a, isNot(b));
    });
  });

  group('ContactPerson.copyWith immutability', () {
    test('copyWith returns a new instance, the original is unchanged', () {
      final p = _person();
      final p2 = p.copyWith(channel: const ChannelWhatsApp('+15551234567'));
      expect(identical(p, p2), isFalse);
      expect(p.channel, isA<ChannelDialer>());
      expect(p2.channel, isA<ChannelWhatsApp>());
    });

    test('id and lookupKey are not copyWith-mutable (identity-bound)', () {
      // copyWith intentionally does not expose id /
      // lookupKey; they are stable for the person's lifetime.
      final p = _person();
      final p2 = p.copyWith(channel: const ChannelSms('+15550000000'));
      expect(p.id, p2.id);
      expect(p.lookupKey, p2.lookupKey);
    });

    test('Person equality is id-based', () {
      final a = _person();
      final b = _person();
      expect(a, b); // same id
    });
  });

  group('PersonSnapshot', () {
    test('carries a Person, a display name, and a resolvable flag', () {
      final p = _person();
      final snap = PersonSnapshot(
        person: p,
        displayName: 'Alice',
        resolvable: true,
      );
      expect(snap.displayName, 'Alice');
      expect(snap.resolvable, isTrue);
      expect(snap.person.id, 'p1');
    });
  });
}
