// Mission chain executor. Runs each mission in order; a
// `ChainFailedAt` aborts the rest; a `ChainTimedOut` is a
// special case of `ChainFailedAt` with a [MissionTimedOut]
// reason.
//
// Layer rules (per .claude/rules/lib-missions.md): the executor
// is a pure function — given a chain and a list of inputs, it
// returns a result. The widget owns the wall-clock; if a
// mission's wall-clock budget is exceeded, the widget passes
// the mission a "no answer" input (e.g., an empty `HoldInput`
// for Hold-tap) and the mission's `verify` returns
// [MissionTimedOut] via the input layer.

import 'package:doit/missions/chain.dart';
import 'package:doit/missions/mission_input.dart';
import 'package:doit/missions/mission_result.dart';

/// Pure chain executor. `inputs[i]` is fed to `chain[i]`; the
/// result is a [MissionChainResult]. The number of inputs MUST
/// equal the chain length; a mismatch is a developer error and
/// is reported as a `ChainFailedAt(0, MissionFailed(...))`.
class MissionChainExecutor {
  const MissionChainExecutor();

  MissionChainResult run(MissionChain chain, List<MissionInput> inputs) {
    if (chain.isEmpty) {
      return const ChainFailedAt(
        index: 0,
        result: MissionFailed('empty-chain'),
      );
    }
    if (inputs.length != chain.length) {
      return ChainFailedAt(
        index: 0,
        result: MissionFailed(
          'input-length-mismatch: ${inputs.length} != ${chain.length}',
        ),
      );
    }
    final results = <MissionResult>[];
    for (var i = 0; i < chain.length; i++) {
      final r = chain[i].verify(inputs[i]);
      results.add(r);
      if (r is MissionPassed) continue;
      if (r is MissionTimedOut) {
        return ChainTimedOut(index: i);
      }
      return ChainFailedAt(index: i, result: r);
    }
    return ChainPassed(results);
  }
}
