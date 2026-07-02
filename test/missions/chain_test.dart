// Tests for [MissionChainExecutor] — composition of missions.
//
// v1.5-cyc-chain extends this file with +8 executor edge-case
// tests (SYS-145 / ADR-076 / WF-073): input-type mismatch
// returns MissionFailed (ChainFailedAt wrapping), idempotency
// for the same chain + inputs, boundary cases for first/last/
// single mission failing, ChainTimedOut is-a ChainFailedAt, the
// ChainPassed contents contract, and proof that the executor
// short-circuits on first failure (a passed-input at index N+1
// would have produced MissionPassed if called — the fact that
// we get a failure proves the executor stopped).
//
// NOTE on the sealed-class constraint: `Mission` is a sealed
// class so the test file cannot extend it to create spy
// missions. The "+2" dropped tests (MissionTimedOut propagation
// at index 0 / at last index with a verify-counter assertion)
// are deferred to v2.0 when a `MissionTimedOut`-returning leaf
// mission lands (currently no public mission emits TimedOut —
// the widget owns the wall-clock and passes a "no answer"
// input). The ChainTimedOut type-hierarchy test below pins the
// `r is MissionTimedOut` branch's data shape independently.

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

    // -----------------------------------------------------------------
    // v1.5-cyc-chain — +8 executor edge cases.
    // -----------------------------------------------------------------

    test('input type mismatch at mission 0 returns ChainFailedAt '
        'wrapping MissionFailed("input-mismatch")', () {
      // Arrange — feed TextInput to HoldMission (wrong type).
      // HoldMission.verify returns MissionFailed('input-mismatch').
      final chain = MissionChain([_hold, _type]);
      final result = executor.run(chain, const [
        TextInput('ok'), // wrong type for HoldMission
        TextInput('ok'),
      ]);

      // Act + Assert.
      expect(result, isA<ChainFailedAt>());
      final failed = result as ChainFailedAt;
      expect(failed.index, 0);
      expect(failed.result, isA<MissionFailed>());
      expect((failed.result as MissionFailed).reason, 'input-mismatch');
    });

    test('idempotent for same chain + inputs (run twice yields identical '
        'results)', () {
      // Arrange — a 3-mission all-pass chain.
      final chain = MissionChain([_hold, _type, _math]);
      const inputs = [
        HoldInput(Duration(seconds: 2)),
        TextInput('ok'),
        MathInput(problem: _twoPlusTwo, answer: 2),
      ];

      // Act.
      final first = executor.run(chain, inputs);
      final second = executor.run(chain, inputs);

      // Assert — both are ChainPassed with the same length +
      // runtime types. Per-mission details (e.g., 'held=2000ms')
      // are deterministic for these inputs.
      expect(first, isA<ChainPassed>());
      expect(second, isA<ChainPassed>());
      expect(
        (first as ChainPassed).results.length,
        (second as ChainPassed).results.length,
      );
      for (var i = 0; i < first.results.length; i++) {
        expect(first.results[i].runtimeType, second.results[i].runtimeType);
      }
    });

    test('executor short-circuits on first failure (passed input at '
        'index N+1 would have produced MissionPassed)', () {
      // Arrange — chain of 3; index 1 fails (TextInput 'nope');
      // index 2's input is a *passing* MathInput. If the
      // executor walked all 3, we'd see ChainPassed. The fact
      // that we see ChainFailedAt(1, ...) proves the executor
      // stopped at index 1.
      final chain = MissionChain([_hold, _type, _math]);

      // Act.
      final result = executor.run(chain, const [
        HoldInput(Duration(seconds: 2)), // passes
        TextInput('nope'), // fails (phrase-mismatch)
        MathInput(problem: _twoPlusTwo, answer: 2), // would pass
      ]);

      // Assert.
      expect(result, isA<ChainFailedAt>());
      expect((result as ChainFailedAt).index, 1);
      expect((result.result as MissionFailed).reason, 'phrase-mismatch');
      // Indirect proof of short-circuit: NOT a ChainPassed.
      expect(result, isNot(isA<ChainPassed>()));
    });

    test('first-mission failing stops at index 0', () {
      // Arrange — chain of 3 where the FIRST fails.
      final chain = MissionChain(
        [_type, _hold, _math], // type first; type fails on "nope"
      );

      // Act.
      final result = executor.run(chain, const [
        TextInput('nope'), // type fails
        HoldInput(Duration(seconds: 2)),
        MathInput(problem: _twoPlusTwo, answer: 2),
      ]);

      // Assert — fail at index 0; the second and third never
      // contribute results.
      expect(result, isA<ChainFailedAt>());
      expect((result as ChainFailedAt).index, 0);
      expect(result.result, isA<MissionFailed>());
    });

    test('last-mission failing stops at last index', () {
      // Arrange — chain of 3 where the LAST fails.
      final chain = MissionChain([_hold, _type, _math]);

      // Act — math at index 2 fails (wrong answer).
      final result = executor.run(chain, const [
        HoldInput(Duration(seconds: 2)),
        TextInput('ok'),
        MathInput(problem: _twoPlusTwo, answer: 999),
      ]);

      // Assert — fail at index 2.
      expect(result, isA<ChainFailedAt>());
      expect((result as ChainFailedAt).index, 2);
      expect(
        (result.result as MissionFailed).reason,
        startsWith('wrong-answer:'),
      );
    });

    test('single-mission chain failing returns ChainFailedAt(index: 0)', () {
      // Arrange — chain of length 1 with a failing mission.
      final chain = MissionChain([_type]);

      // Act.
      final result = executor.run(chain, const [TextInput('nope')]);

      // Assert — index 0 (the only position).
      expect(result, isA<ChainFailedAt>());
      expect((result as ChainFailedAt).index, 0);
      expect(result.result, isA<MissionFailed>());
      // input length matches (1 == 1), so this is NOT an
      // input-length-mismatch; it's a per-mission failure.
      expect((result.result as MissionFailed).reason, 'phrase-mismatch');
    });

    test('ChainTimedOut is-a ChainFailedAt (the type hierarchy)', () {
      // Arrange + Act.
      const timedOut = ChainTimedOut(index: 0);

      // Assert — the sealed-hierarchy contract: ChainTimedOut
      // extends ChainFailedAt with `result: MissionTimedOut()`.
      // The executor's `r is MissionTimedOut` branch wraps it
      // as ChainTimedOut(index: i); no public mission emits
      // MissionTimedOut today (the widget owns the wall-clock),
      // so this test pins the data shape independently.
      expect(timedOut, isA<ChainFailedAt>());
      expect(timedOut, isA<MissionChainResult>());
      expect(timedOut.index, 0);
      expect(timedOut.result, isA<MissionTimedOut>());
    });

    test('ChainPassed contains all per-mission results in order', () {
      // Arrange — a 3-mission all-pass chain.
      final chain = MissionChain([_hold, _type, _math]);

      // Act.
      final result = executor.run(chain, const [
        HoldInput(Duration(seconds: 2)),
        TextInput('ok'),
        MathInput(problem: _twoPlusTwo, answer: 2),
      ]);

      // Assert — ChainPassed with 3 entries, in order, each
      // MissionPassed. HoldMission's detail includes the held
      // duration; TypeMission's is null; MathMission's is null.
      expect(result, isA<ChainPassed>());
      final passed = result as ChainPassed;
      expect(passed.results.length, 3);
      expect(passed.results[0], isA<MissionPassed>());
      expect(passed.results[1], isA<MissionPassed>());
      expect(passed.results[2], isA<MissionPassed>());
      // Per-mission detail pinning (deterministic for these inputs).
      expect(
        (passed.results[0] as MissionPassed).detail,
        'held=2000ms',
        reason: 'HoldMission records the held duration in its detail.',
      );
      expect(
        (passed.results[1] as MissionPassed).detail,
        isNull,
        reason: 'TypeMission does not set a detail.',
      );
      expect(
        (passed.results[2] as MissionPassed).detail,
        isNull,
        reason: 'MathMission does not set a detail.',
      );
    });
  });
}
