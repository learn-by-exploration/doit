# v0.3 Release Checklist (right-side gate)

Status: **in flight** — created 2026-06-14 alongside
[`v0_3_release_baseline.md`](v0_3_release_baseline.md). The v0.3
left-side doc lists the scope; this document is the verification
gate the v0.3 build must clear before it is handed to a friend.

The v0.3 sign-off is a different gate from the v0.2 personal-use
run ([`acceptance_run_v2.md`](acceptance_run_v2.md)): Run #2 is
"I trust it on my primary phone"; v0.3 is "I trust someone else's
hands to use it." The two run in parallel. If Run #2 finds a v0.2
defect, the v0.3 release is paused until the fix lands, and the
v0.3 work resumes on a clean v0.2 tip.

## Purpose

v0.3 ships a release-signed Android build of the v0.2 surface to a
few trusted users. The build is sideload-only — no Play Store
metadata, no a11y audit, no per-locale strings, no cloud sync, no
account. The hard floor is the v0.3 constraint list in
[`v0_3_release_baseline.md`](v0_3_release_baseline.md#constraints-v03-floor).

## Setup

The release build is the user's hands-on step. Before the build:

1. `flutter pub get` on a clean clone.
2. `dart format --output=none --set-exit-if-changed .` clean.
3. `flutter analyze --fatal-infos` clean.
4. `flutter test` green (328 / 328 as of v0.3d).
5. `flutter test --coverage` ≥ 80% on the v0.2 changed files
   (the runbook's gate).
6. `flutter build appbundle --release` succeeds with the user's
   keystore env vars set:
   - `ANDROID_KEYSTORE_PATH` (or `android/key.properties` is
     filled in and `storeFile` points at the keystore)
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
7. The artifact lands in
   `build/app/outputs/bundle/release/app-release.aab`. The
   `apksigner verify --print-certs` output confirms the user's
   upload key.
8. Note the SHA of the build: `git rev-parse HEAD` =
   `____________________`.

## SYS- exit criteria

v0.3 is accepted when every row in the table below is "yes":

| # | SYS- | What the user verifies | Yes / No |
|---|------|------------------------|----------|
| 1 | SYS-050 | A `LICENSE` file exists at the repo root; its text is the verbatim MIT from the Open Source Initiative. | ___ |
| 2 | SYS-051 | A `PRIVACY.md` exists at the repo root and contains the four disclosure sections (data inventory, what the app does not do, on-device footprint, no-`INTERNET` enforcement). | ___ |
| 3 | SYS-052 | `lib/build_info.dart` exports `kAppVersion = '0.3.0'` and `kAppVersionCode = 3`; `pubspec.yaml` matches; the test `test/build_info_test.dart` passes. | ___ |
| 4 | SYS-053 | `android/app/build.gradle.kts` declares a `signingConfigs.release` block that reads `android/key.properties`; the file is gitignored; the `release` buildType points at `signingConfigs.getByName("release")`; `isMinifyEnabled` is NOT set; the test `test/release_signing_test.dart` passes. | ___ |
| 5 | SYS-054 | The Settings → About section has a "Open source licenses" `ListTile`; tapping it opens `showLicensePage`; the static version row reads `kAppVersion`; the test `test/screens/settings_licenses_test.dart` passes. | ___ |
| 6 | SYS-055 | `test/integration/fresh_install_test.dart` passes (the in-test wiped-device simulation). See also the [Fresh-install smoke test](#fresh-install-smoke-test) below. | ___ |
| 7 | SYS-056 | The `README.md` Status section is honest — it does not say "implementation has not started"; it points to `implementation_status.md` for the current slice. | ___ |
| 8 | SYS-048 | The "Send a test reminder" tile in Settings → About schedules a one-shot alarm in ~5 seconds. (Back-filled; existing v0.2 behavior.) | ___ |
| 9 | SYS-049 | The home screen exposes a "Bulk complete" action for interval habits with ≥ 2 missed occurrences. (Back-filled; existing v0.2 behavior.) | ___ |
| 10 | (no SYS-) | The 14-day personal-use run #2 ([`acceptance_run_v2.md`](acceptance_run_v2.md)) is still in flight, with no `✗` in its 3-gate log for the v0.3 build's SHA. | ___ |
| 11 | (no SYS-) | The release artifact is signed with the user's upload key. `apksigner verify --print-certs build/app/outputs/bundle/release/app-release.aab` shows the user's cert. | ___ |
| 12 | (no SYS-) | The manifest baseline still has no `INTERNET`, no `CALL_PHONE`, no `READ_CALL_LOG`, no `READ_PHONE_STATE`, no `RECORD_AUDIO`. (See [`AndroidManifest.xml`](../../android/app/src/main/AndroidManifest.xml).) | ___ |

## Fresh-install smoke test

This is the user's hands-on counterpart to
`test/integration/fresh_install_test.dart`. The user ticks off
this 2-paragraph checklist on a wiped phone (or emulator) before
handing the apk to friends.

### On a wiped device (or emulator)

1. Install the v0.3 release artifact
   (`build/app/outputs/bundle/release/app-release.aab` → extract
   an .apk with `bundletool build-apks` or sideload the .aab
   directly via `adb install`).
2. Open do it. The OnboardingScreen renders (Notifications step
   is first, "Skip" CTA visible).
3. Tap Skip. The HomeScreen renders with the "No habits yet."
   empty-state placeholder.
4. Tap `+` to add a habit. Pick "Drink water" (or any preset).
   The habit saves.
5. Open Settings → About → "Send a test reminder". A
   notification appears within ~10 seconds.
6. Open Settings → About → "Open source licenses". The standard
   Flutter license page renders with the application name
   "do it", version `0.3.0`, and the legalese "Local-only. No
   telemetry. No accounts."

### On the same wiped device, after the smoke test

1. Uninstall do it. Verify that the database under
   `/data/data/com.common_games.streak/` is gone (use
   `adb shell run-as com.common_games.streak ls databases/`
   before uninstall).
2. Reinstall the v0.3 artifact. The OnboardingScreen re-renders
   (this is the v0.3 design; the firstLaunch persisted flag is
   a v0.4 line item).
3. Open Settings → About. Confirm the version row reads
   `0.3.0`.

A "yes" on every step means the v0.3 surface matches the
[`fresh_install_test.dart`](../../test/integration/fresh_install_test.dart)
contract on a real device. A "no" on any step is a defect and
the v0.3 release is paused until the fix lands.

## 3-gate log (every commit during v0.3)

Every commit on `main` during v0.3 must pass the 3-gate _before_
push. The user pastes the tail of the three commands into a row.
If a commit lands without a row here, the release is paused until
it is backfilled.

| SHA | `dart format` | `flutter analyze` | `flutter test` (count) | Notes |
|-----|---------------|-------------------|------------------------|-------|
| `82b875f` | ✓ | ✓ | ✓ (312) | Phase 0: back-fill SYS-048/049 + honest README. |
| `6502432` | ✓ | ✓ | ✓ (316) | v0.3a: LICENSE, PRIVACY.md, build_info.dart. |
| `bcb5c9b` | ✓ | ✓ | ✓ (324) | v0.3b: release signingConfig + 8 static tests. |
| `78b8302` | ✓ | ✓ | ✓ (327) | v0.3c: in-app About / Open source licenses tile. |
| `50781ce` | ✓ | ✓ | ✓ (328) | v0.3d: fresh-install widget test. |
| `d5edf3c` | ✓ | ✓ | ✓ (328) | v0.3e: release baseline + checklist + status updates. **Both builds are debug-signed** (CN=Android Debug) because no `android/key.properties` is set in this dev env — the v0.3b fallback design. The user re-runs `flutter build apk --release` (or `appbundle --release`) with the keystore env vars set to get a release-signed artifact.<br>APK artifact: `build/app/outputs/flutter-apk/app-release.apk` (52.7 MB) — SHA-256 `1447ad7a2d838bf24cf98b45f0ac5b3dc9b0793eaeb31bf5aaed47ad9e48a818`.<br>AAB artifact: `build/app/outputs/bundle/release/app-release.aab` (52.2 MB) — SHA-256 `2e7e6b0b84e360e06f4f51c2c68a70887c44b1b820a46d6cb806a3678d6e1588`.<br>Debug-cert SHA-256: `1fd9295da2808d76f97c41b06b718454ba694a210b6e62584fa8c6b894dc288a` (CN=Android Debug) — the v0.3b fallback, not the user's upload key. |

_(Append a row for the v0.3e commit.)_

## Exit criteria

The v0.3 release is **accepted** when, at the v0.3e commit:

1. Every row in the [SYS- exit criteria](#sys--exit-criteria)
   table is "yes".
2. Every step in the [Fresh-install smoke test](#fresh-install-smoke-test)
   is "yes".
3. The 3-gate log table is complete (no missing rows for
   v0.3a..v0.3e).
4. The release artifact is signed with the user's upload key.
5. The v0.2 personal-use run #2 is still in flight with no `✗`
   in its 3-gate log for the v0.3 build's SHA.
6. The user has signed off in the [Sign-off](#sign-off) section.

The v0.3 release is **rejected** (and a v0.4 fix loop begins) when
any of:

- 3+ rows in the SYS- exit criteria table are "no".
- The fresh-install smoke test failed on a real device.
- A 3-gate was skipped or regressed.
- A v0.2 regression surfaced in Run #2 for the v0.3 build's SHA.

## Sign-off

The v0.3 release is closed by a single line:

```
Accepted on YYYY-MM-DD by <user>. Final SHA: <git rev-parse HEAD>.
```

If rejected, append a v0.4 fix-loop plan link instead.

## Traceability

| Artifact | This document |
|----------|---------------|
| `v0_3_release_baseline.md` | The left-side doc; the SYS- IDs and the v0.3 constraint floor live there. |
| `requirements.md` SYS-048..SYS-056 | The SYS- exit criteria table cites each row. |
| `LICENSE` (MIT) | SYS-050 row 1. |
| `PRIVACY.md` | SYS-051 row 2. |
| `lib/build_info.dart` | SYS-052 row 3. |
| `android/app/build.gradle.kts` | SYS-053 row 4. |
| `lib/screens/settings.dart` About section | SYS-054 row 5. |
| `test/integration/fresh_install_test.dart` | SYS-055 widget side. |
| `README.md` | SYS-056 row 7. |
| `test/screens/settings_test_reminder_test.dart` | SYS-048 row 8. |
| `lib/screens/home.dart` | SYS-049 row 9. |
| `acceptance_run_v2.md` | The v0.2 personal-use run; row 10. |
| `AndroidManifest.xml` | The manifest baseline check; row 12. |
| `traceability_matrix.md` | Every SYS- ID in the SYS- exit criteria table has a row there. |
| `decision_record.md` | Any loosening of a v0.3 constraint lands here. |
| `implementation_status.md` | v0.3a..v0.3e rows. |
