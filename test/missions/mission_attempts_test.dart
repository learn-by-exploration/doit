// Tests for the shared wrong-attempt bookkeeping used by
// missions that have a "user typed something wrong" notion
// (Math, Type). Per WF-030, every mission that tracks wrong
// attempts uses the same counter, the same nudge copy, and
// the same auto-fail threshold — this is the single source
// of truth.

import 'package:doit/missions/mission_attempts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kMissionMaxWrongAttempts', () {
    test('is 3 — the 4th wrong auto-fails the mission', () {
      expect(kMissionMaxWrongAttempts, 3);
    });
  });

  group('MissionWrongAttempts', () {
    test('starts at zero wrong with full budget remaining', () {
      final a = MissionWrongAttempts();
      expect(a.wrongCount, 0);
      expect(a.remaining, 3);
      expect(a.budgetExhausted, isFalse);
    });

    test('first wrong records 1 with 2 remaining', () {
      final a = MissionWrongAttempts();
      final autoFail = a.recordWrong();
      expect(autoFail, isFalse);
      expect(a.wrongCount, 1);
      expect(a.remaining, 2);
      expect(a.budgetExhausted, isFalse);
    });

    test('third wrong exhausts the budget and auto-fails', () {
      final a = MissionWrongAttempts();
      a.recordWrong();
      a.recordWrong();
      final autoFail = a.recordWrong();
      expect(
        autoFail,
        isTrue,
        reason: '3rd wrong auto-fails per SYS-011 (no 4th attempt)',
      );
      expect(a.wrongCount, 3);
      expect(a.remaining, 0);
      expect(a.budgetExhausted, isTrue);
    });

    test('errorLabel returns null before any wrong is recorded', () {
      final a = MissionWrongAttempts();
      expect(a.errorLabel(), isNull, reason: 'no wrong yet, no label');
    });

    test(
      'errorLabel renders attempts-left copy after each non-final wrong',
      () {
        final a = MissionWrongAttempts();
        a.recordWrong();
        expect(a.errorLabel(), 'Wrong. 2 attempt(s) left.');
        a.recordWrong();
        expect(a.errorLabel(), 'Wrong. 1 attempt(s) left.');
      },
    );

    test('errorLabel renders the take-a-break nudge on the final wrong', () {
      final a = MissionWrongAttempts();
      a.recordWrong();
      a.recordWrong();
      a.recordWrong();
      // Caller normally pops after the 3rd wrong (recordWrong
      // returned true), but if they read the label anyway,
      // it is the take-a-break copy per SYS-011.
      expect(a.errorLabel(), missionTakeBreakNudge);
    });

    test('honors a custom maxWrong', () {
      final a = MissionWrongAttempts(maxWrong: 1);
      expect(a.remaining, 1);
      expect(
        a.recordWrong(),
        isTrue,
        reason: 'with maxWrong=1, the 1st wrong auto-fails',
      );
    });
  });

  group('missionTakeBreakNudge', () {
    test('is non-empty and ends with a period', () {
      expect(missionTakeBreakNudge, isNotEmpty);
      expect(missionTakeBreakNudge, endsWith('.'));
    });
  });
}
