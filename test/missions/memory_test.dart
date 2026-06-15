// Tests for [MemoryMission.verify].

import 'package:doit/missions/mission.dart';
import 'package:doit/missions/mission_input.dart';
import 'package:doit/missions/mission_result.dart';
import 'package:flutter_test/flutter_test.dart';

List<MemoryPair> _pairs(int n) => [
  for (var i = 0; i < n; i++) MemoryPair(i, i + 100),
];

void main() {
  const mission = MemoryMission(
    id: 'm1',
    label: 'Memory',
    timeout: Duration(seconds: 30),
    rows: 2,
    cols: 3,
    theme: 'animals',
  );

  group('MemoryMission.verify', () {
    test('passes when all pairs matched within time limit', () {
      final result = mission.verify(
        MemoryInput(
          matchedPairs: _pairs(3),
          elapsed: const Duration(seconds: 10),
        ),
      );
      expect(result, isA<MissionPassed>());
    });

    test('fails when not all pairs matched', () {
      final result = mission.verify(
        MemoryInput(
          matchedPairs: _pairs(2),
          elapsed: const Duration(seconds: 10),
        ),
      );
      expect(result, isA<MissionFailed>());
      expect((result as MissionFailed).reason, startsWith('not-all-pairs:'));
    });

    test('fails when elapsed exceeds time limit', () {
      final result = mission.verify(
        MemoryInput(
          matchedPairs: _pairs(3),
          elapsed: const Duration(seconds: 61),
        ),
      );
      expect(result, isA<MissionFailed>());
      expect((result as MissionFailed).reason, 'time-limit-exceeded');
    });

    test('fails when a card is flipped twice (duplicate-flip)', () {
      const input = MemoryInput(
        matchedPairs: [
          MemoryPair(0, 100),
          MemoryPair(0, 200), // 0 reused
          MemoryPair(2, 102),
        ],
        elapsed: Duration(seconds: 10),
      );
      final result = mission.verify(input);
      expect(result, isA<MissionFailed>());
      expect((result as MissionFailed).reason, 'duplicate-flip');
    });

    test('input-mismatch when input is not MemoryInput', () {
      final result = mission.verify(const TextInput('done'));
      expect(result, isA<MissionFailed>());
      expect((result as MissionFailed).reason, 'input-mismatch');
    });
  });
}
