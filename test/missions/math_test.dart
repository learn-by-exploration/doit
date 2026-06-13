// Tests for [MathMission.verify].

import 'package:common_games/missions/mission.dart';
import 'package:common_games/missions/mission_input.dart';
import 'package:common_games/missions/mission_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mission = MathMission(
    id: 'm1',
    label: 'Math',
    timeout: Duration(seconds: 30),
    difficulty: MathDifficulty.easy,
  );

  group('MathMission.verify', () {
    test('passes when answer is correct', () {
      const problem = MathProblem(a: 2, b: 3, op: MathOp.add, answer: 5);
      final result = mission.verify(
        const MathInput(problem: problem, answer: 5),
      );
      expect(result, isA<MissionPassed>());
    });

    test('fails when answer is wrong', () {
      const problem = MathProblem(a: 2, b: 3, op: MathOp.add, answer: 5);
      final result = mission.verify(
        const MathInput(problem: problem, answer: 6),
      );
      expect(result, isA<MissionFailed>());
      expect((result as MissionFailed).reason, startsWith('wrong-answer:'));
    });

    test('input-mismatch when input is not MathInput', () {
      final result = mission.verify(const TextInput('5'));
      expect(result, isA<MissionFailed>());
      expect((result as MissionFailed).reason, 'input-mismatch');
    });
  });
}
