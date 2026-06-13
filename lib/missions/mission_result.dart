// Mission verification results. Pure Dart, no Flutter.
//
// Per docs/v_model/mission_catalog.md § Common contract:
//   - MissionPassed: the user satisfied the mission.
//   - MissionFailed(reason): the user attempted and failed.
//   - MissionTimedOut: the user ran out of wall-clock time.
//
// The chain executor (`lib/missions/chain_executor.dart`)
// pattern-matches on these to decide whether to advance to
// the next mission or abort.

import 'package:meta/meta.dart';

@immutable
sealed class MissionResult {
  const MissionResult();
}

final class MissionPassed extends MissionResult {
  const MissionPassed({this.detail});
  final String? detail;
}

final class MissionFailed extends MissionResult {
  const MissionFailed(this.reason);
  final String reason;
}

final class MissionTimedOut extends MissionResult {
  const MissionTimedOut();
}

/// Chain-level result. The executor returns one of these after
/// running the entire chain. A `ChainFailedAt` aborts the rest
/// of the chain; a `ChainTimedOut` is a special case of
/// `ChainFailedAt` with `result` set to a [MissionTimedOut].
@immutable
sealed class MissionChainResult {
  const MissionChainResult();
}

final class ChainPassed extends MissionChainResult {
  const ChainPassed(this.results);
  final List<MissionResult> results;
}

final class ChainFailedAt extends MissionChainResult {
  const ChainFailedAt({required this.index, required this.result});
  final int index;
  final MissionResult result;
}

/// Convenience: a chain that has run out of wall-clock time. The
/// mission at [index] did not complete in the time it was given
/// (per-mission `timeout`).
final class ChainTimedOut extends ChainFailedAt {
  const ChainTimedOut({required super.index})
    : super(result: const MissionTimedOut());
}
