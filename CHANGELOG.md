# do it — Changelog

All notable changes to the do it app are documented here. do it
follows a V-Model process: each release has a left-side baseline
(`docs/v_model/v<major>_<minor>_baseline.md`) and a right-side
checklist (`v<major>_<minor>_release_checklist.md`). This changelog
is the user-facing summary of what shipped in each release; the
V-Model artifacts are the engineering contract.

## [1.1.0] — 2026-06-21 — Polish + expansion

Nine v1.1 sub-entries (v1.1a through v1.1i) ship nine
follow-ups to the v1.0 foundation. The headline themes:
**routines** (RoutineConfig + dispatch + ActionOpenApp +
generic apply UX for templates #17..#21), **location**
(offline map preview for the location picker),
**reliability** (per-automation badges + the
PACKAGE_USAGE_STATS permission flow), **i18n** (ARB
scaffolding + Spanish smoke-test locale), and **branding**
(custom launcher icon + splash + notification icon).
Version `1.0.0+7` → `1.1.0+8`. SHA range: `<v1.1a SHA>`
→ `78b1267`. 893 / 893 tests, `dart format` clean,
`flutter analyze --fatal-infos` clean. Right-side gate:
`implementation_status.md` rows v1.1a..v1.1i.

### v1.1a — `RoutineConfig` value class + per-template persistence

(SYS-080 / ADR-025.)

Routines now have a first-class value object instead of
free-form JSON. `lib/services/routine_config.dart`
defines a structural-`==`, deterministic-`hashCode`,
immutable `RoutineConfig` with `copyWith` and a
version-free `toJson` / `fromJson` codec (the codec uses
per-shape discriminators so an envelope from a future
client can fail-soft instead of crashing). The class
follows the singleton-with-`_ready` gate pattern that
every service in `lib/services/` uses (see
`.claude/rules/lib-services.md`).

**What's new**

- `SettingsService.setRoutine(templateId, config)` /
  `getRoutine(templateId)` / `deleteRoutine(templateId)`
  / `routines` `ValueNotifier<Map<String, RoutineConfig>>`
  are persisted under the `doit.routine.<templateId>`
  SharedPreferences key — a stable shape that survives
  uninstall/reinstall and is independent of the
  `JapanRoutineConfig` legacy keys (the deliberate
  non-migration is documented in ADR-025).
- 19 new tests (12 codec + 5 settings-service + 2
  routine-executor dispatch regression).

ADR-025 / SYS-080. See `decision_record.md` ADR-025 for
the rationale on the codec shape + persistence key.

### v1.1b — Routine executor: dispatch + reactive settings

The executor-side half of v1.1: `RoutineExecutor`
consumes `SettingsService.routines` reactively via a
`ValueNotifier` listener — no manual `executor.refresh()`
is needed after a settings change. `_dispatchAction` is
a single exhaustive `is`-switch over all five `Action`
leaves (ADR-021 wired). Per the V-Model, no widget code
in this PR; the widget-side follow-up is v1.1c.

**What's new**

- Reactive subscription to `SettingsService.routines`
  via `ValueNotifier.addListener`.
- `_dispatchAction` is one exhaustive `is`-switch over
  all five `Action` leaves (`ActionOpenApp` is added in
  v1.1c).
- 16 new tests (4 dispatch + 12 reactive subscription
  tests).

### v1.1c — `ActionOpenApp` + `RoutineOpenAppRequest` + `RoutineBanner`

(SYS-082 / ADR-026.)

A routine can now ask the user to open an app (e.g., "When
I arrive at the gym, open Spotify"). The request is queued
in FIFO order and surfaced as a passive banner on the
home screen; the user taps to dismiss or to open.

**What's new**

- New `ActionOpenApp` `Action` leaf.
- New `RoutineOpenAppRequest` value class +
  `pendingOpenApp` `ValueListenable`.
- New passive `RoutineBanner` widget that drains FIFO.
  Captures `NavigatorState` synchronously inside `build`
  to avoid the stale-`BuildContext` crash that an
  async-after-build pattern would risk.
- The home screen places the banner under
  `ReliabilityBanner.fromService()` so it sits in the
  same slot as the existing reliability hint.
- 4 new banner tests.

ADR-026 / SYS-082.

### v1.1d — Generic `RoutineApplyScreen` for templates #17..#21

(SYS-083 / ADR-027.)

Templates #17 through #21 (the second batch of curated
routines) were a "Coming in v1.1" badge on the Templates
screen in v1.0. v1.1d routes them through a generic
`RoutineApplyScreen` that knows how to decode any
`RoutineTemplatePayload` envelope and let the user save,
update, or delete the routine. The badge is removed; the
existing "Use this" button does the job.

**What's new**

- New `lib/routines/routine_template_payload.dart` —
  fail-soft decoder for the
  `{k:1, routine:{trigger, condition, action, note}}`
  envelope (an envelope from an old format falls through
  to a "this template needs an update" fallback rather
  than crashing the templates screen).
- New `lib/screens/routine_apply.dart` — generic apply
  UX with enable toggle, Save / Update / Delete, and
  the malformed-envelope fallback path.
- New `SettingsService.deleteRoutine(templateId)`.
- `TemplatesScreen._onUse` routes templates #17..#21 to
  the new screen.
- 27 new tests (12 codec + 13 settings-service + 6 widget
  + 2 catalog regression updates).

ADR-027 / SYS-083.

### v1.1e — Offline `LocationMapPreview` for `LocationPicker`

(SYS-084 / ADR-028.)

The location picker used to be three text fields (lat, lon,
radius). It now shows a map-style preview of the geofence
footprint: a stylised grid + a pin + a ring at the chosen
radius. The preview is a pure `CustomPaint` widget — no
`flutter_map`, no `INTERNET` permission. The pin follows
typed coordinates in real time as the user types.

**What's new**

- New `lib/widgets/location_map_preview.dart` — pure
  `CustomPaint` widget with stylised grid + pin + geofence
  ring. Equirectangular projection helpers exposed for
  tests.
- `LocationPicker` mounts the preview between the lat/lon
  fields and the "Use current location" button.
- `lat` / `lon` `TextFormField`s gain
  `onChanged: (_) => setState(() {})` so the pin follows
  typed coordinates.
- 15 new tests (11 preview widget/helper + 4 picker + a
  scroll-up drag for the On exit path because the
  preview's added height made the Save button sit at the
  bottom-sheet's scroll-detector overlap).

**Not in this release:** swapping the `CustomPaint` body
for `flutter_map` + cached tiles. That would need the
`INTERNET` permission, which is out of v1.1 scope. v1.2
candidate.

ADR-028 / SYS-084.

### v1.1f — Per-automation reliability badges

(SYS-085 / ADR-029.)

The home screen today shows a global `Reliability.degraded`
banner. v1.1f adds a per-automation badge to each routine
row in the add-do / add-person / add-event screens, so the
user can see which routine is in the degraded mode without
opening the debug screen. The badge hides itself for
optimal automations, paints warning-amber for degraded
(matches `ReliabilityBanner`), and info-outline for
unknown.

**What's new**

- New `lib/routines/automation_reliability.dart` —
  `AutomationReliability` enum + a pure
  `automationReliability(Automation, statuses)`
  function exhaustive over the sealed `Trigger`
  hierarchy via `_requiredPermissionForTrigger`
  (`TriggerLocation*` → `PermissionKind.location`,
  `TriggerCalendarEvent*` → `PermissionKind.calendar`,
  `TriggerDeviceState*` / `TriggerCallIncoming*` /
  `TriggerTimeOfDay` → `null`).
- New `lib/widgets/automation_reliability_badge.dart` —
  40×40 dp `IconButton` wrapped in a
  `ValueListenableBuilder` over
  `PermissionService.instance.statuses`.
- Three `_RoutineRow` widgets (`add_habit` / `add_person`
  / `add_event`) restructure their trailing slot from a
  single `IconButton` into a
  `Row(min, [badge, remove])`.
- 28 new tests (16 pure-function unit tests + 11 widget
  tests + 1 catalog regression test).

**Not in this release:** the `onTap` dialog wiring
(deferred to a follow-up). v1.2 candidate: fold
`TriggerCallIncoming*` into the badge once `RoleManager`
is wired through `PermissionService`.

ADR-029 / SYS-085.

### v1.1g — `PACKAGE_USAGE_STATS` permission + rationale UX

(SYS-086 / ADR-030.)

`PACKAGE_USAGE_STATS` is a special-access permission —
the system has no on-demand grant dialog, so the user has
to flip a switch in Settings → Special access → Usage
access. v1.1g ships the probe + deep-link + rationale
copy for the permission. The actual `TriggerForegroundApp`
routine leaf that will consume the permission is v1.2
scope.

**What's new**

- New `lib/services/usage_stats_service.dart` —
  `UsageStatsService` singleton with `isGranted()` probe
  + `openSettings()` deep-link. Abstract
  `UsageStatsSource` seam; production
  `_MethodChannelUsageStatsSource` talks to
  `doit/device_state`; the test `ScriptedUsageStatsSource`
  is hand-driven.
- `PermissionService` gains `PermissionKind.usageStats`,
  `requestUsageStats()`, `refreshUsageStats()`. The probe
  is fire-and-forget from `init()` via
  `unawaited(_refreshUsageStatsAfterInit())` —
  mandatory because `MethodChannel.invokeMethod` returns
  a real `Future` that does NOT advance in a widget-test
  fake-async zone (the v1.1g diagnostic caught this when
  `calendar_picker_test.dart` hung at
  `await PermissionService.instance.init()`).
- `PermissionSheet` extends its sealed `PermissionKind`
  switch with `_meta` rationale copy + routes the
  "Allow" CTA to the deep-link (no system dialog).
- `Settings._PermissionTile._reProbe` calls
  `refreshUsageStats()` on `usageStats` (the only kind
  that re-probes rather than re-requests).
- New manifest entry
  `<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" tools:ignore="ProtectedPermissions"/>`
  — cross-checked against the v0.1 permission baseline.
- Kotlin side (`DeviceStateChannel.kt`) gains
  `isUsageStatsGranted` (uses
  `AppOpsManager.unsafeCheckOpNoThrow(OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)`)
  + `openUsageAccessSettings` (launches
  `Settings.ACTION_USAGE_ACCESS_SETTINGS` with
  `FLAG_ACTIVITY_NEW_TASK`).
- 8 new `UsageStatsService` unit tests.

**Not in this release:** the `TriggerForegroundApp` leaf
that will consume `PermissionKind.usageStats` — v1.2
candidate.

ADR-030 / SYS-086.

### v1.1h — i18n scaffolding (ARB extraction + `es` locale + `localizedApp` test helper)

(SYS-087 / ADR-031.)

Every user-facing string moves to ARB files. English
(`app_en.arb`) is the source of truth; Spanish
(`app_es.arb`) is a smoke-test locale for the codegen +
delegate pipeline (NOT a professional translation — a
v1.2 follow-up with a native Spanish speaker). The
generated `AppLocalizations` class is wired through
`lib/main.dart` so every screen reads its copy from
`AppLocalizations.of(context)` at runtime.

**What's new**

- New `lib/l10n/app_en.arb` (~60 keys — source of truth
  for AppBar titles, snackbars, empty states, settings
  sections, theme / anchor / reliability copy, permission
  tile labels, onboarding step labels, licenses / version
  rows, plus ICU plural in `homeSelectionAppBarTitle`
  and `homeSnackbarMarkedCount`).
- New `lib/l10n/app_es.arb` (Spanish translation of every
  key — smoke-test locale for the codegen + delegate
  pipeline).
- New top-level `l10n.yaml` drives `flutter gen-l10n`
  (`arb-dir: lib/l10n`, `template-arb-file: app_en.arb`,
  `output-class: AppLocalizations`,
  `output-dir: lib/l10n/gen`, `nullable-getter: false`).
- `pubspec.yaml` adds
  `flutter_localizations: { sdk: flutter }` + `intl: any` +
  `flutter: { generate: true }`.
- Generated `lib/l10n/gen/app_localizations*.dart`
  produced by `flutter gen-l10n`.
- `lib/main.dart` wires
  `localizationsDelegates: AppLocalizations.localizationsDelegates`
  + `supportedLocales: AppLocalizations.supportedLocales`.
- `lib/screens/{home,settings,onboarding}.dart` read
  every user-facing string from
  `AppLocalizations.of(context)`.
- New `test/support/localized_app.dart` helper (~30
  lines) builds a `MaterialApp` with the generated
  delegates pre-installed so existing widget tests do
  not crash on `AppLocalizations.of(context)!`. 10
  screen-test files route through it.
- New `test/l10n/app_localizations_test.dart` (11 tests —
  5 structural assertions on ARB catalogs, 4 widget tests,
  2 class-API tests).

**Hands-on:** pick Spanish in Android Settings → System →
Languages, launch do it, confirm the AppBar / settings
sections / onboarding steps render in Spanish.

ADR-031 / SYS-087.

### v1.1i — Custom app icon + splash (adaptive icon + brand color)

(SYS-088 / ADR-032.)

The default Flutter launcher icon (a blue "F" on white) is
gone. The app now ships a hand-authored vector adaptive
icon (a white sans-serif lowercase 'd' with a small filled
check dot on the brand purple `#FF6750A4`) and an on-brand
splash that layers the same 'd' centered on the purple
background. The pre-existing
`drawable/ic_streak_notification.xml` resource gap (called
out at `architecture_options.md:191-192`) is closed in the
same PR.

**What's new**

- New `mipmap-anydpi-v26/ic_launcher.xml` is the
  `<adaptive-icon>` entry point, referencing three vector
  layers:
  - `drawable/ic_launcher_background.xml` — solid brand
    purple `#FF6750A4` on the 108dp adaptive-icon canvas.
  - `drawable/ic_launcher_foreground.xml` — a white
    sans-serif lowercase 'd' glyph (stem at
    x ∈ [23, 29], bowl centered on (54, 54) with outer
    radius 25 and inner radius 16, evenOdd fill carves
    the counter) plus a small filled check dot at
    (80, 80), radius 4. The 'd' represents the 'do'
    brand entity; the dot represents completion.
  - `drawable/ic_launcher_monochrome.xml` — same glyph as
    the foreground, paint pure white. Android 13+ themed
    icons recolor this layer against the user's
    wallpaper-derived tint; we ship the foreground glyph
    only (no brand purple), so the themed-icon system
    paints the 'd' against the wallpaper tint and drops
    the background layer entirely.
- The five
  `mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`
  legacy density buckets stay in place as the API 21..25
  fallback. A v1.2 follow-up can regenerate them from the
  master vector if a pre-26 device needs on-brand
  visuals.
- Both `drawable/launch_background.xml` and
  `drawable-v21/launch_background.xml` are rewritten as a
  `<layer-list>` that paints the brand purple first (via a
  new named color resource `@color/launch_background`
  defined in `values/colors.xml` — AAPT2 rejects inline
  color values inside `drawable-v21/`
  `<item android:drawable>`) then layers the foreground
  vector centered on a 96dp × 96dp box (Material's
  "logo size on splash" guideline).
- New `drawable/ic_streak_notification.xml` — monochrome
  white-on-transparent version of the launcher glyph with
  the check dot dropped (the dot is unreadable at 24dp).
  This is the resource name
  `architecture_options.md:191-192` calls out as the
  status-bar icon for the `streak.reminders` notification
  channel; the Kotlin-side channel init reads it by name.
- Version bumped `1.0.0+7` → `1.1.0+8` in `pubspec.yaml`
  + `lib/build_info.dart`. The mirror-pin assertions in
  `test/release_signing_test.dart` update in lockstep;
  two new tests pin the manifest icon reference +
  `app_name` + `kAppVersion` together.
- New `test/app_icon_test.dart` (9 filesystem tests).
- Bundled platform maintenance:
  `android/app/build.gradle.kts` compileSdk 34 → 36 +
  minSdk 28 → 30; `CallInterceptor.kt` migrates from the
  removed `Call.Response.Builder` to
  `CallScreeningService.CallResponse.Builder`;
  `MainActivity.kt` passes the Activity explicitly via
  `setActivity(this / null)`.

**Not in this release:** per-density PNG regeneration
from the master vector (v1.2 follow-up; the legacy PNGs
stay as the API 21..25 fallback in the meantime), iOS
App Store icon assets (v1.1+ port candidate; iOS is not
in v1.1 scope), light-theme icon variant (v1.2 follow-up;
dark theme is the v1.0 default).

**Hands-on:** `flutter build appbundle --release` (asks
first per CLAUDE.md) →
`adb install -r build/app/outputs/bundle/release/app-release.aab`
(asks first) → visual checks: app drawer shows the 'd' +
dot icon on the brand purple background, masked into a
circle (Pixel launcher) / squircle (Samsung) / teardrop
(Xiaomi); Settings → Apps → do it → Icon shows the
adaptive icon previews (background + foreground layers
visible separately); splash on cold start: brand purple
flash with the 'd' icon centered for ~100ms before the
home screen draws; status-bar notification (Settings →
Test reminder): white 'd' glyph, no dot; on Android 13+:
Settings → Wallpaper & style → Themed icons → enable,
the launcher icon re-tints against the wallpaper palette.

ADR-032 / SYS-088. See `decision_record.md` ADR-032 for
the hand-authored-vector choice (over
`flutter_launcher_icons` / `flutter_native_splash`),
`docs/v_model/requirements.md` SYS-088 for the
behavioral contract, and
`docs/v_model/architecture_options.md:191-192` for the
notification-icon resource reference.

## [Unreleased]

### v1.0/Phase A — `Habit` → `Do` rename (sealed hierarchy kept, feature identifiers preserved)

do it is no longer about streaks. Phase A renames the
"Habit" concept to "Do" and the "Streak" / "streak" display
copy to "Consecutive run" / "consecutive run", to reflect
what the app actually does: a list of small actions the user
commits to doing, with the consecutive-run counter as one
signal among many (not the product). Feature-level
identifiers (`StreakCalculator`, `StreakService`,
`StreakSnapshot`, `StreakConfig`) stay — they describe the
consecutive-run feature, not the app.

**What's new**

- **Class rename.** `Habit` → `Do` (sealed hierarchy kept:
  `DoFixed` / `DoInterval` / `DoAnchor` / `DoDayOfX` /
  `DoTimeWindow` mirror the v0.x `Habit*` subclasses).
  `HabitRepository` → `DoRepository`. `HabitCategory` →
  `DoCategory`. `HabitIcons` → `DoIcons`. Mirror rename in
  `lib/do/do.dart`, `lib/services/do_repository.dart`, and
  every test that imports them.
- **User-facing copy.** "Habit" → "Do", "Add a habit" →
  "Add a do", "Habits" → "Things to do", "I'm up" →
  "Start my day", "Streak" → "Consecutive run". Every
  screen and widget that renders a habit name, category,
  or streak badge was updated. The `showLicensePage(
  applicationName: 'do it', ...)` call is updated.
- **V-Model docs.** `conops.md` / `requirements.md` /
  `workflows.md` updated to the "Do / consecutive run"
  framing. WF-002 → WF-002a (the wake-up anchor workflow
  keeps its number, the prefix shifts). SYS- IDs renamed
  in the docs only; the runtime identifiers stay
  (`do_repository.dart` keeps the `habits` table name;
  column-level rename is deferred to v1.1+ to avoid a
  needless migration).
- **iOS-port-friendly model.** The model layer
  (`lib/do/`, `lib/habits/`, `lib/people/`,
  `lib/missions/`) no longer carries the "Habit" word
  outside `StreakCalculator` and `StreakService`. An iOS
  port is a v1.1+ candidate; the rename means a future
  Swift port inherits a clean model vocabulary.

**Why now:** the v0.5 rename-to-"do it" milestone
(`v0.5a` → `ff56021`) repainted the app's *display* name
to "do it" but left the *feature* name "Habit" in place.
v1.0/Phase A finishes the rename: the model class, the
repository, the categories, and every user-facing string
move from "Habit" to "Do" so the codebase reads
consistently.

**Per-PR (3 commits, all on `main`):**

- `fee9694` (v1.0a.1) — class + file rename pass
- `2e6b69d` (v1.0a.2) — user-facing copy rename
- `373913c` (v1.0a.3) — V-Model docs sync

See `decision_record.md` ADR-024 for the rename rationale
and the "feature identifiers stay" decision. The rename
verification grep (mirror v0.5a):

```
grep -rn "Habit" --include="*.dart" --include="*.md" \
  lib/ test/ docs/ CHANGELOG.md | \
  grep -v "StreakCalculator\|StreakService\|StreakSnapshot\|StreakConfig\|streak_calculator\|streak_service\|streak_snapshot" | wc -l
```

returns zero. The `Streak*` identifiers are feature-level,
intentionally kept.

### v1.0/Phase E — Calendar-event triggers (calendar trigger kind + on-demand permission + picker UX)

Calendar events become a first-class routine trigger. The
executor subscribes once at app start to the native
`CalendarContract.Instances` stream via `CalendarService`,
matches each transition (event-start, event-end, reminder,
free-busy change) against the registered automation set,
and dispatches the matching `Action`. The user-facing
entry point is the new `CalendarPicker` bottom sheet, a
"Add a calendar routine" button in the add-do /
add-event / add-person screens' "Routines" section, and a
Settings → Permissions → Calendar tile.

PR 1 (`f61b718`) shipped the platform side: `CalendarService`,
`CalendarChannel.kt` reading `CalendarContract.Instances`,
`PermissionKind.calendar` + `PermissionSheet` arm + the
`READ_CALENDAR` `AndroidManifest` entry, the executor's
`_calendarMatches` predicate, the matching engine arm,
and ADR-023 (library choice: native over `device_calendar`).

#### v1.0/Phase E PR 2 — `CalendarPicker` + Routines section (user-facing)

- New widget `lib/widgets/calendar_picker.dart` (mirror of
  `LocationPicker`): modal bottom sheet that gates on
  `PermissionSheet.show(PermissionKind.calendar)` and
  builds one of the four `TriggerCalendarEvent*` leaves
  with a default `ActionNotify`. Four fields: label
  (required), event title filter (optional), calendar
  account dropdown (populated by
  `CalendarService.listAccounts()` on tap of `Refresh`),
  event-kind radio (start / end / reminder / free-busy).
  Empty `calendarId` is a valid sentinel — the executor's
  `_calendarMatches` predicate treats it as "match any
  calendar".
- Add-do / add-event / add-person screens gain an
  "Add a calendar routine" button next to the existing
  "Add a location routine" button (in a `Wrap`). The
  empty-state copy mentions both location and calendar
  trigger kinds.
- V-Model sync: WF-035 added to `workflows.md`; the
  `## Routines (v1.0/Phase C–F)` section in `conops.md`
  is extended with Phase E PR 2 detail (calendar UX,
  reliability note). Closes SYS-074.

**Not in this PR:** the Settings → Permissions → Calendar
tile was wired in Phase E PR 1 (lands in the app via the
generic `_PermissionTile` loop); nothing additional
needed here. Per-automation reliability badges for
calendar triggers are a v1.1 follow-up.

### v1.0/Phase C — Location triggers (sealed `Trigger` / `Condition` / `Action` spine + Geofence)

Routines are a first-class field on each entity (do / event /
person) — a non-time `Trigger` (location enter/exit, device-state,
calendar event, or incoming call) plus an optional `Condition`
plus a `List<Action>`. Phase C ships the foundation (PR 1) and the
first concrete non-time trigger kind (PR 2: geofence enter / exit).

#### v1.0/Phase C PR 1 — sealed-type spine + Drift v3 → v4 migration

The sealed-type foundation every routine kind (Phase C–F) attaches
to, plus the schema column that carries routines on each entity.

**What's new**

- **Sealed `Trigger`** in `lib/triggers/trigger.dart` — five
  top-level subclasses: `TriggerLocationEnter` /
  `TriggerLocationExit` (sealed pair; both extend a private
  `TriggerLocation` mixin carrying `geofenceId`, `label`, `latitude`,
  `longitude`, `radiusMeters`, `validate()` rejecting radii outside
  50 m .. 5000 m), plus marker leaves `TriggerDeviceState` (Phase D),
  `TriggerCalendarEvent` (Phase E), `TriggerCallIncoming` (Phase F).
- **Sealed `Condition`** in `lib/triggers/condition.dart` — leaves
  `ConditionAnd`, `ConditionOr`, `ConditionTimeWindow`,
  `ConditionDayOfWeek`, `ConditionCalendarBusy`,
  `ConditionBatteryRange`, `ConditionSilentMode`. A `null` condition
  on an `Automation` is a no-op (the trigger fires unconditionally
  subject to the action's own validation).
- **Sealed `Action`** in `lib/actions/action.dart` — leaves
  `ActionNotify` (the only PR 1 leaf with a body, wraps the existing
  `NotificationService`), `ActionFullScreen` (wraps
  `FullScreenIntent`), `ActionCallIntercept`, `ActionOverrideSilent`,
  `ActionOpenApp`.
- **`Automation`** aggregate in `lib/triggers/automation.dart` —
  immutable `{trigger, condition?, actions, disabled}` with
  `validate()`, `toJsonEnvelope()` / `fromJsonEnvelope()`, sealed
  `AutomationValidationException` with one PR 1 leaf
  (`AutomationEmptyActions`).
- **`RoutineExecutor`** skeleton in `lib/routines/routine_executor.dart`
  — singleton with `_ready` Completer gate (mirrors the rest of
  `lib/services/`); exposes `init()`, `evaluate(snapshot)` (no-op
  in PR 1), `dispatch(automation, now)` (the `ActionNotify` arm
  runs; every other arm throws `UnimplementedError`), and a
  broadcast `Stream<AutomationFired>`.
- **`automationsJson` envelope** in
  `lib/triggers/automation_codec.dart` —
  `{"k":1,"automations":[<Automation>...]}` with
  `kAutomationFormatVersion = 1`. Mirrors the existing
  `missionChainJson` and `kTemplateFormatVersion = 1` patterns.
- **Drift schema v3 → v4 migration** in
  `lib/services/db/migrations/v3_to_v4.dart` — three `ALTER TABLE`
  column adds (`habits`, `people`, `events`) carrying the
  `automations_json` envelope. Nullable, no DEFAULT. NULL
  post-migration means "no non-default automations" — the correct
  state for every existing row.
- **`automations` field** on `Do` (5 subclasses — `copyWith` updated
  on all), `Event`, `Person` (`ContactPerson.copyWith` updated).
- **Decoder** in each repository's `_fromRow` reads `automationsJson`
  via `Automation.fromJsonEnvelope`; `null` / empty array means
  "use the default `ActionNotify` synthesized at dispatch time".

**V-Model doc sync (this release):** SYS-069 (sealed `Trigger`),
SYS-070 (sealed `Condition`), SYS-071 (sealed `Action`),
SYS-072 (geofence trigger), SYS-076 (`PermissionKind.location`
+ rationale), the Triggers / Conditions / Actions module row in
`architecture_options.md`, the `kAutomationFormatVersion = 1`
row in the format-version pins table, and a `## Routines
(v1.0/Phase C–F)` section in `conops.md`.

**Not in this release:** geofence wire-up (PR 2), device-state
(Phase D), calendar (Phase E), call-intercept (Phase F).

#### v1.0/Phase C PR 2 — `GeofenceService` + LocationEnter / Exit triggers + permission tile

The first concrete non-time trigger end-to-end: geofence enter /
exit. The user configures a routine from the add-do / add-event /
add-person screens' new "Routines" section; the routine fires a
notification when the device enters (or exits) the chosen circle.

**What's new**

- **`GeofenceService`** in `lib/services/geofence_service.dart` —
  singleton wrapping `geolocator` ^13.0.1 (ADR-021). Subscribes to
  `Geolocator.getPositionStream(...)` (filtered at 25 m), runs a
  pure-Dart Haversine matcher (`computeTransitions(...)`, exposed
  `@visibleForTesting`) against the registered `TriggerLocation`
  circles, and emits `GeofenceEntered` / `GeofenceExited` on a
  broadcast `Stream<GeofenceEvent>`.
- **`LocationPicker`** in `lib/widgets/location_picker.dart` —
  modal bottom sheet gated by `PermissionSheet.show(PermissionKind.location)`
  (the v0.5 / ADR-014 on-demand permission pattern). Fields:
  `label` (required), `latitude` / `longitude` (validated
  `[-90, 90]` / `[-180, 180]`), `radius` slider (50 m .. 500 m,
  default 100 m), `LocationEvent` radio (enter default / exit).
  "Use current location" button calls
  `Geolocator.getCurrentPosition()` when the permission is
  granted. No map widget in PR 2 — coordinate paste or current-
  position capture is the v1.0 path; `google_maps_flutter` /
  `flutter_map` is a v1.1 follow-up.
- **`PermissionKind.location`** entry on `PermissionService` enum
  (v0.5a+ service singleton, `_ready` Completer gate) — probes
  `Permission.location` (which maps to `ACCESS_COARSE_LOCATION`)
  in `init()`, exposes `requestLocation()`, surfaces the
  city-block-accurate rationale in `PermissionSheet`. A denied
  coarse-location is a soft failure: geofence triggers silently
  no-op; the home-screen reliability banner flips to
  `Reliability.degraded` only when at least one
  `TriggerLocation*` automation is registered.
- **Settings → Permissions → Location** tile (the `_PermissionTile`
  pattern from v0.5d / ADR-016) with a `case
  PermissionKind.location:` arm in `_PermissionTile._reProbe`
  calling `service.requestLocation()`. Onboarding step is
  deferred to a Phase D/E/F consolidation so the user is not
  asked for 5+ permissions during first run.
- **"Routines" section** on `AddHabitScreen` / `AddEventScreen` /
  `AddPersonScreen` — empty-state copy is entity-specific
  ("fire this do / event / remind you to reach out when you arrive
  at or leave a place"), the "Add a location routine" button
  (`add_<entity>.add_location_routine` key) opens the picker.
- **`RoutineExecutor` wire-up** — subscribes to
  `GeofenceService.instance.events` in `init()`; the
  `TriggerLocation*` arm in `dispatch(...)` calls the existing
  `NotificationService.show(...)` path.
- **`GeofenceBroadcastReceiver.kt`** — dynamically registered from
  the Dart `GeofenceService.init()` path via
  `ContextCompat.registerReceiver`. No `<receiver>` block in
  `AndroidManifest.xml` (confirmed against the chosen library's
  docs).
- **`<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />`**
  added to `android/app/src/main/AndroidManifest.xml`.
  `ACCESS_FINE_LOCATION` stays explicitly out of scope (the
  50 m .. 5000 m radius bound on `TriggerLocation.validate()`
  is well above the coarse-location noise floor).

**V-Model doc sync (this release):** ADR-021 (geofence library
choice — `geolocator` over `flutter_geofence` /
`geofence_service`), WF-034 (Add a location-triggered do /
event / person), a Trigger-reliability → Geofence section in
`notification_reliability.md`, the ACCESS_COARSE_LOCATION
permission baseline row + the explicit `ACCESS_FINE_LOCATION`
"out of scope" note in `architecture_options.md`.

**Not in this release:** map widget in the picker (v1.1),
device-state triggers (Phase D), calendar triggers (Phase E),
call-intercept routine (Phase F), onboarding step for
`ACCESS_COARSE_LOCATION` (consolidated with Phase D/E/F in a
follow-up PR).

### v1.0/Phase D — Device-state triggers (reactive broadcasts, no polling)

Device state becomes a first-class routine trigger. The
executor subscribes once at app start to the native
`DeviceStateChannel` Kotlin broadcast stream and matches
each snapshot against the registered automation set; the
matching arm fires the matching `Action`. The user-facing
entry point is a Settings → Triggers debug screen that
shows the live device-state snapshot stream (one row per
property: charging state, battery range, BT device name,
Wi-Fi SSID, headphones plugged, ringer mode, foreground
app).

**Why reactive, not polling (ADR-022):** a polling design
(every 60 s) is the obvious shape, but it costs battery
and the user perceives a 30-60 s latency between
"plugged in" and "routine fired". The native broadcast
stream is the source of truth for every property we
expose; we subscribe once, the OS calls us back when
state changes, latency is sub-second.

**What's new**

- **`DeviceStateChannel.kt`** — Kotlin
  `BroadcastReceiver` registered for the seven state
  changes (`ACTION_POWER_CONNECTED` / `ACTION_POWER_DISCONNECTED`,
  `BatteryManager.EXTRA_LEVEL`,
  `BluetoothDevice.ACTION_ACL_CONNECTED`,
  `WifiManager.NETWORK_STATE_CHANGED_ACTION`,
  `AudioManager.ACTION_AUDIO_BECOMING_NOISY`,
  `AudioManager.RINGER_MODE_CHANGED_ACTION`,
  `Intent.ACTION_PACKAGE_CHANGED` for foreground-app
  detection). Each broadcast is forwarded to Dart as a
  typed `DeviceStateSnapshot` over the `doit/device_state`
  `MethodChannel`. The receiver is registered dynamically
  from `lib/services/device_state_probe.dart`; no
  `<receiver>` block in `AndroidManifest.xml`.
- **`DeviceStateService`** — singleton with the
  `_ready`-gated init pattern (mirror
  `lib/services/permission_service.dart`). Exposes
  `Stream<DeviceStateSnapshot> events` for the executor
  and `DeviceStateSnapshot current` for the debug screen.
- **`TriggerDeviceState` (sealed, 7 leaves)** —
  `TriggerCharging` / `TriggerBatteryRange(min, max)` /
  `TriggerBluetoothDevice(name)` /
  `TriggerWifiSsid(ssid)` / `TriggerHeadphonesPlugged` /
  `TriggerRingerMode(mode)` /
  `TriggerForegroundApp(packageName)`. Each leaf
  implements `validate()` (throws on malformed input —
  e.g., battery range out of bounds, missing device name).
  Mirror the `TriggerLocation.validate()` pattern.
- **`PermissionKind.bluetooth`** —
  `BLUETOOTH_CONNECT` (Android 12+ runtime permission).
  Requested at Settings → Permissions → Bluetooth on
  first use; Settings → Permissions tile is the recovery
  affordance for `permanentlyDenied` (mirror
  `PermissionKind.location`).
- **Settings → Triggers debug screen** — live dashboard
  showing the current `DeviceStateSnapshot`. Each row
  has a "Send test event" `TextButton` that fires a
  synthetic event into the executor (debug-only; behind
  `kDebugMode`). Useful for verifying the trigger
  wire-up without a real charging cable / BT pairing /
  Wi-Fi roam.

**Per-PR (2 commits, all on `main`):**

- `9ed6abe` (v1.0d.1) — `DeviceStateChannel` +
  `DeviceStateService`
- `c7035cc` (v1.0d.2) — `TriggerDeviceState` wired +
  Settings → Triggers debug screen + ADR-022

See `decision_record.md` ADR-022 for the reactive-first
vs. polling decision. The 60-second poll slot that
earlier drafts mentioned is reserved for the debug
screen only — the executor never polls.

**Not in this release:** foreground-app permission
(`PACKAGE_USAGE_STATS` is a Settings-only grant, not a
runtime prompt) — the foreground-app trigger fires on a
best-effort basis without the permission and the debug
screen shows a banner explaining the degraded mode
(v1.1 follow-up; needs a separate SYS- ID and ADR).

### v1.0/Phase B — Templates (curated library + save-as-template)

Templates are a curated, opt-in way to bootstrap a new do / event /
person from a pre-filled configuration. Templates ship locally (no
network); they restore automatically via the existing backup service.

**What's new**

- **`TemplatesScreen` (catalog).** Reached from the home FAB →
  "Browse templates". Two-column grid of 25 cards (12 Do + 3
  Person + 4 Event + 6 Routine), with filter chips for Do /
  Event / Person / Routine. Routine cards render a "Coming in
  v1.1" badge — the routine apply UX lands in Phase F.
- **`initialPayload` pre-fill** on `AddHabitScreen`,
  `AddPersonScreen`, and `AddEventScreen` (extracted from
  `events.dart` into its own file). Tapping a template card
  opens the matching add screen with name, schedule, cadence,
  proof mode, category, icon, color, lead time, and
  recurrence all pre-filled. The user reviews and saves.
- **"Save as template"** AppBar overflow action on all three
  add screens (Do / Event / Person) — captures the current
  form state (not the persisted row) as a new user template.
  Built-ins are read-only; user templates are deletable via
  long-press in the catalog.

**Data layer**

- Drift schema bumped **v2 → v3**; `Templates` table added
  (id, name, description, iconName, entityType, payloadJson,
  isBuiltIn, createdAtMillis, lastUsedAtMillis).
- `Template` model with `entityType` discriminator
  (`doEntity / event / person / routine`); `payloadJson` is a
  versioned envelope `{"k":1,"<entityType>":{...}}` with
  `kTemplateFormatVersion = 1`. Hand-rolled `dart:convert`
  (no codegen) — matches the codebase convention.
- 19 hand-crafted built-in templates shipped in Phase B
  (12 Do + 3 Person + 4 Event). Phase F adds the 6 routine
  templates to reach the master-plan quota of 25. The data
  model already supports `entityType: 'routine'`, so Phase F
  is a seed-only add (no schema change).
- `TemplateRepository` singleton with `_ready` gate (matches
  the rest of `lib/services/`): `save`, `getById`, `listAll`,
  `deleteById` (refuses built-ins), `seedBuiltIns` (idempotent).
- Built-in seed runs from `AppDatabaseService.init()` AFTER
  the v2→v3 migration, guarded by `from < 3` so existing v3
  users do not re-seed.

**V-Model doc sync (this release):** ADR-020 (template model +
JSON envelope), SYS-067 (≥25 curated templates), SYS-068
(save-as-template), WF-032 (pick from library), WF-033 (save
configured do as user template), a Templates section in the
`conops.md` operational scenario, a Templates layer row + a
format-version table entry in `architecture_options.md`. Doc-
only PR; closes the V right-side.

**Not in this release:** routine apply UX (Phase F), template
search / categories / sharing (v1.1+).

### v1.0/Phase F — CallInterceptor + Japan silent-mode routine

Phone calls become a first-class routine trigger and a
first-class routine action. The Kotlin
`CallInterceptor.kt` extends `CallScreeningService`; the
executor wires two new `Action` leaves
(`ActionCallIntercept` — block a call matching the
configured contact / pattern, `ActionOverrideSilent` —
flip the ringer to silent before the screen) and one new
`Trigger` leaf (`TriggerCallIncoming` — fires when a
call comes in). Template #16 from the curated library
("Auto-silence unknown calls at the office") routes to a
real `AddRoutineScreen` that wires the silent-mode flow.

**Why `CallScreeningService` over `PhoneAccount`
(ADR-019):** `PhoneAccount` lets us *place* calls on
behalf of the user but does not let us *screen* incoming
calls. `CallScreeningService` (added in Android 10,
expanded in Android 11+ for `ROLE_CALL_SCREENING`) is
the right shape: we see every incoming call before the
phone rings, we can block it, and we can override the
ringer mode for the duration of the call. The role is
opt-in via `RoleManager` (SYS-079); a user who does not
grant the role still gets the notification but no
silent-mode override (graceful degrade).

**What's new**

- **`CallInterceptor.kt`** — Kotlin `CallScreeningService`
  implementation. Reads the registered routine config
  from `SharedPreferences` (synced from
  `SettingsService.japanRoutine`); on each incoming
  call, matches against the contact list + the
  target-mode (silent / block / silent + block); calls
  `respondToCall` with `CallResponse`. The interceptor
  also sets the ringer mode to silent (or back to the
  prior mode) before / after the call.
- **`CallInterceptorService`** — Dart singleton
  wrapping the platform channel. Exposes
  `configure(JapanRoutineConfig)` (writes to
  SharedPreferences), `Stream<CallEvent> events` (incoming
  / rejected / ringer-overridden), and `enable(bool)`.
- **`ActionCallIntercept` + `ActionOverrideSilent`** —
  sealed-`Action` leaves that the executor dispatches
  when the matching arm fires. `ActionCallIntercept`
  asks `CallInterceptorService` to start screening for
  the next 60 s (one-shot; the persistent config is the
  template #16 path); `ActionOverrideSilent` flips the
  ringer mode via `AudioManager`.
- **`JapanRoutineConfig`** — `lib/services/japan_routine_config.dart`
  singleton. `enable: bool`, `contacts: List<String>`
  (phone numbers or partial-pattern matches), `targetMode:
  TargetMode` (`silent` / `block` / `silentAndBlock`).
  Persisted via `SettingsService.japanRoutine`.
- **`AddRoutineScreen`** — wired to template #16. Form
  fields: enable toggle, contacts list (multi-select
  picker, gated on `READ_CONTACTS` permission via
  `PermissionSheet.show(PermissionKind.contacts)`),
  target-mode radio (silent / block / silent + block).
  Save calls `CallInterceptorService.configure(config)`
  and pushes to the executor's `RoutineExecutor._onCallEvent`.
- **`PermissionKind.phoneState` + `ROLE_CALL_SCREENING`** —
  the role is opt-in via `RoleManager`; the Settings →
  Permissions → Call-screening tile probes
  `isCallScreeningRoleHeld()` and offers
  `requestCallScreeningRole()`. Onboarding step 4
  (added in v1.0f.2) surfaces the rationale before the
  system role dialog appears.
- **Templates #16 routing** — the curated templates
  library routes template #16 ("Auto-silence unknown
  calls at the office") to the real `AddRoutineScreen`
  instead of the v1.1 snackbar. Templates #17–#21 still
  show the snackbar — the generic routine apply UX is
  a v1.1 follow-up.

**Per-PR (2 commits, all on `main`):**

- `e00a97f` (v1.0f.1) — `CallInterceptor` (Kotlin
  `CallScreeningService`) + `ActionCallIntercept` +
  `ActionOverrideSilent` Dart wrappers + ADR-019
- `ff56021` (v1.0f.2) — Japan silent-mode template + UI
  + `JapanRoutineConfig` + Settings → Call-screening tile
  + onboarding step 4 (SYS-079) + ADR-019 follow-up

See `decision_record.md` ADR-019 for the
`CallScreeningService` choice and the role opt-in
rationale. ADR-019 follow-up captures the Japan routine
UX decision (silent-mode override is the user's daily
driver; the routine config lives in `SharedPreferences`
not in the Drift `automationsJson` because the
interceptor reads it on every call, before the Dart
isolate is warm).

**Not in this release:** generic routine apply UX for
templates #17–#21 (v1.1 — needs a `RoutineTemplatePayload`
decoder + a 6-template picker workflow), call-screening
on iOS (the role is Android-only; iOS is a v1.1+ port
candidate), per-call notification customization
(v1.1+).
### v0.5a — rename to "do it"

App-level rename. The app's display name, package id, directory,
notification channel, WorkManager task name, MethodChannel, and
Dart package `name:` are all changed. Feature-level identifiers
(`StreakCalculator`, `StreakService`, `StreakSnapshot`,
`StreakConfig`, `streak_calculator.dart`, `streak_service.dart`,
`currentStreak`, `longestStreak`) are unchanged — they describe
the *streak* feature, not the app.

- **App name:** "Streak" → "do it" (lowercase, with a space).
- **Android `applicationId` / `namespace`:** `com.common_games.streak`
  → `com.doit`. The earlier draft picked `com.doit.package` but
  `package` is a Java reserved keyword and AGP rejected the
  namespace at build time. v0.5e-fix renames to `com.doit`.
  Forces uninstall-before-install on existing v0.4b devices at
  v0.5e.
- **Dart package `name:`:** `common_games` → `doit`. Every
  `package:common_games/...` import becomes `package:doit/...`.
- **Directory:** `/home/shyam/common_games/streak/` →
  `/home/shyam/common_games/doit/`.
- **Kotlin tree:** `com/common_games/streak/` →
  `com/doit/`. `package com.common_games.streak` →
  `package com.doit`.
- **MethodChannel:** `streak/reminders` → `doit/reminders`.
- **Notification channel id:** `streak.reminders` → `doit.reminders`.
- **WorkManager task name:** `streak.backup.nightly` →
  `doit.backup.nightly`.
- **SharedPreferences key:** `streak.backup.folder_uri` →
  `doit.backup.folder_uri`.
- **Test reminder habit id:** `streak.test_reminder` →
  `doit.test_reminder`.
- **Version:** `0.4.0+5` → `0.5.0+6` (`pubspec.yaml` and
  `lib/build_info.dart`).
- **User-facing display strings:** every "Streak" / "Streak test
  reminder" / "Welcome to Streak" / "Pick a Streak backup" string
  in user-facing copy updated.
- **v0.5a pin tests** added to `test/release_signing_test.dart`
  asserting `applicationId` is exactly `com.doit`, the
  `MethodChannel('doit/reminders')` is declared exactly once, the
  notification channel id is `'doit.reminders'`, and the backup
  task name is `'doit.backup.nightly'`.

App behavior is unchanged; this is a pure rename. The release APK
is rebuilt at v0.5e.

### v0.5b — `PermissionService` + sealed result

The v0.1 onboarding was a "visual walkthrough" — the rationale
UI existed, the runtime request did not. v0.5b introduces the
seam that the v0.5c wiring uses:

- **`lib/services/permission_service.dart`** — singleton with
  the `_ready`-gated init pattern from
  `.claude/rules/lib-services.md`. Public methods:
  `requestNotifications()` (SYS-063),
  `requestContacts()` (SYS-064),
  `requestExactAlarm()` (SYS-065),
  `requestBackupFolder()` (SYS-066),
  `openAppSettings()` (deep-link to system app-settings for
  `permanentlyDenied` recovery), and `init()` (idempotent;
  swallows platform-channel errors per the v0.4b-release-fix
  lesson).
- **`lib/services/permission_result.dart`** — sealed class
  hierarchy. Runtime results: `PermissionResultGranted()`,
  `PermissionResultDenied({required bool canOpenSettings})`,
  `PermissionResultPermanentlyDenied()`. Backup-folder results:
  `BackupFolderPicked({required String path})`,
  `BackupFolderCancelled()`,
  `BackupFolderError({required String message})`. The widget
  layer never sees `PermissionStatus` directly; the
  `_mapStatus` private method folds `restricted` and
  `limited` into `denied` for widget purposes.
- **`test/services/permission_service_test.dart`** — 9
  service tests pinning the sealed result branches (granted /
  denied / permanentlyDenied for each of the three runtime
  permissions; picked / cancelled / error for backup folder;
  idempotent init; platform-error swallow).
- The widget layer is **not** touched at v0.5b — the seam
  exists in isolation. v0.5c wires the onboarding CTAs to it.

### v0.5c — wire onboarding CTAs to `PermissionService`

The four onboarding "Allow" / "Pick folder" buttons (which in
v0.1 were visual stubs that did `setState(() => _step++)`)
are now wired to the v0.5b seam:

- **`lib/screens/onboarding.dart`** — `_handleStepCta` dispatches
  on `_step`:
  - `_step == 0` → `requestNotifications()`; advance on
    `granted`.
  - `_step == 1` → `requestContacts()`; advance on `granted`.
  - `_step == 2` → `requestExactAlarm()`; on
    `denied(canOpenSettings: true)` / `permanentlyDenied` show
    the "Open Android settings" `FilledButton.tonal` that
    deep-links to the system Alarms & reminders page via
    `PermissionService.openAppSettings()`. Re-tapping the CTA
    after returning from system settings re-probes and advances
    on `granted`.
  - `_step == 3` → `requestBackupFolder()`. On `picked` persist
    via `SettingsService.setBackupFolderUri` and advance. On
    `cancelled` advance (per ADR-015 — the backup folder is
    skippable). On `error` show the rationale and stay on the
    step.
- **`lib/services/settings_service.dart`** — new
  `ValueNotifier<String?> backupFolderUri` (defaults `null`);
  `setBackupFolderUri(String?)` mutates it.
- **`test/services/settings_service_backup_uri_test.dart`** — 3
  tests pinning the notifier (default-null, set-then-read,
  listener fires).
- **`test/screens/onboarding_permission_wiring_test.dart`** — 6
  tests pinning the call-and-advance behavior (4 step CTAs +
  skip + backupUri persistence). The `'tapping Allow on step 0
  calls requestNotifications and advances on granted'` test
  would have failed on the v0.1 stub because the channel saw
  zero calls.
- The widget layer no longer imports `permission_handler` or
  `file_picker` directly; the seam is `PermissionService`.
- `lib/screens/onboarding.dart`'s file-level comment is
  updated to drop the "visual walkthrough" wording.

### v0.5d — Settings → "Permissions" tile + ADR-016

A user who taps "Don't ask again" on any of the four onboarding
steps needs an in-app recovery path. v0.5d adds it:

- **`lib/screens/settings.dart`** — new `Permissions` section
  between `Wake-up anchor` and `Reliability`. Three new
  widgets:
  - `_PermissionsRow` — subscribes to
    `PermissionService.instance.statuses` (a
    `ValueNotifier<Map<PermissionKind, PermissionResult?>>`),
    renders one `ListTile` per permission (notifications,
    contacts, exact alarms, backup folder).
  - `_PermissionTile` — icon + name + status text + a
    "Settings" `TextButton` for `permanentlyDenied` rows that
    deep-links to the system app-settings page via
    `PermissionService.openAppSettings()`. Tapping the row
    re-probes via `requestX()`.
  - `_BackupFolderTile` — picked path (or "Not picked") + a
    "Re-pick" `TextButton` when a path is set; tapping the
    row or button calls `requestBackupFolder()` and persists
    via `setBackupFolderUri()`. The re-pick path is the
    recovery affordance for users who revoked the SAF grant
    from system settings.
- **`test/screens/settings_permissions_test.dart`** — 4 tests
  pinning the recovery affordance (row renders, "Settings"
  button on `permanentlyDenied` only, deep-link tap, on-demand
  re-probe).
- **`docs/v_model/notification_reliability.md`** — line
  126-127 is updated. The pre-v0.5 "On first scheduling of a
  fixed-time habit, the app detects whether the user has
  granted `SCHEDULE_EXACT_ALARM`" copy is replaced with: "The
  app probes `SCHEDULE_EXACT_ALARM` at onboarding step 2
  (SYS-065) and surfaces the result on the home screen
  reliability banner. If the user denies, the
  `Reliability.degraded` path activates and the Settings →
  Permissions tile is the recovery affordance."
- **`decision_record.md`** — ADR-016 is appended: "Permission
  service seam: sealed result, singleton, on-demand probe".
  The ADR also documents ADR-014 (onboarding permission
  order) and ADR-015 (backup folder is skippable) — both
  pre-existing decisions that v0.5 makes explicit.
- **`docs/v_model/open_questions.md` items #5
  (READ_CONTACTS revocation) and #6 (SAF URI revocation) are
  closed by v0.5d (ADR-016) — both surfaces now have an
  in-app recovery affordance.

### v0.5e-fix (ADR-017) — `com.doit.package` is not a valid Java namespace

`flutter build appbundle --release` failed at v0.5e with:
"Namespace 'com.doit.package' is not a valid Java package
name as 'package' is a Java reserved keyword". The v0.5a
rename picked `com.doit.package` for `applicationId` and
`namespace` (mirroring the Dart package name `doit` with
`package` as a namespace segment). The 3-gate was green
(407 / 407) and the v0.5a pin tests asserted the value
*exactly* — the defect was invisible until the release
AOT build ran. The fix is five surgical changes, all in
one commit:

- **`android/app/build.gradle.kts`** — `namespace = "com.doit"`,
  `applicationId = "com.doit"`. (Was `com.doit.package`.)
- **`android/app/src/main/AndroidManifest.xml`** —
  `<action android:name="com.doit.FIRE_ALARM" />`.
  (Was `com.doit.package.FIRE_ALARM`.)
- **`android/app/src/main/kotlin/com/doit/package/` →
  `android/app/src/main/kotlin/com/doit/`** via `git mv`
  with an intermediate name (`doit_tmp` — the parent
  `com/doit/` already existed, so the rename had to go
  through a detour). Every `.kt` file's `package`
  declaration is now `package com.doit`. (Was
  `package com.doit.package`.)
- **`test/release_signing_test.dart`** — the v0.5a pin
  test is rewritten to assert `applicationId == "com.doit"`
  and `namespace == "com.doit"`. A new
  regression-guard assertion is added:
  `expect(build, isNot(contains('com.doit.package')),
  reason: 'v0.5e-fix: com.doit.package is an invalid
  Java namespace ...')`. A future revert of either the
  applicationId or namespace value (or a re-pick of the
  bad value) fails CI before the release build runs.
- **Four doc files** updated:
  `v0_1_baseline.md`, `v0_5_release_baseline.md`,
  `v0_5_release_checklist.md`,
  `implementation_status.md`, plus `CHANGELOG.md` (this
  entry), `AGENTS.md`, and `docs/v_model/open_questions.md`
  item #21 (closed by ADR-017). ADR-017 is appended to
  `decision_record.md` with the full post-mortem and
  the JLS §3.9 reserved-keyword list.
- **Release AAB (61.0 MB) and APK (69.8 MB) are rebuilt
  successfully** (2026-06-16 22:29). The 3-gate is
  green at 407 / 407 (the test count is unchanged — the
  v0.5a pin test is rewritten in place; the
  regression-guard assertion is a new `expect` inside
  the same test body).
- **The launch command is `adb shell monkey -p com.doit
  -c android.intent.category.LAUNCHER 1`** (was
  `-p com.doit.package` in the v0.5a draft; the v0.5a
  draft's launch command was not executed because the
  build failed first). The user's v0.5e on-device
  verification on a real SM-S918B device is still
  pending the user attaching the phone.

**Lesson (project-wide).** A green 3-gate does not mean
a green build. The 3-gate is `dart format` +
`flutter analyze --fatal-infos` + `flutter test`; the
release AOT build is the user's hands-on step
(ADR-013's lesson, restated). The v0.5e-fix is the
third post-`flutter build appbundle` defect in this
project (after v0.4b-release-fix and
v0.4b-release-fix-2). Pin tests for *invalid* values
matter as much as pin tests for *exact* values. The
"com.doit.package" pick was stylish-looking but
redundant — the redundancy hid a defect that a
shorter, plainer `com.doit` would not have. See
`decision_record.md` ADR-017 for the full post-mortem.

## [0.4.0] — 2026-06-15 — Contract closure

Six work items that close the v0.3 contract items the v0.3 docs
flagged as v0.4 line items, plus the "Not started" CI 3-gate. The
release is contract-closure work — no new features beyond what
the v0.3 baseline promised. SHA range:
`608483e` → `efbfbdc` (v0.4a..v0.4d). 373 / 373 tests, 41
analyze infos (matches v0.3 baseline), `dart format` clean at
every commit. Right-side gate: `v0_4_release_checklist.md`.

### v0.4a.1 — CI 3-gate

- `.github/workflows/ci.yml` runs `dart format`,
  `flutter analyze --fatal-infos`, and `flutter test` on every
  PR and push to `main` (SYS-057). Three jobs: `quality` (the
  3-gate), `build-debug` (APK), and `build-android-release`
  (AAB on main, gated on 4 `ANDROID_*` secrets). A coverage
  report is uploaded as a CI artifact.
- `test/ci_workflow_test.dart` parses the workflow and asserts
  the three steps + the trigger set. Closes the "Not started"
  row in the v0.3 implementation status table.

### v0.4a.2 — `CHANGELOG.md`

- This file. Sections for v0.1, v0.2, v0.3, and v0.4
  (Keep-a-Changelog shape) (SYS-058). Closes [open question
  #20](docs/v_model/open_questions.md#20).

### v0.4a.3 — `firstLaunch` persisted flag

- `SettingsService.firstLaunchCompleted` is a
  `SharedPreferences`-backed `ValueNotifier<bool>` (SYS-059).
  The hard-coded `true` in `lib/main.dart` is replaced with a
  `ValueListenableBuilder` that reads the notifier. The
  onboarding screen no longer re-appears on every reinstall.
- `test/services/first_launch_persisted_test.dart` (7 tests) +
  `test/widget_test.dart` (3 tests) cover the flag's
  persistence across "app restarts" and the route-switch
  behavior.
- The "Onboarding re-appears on every reinstall" caveat in
  `PRIVACY.md` is removed.

### v0.4b — WorkManager periodic backup

- The dormant `workmanager: ^0.6.0` dep is wired up (SYS-060).
  `lib/services/backup_scheduler.dart` registers a 24-hour
  periodic task; the top-level
  `@pragma('vm:entry-point')` dispatcher
  (`_backupTaskDispatcher`) is registered via
  `Workmanager().initialize()`. The scheduler is opt-in from
  the settings screen.
- The "scheduling call not yet wired" caveat in `PRIVACY.md` is
  removed.

### v0.4c.1 — Backup encryption at rest

- `kBackupFormatVersion` bumps to 2 (SYS-061). The export flow
  takes a user-supplied passphrase, derives a 32-byte key via
  `PBKDF2-HMAC-SHA256` (100,000 iterations, 16-byte random
  salt), and encrypts the JSON payload with `AES-256-GCM`
  (12-byte nonce, MAC appended). Envelope:
  `{"version": 2, "kdf": {name, iterations, saltB64},
  ciphertextB64, macB64, nonceB64}`.
- The import flow supports v1 (plain JSON, back-compat) and v2
  (passphrase + encrypted). A wrong passphrase surfaces as
  `BackupFormatException`. The KDF iteration floor is
  enforced on read.
- The "plain JSON backups" caveat in `PRIVACY.md` is updated
  to describe both the v1 (read-only) and v2 (encrypted)
  paths.
- New dep: `cryptography: ^2.9.0` (mirrors `card_box`).

### v0.4c.2 — TalkBack / a11y static review

- `test/a11y/semantics_labels_test.dart` walks every
  `lib/screens/*.dart` and `lib/widgets/*.dart`, finds every
  `IconButton`, `ListTile`, button, `GestureDetector`, and
  `InkWell`, and asserts each has a `tooltip` / `semanticLabel`
  / `Text` / `Semantics` wrapper / `excludeFromSemantics: true`
  (SYS-062). 18 per-file tests, all green.
- The static analysis caught 6 real issues in
  `lib/screens/add_habit.dart` (three pairs of `+`/`-`
  IconButtons in the `n` / day-of-month / nth-weekday dialogs
  were missing tooltips). Fixed.
- The user's hands-on TalkBack pass on a real device (or
  emulator) is the v0.4d sign-off step.

### v0.4b-release-fix (ADR-013) — WorkManager cold-start crash

- **Post-mortem on the v0.4b release-mode launch crash.** The
  v0.4b release APK (`build/app/outputs/flutter-apk/app-release.apk`
  at SHA `8f0ec5c`) crashed on every cold start on a real
  device. Root cause: two interlocking defects in
  `lib/services/backup_scheduler.dart` —
  1. The WorkManager dispatcher was a **private** top-level
     function (`_backupTaskDispatcher`). In a release AOT
     build, `PluginUtilities.getCallbackHandle` cannot
     resolve a private symbol by name, and
     `Workmanager().initialize(...)` throws before `runApp`.
  2. `init()` rethrew the platform exception. The exception
     propagated out of `main()` and the OS killed the
     process.
- **The fix.**
  1. The dispatcher is renamed to a **public** top-level
     function `backupTaskDispatcher`. The `@pragma('vm:entry-point')`
     annotation stays. The symbol is pinned at the type
     level by a new test
     (`test/services/backup_scheduler_test.dart`:
     `backupTaskDispatcher is a public top-level function`).
  2. `init()` no longer rethrows. A platform exception is
     logged (debug-only, via the `assert(() { print(...);
     return true; }())` pattern that compiles to a no-op in
     release) and the gate is left uncompleted. A follow-up
     `scheduleNightlyBackup()` throws a clear `StateError`.
  3. `main()` wraps the `await BackupScheduler.instance.init()`
     call in a defensive `try/catch` (debug-only `debugPrint`).
- **The new test** `init() swallows platform exceptions`
  throws a `PlatformException` from the mock's
  `initialize` handler and asserts `init()` does not
  rethrow, the call was made, and the gate is left
  uncompleted.
- **The release APK is rebuilt.** v0.4d's sign-off line
  remains "Pending. Awaiting user's hands-on TalkBack
  pass (SYS-062)"; the v0.4b-release-fix commit is the
  artifact the TalkBack pass should exercise. See
  `decision_record.md` ADR-013.

### v0.4b-release-fix-2 (ADR-013 follow-up) — The real cold-start crash: R8 stripping workmanager's `WorkDatabase_Impl`

- **The v0.4b-release-fix at `384cfb2` was a misdiagnosis.**
  The user installed the rebuilt APK on a Samsung Galaxy S23
  (SM-S918B, Android 14) and reported the app still crashed
  on cold start. The 3-gate stayed green, the Dart-side
  dispatcher-name and `init()`-rethrow fixes from `384cfb2`
  are correct on their own, but they were not the cause of
  the release-mode cold-start crash. Pulling
  `adb logcat -b crash` showed the OS-side stack trace:
  `FATAL EXCEPTION: main` → `Unable to get provider
  androidx.startup.InitializationProvider` →
  `WorkManagerInitializer.create` → `Failed to create an
  instance of class
  androidx.work.impl.WorkDatabase.canonicalName`. The
  `r8-map-id-...` prefix on the stack frames confirms R8 had
  run, renaming Room's generated `WorkDatabase_Impl` class
  such that `Class.forName(...)` inside
  `WorkManagerInitializer.create` throws. The crash fires
  at process start, before any Dart code can run.
- **The real cause.** Two compounding issues:
  1. **workmanager's `androidx.startup` auto-init runs at
     process start.** The workmanager 0.6.0 plugin
     auto-registers an `androidx.startup.Initializer` (the
     `WorkManagerInitializer`) that fires before
     `MainActivity.onCreate` and constructs the workmanager
     singleton (which builds the `WorkDatabase`). do it
     already owns the WorkManager init order from
     `BackupScheduler.init` in Dart — the OS does not need
     to pre-create the singleton.
  2. **R8 ran in this AGP build.** The v0.3 decision was
     "R8 / minify is OFF" but the build config relied on
     the AGP default. AGP 9.1.0 (the version this project
     uses) ran R8 even with `isMinifyEnabled` not set, and
     R8 stripped/renamed the Room-generated
     `WorkDatabase_Impl` class.
- **The fix.**
  1. **Disable workmanager's auto-init at the OS level.**
     `android/app/src/main/AndroidManifest.xml` adds a
     `tools:node="remove"` entry inside the
     `InitializationProvider` block to drop the
     `androidx.work.WorkManagerInitializer` meta-data from
     the merged manifest. The provider itself stays; only
     the workmanager auto-init is removed.
  2. **Pin R8 / minify / resource-shrink off explicitly.**
     `android/app/build.gradle.kts` `buildTypes.release`
     now sets `isMinifyEnabled = false` and
     `isShrinkResources = false` explicitly. The v0.3
     decision becomes a compile-time invariant instead of a
     default assumption. A future AGP upgrade that flips a
     default cannot silently re-enable R8 and re-introduce
     the same crash shape.
- **Two new tests in `test/release_signing_test.dart`** pin
  both invariants:
  - `isMinifyEnabled = false is pinned in
    buildTypes.release` — asserts the explicit
    `isMinifyEnabled = false` and `isShrinkResources = false`
    lines.
  - `AndroidManifest disables workmanager
    WorkManagerInitializer auto-init` — asserts the
    `xmlns:tools` namespace, the
    `androidx.work.WorkManagerInitializer` reference, and
    the `tools:node="remove"` marker.
  A future revert of either change fails the test.
- **The release APK is rebuilt (69.7 MB, 2026-06-16).** The
  user installed it on the same SM-S918B device and the app
  launched — `pidof com.common_games.streak` is non-zero,
  the crash buffer is empty, first frame rendered, touch
  events flowing. The cold-start crash is fixed. See
  `decision_record.md` ADR-013 (follow-up) for the full
  post-mortem, the lessons, and the consequences.

## [0.3.0] — 2026-06-14 — Sideload-to-friends release

The first release that is not just for the user's primary phone.
Six PR-shaped work items (`6502432` → `5ebb441`):

### v0.3a — Public docs + version constant

- `LICENSE` (MIT) at the repo root. (SYS-050.)
- `PRIVACY.md` at the repo root with the four disclosure sections
  (what the app stores, what the app does NOT do, on-device
  footprint, no-`INTERNET` enforcement). The honest caveats
  include "Onboarding re-appears on every reinstall" (closed in
  v0.4a.3), "WorkManager scheduler dep is in pubspec but not
  wired" (closed in v0.4b), and "Backup files are plain JSON, not
  encrypted" (closed in v0.4c.1). (SYS-051.)
- `lib/build_info.dart` exposes `kAppVersion = '0.3.0'` and
  `kAppVersionCode = 3`. `pubspec.yaml` `version` mirrors it. The
  test `test/build_info_test.dart` asserts they match. (SYS-052.)

### v0.3b — Real release signing

- `android/app/build.gradle.kts` now declares a real
  `signingConfigs.create("release")` block that reads
  `android/key.properties` (gitignored) and falls back to debug
  signing when the file is absent. R8 / minify stays **off** for
  v0.3 (no `proguard-rules.pro`). (SYS-053.)
- `android/key.properties.example` committed as the four-key
  template; the real file is gitignored.
- `test/release_signing_test.dart` parses `build.gradle.kts` and
  asserts the structural shape (release `signingConfigs` block,
  `signingConfigs.getByName("release")` reference, the fallback
  to debug, and the `isMinifyEnabled` block is NOT set).

### v0.3c — In-app About / Open source licenses

- The static "v0.1.0 — local-only" tile in the Settings → About
  section is split into two: an informational tile that reads
  `${kAppVersion} — local-only. See PRIVACY.md for the data we
  store`, plus a tappable "Open source licenses" tile that opens
  `showLicensePage(applicationName: 'do it',
  applicationVersion: kAppVersion, applicationLegalese: 'Local-only.
  No telemetry. No accounts.')`. (SYS-054.)
- `test/screens/settings_licenses_test.dart` asserts both tiles
  are present and the licenses tile opens the standard Flutter
  route.

### v0.3d — Fresh-install smoke test

- `test/integration/fresh_install_test.dart` simulates a wiped-device
  install end-to-end: close the in-memory DB, re-init with
  `AppDatabase(NativeDatabase.memory())`, reset `ReminderService`
  to the `FakeAlarmScheduler`, pump `OnboardingScreen` (assert
  the rationale text), tap the "Done" CTA, pump `HomeScreen`
  (assert the empty-state placeholder), save a `HabitFixed`,
  schedule a test reminder, and assert the `FakeAlarmScheduler`
  received exactly one entry with `habitId == 'streak.test_reminder'`.
  (SYS-055.)
- The hands-on equivalent for the user is a 2-paragraph checklist
  in `docs/v_model/v0_3_release_checklist.md` § Fresh-install
  smoke test, ticked off on a wiped phone or emulator before
  handing the APK to friends.

### v0.3e — Release build

- The release baseline is `v0_3_release_baseline.md`; the
  right-side gate is `v0_3_release_checklist.md`. The release
  artifact is `build/app/outputs/bundle/release/app-release.aab`,
  built with `flutter build appbundle --release` against the
  user's upload key. The SHA of the build is recorded in the
  checklist.

### v0.3 honest README + back-fills

- The "implementation has not started" line in the README's
  Status section was replaced with a pointer to
  `docs/v_model/implementation_status.md` for the current slice.
  (SYS-056.)
- `SYS-048` (Test reminder, WF-028) and `SYS-049` (Bulk complete,
  WF-029) are back-filled in `requirements.md`. The v0.2 runbook
  cited them; the definitions were missing until v0.3a-prep.

## [0.2.0] — 2026-06-14 — UX completeness + v0.2 run #2

Builds on v0.1. Eight new workflows (WF-017..WF-031), sixteen new
SYS-IDs (SYS-032..SYS-047), four implementation phases (`9c032fc`
→ `fd1a4d9`). v0.2's right-side gate is the 14-day real-device
run #2 documented in `acceptance_run_v2.md`; that run is in
flight in parallel with the v0.3 release.

### v0.2a — Completeness

- A new `habits` table migration (`v2_to_v3`) adds `category`,
  `color_seed`, `icon_name`, `paused_until_millis`. The
  `people` table gains `paused_until_millis`. (SYS-045, SYS-046,
  SYS-047.)
- Edit-habit screen at `lib/screens/edit_habit.dart` preserves
  the completion log. (SYS-042, SYS-043.)
- Pause / resume service at `lib/services/pause_service.dart`; the
  habit-detail screen exposes the toggle. (SYS-047.)
- Category, color, and icon are first-class on every habit; the
  home screen renders the new chips. (SYS-045, SYS-046.)
- All four schedule types are exposed in the UI (`HabitInterval`,
  `HabitAnchor`, `HabitDayOfX` join `HabitFixed`). v0.1 had the
  type system but only Fixed in the add-habit flow.

### v0.2b — Events

- New `Event` sealed model at `lib/events/event.dart` with `name`,
  `at`, `leadTime`, optional `missionChain`, optional recurrence
  (`none` / `annually`), and `archivedAt`. (SYS-032..SYS-035.)
- `lib/services/event_repository.dart` (CRUD) and
  `lib/screens/add_event.dart` + `events_list.dart`. One-shot
  scheduling via the existing `AlarmScheduler` path. (SYS-033,
  SYS-034, SYS-035.)

### v0.2c — Contact groups

- New `PersonGroup` sealed model at
  `lib/people/person_group.dart` with `memberIds`, `cadence`,
  `GroupRotation` / `GroupAny` / `GroupAll` semantics, shared
  `channel`, shared `missionChain`, and a per-member
  `lastContactedByMember` map. (SYS-036..SYS-038.)
- `lib/services/person_group_repository.dart` and the rotation
  selector at `lib/people/rotation.dart`. (SYS-037.)
- `lib/screens/add_group.dart` and the home-screen group
  launcher. (SYS-038.)

### v0.2d — UX delight

- `HabitTimeWindow` (subclass of `Habit`) at
  `lib/habits/habit_time_window.dart` with `start`, `end`,
  `weekdays`, optional `targetDuration`. (SYS-039, SYS-040.)
- `lib/widgets/fasting_timer.dart` renders the live timer for
  time-window habits with a `targetDuration`. (SYS-040.)
- The Settings → About section gains a "Send a test reminder"
  tile that schedules a 5-second one-shot alarm via the
  existing `AlarmScheduler` path. (SYS-048 = WF-028.)
- The home screen gains a "Bulk complete" action that logs 1–4
  completions with timestamps spread across the missed window.
  (SYS-049 = WF-029.)

## [0.1.0] — 2026-06-14 — Personal-use baseline

The first installable Android build. Runs on the user's primary
phone; the 14-day real-device run is at
`docs/v_model/acceptance_run.md`. Five implementation phases
(`e5404ac` → `5f4f31d`); one runbook-only phase (`eeb87a0`).

### Phase 0 — Scaffold

- `flutter create` with `--org com.common_games --project-name
  streak --platforms android`. `pubspec.yaml` is `name:
  common_games` (monorepo convention). 18 lints in
  `analysis_options.yaml`; `minSdk = 28`; core-library desugaring
  enabled (required by `flutter_local_notifications` 17.x);
  `workmanager` pinned to `^0.6.0` because 0.5.x uses the removed
  v1 Flutter plugin embedding. The v0.1 permission baseline is in
  `android/app/src/main/AndroidManifest.xml`.

### Phase 1 — Models and schedule engine

- `lib/habits/habit.dart` (sealed, with `HabitFixed`,
  `HabitInterval`, `HabitAnchor`, `HabitDayOfX`).
- `lib/habits/schedule.dart` — pure-Dart `nextOccurrence()` per
  type. (SYS-001, SYS-002.)
- `lib/habits/proof_mode.dart` (sealed `Soft` / `Strong` /
  `Auto`); immutability after creation. (SYS-007, ADR-012.)
- `lib/habits/streak_calculator.dart` — pure-Dart streak from a
  completion log. (SYS-019.)
- `lib/habits/rest_day_budget.dart` — 2 / calendar month,
  hard-reject on exhaustion. (SYS-020.)
- `lib/people/person.dart` (sealed channel type) and
  `lib/people/cadence.dart` (pure-Dart `nextOccurrence()`).
  (SYS-014.)

### Phase 2 — Local DB (Drift)

- `lib/services/db.dart` (Drift singleton, `Completer<void>
  _ready` gate). The schema version is 2; `lib/services/db/
  migrations/v1_to_v2.dart` is the only migration so far.
  (SYS-022.)
- Tables: `habits`, `people`, `completions`, `missions`,
  `settings`. (SYS-022.)

### Phase 3 — Mission engine

- `lib/missions/mission.dart` (sealed `ShakeMission`,
  `TypeMission`, `HoldMission`, `MathMission`, `MemoryMission`).
  (SYS-008..SYS-012.)
- `lib/missions/chain.dart` — pure-Dart executor. A failure
  aborts the rest; timeouts are a special case. (SYS-013,
  SYS-031.)
- `lib/missions/shake_detector.dart` is the only file in this
  folder that imports `package:sensors_plus`. (SYS-008.)
- Per-mission tests cover happy path, parameter edge cases, and
  at least one fail-fast. (SYS-008..SYS-012.)

### Phase 4 — Reminder scheduling

- `lib/reminders/alarm_scheduler.dart`,
  `lib/reminders/notification_service.dart`,
  `lib/reminders/full_screen_intent.dart`, and
  `lib/reminders/anchor_detector.dart`. (SYS-003, SYS-005,
  SYS-006, SYS-029, SYS-015..SYS-017.)
- `android/app/src/main/.../BootReceiver.kt` — native Kotlin
  receiver for `BOOT_COMPLETED` / `LOCKED_BOOT_COMPLETED` /
  `MY_PACKAGE_REPLACED`; re-schedules all pending alarms from
  the local DB. (SYS-016, SYS-017.)
- `android/app/src/main/.../HomeWidgetProvider.kt` — the
  due-now strip on the launcher widget. (SYS-029.)
- The manifest baseline is at
  `android/app/src/main/AndroidManifest.xml` and is cross-checked
  against `docs/v_model/architecture_options.md` on every PR
  that touches it. (SYS-026, SYS-030.)

### Phase 5 — Screens and onboarding

- `lib/screens/onboarding.dart` — permission-first flow with
  rationale screens for `POST_NOTIFICATIONS`, `READ_CONTACTS`,
  `SCHEDULE_EXACT_ALARM`, battery optimization, OEM auto-start,
  backup folder, and anchor mode. (SYS-025.)
- `lib/screens/home.dart` — catalog + due-now strip + "I'm up"
  anchor button. (SYS-015, SYS-027.)
- `lib/screens/add_habit.dart` and `add_person.dart` — multi-step
  form, mission-chain composer. (SYS-001, SYS-002.)
- `lib/screens/stats.dart` — streaks, completion rate, time-of-day
  histograms; consumes `StreakCalculator` over
  `CompletionLogService`. (SYS-021.)
- `lib/screens/settings.dart` — theme, anchor mode, reliability
  row, restore-from-backup tile, OEM guide card. (SYS-003,
  SYS-025, SYS-027.)
- `lib/screens/mission_<name>.dart` (5 screens) for Shake,
  Type, Hold, Math, Memory; per-screen widget tests. (SYS-008..SYS-012.)

### Phase 6 — Backup

- `lib/services/backup_service.dart` — SAF-based. JSON envelope
  `{version, exportedAtMillis, tables}`. `kBackupFormatVersion = 1`.
  Six tables round-trip: `habits`, `people`, `completions`,
  `restDayBudgets`, `settings`, `eventLogs`. (SYS-023, SYS-024.)
- `lib/screens/settings_restore.dart` — SAF file picker + confirm
  dialog. (SYS-024.)
- `test/services/backup_service_test.dart` covers envelope shape,
  round-trip, missing file, malformed JSON, future version, and
  missing-tables.

### Phase 7 — Acceptance run

- The runbook at `docs/v_model/acceptance_run.md` defines 11
  scenarios, 17 SYS-IDs, 9 WF-IDs, a per-day log template, and
  exit criteria. The run is hands-on (install on the primary
  phone); no code lands in this phase.

## [Pre-1.0] — 2026-06-13 — Project bootstrap

- V-Model artifacts seeded: `plan.md`, `conops.md`, `workflows.md`
  (WF-001..WF-016), `requirements.md` (SYS-001..SYS-030),
  `v0_1_baseline.md`, `architecture_options.md`,
  `decision_record.md`, `traceability_matrix.md`,
  `mission_catalog.md`, `notification_reliability.md`, and
  `open_questions.md` (20 items, all non-blocking for v0.1).
- Twelve ADRs in `decision_record.md`. (Append-only.)
- The 18 lints in `analysis_options.yaml` are inherited from
  `board_box`; they catch the issues the v0.1 baseline cares
  about (`unawaited_futures`, `prefer_final_locals`,
  `always_use_package_imports`, etc.).
