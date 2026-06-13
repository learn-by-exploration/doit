// Tests for [HoldMission.verify].

import 'package:common_games/missions/mission.dart';
import 'package:common_games/missions/mission_input.dart';
import 'package:common_games/missions/mission_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mission = HoldMission(
    id: 'm1',
    label: 'Hold',
    timeout: Duration(seconds: 30),
    holdDuration: Duration(seconds: 2),
  );

  group('HoldMission.verify', () {
    test('passes when duration >= holdDuration', () {
      final result = mission.verify(const HoldInput(Duration(seconds: 2)));
      expect(result, isA<MissionPassed>());
    });

    test('passes when duration > holdDuration', () {
      final result = mission.verify(const HoldInput(Duration(seconds: 5)));
      expect(result, isA<MissionPassed>());
    });

    test('fails when duration < holdDuration', () {
      final result = mission.verify(
        const HoldInput(Duration(milliseconds: 1999)),
      );
      expect(result, isA<MissionFailed>());
    });

    test('input-mismatch when input is not HoldInput', () {
      final result = mission.verify(const TextInput('hi'));
      expect(result, isA<MissionFailed>());
      expect((result as MissionFailed).reason, 'input-mismatch');
    });
  });
}
