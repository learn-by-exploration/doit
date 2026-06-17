# v0.5 — Rename to "do it" + wire real Android permissions into onboarding

Status: **in flight**, 2026-06-16. The v0.4b-release-fix-2
build shipped at `1bcc29f` and is installed on the user's
Samsung SM-S918B. v0.5 closes two issues that build surfaced:

1. **The app "looks dummy"** because the persisted
   `firstLaunchCompleted` flag is `true` (v0.4a.3, SYS-059)
   but the [v0.1 onboarding stub](lib/screens/onboarding.dart)
   was shipped as a **visual walkthrough**, not a real
   permission flow. The four "Allow" / "Pick folder" CTAs all
   did `setState(() => _step++)` — they never called
   `permission_handler`. v0.5 wires the CTAs to a new
   `PermissionService` that returns a sealed `PermissionResult`.
2. **The name "Streak" doesn't fit anymore.** The user wants
   the app to be called **"do it"** (lowercase, with a space)
   and wants a full rename — package id, directory, Kotlin
   package, channel names, task names, docs, tests. "Streak"
   remains the name of the *feature* (consecutive-day
   tracking); the `StreakCalculator` / `StreakService` /
   `StreakSnapshot` identifiers stay — they describe the
   feature, not the app.

This is the **left-side** V-Model doc for v0.5. The
right-side gate is
[`v0_5_release_checklist.md`](v0_5_release_checklist.md).
v0.5 is a **fix-loop** milestone, not a feature milestone —
the two items above are the fix. v0.6 (reliability) and
v0.7 (polish) follow.

## Why v0.5 exists

The user installed the v0.4b-release-fix-2 build (`1bcc29f`)
on a real device and reported two issues:

- **Onboarding is non-functional.** The four rationale
  screens render, the "Allow" / "Pick folder" buttons are
  tappable, and tapping them does **not** show a system
  dialog. The user is dropped straight on the Home screen
  because `firstLaunchCompleted == true` from the v0.4a.3
  install, but the v0.1 onboarding was a stub.
- **The app's name is "Streak".** That name describes the
  *consecutive-day tracking* feature, not the app the user
  has in mind. The user wants the app to be called "do it"
  — display name, package id, directory, notification
  channel, WorkManager task, docs.

v0.5 fixes both. The two are interleaved because the rename
touches every file the permission wiring also touches, and
doing them as one milestone produces one signed-off build
(instead of two APK-install cycles on the user's primary
phone).

## Scope

Six work items, one commit each, 3-gate green at every
commit:

| ID | What | Why | Why not earlier |
|----|------|-----|------------------|
| v0.5a | Rename: "Streak" → "do it" (app-level identifiers only) | The user asked for the rename. The `Streak*` feature-level identifiers stay. | Deferred: the user wanted a v0.4 release first; the rename waited for a stable base. |
| v0.5b | `PermissionService` singleton + sealed `PermissionResult` | The widget layer cannot call the platform directly (per `.claude/rules/lib-screens.md`); a service seam is required to make the v0.5c wiring testable. | Deferred: v0.1's onboarding rationale UI was a stub; the seam was not needed for a stub. |
| v0.5c | Wire onboarding "Allow" / "Pick folder" buttons to `PermissionService` | The v0.1 buttons did `setState(() => _step++)` — no real permission request was ever issued. v0.5 makes the rationale UI do what it always said it did. | Deferred: same as v0.5b. |
| v0.5d | Settings → "Permissions" tile (recovery for "Don't ask again") | A user who taps "Don't ask again" on any of the four onboarding steps needs an in-app recovery path. Pre-v0.5 the only path was "reinstall". | Deferred: the tile requires a `PermissionService.statuses` `ValueNotifier` and a sealed `PermissionResult` — both gated on v0.5b. |
| v0.5e | Release APK rebuild + on-device verification | The applicationId changed (`com.common_games.streak` → `com.doit`), which forces an uninstall-before-install. The new APK must be built and verified on a real device. | Deferred: the rename is the install boundary. (The earlier v0.5a draft picked `com.doit.package`; v0.5e-fix renames to `com.doit` because `package` is a Java reserved keyword.) |
| v0.5f | Sign-off + CHANGELOG [0.5.0] | v0.5 close-out. Moves the v0.5 entries from `[Unreleased]` to `[0.5.0]`, closes the open-questions from v0.5d. | Deferred: cannot sign off without the on-device verification. |

## Constraints (v0.5 floor — same as v0.4)

The v0.5 floor is the v0.4 floor: no `INTERNET`, no
analytics, no telemetry, no cloud sync, no account, no
advertising SDK, no third-party crash reporter, no
`CALL_PHONE`, no `READ_CALL_LOG`, no `RECORD_AUDIO`. v0.5a
(the rename) does **not** add network code. v0.5b / v0.5c /
v0.5d (the permission wiring) does **not** add network code.
v0.5e (the release rebuild) does **not** add network code.

v0.5 does **not** loosen any v0.4 constraint. The four
runtime permissions the wiring requests
(`POST_NOTIFICATIONS`, `READ_CONTACTS`,
`SCHEDULE_EXACT_ALARM`, backup folder) are all
**local-only** — none of them enable a network call. The
backup-folder SAF URI is written to local SharedPreferences
(`SettingsService.backupFolderUri`); the file written to
that folder is a local JSON envelope; the workmanager
periodic backup scheduler is local; the encrypted envelope
uses the v0.4c.1 AES-256-GCM path.

v0.5 does **not** re-name the `StreakCalculator` /
`StreakService` / `StreakSnapshot` /
`streak_calculator.dart` / `streak_service.dart` /
`StreakConfig` identifiers. They are **feature-level**
names, not app-level names. Renaming them is out of scope.

## System Requirements (new in v0.5)

v0.5 owns the following SYS- IDs in
[`requirements.md`](requirements.md):

- **SYS-063** — `POST_NOTIFICATIONS` requested at
  onboarding step 0 (Android 13+). The system shows the
  runtime dialog; on `granted` the step advances.
  Verification: `test/screens/onboarding_permission_wiring_test.dart`
  "tapping Allow on step 0 calls requestNotifications and
  advances on granted".
- **SYS-064** — `READ_CONTACTS` requested at onboarding
  step 1 (cadence-style habits). On `granted` the step
  advances. The Settings → Permissions tile is the recovery
  affordance for `permanentlyDenied`. Verification:
  `test/screens/settings_permissions_test.dart` "tapping
  Settings on a permanentlyDenied row calls openAppSettings
  (SYS-064)".
- **SYS-065** — `SCHEDULE_EXACT_ALARM` requested at
  onboarding step 2 (Android 12+ policy permission). The
  runtime `request()` returns `denied`; the step surfaces
  a "Open Android settings" `FilledButton.tonal` that
  deep-links to the system Alarms & reminders page via
  `PermissionService.openAppSettings()`. The home-screen
  reliability banner reads the on-demand probe; the
  Settings → Permissions tile is the recovery affordance.
  Verification: `notification_reliability.md` layer 5,
  bullet 1 copy update; the `_PermissionTile` "Settings"
  button is rendered on `permanentlyDenied` only.
- **SYS-066** — `SettingsService.backupFolderUri`
  `ValueNotifier<String?>` (defaults `null`); SAF folder
  picker at onboarding step 3. The step advances on
  `picked` or `cancelled` (skippable per ADR-015). The
  Settings → `_BackupFolderTile` is the post-onboarding
  recovery affordance for users who skipped or revoked
  the SAF grant. Verification:
  `test/services/settings_service_backup_uri_test.dart`
  (3 tests); `test/screens/settings_permissions_test.dart`
  "tapping the re-pick button calls
  `requestBackupFolder` and persists the picked path".

## Architecture decisions (new in v0.5)

Three ADRs are appended to
[`decision_record.md`](decision_record.md):

- **ADR-014** — Onboarding permission order:
  notifications → contacts → exact alarm → backup folder.
  The order is the user's cognitive surface: the two
  runtime prompts the user is most likely to grant come
  first; the policy permission that requires a system
  settings deep-link comes third; the skippable backup
  folder comes last.
- **ADR-015** — Backup folder is skippable on onboarding.
  The runtime permission status enum has no `skippable`
  field; the seam (`BackupFolderResult`) is a separate
  sealed class that the dispatch in
  `_handleStepCta` matches on. A user who cancels the
  SAF picker advances without persisting.
- **ADR-016** — Permission service seam: sealed result,
  singleton, on-demand probe. The
  `lib/services/permission_service.dart` singleton follows
  the `_ready`-gated init pattern from
  `.claude/rules/lib-services.md`. The sealed
  `PermissionResult` (`granted` / `denied(canOpenSettings)`
  / `permanentlyDenied`) is the only thing the widget layer
  ever sees. The Settings → Permissions tile
  (`_PermissionsRow` + `_PermissionTile` +
  `_BackupFolderTile`) is the recovery affordance for
  users who hit "Don't ask again".
- **ADR-017** — v0.5e-fix: `com.doit.package` is an invalid
  Java namespace; rename to `com.doit`. The v0.5a draft
  picked `com.doit.package` for `applicationId` and
  `namespace` (mirroring the Dart package name `doit` with
  `package` as a namespace segment). The 3-gate was green
  (407/407) and the v0.5a pin tests asserted the value
  *exactly*. At v0.5e, `flutter build appbundle --release`
  failed: `package` is a Java reserved keyword (JLS §3.9)
  and cannot appear as a segment of a Java package name.
  Five surgical changes: `build.gradle.kts`
  (`com.doit` / `com.doit`), `AndroidManifest.xml`
  (`com.doit.FIRE_ALARM`), `kotlin/com/doit/package/` →
  `kotlin/com/doit/` via `git mv`, `release_signing_test`
  rewrite + regression-guard
  `isNot(contains('com.doit.package'))`, four doc files
  updated. The release AAB (61.0 MB) and APK (69.8 MB)
  rebuild successfully. Lesson: a green 3-gate does not
  mean a green build; pin tests for *invalid* values
  matter as much as pin tests for *exact* values;
  stylistic redundancy in identifiers is a smell, not a
  virtue.

## Approval status

- **2026-06-16**: v0.5 plan approved; v0.5a (rename) lands
  first, then v0.5b (`PermissionService` + sealed result),
  then v0.5c (wiring), then v0.5d (Settings → Permissions
  tile + ADR-016), then v0.5e (release APK + on-device
  verification), then v0.5f (sign-off).
- **v0.5e** is the user's hands-on step: the seven-step
  on-device verification on a real SM-S918B device. The
  checklist sign-off line is the gate.

## What is explicitly out of scope for v0.5

- **Battery optimization
  (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`)** and
  **OEM auto-start detection**. Both are in the v0.1
  baseline's "Reliability" section but require separate
  manifest lines, OEM-detection logic, and a separate SYS- ID.
  They are v0.6 work.
- **The `PermissionService.statuses` `ValueNotifier` driving
  the home-screen reliability banner.** v0.5d's tile reads
  the notifier; the home-screen banner still uses the
  `ReminderService.reliability` sealed enum. A unified
  source-of-truth notifier is a v0.6 follow-up.
- **Localization of the new copy.** All new strings (the
  "Go to Android Settings" button, the "Granted" / "Not
  granted" status text, the "Permissions" section header)
  are hard-coded English. Non-English v0.5 is a v0.6
  follow-up.
- **A "v0.5-pre data export"** that uses the v0.4c.1
  encrypted backup flow to preserve the user's existing
  local data (the "test" habit) across the
  applicationId-driven uninstall. v0.5e erases the user's
  data because the applicationId changes. The user can
  re-create the test habit after install.
- **Re-naming `StreakCalculator` / `StreakService` /
  `StreakSnapshot` / `streak_calculator.dart` /
  `streak_service.dart` / `StreakConfig`.** Feature-level
  identifiers stay.
- **v0.2f (VIP escalation, `READ_PHONE_STATE` permission).**
  Still deferred; v0.7 follow-up.
- **Crash reporting / analytics / telemetry.** No
  third-party SDKs. v0.4 floor stands.
- **Multi-user / multi-device sync.** Out of project scope.
- **A new app icon.** v0.5 keeps the default Flutter icon.
  A custom `do it` icon is a v0.7 follow-up.
- **A new launcher splash.** v0.5 keeps the default Flutter
  splash. A custom splash is a v0.7 follow-up.

## Traceability

| Artifact | This document |
|----------|---------------|
| `requirements.md` SYS-063..SYS-066 | The SYS- IDs above. |
| `lib/services/permission_service.dart` | SYS-063..066 — the singleton-with-`_ready` seam. |
| `lib/services/permission_result.dart` | SYS-063..066 — the sealed `PermissionResult` and `BackupFolderResult`. |
| `lib/services/settings_service.dart` | SYS-066 — `ValueNotifier<String?> backupFolderUri`. |
| `lib/screens/onboarding.dart` | SYS-063..066 — `_handleStepCta` dispatch on `_step`. |
| `lib/screens/settings.dart` | SYS-063..066 — the new `Permissions` section (`_PermissionsRow` + `_PermissionTile` + `_BackupFolderTile`). |
| `docs/v_model/notification_reliability.md` | SYS-065 — layer 5 bullet 1 copy update (onboarding probe + Settings → Permissions recovery). |
| `decision_record.md` | ADR-014, ADR-015, ADR-016. |
| `pubspec.yaml` + `lib/build_info.dart` | v0.5a — `name: doit`, `version: 0.5.0+6`. |
| `android/app/build.gradle.kts` + `AndroidManifest.xml` | v0.5a — `applicationId = "com.doit"`, `android:label="do it"`. (The earlier draft picked `com.doit.package`; v0.5e-fix renames to `com.doit` because `package` is a Java reserved keyword.) |
| `lib/reminders/reminder_bridge.dart` | v0.5a — `MethodChannel('doit/reminders')`. |
| `lib/services/notification_service.dart` | v0.5a — channel id `'doit.reminders'`. |
| `lib/services/backup_scheduler.dart` | v0.5a — task name `'doit.backup.nightly'`. |
| `lib/services/reminder_service.dart` | v0.5a — test reminder habit id `'doit.test_reminder'`. |
| `lib/main.dart` + `lib/screens/onboarding.dart` | v0.5a — `'Welcome to do it'`, `MaterialApp.title = 'do it'`. |
| `test/release_signing_test.dart` | v0.5a — rename-pins (`applicationId`, channel names, task name). |
| `test/services/permission_service_test.dart` | v0.5b — 9 service tests pinning the sealed result. |
| `test/services/settings_service_backup_uri_test.dart` | v0.5c — 3 tests pinning the `backupFolderUri` notifier. |
| `test/screens/onboarding_permission_wiring_test.dart` | v0.5c — 6 tests pinning the wiring. |
| `test/screens/settings_permissions_test.dart` | v0.5d — 4 tests pinning the recovery tile. |
| `CHANGELOG.md` | v0.5 `[Unreleased]` section (v0.5a..v0.5e subsections); v0.5f moves to `[0.5.0]`. |
| `PRIVACY.md` "Honest caveats" | Updated by v0.5e. |
| `v0_5_release_checklist.md` | The right-side gate. |
| `implementation_status.md` | v0.5a..v0.5f rows. |
| `traceability_matrix.md` | SYS-063..SYS-066 rows. |
| `docs/v_model/open_questions.md` #5, #6 | Closed by v0.5d (ADR-016). |
