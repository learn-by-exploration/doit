// Shake detector — pure-Dart adapter.
//
// Layer rules (per .claude/rules/lib-missions.md): this is the
// ONLY file in lib/missions/ that talks to the platform
// accelerometer. It converts a stream of accelerometer samples
// into [ShakeEvent]s for the model layer.
//
// The v0.1 implementation accepts an injected
// [Stream<ShakeSample>] (the platform side wraps `sensors_plus`
// and pushes samples through). The detector's pure logic lives
// in [ShakeMission.countShakes] in `mission.dart` — this file
// is a thin stream→event adapter on top of that.
//
// Defaults (SYS-008): magnitudeThreshold=14.0, minSpacingMs=250,
// maxSpacingMs=1500.

import 'dart:async';

import 'package:common_games/missions/mission_input.dart';

/// Emitted every time a new shake event is detected. The
/// `countSinceFirst` is a monotonically increasing counter
/// (since the stream started listening).
class ShakeEvent {
  const ShakeEvent({required this.at, required this.countSinceFirst});
  final DateTime at;
  final int countSinceFirst;
}

class ShakeDetector {
  ShakeDetector({
    required this.samples,
    this.magnitudeThreshold = 14.0,
    this.minSpacingMs = 250,
    this.maxSpacingMs = 1500,
  });

  final Stream<ShakeSample> samples;
  final double magnitudeThreshold;
  final int minSpacingMs;
  final int maxSpacingMs;

  /// Returns a stream of [ShakeEvent]s. The stream is single-
  /// subscription; cancelling the subscription cancels the
  /// listener.
  Stream<ShakeEvent> events() {
    final out = StreamController<ShakeEvent>();
    var count = 0;
    DateTime? lastShakeAt;
    samples.listen(
      (s) {
        if (s.magnitude < magnitudeThreshold) return;
        if (lastShakeAt == null) {
          count = 1;
          lastShakeAt = s.at;
          out.add(ShakeEvent(at: s.at, countSinceFirst: count));
          return;
        }
        final dt = s.at.difference(lastShakeAt!).inMilliseconds;
        if (dt < minSpacingMs) return;
        if (dt > maxSpacingMs) {
          count = 1;
          lastShakeAt = s.at;
          out.add(ShakeEvent(at: s.at, countSinceFirst: count));
          return;
        }
        count++;
        lastShakeAt = s.at;
        out.add(ShakeEvent(at: s.at, countSinceFirst: count));
      },
      onError: out.addError,
      onDone: out.close,
    );
    return out.stream;
  }

  /// Convenience: collect the full sample list (capped at
  /// [maxSamples]) and return a [ShakeInput] ready for the
  /// chain executor. The widget layer uses this when the chain
  /// completes.
  static Future<ShakeInput> collect({
    required Stream<ShakeSample> samples,
    int maxSamples = 4096,
  }) async {
    final list = <ShakeSample>[];
    await for (final s in samples) {
      list.add(s);
      if (list.length >= maxSamples) break;
    }
    return ShakeInput(list);
  }
}
