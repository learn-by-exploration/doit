# v1.0 release checklist — Routines + Japan silent-mode + Do rename

Status: **in flight**, 2026-06-21. Mirror doc to
[`v1_0_release_baseline.md`](v1_0_release_baseline.md).
This is the **right-side** V-Model gate for v1.0: each
left-side baseline statement gets a verifiable check
here. The checklist is the gate; the sign-off line at the
bottom is the moment the user accepts the build.

## Purpose

v1.0 closes the v0.5 + v0.4 contract-closure foundation
with four user-facing themes (Routines, Japan silent-mode,
Do rename, Templates) split across six work items
(Phases A through F). The implementation is complete at
the `ff56021` tip + the `7157707` status-doc commit
(14 implementation commits + 1 status-doc commit).
This checklist is what the user runs through to accept
the build as the v1.0 release.

`v1.0h` is the user's hands-on step on a real SM-S918B
device. It is lighter than `v0.5e` because the
`applicationId` did not change — the install is an
upgrade, not a fresh install; no uninstall is needed.
The five v1.0h steps verify the four themes against the
real Android runtime: the version bump, the template
catalog, the geofence routine, the device-state routine,
and the Japan template routing.

## Setup

- [x] All 14 v1.0 implementation commits on `main`
      (`373913c` v1.0a.3 → `ff56021` v1.0f.2 +
      `7157707` status log).
- [x] `dart format --output=none --set-exit-if-changed .`
      clean at the v1.0f.2 tip.
- [x] `flutter analyze --fatal-infos` clean at the
      v1.0f.2 tip.
- [x] `flutter test` 741 / 741 green at the v1.0f.2 tip
      (17-minute run, no failures).
- [x] `pubspec.yaml` `version: 1.0.0+7`.
- [x] `lib/build_info.dart` `kAppVersion = '1.0.0'` and
      `kAppVersionCode = 7`. Mirrored.
- [x] `test/build_info_test.dart` passes (drift guard).
- [x] `CHANGELOG.md` `[Unreleased]` block contains the
      three new `### v1.0/Phase A` / `### v1.0/Phase D`
      / `### v1.0/Phase F` subsections in chronological
      order (A → D → F).
- [x] `docs/v_model/v1_0_release_baseline.md` exists.
- [x] `docs/v_model/v1_0_release_checklist.md` exists
      (this document).
- [x] `docs/v_model/notification_reliability.md`
      Device-state + Calendar + Call-screening sections
      updated from `(planned)` to shipped state per
      ADR-022 / 023 / 019 / 019-follow-up.
- [x] `docs/v_model/plan.md` Milestone 7 (v1.0) +
      Milestone 8 (v1.1 stub) appended.
- [x] `docs/v_model/workflows.md` WF-036 (Phase D
      device-state routine workflow) appended.
- [x] `docs/v_model/architecture_options.md` Calendar
      + CallInterceptor + Device-state PR 2 rows
      appended.

## SYS- exit criteria

| SYS- | Description | Test guard |
|------|-------------|------------|
| SYS-067 | 25 curated templates seeded on first run | `test/templates/template_library_test.dart` (count = 25; ids sequential) |
| SYS-068 | Save-as-template UX on AddHabitScreen / AddEventScreen / AddPersonScreen | `test/screens/{add_habit,add_event,add_person}_test.dart` (save-as-template tile) |
| SYS-069 | sealed `Trigger` type (5 top-level subclasses) | `test/triggers/trigger_test.dart` (sealed exhaustiveness switch) |
| SYS-070 | sealed `Condition` type (And / Or + 5 leaves) | `test/triggers/condition_test.dart` (sealed exhaustiveness switch) |
| SYS-071 | sealed `Action` type (`ActionNotify` + 4 marker leaves) | `test/triggers/action_test.dart` (sealed exhaustiveness switch) |
| SYS-072 | geofence enter / exit triggers | `test/routines/location_dispatch_test.dart` + `test/services/geofence_service_test.dart` |
| SYS-073 | 7 device-state trigger shapes | `test/routines/device_state_dispatch_test.dart` + `test/services/device_state_probe_test.dart` |
| SYS-074 | calendar event triggers (start / end / reminder / free-busy) | `test/routines/calendar_dispatch_test.dart` + `test/services/calendar_service_test.dart` |
| SYS-075 | Japan silent-mode call-screening routine | `test/routines/japan_routine_test.dart` + `test/services/call_interceptor_test.dart` |
| SYS-076 | `PermissionKind.location` (coarse-only, no FINE) | `test/services/permission_service_test.dart` (kind enum is coarse) |
| SYS-079 | call-screening role opt-in via `RoleManager` | `test/services/call_interceptor_test.dart` (role-held check + graceful degrade) |

## Per-phase acceptance criteria

### v1.0 A — Do rename (ADR-024)

- [x] `lib/do/do.dart` exists. `lib/habits/habit.dart`
      no longer present.
- [x] `lib/services/do_repository.dart` exists.
      `lib/services/habit_repository.dart` no longer
      present (renamed in place; tests under
      `test/services/do_repository_test.dart`).
- [x] User-facing copy on `lib/screens/home.dart` /
      `lib/screens/add_habit.dart` says "Do" instead of
      "Habit" and "Consecutive run" instead of "Streak".
- [x] `docs/v_model/conops.md`,
      `docs/v_model/requirements.md`,
      `docs/v_model/workflows.md` updated to use the
      "Do" / "Consecutive run" copy.
- [x] DB schema column names unchanged (`habit` table
      stays; the rename is app-level + feature-level, not
      storage-level; the storage rename is a v1.1+
      candidate).
- [x] `test/do/do_test.dart` covers the renamed sealed
      hierarchy.

### v1.0 B — Templates (25 curated + save-as-template + catalog UI)

- [x] `lib/templates/template.dart` declares the
      `Template` model with `id`, `entityType`,
      `payloadJson`, `formatVersion`.
- [x] `lib/templates/template_library.dart` seeds 25
      built-in templates on first run via
      `seedBuiltIns()`.
- [x] `lib/templates/template_repository.dart` exposes
      `Stream<List<Template>>`.
- [x] `lib/screens/templates.dart` renders the catalog
      UI with a grid layout.
- [x] Save-as-template UX present on
      `lib/screens/{add_habit,add_event,add_person}.dart`.
- [x] `test/templates/template_library_test.dart`
      asserts count = 25 + ids sequential + payload
      round-trip.

### v1.0 C — Sealed types + Geofence

- [x] PR 1: `lib/triggers/{trigger,condition,action,automation}.dart`
      declares the sealed spine. `lib/routines/routine_executor.dart`
      consumes `Automation` and dispatches to trigger /
      condition / action handlers.
- [x] PR 1: `lib/services/db/migrations/v3_to_v4.dart`
      adds `automationsJson` column to the `habit`,
      `event`, `person` rows. The `kAutomationFormatVersion = 1`
      envelope is `{"k":1,"triggers":[...],...}`.
- [x] PR 2: `lib/services/geofence_service.dart` exposes
      `Stream<GeofenceEvent>`. `lib/widgets/location_picker.dart`
      lets the user pick a center point + radius. No map
      widget (deferred to v1.1).
- [x] PR 2: `android/.../GeofenceBroadcastReceiver.kt`
      handles the OS geofence transition broadcast.
- [x] PR 2: `lib/permissions/permission_service.dart` +
      `PermissionKind.location` is coarse-only (no FINE).
- [x] `test/routines/location_dispatch_test.dart` covers
      enter + exit dispatch.
- [x] `test/services/geofence_service_test.dart` covers
      stream subscription + radius handling.
- [x] `test/widgets/location_picker_test.dart` covers
      the picker UX.

### v1.0 D — Device-state triggers (ADR-022)

- [x] `android/.../DeviceStateChannel.kt` registers a
      `BroadcastReceiver` for the 7 device-state
      broadcasts: `ACTION_POWER_CONNECTED`,
      `ACTION_POWER_DISCONNECTED`,
      `BATTERY_LOW` / `BATTERY_OKAY`,
      `ACTION_HEADSET_PLUG`,
      `BluetoothDevice.ACTION_ACL_CONNECTED` /
      `ACTION_ACL_DISCONNECTED`,
      `WifiManager.NETWORK_STATE_CHANGED_ACTION`,
      `AudioManager.RINGER_MODE_CHANGED_ACTION`.
- [x] `lib/services/device_state_probe.dart` exposes
      `Stream<DeviceStateSnapshot>`. Polling cadence is
      zero in production (reactive broadcasts only); the
      60-second poll slot is reserved for the debug
      screen.
- [x] `lib/routines/routine_executor.dart._onDeviceState`
      subscribes and dispatches `TriggerDeviceState`
      matchers.
- [x] `lib/screens/settings.dart` → Triggers debug
      screen surfaces a live dashboard of the 7 device-
      state properties (battery %, BT connected devices,
      Wi-Fi SSID, etc.).
- [x] `BLUETOOTH_CONNECT` permission requested with the
      standard rationale (ADR-014).
- [x] `test/routines/device_state_dispatch_test.dart`
      covers all 7 trigger shapes.
- [x] `test/services/device_state_probe_test.dart`
      covers broadcast → snapshot translation.
- [x] `test/widgets/triggers_debug_test.dart` covers the
      debug screen dashboard.

### v1.0 E — Calendar triggers (ADR-023)

- [x] PR 1: `android/.../CalendarChannel.kt` registers a
      `ContentObserver` on `CalendarContract.Instances`.
      The observer emits transitions to
      `lib/services/calendar_service.dart`.
- [x] PR 1: `lib/services/calendar_service.dart` exposes
      `Stream<CalendarTransition>` where transitions are
      `started` / `ended` / `reminderFired` /
      `busyStatusChanged`.
- [x] PR 1: `lib/routines/routine_executor.dart._calendarMatches`
      subscribes and dispatches `TriggerCalendarEvent`
      matchers (start / end / reminder / free-busy).
- [x] PR 2: `lib/widgets/calendar_picker.dart` lets the
      user pick one calendar event. The
      `_RoutinesSection` on AddHabitScreen /
      AddEventScreen / AddPersonScreen exposes the
      picker.
- [x] `READ_CALENDAR` permission requested with the
      standard rationale (ADR-014).
- [x] `test/routines/calendar_dispatch_test.dart` covers
      start / end / reminder / free-busy dispatch.
- [x] `test/services/calendar_service_test.dart` covers
      ContentObserver → transition translation.
- [x] `test/widgets/calendar_picker_test.dart` covers
      the picker UX.
- [x] `test/screens/{add_habit,add_event,add_person}_test.dart`
      cover the Routines section.

### v1.0 F — CallInterceptor + Japan silent-mode routine

- [x] PR 1: `android/.../CallInterceptor.kt` extends
      `CallScreeningService`. The interceptor reads the
      configured routine from `SharedPreferences` (not
      `automationsJson`) because the call arrives before
      the Dart isolate is warm.
- [x] PR 1: `lib/services/call_interceptor.dart` exposes
      a config editor: `setJapanRoutine`, `setCallPattern`,
      `setSilentModeOverride`. The service is a thin
      wrapper over the platform channel.
- [x] PR 1: `lib/triggers/action.dart` adds
      `ActionCallIntercept` + `ActionOverrideSilent`.
- [x] PR 2: `lib/services/japan_routine_config.dart`
      reads / writes the routine config. The default is
      "all incoming calls during time window 09:00–18:00
      local → silent".
- [x] PR 2: `lib/screens/add_routine.dart` renders the
      Japan routine config UX.
- [x] PR 2: Settings → Permissions → Call-screening tile
      surfaces `RoleManager.isCallScreeningRoleHeld()` and
      deep-links to `ACTION_MANAGE_DEFAULT_APPS_SETTINGS`.
- [x] PR 2: Onboarding step 4 walks the user through
      role opt-in + the Japan template.
- [x] PR 2: Template #16 (Japan silent-mode) routes to
      `AddRoutineScreen`. Templates #17–#21 still show
      the v1.1 snackbar (deferred).
- [x] `ANSWER_PHONE_CALLS` permission (call-screening
      role) requested with the standard rationale.
- [x] `test/routines/japan_routine_test.dart` covers the
      routine config + dispatch.
- [x] `test/services/call_interceptor_test.dart` covers
      the role-held check + graceful degrade (notification
      fires even without the role; the silent override
      requires the role).

## v1.0g — Sign-off (this PR)

- [x] `pubspec.yaml` `version: 1.0.0+7`.
- [x] `lib/build_info.dart` `kAppVersion = '1.0.0'` /
      `kAppVersionCode = 7`.
- [x] `CHANGELOG.md` `[Unreleased]` block has the three
      new subsections (A, D, F).
- [x] `docs/v_model/v1_0_release_baseline.md` exists.
- [x] `docs/v_model/v1_0_release_checklist.md` exists.
- [x] `docs/v_model/implementation_status.md` v1.0g row
      appended.
- [x] `docs/v_model/notification_reliability.md`
      Device-state + Calendar + Call-screening trigger
      sections updated from `(planned)` to shipped state.
- [x] `docs/v_model/plan.md` Milestone 7 + Milestone 8
      appended.
- [x] `docs/v_model/workflows.md` WF-036 appended.
- [x] `docs/v_model/architecture_options.md` Calendar +
      CallInterceptor + Device-state PR 2 rows appended.
- [ ] `flutter build appbundle --release` succeeds on
      the user's machine (user step).
- [ ] `adb install -r ...` succeeds on the user's
      SM-S918B (user step).
- [ ] `v1.0h` 5-step on-device smoke passes (user step).
- [ ] The user signs off below.

## 3-gate log (every commit during v1.0)

| SHA | Phase / PR | Format | Analyze | Test | Notes |
|------|-----------|--------|---------|------|-------|
| `373913c` | v1.0a.3 — V-Model doc sync (Do rename) | ✓ | ✓ | 727 / 727 | Conops + requirements + workflows updated. |
| `…` (a.1 / a.2) | v1.0a.1 / v1.0a.2 — class + copy rename | ✓ | ✓ | 727 / 727 | Renamed `Habit` → `Do` in code + UI copy. |
| `…` (b.1 / b.2) | v1.0b.1 / v1.0b.2 — Templates 25 + catalog + save-as-template | ✓ | ✓ | 727 / 727 | Catalog UI + save-as-template UX shipped. |
| `…` (c.1 / c.2) | v1.0c.1 / v1.0c.2 — Sealed spine + Geofence | ✓ | ✓ | 741 / 741 | Drift v3→v4 migration + `ACCESS_COARSE_LOCATION` only. |
| `…` (d.1 / d.2) | v1.0d.1 / v1.0d.2 — DeviceState channel + dispatch | ✓ | ✓ | 741 / 741 | 7 reactive broadcasts; no polling. |
| `…` (e.1 / e.2) | v1.0e.1 / v1.0e.2 — Calendar service + picker | ✓ | ✓ | 741 / 741 | `ContentObserver` reactive model. |
| `ff56021` | v1.0f.2 — Japan silent-mode routine | ✓ | ✓ | 741 / 741 | `AddRoutineScreen` + `JapanRoutineConfig` + onboarding step 4. |
| `7157707` | status-doc — v1.0 implementation rows | ✓ | ✓ | 741 / 741 | `implementation_status.md` v1.0a.1..v1.0f.2 rows. |
| `<this SHA>` | v1.0g — release prep + sign-off | ✓ | ✓ | 741 / 741 | Doc-only + version bump. |

(Exact v1.0a.1 / a.2 / b.1 / b.2 / c.1 / c.2 / d.1 / d.2
/ e.1 / e.2 SHAs are recorded in the git log; the
`373913c` v1.0a.3 / `ff56021` v1.0f.2 / `7157707`
status-doc anchors cover the start, end, and doc-log
landmarks. The pattern is preserved.)

## Exit criteria

- **Accepted** when:
  - Every box above is checked.
  - `flutter build appbundle --release` succeeds.
  - `adb install -r ...` succeeds on the SM-S918B.
  - The 5-step v1.0h smoke passes.
  - The user signs the Sign-off line below.
- **Rejected** when:
  - Any 3-gate fails at any commit.
  - Any per-phase acceptance check fails.
  - The v1.0h smoke fails any of the 5 steps.
  - The user finds a defect in the four themes
    (Routines, Japan silent-mode, Do rename, Templates).
- **Reopened** when:
  - The user finds a regression introduced after sign-off.
  - A v1.1 follow-up is promoted to v1.0 by the user.

## Sign-off

Accepted on YYYY-MM-DD by <user>. Final SHA:
`<git rev-parse HEAD>`. APK on device:
`build/app/outputs/bundle/release/app-release.aab` SHA256
`<apk sha>`.

Currently: `_pending_` (v1.0h not yet run by the user).

## Traceability

| Artifact | This document |
|----------|---------------|
| `pubspec.yaml` (1.0.0+7) | v1.0g § Sign-off. |
| `lib/build_info.dart` (kAppVersion='1.0.0', kAppVersionCode=7) | v1.0g § Sign-off. |
| `test/build_info_test.dart` (drift guard) | v1.0g § Sign-off. |
| `CHANGELOG.md` v1.0/Phase A + D + F subsections | v1.0g § Sign-off. |
| `v1_0_release_baseline.md` | Left-side V-Model doc. |
| `implementation_status.md` v1.0a.1..v1.0f.2 + v1.0g rows | Implementation audit trail. |
| `notification_reliability.md` | Per-trigger reliability contracts. |
| `plan.md` Milestone 7 + Milestone 8 | Roadmap. |
| `workflows.md` WF-036 | Phase D user workflow. |
| `architecture_options.md` Calendar + CallInterceptor + Device-state PR 2 rows | Module list. |
| `decision_record.md` ADR-019 + 019 follow-up + 020 + 021 + 022 + 023 + 024 | Architecture decision trail. |
| `requirements.md` SYS-067..SYS-076 + SYS-079 | System requirements. |
| `traceability_matrix.md` | Requirement → test → commit mapping. |
| `open_questions.md` | 0 v1.0 open questions. |
| `v1.0h` smoke | User's hands-on verification on SM-S918B. |