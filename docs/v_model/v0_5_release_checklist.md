# v0.5 Release Checklist (right-side gate)

Status: **in flight** — created 2026-06-16 alongside
[`v0_5_release_baseline.md`](v0_5_release_baseline.md). v0.5
is a **fix-loop** milestone: it closes the v0.1 onboarding
stub and renames the app from "Streak" to "do it". v0.5 is
**not** a feature milestone — the v0.4 contract closure is
the previous milestone, and v0.6 (reliability) and v0.7
(polish) follow.

## Purpose

v0.5 ships six work items, one commit each, 3-gate green at
every commit. v0.5e is the user's hands-on step — the
seven-step on-device verification on a real SM-S918B device
— which is the right-side gate. v0.5f is the sign-off commit
that closes the milestone.

## Setup

Before the v0.5 work:

1. `flutter pub get` on a clean clone.
2. `dart format --output=none --set-exit-if-changed .` clean.
3. `flutter analyze --fatal-infos` clean.
4. `flutter test` green (377 / 377 at the v0.4b-release-fix-2
   tip).
5. `git status` clean; the v0.4b-release-fix-2 tip is
   `1bcc29f`.

## SYS- exit criteria

v0.5 is accepted when every row in the table below is "yes":

| # | SYS- | What the user / CI verifies | Yes / No |
|---|------|------------------------------|----------|
| 1 | SYS-063 | Onboarding step 0 ("Notifications") calls `PermissionService.requestNotifications()`; on `granted` the step advances. `test/screens/onboarding_permission_wiring_test.dart` "tapping Allow on step 0 calls requestNotifications and advances on granted" is green. | yes (v0.5c). |
| 2 | SYS-064 | Onboarding step 1 ("Contacts") calls `PermissionService.requestContacts()`; on `granted` the step advances. The Settings → `_PermissionTile` for `PermissionKind.contacts` renders the "Settings" `TextButton` on `permanentlyDenied` and deep-links to the system app-settings page. `test/screens/settings_permissions_test.dart` "tapping Settings on a permanentlyDenied row calls openAppSettings (SYS-064)" is green. | yes (v0.5c / v0.5d). |
| 3 | SYS-065 | Onboarding step 2 ("Exact alarms") calls `PermissionService.requestExactAlarm()`. The "Open Android settings" `FilledButton.tonal` is shown on `denied` (canOpenSettings: true) and on `permanentlyDenied`. `notification_reliability.md` layer 5 bullet 1 copy is updated to point at the on-demand probe + the Settings → Permissions tile recovery affordance. ADR-016 is appended to `decision_record.md`. | yes (v0.5c / v0.5d). |
| 4 | SYS-066 | `SettingsService.backupFolderUri` is a `ValueNotifier<String?>` (defaults `null`); `test/services/settings_service_backup_uri_test.dart` (3 tests) is green. Onboarding step 3 ("Backup folder") calls `PermissionService.requestBackupFolder()`; on `picked` the path is persisted via `SettingsService.setBackupFolderUri`; on `cancelled` the step advances (per ADR-015); on `error` the rationale text shows the message. The Settings → `_BackupFolderTile` "Re-pick" `TextButton` is rendered when a path is set; tapping it re-picks and persists. | yes (v0.5c / v0.5d). |
| 5 | App identity | `pubspec.yaml` `name:` is `doit`. `lib/build_info.dart` `kAppVersion` is `'0.5.0'`. `android/app/build.gradle.kts` `applicationId` is `com.doit` and `namespace` is `com.doit`. `AndroidManifest.xml` `android:label` is `"do it"`. `MethodChannel('doit/reminders')` is declared exactly once. The notification channel id is `'doit.reminders'`. The workmanager task name is `'doit.backup.nightly'`. The test reminder habit id is `'doit.test_reminder'`. The `test/release_signing_test.dart` v0.5a pin tests assert all of the above (and additionally assert no `com.doit.package` remnants). | yes (v0.5a, v0.5e-fix). |

## Per-phase acceptance criteria

### v0.5a — Rename: "Streak" → "do it"

- `pubspec.yaml` `name:` is `doit`. `version:` is `0.5.0+6`.
- `lib/build_info.dart` `kAppVersion` is `'0.5.0'`,
  `kAppVersionCode` is `6`.
- `android/app/build.gradle.kts` `applicationId` is
  `com.doit`; `namespace` is `com.doit`.
- `android/app/src/main/AndroidManifest.xml` `package` is
  `com.doit`; `android:label` is `"do it"`. (The manifest
  `package` attribute is no longer required in AGP 8.x — the
  `namespace` from `build.gradle.kts` is the source of
  truth — but do it pins it explicitly so the file's
  app-level identity is clear.)
- `android/app/src/main/kotlin/com/common_games/streak/` is
  renamed to `android/app/src/main/kotlin/com/doit/` via
  `git mv`; every `.kt` file's `package` declaration is
  updated. (The earlier v0.5a draft picked
  `com/doit/package/`; v0.5e-fix renames to `com/doit/`
  because `package` is a Java reserved keyword.)
- `lib/main.dart` `MaterialApp.title` is `'do it'`; the
  `showLicensePage(applicationName: 'do it', ...)` (if
  present) is updated.
- `lib/screens/onboarding.dart` `'Welcome to Streak'` (the
  app bar title) is `'Welcome to do it'`. The file-level
  comment is updated to reflect the v0.5 reality (no
  "visual walkthrough" wording).
- `lib/screens/settings.dart` About section's `'Streak'` is
  `'do it'`.
- `lib/reminders/reminder_bridge.dart`
  `MethodChannel('streak/reminders')` is
  `MethodChannel('doit/reminders')`. The Kotlin side mirrors.
- `lib/services/notification_service.dart` (or wherever the
  channel is created) `'streak.reminders'` is
  `'doit.reminders'`.
- `lib/services/backup_scheduler.dart`
  `'streak.backup.nightly'` is `'doit.backup.nightly'`.
- `lib/services/reminder_service.dart` test reminder habit id
  `'streak.test_reminder'` is `'doit.test_reminder'`; the
  corresponding test in `test/reminders/` updates its
  `expect` to match.
- Every Dart file that contains
  `import 'package:common_games/...` is updated to
  `import 'package:doit/...`.
- Every test file that contains `'Streak'` (the display
  name) or `'streak'` (an app-level id) is updated. Test
  files that assert `StreakCalculator.compute(...)` or
  `StreakService.instance` **stay** (feature identifiers).
- Every doc file under `docs/v_model/` and at the repo
  root (`CHANGELOG.md`, `README.md`, `LICENSE`, `PRIVACY.md`)
  — text content updated. The HISTORY rows in the v0.4 phase
  log stay as-is.
- `test/release_signing_test.dart` v0.5a pin tests assert
  the rename invariants.

**Rename verification grep:**
```
grep -rn "streak" --include="*.dart" --include="*.kts" \
  --include="*.kt" --include="*.xml" --include="*.yaml" \
  lib/ android/ test/ | \
  grep -v "StreakCalculator\|StreakService\|StreakSnapshot\|StreakConfig\|streak_calculator\|streak_service\|streak_snapshot\|kStreak" | wc -l
```
returns zero. The `Streak*` identifiers are feature-level,
intentionally kept.

### v0.5b — `PermissionService` singleton + sealed result

- `lib/services/permission_service.dart` is a singleton with
  a `Completer<void> _ready` (matches
  `lib/services/backup_service.dart` and
  `.claude/rules/lib-services.md`).
- The singleton exposes:
  `requestNotifications()`,
  `requestContacts()`,
  `requestExactAlarm()`,
  `requestBackupFolder()`,
  `openAppSettings()`,
  `init()`.
- `lib/services/permission_result.dart` is the sealed class:
  `PermissionResultGranted()`,
  `PermissionResultDenied({required bool canOpenSettings})`,
  `PermissionResultPermanentlyDenied()`,
  `BackupFolderPicked({required String path})`,
  `BackupFolderCancelled()`,
  `BackupFolderError({required String message})`.
- `test/services/permission_service_test.dart` (9 tests):
  1. `requestNotifications` returns `granted` on
     `PermissionStatus.granted`.
  2. `requestNotifications` returns
     `denied(canOpenSettings: false)` on
     `PermissionStatus.denied` (one-shot).
  3. `requestNotifications` returns `permanentlyDenied` on
     `PermissionStatus.permanentlyDenied`.
  4. `requestContacts` same shape as 1-3.
  5. `requestExactAlarm` returns `granted` on
     `PermissionStatus.granted` (policy permission path).
  6. `requestBackupFolder` returns `picked` on a non-null
     `treeUri`.
  7. `requestBackupFolder` returns `cancelled` on null.
  8. `init()` is idempotent (second call resolves
     immediately).
  9. `init()` swallows a thrown platform-channel error
     (defense in depth, per the v0.4b-release-fix lesson).

### v0.5c — Wire onboarding CTAs to `PermissionService`

- `lib/screens/onboarding.dart` `_handleStepCta` dispatches
  on `_step`:
  - `_step == 0` →
    `requestNotifications()`; advance on `granted`.
  - `_step == 1` → `requestContacts()`; advance on
    `granted`.
  - `_step == 2` → `requestExactAlarm()`; on
    `denied(canOpenSettings: true)` /
    `permanentlyDenied` show the "Open Android settings"
    `FilledButton.tonal` that calls
    `PermissionService.openAppSettings()`. Re-tapping the
    CTA after returning from system settings re-probes
    and advances on `granted`.
  - `_step == 3` → `requestBackupFolder()`. On `picked`
    persist via `SettingsService.setBackupFolderUri` and
    advance. On `cancelled` advance (per ADR-015). On
    `error` show the rationale and stay on the step.
- `lib/services/settings_service.dart` exposes
  `ValueNotifier<String?> backupFolderUri` (defaults
  `null`); `setBackupFolderUri(String?)` mutates it.
- `test/services/settings_service_backup_uri_test.dart` (3
  tests): default-null, set-then-read, listener fires.
- `test/screens/onboarding_permission_wiring_test.dart` (6
  tests):
  1. `'tapping Allow on step 0 calls requestNotifications
     and advances on granted'`.
  2. `'tapping Allow on step 0 does not advance on denied
     (one-shot)'` — the step stays at 0; the inline
     rationale is shown.
  3. `'tapping Allow on step 2 shows a Go to Settings
     button on permanentlyDenied for SCHEDULE_EXACT_ALARM'`.
  4. `'tapping Pick folder on step 3 advances on a non-null
     treeUri and persists to SettingsService'`.
  5. `'tapping Pick folder on step 3 advances on cancelled
     (per ADR-014 step 6: skippable)'` — the step advances
     and `backupFolderUri` stays `null`.
  6. `'Skip button still calls onDone immediately'`.
- The widget layer no longer imports `permission_handler`
  or `file_picker` directly; the seam is
  `PermissionService`.
- `lib/screens/onboarding.dart`'s file-level comment is
  updated to reflect the new reality (no "visual
  walkthrough" wording).

### v0.5d — Settings → "Permissions" tile

- `lib/screens/settings.dart` has a new `Permissions` section
  between `Wake-up anchor` and `Reliability`.
- The new section has:
  - `_PermissionsRow` (subscribes to
    `PermissionService.instance.statuses` and renders one
    `ListTile` per permission).
  - `_PermissionTile` (icon + name + status text +
    "Settings" `TextButton` for `permanentlyDenied` rows
    that deep-links to `openAppSettings()`). Tapping the
    row re-probes via `requestX()`.
  - `_BackupFolderTile` (icon + picked path or "Not
    picked" + "Re-pick" `TextButton` when a path is set;
    tapping the row or button calls
    `requestBackupFolder()` and persists via
    `setBackupFolderUri`).
- `test/screens/settings_permissions_test.dart` (4 tests):
  1. `'renders all four permission tiles with the initial
     status text (SYS-063..066)'`.
  2. `'Settings button renders only on the permanentlyDenied
     row (SYS-064)'`.
  3. `'tapping Settings on a permanentlyDenied row calls
     openAppSettings (SYS-064)'`.
  4. `'tapping a granted row re-probes via requestX without
     a system dialog (SYS-063)'`.
- `docs/v_model/notification_reliability.md` is updated:
  the line at 126-127 ("On first scheduling of a fixed-time
  habit, the app detects whether the user has granted
  `SCHEDULE_EXACT_ALARM`") is replaced with "The app probes
  `SCHEDULE_EXACT_ALARM` at onboarding step 2 (SYS-065) and
  surfaces the result on the home screen reliability banner.
  If the user denies, the `Reliability.degraded` path
  activates and the Settings → Permissions tile is the
  recovery affordance."
- `docs/v_model/decision_record.md` has ADR-016 appended
  ("Permission service seam: sealed result, singleton,
  on-demand probe").

### v0.5e — Release APK rebuild + on-device verification

- `flutter clean && flutter pub get` runs clean.
- 3-gate is green: `dart format` clean,
  `flutter analyze --fatal-infos` clean (41/41, matches
  v0.4 baseline), `flutter test` ≥ 406/406.
- The release APK is built:
  `flutter build appbundle --release` (or
  `flutter build apk --release`).
- The v0.4b-release-fix-2 build is uninstalled
  (the applicationId changed; in-place upgrade is not
  possible):
  `adb -s <device> uninstall com.common_games.streak`.
- The v0.5 release APK is installed:
  `adb -s <device> install build/app/outputs/flutter-apk/app-release.apk`.
- The app is launched:
  `adb -s <device> shell monkey -p com.doit -c
  android.intent.category.LAUNCHER 1`.

**On-device verification (seven steps on a real SM-S918B):**

1. **Onboarding step 0 — `POST_NOTIFICATIONS`:** the system
   "Allow notifications?" dialog appears. Tap "Allow". The
   step advances.
2. **Onboarding step 1 — `READ_CONTACTS`:** the system "Allow
   do it to access your contacts?" dialog appears (the
   `android:label` is `do it` post-rename). Tap "Allow". The
   step advances.
3. **Onboarding step 2 — `SCHEDULE_EXACT_ALARM`:** the
   runtime request returns `denied` (policy permission on
   Android 12+); the "Open Android settings" `FilledButton.tonal`
   is rendered. Tap it; the Android Alarms & reminders
   settings page opens. Grant the permission; return to the
   app; re-tap the CTA; the step advances.
4. **Onboarding step 3 — backup folder:** the SAF folder
   picker opens. Pick any folder. The step advances.
5. **Last step — anchor mode + theme mode:** unchanged from
   v0.4b. Tap "Done". The home screen renders with the new
   app bar title `do it`.
6. **Settings → Permissions tile:** open Settings from the
   home screen. Verify the new `Permissions` section is
   present above `Reliability`. Verify the four permission
   rows show "Granted" / "Not granted" status text
   correctly.
7. **`adb logcat -b crash`:** empty (no cold-start crash —
   the v0.4b-release-fix-2 fix still holds under the new
   `applicationId` and `MethodChannel` name).

If any of the seven steps fails, the v0.5 fix loop begins
and a v0.5e-follow-up commit is appended to the 3-gate log
table below.

### v0.5f — Sign-off

- The v0.5 release checklist sign-off line is filled in.
- `CHANGELOG.md` moves the v0.5 entries from
  `[Unreleased]` to `[0.5.0] — YYYY-MM-DD — Permission wiring
  + rename to "do it"`.
- `docs/v_model/open_questions.md` items #5 (READ_CONTACTS
  revocation) and #6 (SAF URI revocation) are closed by
  v0.5d (ADR-016 — the in-app recovery affordance is the
  Settings → Permissions tile).
- `docs/v_model/implementation_status.md` has a v0.5f row.

## 3-gate log (every commit during v0.5)

Every commit on `main` during v0.5 must pass the 3-gate
_before_ push. If a commit lands without a row here, the
milestone is paused until it is backfilled.

| SHA | `dart format` | `flutter analyze` | `flutter test` (count) | Notes |
|-----|---------------|-------------------|------------------------|-------|
| `<v0.5a>` | clean (0 changed) | clean (41, matches v0.4 baseline) | 381 / 381 (377 prior + 4 new: applicationId pin, MethodChannel pin, channel id pin, task name pin) | v0.5a: rename to "do it" (app-level). |
| `<v0.5b>` | clean (0 changed) | clean (41, matches v0.4 baseline) | 390 / 390 (381 prior + 9 new: 9 permission_service tests) | v0.5b: `PermissionService` + sealed result. |
| `<v0.5c>` | clean (0 changed) | clean (41, matches v0.4 baseline) | 399 / 399 (390 prior + 3 settings_backup_uri + 6 onboarding_wiring) | v0.5c: wire onboarding CTAs. |
| `a04e392` | clean (0 changed) | clean (41, matches v0.4 baseline) | 406 / 406 (399 prior + 4 settings_permissions + 3 settings_test header) | v0.5d: Settings → Permissions tile + ADR-016 + notification_reliability copy. |
| `<v0.5e>` | _tbd_ | _tbd_ | _tbd_ | v0.5e: release APK + on-device verification. |
| `<v0.5f>` | _tbd_ | _tbd_ | _tbd_ | v0.5f: sign-off + CHANGELOG [0.5.0] + open-question closures. |

_(Append a row for each v0.5 commit.)_

## Exit criteria

v0.5 is **accepted** when, at the v0.5f commit:

1. Every row in the [SYS- exit criteria](#sys--exit-criteria)
   table is "yes".
2. The 3-gate log table is complete (no missing rows for
   v0.5a..v0.5f).
3. The on-device verification (v0.5e step) is recorded.
4. The user has signed off in the [Sign-off](#sign-off)
   section.

v0.5 is **rejected** (and a v0.5 fix loop begins) when any
of:

- 3+ rows in the SYS- exit criteria table are "no".
- A 3-gate was skipped or regressed.
- A v0.4 regression surfaced in CI for the v0.5 build's SHA.
- One of the seven on-device verification steps failed.

## Sign-off

The v0.5 release is closed by a single line:

```
Accepted on YYYY-MM-DD by <user>. Final SHA: <git rev-parse HEAD>.
```

The v0.5d commit is `a04e392`. The release is _in flight_
until the user runs the seven-step on-device verification
on a real SM-S918B device (or emulator) — the checklist is
not signed off below until that step is recorded.

```
Pending. Awaiting user's hands-on on-device verification (v0.5e).
```

If rejected, append a v0.6-pre fix-loop plan link instead.

## Traceability

| Artifact | This document |
|----------|---------------|
| `v0_5_release_baseline.md` | The left-side doc; the SYS- IDs and the v0.5 floor live there. |
| `requirements.md` SYS-063..SYS-066 | The SYS- exit criteria table cites each row. |
| `lib/services/permission_service.dart` + `permission_result.dart` | SYS-063..066 rows 1-4. |
| `lib/services/settings_service.dart` | SYS-066 row 4. |
| `lib/screens/onboarding.dart` | SYS-063..066 rows 1-4. |
| `lib/screens/settings.dart` | SYS-063..066 rows 1-4. |
| `docs/v_model/notification_reliability.md` | SYS-065 row 3 — copy update. |
| `decision_record.md` ADR-014, ADR-015, ADR-016 | Architecture decisions for v0.5. |
| `pubspec.yaml` + `lib/build_info.dart` | Row 5 (app identity). |
| `android/app/build.gradle.kts` + `AndroidManifest.xml` | Row 5 (app identity). |
| `lib/reminders/reminder_bridge.dart` + `lib/services/notification_service.dart` + `lib/services/backup_scheduler.dart` + `lib/services/reminder_service.dart` | Row 5 (channel + task + test reminder rename). |
| `test/release_signing_test.dart` | Row 5 v0.5a pin tests. |
| `test/services/permission_service_test.dart` | v0.5b — 9 service tests. |
| `test/services/settings_service_backup_uri_test.dart` | v0.5c — 3 tests. |
| `test/screens/onboarding_permission_wiring_test.dart` | v0.5c — 6 wiring tests. |
| `test/screens/settings_permissions_test.dart` | v0.5d — 4 tile tests. |
| `CHANGELOG.md` | v0.5 `[Unreleased]` section; v0.5f moves to `[0.5.0]`. |
| `PRIVACY.md` "Honest caveats" | Updated by v0.5e. |
| `traceability_matrix.md` | SYS-063..SYS-066 rows. |
| `docs/v_model/open_questions.md` #5, #6 | Closed by v0.5d (ADR-016). |
| `implementation_status.md` | v0.5a..v0.5f rows. |
