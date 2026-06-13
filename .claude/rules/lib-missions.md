# `lib/missions/**` — Mission engine

## Model purity (where possible)

- `Mission` (sealed), `MissionResult`, `MissionInput` are pure
  Dart. The model layer can be unit-tested without a Flutter
  test harness.
- `ShakeDetector` is the **only** file in this folder that
  imports `package:sensors_plus/` (or any sensor package). It
  is a thin adapter that converts the sensor stream into
  `ShakeInput` for the model.
- Widgets that render mission UIs live in `lib/screens/mission_<name>.dart`,
  not in this folder.

## Sealed hierarchy

- `Mission` is a sealed class with `ShakeMission`, `TypeMission`,
  `HoldMission`, `MathMission`, `MemoryMission`. Add a new
  mission type (e.g., `BarcodeMission` in v0.2) by adding a
  new subclass.
- Each mission has a `verify(MissionInput) → MissionResult`
  method that is **pure**: no side effects, no `DateTime.now()`
  inside (the caller passes the relevant input).
- Each mission has a `timeout` and a `label`. The timeout is
  honored by the chain executor, not by the mission itself.

## Chain executor

- `MissionChain` is `unmodifiableListView` of `Mission`. The
  chain list is immutable after creation.
- `execute(MissionChain, List<MissionInput>) → MissionChainResult`
  runs each mission in order. A `ChainFailedAt` aborts the
  rest. A `ChainTimedOut` is a special case of `ChainFailedAt`
  with a `MissionTimedOut` reason.
- The chain executor does not own any timers; it is given
  inputs and returns a result. Timers live in the widget
  (which has access to a real `Ticker` and can pause on
  background).

## Shake detector specifics

- `ShakeDetector` consumes accelerometer events. It is a
  `Stream<ShakeEvent>` adapter.
- A shake event is fired when a sample's magnitude exceeds
  `magnitudeThreshold` AND the inter-shake spacing is in
  `[minSpacingMs, maxSpacingMs]`. See
  [`docs/v_model/mission_catalog.md`](../../docs/v_model/mission_catalog.md)
  for the full algorithm.
- Holding the phone still MUST NOT advance the shake count.
  A unit test covers this explicitly.

## Math problem generator

- `MathProblem.next(difficulty)` is a pure function. No
  `Random()` at module init; the caller passes an `Random`
  (or a seeded one for tests).
- Subtraction problems never produce negative results.
- Multiplication is generated with `a × b` where `a, b` are
  within the difficulty range. Order is independent of the
  answer.

## Memory game specifics

- `MemoryGame.generate(theme, seed)` returns a list of
  `MemoryCard` objects. The list has `rows × cols` entries
  and `rows × cols / 2` distinct pairs.
- The `seed` parameter is required so widget tests are
  deterministic.
- A user flipping the same card twice (impossible by the UI
  but possible by a buggy engine) is a `MissionFailed`.

## Forbidden patterns

- No `print()`.
- No `DateTime.now()` in the model or executor. The chain
  executor takes a `Stopwatch` from the caller so wall-clock
  is observable in tests.
- No `Random()` at module init. Pass the RNG.
- No side effects. Missions are pure.

## Tests

- `test/missions/<name>_test.dart` for each of the 5 mission
  types. Each must cover happy path, parameter edge cases,
  and at least one fail-fast.
- `test/missions/chain_test.dart` — single mission, multi
  mission, failure aborts the rest, idempotent re-execution
  on the same input.
- `test/missions/shake_detector_test.dart` — synthetic
  accelerometer stream, validates magnitude + spacing
  threshold.
- 80%+ coverage on changed files.

## When changing this folder

- Update
  [`docs/v_model/mission_catalog.md`](../../docs/v_model/mission_catalog.md)
  if a new mission type is added or an existing one changes.
- Update the SYS- IDs in
  [`docs/v_model/requirements.md`](../../docs/v_model/requirements.md).
- Update the test list above.
- Update
  [`docs/v_model/traceability_matrix.md`](../../docs/v_model/traceability_matrix.md)
  if a new test covers a new requirement.
- If a new sensor or input is used, append an ADR.
