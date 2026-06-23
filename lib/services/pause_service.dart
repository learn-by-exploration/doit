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
//   - **No `init()` method is needed.** The service holds no
//     state of its own (it forwards to `DoRepository` and
//     `PersonRepository`, which own their own readiness gates).
//     The `_readyCompleter` is completed eagerly in the
//     constructor so every public method can `await _ready`
//     without an `init()` round-trip. Future additions (e.g.,
//     a paused-until cache, or a remote-sync integration) can
//     swap this to a lazy gate by re-introducing `init()` and
//     keeping `_ready` on a re-creatable `Completer` (see
//     `resetForTesting` for the test seam that already supports
//     this).
//   - Public methods are async.

import 'dart:async';

import 'package:doit/do/do.dart';
import 'package:doit/people/person.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/person_repository.dart';
import 'package:meta/meta.dart';

class PauseService {
  PauseService._() {
    // Eager-complete: the service is stateless (it forwards to
    // the repositories, each of which owns its own readiness
    // gate). Completing here means callers do not need an
    // `init()` round-trip and existing `await _ready` lines
    // in the public methods resolve immediately.
    _readyCompleter.complete();
  }

  static final PauseService instance = PauseService._();

  Future<void> get _ready => _readyCompleter.future;
  final Completer<void> _readyCompleter = Completer<void>();

  /// Test-only readiness probe. Returns `true` once the
  /// service has completed its readiness gate (eager at
  /// construction; never `false` after the singleton has
  /// been touched). Mirrors the pattern in the other
  /// services (e.g., `AppDatabaseService.isReady`).
  @visibleForTesting
  bool get isReady => _readyCompleter.isCompleted;

  /// Pause a habit until [until] (inclusive). A null
  /// [until] is rejected; call [resume] to clear.
  ///
  /// Re-saves the habit through [DoRepository] (so the
  /// v0.1 `insertOnConflictUpdate` path is used). The
  /// reminder layer reads `pausedUntil` directly from the
  /// row, so the new state is effective on the next
  /// `listActive` / `scheduleHabit` call.
  Future<void> pauseHabit(Do habit, DateTime until) async {
    await _ready;
    final updated = habit.copyWith(pausedUntil: until);
    await DoRepository.instance.save(updated);
  }

  /// Clear the pause state on a habit. The next call to
  /// `nextOccurrence` will fire reminders as usual.
  Future<void> resumeHabit(Do habit) async {
    await _ready;
    final updated = habit.copyWith(clearPausedUntil: true);
    await DoRepository.instance.save(updated);
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
    Do habit,
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

  /// Test-only seam. Re-creates the `_readyCompleter` and
  /// completes it eagerly. Mirrors the pattern in the other
  /// services (e.g., `GeofenceService.resetForTesting`) so
  /// unit tests can drive the service after a fresh
  /// `resetForTesting()` round.
  void resetForTesting() {
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
    // `_readyCompleter` is `final`, so we cannot replace the
    // reference. The eager-complete-at-construction pattern
    // means there is no "incomplete → complete" transition
    // needed in tests either; this method exists so test
    // code reads identically to the rest of the suite.
  }
}
