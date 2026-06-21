# v1.0 — Routines + Japan silent-mode + Do rename

Status: **in flight**, 2026-06-21. All six v1.0 phases
(A through F) are closed at the `ff56021` tip + the
`7157707` status-doc commit. v1.0 ships four user-facing
themes that build on the v0.5 + v0.4 contract-closure
foundation:

1. **Routines are first-class** — every do / event /
   person gets a Trigger / Condition / Action automation
   list (Phases C, D, E, F).
2. **Japan silent-mode is a real routine** — template
   #16 routes to a working `AddRoutineScreen` that
   configures `CallInterceptor` via `ROLE_CALL_SCREENING`
   (Phase F).
3. **The Habit → Do rename finishes** — class names,
   user-facing copy, and V-Model docs all move from
   "Habit / Streak" to "Do / Consecutive run" (Phase A).
4. **Templates carry the curated library** — 25 templates
   seeded on first run, save-as-template UX, catalog UI
   (Phase B).

This is the **left-side** V-Model doc for v1.0. The
right-side gate is
[`v1_0_release_checklist.md`](v1_0_release_checklist.md).
v1.0 is a **feature milestone** — the four themes above
are the ship. v1.1 (the polish / expansion milestone)
follows.

## Why v1.0 exists

The v0.5 contract closure (`a04e392` v0.5d + `ce6dd83`
v0.5e-fix) shipped a working "do it" Android app with
permissions, reliability, backup, and a tested release
APK. The user installed it on a real SM-S918B and the
app worked, but three things were still missing:

- **Routines are an empty `automationsJson` column.**
  The Phase C PR 1 sealed-type spine shipped but no
  trigger kind was wired end-to-end. v1.0 closes the
  loop with geofence (C PR 2), device-state (D), calendar
  (E), and call-screening (F).
- **"Habit" still names the model class and the home
  screen copy.** v0.5a repainted the app-level name but
  left the feature-level name in place. v1.0a finishes
  the rename.
- **The curated template library was 19 templates, not
  the 25 the user wanted.** v1.0b lands the 25-template
  quota + save-as-template + catalog UI.

v1.0 fixes all three. The four themes are interleaved
because the rename touches every file the routine wiring
also touches, and shipping all four themes as one
milestone produces one signed-off build (instead of four
APK-install cycles on the user's primary phone).

## Scope

Six work items, three of which are themselves split into
PRs (A.1/A.2/A.3, B.1/B.2/B.3, etc.). v1.0 owns 14
implementation commits and 1 release-prep commit (this
document's PR). Every commit on `main` during v1.0 must
pass the 3-gate _before_ push.

| ID | What | Why | Why not earlier |
|----|------|-----|------------------|
| v1.0 A | `Habit` → `Do` rename (class, copy, docs) | The v0.5a rename left the feature name in place. v1.0a finishes it. | Deferred: v0.5a was about the *app* name; the *feature* name needed its own milestone. |
| v1.0 B | Templates: curated library (25) + save-as-template + catalog UI | The user wanted a "browse what other people use" entry point. Phase B ships the curated library + the UX. | Deferred: Phase B was sequenced after Phase A so the catalog UI saw the renamed "Do" copy first. |
| v1.0 C | `Trigger` / `Condition` / `Action` sealed types + Geofence | The Phase C PR 1 spine was required before any non-time trigger kind could be wired. | Deferred: PR 2 (geofence) was the first concrete trigger kind, to validate the spine shape. |
| v1.0 D | Device-state triggers (reactive broadcasts) | The 7 device-state properties (charging, battery, BT, Wi-Fi, headphones, ringer, foreground) are the second trigger kind. | Deferred: Phase D follows C so the executor wire-up has a precedent (geofence). |
| v1.0 E | Calendar triggers (native `CalendarContract`) | Calendar events are a routine trigger kind for habit-related reminders. | Deferred: Phase E follows D so the trigger matching engine has two precedents. |
| v1.0 F | CallInterceptor (Kotlin `CallScreeningService`) + Japan silent-mode template | Incoming calls are a trigger kind + a silent-mode override action. Template #16 needs the wiring. | Deferred: Phase F is the closing trigger kind; the template work was sequenced after the wiring landed. |

## Constraints (v1.0 floor — same as v0.5)

The v1.0 floor is the v0.5 floor: no `INTERNET`, no
analytics, no telemetry, no cloud sync, no account, no
advertising SDK, no third-party crash reporter, no
`CALL_PHONE`, no `READ_CALL_LOG`, no `RECORD_AUDIO`.
v1.0a / v1.0b (the rename + templates) do **not** add
network code. v1.0c / v1.0d / v1.0e / v1.0f (the routine
wiring) do **not** add network code. The four new
permissions v1.0 requests (`ACCESS_COARSE_LOCATION`,
`READ_CALENDAR`, `BLUETOOTH_CONNECT`,
`ROLE_CALL_SCREENING`) are all **local-only** — none of
them enable a network call. The geofence subscription is
local; the device-state broadcasts are local; the
calendar `ContentObserver` is local; the call-screening
interceptor is local.

v1.0 does **not** loosen any v0.5 constraint. The
`CallInterceptor.kt` reads from `SharedPreferences` (no
network); the `CalendarChannel.kt` reads from
`CalendarContract.Instances` (no network); the
`DeviceStateChannel.kt` reads from the seven
broadcasts (no network); the geofence subscription uses
the OS `GeofencingClient` (no network).

v1.0 does **not** re-name the `StreakCalculator` /
`StreakService` / `StreakSnapshot` /
`streak_calculator.dart` / `streak_service.dart` /
`StreakConfig` identifiers. They are **feature-level**
names, not app-level names. Renaming them is out of
scope.

## System Requirements (new in v1.0)

v1.0 owns the following SYS- IDs in
[`requirements.md`](requirements.md):

- **SYS-067** — 25 curated templates seeded on first run
  via `TemplateLibrary.seedBuiltIns`. (Phase B)
- **SYS-068** — save-as-template UX on AddHabitScreen /
  AddEventScreen / AddPersonScreen. (Phase B)
- **SYS-069** — sealed `Trigger` type with five
  top-level subclasses (`TriggerTimeOfDay`,
  `TriggerLocationEnter/Exit`, `TriggerDeviceState`,
  `TriggerCalendarEvent`, `TriggerCallIncoming`).
  (Phase C PR 1)
- **SYS-070** — sealed `Condition` type with
  `ConditionAnd` / `ConditionOr` / 5 leaves. (Phase C PR 1)
- **SYS-071** — sealed `Action` type with `ActionNotify`
  + 4 marker leaves. (Phase C PR 1)
- **SYS-072** — geofence enter / exit triggers via
  `GeofenceService` + `ACCESS_COARSE_LOCATION`. (Phase C PR 2)
- **SYS-073** — 7 device-state trigger shapes via
  `DeviceStateService` + `BLUETOOTH_CONNECT`.
  (Phase D)
- **SYS-074** — calendar event triggers (start / end /
  reminder / free-busy) via `CalendarService` +
  `READ_CALENDAR`. (Phase E)
- **SYS-075** — Japan silent-mode call-screening
  routine via `CallInterceptor.kt` + `JapanRoutineConfig`.
  (Phase F)
- **SYS-076** — `PermissionKind.location` (coarse-only,
  no FINE) per the Phase C PR 2 mandate. (Phase C PR 2)
- **SYS-079** — call-screening role opt-in via
  `RoleManager.requestCallScreeningRole()` +
  `isCallScreeningRoleHeld()`. (Phase F PR 2)

## Architecture decisions (new in v1.0)

Seven ADRs are appended to
[`decision_record.md`](decision_record.md):

- **ADR-019** — Phase F PR 1: `CallScreeningService` over
  `PhoneAccount`. The role-based call-screening API is
  the right shape for incoming-call matching and
  ringer-mode override; `PhoneAccount` is for *outgoing*
  calls and does not let us see / block incoming calls.
- **ADR-019 follow-up** — Phase F PR 2: Japan-routine
  apply UX + role opt-in. The user configures
  `JapanRoutineConfig` via `AddRoutineScreen`; the
  routine config lives in `SharedPreferences` (not
  `automationsJson`) because the interceptor reads it on
  every call, before the Dart isolate is warm. Role opt-in
  is via `RoleManager`; a user who does not grant the role
  still gets the notification but no silent-mode
  override (graceful degrade).
- **ADR-020** — Phase B: Template model + JSON envelope.
  `kTemplateFormatVersion = 1`; the envelope is
  `{"k":1,"<entityType>":{...}}` keyed on `do` / `event`
  / `person` / `routine`. The routine inner payload is
  opaque in Phase B; the decoder lands with Phase F.
- **ADR-021** — Phase C PR 2: `geolocator` over
  `flutter_geofence` / `geofence_service`. The deciding
  factor is the `ACCESS_COARSE_LOCATION`-only mandate;
  `geolocator` is the only candidate that satisfies it
  without bringing in an unmaintained package.
- **ADR-022** — Phase D: device-state polling cadence
  is **reactive-first** (broadcasts from
  `DeviceStateChannel.kt`); the 60-second poll slot is
  reserved for the debug screen only. The executor never
  polls.
- **ADR-023** — Phase E PR 1: native `CalendarContract`
  over `device_calendar`. The deciding factor is the
  `ContentObserver` shape: the OS calls us back when an
  instance row is inserted / updated / deleted; we match
  the change against the registered automation set;
  latency is sub-second. A 5-minute poll would be
  costlier and the user would perceive a 30 s – 5 min
  latency between "calendar event started" and
  "routine fired".
- **ADR-024** — Phase A: rename `Habit` → `Do` + drop
  the "Streak" display copy. Feature-level identifiers
  (`StreakCalculator`, `StreakService`, etc.) stay.

## Approval status

- **2026-06-21**: v1.0 plan approved via AskUserQuestion
  (user selected "v1.0 release PR (sign-off prep)").
  Single release-prep PR; no code changes beyond the
  version bump. All 14 v1.0 implementation commits are
  on `main` (`373913c` v1.0a.3 through `ff56021`
  v1.0f.2 + `7157707` doc log).
- **v1.0h** is the user's hands-on step: the five-step
  on-device verification on a real SM-S918B device
  (parallels v0.5e but lighter: no `applicationId`
  change, no uninstall is needed). The checklist
  sign-off line is the gate.

## What is explicitly out of scope for v1.0

- **Map widget in `LocationPicker`** (Phase C PR 2
  deferral). Adding `google_maps_flutter` (~5 MB APK +
  Play Services key) or `flutter_map` is a v1.1
  candidate. v1.1.
- **Per-automation reliability badges.** The executor
  surfaces a global reliability banner
  (`Reliability.degraded`); per-automation badges are a
  v1.1 follow-up. v1.1.
- **Generic routine apply UX for templates #17–#21.**
  v1.0f.2 routes only template #16 (Japan) to a real
  `AddRoutineScreen`; templates #17–#21 still show
  the v1.1 snackbar. The generic routine apply UX needs
  a `RoutineTemplatePayload` decoder and a 6-template
  picker workflow. v1.1.
- **Foreground-app permission (`PACKAGE_USAGE_STATS`)**.
  The trigger fires on a best-effort basis without the
  permission; the debug screen surfaces a banner
  explaining the degraded mode. A v1.1 follow-up needs a
  separate SYS- ID and ADR. v1.1.
- **i18n.** All new copy is hard-coded English. v1.1.
- **Wear OS / Android Auto.** Out of v1.0 scope. v1.1+.
- **Multi-user / multi-device sync.** Out of project
  scope.
- **A new app icon + splash.** v1.0 keeps the default
  Flutter icon and splash. v1.1.
- **A `RoutineTemplatePayload` decoder.** The curated
  routines carry an opaque `{"k":1,"routine":{...}}`
  envelope today; the decoder lands with v1.1's generic
  routine apply UX.

## Traceability

| Artifact | This document |
|----------|---------------|
| `requirements.md` SYS-067..SYS-076 + SYS-079 | The SYS- IDs above. |
| `decision_record.md` ADR-019 + 019 follow-up + 020 + 021 + 022 + 023 + 024 | The ADRs above. |
| `lib/do/do.dart` + `lib/services/do_repository.dart` | v1.0a.1 — class rename. |
| `lib/screens/add_habit.dart` + `lib/screens/home.dart` + every screen that renders a habit name | v1.0a.2 — user-facing copy rename. |
| `docs/v_model/conops.md` + `requirements.md` + `workflows.md` | v1.0a.3 — V-Model doc sync. |
| `lib/templates/{template.dart,template_library.dart,template_repository.dart}` | v1.0b.1 — template model + repository + 25-template seed. |
| `lib/screens/templates.dart` + `lib/screens/{add_habit,add_event,add_person}.dart` | v1.0b.2 — catalog UI + save-as-template. |
| `lib/triggers/{trigger,condition,action,automation}.dart` + `lib/routines/routine_executor.dart` + `lib/services/db/migrations/v3_to_v4.dart` | v1.0c.1 — sealed-type spine + Drift v3→v4. |
| `lib/services/geofence_service.dart` + `lib/widgets/location_picker.dart` + `android/.../GeofenceBroadcastReceiver.kt` | v1.0c.2 — geofence + `LocationPicker` + ADR-021. |
| `android/.../DeviceStateChannel.kt` + `lib/services/device_state_probe.dart` | v1.0d.1 — device-state channel + service. |
| `lib/routines/routine_executor.dart` (device-state arm) + Settings → Triggers debug screen | v1.0d.2 — `TriggerDeviceState` wired + ADR-022. |
| `lib/services/calendar_service.dart` + `android/.../CalendarChannel.kt` | v1.0e.1 — calendar service + ADR-023. |
| `lib/widgets/calendar_picker.dart` + Routines section on Add screens | v1.0e.2 — `CalendarPicker` UI. |
| `android/.../CallInterceptor.kt` + `lib/services/call_interceptor.dart` + `ActionCallIntercept` + `ActionOverrideSilent` | v1.0f.1 — `CallInterceptor` + ADR-019. |
| `lib/services/japan_routine_config.dart` + `lib/screens/add_routine.dart` + Settings → Call-screening tile + onboarding step 4 | v1.0f.2 — Japan silent-mode routine + ADR-019 follow-up. |
| `pubspec.yaml` (1.0.0+7) + `lib/build_info.dart` (kAppVersion='1.0.0') | v1.0g — version bump. |
| `CHANGELOG.md` v1.0 `[Unreleased]` section | v1.0g — `[Unreleased]` moves to `[1.0.0]`. |
| `test/build_info_test.dart` | Drift guard for the version bump. |
| `v1_0_release_checklist.md` | The right-side gate. |
| `implementation_status.md` v1.0a.1..v1.0f.2 + v1.0g rows | Implementation audit trail. |
| `traceability_matrix.md` | SYS-067..SYS-076 + SYS-079 rows. |
| `docs/v_model/open_questions.md` | All v0.x items closed; no v1.0 items open. |