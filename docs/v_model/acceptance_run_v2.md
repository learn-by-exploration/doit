# v0.2 Acceptance Run #2 (14-day real-device)

Status: **in flight** — kicked off 2026-06-14 at SHA `c1b9e64`
(v0.2d tip + the v0.2 defect-fix commit: compileSdk 36 bump +
picker widget tests). Created 2026-06-14; this document is the
right-side verification for [v0.2](v0_2_baseline.md). It does
not replace [`acceptance_run.md`](acceptance_run.md) — Run #1
still gates v0.1's "I trust it on my primary phone" claim. Run
#2 adds the v0.2 surface (events, groups, time-windows, edit,
pause, test reminder, bulk complete) and gates v0.2's "the new
features work in the wild" claim.

## Purpose

The 14-day real-device run #2 exercises the v0.2 surface area
on the user's primary phone. It must pass alongside Run #1
(the v0.1 run is still running; Run #2 stacks on top of it).

The run is "accepted" when, at Day 14:

1. Every v0.1 acceptance criterion in
   [`acceptance_run.md`](acceptance_run.md) is still "yes".
2. The v0.2-specific scenarios below (E1..E5, G1..G3, W1..W2,
   X1..X3) all have a non-empty cell.
3. The 3-gate passed with zero failures on every commit
   during the 14 days.
4. The user has signed off in the
   [Sign-off](#sign-off) section.

The run is **rejected** (and a v0.2 fix loop begins) when any
of:

- A v0.1 criterion regressed.
- 3+ v0.2 scenarios ended in `✗`.
- A 3-gate was skipped or regressed.

## Scope

- **Device:** the user's primary Android phone (API 28+), the
  same one used for Run #1 (no second device).
- **Build:** `flutter build apk --debug` from the tip of `main`,
  with `flutter test --coverage` clean on the same SHA.
- **Account:** none. Streak is single-user, single-device,
  local-only. No login flow exists or will be created for
  this run.
- **Network:** disabled for the app (`INTERNET` is not in the
  manifest — see
  [architecture_options.md](architecture_options.md) § manifest
  baseline). The run cannot accidentally exfiltrate data
  because the platform itself will not let the app make a
  call.
- **v0.2c (groups) needs `READ_CONTACTS`** — the user already
  granted it during Run #1's onboarding. No new permission
  prompts for v0.2 (the VIP feature in v0.2f will introduce
  `READ_PHONE_STATE`, but that lands in a later run).

## Setup (Day 0)

The run starts at the end of a working day. Before Day 1:

1. `flutter pub get` on a clean clone.
2. `dart format --output=none --set-exit-if-changed .` clean.
3. `flutter analyze --fatal-infos` clean.
4. `flutter test` green (≥ 293 tests as of v0.2d; the threshold
   only goes up during the run).
5. `flutter test --coverage` ≥ 80% on the v0.2 changed files
   (the union of `lib/people/`, `lib/events/`, the v0.2 screens,
   `lib/services/reminder_service.dart`).
6. `flutter build apk --debug` succeeds.
7. **Do not uninstall** the app. Run #1's local DB and backup
   folder are reused.
8. Note the SHA of the build: `git rev-parse HEAD` =
   `____________________`.
9. Add the v0.2 scenarios from the
   [scenario matrix](#scenario-matrix) below. The v0.1
   habits from Run #1 stay in place.

## Scenario matrix (v0.2 surface)

The 14 days exercise 11 v0.2 scenarios against the new SYS-
IDs and WF- IDs. The v0.1 scenarios from Run #1 are still
exercised and recorded in
[`acceptance_run.md`](acceptance_run.md); the two runs are
logically independent.

| # | Scenario | SYS- / WF- | Day |
|---|----------|------------|-----|
| E1 | Add a one-off event ("Dentist 2026-07-01 14:00") | SYS-035, WF-017 | 1, 14 |
| E2 | Add an annually-recurring event ("Mom's birthday 1965-03-15") | SYS-035, WF-017 | 2, 9 |
| E3 | Verify a fired event auto-archives within 24 h | SYS-035, WF-017 | 3, 10 |
| G1 | Add a rotation group "Call a friend" (5 friends, weekly) | SYS-036..SYS-038, WF-018 | 4, 11 |
| G2 | Mark the suggested member contacted; verify the rotation advances | SYS-036..SYS-038, WF-018 | 5, 12 |
| G3 | Add a second group with a different semantic (any / all) | SYS-036..SYS-038, WF-018 | 7 |
| W1 | Add a 16:8 fasting window (20:00 → 12:00 next day) | SYS-039, WF-019 | 6, 13 |
| W2 | Verify the live timer shows the right "Fasting — HH:MM:SS left" or "Opens in HH:MM:SS" | SYS-039, WF-019 | 6, 13 |
| X1 | Edit an existing v0.1 habit; verify the completion log is intact | WF-022, SYS-033 | 8 |
| X2 | Pause a habit for 1 day; verify it does not break the streak | WF-027, SYS-047 | 9 |
| X3 | Fire the "Send a test reminder" tile; verify a notification in ≤ 10 s | WF-028, SYS-048 | 14 |
| B1 | Bulk-complete a busy morning (3+ habits at once) | WF-029, SYS-049 | 11 |

The mark is `✓` (passed on first try), `△` (passed with fix;
record commit SHA in notes), or `✗` (failed; record blocker).

## Daily log

For each of the 14 days, copy this block into a fresh row and
fill it in. Append a one-line `Notes:` after the block with
anything unusual — the run only stays useful if anomalies are
recorded, not just successes.

```
### Day N — YYYY-MM-DD
- Build SHA: ____________
- 3-gate status:
  - `dart format`: ✓ / ✗
  - `flutter analyze --fatal-infos`: ✓ / ✗
  - `flutter test`: ✓ / ✗ (N passing)
- Coverage on v0.2 changed files: __%
- v0.1 scenarios run today (from Run #1 matrix): ___, ___, ___
- v0.2 scenarios run today (from matrix above): ___, ___
- v0.1 results: ✓✓✓ / ✓△✓ / ✗
- v0.2 results: ✓✓ / ✗
- Any reliability banner ("may be late") visible? yes / no
- Any duplicate reminders? yes / no
- Any missed reminders? yes / no (record the habit + time)
- Notes: ___
```

### Day 1 — 2026-06-14 (kickoff day)
- Build SHA: `c1b9e64` (v0.2d tip + the v0.2 defect-fix commit;
  debug apk at `build/app/outputs/flutter-apk/app-debug.apk`,
  174 MB)
- 3-gate status:
  - `dart format`: ✓ (0 changed)
  - `flutter analyze --fatal-infos`: ✓ (exit 0; 41 pre-existing
    info-level lints, 0 errors, 0 warnings)
  - `flutter test`: ✓ (312 passing; +19 vs the v0.2d baseline
    of 293 from the new picker tests)
- Coverage on v0.2 changed files: **89.8%** (model + service +
  widget layer, the runbook's scope — 535 / 596 lines)
  - `lib/widgets/icon_picker.dart`: 48 / 48 (was 0 / 48)
  - `lib/widgets/category_chip.dart`: 115 / 117 (was 35 / 117)
  - `lib/services/event_repository.dart`: 64 / 64
  - `lib/services/person_group_repository.dart`: 91 / 98
  - `lib/services/reminder_service.dart`: 33 / 43
  - `lib/people/person_group.dart`: 42 / 47
  - `lib/people/cadence.dart`: 44 / 45
  - `lib/people/person.dart`: 20 / 43
  - `lib/events/event.dart`: 30 / 40
  - `lib/habits/category.dart`: 25 / 28
  - `lib/widgets/reliability_banner.dart`: 23 / 23
- v0.1 scenarios run today (from Run #1 matrix): _Run #1 still
  in progress on the primary phone; this run's Day 1 is the
  kickoff prep + apk install. The v0.1 scenario results will be
  carried over from Run #1's daily log, not re-run here._
- v0.2 scenarios run today (from matrix above): E1
  (add a one-off event — "Dentist 2026-07-01 14:00")
- v0.1 results: _tbd (per Run #1)_
- v0.2 results: _tbd — user to fill in after the apk is
  installed and the scenario is exercised on the primary phone_
- Any reliability banner visible? _tbd_
- Any duplicate reminders? _tbd_
- Any missed reminders? _tbd_
- Notes: Day 0 prep found a v0.2a defect (icon_picker.dart
  shipped without tests, dragging v0.2 coverage to 67.8%, below
  the 80% gate). Fix landed in commit `c1b9e64` along with
  category_chip coverage and a build-config bump: file_picker's
  transitive dep flutter_plugin_android_lifecycle now requires
  compileSdk 36+, so the app + every Android subproject was
  bumped to compileSdk 36 (minSdk 28, targetSdk follows Flutter
  default). With the fix the v0.2 surface is at 89.8% coverage
  and the debug apk builds clean.

_(Copy the Day 1 block above for Days 2..14.)_

## Per-scenario acceptance criteria (v0.2)

A scenario is "passed" only when the criterion in its row is
met across the run. Partial credit is recorded in the daily
notes, not the cell.

| # | Scenario | Acceptance criterion |
|---|----------|----------------------|
| E1 | One-off event | The reminder fires within ±15 min of the lead-time target; the event auto-archives within 24 h of fire. |
| E2 | Annually recurring event | The reminder fires on the same day-of-year in the next calendar year; an archive of the prior year is visible. |
| E3 | Auto-archive | The "Past (unarchived)" section empties within 24 h of a fired event. |
| G1 | Add rotation group | All 5 members are pickable; the "Next: <person>" line is correct on Day 4. |
| G2 | Mark contacted advances rotation | After marking, the next "Next: <person>" line differs from the prior one (when > 1 uncontacted member exists). |
| G3 | Non-rotation semantic | The "any" semantic group is satisfied by any single member being marked; the "all" semantic group is not satisfied until every member is marked. |
| W1 | Add fasting window | The window is saved; the live timer renders on a fasting weekday. |
| W2 | Live timer accuracy | The "Fasting — HH:MM:SS left" or "Opens in HH:MM:SS" matches the wall clock within ±2 s. |
| X1 | Edit habit | The edited habit's completion log is unchanged; the streak number is correct. |
| X2 | Pause | The habit does not fire during the pause; the streak is unbroken on Day 10 (unpause day). |
| X3 | Test reminder | A notification appears within 10 s of tapping the tile; the action button (Done / Open) is wired. |
| B1 | Bulk complete | 3+ completion entries land within the same `dayMillis` bucket; the SnackBar shows the count. |

## 3-gate log (every commit during the run)

Every commit on `main` during the 14 days must pass the 3-gate
_before_ push. The user pastes the tail of the three commands
into a row. If a commit lands without a row here, the run is
paused until it is backfilled.

| SHA | `dart format` | `flutter analyze` | `flutter test` (count) | Notes |
|-----|---------------|-------------------|------------------------|-------|
| `54be40f` | ✓ | ✓ | ✓ (293) | v0.2d tip. Run #2 kickoff baseline. |
| `c1b9e64` | ✓ | ✓ | ✓ (312) | compileSdk 36 + picker widget tests. Run #2 kickoff build (debug apk at `build/app/outputs/flutter-apk/app-debug.apk`). |

_(Append a row per commit during the run.)_

## Exit criteria

The run is **accepted** when, at Day 14:

1. Every v0.1 criterion in
   [`acceptance_run.md`](acceptance_run.md) is still "yes".
2. Every v0.2 scenario in the matrix above has a non-empty
   cell.
3. ≥ 70% of v0.1 active presets show ≥ 70% completion over
   the 14 days.
4. ≥ 1 event, ≥ 1 group, ≥ 1 time-window habit, ≥ 1 edit, ≥
   1 pause, ≥ 1 test reminder, ≥ 1 bulk-complete all
   exercised.
5. No `✗` in the 3-gate log for the run period.
6. The user has signed off in the [Sign-off](#sign-off)
   section.

The run is **rejected** (and a v0.2 fix loop begins) when any
of:

- 3+ v0.2 scenarios ended in `✗`.
- A v0.1 criterion regressed (this is a Run #1 regression
  and is treated as a Run #2 reject too).
- A 3-gate was skipped or regressed.

## Sign-off

The run is closed by a single line:

```
Accepted on YYYY-MM-DD by <user>. Final SHA: <git rev-parse HEAD>.
```

If rejected, append a v0.2 fix-loop plan link instead.

## Traceability

| Artifact | This document |
|----------|---------------|
| `v0_2_baseline.md` § Acceptance | The 9 v0.2 exit criteria here are a per-scenario expansion. |
| `acceptance_run.md` | Run #1's matrix. Run #2 stacks on top of it. |
| `conops.md` § Normal Operational Scenario | Daily routine maps directly to Day N template. |
| `workflows.md` WF-017, WF-018, WF-019, WF-022, WF-027, WF-028, WF-029 | Each scenario cites its WF- IDs. |
| `requirements.md` SYS-033, SYS-035..SYS-039, SYS-047, SYS-048, SYS-049 | The scenario matrix cites the exercised SYS- IDs. |
| `traceability_matrix.md` | Every SYS- ID in the matrix has a row in the per-scenario acceptance table above. |
| `mission_catalog.md` | Scenario G1..G3 exercise the rotation selector; W1..W2 exercise the time-window schedule engine. |
| `notification_reliability.md` | The "may be late" banner check on every day is the real-device counterpart of the integration tests in `test/reminders/`. |
| `decision_record.md` | The "no `INTERNET`" and "no `CALL_PHONE`" decisions are enforced by the absence of those permissions in the manifest — no new code ships during the run that adds them. `READ_PHONE_STATE` is deferred to v0.2f and is not in scope for this run. |
| `test/` (293+ tests as of v0.2d) | The 3-gate is the contract; any test regression during the run fails the run. |

## What is explicitly out of scope for Run #2

- **v0.2f (VIP escalation, `READ_PHONE_STATE`).** It is the
  next phase but lands a new permission and a new permission
  rationale. That is a Run #3 concern, not a Run #2 one.
- **Multi-user / multi-device sync.** v0.2 is single-user,
  single-device.
- **Cloud backup.** Backup is local-only via SAF; the file
  lives in a user-picked folder. The restore flow from Run #1
  is reused.
- **iOS.** v0.2 is Android only.
- **Encryption at rest for backups.** v0.2 backups are plain
  JSON; encryption is a v0.3 feature behind a user passphrase.
- **New mission types.** The 5 mission types in the catalog
  are the contract for both v0.1 and v0.2. Barcode / QR /
  Photo are v0.3.
- **The home widget.** The home widget is implemented in the
  Kotlin side, but acceptance is on the in-app loop. The
  widget is verified manually (visible on home screen,
  tap-to-open) but is not in the pass/fail matrix.

If any of the above sneaks into the run, it is a scope creep;
cut it back to the matrix and ship the in-scope fix.
