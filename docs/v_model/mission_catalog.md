# Mission Catalog

Status: draft baseline, created 2026-06-13.

This is the spec for each of the five v0.1 mission types. Every
mission is a subclass of the sealed `Mission` class, and every
chain is a `List<Mission>` executed in order by `MissionChain`. If
a chain is `[]` (empty), the habit's proof mode cannot be Strong
(the model throws on save).

## Common contract

```dart
sealed class Mission {
  /// Human-readable label for the UI.
  String get label;

  /// How long the user is given before the mission times out.
  Duration get timeout;

  /// Verifies the user input. Returns the result with details
  /// (e.g., how many shakes were counted, how long they held).
  MissionResult verify(MissionInput input);
}
```

`MissionResult` is a sealed class with three subclasses:
`MissionPassed`, `MissionFailed(reason)`, `MissionTimedOut`.

`MissionInput` carries the raw input the engine captured:
`ShakeInput(samples: List<AccelerometerEvent>)`,
`TextInput(typed: String)`, `HoldInput(duration: Duration)`,
`MathInput(answer: int)`, `MemoryInput(pairs: List<Pair>)`.

## SYS-IDs covered

- **SYS-008** Shake-N
- **SYS-009** Type phrase
- **SYS-010** Hold-tap
- **SYS-011** Math
- **SYS-012** Memory
- **SYS-013** Chain ordering

---

## M-001 — Shake-N

**User experience.** The user shakes the phone up and down (or side
to side) a target number of times. A counter on screen ticks up
with each detected shake.

**Parameters.**
- `n` (int, 1-50, default 10): target shake count.
- `magnitudeThreshold` (double, m/s², default 14.0): how hard a
  single sample must be to count as a "shake event".
- `minSpacingMs` (int, default 250): minimum milliseconds between
  two shake events. Prevents a single high-magnitude sample from
  being double-counted.
- `maxSpacingMs` (int, default 1500): maximum milliseconds between
  two shake events. If the user goes too slow, the chain restarts
  (the user must keep a steady pace).

**Algorithm.**
```
shakes = 0
lastShakeAt = null
for sample in samples:
  if magnitude(sample) >= magnitudeThreshold:
    if lastShakeAt is null or
       (now - lastShakeAt).inMs >= minSpacingMs:
      if lastShakeAt is not None and
         (now - lastShakeAt).inMs > maxSpacingMs:
        shakes = 0  # reset on too-slow
      shakes += 1
      lastShakeAt = now
return shakes >= n
```

**Fail-safe.** If the device has no accelerometer (emulator, some
tablets), the engine raises `MissionSensorUnavailable` and the
chain fails-fast; the caller is expected to swap to a Hold-Tap
fallback or skip the habit.

**Telemetry.** The completion log records the actual shake count
and the time it took.

**Unit tests** (`test/missions/shake_test.dart`):
- Steady pace of N shakes → pass.
- Faster than minSpacing → counted once.
- Slower than maxSpacing → reset.
- Holding the phone still with one big jiggle → does not advance.
- Negative-direction shakes count the same as positive.
- Magnitude below threshold → does not count.
- n=0 → pass immediately (degenerate; forbidden by validation).

---

## M-002 — Type phrase

**User experience.** The user types a specific phrase into a text
field. The phrase is shown in a hint, faded, so the user must
actually recall it.

**Parameters.**
- `phrase` (string, 1-200 chars, required): the expected text.
- `caseSensitive` (bool, default false).
- `trimWhitespace` (bool, default true).
- `ignorePunctuation` (bool, default true): so "it's" matches
  "its".

**Algorithm.**
```
def verify(typed):
  expected = phrase
  actual = typed
  if trimWhitespace:
    expected = expected.strip()
    actual = actual.strip()
  if not caseSensitive:
    expected = expected.lower()
    actual = actual.lower()
  if ignorePunctuation:
    expected = strip_punct(expected)
    actual = strip_punct(actual)
  return expected == actual
```

**Edge cases.**
- Empty typed → fail.
- Phrase contains a newline → forbidden by validation; the phrase
  must be a single line.
- Unicode normalization (NFC/NFD) is applied to both sides before
  comparison, so combining-diacritic characters work.

**Unit tests** (`test/missions/type_test.dart`):
- Exact match → pass.
- Case mismatch → pass (with `caseSensitive=false`).
- Trailing space → pass (with `trimWhitespace=true`).
- Missing period → pass (with `ignorePunctuation=true`).
- Extra leading word → fail.
- Substring → fail.
- Empty typed → fail.
- Unicode normalization round-trip → pass.

---

## M-003 — Hold-tap

**User experience.** The user presses and holds a circular button
for a target duration. Releasing early resets the progress; the
ring fills clockwise.

**Parameters.**
- `duration` (Duration, 1-30 s, default 4 s).
- `visualRingFill` (bool, default true): whether to render the
  progress ring (almost always true).

**Algorithm.**
```
def verify(hold_input):
  return hold_input.duration >= duration
```

**Edge cases.**
- User releases and re-presses within the same attempt → only the
  cumulative duration of the active presses counts. The progress
  ring resets visually, but a sliding window tracks the best
  cumulative hold.
- User rotates the phone mid-hold → no effect.
- Screen turns off mid-hold (very rare in full-screen) → the
  wakelock is held; this should not happen.

**Unit tests** (`test/missions/hold_test.dart`):
- Hold for exactly `duration` → pass.
- Hold for `duration - 1ms` → fail.
- Hold for `duration + 1s` → pass.
- Multi-tap (release, press, release) → cumulative counts.
- Pause the test clock → progress should not advance (the engine
  uses real wall-clock time, not test time).

---

## M-004 — Math

**User experience.** A random math problem is shown (e.g., "17 × 8
= ?"). The user types the integer answer.

**Parameters.**
- `difficulty` (enum: `Easy`, `Normal`, `Hard`).
  - `Easy`: 1-digit × 1-digit OR 2-digit + 1-digit.
  - `Normal`: 2-digit × 1-digit OR 2-digit + 2-digit.
  - `Hard`: 2-digit × 2-digit OR 3-digit + 2-digit.
- `ops` (set of `+`, `-`, `×`, default `+` and `×`): allowed
  operators.
- `maxAttempts` (int, 1-5, default 1): how many wrong answers
  before the mission is failed.

**Algorithm.**
```
def next_problem(difficulty):
  a, b = sample_within(difficulty.range)
  op = random.choice(ops)
  return MathProblem(a, b, op, answer=compute(a, b, op))

def verify(answer, problem):
  return int(answer) == problem.answer
```

**Edge cases.**
- Subtraction with negative results → forbidden; the generator
  only produces `a - b` with `a > b`.
- Division is out of scope for v0.1.
- The user has up to `maxAttempts` retries. The log records each
  wrong answer.

**Unit tests** (`test/missions/math_test.dart`):
- Correct answer → pass.
- Wrong answer, `maxAttempts=1` → fail on first wrong.
- Wrong answer, `maxAttempts=3` → fail on third wrong.
- Easy difficulty problems stay in range.
- Hard difficulty problems stay in range.
- Subtraction does not produce negatives.
- Multiplication is commutative (problem is independent of order).

---

## M-005 — Memory

**User experience.** A 4×3 grid of cards (12 cards, 6 pairs) is
shown face-down. The user flips two at a time. Matching pairs stay
revealed; mismatches flip back after 1 second. All 6 pairs must be
matched within 60 seconds.

**Parameters.**
- `rows` (int, default 4).
- `cols` (int, default 3).
- `timeLimit` (Duration, default 60 s).
- `theme` (enum: `Animals`, `Fruits`, `Shapes`, `Numbers`,
  default `Animals`): the visual set of pairs.
- `revealDelayMs` (int, default 1000): how long a mismatched pair
  stays revealed before flipping back.

**Algorithm.**
```
def verify(memory_input):
  return (memory_input.pairs.all_matched() and
          memory_input.elapsed <= timeLimit)
```

**Edge cases.**
- User flips the same card twice (impossible by UI, but a buggy
  engine could) → `MissionFailed(reason: 'duplicate-flip')`.
- User taps outside the grid → ignored.
- Screen rotation → the in-progress state is preserved (the
  matched pairs stay revealed; the timer continues).
- App backgrounded mid-game → the timer pauses (the OS will not
  kill the foreground service for 60 s of backgrounding, but
  safer to pause).

**Unit tests** (`test/missions/memory_test.dart`):
- All 6 pairs matched in 30 s → pass.
- 5 pairs matched, time runs out → fail.
- 6 pairs matched in 61 s → fail.
- Mismatched pair reveals the wrong face-up for 1 s before
  flipping back (visual; not in unit test).
- Random theme generates 6 distinct pairs.

---

## Chain execution

```dart
sealed class MissionChainResult {
  const MissionChainResult();
}
class ChainPassed extends MissionChainResult {
  final List<MissionResult> results;
}
class ChainFailedAt extends MissionChainResult {
  final int index;          // 0-based index of the failed mission
  final MissionResult result;
}
class ChainTimedOut extends MissionChainResult {
  final int index;
  final MissionResult result;
}
```

`MissionChain.execute(input: List<MissionInput>)` runs each
mission in order. A `ChainFailedAt` aborts the rest. A
`ChainTimedOut` is a special case of `ChainFailedAt` with a
`MissionTimedOut` reason.

The completion log records:

- The chain's missions in order.
- Per-mission result (passed, failed, timed out).
- The wall-clock duration of the entire chain.

**Unit tests** (`test/missions/chain_test.dart`):
- Empty chain → forbidden (validation throws).
- Single mission passing → `ChainPassed`.
- Three missions, second fails → `ChainFailedAt(index: 1)`;
  third is not run.
- Three missions, all pass → `ChainPassed` with three results.
- Reordering the chain after creation is forbidden (the chain
  list is `unmodifiable`).

## Validation (at habit-save time)

The habit-save flow validates:

- Strong mode → `mission_chain.length >= 1`.
- Soft or Auto mode → `mission_chain` is `null` (or empty).
- Each mission in the chain has valid parameters (per the
  per-mission rules above).
- The total chain `timeout` (sum of per-mission timeouts) is
  ≤ 5 minutes (sanity check; longer chains need explicit user
  confirmation in v0.2).

If validation fails, the user sees a field-level error and the
habit is not saved.
