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
}
