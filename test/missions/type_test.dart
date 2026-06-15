// Tests for [TypeMission.verify].

import 'package:doit/missions/mission.dart';
import 'package:doit/missions/mission_input.dart';
import 'package:doit/missions/mission_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mission = TypeMission(
    id: 'm1',
    label: 'Type',
    timeout: Duration(seconds: 30),
    expectedPhrase: 'I am present',
  );

  group('TypeMission.verify', () {
    test('exact match passes', () {
      final result = mission.verify(const TextInput('I am present'));
      expect(result, isA<MissionPassed>());
    });

    test('case mismatch passes (caseSensitive default false)', () {
      final result = mission.verify(const TextInput('i am PRESENT'));
      expect(result, isA<MissionPassed>());
    });

    test('trailing whitespace is trimmed (trimWhitespace default true)', () {
      final result = mission.verify(const TextInput('  I am present  '));
      expect(result, isA<MissionPassed>());
    });

    test('punctuation is stripped (ignorePunctuation default true)', () {
      final result = mission.verify(const TextInput('I, am present!'));
      expect(result, isA<MissionPassed>());
    });

    test('mismatch fails', () {
      final result = mission.verify(const TextInput('I am here'));
      expect(result, isA<MissionFailed>());
      expect((result as MissionFailed).reason, 'phrase-mismatch');
    });

    test('empty input fails with empty-input', () {
      final result = mission.verify(const TextInput(''));
      expect(result, isA<MissionFailed>());
      expect((result as MissionFailed).reason, 'empty-input');
    });

    test('input-mismatch when input is not TextInput', () {
      const hold = HoldMission(
        id: 'm2',
        label: 'Hold',
        timeout: Duration(seconds: 10),
        holdDuration: Duration(seconds: 2),
      );
      final result = hold.verify(const TextInput('hi'));
      expect(result, isA<MissionFailed>());
      expect((result as MissionFailed).reason, 'input-mismatch');
    });

    test('caseSensitive=true makes case mismatch fail', () {
      const m = TypeMission(
        id: 'm1',
        label: 'Type',
        timeout: Duration(seconds: 30),
        expectedPhrase: 'I am present',
        caseSensitive: true,
      );
      final result = m.verify(const TextInput('i am present'));
      expect(result, isA<MissionFailed>());
    });
  });
}
