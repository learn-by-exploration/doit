// Pause service — single API for setting/clearing the
// `pausedUntil` timestamp on habits and people.
//
// Per WF-027. A paused habit does not get reminders; a paused
// period does not break the streak (the calculator skips dates
// in the pause window). Pausing is the user's escape hatch for
// vacations, illness, schedule changes, or a "this isn't
// working for me right now" moment.
//
// The service is a thin wrapper over the repositories: it
// keeps the pause-state shape in one place so the home screen
// and the settings page can both call it without re-deriving
// the "is paused?" logic.
//
// Per .claude/rules/lib-services.md:
//   - One singleton per process.
//   - `Completer<void> _ready`.
//   - `init()` is idempotent (a no-op for this service — it
//     holds no state of its own; the repositories own the
//     state).
//   - Public methods are async.

import 'dart:async';

import 'package:common_games/habits/habit.dart';
import 'package:common_games/people/person.dart';
import 'package:common_games/services/habit_repository.dart';
import 'package:common_games/services/person_repository.dart';

class PauseService {
  PauseService._();

  static final PauseService instance = PauseService._();

  // Pause is pure read/write over the repositories; no async
  // init needed. The `_ready` Completer is kept so future
  // additions (e.g., a paused-until cache) can hook here
  // without changing the public surface.
  Future<void> get _ready => _readyCompleter.future;
  final Completer<void> _readyCompleter = Completer<void>();

  /// Pause a habit until [until] (inclusive). A null
  /// [until] is rejected; call [resume] to clear.
  ///
  /// Re-saves the habit through [HabitRepository] (so the
  /// v0.1 `insertOnConflictUpdate` path is used). The
  /// reminder layer reads `pausedUntil` directly from the
  /// row, so the new state is effective on the next
  /// `listActive` / `scheduleHabit` call.
  Future<void> pauseHabit(Habit habit, DateTime until) async {
    await _ready;
    final updated = habit.copyWith(pausedUntil: until);
    await HabitRepository.instance.save(updated);
  }

  /// Clear the pause state on a habit. The next call to
  /// `nextOccurrence` will fire reminders as usual.
  Future<void> resumeHabit(Habit habit) async {
    await _ready;
    final updated = habit.copyWith(clearPausedUntil: true);
    await HabitRepository.instance.save(updated);
  }

  /// Pause a person (cadence habit) until [until]. The cadence
  /// streak is preserved across the pause window.
  Future<void> pausePerson(Person person, DateTime until) async {
    await _ready;
    final updated = person.copyWith(pausedUntil: until);
    await PersonRepository.instance.save(updated);
  }

  /// Clear the pause state on a person.
  Future<void> resumePerson(Person person) async {
    await _ready;
    final updated = person.copyWith(clearPausedUntil: true);
    await PersonRepository.instance.save(updated);
  }

  /// Sugar: pause for a [duration] from [from]. Default `from`
  /// is "now". Used by the home-screen "Pause 1 day" /
  /// "Pause 1 week" quick-actions.
  Future<void> pauseHabitFor(
    Habit habit,
    Duration duration, {
    DateTime? from,
  }) async {
    final start = from ?? DateTime.now();
    await pauseHabit(habit, start.add(duration));
  }

  /// Sugar: pause a person for a [duration] from [from].
  Future<void> pausePersonFor(
    Person person,
    Duration duration, {
    DateTime? from,
  }) async {
    final start = from ?? DateTime.now();
    await pausePerson(person, start.add(duration));
  }
}
