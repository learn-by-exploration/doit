# v0.4 Release Checklist (right-side gate)

Status: **in flight** — created 2026-06-14 alongside
[`v0_4_release_baseline.md`](v0_4_release_baseline.md). v0.4 is
contract-closure work: it closes the v0.3 contract items flagged
as v0.4 line items, plus the one "Not started" item in
[`implementation_status.md`](implementation_status.md) — the
CI 3-gate that every doc references but no GitHub Actions
workflow actually exists for.

## Purpose

v0.4 ships six work items, one commit each, 3-gate green at
every commit. v0.4 is the last v0.x milestone before the v1.0
sign-off — the focus is **contract closure**, not new features.
The [v0.2f VIP escalation](v0_2_proposal.md) is a separate gate
and is **not** in v0.4 scope.

## Setup

Before the v0.4 work:

1. `flutter pub get` on a clean clone.
2. `dart format --output=none --set-exit-if-changed .` clean.
3. `flutter analyze --fatal-infos` clean.
4. `flutter test` green (328 / 328 at the v0.3 tip).
5. `git status` clean; the v0.3 tip is `5ebb441`.

## SYS- exit criteria

v0.4 is accepted when every row in the table below is "yes":

| # | SYS- | What the user / CI verifies | Yes / No |
|---|------|------------------------------|----------|
| 1 | SYS-057 | A `.github/workflows/ci.yml` exists with three jobs / steps (`dart format`, `flutter analyze --fatal-infos`, `flutter test`). The CI run is green on the v0.4 tip. The test `test/ci_workflow_test.dart` parses the workflow and asserts the three steps. | yes (`608483e`; the green CI run on `main` requires the user's hands-on merge of the workflow file into the GitHub repo). |
| 2 | SYS-058 | A `CHANGELOG.md` exists at the repo root with sections for v0.1, v0.2, v0.3, and v0.4. Open question #20 is closed. | yes (`7bbb2aa`). |
| 3 | SYS-059 | The `firstLaunch` flag is persisted via `SharedPreferences`. The `lib/main.dart` `firstLaunch` is no longer hard-coded `true`. The test `test/services/first_launch_persisted_test.dart` asserts the flag persists across "app restarts" (close + reopen). `PRIVACY.md` no longer discloses the "Onboarding on every reinstall" caveat. | yes (v0.4a.3). |
| 4 | SYS-060 | `BackupService.scheduleNightlyBackup()` registers a `workmanager` periodic task. The test asserts the scheduler is called with the right task name and frequency. `PRIVACY.md` no longer discloses the "scheduling call not yet wired" caveat. | ___ |
| 5 | SYS-061 | `kBackupFormatVersion` is 2. The export flow takes a user-supplied passphrase, derives an AES-256-GCM key via PBKDF2-HMAC-SHA256 (≥ 100,000 iterations), and writes an envelope. The import flow supports v1 (plain JSON, back-compat) and v2 (passphrase + encrypted). The test `test/services/backup_encryption_test.dart` round-trips with a passphrase. `PRIVACY.md` no longer discloses the "plain JSON backups" caveat. | ___ |
| 6 | SYS-062 | Every interactive element in `lib/screens/*.dart` and `lib/widgets/*.dart` has a `Semantics` label (or `tooltip` / `semanticLabel`). The test `test/a11y/semantics_labels_test.dart` walks the widget tree of every public screen and asserts the labels. The user's hands-on TalkBack pass on a real device or emulator is the v0.4d step. | ___ |

## Per-phase acceptance criteria

### v0.4a.1 — CI 3-gate

The CI workflow file declares the three steps in the right order
(`dart format` → `flutter analyze --fatal-infos` → `flutter test`).
The workflow triggers on `pull_request` and `push` to `main`. The
test parses the workflow and asserts the structure. The first
green CI run lands on the v0.4a.1 commit.

### v0.4a.2 — CHANGELOG.md

A `CHANGELOG.md` exists with sections for v0.1, v0.2, v0.3, and
v0.4. Each section lists the headline features and the bug fixes.
The v0.4 section is appended in v0.4d (the sign-off commit). The
PR for v0.4a.2 lands the v0.1 / v0.2 / v0.3 sections in retro­
spect.

### v0.4a.3 — firstLaunch persisted flag

`lib/main.dart`'s `firstLaunch` reads from `SettingsService.firstLaunchCompleted`,
which is a `SharedPreferences`-backed boolean. The test closes the
service, reopens it, and asserts the flag is still `false` (or
`true`, depending on the setup). `PRIVACY.md` no longer discloses
the caveat.

### v0.4b — WorkManager periodic backup

`BackupService.scheduleNightlyBackup()` calls
`Workmanager().registerPeriodicTask(...)` with the task name
`streak.backup.nightly` and a 24-hour frequency. The test mocks
the `Workmanager` interface and asserts the call. The Kotlin
side (in `android/app/src/main/kotlin/.../BackupWorker.kt`)
registers the Dart callback via `WorkmanagerPlugin`'s
`setPluginRegistrantCallback`. `PRIVACY.md` no longer discloses
the caveat.

### v0.4c.1 — Backup encryption

`kBackupFormatVersion` is 2. The export flow:
1. Generates a 16-byte salt via `Random.secure()`.
2. Derives a 32-byte key via PBKDF2-HMAC-SHA256 (≥ 100,000
   iterations).
3. Generates a 12-byte nonce.
4. Encrypts the JSON envelope with AES-256-GCM.
5. Writes `{"version": 2, "kdf": {"name": "pbkdf2-hmac-sha256",
   "iterations": 100000, "saltB64": "..."}, "ciphertextB64": "...",
   "nonceB64": "..."}` to the file.

The import flow:
1. Parses the JSON envelope.
2. If `version == 1`, runs the v1 plain-JSON path (back-compat).
3. If `version == 2`, prompts for the passphrase, derives the
   key, decrypts, then runs the v1 import logic on the
   decrypted JSON.

The test (`test/services/backup_encryption_test.dart`) round-trips
with a passphrase and asserts the v1 read path still works on a
v1 fixture.

### v0.4c.2 — TalkBack / a11y static review

Every `Button`, `IconButton`, `ListTile`, `TextField`, and
tap-able `GestureDetector` in `lib/screens/*.dart` and
`lib/widgets/*.dart` has a `Semantics` label or `tooltip` /
`semanticLabel`. The static-analysis test
(`test/a11y/semantics_labels_test.dart`) walks the widget tree
of every public screen and asserts the labels. The user's
hands-on TalkBack pass on a real device is the v0.4d step.

## 3-gate log (every commit during v0.4)

Every commit on `main` during v0.4 must pass the 3-gate _before_
push. The user pastes the tail of the three commands into a row.
If a commit lands without a row here, the milestone is paused
until it is backfilled.

| SHA | `dart format` | `flutter analyze` | `flutter test` (count) | Notes |
|-----|---------------|-------------------|------------------------|-------|
| `608483e` | clean (0 changed) | clean (41, matches v0.3 baseline) | 333 / 333 (328 prior + 5 new) | v0.4a.1: CI 3-gate workflow. |
| `7bbb2aa` | clean (0 changed) | clean (41, matches v0.3 baseline) | 333 / 333 (unchanged) | v0.4a.2: CHANGELOG.md (v0.1 / v0.2 / v0.3 sections). |
| `________` | _tbd_ | _tbd_ | _tbd_ | v0.4a.3: firstLaunch persisted flag. |
| `________` | _tbd_ | _tbd_ | _tbd_ | v0.4b: WorkManager periodic backup scheduler. |
| `________` | _tbd_ | _tbd_ | _tbd_ | v0.4c.1: backup encryption at rest. |
| `________` | _tbd_ | _tbd_ | _tbd_ | v0.4c.2: TalkBack / a11y static review. |
| `________` | _tbd_ | _tbd_ | _tbd_ | v0.4d: sign-off + v0.4 CHANGELOG section. |

_(Append a row for each v0.4 commit.)_

## Exit criteria

v0.4 is **accepted** when, at the v0.4d commit:

1. Every row in the [SYS- exit criteria](#sys--exit-criteria)
   table is "yes".
2. The 3-gate log table is complete (no missing rows for
   v0.4a.1..v0.4d).
3. The first green CI run on the v0.4 tip is recorded (row 1 of
   the SYS- exit criteria).
4. The user has signed off in the [Sign-off](#sign-off) section.

v0.4 is **rejected** (and a v0.4 fix loop begins) when any of:

- 3+ rows in the SYS- exit criteria table are "no".
- A 3-gate was skipped or regressed.
- A v0.3 regression surfaced in CI for the v0.4 build's SHA.

## Sign-off

The v0.4 release is closed by a single line:

```
Accepted on YYYY-MM-DD by <user>. Final SHA: <git rev-parse HEAD>.
```

If rejected, append a v0.5 fix-loop plan link instead.

## Traceability

| Artifact | This document |
|----------|---------------|
| `v0_4_release_baseline.md` | The left-side doc; the SYS- IDs and the v0.4 floor live there. |
| `requirements.md` SYS-057..SYS-062 | The SYS- exit criteria table cites each row. |
| `.github/workflows/ci.yml` | SYS-057 row 1. |
| `CHANGELOG.md` | SYS-058 row 2. |
| `lib/main.dart` + `lib/services/settings_service.dart` | SYS-059 row 3. |
| `lib/services/backup_service.dart` | SYS-060 row 4 + SYS-061 row 5. |
| `lib/screens/*.dart`, `lib/widgets/*.dart` | SYS-062 row 6. |
| `PRIVACY.md` | Updated by SYS-059, SYS-060, SYS-061. |
| `traceability_matrix.md` | Every SYS- ID in the SYS- exit criteria table has a row there. |
| `decision_record.md` | New ADRs for the encryption choice (KDF, cipher, version bump). |
| `implementation_status.md` | v0.4a..v0.4d rows. |
| `docs/v_model/open_questions.md` #20 | Closed by SYS-058. |
