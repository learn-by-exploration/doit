// v1.4-stab-L / Phase 52 / SYS-139 / ADR-070 / WF-067:
// Person model fuzz test.
//
// 1000 iterations of randomized `ContactPerson` construction
// + `copyWith`. Invariants pinned:
//   - copyWith preserves the runtime subclass (ContactPerson
//     stays ContactPerson, all 5 channels preserve their
//     channel type).
//   - copyWith preserves fields not overridden.
//   - copyWith with a new channel swaps the channel type
//     exactly when the override is provided.
//   - Construction never throws (the constructor is pure).
//
// Fuzz seed: `dart:math.Random(seed)` — no `package:faker`
// per the Cycle L pre-auth.

import 'dart:math';

import 'package:doit/people/cadence.dart';
import 'package:doit/people/person.dart';
import 'package:flutter_test/flutter_test.dart';

const int _iterations = 1000;

class _Fuzz {
  _Fuzz(int seed) : _rng = Random(seed);
  final Random _rng;

  int nextInt(int max) => _rng.nextInt(max);

  PersonChannel nextChannel() {
    final kind = _rng.nextInt(5);
    final phone = '+${1000000 + _rng.nextInt(8999999)}';
    switch (kind) {
      case 0:
        return ChannelDialer(phone);
      case 1:
        return ChannelWhatsApp(phone);
      case 2:
        return ChannelTelegram('user-${_rng.nextInt(1 << 20)}');
      case 3:
        return ChannelSignal(phone);
      default:
        return ChannelSms(phone);
    }
  }

  ContactPerson nextPerson() {
    final id = 'p-${_rng.nextInt(1 << 30)}';
    final lookupKey = 'lk-${_rng.nextInt(1 << 30)}';
    final channel = nextChannel();
    final cadenceKind = _rng.nextInt(4);
    final createdAt = DateTime(
      2024 + _rng.nextInt(10),
      1 + _rng.nextInt(12),
      15,
    );
    PersonCadence cadence;
    switch (cadenceKind) {
      case 0:
        cadence = EveryNDays(1 + _rng.nextInt(30));
      case 1:
        cadence = WeeklyOn(1 + _rng.nextInt(7));
      case 2:
        cadence = MonthlyOn(1 + _rng.nextInt(28));
      default:
        cadence = YearlyOn(1 + _rng.nextInt(12), 1 + _rng.nextInt(28));
    }
    return ContactPerson(
      id: id,
      lookupKey: lookupKey,
      channel: channel,
      cadence: cadence,
      createdAt: createdAt,
    );
  }
}

void main() {
  test(
    'ContactPerson constructor + copyWith invariants hold over 1000 fuzz iterations',
    () {
      // Arrange
      final fuzz = _Fuzz(44);

      // Act + Assert
      for (var i = 0; i < _iterations; i++) {
        final p = fuzz.nextPerson();

        // Runtime type preserved through copyWith.
        final renamed = p.copyWith();
        expect(renamed.runtimeType, equals(ContactPerson));
        expect(renamed.id, equals(p.id));
        expect(renamed.lookupKey, equals(p.lookupKey));
        expect(renamed.channel, equals(p.channel));
        expect(renamed.cadence, equals(p.cadence));
        expect(renamed.createdAt, equals(p.createdAt));

        // Channel swap works — pick a new channel of the
        // SAME shape (ChannelDialer) to keep the field set
        // uniform. The channel field must replace cleanly.
        final newPhone = '+${1000000 + fuzz.nextInt(1 << 30)}';
        final swapped = p.copyWith(channel: ChannelDialer(newPhone));
        expect(swapped.channel, isA<ChannelDialer>());
        expect(
          (swapped.channel as ChannelDialer).phoneNumber,
          equals(newPhone),
        );

        // No-throw invariants: copyWith without args must
        // never throw, and the resulting instance must equal
        // the source field-for-field.
        final cloned = p.copyWith();
        expect(cloned.id, equals(p.id));
        expect(cloned.lookupKey, equals(p.lookupKey));
        expect(cloned.cadence, equals(p.cadence));
      }
    },
  );
}
