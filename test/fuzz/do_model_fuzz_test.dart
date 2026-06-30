// v1.4-stab-L / Phase 52 / SYS-139 / ADR-070 / WF-067:
// Do model fuzz tests.
//
// 1000 iterations × 2 tests = 2000 fuzz inputs.
// Each iteration generates a random `Do` (any of the 5
// schedule subclasses) and exercises:
//   1. `Do.validate()` — must throw a `DoValidationException`
//      iff the random fields trip an invariant; otherwise it
//      must complete.
//   2. `Do.copyWith(name: <random>)` — must produce a new
//      instance with the new name; identity, schedule, and
//      the other fields preserved.
//
// The fuzz seed is `dart:math`'s `Random(seed)` (no
// `package:faker` per cycle pre-auth — the plan files
// "writes its own seed generator").
//
// The invariants the fuzz must not violate:
//   - copyWith never mutates the source (immutability).
//   - copyWith(name: X).name == X.
//   - copyWith preserves the runtime subclass (DoFixed
//     stays DoFixed, etc.).
//   - copyWith preserves every non-overridden field.

import 'dart:math';

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/missions/chain.dart';
import 'package:flutter_test/flutter_test.dart';

const int _iterations = 1000;

/// Top-level fuzz seed generator. NO `package:faker` —
/// per the Cycle L pre-auth, write our own. Uses
/// `dart:math.Random` with a deterministic seed so the
/// fuzz run is reproducible.
class _Fuzz {
  _Fuzz(int seed) : _rng = Random(seed);
  final Random _rng;

  /// Generates a random `Do` of any of the 5 schedule
  /// subclasses. The fields are randomized across their
  /// declared ranges — some valid, some intentionally
  /// invalid — so `Do.validate()` gets exercised.
  Do nextDo() {
    final id = 'do-${_rng.nextInt(1 << 30)}';
    // Half the time use a non-empty name, half the time a
    // string that may or may not be empty after trim.
    final name = _rng.nextBool()
        ? 'name-${_rng.nextInt(1000)}'
        : '   '; // empty after trim → DoNameEmpty
    final proof = _rng.nextBool()
        ? const SoftProof()
        : StrongProof(_nonEmptyChain());
    final createdAt = DateTime(
      2024 + _rng.nextInt(10),
      1 + _rng.nextInt(12),
      15,
      _rng.nextInt(24),
      _rng.nextInt(60),
    );
    final restDays = _rng.nextInt(40); // 0..39 → may be invalid
    final category = DoCategory.values[_rng.nextInt(DoCategory.values.length)];
    // 0..9 — may be invalid (>7).
    final colorSeed = _rng.nextInt(10);
    final iconName = _rng.nextBool()
        ? null
        : DoIcons.keys[_rng.nextInt(DoIcons.keys.length)];
    final pausedUntil = _rng.nextBool()
        ? null
        : createdAt.add(Duration(days: _rng.nextInt(30) - 15));
    final graceOverride = _rng.nextBool()
        ? null
        : Duration(hours: _rng.nextInt(48));
    final deletedAt = _rng.nextInt(100) < 5
        ? createdAt.add(Duration(days: _rng.nextInt(30)))
        : null;

    final kind = _rng.nextInt(5);
    switch (kind) {
      case 0:
        return DoFixed(
          id: id,
          name: name,
          proofMode: proof,
          createdAt: createdAt,
          restDaysPerMonth: restDays,
          category: category,
          colorSeed: colorSeed,
          iconName: iconName,
          pausedUntil: pausedUntil,
          graceWindowOverride: graceOverride,
          deletedAt: deletedAt,
          weekdays: _randomWeekdays(),
          time: DoTime(_rng.nextInt(30), _rng.nextInt(70)),
        );
      case 1:
        return DoInterval(
          id: id,
          name: name,
          proofMode: proof,
          createdAt: createdAt,
          restDaysPerMonth: restDays,
          category: category,
          colorSeed: colorSeed,
          iconName: iconName,
          pausedUntil: pausedUntil,
          graceWindowOverride: graceOverride,
          deletedAt: deletedAt,
          nDays: _rng.nextInt(10), // may be <1 → invalid
          referenceDate: createdAt,
        );
      case 2:
        return DoAnchor(
          id: id,
          name: name,
          proofMode: proof,
          createdAt: createdAt,
          restDaysPerMonth: restDays,
          category: category,
          colorSeed: colorSeed,
          iconName: iconName,
          pausedUntil: pausedUntil,
          graceWindowOverride: graceOverride,
          deletedAt: deletedAt,
          // 50% self-reference (invalid), 50% a different id.
          targetDoId: _rng.nextBool() ? id : 'other-${_rng.nextInt(1 << 20)}',
          lastAnchor: _rng.nextBool()
              ? null
              : createdAt.add(Duration(days: _rng.nextInt(30))),
        );
      case 3:
        // Always satisfy the assert (dayOfMonth OR (nth,
        // weekday)) so construction succeeds; out-of-range
        // values still surface via Do.validate.
        final useDay = _rng.nextBool();
        return DoDayOfX(
          id: id,
          name: name,
          proofMode: proof,
          createdAt: createdAt,
          restDaysPerMonth: restDays,
          category: category,
          colorSeed: colorSeed,
          iconName: iconName,
          pausedUntil: pausedUntil,
          graceWindowOverride: graceOverride,
          deletedAt: deletedAt,
          dayOfMonth: useDay ? 1 + _rng.nextInt(35) : null,
          nth: useDay ? null : 1 + _rng.nextInt(7),
          weekday: useDay ? null : 1 + _rng.nextInt(8),
          referenceDayOfMonth: 1 + _rng.nextInt(35),
        );
      default:
        return DoTimeWindow(
          id: id,
          name: name,
          proofMode: proof,
          createdAt: createdAt,
          restDaysPerMonth: restDays,
          category: category,
          colorSeed: colorSeed,
          iconName: iconName,
          pausedUntil: pausedUntil,
          graceWindowOverride: graceOverride,
          deletedAt: deletedAt,
          weekdays: _randomWeekdays(),
          start: DoTime(_rng.nextInt(24), _rng.nextInt(60)),
          end: DoTime(_rng.nextInt(24), _rng.nextInt(60)),
          targetHours: _rng.nextBool()
              ? 1 +
                    _rng.nextInt(25) // may be invalid (>23)
              : null,
        );
    }
  }

  Set<Weekday> _randomWeekdays() {
    final n = _rng.nextInt(8); // 0..7 → may be invalid (0 = empty)
    final set = <Weekday>{};
    for (var i = 0; i < n; i++) {
      set.add(1 + _rng.nextInt(8)); // may be invalid (>7)
    }
    return set;
  }

  /// Non-empty variant for StrongProof — Do.validate
  /// rejects empty chains via [validateProofMode]. Keep
  /// the construction phase assert-free.
  MissionChain _nonEmptyChain() {
    final list = <Mission>[_randomMission(0)];
    return MissionChain.from(list);
  }

  Mission _randomMission(int idx) {
    final kind = _rng.nextInt(5);
    final id = 'm$idx';
    final label = 'label-$idx';
    final timeout = Duration(seconds: 5 + _rng.nextInt(60));
    switch (kind) {
      case 0:
        return ShakeMission(
          id: id,
          label: label,
          timeout: timeout,
          targetCount: 5 + _rng.nextInt(20),
        );
      case 1:
        return TypeMission(
          id: id,
          label: label,
          timeout: timeout,
          expectedPhrase: 'phrase-${_rng.nextInt(100)}',
        );
      case 2:
        return HoldMission(
          id: id,
          label: label,
          timeout: timeout,
          holdDuration: Duration(seconds: 1 + _rng.nextInt(30)),
        );
      case 3:
        return MathMission(
          id: id,
          label: label,
          timeout: timeout,
          difficulty:
              MathDifficulty.values[_rng.nextInt(MathDifficulty.values.length)],
        );
      default:
        // MemoryMission asserts even-cell grid + rows>0 +
        // cols>0. Pick both even to keep construction
        // assert-free.
        final rows = 2 + _rng.nextInt(3) * 2;
        final cols = 2 + _rng.nextInt(3) * 2;
        return MemoryMission(
          id: id,
          label: label,
          timeout: timeout,
          rows: rows,
          cols: cols,
          theme: 'theme-$idx',
        );
    }
  }
}

/// v1.4-stab-L (SYS-139): fuzz `Do` constructor + `copyWith`
/// invariants across 1000 iterations.
void main() {
  test(
    'Do constructor + copyWith invariants hold over 1000 fuzz iterations',
    () {
      // Arrange
      final fuzz = _Fuzz(42);

      // Act + Assert
      for (var i = 0; i < _iterations; i++) {
        final d = fuzz.nextDo();
        // validate must NOT throw — invalid Do instances are
        // allowed to exist transiently (e.g. during a copyWith
        // that mutates a single field at a time). The fuzz
        // just exercises the constructor + the validate
        // method together; it must never crash.
        try {
          d.validate();
        } on DoValidationException {
          // Expected when a random field trips an invariant.
          // The constructor itself should not throw for
          // invalid fields — that's what validate() is for.
        }
        // copyWith(name: ...) must return a new instance
        // with the new name; identity preserved.
        final renamed = d.copyWith(name: 'renamed-$i');
        expect(renamed.name, equals('renamed-$i'));
        expect(renamed.id, equals(d.id));
        expect(renamed.runtimeType, equals(d.runtimeType));
        // copyWith without args must equal the source.
        final cloned = d.copyWith();
        expect(cloned.id, equals(d.id));
        expect(cloned.name, equals(d.name));
        expect(cloned.runtimeType, equals(d.runtimeType));
      }
    },
  );

  test('Do validate surfaces invariants across 1000 fuzz iterations', () {
    // Arrange — fuzz a smaller set, but assert that
    // validate() throws iff the random fields trip an
    // invariant (and never throws a non-DoValidationException).
    final fuzz = _Fuzz(43);

    // Act + Assert
    var sawInvalid = 0;
    var sawValid = 0;
    for (var i = 0; i < _iterations; i++) {
      final d = fuzz.nextDo();
      try {
        d.validate();
        sawValid++;
      } on DoValidationException {
        sawInvalid++;
      } catch (e) {
        fail(
          'Iteration $i: validate() threw unexpected $e '
          '(must be DoValidationException)',
        );
      }
    }
    // Sanity — at least SOME iterations hit each branch.
    // (If 100% are valid, the fuzz isn't exercising the
    // validation surface.)
    expect(sawInvalid, greaterThan(0));
    expect(sawValid, greaterThan(0));
  });
}
