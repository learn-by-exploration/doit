// Tests for [MissionChainExecutor] — composition of missions.

import 'package:doit/missions/chain.dart';
import 'package:doit/missions/chain_executor.dart';
import 'package:doit/missions/mission.dart';
import 'package:doit/missions/mission_input.dart';
import 'package:doit/missions/mission_result.dart';
import 'package:flutter_test/flutter_test.dart';

const _hold = HoldMission(
  id: 'hold',
  label: 'Hold',
  timeout: Duration(seconds: 10),
  holdDuration: Duration(seconds: 1),
);
const _type = TypeMission(
  id: 'type',
  label: 'Type',
  timeout: Duration(seconds: 10),
  expectedPhrase: 'ok',
);
const _math = MathMission(
  id: 'math',
  label: 'Math',
  timeout: Duration(seconds: 10),
  difficulty: MathDifficulty.easy,
);

const _twoPlusTwo = MathProblem(a: 1, b: 1, op: MathOp.add, answer: 2);

void main() {
  group('MissionChainExecutor.run', () {
    const executor = MissionChainExecutor();

    test('empty chain returns empty-chain failure at index 0', () {
      final chain = MissionChain(const <Mission>[]);
      final result = executor.run(chain, const <MissionInput>[]);
      expect(result, isA<ChainFailedAt>());
      expect((result as ChainFailedAt).index, 0);
      expect((result.result as MissionFailed).reason, 'empty-chain');
    });

    test('input-length-mismatch returns failure at index 0', () {
      final chain = MissionChain([_hold, _type]);
      final result = executor.run(chain, const [
        HoldInput(Duration(seconds: 2)),
      ]);
      expect(result, isA<ChainFailedAt>());
      expect((result as ChainFailedAt).index, 0);
      expect(
        (result.result as MissionFailed).reason,
        startsWith('input-length-mismatch:'),
      );
    });

    test('single pass', () {
      final chain = MissionChain([_hold]);
      final result = executor.run(chain, const [
        HoldInput(Duration(seconds: 2)),
      ]);
      expect(result, isA<ChainPassed>());
      expect((result as ChainPassed).results.length, 1);
      expect(result.results.first, isA<MissionPassed>());
    });

    test('three pass', () {
      final chain = MissionChain([_hold, _type, _math]);
      final result = executor.run(chain, const [
        HoldInput(Duration(seconds: 2)),
        TextInput('ok'),
        MathInput(problem: _twoPlusTwo, answer: 2),
      ]);
      expect(result, isA<ChainPassed>());
      expect((result as ChainPassed).results.length, 3);
    });

    test('failure aborts the rest', () {
      final chain = MissionChain([_hold, _type, _math]);
      final result = executor.run(chain, const [
        HoldInput(Duration(seconds: 2)),
        TextInput('nope'), // type fails
        // math should not be reached
        MathInput(problem: _twoPlusTwo, answer: 2),
      ]);
      expect(result, isA<ChainFailedAt>());
      expect((result as ChainFailedAt).index, 1);
      expect(result.result, isA<MissionFailed>());
    });

    test('timeout-style hold short-circuit returns failure at index 0', () {
      final chain = MissionChain([_hold, _type]);
      final result = executor.run(chain, const [
        HoldInput(Duration(milliseconds: 500)),
        TextInput('ok'),
      ]);
      expect(result, isA<ChainFailedAt>());
      expect((result as ChainFailedAt).index, 0);
      expect(result.result, isA<MissionFailed>());
    });
  });
}
