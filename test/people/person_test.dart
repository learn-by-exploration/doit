// Direct unit tests for the `Person` sealed hierarchy.
//
// v1.4-stab-D / Phase 44 / SYS-131: lifts `person.dart`
// coverage from 54.5% → ≥80% by exercising the
// `isPausedAt(now)` branch and the `clearPausedUntil`
// path on `ContactPerson.copyWith`.
//
// The deeper model tests (5 channel subclasses, sealed
// exhaustiveness, `PersonSnapshot`, and the full set of
// `copyWith` invariants) live in `test/people/person_model_test.dart`
// (v0.1) and the Cycle K extension (Phase 51 / SYS-138).

import 'package:doit/people/cadence.dart';
import 'package:doit/people/person.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContactPerson pause semantics (SYS-131)', () {
    test('isPausedAt(now) is true iff pausedUntil is non-null and in '
        'the future at the reference time', () {
      final now = DateTime(2026, 6, 30, 12);
      final paused = ContactPerson(
        id: 'p1',
        lookupKey: 'lookup-abc',
        channel: const ChannelDialer('+15551234567'),
        cadence: const EveryNDays(7),
        createdAt: now.subtract(const Duration(days: 30)),
        pausedUntil: now.add(const Duration(days: 3)),
      );
      expect(paused.isPausedAt(now), isTrue);
      expect(
        paused.isPausedAt(now.add(const Duration(days: 5))),
        isFalse,
        reason: 'pause expired at pausedUntil',
      );
      expect(
        paused.isPausedAt(now.subtract(const Duration(seconds: 1))),
        isTrue,
        reason: 'still paused one second in the past',
      );
    });

    test('isPausedAt(now) is false when pausedUntil is null (the '
        'un-paused path)', () {
      final now = DateTime(2026, 6, 30, 12);
      final active = ContactPerson(
        id: 'p1',
        lookupKey: 'lookup-abc',
        channel: const ChannelDialer('+15551234567'),
        cadence: const EveryNDays(7),
        createdAt: now,
      );
      expect(active.isPausedAt(now), isFalse);
      expect(active.pausedUntil, isNull);
    });

    test('copyWith(clearPausedUntil: true) drops the pause even if '
        'pausedUntil is also passed (defensive)', () {
      final now = DateTime(2026, 6, 30, 12);
      final paused = ContactPerson(
        id: 'p1',
        lookupKey: 'lookup-abc',
        channel: const ChannelDialer('+15551234567'),
        cadence: const EveryNDays(7),
        createdAt: now,
        pausedUntil: now.add(const Duration(days: 3)),
      );
      final resumed = paused.copyWith(clearPausedUntil: true);
      expect(
        resumed.pausedUntil,
        isNull,
        reason: 'clearPausedUntil wins over the passed timestamp',
      );
    });
  });

  // v1.4-stab-K / Phase 51 / SYS-138: extend to 100% coverage
  // by exercising every PersonChannel subclass + PersonSnapshot
  // + ContactPerson ==/hashCode.
  group('PersonChannel subclasses (SYS-138)', () {
    test('ChannelDialer ==/hashCode are value-based', () {
      expect(
        const ChannelDialer('+15551234567'),
        equals(const ChannelDialer('+15551234567')),
      );
      expect(
        const ChannelDialer('+15551234567').hashCode,
        equals(const ChannelDialer('+15551234567').hashCode),
      );
      expect(
        const ChannelDialer('+15551234567'),
        isNot(equals(const ChannelDialer('+15559876543'))),
      );
    });

    test('ChannelWhatsApp ==/hashCode are value-based', () {
      expect(
        const ChannelWhatsApp('+15551234567'),
        equals(const ChannelWhatsApp('+15551234567')),
      );
      expect(
        const ChannelWhatsApp('+15551234567').hashCode,
        isNot(equals(const ChannelWhatsApp('+15559876543').hashCode)),
      );
    });

    test('ChannelTelegram ==/hashCode are value-based', () {
      expect(
        const ChannelTelegram('alice'),
        equals(const ChannelTelegram('alice')),
      );
      expect(
        const ChannelTelegram('alice').hashCode,
        isNot(equals(const ChannelTelegram('bob').hashCode)),
      );
    });

    test('ChannelSignal ==/hashCode are value-based', () {
      expect(
        const ChannelSignal('+15551234567'),
        equals(const ChannelSignal('+15551234567')),
      );
      expect(
        const ChannelSignal('+15551234567').hashCode,
        isNot(equals(const ChannelSignal('+15559876543').hashCode)),
      );
    });

    test('ChannelSms ==/hashCode are value-based', () {
      expect(
        const ChannelSms('+15551234567'),
        equals(const ChannelSms('+15551234567')),
      );
      expect(
        const ChannelSms('+15551234567').hashCode,
        isNot(equals(const ChannelSms('+15559876543').hashCode)),
      );
    });

    test('distinct channel types are not equal', () {
      const dialer = ChannelDialer('+15551234567');
      const sms = ChannelSms('+15551234567');
      // Different types, so == must be false.
      expect(dialer, isNot(equals(sms)));
    });
  });

  group('PersonSnapshot (SYS-138)', () {
    test('exposes the underlying person + display name + resolvable', () {
      final person = ContactPerson(
        id: 'p1',
        lookupKey: 'lookup-abc',
        channel: const ChannelDialer('+15551234567'),
        cadence: const EveryNDays(7),
        createdAt: DateTime(2026, 1, 15),
      );
      final snap = PersonSnapshot(
        person: person,
        displayName: 'Alice',
        resolvable: true,
      );
      expect(snap.person, same(person));
      expect(snap.displayName, 'Alice');
      expect(snap.resolvable, isTrue);
    });

    test('unresolved snapshot has resolvable=false', () {
      final person = ContactPerson(
        id: 'p1',
        lookupKey: 'lookup-abc',
        channel: const ChannelDialer('+15551234567'),
        cadence: const EveryNDays(7),
        createdAt: DateTime(2026, 1, 15),
      );
      final snap = PersonSnapshot(
        person: person,
        displayName: 'Alice (deleted)',
        resolvable: false,
      );
      expect(snap.resolvable, isFalse);
    });
  });

  group('ContactPerson ==/hashCode (SYS-138)', () {
    test('equality is id-based', () {
      final a = ContactPerson(
        id: 'p1',
        lookupKey: 'lookup-abc',
        channel: const ChannelDialer('+15551234567'),
        cadence: const EveryNDays(7),
        createdAt: DateTime(2026, 1, 15),
      );
      final b = ContactPerson(
        id: 'p1',
        lookupKey: 'lookup-xyz',
        channel: const ChannelWhatsApp('+15559876543'),
        cadence: const EveryNDays(14),
        createdAt: DateTime(2026, 2, 20),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
