# v0.3 — Public release baseline (sideload tier)

Status: **approved**, 2026-06-14. Created with the v0.3 plan at
commit `c1b9e64` (the v0.2d tip) and the v0.3a–v0.3e work landed
between `82b875f` and this document.

This is the **left-side** V-Model doc for v0.3. The right-side
gate is [`v0_3_release_checklist.md`](v0_3_release_checklist.md).
The v0.3 sign-off is a different gate from the v0.2 personal-use
run ([`acceptance_run_v2.md`](acceptance_run_v2.md)): Run #2 is
"I trust it on my primary phone"; v0.3 is "I trust someone else's
hands to use it." The two run in parallel.

## Scope

Ship a release-signed Android build of the v0.2 surface to a few
trusted users. v0.3 is **sideload-only**: no Play Store metadata,
no a11y audit, no per-locale strings, no cloud sync, no account.

## Constraints (v0.3 floor)

These are non-negotiable for v0.3. Any loosening is a v0.4 ADR
recorded in [`decision_record.md`](decision_record.md).

- **No `INTERNET` permission.** Enforced by the manifest. The
  Android platform itself will not let the app make a network
  call. The PRIVACY.md is not a promise — the absence of the
  permission in the manifest is the contract. (Inherited from
  v0.1, SYS-026.)
- **No analytics.** No Firebase Analytics, no Mixpanel, no
  Amplitude, no Segment, no Crashlytics, no Sentry, no Bugsnag,
  no Datadog. (SYS-051 + PRIVACY.md.)
- **No telemetry.** No install ID, no advertising ID, no device
  fingerprint, no usage ping. (SYS-051.)
- **No cloud backup.** The SAF backup is local; the app does not
  upload it. (SYS-051 + `lib/services/backup_service.dart`.)
- **No account.** No sign-in, no profile, no sync. (SYS-051.)
- **No advertising SDK.** No AdMob, no Facebook Ads, no Unity
  Ads. (SYS-051.)
- **No third-party crash reporter.** (SYS-051.)
- **No `CALL_PHONE`, `READ_CALL_LOG`, `RECORD_AUDIO`,
  `READ_PHONE_STATE` permissions.** (Inherited from v0.1; see
  [`AndroidManifest.xml`](../../android/app/src/main/AndroidManifest.xml).)
- **MIT license at the project root.** (SYS-050.)
- **Real release signingConfig sourced from
  `android/key.properties`** (gitignored). Falls back to debug
  signing when the file is absent. R8 / minify is **off** for
  v0.3. (SYS-053.)
- **In-app About / Open source licenses tile** in Settings
  → About. (SYS-054.)
- **Fresh-install smoke test** that simulates a wiped-device
  install end-to-end. (SYS-055.)
- **Honest README status** that points to
  [`implementation_status.md`](implementation_status.md) for the
  current slice. (SYS-056.)

## System Requirements (new in v0.3)

v0.3 owns the following SYS- IDs in
[`requirements.md`](requirements.md):

- **SYS-048** — Test reminder (WF-028). Back-fill; the v0.2
  runbook cited this ID without a definition. The "Send a test
  reminder" tile schedules a 5-second one-shot alarm via the
  same `AlarmScheduler` path.
- **SYS-049** — Bulk complete (WF-029). Back-fill; same gap.
  The "Bulk complete" action logs 1–4 completions with
  timestamps spread across the missed window.
- **SYS-050** — `LICENSE` (MIT) at repo root. Sole license.
- **SYS-051** — `PRIVACY.md` at repo root with the four
  disclosure sections.
- **SYS-052** — `kAppVersion` / `kAppVersionCode` constants
  in `lib/build_info.dart`; the test
  `test/build_info_test.dart` guards against drift.
- **SYS-053** — Real release signingConfig reading
  `android/key.properties`; `test/release_signing_test.dart`
  pins the structural shape.
- **SYS-054** — In-app "Open source licenses" tile wired to
  `showLicensePage`; `test/screens/settings_licenses_test.dart`
  asserts the tile and the route.
- **SYS-055** — Fresh-install widget test simulating a
  wiped device; `test/integration/fresh_install_test.dart`.
- **SYS-056** — Honest `README.md` status line; no stale
  "implementation has not started" claims.

## Approval status

- **2026-06-14**: v0.3a (`82b875f`) → v0.3d (`50781ce`) landed
  in a single day's work. The right-side gate is
  [`v0_3_release_checklist.md`](v0_3_release_checklist.md).
- **v0.3e (release build)** is the user's hands-on step:
  `flutter build appbundle --release` with the user's keystore
  env vars set. The artifact lands in
  `build/app/outputs/bundle/release/app-release.aab`. The SHA
  of the build is recorded in the checklist.

## What is explicitly out of scope for v0.3

- **Play Store metadata, screenshots, content rating, F-Droid
  submission.** v0.3 is sideload-only. A "v0.3.1 — Play Store"
  milestone can be a follow-up.
- **TalkBack / a11y audit on a real device.** A v0.4 line item.
- **Localization.** All strings are hard-coded English. A
  v0.4 line item.
- **Backup encryption at rest.** Plain JSON. A v0.4 line item
  behind a user passphrase.
- **Crash reporting / analytics / telemetry.** The project's
  stance is **no** third-party SDKs. v0.3 sideloaders report
  bugs by chatting with the user.
- **`v0.2f` (VIP escalation, `READ_PHONE_STATE` permission).**
  Deferred to a future milestone; not in v0.3 scope.
- **Multi-user / multi-device sync.** Out of project scope; the
  local-only stance is the project's identity.
- **The firstLaunch persisted flag.** v0.3 keeps the
  hard-coded `true` in `lib/main.dart`; every sideload install
  sees Onboarding. v0.4 line item.
- **The WorkManager periodic backup scheduler.** Forward-dep is
  in `pubspec.yaml` but the scheduling call is not yet wired.
  v0.3 PRIVACY.md discloses this honestly. v0.4 line item.
- **R8 / minify / ProGuard.** Off for v0.3. A v0.4 release can
  add minify with a hand-written `proguard-rules.pro`.

## Traceability

| Artifact | This document |
|----------|---------------|
| `requirements.md` SYS-048..SYS-056 | The SYS- IDs above. |
| `LICENSE` (MIT) | SYS-050. |
| `PRIVACY.md` | SYS-051. |
| `lib/build_info.dart` | SYS-052. |
| `pubspec.yaml` `version: 0.3.0+3` | SYS-052 mirror. |
| `android/app/build.gradle.kts` | SYS-053. |
| `android/key.properties.example` | SYS-053 template. |
| `.gitignore` | SYS-053 (the keystore is never committed). |
| `lib/screens/settings.dart` About section | SYS-054. |
| `test/integration/fresh_install_test.dart` | SYS-055 widget side. |
| `README.md` Status section | SYS-056. |
| `acceptance_run.md` (v0.1) | Stays in flight in parallel. |
| `acceptance_run_v2.md` (v0.2) | Stays in flight in parallel. |
| `v0_3_release_checklist.md` | The right-side gate. |
| `implementation_status.md` | v0.3a..v0.3e rows. |
| `traceability_matrix.md` | SYS-048..SYS-056 rows. |
| `decision_record.md` | Any loosening of a v0.3 constraint lands here. |
