// Tests for [ShakeMission.verify] (with [ShakeMission.countShakes])
// and the [ShakeDetector] stream adapter.

import 'dart:async';

import 'package:common_games/missions/mission.dart';
import 'package:common_games/missions/mission_input.dart';
import 'package:common_games/missions/mission_result.dart';
import 'package:common_games/missions/shake_detector.dart';
import 'package:flutter_test/flutter_test.dart';

ShakeSample _s({required int ms, double x = 0, double y = 0, double z = 0}) {
  // ms since epoch 2026-01-01
  final at = DateTime(2026).add(Duration(milliseconds: ms));
  return ShakeSample(x: x, y: y, z: z, at: at);
}

void main() {
  group('ShakeMission.countShakes', () {
    test('steady pace of N shakes → count = N', () {
      final samples = [
        for (var i = 0; i < 14; i++)
          _s(ms: i * 400, x: 20), // 400ms spacing, well within [250, 1500]
      ];
      final n = ShakeMission.countShakes(
        samples,
        magnitudeThreshold: 14.0,
        minSpacingMs: 250,
        maxSpacingMs: 1500,
      );
      expect(n, 14);
    });

    test('faster than minSpacing → counted once', () {
      // Two samples 100ms apart with magnitude 20 — second is
      // ignored.
      final samples = [_s(ms: 0, x: 20), _s(ms: 100, x: 20)];
      final n = ShakeMission.countShakes(
        samples,
        magnitudeThreshold: 14.0,
        minSpacingMs: 250,
        maxSpacingMs: 1500,
      );
      expect(n, 1);
    });

    test('slower than maxSpacing → reset to 1', () {
      // Two samples 2000ms apart with magnitude 20 — the
      // second resets the count to 1.
      final samples = [_s(ms: 0, x: 20), _s(ms: 2000, x: 20)];
      final n = ShakeMission.countShakes(
        samples,
        magnitudeThreshold: 14.0,
        minSpacingMs: 250,
        maxSpacingMs: 1500,
      );
      expect(n, 1);
    });

    test('magnitude below threshold is ignored', () {
      final samples = [for (var i = 0; i < 10; i++) _s(ms: i * 400, x: 5)];
      final n = ShakeMission.countShakes(
        samples,
        magnitudeThreshold: 14.0,
        minSpacingMs: 250,
        maxSpacingMs: 1500,
      );
      expect(n, 0);
    });

    test('one big jiggle does not advance the count', () {
      // A single sample above threshold → count = 1, not 2.
      // Holding the phone still with a one-off jiggle should
      // not produce a streak of shakes.
      final samples = [_s(ms: 0, x: 20), _s(ms: 0)];
      final n = ShakeMission.countShakes(
        samples,
        magnitudeThreshold: 14.0,
        minSpacingMs: 250,
        maxSpacingMs: 1500,
      );
      expect(n, 1);
    });
  });

  group('ShakeMission.verify', () {
    test('passes when count >= targetCount', () {
      const mission = ShakeMission(
        id: 'm1',
        label: 'Shake',
        timeout: Duration(seconds: 30),
        targetCount: 3,
      );
      final samples = [for (var i = 0; i < 3; i++) _s(ms: i * 400, x: 20)];
      final result = mission.verify(ShakeInput(samples));
      expect(result, isA<MissionPassed>());
    });

    test('fails when count < targetCount', () {
      const mission = ShakeMission(
        id: 'm1',
        label: 'Shake',
        timeout: Duration(seconds: 30),
        targetCount: 5,
      );
      final samples = [for (var i = 0; i < 2; i++) _s(ms: i * 400, x: 20)];
      final result = mission.verify(ShakeInput(samples));
      expect(result, isA<MissionFailed>());
    });

    test('input-mismatch when input is not ShakeInput', () {
      const mission = ShakeMission(
        id: 'm1',
        label: 'Shake',
        timeout: Duration(seconds: 30),
        targetCount: 3,
      );
      final result = mission.verify(const TextInput('hi'));
      expect(result, isA<MissionFailed>());
      expect((result as MissionFailed).reason, 'input-mismatch');
    });
  });

  group('ShakeDetector', () {
    test('emits one ShakeEvent per detected shake', () async {
      final ctrl = StreamController<ShakeSample>();
      final detector = ShakeDetector(samples: ctrl.stream);
      final events = <ShakeEvent>[];
      final sub = detector.events().listen(events.add);

      ctrl.add(_s(ms: 0, x: 20));
      ctrl.add(_s(ms: 100, x: 20)); // ignored (too close)
      ctrl.add(_s(ms: 500, x: 20)); // valid
      ctrl.add(_s(ms: 900, x: 20)); // valid
      await Future<void>.delayed(Duration.zero);
      await ctrl.close();
      await sub.cancel();
      expect(events.length, 3);
      expect(events.last.countSinceFirst, 3);
    });

    test('emits nothing when stream is empty', () async {
      final detector = ShakeDetector(
        samples: const Stream<ShakeSample>.empty(),
      );
      final events = await detector.events().toList();
      expect(events, isEmpty);
    });

    test('collect() returns a ShakeInput with all samples', () async {
      final stream = Stream<ShakeSample>.fromIterable([
        _s(ms: 0, x: 20),
        _s(ms: 400, y: 20),
        _s(ms: 800, z: 20),
      ]);
      final input = await ShakeDetector.collect(samples: stream);
      expect(input.samples.length, 3);
    });
  });
}
