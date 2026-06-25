# v1.3 release checklist (right-side gate)

> **Purpose.** This document is the right-side gate of the
> V-Model for the v1.3 milestone. It is the on-device
> verification steps that close out the v1.3 cycle. The
> left-side baseline is
> [`v1_3_release_baseline.md`](v1_3_release_baseline.md); that
> doc is where the scope, the 30-phase roadmap status, the
> SYS- IDs, the ADRs, and the deferred items live.

The sign-off line at the bottom of this doc is the moment
the user accepts the build as the v1.3 release. v1.3x is the
user's hands-on on-device verification on the Android
emulator (or a real SM-S918B device), the same shape as
v0.5e / v1.0h / v1.1h / v1.1k / v1.2x.

## Pre-flight (mechanical, before the user's hands-on step)

These run as CI / commit-time checks, not on the device:

- [x] `dart format --output=none --set-exit-if-changed .` —
      clean.
- [x] `flutter analyze --fatal-infos` — No issues found!
- [x] `flutter test` — 1064 / 1064 tests passing.
- [x] `pubspec.yaml` → `version: 1.3.0+10`.
- [x] `lib/build_info.dart` → `kAppVersion = '1.3.0'`,
      `kAppVersionCode = 10`.
- [x] `test/release_signing_test.dart` mirror-pin assertions
      updated in lockstep.
- [x] `CHANGELOG.md` `## [1.3.0]` block exists with four
      sub-entries (v1.3a..v1.3d).
- [x] `docs/v_model/plan.md` Milestone 10 (v1.3) flipped to
      `shipped`.
- [x] `docs/v_model/implementation_status.md` has 4 new
      rows (v1.3a..v1.3d) + the sign-off row.
- [x] `docs/v_model/decision_record.md` ADR-042..ADR-044
      appended.
- [x] `docs/v_model/requirements.md` SYS-112..SYS-114
      appended.
- [x] `docs/v_model/v1_3_release_baseline.md` +
      `v1_3_release_checklist.md` exist.

## Build + install (the user runs)

- [ ] `flutter build apk --debug` — no signing-config touch.
      Record the SHA1 + size in the `release(v1.3)` commit
      (mirrors the v1.1i pattern at `222f860`).
- [ ] `adb install -r build/app/outputs/apk/debug/app-debug.apk`
      on the Android emulator (or a real SM-S918B device).
- [ ] Optional (asks first per CLAUDE.md):
      `flutter build appbundle --release` +
      `adb install -r build/app/outputs/bundle/release/app-release.aab`.

## On-device verification (one per sub-entry)

The v1.3 cycle shipped 4 sub-entries. The on-device checks
are organized by sub-entry; the user runs each in turn.

### v1.3a (Monthly stats + per-do grace factory)

- [ ] Open the Stats screen. The 30-day completion-rate
      tile should render the new percentage + the
      month-over-month delta (green ↑ / red ↓ arrow).
- [ ] The 7-day bar chart should render below the rate tile.
- [ ] Edit a habit. The "Grace window" section should now
      show a per-do override picker (the new
      `Do.graceWindowOverride` field). Save with
      `2 hours` override — the streak should respect the
      new window within the grace window.
- [ ] The `Do.effectiveStreakConfig(...)` factory is the
      single source-of-truth; the home-screen tile renders
      the per-do config consistently.

### v1.3b (unified `ReliabilityService`)

- [ ] Open the home screen. The `ReliabilityBanner` should
      render the "optimal" / "degraded" badge state from
      the new `ReliabilityService.instance.notifier` (NOT
      from `PlatformAlarmScheduler.reliability` directly).
- [ ] Open Settings → Reminders. The `_ReliabilityRow`
      should render the same state as the home banner.
      Both should bind to `ReliabilityService.instance.notifier`.
- [ ] Toggle the device into airplane mode (no impact on
      reliability — `Reliability.optimal` stays). Toggle
      a `TriggerLocation*` routine's `ACCESS_FINE_LOCATION`
      permission off in OS settings. Return to do it. The
      home banner should flip to "may be late" within ~50 ms
      of `AppLifecycleState.resumed` (the
      `PermissionLifecycleReProbe` hook in `v1.2i` + the
      unified service's `statuses` listener in `v1.3b`).
- [ ] Cold-launch the app. The very first read of the
      reliability state should be `optimal` (NOT `unknown`) —
      closes the v1.3a first-read race.

### v1.3c (`USE_FULL_SCREEN_INTENT` probe + reliability wiring)

- [ ] Open Settings → Permissions. The 5th tile "Full-screen
      access" should render with the `Icons.open_in_full` icon.
- [ ] Tap the tile → land on the system FSI toggle (Android
      14+) or the app-info page (API 32 / 33) or implicit
      (API < 32).
- [ ] Toggle `USE_FULL_SCREEN_INTENT` off. Return to do it.
      The home banner should flip to "may be late" within
      ~50 ms of `AppLifecycleState.resumed` (the
      `PermissionService.refreshFullScreenIntent()` re-probes
      the channel probe and merges the result into `statuses`,
      which the unified service's `statuses` listener picks up).
- [ ] Toggle it back on. The banner should clear after the
      re-probe resolves (per the v1.2i
      `AppLifecycleState.resumed` re-probe hook).
- [ ] The home banner's `onTap` callback should push
      `SettingsScreen` so the user is one tap from the tile.

### v1.3d (`FullScreenActivity` launch path — Phase 6a proper)

- [ ] Create a strong-mode habit (Type mission). Schedule
      it for 1 minute from now. Lock the device.
- [ ] At the alarm fire time, the device should wake and
      `FullScreenActivity` should surface directly on the
      lockscreen (NOT just the heads-up notification).
- [ ] Tap through the Type mission with the correct phrase.
      The activity should dismiss; the home screen should
      show the streak advanced by 1.
- [ ] Create a soft-mode habit. Schedule it for 1 minute from
      now. Lock the device. At the alarm fire time, only
      the notification should surface (NO full-screen
      activity); the "Done" action should mark complete
      without launching the activity.
- [ ] Create a routine with a `showFullscreen` action (v1.2f
      pattern). Trigger the routine — the
      `RoutineOverlayScreen` banner should surface with
      the routine's title + body.
- [ ] Cancel the overlay — the activity should dismiss
      with `null`.
- [ ] On API 34+: verify the `USE_FULL_SCREEN_INTENT`
      permission (v1.3c) is granted; if NOT, the
      notification fallback (heads-up only, no full-screen
      activity) is the expected behavior per
      `docs/v_model/notification_reliability.md` "Full-screen
      access".

## Regression checks (re-run the v1.2x checks)

The v1.3 cycle should not have regressed any v1.2
functionality. Re-run:

- [ ] Per-automation reliability badges (the icon-only
      state, before tapping). (v1.1f.)
- [ ] `PACKAGE_USAGE_STATS` permission rationale +
      deep-link. (v1.1g.)
- [ ] Brand-purple launcher icon + 'd' glyph + check dot.
      On-brand splash. Status-bar notification icon.
      (v1.1i.)
- [ ] Spanish locale. (v1.1h.)
- [ ] DST transition banner + streak-recovery card +
      pre-notification 5-min / 1-min heads-up. (v1.2j.)
- [ ] `CompletionLogSection` for review + undo. (v1.2m.)
- [ ] Uniform 3-wrong take-a-break across Math + Type.
      (v1.2l.)
- [ ] Hard-delete affordance on edit screen. (v1.2k.)

## SYS- exit criteria (left-side ↔ right-side traceability)

Every SYS- ID added in v1.3 maps to a verifiable test or
on-device check. The `requirements.md` row carries the
canonical mapping; this table mirrors it for quick sign-off:

| SYS- ID | v1.3 sub-entry | Verification (test or on-device check) |
| --- | --- | --- |
| SYS-112 | v1.3b | `test/services/reliability_service_test.dart` (~10 tests — initial value is `optimal`; `refresh()` re-probes `bridge.probeReliability()`; subscribing to `statuses` re-derives the value when a gated kind flips; the 30 s timer fires `refresh()`; `resetForTesting()` clears the singleton; `init()` is idempotent) + `test/services/platform_alarm_scheduler_test.dart` reliability group rewritten (getter delegates to `ReliabilityService.instance.value`) + `test/widgets/reliability_banner_test.dart` (2 new tests — `fromStream` renders nothing when optimal; rebuilds when degraded) + on-device initial-read check + `AppLifecycleState.resumed` re-probe |
| SYS-113 | v1.3c | `test/services/full_screen_intent_service_test.dart` (8 tests — `isGranted` happy path + `MissingPluginException` swallow + `PlatformException` swallow; `openSettings` happy path + `MissingPluginException` swallow + `PlatformException` swallow; `resetForTesting`; `debugInstance`) + `test/services/permission_service_test.dart` (+3 tests — `requestFullScreenIntent` deep-links; `refreshFullScreenIntent` merges `isGranted=true` → `PermissionResultGranted`; `refreshFullScreenIntent` merges `isGranted=false` → `PermissionResultDenied(canOpenSettings: true)`) + `test/services/reliability_service_test.dart` (+1 test — flipping `fullScreenIntent` to `Denied` re-derives to `degraded`) + `test/screens/settings_permissions_test.dart` (+2 tests — tapping the FSI tile re-probes via `doit/full_screen`; the tile renders the localized title) + `test/widgets/reliability_banner_test.dart` (+1 test — `fromStream` wires `onTap`) + on-device Android 14+ permission cycle |
| SYS-114 | v1.3d | `test/services/platform_full_screen_intent_test.dart` (6 tests — `showHabitMission` invokes the right method + `habitId` arg; `showRoutineOverlay` propagates `title` / `body` and skips missing keys; `getLaunchIntent` swallows production `MissingPluginException` and returns `null`; `showHabitMission` swallows `MissingPluginException` end-to-end; `getLaunchIntent` returns null on partial args; `showRoutineOverlay` accepts title-only / body-only / neither) + `test/screens/mission_launcher_test.dart` (6 tests — 1-mission chain (Type) appends with `proofModeAtTime: "strong"` and `missionResultsJson: "missions=1"`, pops `true`; 2-mission chain appends with `missions=2`; `ChainFailedAt` pops `null`; missing habit pops `null`; non-`StrongProof` habit pops `null`; cancel on first mission aborts) + `test/screens/routine_overlay_test.dart` (4 tests — renders `title` + `body` from constructor args; falls back to generic copy on null; falls back on empty; Dismiss button pops with `null`) + `test/a11y/semantics_labels_test.dart` (SYS-062 — Dismiss button's `Semantics` label auto-validated) + on-device strong-mode schedule-and-lock check |

## Sign-off

When every check above is green, the user accepts the build
as the v1.3 release:

```
v1.3 sign-off: 2026-06-25

Build SHA1: <from release(v1.3) commit>
Build size: <from release(v1.3) commit>
Test count: 1064 / 1064
```

The sign-off line lives in the `release(v1.3)` commit
message; the build SHA1 + size are recorded there.