// Habit proof mode — sealed Soft / Strong / Auto.
//
// Each habit declares its proof mode at creation. The mode is
// the answer to "how does the user prove they did this habit
// today?" See docs/v_model/requirements.md § SYS-004 and
// docs/v_model/mission_catalog.md.

import 'package:common_games/missions/chain.dart';
import 'package:common_games/missions/mission.dart';
import 'package:meta/meta.dart';

/// How the user proves they completed a habit on a given day.
///
/// Soft: a tap on the home screen. No sensor input. Default
/// for routine, low-friction habits ("drink water").
///
/// Strong: a Mission chain. The user must complete N missions
/// in order; a failure in mission N forces a retry of N. See
/// SYS-031 (max 5 min total chain timeout).
///
/// Auto: the app proves it. Reserved for v0.2 (anchor detection
/// from calendar / contact events). Phase 1 ships the type so
/// habits can be persisted with `Auto`; the engine is a stub
/// that defers to v0.2.
@immutable
sealed class HabitProofMode {
  const HabitProofMode();
}

/// Soft proof: a single tap. No chain.
final class SoftProof extends HabitProofMode {
  const SoftProof();
}

/// Strong proof: complete the given mission chain.
final class StrongProof extends HabitProofMode {
  const StrongProof(this.chain);

  /// The mission chain. Must be non-empty and respect
  /// `totalTimeout ≤ Duration(minutes: 5)` (SYS-031).
  final MissionChain chain;
}

/// Auto proof: the app determines completion. Phase 1 stub;
/// the v0.2 anchor detector fills this in.
final class AutoProof extends HabitProofMode {
  const AutoProof();

  @override
  bool operator ==(Object other) => other is AutoProof;

  @override
  int get hashCode => (AutoProof).hashCode;
}

@immutable
sealed class HabitProofModeException implements Exception {
  const HabitProofModeException(this.message);
  final String message;

  @override
  String toString() => 'HabitProofModeException: $message';
}

/// Thrown by `validate` when a Strong chain is empty or its
/// total timeout exceeds SYS-031 (5 min).
final class StrongChainInvalid extends HabitProofModeException {
  const StrongChainInvalid(super.message);
}

/// Thrown by `validate` when an Auto proof is created. Phase 1
/// rejects Auto explicitly; v0.2 enables it.
final class AutoProofNotSupported extends HabitProofModeException {
  const AutoProofNotSupported()
    : super('Auto proof is not supported in v0.1; it lands in v0.2.');
}

/// Validates a proof mode. Strong mode requires a non-empty
/// chain with `totalTimeout ≤ 5 min` (SYS-031). Auto is
/// rejected in v0.1.
void validateProofMode(HabitProofMode mode) {
  switch (mode) {
    case SoftProof():
      return;
    case StrongProof(:final chain):
      if (chain.isEmpty) {
        throw const StrongChainInvalid(
          'Strong proof requires a non-empty mission chain.',
        );
      }
      if (chain.totalTimeout > const Duration(minutes: 5)) {
        throw StrongChainInvalid(
          'Strong chain total timeout ${chain.totalTimeout} '
          'exceeds the 5-minute cap (SYS-031).',
        );
      }
      return;
    case AutoProof():
      throw const AutoProofNotSupported();
  }
}

/// Convenience: the empty list of [Mission] for callers that
/// need a Soft / placeholder.
const List<Mission> noMissions = <Mission>[];
