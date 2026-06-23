// Shared wrong-attempt bookkeeping for missions that have a
// "user typed something wrong" notion (Math, Type).
//
// Per ADR-016 and the 30-phase plan Phase 11b (WF-030
// uniform 3-wrong take-a-break), every mission that tracks
// wrong attempts uses the same counter, the same nudge
// copy, and the same auto-fail threshold so the user
// never sees a behavior gap between mission kinds.
//
// Missions that don't have a "wrong attempt" concept
// (Shake, Hold, Memory — they time-out instead of fail
// per-attempt) do not use this module.
//
// This is pure Dart (no Flutter) so it can be unit-tested
// without a harness.

/// The number of WRONG attempts the user is allowed before
/// the mission auto-fails. The (n+1)-th wrong attempt is
/// NOT allowed — the mission pops with `null` on the
/// n-th wrong. So with this set to 3, the 3rd wrong pops
/// the screen and the user is told to take a break.
const int kMissionMaxWrongAttempts = 3;

/// Sentinel copy for the inline error label after a wrong
/// attempt. Missions render this with the attempts-left
/// count appended (`"Wrong. 2 attempt(s) left."`).
String missionWrongAttemptLabel(int attemptsRemaining) {
  return 'Wrong. $attemptsRemaining attempt(s) left.';
}

/// Copy for the one-shot nudge shown alongside the 3rd
/// (final) wrong attempt, surfaced as a `SnackBar` so it
/// doesn't disrupt the screen layout mid-input.
const String missionTakeBreakNudge = 'Take a break. The mission will end.';

/// State container for a single mission-screen instance.
/// Holds the wrong-attempt count; pure Dart so the screens
/// can build it in `initState` and forget about it.
class MissionWrongAttempts {
  MissionWrongAttempts({this.maxWrong = kMissionMaxWrongAttempts});

  /// Maximum number of wrong attempts before auto-fail.
  /// Defaults to [kMissionMaxWrongAttempts]; tests can pass a
  /// smaller value to exercise the auto-fail path quickly.
  final int maxWrong;
  int _wrongCount = 0;

  /// The number of wrong attempts recorded so far.
  int get wrongCount => _wrongCount;

  /// The number of wrong attempts still allowed before the
  /// auto-fail fires. Becomes 0 immediately before auto-fail.
  int get remaining => maxWrong - _wrongCount;

  /// Has the user already burned the budget (used to
  /// gate the take-a-break nudge)?
  bool get budgetExhausted => _wrongCount >= maxWrong;

  /// Record a wrong attempt. Returns `true` if the caller
  /// should auto-fail (the n-th wrong, with n =
  /// `kMissionMaxWrongAttempts`). Returns `false` if more
  /// attempts remain.
  bool recordWrong() {
    _wrongCount += 1;
    return _wrongCount >= maxWrong;
  }

  /// Render the inline error label for the current state.
  /// Returns `null` when no wrong attempt has been recorded
  /// yet (the screen's initial state). On every wrong
  /// attempt (including the final one) returns a label —
  /// `missionWrongAttemptLabel` for the first (n-1) and
  /// `missionTakeBreakNudge` for the n-th, per SYS-011.
  /// Callers that auto-fail after `recordWrong() == true`
  /// do not need to read this on the n-th attempt, but the
  /// label is still computed so widget tests can pin the
  /// take-a-break copy.
  String? errorLabel() {
    if (_wrongCount == 0) return null;
    if (_wrongCount >= maxWrong) return missionTakeBreakNudge;
    return missionWrongAttemptLabel(remaining);
  }
}
