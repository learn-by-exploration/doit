# v0.1 Acceptance Run (14-day real-device)

Status: pending — kickoff after v0.1 is feature-complete and `flutter
build apk --debug` succeeds. Created 2026-06-14; this document
supersedes the "Not started" entry in
[`implementation_status.md`](implementation_status.md) once the run
begins.

This is the right-side verification for the
[v0.1 baseline](v0_1_baseline.md). Every cell links to a SYS- ID (or
a `WF-` workflow), the test that guards it, and a daily check mark.
If a day ships without the gate passing, the V is incomplete for
that slice — fix it in the same commit, do not defer.

## Purpose

The 14-day real-device run is the gate between "v0.1 works in tests"
and "I trust it on my primary phone." It exercises:

- The 4 presets at default settings.
- 1 custom habit (covers mission types not exercised by the
  presets).
- 1 rest day, 1 snooze, 1 backup restore, 1 forced reboot, 1
  timezone change.
- The 3-gate on every commit during the 14 days.

If at the end the user has > 70% completion on ≥ 3 of the 4 presets
**and** every reliability scenario passed, the v0.1 build is
accepted for personal use. Anything else triggers a Phase 8 fix
loop.

## Scope

- **Device:** the user's primary Android phone (API 28+).
- **Build:** `flutter build apk --debug` from the tip of `main`,
  with `flutter test --coverage` clean on the same SHA.
- **Account:** none. Streak is single-user, single-device, local-only.
  No login flow exists or will be created for this run.
- **Network:** disabled for the app (`INTERNET` is not in the
  manifest — see [architecture_options.md](architecture_options.md)
  § manifest baseline). The run cannot accidentally exfiltrate data
  because the platform itself will not let the app make a call.

## Setup (Day 0)

The run starts at the end of a working day. Before Day 1:

1. `flutter pub get` on a clean clone.
2. `dart format --output=none --set-exit-if-changed .` clean.
3. `flutter analyze --fatal-infos` clean.
4. `flutter test` green (≥ 237 tests as of Phase 6; the threshold
   only goes up during the run).
5. `flutter test --coverage` ≥ 80% on `lib/services/`,
   `lib/screens/`, `lib/reminders/`, `lib/missions/`.
6. `flutter build apk --debug` succeeds.
7. Install on the device. Grant `POST_NOTIFICATIONS` and
   `READ_CONTACTS` only when prompted by the rationale screens
   (WF-001).
8. Pick the backup folder via SAF (WF-014).
9. Pick the anchor mode (WF-016) — recommended: **First-unlock**.
10. Note the SHA of the build: `git rev-parse HEAD` =
    `____________________`.
11. Add the 5 habits from the [scenario matrix](#scenario-matrix)
    below, in any order. Skip the ones the user does not want to
    run; mark skipped cells as "N/A" with a one-line reason.

## Scenario matrix

The 14 days exercise 11 scenarios against 17 SYS- IDs and 9 WF- IDs.
Each scenario is a row; each cell is a date. The mark is `✓` (passed
on first try), `△` (passed with fix; record commit SHA in notes),
or `✗` (failed; record blocker).

| # | Scenario | SYS- / WF- | Day |
|---|----------|------------|-----|
| 1 | Drink water — Interval 30 min × 8, Auto, default window | SYS-002, SYS-005, WF-002, WF-007 | 1..14 |
| 2 | Call Mom — every 3 days, Strong, Shake-N=10 | SYS-003, SYS-008, WF-003, WF-006 | 1, 4, 7, 10, 13 |
| 3 | Morning routine — 06:30 weekday, Strong, Hold-tap 4 s, anchored | SYS-004, SYS-006, SYS-009, SYS-027, WF-005, WF-006, WF-016 | 1..14 |
| 4 | Daily todo — Soft, one-off | SYS-001, SYS-007, WF-004 | 1, 2, 3 |
| 5 | Custom "Read 20 min" — Fixed 21:00, Strong, Type phrase | SYS-001, SYS-008, WF-002, WF-006 | 1..14 |
| 6 | Rest day on Morning routine | SYS-011, WF-008 | 5 |
| 7 | Snooze Call Mom (one time) | SYS-013, WF-010 | 9 |
| 8 | Backup restore after a fresh install | SYS-022, WF-014 | 10 |
| 9 | Forced reboot during a scheduled reminder | SYS-019, WF-009 | 11 |
| 10 | Timezone change +3 h while reminders pending | SYS-020, WF-013 | 12 |
| 11 | Notification reliability under battery-saver | SYS-016, SYS-017, WF-009 | 13 |

## Daily log

For each of the 14 days, copy this block into a fresh row and fill
it in. Append a one-line `Notes:` after the block with anything
unusual — the run only stays useful if anomalies are recorded, not
just successes.

```
### Day N — YYYY-MM-DD
- Build SHA: ____________
- 3-gate status:
  - `dart format`: ✓ / ✗
  - `flutter analyze --fatal-infos`: ✓ / ✗
  - `flutter test`: ✓ / ✗ (N passing)
- Coverage (lib/services, lib/screens, lib/reminders, lib/missions): __%
- Scenarios run today (from matrix): ___, ___, ___
- Results: ✓✓✓ / ✓△✓ / ✗
- Reminder latency observation (eyeball):
  - Drink water — within ±60 s? yes / no (record delta)
  - Morning routine — within ±60 s? yes / no (record delta)
  - Call Mom / Read — within ±60 s? yes / no (record delta)
- Any reliability banner ("may be late") visible? yes / no
- Any duplicate reminders? yes / no
- Any missed reminders? yes / no (record the habit + time)
- Completion rate (day): ___ / 4 active presets
- Notes: ___
```

### Day 1 — YYYY-MM-DD
- Build SHA: `5f4f31d` (Phase 6 tip at kickoff)
- 3-gate status:
  - `dart format`: ✓
  - `flutter analyze --fatal-infos`: ✓
  - `flutter test`: ✓ (237 passing)
- Coverage: __%
- Scenarios run today (from matrix): 1, 2, 3, 4, 5
- Results: _tbd_
- Reminder latency observation (eyeball): _tbd_
- Any reliability banner visible? _tbd_
- Any duplicate reminders? _tbd_
- Any missed reminders? _tbd_
- Completion rate (day): _tbd_
- Notes: _tbd_

_(Copy the Day 1 block above for Days 2..14.)_

## Per-scenario acceptance criteria

A scenario is "passed" only when the criterion in its row is met
across the run. Partial credit is recorded in the daily notes, not
the cell.

| # | Scenario | Acceptance criterion |
|---|----------|----------------------|
| 1 | Drink water | ≥ 80% of the 8 daily windows confirmed within ±15 min of the target. |
| 2 | Call Mom | 5/5 occurrences completed; each mission pass in ≤ 60 s; streak unbroken at end of run. |
| 3 | Morning routine | 14/14 occurrences fired within ±60 s; chain executed in ≤ 30 s on weekdays; weekend time respected. |
| 4 | Daily todo | 3/3 completions recorded; no false "missed" entry after completion. |
| 5 | Read 20 min | 14/14 occurrences fired; Type phrase acceptance case-insensitive + trim works. |
| 6 | Rest day | Morning routine streak unbroken; budget decremented by 1 for the month. |
| 7 | Snooze | Call Mom fires again in 10 min; original occurrence is marked snoozed (not missed). |
| 8 | Backup restore | All 4 active presets appear post-restore; completion log is intact; rest-day budget is correct. |
| 9 | Forced reboot | The 06:30 reminder fires within ±60 s of the target post-reboot; no duplicate. |
| 10 | Timezone change | All pending reminders re-anchor to the new zone; no fires skipped, no duplicates. |
| 11 | Battery-saver reliability | A scheduled reminder fires within ±15 min of target while battery-saver is on; banner shows "may be late". |

## 3-gate log (every commit during the run)

Every commit on `main` during the 14 days must pass the 3-gate
_before_ push. The user pastes the tail of the three commands into
a row. If a commit lands without a row here, the run is paused
until it is backfilled.

| SHA | `dart format` | `flutter analyze` | `flutter test` (count) | Notes |
|-----|---------------|-------------------|------------------------|-------|
| `5f4f31d` | ✓ | ✓ | ✓ (237) | Phase 6 tip. Kickoff baseline. |

_(Append a row per commit during the run.)_

## Exit criteria

The run is **accepted** when, at Day 14:

1. Every scenario in the matrix has a non-empty cell.
2. ≥ 70% of the active presets show ≥ 70% completion over the
   14 days. (`completion_rate_overall = sum(per-habit completions)
   / sum(per-habit opportunities)`. A "rest day" counts as
   completed; a snooze counts as completed; a missed window counts
   as missed.)
3. No `✗` in the 3-gate log for the run period.
4. The reliability scenarios (8, 9, 10, 11) all passed.
5. The user has signed off in the [Sign-off](#sign-off) section.

The run is **rejected** (and a Phase 8 fix loop begins) when any
of:

- 3+ scenarios ended in `✗`.
- A reliability scenario (8, 9, 10, 11) failed.
- A 3-gate was skipped or regressed.

## Sign-off

The run is closed by a single line:

```
Accepted on YYYY-MM-DD by <user>. Final SHA: <git rev-parse HEAD>.
```

If rejected, append a Phase 8 plan link instead.

## Traceability

| Artifact | This document |
|----------|---------------|
| `plan.md` § Initial milestones | Acceptance is milestone 4 of v0.1. |
| `v0_1_baseline.md` § Acceptance Test Set | The 11 scenarios are the test set, expanded. |
| `conops.md` § Normal Operational Scenario | Daily routine maps directly to Day N template. |
| `workflows.md` WF-001..WF-016 | Each scenario cites its WF- IDs. |
| `requirements.md` SYS-001..SYS-030 | The scenario matrix cites the exercised SYS- IDs. |
| `traceability_matrix.md` | Every SYS- ID in the matrix has a row in the per-scenario acceptance table above. |
| `mission_catalog.md` | Scenarios 2, 3, 5 exercise the 5 mission types. |
| `notification_reliability.md` | Scenarios 9, 10, 11 are the real-device counterpart of the integration tests in `test/reminders/`. |
| `decision_record.md` | The "no `INTERNET`" and "no `CALL_PHONE`" decisions are enforced by the absence of those permissions in the manifest — no new code ships during the run that adds them. |
| `test/` (237+ tests as of Phase 6) | The 3-gate is the contract; any test regression during the run fails the run. |

## What is explicitly out of scope for this run

- Multi-user / multi-device sync. v0.1 is single-user, single-device.
- Cloud backup. Backup is local-only via SAF; the file lives in a
  user-picked folder.
- iOS. v0.1 is Android only. The iOS port is a v0.2+ candidate.
- Encryption at rest for backups. v0.1 backups are plain JSON;
  encryption is a v0.2 feature behind a user passphrase.
- New mission types. The 5 mission types in the catalog are the
  contract for v0.1. Barcode / QR / Photo are v0.2.
- The home widget. The home widget is listed in
  `v0_1_baseline.md` § Lean MVP and is implemented in the
  Kotlin side, but acceptance is on the in-app loop. The widget
  is verified manually (visible on home screen, tap-to-open) but
  is not in the pass/fail matrix.

If any of the above sneaks into the run, it is a scope creep; cut
it back to the matrix and ship the in-scope fix.
