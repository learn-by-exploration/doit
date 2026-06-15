// Missions — sealed data type.
//
// Phase 1 ships the data shape and the chain container; the
// execution engine (verify(), pure functions, sensor adapters)
// lands in Phase 3 per docs/v_model/implementation_status.md.
//
// Why a stub now: a Habit in Strong mode carries a `missionChain`.
// To stay type-safe without a circular import, the chain type
// lives next to Habit in lib/missions/. Phase 3 adds the
// `verify()` method and the sensor adapters without changing
// the data shape.

import 'package:meta/meta.dart';

import 'package:doit/missions/mission_input.dart';
import 'package:doit/missions/mission_result.dart';

/// A sealed mission. The 5 v0.1 types are exhaustive; adding a
/// v0.2 type (Barcode, Photo) means adding a new subclass here.
@immutable
sealed class Mission {
  const Mission({required this.id, required this.label, required this.timeout});

  /// Stable identifier for this mission within the habit's
  /// chain. Two habits may carry the same id; the chain
  /// resolves the index.
  final String id;

  /// User-facing label. Shown in the mission picker and the
  /// mission UI. Brand-voice: lead with the action.
  final String label;

  /// Per-mission timeout. The chain executor pauses on
  /// background; this is wall-clock in the foreground.
  final Duration timeout;

  /// Pure verification. The implementation pattern-matches on
  /// [input] and returns a [MissionResult]. A wrong-typed
  /// input for this mission returns a [MissionFailed]
  /// (`reason: 'input-mismatch'`).
  MissionResult verify(MissionInput input);
}

/// Shake-N: user shakes the phone N times within spacing
/// thresholds. See SYS-008 for defaults (14.0 m/s², 250 ms,
/// 1500 ms).
final class ShakeMission extends Mission {
  const ShakeMission({
    required super.id,
    required super.label,
    required super.timeout,
    required this.targetCount,
    this.magnitudeThreshold = 14.0,
    this.minSpacingMs = 250,
    this.maxSpacingMs = 1500,
  });

  final int targetCount;
  final double magnitudeThreshold;
  final int minSpacingMs;
  final int maxSpacingMs;

  @override
  MissionResult verify(MissionInput input) {
    if (input is! ShakeInput) {
      return const MissionFailed('input-mismatch');
    }
    final count = ShakeMission.countShakes(
      input.samples,
      magnitudeThreshold: magnitudeThreshold,
      minSpacingMs: minSpacingMs,
      maxSpacingMs: maxSpacingMs,
    );
    if (count >= targetCount) {
      return MissionPassed(detail: 'shakes=$count target=$targetCount');
    }
    return MissionFailed('not-enough-shakes: $count < $targetCount');
  }

  /// Pure: count the valid shake events in a sample list.
  /// Exposed as a static method so unit tests and the chain
  /// executor can call it directly.
  static int countShakes(
    List<ShakeSample> samples, {
    required double magnitudeThreshold,
    required int minSpacingMs,
    required int maxSpacingMs,
  }) {
    var count = 0;
    DateTime? lastShakeAt;
    for (final s in samples) {
      if (s.magnitude < magnitudeThreshold) continue;
      if (lastShakeAt == null) {
        count = 1;
        lastShakeAt = s.at;
        continue;
      }
      final dt = s.at.difference(lastShakeAt).inMilliseconds;
      if (dt < minSpacingMs) continue;
      if (dt > maxSpacingMs) {
        count = 1;
        lastShakeAt = s.at;
        continue;
      }
      count++;
      lastShakeAt = s.at;
    }
    return count;
  }
}

/// Type phrase: user types the expected phrase. Case-insensitive,
/// trim, exact match.
final class TypeMission extends Mission {
  const TypeMission({
    required super.id,
    required super.label,
    required super.timeout,
    required this.expectedPhrase,
    this.caseSensitive = false,
    this.trimWhitespace = true,
    this.ignorePunctuation = true,
  });

  final String expectedPhrase;
  final bool caseSensitive;
  final bool trimWhitespace;
  final bool ignorePunctuation;

  @override
  MissionResult verify(MissionInput input) {
    if (input is! TextInput) {
      return const MissionFailed('input-mismatch');
    }
    if (input.typed.isEmpty) {
      return const MissionFailed('empty-input');
    }
    if (_normalize(input.typed) == _normalize(expectedPhrase)) {
      return const MissionPassed();
    }
    return const MissionFailed('phrase-mismatch');
  }

  String _normalize(String s) {
    var out = s;
    if (trimWhitespace) out = out.trim();
    if (!caseSensitive) out = out.toLowerCase();
    if (ignorePunctuation) {
      out = out.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '');
    }
    return out;
  }
}

/// Hold-tap: user holds a button for a continuous duration.
final class HoldMission extends Mission {
  const HoldMission({
    required super.id,
    required super.label,
    required super.timeout,
    required this.holdDuration,
  });

  final Duration holdDuration;

  @override
  MissionResult verify(MissionInput input) {
    if (input is! HoldInput) {
      return const MissionFailed('input-mismatch');
    }
    if (input.duration >= holdDuration) {
      return MissionPassed(detail: 'held=${input.duration.inMilliseconds}ms');
    }
    return MissionFailed(
      'not-held-long-enough: ${input.duration.inMilliseconds}ms < '
      '${holdDuration.inMilliseconds}ms',
    );
  }
}

/// Math: user solves a generated problem. Difficulty is a
/// classification, not a numeric knob.
enum MathDifficulty { easy, normal, hard }

final class MathMission extends Mission {
  const MathMission({
    required super.id,
    required super.label,
    required super.timeout,
    required this.difficulty,
  });

  final MathDifficulty difficulty;

  @override
  MissionResult verify(MissionInput input) {
    if (input is! MathInput) {
      return const MissionFailed('input-mismatch');
    }
    if (input.answer == input.problem.answer) {
      return const MissionPassed();
    }
    return MissionFailed(
      'wrong-answer: ${input.answer} != ${input.problem.answer}',
    );
  }
}

/// Memory: user matches pairs on a grid. Rows × cols must be
/// even (the grid is 2 pairs per row minimum).
final class MemoryMission extends Mission {
  const MemoryMission({
    required super.id,
    required super.label,
    required super.timeout,
    required this.rows,
    required this.cols,
    required this.theme,
    this.timeLimit = const Duration(seconds: 60),
  }) : assert(rows > 0),
       assert(cols > 0),
       assert(
         (rows * cols) % 2 == 0,
         'Memory grid must have an even number of cells.',
       );

  final int rows;
  final int cols;
  final String theme;
  final Duration timeLimit;

  @override
  MissionResult verify(MissionInput input) {
    if (input is! MemoryInput) {
      return const MissionFailed('input-mismatch');
    }
    final totalPairs = (rows * cols) ~/ 2;
    if (input.elapsed > timeLimit) {
      return const MissionFailed('time-limit-exceeded');
    }
    if (input.matchedPairs.length < totalPairs) {
      return MissionFailed(
        'not-all-pairs: ${input.matchedPairs.length}/$totalPairs',
      );
    }
    if (_hasDuplicateCard(input.matchedPairs)) {
      return const MissionFailed('duplicate-flip');
    }
    return const MissionPassed();
  }

  static bool _hasDuplicateCard(List<MemoryPair> pairs) {
    final seen = <int>{};
    for (final p in pairs) {
      if (!seen.add(p.a)) return true;
      if (!seen.add(p.b)) return true;
    }
    return false;
  }
}
