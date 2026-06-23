# v1.2 release checklist (right-side gate)

> **Purpose.** This document is the right-side gate of the
> V-Model for the v1.2 milestone. It is the on-device
> verification steps that close out the v1.2 cycle. The
> left-side baseline is
> [`v1_2_release_baseline.md`](v1_2_release_baseline.md); that
> doc is where the scope, the 30-phase roadmap status, the
> SYS- IDs, the ADRs, and the deferred items live.

The sign-off line at the bottom of this doc is the moment
the user accepts the build as the v1.2 release. v1.2x is the
user's hands-on on-device verification on the Android
emulator (or a real SM-S918B device), the same shape as
v0.5e / v1.0h / v1.1h / v1.1k.

## Pre-flight (mechanical, before the user's hands-on step)

These run as CI / commit-time checks, not on the device:

- [x] `dart format --output=none --set-exit-if-changed .` —
      clean.
- [x] `flutter analyze --fatal-infos` — No issues found!
- [x] `flutter test` — 1001 / 1001 tests passing.
- [x] `pubspec.yaml` → `version: 1.2.0+9`.
- [x] `lib/build_info.dart` → `kAppVersion = '1.2.0'`,
      `kAppVersionCode = 9`.
- [x] `test/release_signing_test.dart` mirror-pin assertions
      updated in lockstep.
- [x] `CHANGELOG.md` `## [1.2.0]` block exists with thirteen
      sub-entries (v1.2a..v1.2m).
- [x] `docs/v_model/plan.md` Milestone 9 (v1.2) flipped to
      `shipped`.
- [x] `docs/v_model/implementation_status.md` has 13 new
      rows (v1.2a..v1.2m) + the sign-off row.
- [x] `docs/v_model/decision_record.md` ADR-033..ADR-041
      appended.
- [x] `docs/v_model/requirements.md` SYS-098..SYS-110
      appended.
- [x] `docs/v_model/v1_2_release_baseline.md` +
      `v1_2_release_checklist.md` exist.

## Build + install (the user runs)

- [ ] `flutter build apk --debug` — no signing-config touch.
      Record the SHA1 + size in the `release(v1.2)` commit
      (mirrors the v1.1i pattern at `222f860`).
- [ ] `adb install -r build/app/outputs/apk/debug/app-debug.apk`
      on the Android emulator (or a real SM-S918B device).
- [ ] Optional (asks first per CLAUDE.md):
      `flutter build appbundle --release` +
      `adb install -r build/app/outputs/bundle/release/app-release.aab`.

## On-device verification (one per sub-entry)

The v1.2 cycle shipped 13 sub-entries. The on-device checks
are organized by sub-entry; the user runs each in turn.

### v1.2a / v1.2b (Phase 1-2, doc-only)

- [ ] No on-device check (these are doc-only baseline stubs;
      the value classes they reserve are consumed by v1.2c
      onwards).

### v1.2c (`TriggerForegroundApp` + `PermissionKind.callScreening`)

- [ ] Open Settings → Routines → Add routine → Trigger
      "Foreground app". Pick an app from the picker (e.g.,
      "Messages"). Save. Open Messages — the routine should
      not fire (the `TriggerForegroundApp` leaf is wired
      but the dispatch path is left for v1.2f to use).
- [ ] No new permission prompt appears for `TriggerForegroundApp`.

### v1.2d (`PauseService._ready` + `PositionSource.dispose`)

- [ ] Open a geofence-based habit. Set a geofence at the
      current location. Background the app for 30 s. Return —
      the geofence "entered" event should fire (the
      `PositionSource.dispose()` contract is now clean; no
      leaked `StreamSubscription`).

### v1.2e (alarm fire → notification render path)

- [ ] Settings → Test reminder → tap "Fire now". The
      notification should render in the status bar with the
      "Done" / "Open" action contract per habit mode:
      - Soft habit → "Done" marks complete from the
        notification (no full-screen intent).
      - Strong habit → "Open" launches the full-screen
        activity (the v0.4b path; v1.2e wires it through
        `NotificationService.show`).
- [ ] Notification icon is the white 'd' glyph (no check
      dot; the dot is unreadable at 24dp).
- [ ] Tapping "Done" dismisses the notification AND marks
      the habit complete in the database.

### v1.2f (`ActionFullscreen` + `ActionCallIntercept` + `Person.pauseUntil` + `DoFixed.weekday`)

- [ ] Add a routine with `ActionFullscreen(route: '/mission')`.
      The full-screen activity should launch on trigger.
- [ ] Add a routine with `ActionCallIntercept(person_id: '<p>')`.
      Have a matching contact call the device — the call
      should be intercepted by the routine (the Japan
      silent-mode pattern).
- [ ] Open a Person detail screen. Tap "Pause until". Pick
      a date 7 days out. Save. The person card should show
      "Paused until <date>". The cadence scheduler should
      skip the paused person.
- [ ] Open a `DoFixed` habit. The time row should now show
      weekday chips (Mon/Tue/Wed/Thu/Fri/Sat/Sun) under the
      time picker. The chips reflect the habit's days-of-week.

### v1.2g (BOOT_COMPLETED coverage confirmation)

- [ ] Schedule a reminder for 30 s out. Reboot the device
      via `adb reboot`. After boot, the reminder should
      still fire (the `BootReceiver` re-schedules all pending
      alarms on `BOOT_COMPLETED` / `LOCKED_BOOT_COMPLETED` /
      `MY_PACKAGE_REPLACED`).
- [ ] Update the app via `adb install -r` of the same
      version (triggers `MY_PACKAGE_REPLACED`). The pending
      alarms should still be scheduled.

### v1.2h (per-automation `AlertDialog` on tap)

- [ ] Add a `TriggerLocation*` routine without granting
      `ACCESS_FINE_LOCATION`. The reliability badge should
      show "degraded" (warning-amber). Tap the badge — the
      dialog should open with the trigger's required
      permission (`location`), the current `PermissionResult`
      (denied), rationale copy, and an "Open settings" CTA.
- [ ] Tap "Open settings" — the OS settings screen for
      `ACCESS_FINE_LOCATION` should open.
- [ ] Grant the permission in OS settings. Return to do it.
      The badge should update to "optimal" (hidden) within
      ~50 ms of `AppLifecycleState.resumed`.

### v1.2i (`PermissionLifecycleReProbe` + `PermissionService.refresh()`)

- [ ] With a `TriggerCalendarEvent*` routine in the
      "degraded" state (calendar permission denied), open OS
      settings and grant the calendar permission. Return to
      do it. The badge should switch to "optimal" without a
      cold launch.
- [ ] Repeat for every other `PermissionKind` (location,
      contacts, notifications, exact alarm, battery
      optimization, usage stats). Each toggle in OS settings
      → return to do it → badge updates within ~50 ms.

### v1.2j (DST banner + streak-recovery card + pre-notification heads-up)

- [ ] Set the device's time zone to a zone that enters or
      exits DST within the next 24 h (e.g., "America/Los_Angeles"
      during the spring/fall transition weekend). The home
      screen should show the `DstTransitionBanner` at the
      top: "Heads up: DST ends tonight. Your morning
      routine may fire one hour later."
- [ ] With a habit that has a missed day inside the grace
      window (3 hours post-deadline), the home screen
      should show the `StreakRecoveryCard` between the habit
      list and the `DstTransitionBanner`. Tap the card —
      the back-fill flow should open, pre-populated with
      the missed date.
- [ ] Schedule a reminder for 6 min from now. At 5 min and
      1 min before the alarm, a low-importance heads-up
      notification should appear in the status bar:
      "Coming up: <habit name>" / "in 5 min" / "in 1 min".
- [ ] Open the habit detail screen → settings tab. Toggle
      "Pre-notifications" off for that habit. The heads-up
      notifications should stop firing.

### v1.2k (hard-delete affordance on edit screen)

- [ ] Open the edit screen for an existing habit. Scroll to
      the bottom. The "Delete" button (red, full-width)
      should be visible.
- [ ] Tap "Delete" — the confirm dialog should open with
      the habit's name + a "This cannot be undone" warning
      + Cancel / Delete actions.
- [ ] Tap "Delete" in the dialog — the habit + its
      completion log + its alarm schedules should be
      removed (cascade per `docs/v_model/conops.md`).
- [ ] Repeat for a Person edit screen — the cascade should
      remove the cadence + the cadence-routine references.
- [ ] The "Delete" button should NOT appear on the create
      screen (the entity is not in the DB yet).

### v1.2l (shared `MissionWrongAttempts` module)

- [ ] Open a Math mission. Enter 3 wrong answers. The
      take-a-break `SnackBar` should appear and a 60-second
      timer should start. The mission should not accept
      input during the break.
- [ ] Open a Type mission. Enter 3 wrong inputs. The
      take-a-break `SnackBar` should appear with the SAME
      60-second timer (was 30 s on Type before v1.2l; now
      uniform).
- [ ] The Shake / Hold / Memory missions should NOT show
      the take-a-break `SnackBar` (they have no "wrong
      attempt" notion).

### v1.2m (`CompletionLogSection` for review + undo)

- [ ] Open the home screen. The `CompletionLogSection`
      should be visible under the habit list, showing the
      last 7 days of completion entries grouped by date.
- [ ] Tap "Undo" on a completion entry. The entry should be
      removed, the streak should decrement, and any
      in-flight notification for that habit should be
      cancelled.
- [ ] If the completion was triggered by a routine, the
      routine's already-fired `Action` is NOT reversed (the
      copy says "Routine actions are not reversed — only
      the streak and notification are undone"). Confirm
      this is the case.

## Regression checks (re-run the v1.1k checks)

The v1.2 cycle should not have regressed any v1.1
functionality. Re-run:

- [ ] Spanish locale (`Settings → System → Languages
      → Español`). Launch do it. AppBar / settings sections
      / onboarding steps render in Spanish. (v1.1h.)
- [ ] Brand-purple launcher icon + 'd' glyph + check dot.
      On-brand splash. Status-bar notification icon. (v1.1i.)
- [ ] Routines templates #17..#21 apply correctly via the
      generic `RoutineApplyScreen`. (v1.1d.)
- [ ] Per-automation reliability badges (the icon-only
      state, before tapping). (v1.1f.)
- [ ] `PACKAGE_USAGE_STATS` permission rationale +
      deep-link. (v1.1g.)

## Sign-off

When every check above is green, the user accepts the build
as the v1.2 release:

```
v1.2 sign-off: 2026-06-23

Build SHA1: <from release(v1.2) commit>
Build size: <from release(v1.2) commit>
Test count: 1001 / 1001
```

The sign-off line lives in the `release(v1.2)` commit
message; the build SHA1 + size are recorded there.
