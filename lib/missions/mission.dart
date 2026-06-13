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
  });

  final int targetCount;
}

/// Type phrase: user types the expected phrase. Case-insensitive,
/// trim, exact match.
final class TypeMission extends Mission {
  const TypeMission({
    required super.id,
    required super.label,
    required super.timeout,
    required this.expectedPhrase,
  });

  final String expectedPhrase;
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
  }) : assert(rows > 0),
       assert(cols > 0),
       assert(
         (rows * cols) % 2 == 0,
         'Memory grid must have an even number of cells.',
       );

  final int rows;
  final int cols;
  final String theme;
}
