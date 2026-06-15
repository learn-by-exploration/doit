# v0.4 — Polish + privacy (close the v0.3 contract)

Status: **in flight**, 2026-06-14. The v0.3 sideload-to-friends
release shipped at `5ebb441`; this milestone closes the remaining
contract items the v0.3 docs flagged as v0.4 line items.

This is the **left-side** V-Model doc for v0.4. The right-side
gate is [`v0_4_release_checklist.md`](v0_4_release_checklist.md).
v0.4 is the last v0.x milestone before the v1.0 sign-off — the
focus is **contract closure**, not new features. The
[v0.2f VIP escalation](v0_2_proposal.md) is a separate gate.

## Why v0.4 exists

v0.3 shipped a release-signed Android build of the v0.2 surface
to a few trusted users. The v0.3 docs (`v0_3_release_baseline.md`
and `PRIVACY.md`) flagged a small set of items as "v0.4 line
items" — not blocking the v0.3 release, but documented as known
gaps the user will want closed before the v1.0 cut. v0.4 closes
those gaps. It also closes the one "Not started" item in
[`implementation_status.md`](implementation_status.md): the CI
3-gate that every doc references but no GitHub Actions workflow
actually exists for.

## Scope

Six work items, one commit each, 3-gate green at every commit:

| ID | What | Why | Why not earlier |
|----|------|-----|------------------|
| v0.4a.1 | CI 3-gate (GitHub Actions) | The contract that every doc cites. | Deferred: requires the workflow file + a static-analysis test. |
| v0.4a.2 | `CHANGELOG.md` (closes open question #20) | The v0.3 cut is the right moment to start the release-process doc. | Deferred: open question #20 said "v0.2 once the first release is cut." |
| v0.4a.3 | `firstLaunch` persisted flag | PRIVACY.md discloses "Onboarding re-appears on every reinstall." A `SharedPreferences`-backed flag kills the caveat. | Deferred: v0.1 was fine for personal use; the v0.3 sideload makes the wart visible. |
| v0.4b | WorkManager periodic backup | The `workmanager: ^0.6.0` dep is in `pubspec.yaml` but no Dart code calls it. PRIVACY.md discloses "scheduling call not yet wired." | Deferred: v0.1 / v0.2 / v0.3 backups were on-demand only. |
| v0.4c.1 | Backup encryption at rest | PRIVACY.md discloses "plain JSON, not encrypted." Bump `kBackupFormatVersion` to 2; AES-GCM with a user passphrase. | Deferred: encryption requires a passphrase UI, key derivation, and on-disk format change. |
| v0.4c.2 | TalkBack / a11y static review | Every screen has `Semantics` labels per `.claude/rules/lib-screens.md`; a code-level pass is buildable, the device pass is the user's hands-on step. | Deferred: v0.1–v0.3 lacked the v0.4 PR-shaped work. |

## Constraints (v0.4 floor — same as v0.3)

The v0.4 floor is the v0.3 floor: no `INTERNET`, no analytics, no
telemetry, no cloud sync, no account, no advertising SDK, no
third-party crash reporter, no `CALL_PHONE`, no `READ_CALL_LOG`,
no `RECORD_AUDIO`. v0.4c.1 (backup encryption) does **not** add
network code; the encryption is local-only with a user-supplied
passphrase. v0.4b (WorkManager backup) does **not** add network
code; the scheduler is local. v0.4c.2 (a11y) adds `Semantics`
labels only; no behavior change.

v0.4 does **not** loosen any v0.3 constraint. The v0.2f VIP
escalation is a separate gate that adds `READ_PHONE_STATE` (a
permission CLAUDE.md permits but v0.3 did not need).

## System Requirements (new in v0.4)

v0.4 owns the following SYS- IDs in
[`requirements.md`](requirements.md):

- **SYS-057** — CI 3-gate. A GitHub Actions workflow at
  `.github/workflows/ci.yml` runs `dart format`,
  `flutter analyze --fatal-infos`, and `flutter test` on every
  PR and push to `main`. A static-analysis test
  (`test/ci_workflow_test.dart`) parses the workflow file and
  asserts the three steps are present.
- **SYS-058** — `CHANGELOG.md` at repo root with sections for
  v0.1, v0.2, v0.3, and v0.4. Open question #20.
- **SYS-059** — `firstLaunch` persisted flag. A
  `SharedPreferences`-backed boolean in `SettingsService`
  replaces the hard-coded `true` in `lib/main.dart`. A test
  (`test/services/first_launch_persisted_test.dart`) asserts the
  flag persists across "app restarts" (close + reopen).
- **SYS-060** — WorkManager periodic backup. The
  `BackupService.scheduleNightlyBackup()` method registers a
  `workmanager` periodic task that invokes the existing
  `runBackup()` entrypoint. A test asserts the scheduler is
  called with the right task name and frequency.
- **SYS-061** — Backup encryption at rest. Bump
  `kBackupFormatVersion` to 2. The export flow takes a
  user-supplied passphrase, derives an AES-256-GCM key via
  PBKDF2-HMAC-SHA256 (≥ 100,000 iterations), and writes an
  envelope `{"version": 2, "kdf": {...}, "ciphertext": ...}`.
  The import flow supports v1 (plain JSON, for back-compat) and
  v2 (passphrase + encrypted). A test
  (`test/services/backup_encryption_test.dart`) round-trips with
  a passphrase and asserts the v1 read path still works on the
  fixture.
- **SYS-062** — `Semantics` labels on every interactive element
  in `lib/screens/*.dart` and `lib/widgets/*.dart`. A static
  analysis test (`test/a11y/semantics_labels_test.dart`) walks
  the widget tree of every public screen and asserts every
  `Button`, `IconButton`, `ListTile`, `TextField`, and tap-able
  `GestureDetector` has a `Semantics` label or `tooltip` /
  `semanticLabel`.

## Approval status

- **2026-06-14**: v0.4 plan approved; v0.4a.1 / v0.4a.2 / v0.4a.3
  land first, then v0.4b (WorkManager backup), then v0.4c.1
  (encryption), then v0.4c.2 (a11y static review).
- **v0.4d (sign-off)** is the user's hands-on step: the
  wiped-device a11y pass on a real TalkBack-enabled phone or
  emulator. The checklist sign-off line is the gate.

## What is explicitly out of scope for v0.4

- **v0.2f VIP escalation (`READ_PHONE_STATE` permission).**
  Separate gate, different milestone. v0.4 does **not** add
  `READ_PHONE_STATE`.
- **R8 / minify / ProGuard.** v0.3 turned it off; v0.4 keeps it
  off. The decision is stable.
- **Backup upload to anywhere.** v0.4c.1 encrypts the backup
  file but does **not** upload it. The v0.3 "no cloud backup"
  floor stands.
- **Crash reporting / analytics / telemetry.** No third-party
  SDKs. v0.3 floor stands.
- **Multi-user / multi-device sync.** Out of project scope.
- **Localization.** v0.4 is English-only; non-English v0.5+.
- **Play Store metadata.** Sideload-only. v0.3 floor stands.

## Traceability

| Artifact | This document |
|----------|---------------|
| `requirements.md` SYS-057..SYS-062 | The SYS- IDs above. |
| `.github/workflows/ci.yml` | SYS-057. |
| `CHANGELOG.md` | SYS-058. |
| `lib/services/settings_service.dart` | SYS-059 (firstLaunch flag). |
| `lib/services/backup_service.dart` | SYS-060 (WorkManager schedule) + SYS-061 (encryption). |
| `lib/screens/*.dart`, `lib/widgets/*.dart` | SYS-062 (Semantics). |
| `docs/v_model/open_questions.md` #20 | Closed by SYS-058. |
| `v0_3_release_baseline.md` § Out of scope | v0.4 closes the items flagged here. |
| `PRIVACY.md` | v0.4a.3 and v0.4b and v0.4c.1 update the caveats. |
| `v0_4_release_checklist.md` | The right-side gate. |
| `implementation_status.md` | v0.4a..v0.4d rows. |
| `traceability_matrix.md` | SYS-057..SYS-062 rows. |
| `decision_record.md` | New ADRs for the encryption choice (KDF, cipher, version bump). |
