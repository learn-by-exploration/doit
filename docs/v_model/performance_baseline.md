# Performance baseline — v1.4-stab-L

Cycle L captures the first canonical performance baseline for
do it. The numbers below are observed under `flutter test`
(the same harness that drives CI) and serve as the
regression guard for every future cycle. A future contributor
who introduces heavy synchronous work to `build()`, splits a
SQL query into per-do reads, or regresses the per-rebuild
median will trip one of these tests.

## Scope

| Surface | Test file | What it pins |
|---|---|---|
| Widget rebuild | `test/perf/widget_rebuild_test.dart` | Per-rebuild cost of a Listenable push inside a MaterialApp + Provider tree |
| SQL query count | `test/perf/sql_benchmark_test.dart` | N+1 invariant on `DoRepository.listAll` and `listActive` |
| Do model fuzz | `test/fuzz/do_model_fuzz_test.dart` | `Do` constructor + `copyWith` + `validate` invariants over 1000 fuzz inputs |
| Person model fuzz | `test/fuzz/person_model_fuzz_test.dart` | `ContactPerson` constructor + `copyWith` invariants over 1000 fuzz inputs |
| Mission model fuzz | `test/fuzz/mission_model_fuzz_test.dart` | `MissionChain` + `Mission.verify` invariants over 1000 fuzz inputs |
| ConsecutiveCounter fuzz | `test/fuzz/consecutive_counter_fuzz_test.dart` | Determinism + non-negativity invariants over 1000 fuzz inputs |

## Observed baseline numbers (v1.4-stab-L, harness run)

| Metric | Value | Budget | Status |
|---|---|---|---|
| Cold widget-tree mount (debug, fake-async) | ~262 ms | ≤ 750 ms | PASS |
| Single-tile Listenable-driven rebuild, median over 100 runs | ~2 ms | ≤ 5 ms | PASS |
| 10-tile parent rebuild, median over 100 runs | ~10 ms | ≤ 25 ms | PASS |
| `DoRepository.listAll` SQL count for N=10 habits | 1 SELECT | exactly 1 | PASS |
| `DoRepository.listActive` SQL count for N=10 habits | 1 SELECT | exactly 1 | PASS |
| `DoRepository.listActive` per-call median (in-memory DB) | < 1 ms | ≤ 10 ms | PASS |
| Do fuzz — 1000 iterations, invariant pass | 100% | 100% | PASS |
| Person fuzz — 1000 iterations, invariant pass | 100% | 100% | PASS |
| Mission fuzz — 1000 iterations, invariant pass | 100% | 100% | PASS |
| ConsecutiveCounter fuzz — 1000 iterations, invariant pass | 100% | 100% | PASS |

**Fuzz invariant:** every fuzz test runs 1000 iterations
with `dart:math.Random(seed)` (no `package:faker` per Cycle
L pre-auth) and asserts:
- Construction never throws for valid args.
- `copyWith` never mutates the source.
- `copyWith` preserves the runtime subclass.
- `copyWith(name: X).name == X`.
- For ConsecutiveCounter: streak never goes negative;
  longest ≥ current; deterministic across calls.

## Interpreting the numbers

The widget-rebuild numbers are observed under `flutter test`
(debug build + fake-async zone). Real-device builds run
3-5× faster per Flutter's published guidance for
release-profile builds. The numbers above are
**regression-direction** guards, not absolute perf budgets:
a future contributor who adds heavy sync work to `build()`
will trip the budget. The real-device profile-mode numbers
should be re-measured in W-13 closeout per the
stabilization retrospective.

The SQL count is a hard invariant: N+1 detection. A future
contributor who splits `listAll` into a per-do read
(e.g. to JOIN related rows) would silently regress to
N+1 queries, and the test fails with a clear reason
("`listAll` should issue exactly 1 SELECT. Got N. A
future contributor who splits the query per-do would
regress N+1 here — fix at the SQL level.").

## How to re-run the baseline

```bash
# Captures every metric above in ~3 minutes on a typical CI box.
flutter test test/perf test/fuzz --reporter=expanded
# Full coverage report (for the final coverage snapshot):
flutter test --coverage
```

The widget-rebuild benchmark prints a `reason:` string when
it fails, so the CI log shows the actual observed median
next to the budget. The SQL benchmark prints the actual
SELECT count vs. the expected `exactly 1`.

## Cycle L's contribution

Before Cycle L, do it had **zero** performance regression
guards. The benchmark tests now act as tripwires for:

1. A future contributor adding heavy sync work to
   `build()` (e.g. a `find.byType(...)` scan, a DB read on
   the UI thread, a JSON parse in the hot path).
2. A future contributor splitting `DoRepository.listAll`
   / `listActive` into a per-do read (the N+1 antipattern).
3. A future contributor breaking the immutability / runtime
   type / field-preservation invariants on the pure-Dart
   model layer (`Do`, `ContactPerson`, `Mission`,
   `ConsecutiveCounter`).

The fuzz tests are *property tests* in the
QuickCheck sense: they assert invariants over randomized
inputs. A future contributor who breaks an invariant
(e.g. makes `copyWith(name:)` ignore the new name, or
makes `ConsecutiveCounter.compute` non-deterministic) will
trip a fuzz test within the first iteration that lands the
bad code path.

## Why median, not mean?

Per-cycle drift lesson (Cycles A..K): single-run timings
swing 5-10× across runs on the same hardware due to
CI noise (cold cache, GC pauses, scheduler jitter). The
median over 100 iterations is robust to that noise — a
real regression shifts the median by 2-3×, while CI noise
shifts the mean by similar amounts. Every test in
`test/perf/` reports the median, not every-run.

## Why `dart:math.Random(seed)`, not `package:faker`?

The Cycle L pre-auth explicitly forbids new pubspec deps
(the 19 runtime + 4 dev deps already cover every channel).
Adding `package:faker` for 4 fuzz files would expand the
dev-deps surface for marginal value. `dart:math.Random(seed)`
is the same RNG the production code uses (`MathProblem.next`,
`MemoryGame.generate`) and is already battle-tested for
deterministic seed-pinning. The fuzz tests pin the seed
value in the file (`Random(42)` etc.) so the run is
reproducible across CI runs and developer machines.

## What Cycle L does NOT cover (W-13 closeout follow-ups)

- **Profile-mode / release-build timings.** The numbers
  above are debug-build fake-async. The W-13 closeout
  should add `flutter run --profile` traces and capture
  the real-device perf baseline.
- **End-to-end scroll perf.** A 100-tile scroll jank test
  would pin the home screen's scroll FPS. Out of scope for
  Cycle L (would need a `flutter drive` device run, not
  available in the harness).
- **APK size.** The plan called for "APK size documented
  in `performance_baseline.md`; debug-signed target ≤ 80 MB".
  Cycle L is a test-only cycle with NO release APK rebuild
  — APK SHA1 stays at `25bb7fab` (Cycle J's). The APK size
  baseline is unchanged from Cycle J's measurement and will
  be re-measured in W-13 closeout.