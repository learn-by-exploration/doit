// v1.4-stab-L / Phase 52 / SYS-139 / ADR-070 / WF-067:
// Mission model fuzz test.
//
// 1000 iterations of randomized `Mission` chain construction.
// Invariants pinned:
//   - MissionChain.from([...]) preserves all missions in
//     order, in count, and the runtime type of each.
//   - MissionChain.empty works (the SoftProof default).
//   - Each mission subclass (Shake, Type, Hold, Math,
//     Memory) constructs without throwing for in-range
//     randomized args.
//   - Mission.verify(MissionInput) returns a MissionResult
//     without throwing — even for an input-mismatch.

import 'dart:math';

import 'package:doit/missions/chain.dart';
import 'package:doit/missions/mission.dart';
import 'package:doit/missions/mission_input.dart';
import 'package:doit/missions/mission_result.dart';
import 'package:flutter_test/flutter_test.dart';

const int _iterations = 1000;

class _Fuzz {
  _Fuzz(int seed) : _rng = Random(seed);
  final Random _rng;

  int nextInt(int max) => _rng.nextInt(max);

  Mission nextMission(int idx) {
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
          targetCount: 1 + _rng.nextInt(20),
        );
      case 1:
        return TypeMission(
          id: id,
          label: label,
          timeout: timeout,
          expectedPhrase: 'phrase-${_rng.nextInt(1000)}',
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
        // MemoryMission asserts even-cell grid. Pick rows
        // and cols both even so the construction succeeds.
        final rows = 2 + _rng.nextInt(3) * 2; // 2, 4, 6
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

void main() {
  test(
    'MissionChain construction + Mission.verify invariants hold over 1000 fuzz iterations',
    () {
      // Arrange
      final fuzz = _Fuzz(45);

      // Act + Assert
      for (var i = 0; i < _iterations; i++) {
        final n = 1 + fuzz.nextInt(5);
        final list = <Mission>[for (var k = 0; k < n; k++) fuzz.nextMission(k)];
        final chain = MissionChain.from(list);

        // Chain length + order preserved.
        expect(chain.length, equals(n));
        for (var k = 0; k < n; k++) {
          expect(chain[k].id, equals('m$k'));
          expect(chain[k].runtimeType, equals(list[k].runtimeType));
        }

        // verify() must never throw — even with a random
        // wrong-typed input. The contract is "return
        // MissionFailed('input-mismatch')" rather than throw.
        for (var k = 0; k < n; k++) {
          final m = chain[k];
          final result = m.verify(const TextInput('hello'));
          expect(result, isA<MissionResult>());
          // For an obvious input-mismatch (TextInput passed to
          // Shake/Hold/Math/Memory), the contract is
          // MissionFailed.
          if (m is! TypeMission) {
            expect(result, isA<MissionFailed>());
          }
        }
      }

      // MissionChain.empty is the SoftProof default — length 0.
      expect(MissionChain.empty.length, equals(0));
    },
  );
}
