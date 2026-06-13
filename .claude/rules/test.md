# `test/**` — Tests

## Coverage

- ≥ 80% line coverage on changed files. `flutter test
  --coverage` produces `coverage/lcov.info`; `genhtml
  coverage/lcov.info -o coverage/html` produces the report.
- A coverage report is uploaded as a CI artifact.
- Coverage is a **floor**, not a goal. Tests that exercise
  edge cases matter more than tests that inflate lines.

## Structure

- `test/<area>/<thing>_test.dart` — one test file per unit.
- `test/<area>/<thing>_integration_test.dart` — integration
  test (slower, may use real platform channels via
  `tester.runAsync`).
- `test/db/migration_test.dart` — DB migration round-trips.
- `test/backup/<name>_test.dart` — backup and restore.
- `test/reminders/<name>_test.dart` — alarm scheduling and
  reliability.
- `test/missions/<name>_test.dart` — one per mission type.

## Patterns

### Arrange-Act-Assert

```dart
test('streak breaks on missed day past grace window', () {
  // Arrange
  final log = [
    CompletionLogEntry(habitId: 'h1', date: DateTime(2026, 6, 1)),
    CompletionLogEntry(habitId: 'h1', date: DateTime(2026, 6, 2)),
    // 6/3 is missing
    CompletionLogEntry(habitId: 'h1', date: DateTime(2026, 6, 4)),
  ];

  // Act
  final snap = StreakCalculator.compute(
    log: log,
    config: StreakConfig(graceWindow: Duration(hours: 3)),
    asOf: DateTime(2026, 6, 5, 4),
  );

  // Assert
  expect(snap.currentStreak, 1);
  expect(snap.brokenAt, DateTime(2026, 6, 3));
});
```

### Determinism

- Use a seeded `Random` for any test that depends on a
  random source. `Random(42)` is a common default.
- Use a frozen `DateTime` for any test that depends on the
  current time. The caller passes the reference time.
- The shake detector tests use a synthetic accelerometer
  stream, not a real device.

### Async patterns

- `tester.runAsync(() async { ... })` to step out of the
  fake-async zone for real `Future`s.
- `tester.pump(Duration(seconds: N))` to advance the
  fake-async clock.
- `tester.pumpAndSettle()` ONLY for non-drag, non-scrolling
  UIs. After a drag, use `tester.pump()` with a short
  duration.

### Forbidden

- `tester.pumpAndSettle()` after a drag.
- `expectLater` in a way that depends on a real timer.
- Skipped tests (`skip: 'reason'`). If a test is
  flaky/broken, fix it; do not skip. The CI rejects skipped
  tests.
- Mocking the model. Mock the platform; trust the model.

## Naming

- `test_<thing>_<condition>_<expected>`.
- Examples:
  - `test_streak_breaks_on_missed_day_past_grace_window`
  - `test_shake_mission_does_not_advance_when_phone_is_still`
  - `test_alarm_schedules_within_60_seconds_of_target_time`

## Verification

A test is "done" when:

- It is in the right folder.
- It follows the AAA pattern.
- It is deterministic.
- It runs in < 1 s (or, for integration tests, < 30 s).
- It has a meaningful name.
- It has at least one assertion per behavior under test.

## When changing this folder

- A new test file is a hint that a new module is being
  added; update
  [`docs/v_model/architecture_options.md`](../../docs/v_model/architecture_options.md)
  if so.
- A deleted test is a hint that a behavior is being
  removed; check the SYS- IDs.
- A failing CI is a defect. Fix the test or the code; do
  not relax the threshold.
