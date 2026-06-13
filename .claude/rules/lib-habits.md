# `lib/habits/**` — Habit model and schedule engine

## Model purity

Files in `lib/habits/` (except where noted) MUST NOT import
`package:flutter/*`. The model layer is pure Dart so it can be
unit-tested without a Flutter test harness and so the schedule
engine can be reused in a future iOS port without changes.

**Exception:** `lib/habits/habit_assets.dart` is the only file in
this folder that imports Flutter. It reads `rootBundle` for
preset definitions.

## Sealed hierarchy

- `Habit` is a sealed class.
- Subclasses: `HabitFixed`, `HabitInterval`, `HabitAnchor`,
  `HabitDayOfX`. Add a new schedule type by adding a new subclass
  here, not by editing an enum.
- `HabitProofMode` is a sealed class with `Soft`, `Strong`,
  `Auto` subclasses. The mode is immutable per `Habit` instance
  (see ADR-012). The model throws `ImmutableFieldChanged` if
  the field is mutated directly.

## Schedule engine

- Every schedule subclass implements
  `DateTime nextOccurrence(DateTime from)`.
- The function is **pure**: same input → same output. No
  `DateTime.now()` calls inside; the caller passes the reference
  time.
- All computation is in the device's current local zone.
  Timezone changes are handled by re-calling `nextOccurrence`
  on every habit when `ACTION_TIMEZONE_CHANGED` fires.
- DST is handled per the rules in
  [`docs/v_model/notification_reliability.md`](../../docs/v_model/notification_reliability.md).

## Streak calculator

- `StreakCalculator` takes a `List<CompletionLogEntry>` and a
  `StreakConfig` and returns a `StreakSnapshot`.
- The completion log is the source of truth; the streak number
  is derived.
- The unit test must cover at least:
  - consecutive days, missed day, missed-then-backfilled, rest
    day, mode change mid-streak, DST boundary, timezone change.
- The streak must never go negative. A habit with zero
  completions has streak = 0, not -1.

## Rest-day budget

- `RestDayBudget` is per-habit, default 2 / calendar month.
- `consume(habitId, date)` decrements the budget for that
  calendar month. A month roll-over resets the budget.
- An exhausted budget is a hard reject; the user must either
  do the habit or accept a streak break.

## Forbidden patterns

- No `print()`; use `debugPrint` behind `kDebugMode` in
  any non-model file in this folder (the model has no UI).
- No `DateTime.now()` inside the model. The caller passes
  the reference time. This is the only way to make the
  schedule engine testable.
- No `Random()` calls inside the model. Math problem
  generation and pair shuffling live in `lib/missions/`.
- No side effects (DB writes, alarm scheduling). The habit
  model is the data; the side effects live in
  `lib/services/`.

## Tests

- `test/habits/schedule_test.dart` — one test per schedule
  type per edge case (fixed in DST, interval crossing a
  boundary, anchor referencing a deleted habit, day-of-X on
  the 29th of February, etc.).
- `test/habits/streak_calculator_test.dart` — at least 20
  cases.
- `test/habits/rest_day_budget_test.dart` — month roll-over,
  exhaustion, mid-month reset.
- `test/habits/habit_model_test.dart` — immutability of
  `proof_mode` and `mission_chain` after creation; immutable
  field change throws.
- 80%+ coverage on changed files.

## When changing this folder

- Update the matching SYS- IDs in
  [`docs/v_model/requirements.md`](../../docs/v_model/requirements.md).
- Update the test list above if a new test file is needed.
- Update
  [`docs/v_model/traceability_matrix.md`](../../docs/v_model/traceability_matrix.md)
  if a new test covers a new requirement.
- If a new schedule type is added, append an ADR to
  [`docs/v_model/decision_record.md`](../../docs/v_model/decision_record.md).
