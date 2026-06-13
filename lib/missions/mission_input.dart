// Mission inputs — the raw data the user provided for a given
// mission. Pure Dart (no Flutter, no sensors_plus). The
// platform-side adapter (lib/missions/shake_detector.dart)
// converts a sensor stream into [ShakeInput].
//
// Layer rules (per .claude/rules/lib-missions.md): pure Dart,
// no DateTime.now() in the model layer. The caller passes the
// current time in the [ShakeInput] (so a unit test can pass a
// frozen clock).

import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Raw input for a mission. The chain executor pattern-matches
/// on the sealed shape and dispatches to the right
/// [Mission.verify] implementation.
@immutable
sealed class MissionInput {
  const MissionInput();
}

/// Accelerometer samples for a Shake-N mission. `at` is the
/// wall-clock timestamp of the sample; the model is told "now"
/// via this so a test can pass a fixed `at` for every sample.
@immutable
final class ShakeInput extends MissionInput {
  const ShakeInput(this.samples);
  final List<ShakeSample> samples;
}

@immutable
final class ShakeSample {
  const ShakeSample({
    required this.x,
    required this.y,
    required this.z,
    required this.at,
  });
  final double x;
  final double y;
  final double z;
  final DateTime at;

  /// Euclidean magnitude, sqrt(x² + y² + z²). The threshold
  /// for "is this a shake?" is a magnitude in m/s², not a
  /// squared magnitude — `countShakes` compares this value
  /// directly against `magnitudeThreshold`.
  double get magnitude => math.sqrt(x * x + y * y + z * z);
}

/// Typed text for a Type-phrase mission.
@immutable
final class TextInput extends MissionInput {
  const TextInput(this.typed);
  final String typed;
}

/// Hold-tap duration input.
@immutable
final class HoldInput extends MissionInput {
  const HoldInput(this.duration);
  final Duration duration;
}

/// Math problem + the user's answer.
@immutable
final class MathInput extends MissionInput {
  const MathInput({required this.problem, required this.answer});
  final MathProblem problem;
  final int answer;
}

/// A pre-generated math problem. The chain executor receives
/// the problem from the widget (which generated it on mount)
/// and the answer from the user's input.
@immutable
final class MathProblem {
  const MathProblem({
    required this.a,
    required this.b,
    required this.op,
    required this.answer,
  });
  final int a;
  final int b;
  final MathOp op;
  final int answer;
}

enum MathOp { add, subtract, multiply }

/// Memory game state. `pairs` is the list of (row, col) indices
/// the user has matched so far, in order; `elapsed` is the
/// wall-clock duration since the game started.
@immutable
final class MemoryInput extends MissionInput {
  const MemoryInput({required this.matchedPairs, required this.elapsed});
  final List<MemoryPair> matchedPairs;
  final Duration elapsed;
}

/// One matched pair. `a` and `b` are 0-based grid indices.
@immutable
final class MemoryPair {
  const MemoryPair(this.a, this.b);
  final int a;
  final int b;
}
