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

import 'package:doit/missions/mission.dart';

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

  /// Pure: generate a problem at the given [difficulty] using
  /// the supplied [rng]. No `Random()` at module init per
  /// `.claude/rules/lib-missions.md`.
  ///
  /// - easy: single-digit add / subtract, a, b ∈ [1, 9].
  /// - normal: two-digit add / subtract, a, b ∈ [10, 99].
  /// - hard: two-digit add / subtract OR two-digit × one-digit.
  factory MathProblem.next(MathDifficulty difficulty, math.Random rng) {
    final opRoll = rng.nextDouble();
    final op = switch (difficulty) {
      MathDifficulty.easy => opRoll < 0.5 ? MathOp.add : MathOp.subtract,
      MathDifficulty.normal => opRoll < 0.5 ? MathOp.add : MathOp.subtract,
      MathDifficulty.hard =>
        opRoll < 0.34
            ? MathOp.add
            : opRoll < 0.67
            ? MathOp.subtract
            : MathOp.multiply,
    };
    return switch (op) {
      MathOp.add => _add(difficulty, rng),
      MathOp.subtract => _subtract(difficulty, rng),
      MathOp.multiply => _multiply(difficulty, rng),
    };
  }

  static MathProblem _add(MathDifficulty d, math.Random rng) {
    final a = _pick(d, rng);
    final b = _pick(d, rng);
    return MathProblem(a: a, b: b, op: MathOp.add, answer: a + b);
  }

  static MathProblem _subtract(MathDifficulty d, math.Random rng) {
    // Subtraction problems never produce negative results.
    var a = _pick(d, rng);
    var b = _pick(d, rng);
    if (b > a) {
      final t = a;
      a = b;
      b = t;
    }
    return MathProblem(a: a, b: b, op: MathOp.subtract, answer: a - b);
  }

  static MathProblem _multiply(MathDifficulty d, math.Random rng) {
    // a, b are within the difficulty range. The result is
    // well-defined.
    final a = _pick(d, rng);
    final b = _pick(d, rng);
    return MathProblem(a: a, b: b, op: MathOp.multiply, answer: a * b);
  }

  static int _pick(MathDifficulty d, math.Random rng) => switch (d) {
    MathDifficulty.easy => 1 + rng.nextInt(9),
    MathDifficulty.normal => 10 + rng.nextInt(90),
    MathDifficulty.hard => 10 + rng.nextInt(90),
  };
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

/// A single memory card. The `symbol` is the human-readable
/// label (e.g., a shape name or emoji). The `pairId` ties two
/// cards together — same `pairId` means they match.
@immutable
final class MemoryCard {
  const MemoryCard({required this.symbol, required this.pairId});
  final String symbol;
  final int pairId;
}

/// Pure: generate a fresh deck for a memory game.
///
/// The deck has `rows * cols` cards and `rows * cols / 2`
/// distinct pairs. The `seed` parameter is required so widget
/// tests are deterministic.
class MemoryGame {
  const MemoryGame._();

  static const _themePool = <String, List<String>>{
    'shapes': ['▲', '●', '■', '◆', '★', '♥', '♦', '♣'],
    'animals': ['🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼'],
    'fruits': ['🍎', '🍌', '🍇', '🍓', '🍑', '🍒', '🥝', '🍍'],
  };

  /// Returns a list of [MemoryCard]s, shuffled deterministically
  /// from the given [seed]. The list length is `rows * cols` and
  /// the pair count is `rows * cols / 2`.
  static List<MemoryCard> generate({
    required int rows,
    required int cols,
    required String theme,
    required int seed,
  }) {
    assert(rows > 0 && cols > 0);
    assert((rows * cols) % 2 == 0);
    final pool = _themePool[theme] ?? _themePool['shapes']!;
    final pairCount = (rows * cols) ~/ 2;
    final cards = <MemoryCard>[];
    for (var i = 0; i < pairCount; i++) {
      final symbol = pool[i % pool.length];
      cards.add(MemoryCard(symbol: symbol, pairId: i));
      cards.add(MemoryCard(symbol: symbol, pairId: i));
    }
    cards.shuffle(math.Random(seed));
    return List<MemoryCard>.unmodifiable(cards);
  }
}
