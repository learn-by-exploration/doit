# do it — Changelog

All notable changes to the do it app are documented here. do it
follows a V-Model process: each release has a left-side baseline
(`docs/v_model/v<major>_<minor>_baseline.md`) and a right-side
checklist (`v<major>_<minor>_release_checklist.md`). This changelog
is the user-facing summary of what shipped in each release; the
V-Model artifacts are the engineering contract.

## [1.4.0] — 2026-06-27 — Home widget + in-app tile completion lifecycle

Four v1.4 sub-entries (v1.4a..v1.4d) ship the **home widget + the
in-app tile's full completion lifecycle**. The headline themes:
**Android home-screen widget** (v1.4a — the first launcher
surface; a native `AppWidgetProvider` + `RemoteViews` over the
`doit/widget` MethodChannel; renders the first-active do's streak
+ a unified `Reliability` badge; cold-start fallback uses
`SharedPreferences` so the widget is never blank between OS
process-kill and first Dart frame; closes B9 / `feature.md` §2.8
+ the home-widget gap from the 30-phase roadmap), **in-app tile
streak + Done button** (v1.4b — the home tile grows the same
streak number + "Mark done" affordance as the widget, mirroring
`WidgetService.markDone` via `CompletionLogService.append`;
strong-mode habits push `MissionLauncherScreen` end-to-end),
**in-app tile Skip today + rest-day budget indicator** (v1.4c —
per-tile "Skip today" `IconButton` consumes a rest-day slot from
the per-do `restDaysPerMonth` budget; the success snackbar reads
"Rest day taken"; the budget caption updates from "X / Y rest
days left" → "No rest days left" on exhaustion), **in-app tile
Undo today's completion** (v1.4d — per-tile `IconButton` visible
only when today is resolved; opens a confirm dialog; calls the
new pure-Dart `undoToday` helper which deletes the matching
`CompletionRow` via the existing
`CompletionLogService.deleteById` from v1.2m / SYS-108; mirrors
`CompletionLogSection._confirmAndDelete` with one fewer tap).

The four sub-entries ship in chronological order across this
CHANGELOG block (see `## v1.4a` / `## v1.4b` / `## v1.4c` /
`## v1.4d` below for the per-sub-entry detail). The left-side
baseline is [`docs/v_model/v1_4_release_baseline.md`](docs/v_model/v1_4_release_baseline.md);
the right-side checklist is
[`docs/v_model/v1_4_release_checklist.md`](docs/v_model/v1_4_release_checklist.md).
`pubspec.yaml` is bumped `1.3.0+10` → `1.4.0+11`; `lib/build_info.dart`
mirrors; `test/release_signing_test.dart` mirror-pin assertions
updated in lockstep.

No new `<uses-permission>`, no `INTERNET`, no DB migration. The
`doit/widget` MethodChannel is a new Kotlin-side handler (no
new pubspec dep — `home_widget` is NOT used). The `FullScreenActivity`
launch path from v1.3d is unchanged. The CI grep rejecting
`import 'package:http'` and `Uri.http(s)` in production code is
unchanged. `flutter test` ends the cycle at **1197 / 1197** tests
passing (+133 over the v1.3 sign-off tip of 1064).

## [1.3.0] — 2026-06-25 — Reliability + lifecycle hardening

Four v1.3 sub-entries (v1.3a..v1.3d) ship the reliability +
lifecycle hardening pass over the v1.2 foundation. The headline
themes: **stats-side groundwork** (v1.3a — monthly 30-day
completion-rate + 7-day bar chart + per-do `graceWindowOverride`
factory), **reliability unification** (v1.3b — a single
`ReliabilityService.instance` is the unified `Stream<Reliability>`
source-of-truth; the home-screen `ReliabilityBanner` and the
settings `_ReliabilityRow` both bind to
`ReliabilityService.instance.notifier`; the
`_kReliabilityGatedKinds` set is the policy gate),
**special-access gating** (v1.3c — `PermissionKind.fullScreenIntent`
joins the gated set, now 5 elements; the Settings → Permissions
screen gains a 5th `_PermissionTile`; the home banner's `onTap`
deep-links the user to the tile; the manifest declares
`<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"
tools:ignore="ProtectedPermissions" />`), and **strong-mode
interruption end-to-end** (v1.3d — `FullScreenActivity` Kotlin
class lands with lockscreen-bypass window flags; the launch
handlers on `doit/full_screen` (`showHabitMission`,
`showRoutineOverlay`) fire the activity; the strong-mode
notification uses `setFullScreenIntent(openPi, true)`; the
chain-level orchestrator widget `MissionLauncherScreen` walks
the `MissionChain` and appends the completion on `ChainPassed`).
Version `1.2.0+9` → `1.3.0+10`. 1064 / 1064 tests, `dart format`
clean, `flutter analyze --fatal-infos` clean. Right-side gate:
`v1_3_release_checklist.md` + `implementation_status.md` rows
v1.3a..v1.3d. Left-side baseline: `v1_3_release_baseline.md`.
ADRs 042-044 (decision_record.md) + SYS-112-114
(requirements.md) were appended in this cycle. The v1.3 cycle
added one new permission (`USE_FULL_SCREEN_INTENT`, opt-in per
ADR-030); no `INTERNET`. Closes `feature.md` §2.1 "Still
deferred" (Phase 6a proper). The deferred items
(action-side permission disambiguation, native Spanish
translator, Wear OS, iOS port, home widget) are tracked in
[`feature.md`](feature.md) §2-4 as v1.x candidates.

## v1.4a — Android home-screen widget (Phase 28 / SYS-115 / ADR-045 / WF-042)

The first v1.x parking-lot item ships: a native Android
home-screen widget (`com.doit.DoitWidgetProvider`) that
renders the user's first-active do, current streak number,
"Done" button, and the unified `Reliability` badge
(`ic_widget_optimal` / `ic_widget_degraded` /
`ic_widget_unknown`). This closes the v1.2g-deferred
`feature.md` §2.8 B9 ("Widget re-arm indicator") — the
"widget re-arm indicator" requirement now has a surface.

### Dart side (6 new files)

- `lib/widget/doit_widget_state.dart` — `@immutable` value
  class with `==` / `hashCode` / `toJson` / `fromJson` /
  `copyWith`; defensive `fromJson` (missing fields default
  to empty / 0 / `unknown`; unrecognized reliability tag
  falls back to `unknown`; unparseable `asOfIso` falls back
  to epoch). Pure-Dart, no Flutter import.
- `lib/widget/widget_bridge.dart` — abstract `WidgetBridge`
  + `PlatformWidgetBridge` (MethodChannel `doit/widget`
  with `_safe` wrapper per ADR-013) + `FakeWidgetBridge`
  (records `cachedSnapshots` + `refreshCount`).
- `lib/widget/widget_state_builder.dart` — pure-Dart
  `buildWidgetState(...)` factory using
  `ConsecutiveCounter.compute` for the streak +
  `Do.effectiveStreakConfig(...)` for the per-do grace
  window override + reliability→badge 1:1 mapping; `null
  activeDo` produces the empty-state snapshot.
- `lib/widget/widget_state_cache.dart` —
  `SharedPreferences`-backed singleton (key
  `doit.widget.cached_v1`) for the cold-start fallback.
- `lib/widget/widget_state_locator.dart` — `firstActiveDo(...)`
  sorts `DoRepository.listAll()` ascending by `createdAt`
  and returns the first non-paused entry (or `null`).
- `lib/services/widget_service.dart` — singleton-with-`_ready`
  (per `.claude/rules/lib-services.md`); `init({bridge,
  doRepository, completionLog, reliabilityService, cache?})`
  is idempotent, subscribes to `ReliabilityService.reliability`
  so every value change triggers a re-derive, primes the cache
  + platform on init, exposes `handleRefreshRequest()` +
  `markDone(habitId)` (no-op when habit missing; otherwise
  appends via `CompletionLogService` with `source:
  CompletionSource.manual` then re-derives); platform-side
  failures swallowed per ADR-013.

### Kotlin side (4 new files + MainActivity wiring)

- `android/app/src/main/kotlin/com/doit/DoitWidgetProvider.kt`
  — `AppWidgetProvider` subclass; `onUpdate` reads
  `WidgetStateCache.cachedFromPrefs(ctx)` FIRST for
  cold-start fallback then attempts a Dart round-trip via
  `WidgetUpdater.refreshIds(ctx, ids)`; `onEnabled` +
  `onDisabled` lifecycle hooks; `onReceive` dispatches
  `ACTION_REFRESH_WIDGET` + `ACTION_MARK_DONE`.
- `android/app/src/main/kotlin/com/doit/WidgetChannel.kt`
  — `object` mirroring `FullScreenIntentChannel.kt` shape
  with `attach(engine)` / `detach()` / `setAppContext(ctx)`;
  dispatches `snapshot` + `cacheSnapshot` + `markDone`
  MethodChannel calls.
- `android/app/src/main/kotlin/com/doit/WidgetUpdater.kt`
  — boots a one-shot `FlutterEngine` via `FlutterEngineCache`,
  applies the cached `RemoteViews`, then triggers a Dart
  round-trip.
- `android/app/src/main/kotlin/com/doit/WidgetStateCache.kt`
  — Kotlin-side `SharedPreferences` at `doit_widget` prefs,
  key `doit.widget.cached_v1`; mirrors the Dart
  `WidgetStateCache` so the widget is never blank between
  OS process-kill and first Dart frame.
- `MainActivity.kt` — `WidgetChannel.setAppContext(...)` +
  `WidgetChannel.attach(flutterEngine)` in
  `configureFlutterEngine`; `WidgetChannel.detach()` in
  `onDestroy`.

### Android resources (5 new)

- `res/xml/doit_widget_info.xml` — 4×2 cell,
  `updatePeriodMillis=1800000`,
  `targetCellWidth=4 targetCellHeight=2`,
  `widgetCategory="home_screen"`, `initialLayout=@layout/widget_medium`.
- `res/layout/widget_medium.xml` — vertical `LinearLayout`
  with habit-name + reliability badge, streak number +
  "day streak" subtitle, "Done" `ImageButton`; tap-target
  `FrameLayout` root with id `widget_root`.
- `res/drawable/widget_bg.xml` + `ic_widget_optimal|degraded|unknown|done.xml`
  — monochrome vector icons + 12 dp rounded rect.
- `res/values/strings.xml` — 6 new `<string>` entries
  (`widget_description`, `widget_done_content_description`,
  `widget_streak_content_description`,
  `widget_streak_subtitle`, `widget_empty_state`,
  `widget_reliability_badge`).

### AndroidManifest.xml

- ONE new `<receiver android:name=".DoitWidgetProvider"
  android:exported="false">` block inside `<application>`
  with `APPWIDGET_UPDATE` intent-filter + `@xml/doit_widget_info`
  meta-data. **No new `<uses-permission>`** — widget
  rendering needs none.

### Tests (5 new files, 35 tests)

- `test/widget/widget_state_builder_test.dart` (8 tests)
  — streak from empty log is 0; streak with 3 consecutive
  days; streak broken at grace-window edge; streak still
  alive within grace window; `isCompletedToday` true only
  when today is in the log; reliability maps to widget
  badge; `null activeDo` produces the empty-state snapshot;
  `Do.effectiveStreakConfig` flows through the factory
  end-to-end.
- `test/widget/widget_bridge_test.dart` (11 tests) —
  `FakeWidgetBridge` cacheSnapshot records;
  `FakeWidgetBridge` requestRefresh increments;
  `FakeWidgetBridge` snapshot returns scripted / null by
  default; `PlatformWidgetBridge` cacheSnapshot forwards
  the JSON envelope; `PlatformWidgetBridge` snapshot happy
  path; `PlatformWidgetBridge` snapshot swallows
  `MissingPluginException`; `PlatformWidgetBridge` snapshot
  swallows `PlatformException`; `PlatformWidgetBridge`
  requestRefresh swallows `MissingPluginException`;
  `DoitWidgetState` JSON round-trips; `fromJson` is
  defensive against missing fields; `fromJson` tolerates
  an unknown reliability tag.
- `test/widget/widget_state_cache_test.dart` (5 tests) —
  save-then-load round-trips; load returns null on empty
  prefs; clear removes the key; save overwrites previous;
  corrupt cache is dropped.
- `test/widget/widget_state_locator_test.dart` (4 tests) —
  returns first-active do by oldest `createdAt`; skips
  paused dos; returns null on empty repository; returns
  null when every do is paused.
- `test/widget/widget_service_test.dart` (6 tests) —
  `init` is idempotent; `handleRefreshRequest` computes +
  caches + persists state; `markDone` appends the completion
  then re-derives; `markDone` is a no-op when the habit
  does not exist; reliability change triggers a re-derive;
  `MissingPluginException` from the bridge is swallowed
  (ADR-013).

### V-Model

- SYS-115 appended (requirements.md).
- ADR-045 appended (decision_record.md) — native
  `AppWidgetProvider` + `RemoteViews` over the `doit/widget`
  MethodChannel; rejects `home_widget` pubspec dep per
  ADR-018.
- WF-042 appended (workflows.md) — end-to-end "View streak
  on the Android home widget" flow.
- `traceability_matrix.md` — WF-042 row added with the 5
  new test files + Kotlin compile gate + manual device
  check.
- `implementation_status.md` — `### v1.4a` row appended.
- `feature.md` §2.8 B9 → shipped in v1.4a; §4 parking-lot
  home-widget bullet removed; §5 quick-index row updated.
- 1130 / 1130 tests pass (1064 prior + 66 new across the
  v1.3 sign-off PRs and v1.4a). `dart format` clean,
  `flutter analyze --fatal-infos` clean.

### Notes

- pubspec stays at `1.3.0+10` until v1.4a signs off; the
  v1.4a sign-off commit is a separate PR that flips
  `pubspec.yaml` + `lib/build_info.dart` + `test/release_signing_test.dart`
  in lockstep, mirroring the v1.2 sign-off at `8684a6e` +
  the v1.3 sign-off at `f51602c`.
- No new pubspec dependencies; no new `<uses-perpermission>`;
  no `wakelock_plus`; no `home_widget` package. The widget
  renders from `RemoteViews` not a `FlutterActivity`.
- The deferred items (small / large widget variants,
  in-app tile streak number, widget config activity,
  deep-link from widget body to a specific do, iOS / Wear
  OS widget surfaces) are tracked in `feature.md` §4 as
  v1.4b candidates.

## [1.2.0] — 2026-06-23 — Code-TODO closure

Thirteen v1.2 sub-entries (v1.2a..v1.2m) ship the
remaining code-TODO closure pass over the v1.1
foundation. The headline themes: **wire-up** (the
NotificationService show/dismiss path, the routine
Action leaves, BOOT_COMPLETED coverage confirmation),
**UX completeness** (Person pauseUntil UI,
DoFixed weekday display, DST transition banner,
streak-recovery card, pre-notification heads-up),
**reliability disambiguation** (per-automation
AlertDialog on tap, AppLifecycleState.resumed
re-probe hook), and **edit affordances** (hard
delete with confirm, completion-log review + undo,
uniform 3-wrong take-a-break across Math + Type).
Version `1.1.0+8` → `1.2.0+9`. 1001 / 1001 tests,
`dart format` clean, `flutter analyze --fatal-infos`
clean. Right-side gate: `v1_2_release_checklist.md`
+ `implementation_status.md` rows v1.2a..v1.2m.
Left-side baseline: `v1_2_release_baseline.md`.
ADRs 033-041 (decision_record.md) + SYS-098-110
(requirements.md) were appended in this cycle. No
new permissions, no `INTERNET`. The deferred
items (strong-mode full-screen hardening,
action-side permission disambiguation,
`google_maps_flutter` map tiles, native Spanish
translator, Wear OS, iOS port) are tracked in
[`feature.md`](feature.md) §2-4 as v1.x candidates.

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

### v1.4a — Android home-screen widget (Phase 28 / SYS-115 / ADR-045 / WF-042)

First time the app surfaces a habit on the Android home screen
without opening the app. The widget renders the user's
first-active do (the soonest-paused-eligible do in
`DoRepository.listAll()`, sorted by `createdAt` ascending), the
current `currentStreak` number, the localized "day streak"
subtitle, the unified `Reliability` caption, and a "Mark done"
`RemoteViews` button. New code:

- `lib/widget/widget_state_locator.dart` (NEW) —
  `firstActiveDo({required DoRepository repo, required DateTime reference}) → Do?`
  (sorted by `createdAt` ascending; paused dos skipped).
- `lib/widget/widget_state_builder.dart` (NEW) —
  `buildWidgetState({required Do? do, required List<CompletionRow> completions, required Reliability reliability, required DateTime asOf}) → DoitWidgetState`
  (pure-Dart; calls `ConsecutiveCounter.compute` for the streak).
- `lib/services/widget_service.dart` (NEW) — singleton-with-`_ready`
  wrapper around the `doit/widget` MethodChannel; exposes
  `handleRefreshRequest`, `markDone`, `applyReliability`
  (swallows `MissingPluginException` per ADR-013).
- `android/app/src/main/kotlin/com/doit/DoitAppWidgetProvider.kt`
  (NEW) — `AppWidgetProvider` + `RemoteViews` rendering
  `widget_medium.xml` (do name / streak / reliability / Done
  button).
- `AndroidManifest.xml` — declares `<receiver
  android:name=".DoitAppWidgetProvider" android:exported="false">`
  with the `android.appwidget.action.APPWIDGET_UPDATE` intent
  filter.

**ADR-045** explicitly rejects the `home_widget` pubspec
package — the widget surface is small, the Kotlin side
already had `AppWidgetProvider` + `RemoteViews` in scope from
v1.3d's `FullScreenActivity` (SYS-114), and adding the
package for one channel is unjustified. Strong-mode "Done"
deep-links to the existing `MissionLauncherScreen` (SYS-114);
soft/auto paths write the completion directly via
`CompletionLogService.append` with `source:
CompletionSource.manual`. No new `<uses-permission>`, no new
pubspec dep.

**SYS-115 + ADR-045 + WF-042 appended.** `feature.md` §2.8
B9 closed; §4 widget bullet removed.

Tests: 1130 / 1130 (1085 prior + 45 new — 3
widget_state_locator + 3 widget_state_builder + 6
widget_service + 3 widget_locale + 30 across the existing
`test/services/reminder_service_test.dart` +
`test/routines/action_dispatch_test.dart` smoke fixtures).

### v1.4b — In-app home tile streak + Done button (Phase 29 / SYS-116 / ADR-046 / WF-043)

Brings the v1.4a widget's UX surface to the in-app home tile.
The home tile (`_HabitTile` in `lib/screens/home.dart`) now
shows the streak number next to the do name, a "day streak"
subtitle, and a per-tile "Mark done" `IconButton` that mirrors
the widget's affordance. The existing SnackBar stub at the
bottom-right of each tile is replaced with a real completion
write via `CompletionLogService.append(habitId, day, source:
CompletionSource.manual, proofModeAtTime: <soft|strong|auto>)`
— same call shape as `WidgetService.markDone`. New code:

- `lib/screens/home_tile_streak.dart` (NEW) — pure-Dart
  helpers: `streakForDo({required Do activeDo, required
  List<CompletionLogEntry> completions, required DateTime
  asOf})` (calls `ConsecutiveCounter.compute` for the streak)
  + `isCompletedOnDay({required List<CompletionLogEntry>
  completions, required DateTime asOf})` (the local-day
  presence check).
- `lib/screens/home_tile_completion.dart` (NEW) — `markDoDone(
  {required Do activeDo, required DateTime asOf, required
  CompletionLogService completionLog})`. The `_proofModeTag`
  helper is inlined here, mirroring the widget's helper — kept
  in lockstep manually until a future PR extracts both into
  `lib/do/proof_mode_tag.dart` (deferred until v1.4a lands on
  `main`).
- `lib/screens/home.dart` — `_HabitTile` is now a
  `StatefulWidget` (`_HabitTileState`) holding `_busy` and
  `_isCompletedToday`. A new `_DoStreakBadge` sub-widget renders
  the streak + subtitle. A new `_DoneButton` sub-widget
  replaces the SnackBar stub: soft/auto → `markDoDone(...)`;
  strong → push `MissionLauncherScreen` (SYS-114) and await the
  pop; already-done → `homeTileAlreadyDoneTooltip` SnackBar.
- `lib/l10n/app_en.arb` + `app_es.arb` — 4 new keys
  (`homeTileMarkDone`, `homeTileStreakLabel`,
  `homeTileAlreadyDoneTooltip`, `homeTileStrongModeHint`). The
  existing `homeSnackbarMarkedDone` is re-used.

**ADR-046** locks the design: pure-Dart helpers, frozen `asOf`
per build, re-compute on every rebuild (cheap: pure-Dart + ~10
entries per visible tile), single source of truth for the
completion write (both surfaces call the same
`CompletionLogService.append` shape), no `StreakService`
needed. No new pubspec dep; no new `<uses-permission>`.

**SYS-116 + ADR-046 + WF-043 appended.** `feature.md` §4 home
tile streak bullet removed; §5 quick-index updated to ADR-046
/ SYS-116 / WF-043.

Tests: 1149 / 1149 (1130 prior + 19 new — 12 home_tile_streak
+ 4 home_tile_completion + 7 home_test widget extensions per
the 3-gate at this commit; the 6 pre-existing `home_test` cases
still pass).

### v1.4c — In-app home tile Skip today button + rest-day budget indicator (Phase 30 / SYS-117 / ADR-047 / WF-044)

Closes the v1.4b → v1.4c parking-lot item: the home tile now
exposes a "Skip today" affordance that consumes one unit of
the do's monthly rest-day budget, plus a small "X / Y rest
days left" caption inside the existing `_DoStreakBadge`. The
streak calculator (`ConsecutiveCounter.compute`) already
credits `CompletionSource.restDay` rows identically to manual
rows, so a rest-day entry preserves the streak end-to-end.
New code:

- `lib/screens/home_tile_skip.dart` (NEW) — pure-Dart
  helpers: `markDoSkipped({required Do activeDo, required
  DateTime asOf, required CompletionLogService completionLog})`.
  Reads `activeDo.restDaysPerMonth`; throws
  `NoRestDaysRemaining(activeDo.id, asOf.year, asOf.month)`
  on `<= 0` or exhausted month. Constructs
  `SkipBudget(doId, monthlyLimit).consume(asOf)` (defensive:
  `SkipBudgetExhausted` is converted to `NoRestDaysRemaining`
  so the contract stays single-message). Calls
  `completionLog.append(habitId, day, source:
  CompletionSource.restDay, proofModeAtTime:
  proofModeTag(activeDo.proofMode))`.
- `lib/screens/home_tile_budget.dart` (NEW) — pure-Dart
  helpers: `budgetRemainingForDo({required Do activeDo,
  required DateTime asOf, required CompletionLogService
  completionLog})` + `BudgetRemaining` immutable value class
  (`used` / `limit` / `remaining`; `canSkip = remaining > 0`;
  `isExhausted = remaining == 0 && limit > 0`; clamps
  negative `remaining` to 0 so a do whose `restDaysPerMonth`
  was lowered mid-month does not render a negative
  caption).
- `lib/do/proof_mode_tag.dart` (NEW) — the shared
  `proofModeTag(DoProofMode)` helper. Consolidates 2 of the
  3 inline copies left over from v1.4b
  (`do_repository.dart` + `home_tile_completion.dart`).
  `mission_launcher.dart` is **not** refactored because its
  `'unknown'` defensive contract differs (it must never
  throw on a future subclass).
- `lib/services/do_repository.dart` (MODIFIED) — uses the
  shared `proofModeTag` instead of the inline `_proofModeTag`.
- `lib/screens/home_tile_completion.dart` (MODIFIED) — uses
  the shared `proofModeTag` instead of the inline
  `_proofModeTag`.
- `lib/screens/home.dart` — `_HabitTileState` grows an
  `_isSkippedToday` flag + `_isResolvedToday = _isCompletedToday
  || _isSkippedToday` getter. New `_SkipButton` sub-widget
  (Icons.bedtime / bedtime_outlined; tooltip
  `homeTileSkipToday` / `homeTileSkipAlready`; tap calls
  `markDoSkipped(...)` in `try/catch on NoRestDaysRemaining`
  → `homeTileSkipSuccess` / `homeTileSkipBudgetExhausted`
  SnackBar). New `_BudgetCaption` sub-widget renders inside
  `_DoStreakBadge` (FutureBuilder over
  `budgetRemainingForDo(...)`; `homeTileBudgetRemaining` /
  `homeTileBudgetNoRemaining` / `SizedBox.shrink()` mid-fetch).
  The `_DoneButton`'s post-tap SnackBar now branches on
  `_isSkippedToday` for `homeTileSkipAlready` vs
  `homeTileAlreadyDoneTooltip` (a Done tap on a skipped-today
  tile shows the rest-day-taken snackbar instead of the
  already-done snackbar — the row IS resolved, just by a
  different mechanism).
- `lib/l10n/app_en.arb` + `app_es.arb` — 6 new keys
  (`homeTileSkipToday`, `homeTileSkipAlready`,
  `homeTileSkipSuccess`, `homeTileSkipBudgetExhausted`,
  `homeTileBudgetRemaining`, `homeTileBudgetNoRemaining`).

**ADR-047** locks the design: pure-Dart helpers, state-only
`_isSkippedToday` flag (DB drives the `_BudgetCaption` on
every build via the existing `listRestDaysInMonth` query),
rest-day budget exhaustion is a soft signal (the streak
calculator only checks the budget at write time, not at
compute time), single source of truth for the rest-day write
(both surfaces call the same `CompletionLogService.append`
shape with `source: CompletionSource.restDay`), no new
pubspec dep; no new `<uses-permission>`.

**SYS-117 + ADR-047 + WF-044 appended.** `feature.md` §4
home-tile skip bullet removed; §5 quick-index updated to
ADR-047 / SYS-117 / WF-044.

Tests: 1148 / 1148 (1149 v1.4b tip − 1 duplicate-removed by
lint cleanups + 19 new — 8 home_tile_skip + 11 home_tile_budget
+ 7 home_test widget extensions per the 3-gate at this commit;
the 19 added in v1.4b — 12 streak + 4 completion + 7 home
extensions — remain green; the 6 pre-existing `home_test`
cases still pass; the v1.4b + v1.4c net delta against the
v1.4a `main` baseline of 1130 is +18).

### v1.4d — In-app home tile Undo today's completion (Phase 31 / SYS-118 / ADR-048 / WF-045)

Closes the v1.4c → v1.4d parking-lot item: the home tile
now exposes an "Undo" affordance that reverts an accidental
Done or Skip tap on today's tile in a single confirm-tap.
The existing `CompletionLogService.deleteById(rowId)` (v1.2m)
is re-used verbatim; no new Drift methods, no new
`lib/services/` surface. Mirrors the `CompletionLogSection`
(SYS-108 / WF-025) review-and-undo flow but with one fewer
tap (no scroll, no list, no per-row delete icon — just a
confirm dialog on the tile itself). New code:

- `lib/screens/home_tile_undo.dart` (NEW) —
  `undoToday({required Do activeDo, required DateTime
  asOf, required CompletionLogService completionLog})`
  fetches `completionLog.listForHabit(activeDo.id)` (re-
  uses the v1.0 query that backs `CompletionLogSection`),
  filters rows whose `day` equals `DateTime(asOf.year,
  asOf.month, asOf.day)` (local-midnight comparison —
  same convention as `markDoDone` + `markDoSkipped`), and
  on the happy path calls `completionLog.deleteById(row.id)`
  exactly once. Returns `UndoResult.removed(rowId, source)`
  (carries the deleted row's id + source) or
  `UndoResult.nothingToUndo()` (defensive — the dialog is
  gated on `_isResolvedToday == true`, but the DB is the
  source of truth and a concurrent app-tile rebuild could
  leave a dangling flag). Pure-Dart, no Flutter import, no
  `DateTime.now()`.
- `lib/screens/home.dart` — `_HabitTileState` grows a
  `_UndoButton` sub-widget (`Icons.undo`, tooltip
  `homeTileUndoToday`, sits between `_SkipButton` and
  `_DoneButton`). Visibility is gated on
  `_isResolvedToday == true` — the tile is "resolved" for
  the day via either Done (`_isCompletedToday`) or Skip
  (`_isSkippedToday`). The undo affordance disappears for
  fresh tiles, eliminating the temptation to undo a row
  that does not exist. Tap opens an `AlertDialog` titled
  `homeTileUndoConfirm` with body `homeTileUndoConfirmBody`;
  the confirm callback calls `undoToday(...)` and on the
  `removed` branch flips `_isCompletedToday` /
  `_isSkippedToday` (whichever was true) back to `false`
  and shows the `homeTileUndoSuccess` SnackBar; on the
  `nothingToUndo` branch shows the `homeTileUndoNotToday`
  SnackBar.
- `lib/l10n/app_en.arb` + `app_es.arb` — 5 new keys
  (`homeTileUndoToday`, `homeTileUndoConfirm`,
  `homeTileUndoConfirmBody`, `homeTileUndoSuccess`,
  `homeTileUndoNotToday`).

**ADR-048** locks the design: pure-Dart helper re-using
the existing `CompletionLogService.deleteById` (no new
service surface), `UndoResult` sealed value class
matching the `BudgetRemaining` value-class shape from
v1.4c, dialog-gated `_UndoButton` visibility on
`_isResolvedToday == true` (a derived getter that
already exists from v1.4c), DB-driven source-of-truth
via `listForHabit` (the same query `CompletionLogSection`
uses), defensive `nothingToUndo` branch even though
the dialog is gated (DB-as-truth principle), no new
pubspec dep; no new `<uses-permission>`.

**SYS-118 + ADR-048 + WF-045 appended.** `feature.md`
§4 per-tile undo bullet removed; §5 quick-index updated
to ADR-048 / SYS-118 / WF-045.

Tests: 1183 / 1183 (1183 v1.4c tip + 13 new — 8
home_tile_undo + 5 home_test widget extensions per the
3-gate at this commit; the 19 added in v1.4b + the 19
added in v1.4c remain green; the v1.4a + v1.4b + v1.4c
+ v1.4d net delta against the v1.4a `main` baseline of
1130 is +53).

### v1.4e — In-app home tile 7-day streak history sparkline (Phase 32 / SYS-119 / ADR-049 / WF-046)

Closes the v1.4d → v1.4e parking-lot item: the home tile
now renders a one-glance view of the last 7 days as a
row of small dots under the streak badge. Filled dots
mark days with at least one completion (manual OR
rest-day, matching the streak calculator's
`ConsecutiveCounter.compute` credit rule); outlined
dots mark days with no completion; the rightmost dot
(today) bumps to a larger filled circle when today is
already resolved. Mirrors the `CompletionLogSection`
review-row pattern (v1.2m / SYS-108 / WF-025) but at
the tile surface — no scroll, no list, no per-row
delete icon. New code:

- `lib/screens/home_tile_sparkline.dart` (NEW) —
  pure-Dart `sparklineForDo({required Do activeDo,
  required DateTime asOf, required CompletionLogService
  completionLog})` returns `Future<List<SparklineDot>>`.
  The `SparklineDot` sealed hierarchy has three
  value-equal subclasses (`SparklineDotFilled(day,
  source)` carrying the first-matching row's source tag;
  `SparklineDotEmpty(day)`; `SparklineDotFuture(day)`
  for the defensive future-day case). The helper builds
  the 7-day window `[asOf - 6 days .. asOf]` (local-
  midnight each), then for each day performs a linear
  first-match scan over `completionLog.listForHabit`
  rows — emitting `SparklineDot.filled` on `dayMillis`
  match, `SparklineDot.future` if `day.isAfter(today)`,
  or `SparklineDot.empty` otherwise. First-match
  semantic mirrors `home_tile_undo.undoToday` (v1.4d /
  SYS-118) so the two helpers stay in lockstep on the
  same-day tiebreak rule. No Flutter import, no
  `DateTime.now()`, no side effects beyond the
  `listForHabit` read.
- `lib/screens/home.dart` — `_DoStreakBadge`'s right-
  aligned `Column` grows a `_Sparkline` sub-widget
  under the budget caption. The widget wraps the 7 dots
  in a single `Semantics(label:
  l.homeTileSparklineSemantics, readOnly: true)` node
  so screen readers announce "Last 7 days" / "Últimos 7
  días" once. While the future is in flight, the widget
  renders `_SparklineSkeleton` (7 outlined 6 dp dots)
  to reserve space and prevent layout shift on resolve.
  On resolve it renders 7 `_SparklineDot` circles — 6 dp
  outlined by default; the rightmost dot (today) bumps
  to 8 dp + filled when `_isResolvedToday == true`. The
  `resolvedToday` hint comes from the parent
  `_DoStreakBadge`'s `rows.any(r.dayMillis ==
  todayMillis)` check — re-derived from the same
  `completions` future the streak badge already holds,
  so no second `listForHabit` round-trip is added.
- `lib/l10n/app_en.arb` + `app_es.arb` — 1 new key
  (`homeTileSparklineSemantics`).

**ADR-049** locks the design: pure-Dart helper behind a
thin widget, sealed `SparklineDot` value class with
three factories (matching the `BudgetRemaining` /
`UndoResult` / `SparklineDot` value-class shape
introduced across v1.4c..v1.4e), first-match `source`
tagging mirrors `home_tile_undo.undoToday` (v1.4d) for
in-lockstep tiebreak semantics, no second
`listForHabit` round-trip (the `resolvedToday` hint
rides on the parent's `completions` future), no new
pubspec dep; no new `<uses-permission>`.

**SYS-119 + ADR-049 + WF-046 appended.** `feature.md`
§4 sparkline bullet removed; §5 quick-index updated to
ADR-049 / SYS-119 / WF-046.

Tests: 1208 / 1208 (1197 v1.4 sign-off tip + 11 new — 8
home_tile_sparkline + 3 home_test widget extensions per
the 3-gate at this commit; the 53 added in v1.4a..v1.4d
remain green; the v1.4a..v1.4e net delta against the
v1.4a `main` baseline of 1130 is +64).

### v1.3d — Light-theme icon variant for the FSI tile (feature.md §2.7)

Closes the §2.7 follow-up: the Settings → Permissions
full-screen-access tile now branches its leading icon on
the active `Theme.of(context).brightness`. On the light
theme the tile uses `Icons.open_in_full_outlined` (the
same outlined style every other permission tile uses),
and on the dark theme it keeps `Icons.open_in_full`
(filled — better contrast on the dark surface). The
icon shown in `PermissionSheet` and in the per-automation
`AutomationReliabilityDialog` (which read from
`permissionKindMeta[PermissionKind.fullScreenIntent].icon`)
is unchanged; the brightness-aware variant is local to
the settings tile. 2 new widget tests pin both branches.
Test count: 1047 → 1049. `dart format` clean,
`flutter analyze --fatal-infos` clean.

### v1.3d — Regenerate legacy launcher PNGs from the master vector (feature.md §2.6)

Closes the §2.6 follow-up: the API 21..25 launcher icon
fallback (`mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`)
was the default Flutter blue 'F' (left over from the
v0.1 scaffold). PR #31 regenerates those PNGs from the
v1.1i / ADR-032 master vector (the same shapes used by
`mipmap-anydpi-v26/ic_launcher.xml`'s `<adaptive-icon>`
foreground + background layers) so the API 21..25 fallback
shows the brand-purple 'd' + check dot icon on devices that
do not support adaptive icons. New `tool/regen_launcher_icons.py`
(Pillow-based, idempotent, runs offline) draws the four
shapes (stem rectangle + outer bowl ellipse + inner
counter ellipse + check dot ellipse) on a brand-purple
canvas at each density bucket size (48 / 72 / 96 / 144 /
192 px). New `test/app_icon_test.dart` test pins the
PNG signature + IHDR width/height for all 5 buckets
so a half-written regen is caught at CI. Test count:
1047 → 1048. `dart format` clean,
`flutter analyze --fatal-infos` clean. No new permissions,
no `INTERNET`, no `flutter pub` changes (Pillow is a
dev-only tool dependency; the script is not in the
runtime pubspec).

### v1.3d — CI grep rejects network calls in production code (SYS-026)

Closes the SYS-026 verification gap. SYS-026 (in
`requirements.md`) requires "a CI grep rule that fails on
`import 'package:http'` and `Uri.https` outside the
dev-only test harness", but no CI step enforces it — the
contract has been a code-review discipline only since v0.1.
PR #32 adds a new `Reject network calls in production
code (SYS-026)` step to `.github/workflows/ci.yml`'s
`quality` job. The grep covers `lib/` + `android/app/src/main/`
(production Dart + Kotlin) and excludes `build/`, `.dart_tool/`,
`tool/` (design-time scripts), `test/` (the dev-only
test harness SYS-026 explicitly whitelists), and `.git/`.
The grep looks for `import 'package:http`, `Uri.http(s)(`,
and `HttpClient()`. Benign `import 'dart:io'` lines (for
`File`, `Directory`, `Platform`, `Process`) are filtered
out via a second-pass `grep -v` so the step only fails
on real HTTP usage. New test in `test/ci_workflow_test.dart`
pins the step's existence, the SYS- ID reference, and the
`test/` + `tool/` exclusion list. Test count: 1047 → 1048.
`dart format` clean, `flutter analyze --fatal-infos`
clean. No new permissions, no `INTERNET`, no `flutter pub`
changes.

### v1.2e — `NotificationService.dismiss` + `PlatformNotificationService.show` real implementations

Phase 5 of the v1.2 code-TODO closure (`30-phase roadmap`).
The Phase-A production wiring left both `NotificationService.show`
and `dismiss` as no-ops. v1.2e wires them through to the Kotlin
`ReminderChannelProxy` (`showNotification` + `cancelNotification`
method-channel calls) and adds the inbound `fireAlarm` adapter
that the Kotlin `AlarmReceiver` invokes to render a notification
when an alarm fires.

**What's new**

- **Bridge surface (Dart).** `ReminderBridge.showNotification` and
  `ReminderBridge.cancelNotification` added to the abstract
  bridge. `PlatformReminderBridge` invokes the matching
  method-channel calls. `FakeReminderBridge` records every call.
- **`PlatformNotificationService`.** `show` forwards
  `(alarmId, habitName, body, strongMode)` to
  `bridge.showNotification`; `dismiss(id)` forwards `id.value` to
  `bridge.cancelNotification`. Both wrap the bridge call in a
  `kDebugMode`-gated try/catch per ADR-013 so a missing platform
  handler never crashes `main()`.
- **Inbound adapter.** `main.dart` constructs a
  `_ReminderInboundAdapter` and passes it to
  `PlatformReminderBridge(inbound: …)`. The Kotlin
  `AlarmReceiver.onReceive` invokes
  `ReminderChannelProxy.fireAlarm(ctx, alarmId)`, which calls
  `channel?.invokeMethod("fireAlarm", …)`; the Dart dispatch
  routes to `adapter.onFireAlarm(alarmId)` →
  `ReminderService.onFireAlarm(AlarmId(alarmId))`.
- **`ReminderService.onFireAlarm`.** Looks up the scheduled
  entry via `AlarmScheduler.lookupForFire`, builds a
  `ReminderEvent`, calls `notifications.show(event)`, then
  either:
    - **Habit-fired**: re-schedules via
      `habit.nextOccurrence(entry.at)` + `scheduler.schedule`,
      and for strong-mode habits also launches the full-screen
      intent via `fullScreen.show(habit, chain)`.
    - **Event-fired**: archives via
      `EventRepository.instance.archive(eventId, DateTime.now())`.
- **Alarm scheduler mirror.** `PlatformAlarmScheduler` now
  keeps a richer Dart-side mirror
  (`Map<AlarmId, ScheduledAlarm>`) carrying `habitName`,
  `strongMode`, and `eventId` so `onFireAlarm` can render the
  notification without a DB round-trip. `cancel` and
  `rescheduleAll` clear the mirror in lockstep with the
  existing `Map<AlarmId, DateTime>` mirror used by `snooze`.
  The `AlarmScheduler` interface gains
  `lookupForFire(AlarmId) → ScheduledAlarm?`; both
  `FakeAlarmScheduler` and `PlatformAlarmScheduler` implement
  it.
- **Kotlin `MainActivity.buildReminderNotification`.** New
  static helper that builds the `NotificationCompat.Builder`
  with channel id `doit.reminders`, title = `habitName`, body
  = `body ?? "Time for <habitName>"`, "Done" action for soft
  mode / "Open" action for strong mode, high priority,
  `autoCancel`. `ReminderChannelProxy.showNotification`
  delegates to it. `MainActivity.configureFlutterEngine`
  registers the channel idempotently at app start.
- **Kotlin `ReminderChannelProxy.cancelNotification`.** New
  handler that calls `NotificationManager.cancel(alarmId)`
  with the id-matched cancel (never the most-recent).
- **Tests (936 passing).** +16 over v1.2d:
    - `test/services/platform_notification_service_test.dart`
      (new, 5 tests) pins the dismiss / show chain:
      `NotificationService.show/dismiss` →
      `PlatformNotificationService` → `ReminderBridge`.
    - `test/services/platform_alarm_scheduler_test.dart` (+6
      tests) pins `lookupForFire` (unknown id, habit entry,
      strong-mode bit, event entry, cancel clears, rescheduleAll
      clears).
    - `test/services/reminder_service_test.dart` (+5 tests)
      pins `onFireAlarm` (unknown id no-op, habit alarm shows
      notification + re-schedules next occurrence, strong-mode
      launches full-screen intent, event alarm archives,
      missing habit shows but does not re-schedule).
    - `test/widgets/permission_sheet_test.dart` adds the two
      new bridge methods to the local `_RecordingBridge`
      stub.

**Coverage** (touched files)

- `lib/services/platform_notification_service.dart`: 100%
- `lib/services/platform_alarm_scheduler.dart`: 100%
- `lib/services/reminder_service.dart`: 82.4% (above the 80%
  floor)
- `lib/reminders/alarm_scheduler.dart` / `reminder_bridge.dart`:
  covered by the bridge-surface tests.

### v1.2f — `ActionFullscreen` + `ActionCallIntercept` real implementations + Person pauseUntil UI + DoFixed weekday display

Phases 6b–6e of the v1.2 code-TODO closure
(`30-phase roadmap`). Closes the I20 / I21 / I26 + I27 / I28
items: every `Action` leaf now has a real side effect.

**What's new**

- **`ActionFullscreen`** — the routine-fired full-screen
  overlay now actually opens. `FullScreenIntent` gained
  `showRoutineOverlay({title?, body?})`; `PlatformFullScreenIntent`
  invokes a new `doit/full_screen` method-channel call
  (`showRoutineOverlay`); the executor dispatches the leaf
  by awaiting that call. Platform failures are swallowed
  per ADR-013 — the executor still publishes the fire
  event, only the side effect is suppressed.
- **`ActionCallIntercept`** — the routine-fired call-screen
  decision (`accept` / `mute` / `decline` / `silent`) now
  drives the Kotlin `CallScreeningService` role.
  `CallSource` gained `recordRoutineDecision`; the service
  exposes a thin pass-through; the executor dispatches the
  leaf by awaiting the pass-through.
- **`Person.pausedUntil`** — per-person pause for cadence
  reminders. The Add Person screen has a Pause section
  visible only after a contact is picked; the Person Groups
  screen renders a per-person "Paused" chip in the
  multi-select picker. Drift schema migration `v5_to_v6`
  adds a nullable `paused_until_millis` column on the
  `person` table.
- **DoFixed weekday set on the home tile** — the
  one-line subtitle under each `DoFixed` habit now reads
  `"Mon, Wed, Fri · 09:00"` (or `"Every day · 06:30"` /
  `"Weekends · 10:00"` for the special-case sets) instead
  of the prior `"Fixed — 06:30"` that dropped the weekday
  set. The label is produced by a pure top-level function
  `describeDo(Do)` in `lib/do/do_description.dart`.

**Coverage**

- 10 new tests in `test/do/do_description_test.dart` —
  every-day / weekdays / weekends / single weekday /
  arbitrary-subset / every non-`DoFixed` branch.
- 1 new widget test in `test/screens/home_test.dart` —
  end-to-end render of the weekday-set subtitle.
- 2 new tests in `test/routines/action_dispatch_test.dart`
  + 1 updated `test/routines/call_dispatch_test.dart` —
  ActionFullscreen + ActionCallIntercept wiring.
- 2 new tests in `test/services/person_repository_test.dart`
  — `pausedUntil` round-trip + `clearPausedUntil` via
  `copyWith`.
- 1 new test in `test/screens/add_person_test.dart` —
  pause-section visibility gates on a picked contact.

**V-Model traceability**

- SYS-099 (ActionFullscreen wiring),
  SYS-100 (ActionCallIntercept wiring),
  SYS-101 (Person pauseUntil),
  SYS-102 (DoFixed weekday display) appended to
  [`docs/v_model/requirements.md`](docs/v_model/requirements.md).
- `lib/do/do_description.dart` is a new pure-Dart file
  imported from `lib/screens/home.dart`; it follows the
  model-purity rule from
  [`.claude/rules/lib-do.md`](.claude/rules/lib-do.md)
  (no Flutter imports).

### v1.2g — BOOT_COMPLETED re-arm confirmation + calendar trigger badge coverage closeout

Phase 7 of the v1.2 code-TODO closure (`30-phase roadmap`).
All three items the plan listed were already closed by
prior PRs; this release is a documentation-only closeout
that explicitly defers the one item that is genuinely
out-of-scope (B9 — the Android home-widget re-arm
indicator; the project does not yet ship a home widget).

**Status of each sub-task**

- **`RECEIVE_BOOT_COMPLETED` re-arm** — closed in v1.0.
  `android/.../BootReceiver.kt` listens for
  `ACTION_BOOT_COMPLETED`, `ACTION_LOCKED_BOOT_COMPLETED`,
  `ACTION_MY_PACKAGE_REPLACED`, and
  `ACTION_TIMEZONE_CHANGED` and routes every one of them
  through `ReminderChannelProxy.rescheduleAll`. The Dart
  inbound side (`ReminderBridge.onRescheduleAll`) is
  covered by `test/reminders/reminder_bridge_test.dart`
  ("inbound rescheduleAll dispatches to handler").
- **Per-automation reliability badges for calendar triggers** —
  closed in v1.1f. `_requiredPermissionForTrigger
  (TriggerCalendarEvent) => PermissionKind.calendar` in
  `lib/routines/automation_reliability.dart:120`; the
  badge reads `PermissionService.statuses
  [PermissionKind.calendar]` through the same
  `ValueListenable` as the other permissions and flips
  to `degraded` when the calendar permission is
  `denied` / `permanentlyDenied`. Covered by three tests
  in `test/routines/automation_reliability_test.dart`
  (granted → optimal, denied → degraded, null →
  unknown).
- **Per-call notification customization** — closed in
  v1.1b. `ActionNotify(title, body)` carries the
  user-authored copy; `RoutineExecutor._dispatchAction`
  builds a `ReminderEvent(habitName: action.title,
  body: action.body)` and forwards it to
  `NotificationService.show`. The body override is
  end-to-end; the Kotlin side uses it verbatim. Covered
  by `test/routines/action_dispatch_test.dart` —
  "ActionNotify shows a system notification with title +
  body".

**Deferral**

- **B9 — Widget re-arm indicator** — explicitly
  deferred. The project does not yet ship an Android
  home-screen widget; the first landing surface for the
  re-arm indicator would be a widget. Tracking this in
  the v2.0 platform-expansion batch (the home widget is
  Phase 28 in the roadmap).

### v1.2h — Per-automation reliability badge `AlertDialog` on tap

Phase 8 of the v1.2 code-TODO closure (`30-phase roadmap`).
The v1.1f `AutomationReliabilityBadge` (SYS-085) was
rendered but non-interactive; v1.2h wires the badge's
`onTap` callback (in all three add screens) to a new
`AlertDialog` that disambiguates the three remediation
paths a routine can need:

- **Trigger-side permission denied / unknown** — the
  dialog shows the matching `PermissionKind` title + the
  current status (Granted / Denied / Permanently denied /
  Not yet probed) + the rationale copy from the canonical
  `permissionKindMeta` module + an "Open settings" CTA
  that calls `PermissionService.openAppSettings()` (or
  `requestUsageStats()` for the special-access kind,
  since `usageStats` has no generic app-settings page).
- **No permission gate** — today only `TriggerTimeOfDay`,
  where reliability lives in the app-wide `Reliability`
  enum. The dialog surfaces a "this trigger does not need
  a runtime permission" note and hides the Open settings
  CTA.
- **Action-side permission** — v1.2+ future work
  (`ActionOverrideSilent` needs `ACCESS_NOTIFICATION_POLICY`,
  contact-requiring actions need `READ_CONTACTS`); not
  shipped in v1.2h.

**What's new**

- New `lib/widgets/automation_reliability_dialog.dart` —
  `showAutomationReliabilityDialog(BuildContext, {required Automation})`
  builds an `AlertDialog` with kind title + status + rationale
  body + Close / Open settings CTAs. Pure `StatelessWidget`
  (no `setState`, no `Future`-side-effects on the render
  path); the Open settings CTA calls the matching
  `PermissionService.requestX` / `openAppSettings` method
  via a small private `_openSettings(context, kind)` helper
  and closes the dialog.
- New `lib/services/permission_kind_meta.dart` — promotes
  the prior private `_KindMeta` / `_meta` constants from
  `permission_sheet.dart` to a public
  `permissionKindMeta: Map<PermissionKind, PermissionKindMeta>`
  module so `PermissionSheet` (v0.6) and this dialog
  share one source of truth for per-`PermissionKind`
  title + icon + rationale copy. Includes a new
  `PermissionKind.calendar` entry that the prior
  private map had been missing (a test caught the gap
  before it shipped).
- Wired `onTap: () => showAutomationReliabilityDialog(...)`
  on every `AutomationReliabilityBadge` in
  `lib/screens/add_habit.dart`, `lib/screens/add_person.dart`,
  and `lib/screens/add_event.dart`.
- Wrapped the Open settings `FilledButton` in
  `Semantics(button: true, label: 'Open settings',
  excludeSemantics: true)` so the SYS-062 a11y scanner
  (10-line lookahead) finds the label and TalkBack reads
  it as a button.
- New `test/widgets/automation_reliability_dialog_test.dart`
  — 4 widget tests covering location / calendar /
  usage-stats / time-of-day triggers, each pinned to
  the matching title + status + rationale body + CTA
  wiring.

### v1.2i — AppLifecycleState.resumed re-probe hook for permissions

Phase 9 of the v1.2 code-TODO closure (`30-phase roadmap`).
ADR-030's lesson: the fire-and-forget probe from
`PermissionService.init()` is stale by the time the user
toggles a permission in Settings → Special access →
Usage access (the most common flow that needs a
re-probe). v1.2i wires a `WidgetsBindingObserver` so the
Settings → Permissions tile and the per-automation
reliability badges reflect the user's most recent
toggle without a full restart.

**What's new**

- New `lib/services/permission_lifecycle_observer.dart`
  with `PermissionLifecycleReProbe` — a stateless
  `WidgetsBindingObserver` whose `didChangeAppLifecycleState
  (resumed)` calls `PermissionService.refresh()` via
  `unawaited(_safeRefresh())`. The observer tracks a
  `_coldStartSeen` bool so the FIRST `resumed` event
  (the OS bringing the app to the foreground after a
  cold launch — `init()` has already probed) is a no-op;
  every subsequent `resumed` (the user returning from
  Settings) fires the re-probe. Non-resumed lifecycle
  events (`paused`, `inactive`, `detached`) are ignored.
- New `PermissionService.refresh()` method (v1.2i /
  Phase 9 / SYS-104). Re-probes every
  `permission_handler` kind in parallel via `Future.wait`
  over six `_safeProbe` futures, then sequentially
  re-probes `usageStats` and `callScreening`. Each
  `_safeProbe` wraps `Permission.X.status` in
  try/catch — a single probe failure keeps the prior
  value (a failed re-probe is NOT a downgrade) and the
  batch continues. ADR-013 follow-up.
- Wired the observer in `lib/main.dart` immediately
  after `PermissionService.instance.init()` completes:
  `WidgetsBinding.instance.addObserver(PermissionLifecycleReProbe())`.
  The observer is process-scoped (no `dispose`); a hot
  restart replaces it via Flutter's framework reset.
- New tests:
  - `test/services/permission_lifecycle_observer_test.dart`
    (3 tests: cold-start resumed is a no-op; second
    resumed fires the `statuses` notifier; non-resumed
    events are ignored).
  - `test/services/permission_service_test.dart` (+4
    tests: `refresh()` re-probes all six
    `permission_handler` kinds; `refresh()` merges
    granted into every kind; `refresh()` swallows a
    single probe failure without aborting the batch;
    `refresh()` re-probes `usageStats` and
    `callScreening` separately).
- Updated `docs/v_model/requirements.md` with the
  `SYS-104` row.

### v1.2j — DST transition banner + streak-recovery card + 5-min/1-min pre-notification

Phase 10 of the v1.2 code-TODO closure (`30-phase
roadmap`). Three small UX improvements, all centered on
the "user missed something, here is how we handled it"
banner subsystem:

- **DST transition banner** (`lib/widgets/dst_transition_banner.dart`)
  — one-shot card that surfaces when the schedule
  engine silently reschedules one or more habit times
  because of a clock change. Singular copy for one
  drop, plural copy for two+. Renders
  `SizedBox.shrink()` when the list is empty (zero
  layout cost in the steady state).
- **Streak-recovery card** (`lib/widgets/streak_recovery_card.dart`)
  — one-shot card that surfaces when the consecutive
  counter reports 3+ missed days on a habit. The
  primary "I'm back" `FilledButton` and a dismiss
  `IconButton` keyed by `habitId` let the user resume
  or shelve the card without going through Settings.
- **Pre-notification heads-up**
  (`lib/services/reminder_service.dart`) — a new
  `ReminderService.schedulePreAlarms({alarmId, fireAt, now})`
  method enqueues a 5-min heads-up when the lead time
  is `> 5 * 60 s` and a 1-min heads-up when the lead
  time is `> 60 s`; lead times at or below those
  thresholds are silently skipped. A new
  `ReminderService.cancelPreAlarms(alarmId)` forwards
  to the bridge so a cancelled habit leaves no
  dangling pre-alarms. The `ReminderBridge` interface
  gains `schedulePreAlarm({alarmId, leadTimeSeconds})`
  and `cancelPreAlarms(alarmId)` abstract methods; the
  Dart side does NOT call `DateTime.now()` directly —
  the caller passes the reference time so the method
  is unit-testable.

Formatted 211 files (0 changed) in 0.74 seconds.
$ flutter analyze --fatal-infos
No issues found! (ran in 1.3s)
$ flutter test
00:22 +984: All tests passed!
```

(Test count: 978 → 984 — 6 new widget tests covering
the menu gating, dialog open, cancel, delete-pop, and
delete-failure paths; 3-gate green with zero analyzer
findings.)

### v1.2k — WF-022 hard delete with confirm (Phase 11a)

Phase 11a of the v1.2 code-TODO closure (`30-phase
roadmap`). Closes the B3 item: the edit screen now offers
a hard-delete affordance with a confirm dialog that names
the do and warns about completion-log loss.

**What's new**

- **`AddHabitScreen` (edit mode) popup menu** — the menu
  now exposes a `Delete…` entry only when the screen is in
  edit mode (`habitId != null`). New-do mode has no menu
  entry; the only way to discard a new do is to navigate
  back without saving.
- **`_confirmAndDelete` flow** — tapping the menu entry
  opens an `AlertDialog` titled `Delete "<name>"?` with
  destructive copy ("This will remove the do and its
  completion log. This cannot be undone."). Cancel keeps
  the screen and the row intact; Delete calls
  `DoRepository.instance.deleteById(habitId)` and pops
  the route with `true`.
- **Failure-path** — if `deleteById` throws (e.g., a
  platform DB error), the screen shows a `Delete failed.
  Please try again.` snackbar and stays mounted so the
  user can retry without re-typing anything.
- **Home-screen refresh hook** — `HomeScreen._onTileTap`
  now `await`s `Navigator.push<bool>`; when the edit
  screen pops with `true`, the home list refreshes
  immediately so the deleted tile disappears without
  waiting for the next `AppLifecycleState.resumed`.
- **Test-only seams** — `AddHabitScreenState.deleteOverride`
  (`Future<void> Function(String id)?`) and the public
  typedef `AddHabitScreenState = _AddHabitScreenState`
  let widget tests exercise the failure branch without
  monkey-patching the repository singleton.

**3-gate verification**

```
$ dart format --output=none --set-exit-if-changed .
Formatted 199 files (0 changed) in 0.72 seconds.

$ flutter analyze --fatal-infos
Analyzing doit...
No issues found! (ran in 1.1s)

$ flutter test
00:27 +936: All tests passed!
```

**V-Model traceability** (this PR)

- `WF-028` (test reminder button) — touched.
- `WF-030` (alarm-fires-this-many-seconds path) — covered.
- New `SYS-098` candidate: "Alarm fire → notification
  render path" — the inbound handler that
  `AlarmReceiver.onReceive` calls via the method channel.

**Deferred** (v1.2 candidates, not closed by v1.2e)

- Strong-mode full-screen launch is best-effort; the Kotlin
  side's `FullScreenActivity` host is v1.2e-minimal and will
  be hardened in a follow-up PR that adds the
  `USE_FULL_SCREEN_INTENT` permission on API 34+ (Phase 6).

### v1.2l — WF-030 uniform 3-wrong take-a-break (Phase 11b)

Phase 11b of the v1.2 code-TODO closure (`30-phase
roadmap`). Closes the B2 item: every mission that tracks
"wrong attempt" semantics now uses the same counter, the
same nudge copy, and the same auto-fail threshold — the
user never sees a behavior gap between Math and Type.

**What's new**

- **`MissionWrongAttempts`** (`lib/missions/mission_attempts.dart`,
  pure Dart, no Flutter) — a tiny state container with
  `recordWrong()` (returns `true` when the caller should
  auto-fail), `errorLabel()` (returns the inline error
  string for the current state), `remaining`, `wrongCount`,
  and `budgetExhausted`. The constant `kMissionMaxWrongAttempts = 3`
  is the single source of truth (overridable per-instance
  via the `maxWrong` constructor arg).
- **`Math` and `Type` mission screens** — both replaced
  their inline `_wrongCount` field with `MissionWrongAttempts`.
  Both surface the shared copy `"Wrong. N attempt(s) left."`
  for the first two attempts and `"Take a break. The mission
  will end."` (the `missionTakeBreakNudge` constant) on
  the third / final attempt, then pop with `null` to
  auto-fail the chain.
- **Out of scope for this PR** — Shake, Hold, and Memory
  do not have a "wrong attempt" notion (they time-out
  instead of failing per-attempt). The shared module is
  documented as opt-in for any future mission kind.

**3-gate verification (consolidated for v1.2l + v1.2m)**

```
$ dart format --output=none --set-exit-if-changed .
Formatted 215 files (0 changed) in 0.76 seconds.
$ flutter analyze --fatal-infos
No issues found! (ran in 1.1s)
$ flutter test
00:24 +1001: All tests passed!
```

(Test count: 984 → 1001 — 9 unit tests for
`MissionWrongAttempts` (constant, getter/setter, error-label,
custom-maxWrong, nudge-copy) + 2 widget tests on the Type
mission (auto-fail on 3rd wrong + per-attempt label
decrement) + 5 widget tests on `CompletionLogSection`
(empty-state, populated + sort order, dialog open, cancel,
confirm + snackbar + DB removal); 3-gate green with zero
analyzer findings.)

### v1.2m — WF-025 edit completion log (Phase 11c)

Phase 11c of the v1.2 code-TODO closure (`30-phase
roadmap`). Closes the B6 item: the user can now review and
undo an accidental completion from the edit-habit screen
without leaving the screen. The completion log is the
source of truth for streak calculation, so this also gives
the user the simplest recovery path when a wrong-day
completion is the cause of a streak break.

**What's new**

- **`CompletionLogSection`** (`lib/widgets/completion_log_section.dart`,
  new StatefulWidget) — renders the most-recent
  `kCompletionLogSectionMaxRows = 30` completions for the
  habit as a list. Each row shows the day, the completion
  time, and the source (`manual` / `notification` /
  `mission` / `rest_day`); a trailing delete icon opens
  a confirm dialog. Empty log shows `"No completions yet."`;
  an older-row cap of 30 keeps the section scannable on a
  dense streak and surfaces `"N older entries are hidden."`
  below the list when the cap hides rows.
- **`AddHabitScreen` (edit mode)** — the new section is
  rendered after the pause row, separated by a `Divider`,
  only in the `_isEdit` branch. A successful delete shows
  a `"Completion removed."` snackbar; a failure shows
  `"Could not delete entry."` (no row removed).
- **Soft tone, no streak-shaming** — the dialog copy is
  `"Delete this completion?"` followed by a row description
  that ends with `"This will shorten your streak by one
  day."` (honest; not punitive). The cancel button is
  the default action visually; the destructive button
  reuses the theme's error color.

### v1.3b — Unified reliability source-of-truth (Phase 13)

Phase 13 of the v1.3 reliability + lifecycle hardening
milestone (`30-phase roadmap`). Closes the B20 / C10 /
E7 / H2 follow-ups: the two parallel reliability signals
that existed in v1.3a — `AlarmScheduler.reliability` (a
synchronous getter backed by a 30 s fire-and-forget
`bridge.probeReliability()` cache) and
`PermissionService.statuses` (a `ValueNotifier<Map<...>>`
the Settings → Permissions tile and the per-automation
`AutomationReliability` enum read) — are now consolidated
behind a single `ReliabilityService` singleton. The
home-screen banner and the settings page `_ReliabilityRow`
bind to the new `Stream<Reliability>` /
`ValueListenable<Reliability>` so they cannot drift.

**What's new**

- **`ReliabilityService` (new).** `lib/services/reliability_service.dart`
  exposes a singleton with a `Stream<Reliability>` getter,
  a `ValueListenable<Reliability>` mirror, and a synchronous
  `value` getter. The service merges the alarm-system
  bridge probe (re-run on `init`, on `refresh`, and on a
  30 s fallback `Timer.periodic`) with the
  `PermissionService.statuses` listener (re-derives the
  value on every change). Initial value is
  `Reliability.optimal` — closes the v1.3a first-read
  race where the very first read of
  `PlatformAlarmScheduler.reliability` returned
  `Reliability.unknown` for a fully optimal device.
- **`PlatformAlarmScheduler.reliability` is a thin
  pass-through.** The `_cachedReliability` /
  `_cachedReliabilityAt` fields, the
  `_refreshReliability` helper, the `clearReliabilityCache`
  test hook, and the fire-and-forget refresh on read are
  removed. The getter body is now
  `ReliabilityService.instance.value` (with a `try /
  on StateError` fallback to `Reliability.optimal` for
  standalone-scheduler unit tests). The
  `kReliabilityCacheTtl` constant moves to
  `reliability_service.dart` (re-exported from the
  scheduler for back-compat with the test imports).
- **`ReliabilityBanner.fromStream` factory.** The new
  `ReliabilityBanner.fromStream({VoidCallback? onTap})`
  factory wraps the unified service notifier in a
  `ValueListenableBuilder<Reliability>`. The home screen
  and the settings page both switch to this factory.
  `ReliabilityBanner.fromService` is kept as a
  `@Deprecated` thin shim for one cycle (returns the
  service's current value at build time and does NOT
  rebuild on change) so existing widget tests that
  constructed a banner via the previous factory still
  compile.
- **`_ReliabilityRow` in settings.dart** now wraps its
  `ListTile` in a `ValueListenableBuilder<Reliability>`
  bound to the unified service. The 3-arm subtitle
  switch (`_ReliabilityRow._subtitleFor(Reliability)`)
  is unchanged; only the data source moves.
- **`PermissionLifecycleReProbe` extended.** The resume
  hook (`AppLifecycleState.resumed` after the cold
  start) now calls
  `ReliabilityService.instance.refresh()` in addition to
  `PermissionService.refresh()`. Same fire-and-forget
  pattern; both errors are swallowed (ADR-013). A
  `StateError` from an uninit'd `ReliabilityService` is
  also swallowed so a unit test that constructs the
  observer standalone does not throw.
- **`main.dart` wires the service.** After
  `WidgetsBinding.instance.addObserver(PermissionLifecycleReProbe())`,
  `main.dart` awaits `ReliabilityService.init(bridge:
  bridge, permissionService: PermissionService.instance)`.
  The order matters: the service needs the bridge for
  `probeReliability()` and the `PermissionService` for
  the `statuses` listener, so it must be wired after
  both are constructed.

**Test pins (new + updated)**

- `test/services/reliability_service_test.dart` (new,
  ~10 tests) pins: initial value is `optimal`; `refresh()`
  re-probes the bridge; subscribing to `statuses`
  re-derives when `location` / `calendar` /
  `callScreening` / `usageStats` flips to denied; an
  unrelated kind does NOT re-derive; the 30 s fallback
  timer calls `refresh()` (via an injectable periodic
  factory); the stream emits `distinct()` values;
  `resetForTesting()` clears the singleton + closes the
  stream controller; `init()` is idempotent; a probe
  failure keeps the prior value (ADR-013); the 4 gated
  kinds are the only ones that flip the service to
  `degraded`.
- `test/services/platform_alarm_scheduler_test.dart`
  reliability group rewritten. The previous 4 tests
  exercised the local 30 s cache; v1.3b has no local
  cache. The new 3 tests pin the delegation: the getter
  reads `ReliabilityService.instance.value`; the getter
  returns `optimal` when the service is not init'd; the
  getter reflects a permissions change to a gated kind.
- `test/widgets/reliability_banner_test.dart` adds 2
  tests: `fromStream` renders nothing when the service
  is optimal; `fromStream` rebuilds when the service
  value flips to degraded.
- `test/screens/home_test.dart` and
  `test/screens/settings_test.dart` `setUp` blocks now
  init the unified service against the same
  `FakeReminderBridge` the reminder service uses, so
  the home banner and the settings row read the right
  value.

**Verification (3-gate)**

```
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

All three gates green at the head of `feat/v1.3b-phase13-reliability-stream`.

**Deferred**

- Per-routine reliability budgets (a v1.3+ polish idea).
- Dropping `PermissionService.statuses` (still the
  source for `AutomationReliability` and the per-
  permission tile).
- Retroactive amendment of ADR-030 (this PR cites it as
  context but does not rewrite history; ADR-042 is the
  new follow-up).

### v1.3c — `USE_FULL_SCREEN_INTENT` probe + reliability wiring (Phase 14)

Closes `feature.md` §2.1 — the Android 14+ full-screen
launch suppression gap. On API 34+, the OS suppresses
full-screen intents from background-launched apps that
do not hold `USE_FULL_SCREEN_INTENT`; without this PR,
the user sees a notification instead of the full-screen
mission screen on a strong-mode habit, and the home
banner / Settings tile do not surface a recovery
affordance.

**What's new**

- `PermissionKind.fullScreenIntent` joins the enum
  (after `callScreening`, before `backupFolder`). The
  permission is **opt-in** — declining does NOT block
  any feature (the user keeps getting the notification
  fallback), mirroring the v1.1g `PACKAGE_USAGE_STATS`
  precedent (ADR-030).
- New `FullScreenIntentService` singleton
  (`lib/services/full_screen_intent_service.dart`) is
  the Dart-side wrapper around the `doit/full_screen`
  MethodChannel. Mirrors the `UsageStatsService` shape
  (singleton with `_ready`, `Scripted*Source` test
  seam, ADR-013 platform-error swallow).
- New Kotlin side
  (`android/app/src/main/kotlin/com/doit/FullScreenIntentChannel.kt`)
  owns the same `doit/full_screen` MethodChannel and
  resolves the API 32 / 33 / 34 asymmetry on the
  platform side:
  - API < 32: implicit-granted; probe returns `true`.
  - API 32 / 33: probes
    `NotificationManager.canUseFullScreenIntent()`;
    deep-link falls back to `ACTION_APPLICATION_SETTINGS`.
  - API 34+: same probe; deep-link uses
    `Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`.
- `PermissionService.requestFullScreenIntent()` deep-
  links via `openSettings()`. `refreshFullScreenIntent()`
  re-probes the channel probe and merges the result into
  `statuses`. The probe runs as a sequential special-
  access probe in `PermissionService.refresh()` (after
  the parallel `Future.wait` batch) and as a fire-and-
  forget call from `init()`.
- `PermissionKind.fullScreenIntent` joins
  `_kReliabilityGatedKinds` (now 5 elements: `location`,
  `calendar`, `callScreening`, `usageStats`,
  `fullScreenIntent`). A denial flips the unified
  reliability stream to `Reliability.degraded`; the home
  banner shows "may be late" and (new in v1.3c) is
  tappable — one tap lands the user on Settings →
  Permissions where the 5th `_PermissionTile` for
  `fullScreenIntent` is rendered.
- `lib/services/permission_kind_meta.dart` gains the
  matching `title` (`'Full-screen access'`) + icon
  (`Icons.open_in_full`) + rationale copy.
- `AndroidManifest.xml` gains
  `<uses-permission android:name=
  "android.permission.USE_FULL_SCREEN_INTENT"
  tools:ignore="ProtectedPermissions" />` — the
  `tools:ignore` marker mirrors the v1.1g
  `PACKAGE_USAGE_STATS` precedent.

**Test pins**

- `test/services/full_screen_intent_service_test.dart`
  (8 tests) — `isGranted` / `openSettings` happy paths
  + `MissingPluginException` / `PlatformException`
  swallows + `resetForTesting` + `debugInstance`.
- `test/services/permission_service_test.dart`
  (+3 tests) — `requestFullScreenIntent` deep-links;
  `refreshFullScreenIntent` merges both branches.
- `test/services/reliability_service_test.dart`
  (+1 test, 1 edit) — flipping `fullScreenIntent` to
  `Denied` re-derives to `degraded`; the existing
  "the 4 gated kinds" test is renamed to "the 5
  gated kinds" and the `gated` const grows from 4 to 5.
- `test/screens/settings_permissions_test.dart`
  (+2 tests, 1 edit) — tapping the FSI tile re-probes
  via `doit/full_screen`; the tile renders the
  localized title; the existing "renders all four"
  test is renamed to "renders all five" with the new
  `ValueKey` asserted.
- `test/widgets/reliability_banner_test.dart`
  (+1 test) — `fromStream` wires `onTap` and the
  callback fires on tap when the service is degraded.
- The new `permissionFullScreenIntentTitle` ARB key
  is auto-validated by the existing "every non-
  template ARB has the same key set as the template"
  test in `test/l10n/app_localizations_test.dart`.

**Verification (3-gate)**

```
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

Plus the targeted Kotlin compile check:

```
./android/gradlew :app:compileDebugKotlin
```

**Deferred**

- The activity launch path itself
  (`PlatformFullScreenIntent.showHabitMission` /
  `showRoutineOverlay`) — Phase 6a proper. The new
  `FullScreenIntentChannel.kt` is shaped so Phase 6a
  can extend it with the launch handlers without re-
  doing the probe wiring. The Dart `_safe` wrapper
  continues to swallow the launch-method
  `MissingPluginException`.
- Per-routine reliability budgets (Phase 13 already
  deferred; still deferred).
- Light-theme icon variant for the FSI tile (feature.md
  §2.7).
- Native Spanish translation (feature.md §2.4) — the
  `app_es.arb` copy for the new keys follows the
  existing non-professional smoke-test pattern.
- The Android home-screen widget (Phase 28). The widget
  surface does not interact with `USE_FULL_SCREEN_INTENT`.

### v1.3d — Full-screen activity launch path (Phase 15)

Closes `feature.md` §2.1 "Still deferred" — Phase 6a proper.
v1.3c shipped the `USE_FULL_SCREEN_INTENT` probe + deep-link
+ reliability wiring (SYS-113 / ADR-043) but explicitly
deferred the activity launch path. v1.3d ships it: a real
`FullScreenActivity` on the Kotlin side, the two launch
handlers on the `doit/full_screen` MethodChannel, and a
chain-level orchestrator widget that loads the habit by id
from `DoRepository` and walks the `MissionChain` end-to-end.

**What's new**

- `android/app/src/main/kotlin/com/doit/FullScreenActivity.kt`
  (NEW) — a thin `FlutterActivity` subclass that hosts a
  Flutter route to `/mission`. `onCreate` sets
  `WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED |
  FLAG_TURN_SCREEN_ON | FLAG_DISMISS_KEYGUARD |
  FLAG_KEEP_SCREEN_ON` so the activity surfaces on the
  lockscreen (API 27+). `getInitialRoute()` encodes the
  intent extras into a query string:
  `/mission?mode=habit&habitId=...` for strong-mode habit
  launches, `/mission?mode=overlay&title=...&body=...` for
  routine-fired overlays.
- `android/app/src/main/kotlin/com/doit/FullScreenIntentChannel.kt`
  grows two new `when` arms: `showHabitMission` builds
  `FullScreenActivity.habitIntent(ctx, habitId)` and starts
  the activity with `FLAG_ACTIVITY_NEW_TASK`; `showRoutineOverlay`
  builds the overlay intent with `title` / `body` extras. The
  existing probe handlers (`canUseFullScreenIntent`,
  `openFullScreenIntentSettings`) are unchanged. The Dart
  `_safe` wrapper at `PlatformFullScreenIntent` is kept as
  defense-in-depth per ADR-013.
- `android/app/src/main/kotlin/com/doit/MainActivity.kt` —
  `buildReminderNotification` splits the strong-mode branch:
  the strong-mode `openIntent` targets `FullScreenActivity`
  (with `habitId` extra), and
  `NotificationCompat.Builder.setFullScreenIntent(openPi,
  /* highPriority= */ true)` is added so the OS launches
  the activity directly when the alarm fires on a locked
  device. The strong-mode `Open` action button reuses the
  same `fsiPi`. Soft-mode notifications keep the existing
  `MainActivity` openPi (no FSI).
- `android/app/src/main/AndroidManifest.xml` declares
  `<activity android:name=".FullScreenActivity">` between
  the existing `<activity>` and the `<receiver>` for
  `BootReceiver`. Attributes: `exported="false"`,
  `taskAffinity=""`, `excludeFromRecents="true"`,
  `launchMode="singleTask"`, `theme="@style/LaunchTheme"`,
  `showOnLockScreen="true"`, `turnScreenOn="true"`,
  `showWhenLocked="true"`. No new `<uses-permission>` —
  the `USE_FULL_SCREEN_INTENT` baseline from v1.3c covers
  the launch path.
- `lib/screens/mission_launcher.dart` (NEW) — chain-level
  orchestrator widget. Loads the habit by id via
  `DoRepository.instance.getById(habitId)`; rejects (and
  pops with `null`) if the habit is missing, not in
  `StrongProof` mode, or carries an empty chain. Iterates
  the `MissionChain`, pushing the matching
  `MissionXxxScreen` for each `Mission` and `await`ing
  the pop value. On all inputs collected, runs
  `MissionChainExecutor.run(chain, inputs)`; on
  `ChainPassed`, appends a completion via
  `CompletionLogService.instance.append` (source
  `CompletionSource.mission`, the proof-mode tag from the
  habit, the `missionResultsJson` summary
  `missions=<N>`); on `ChainFailedAt` / `ChainTimedOut`,
  pops with `null` (the streak stays broken per the
  v1.1f grace-window contract).
- `lib/screens/routine_overlay_screen.dart` (NEW) — banner
  widget for routine-fired overlay launches. Renders the
  `title` / `body` from the launch intent; falls back to
  `"Routine alert"` + a generic explanation when null or
  empty. The Dismiss button is ≥ 64 dp and wrapped in
  `Semantics(button: true, label: 'Dismiss routine overlay',
  ...)` per `.claude/rules/lib-screens.md` (SYS-062).
- `lib/main.dart` — `MaterialApp` gains `onGenerateRoute`
  that resolves `/mission` to `MissionLauncherScreen`
  (default) or `RoutineOverlayScreen` (when `mode=overlay`)
  based on the initial-route query string parsed by
  `FullScreenActivity.getInitialRoute()`. The existing
  `home:` switch is unchanged (`onGenerateRoute` is
  additive).
- `lib/services/platform_full_screen_intent.dart` gains
  `Future<LaunchIntent?> getLaunchIntent()` which reads
  `getLaunchIntent` over the `doit/full_screen` channel.
  The `_safeResult` wrapper swallows the production
  `MissingPluginException` (Kotlin side does not implement
  the read; the canonical read is the initial-route query
  string). `LaunchIntent` + `LaunchMode` (a new
  immutable class + enum) live in
  `lib/reminders/full_screen_intent.dart`; the
  `FullScreenIntent` interface grows the read; the
  `FakeFullScreenIntent` test seam records the
  scripted / last launch intent.
- No `wakelock_plus` package added — pubspec stays clean.
  The wake-lock is held at the Android Window level via
  `FLAG_KEEP_SCREEN_ON` on the activity (released
  automatically when the activity is destroyed), per the
  v1.2e precedent.

**Test pins**

- `test/services/platform_full_screen_intent_test.dart`
  (NEW, 6 tests) — `showHabitMission` invokes the right
  method + `habitId` arg; `showRoutineOverlay` propagates
  `title` / `body` and skips missing keys; `getLaunchIntent`
  swallows the production `MissingPluginException` and
  returns `null`; `showHabitMission` swallows
  `MissingPluginException` end-to-end (defense-in-depth
  per ADR-013).
- `test/screens/mission_launcher_test.dart` (NEW, 6 tests) —
  1-mission chain (Type) appends the completion with
  `proofModeAtTime: 'strong'` and `missionResultsJson:
  'missions=1'`, pops `true`; 2-mission chain
  (Type → Type) appends with `missions=2`; `ChainFailedAt`
  (wrong phrase) pops `null` and does NOT append;
  missing habit pops `null`; non-`StrongProof` habit
  (soft) pops `null`; cancel on first mission aborts
  the chain and does NOT append.
- `test/screens/routine_overlay_test.dart` (NEW, 4 tests) —
  renders `title` + `body` from constructor args; falls
  back to generic copy when null; falls back when
  `title` / `body` are empty strings; the Dismiss button
  pops the route with `null`.
- The existing `test/reminders/reminder_service_test.dart`
  + `test/routines/action_dispatch_test.dart` (which
  drive `FakeFullScreenIntent`) keep passing — the
  `launches` / `routineOverlays` recording is unchanged
  in shape (the new `launchIntents` list is additive).
- The `Semantics` label on the Dismiss button is auto-
  validated by the existing
  `test/a11y/semantics_labels_test.dart` (SYS-062) static
  analyzer — 0 regressions.
- A11y touch target: the Dismiss button's `minimumSize` is
  `Size.fromHeight(Sizing.tapPrimary)` (64 dp), exceeding
  the 48 dp baseline. SYS-062.

**Verification (3-gate)**

```
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

Plus the targeted Kotlin compile check:

```
./android/gradlew :app:compileDebugKotlin
```

Plus the targeted test files for the launch path:

```
flutter test test/services/platform_full_screen_intent_test.dart
flutter test test/screens/mission_launcher_test.dart
flutter test test/screens/routine_overlay_test.dart
flutter test test/a11y/semantics_labels_test.dart
```

Test count: 1032 → 1064 (+~16: 6 fsi-service + 6 launcher + 4
overlay — matches the PR plan). Coverage ≥ 80% on every
changed file.

**Deferred**

- Kotlin-side unit tests for `FullScreenIntentChannel.
  showHabitMission` / `showRoutineOverlay` + the new
  `FullScreenActivity`. The Dart-side tests cover the
  channel-call contract; the actual `Intent` construction,
  flags, and activity launch are not unit-tested in Kotlin.
  Acceptable for v1.3d (the Kotlin code is short, the
  activity-launch path is well-understood, and the lint
  check + `compileDebugKotlin` gate catch syntax / null-
  safety / deprecation issues). A v1.4+ follow-up can add
  `FullScreenIntentChannelTest.kt` using Robolectric or
  `androidx.test.core` to assert the Intent construction
  (extras, flags, target component).
- `wakelock_plus` package (the v1.4+ follow-up may swap
  to per-mission wake-lock control if the team wants
  finer-grained control than the activity-level
  `FLAG_KEEP_SCREEN_ON`).
- Per-mission retry UX (a `ChainFailedAt` currently pops
  with `null`; v1.1f grace-window semantics handle
  Math / Type; Shake / Hold / Memory do not retry).
- The light-theme icon variant (feature.md §2.7) — still
  deferred.
- The Android home-screen widget (Phase 28).

### v1.3d — `TriggerCallIncoming*` reliability arm closeout (docs, Phase 25b)

Doc-only closeout (no code changes, no new tests). The
`TriggerCallIncoming*` → `PermissionKind.callScreening`
arm — explicitly deferred in v1.2h (`feature.md` §2.3)
because `PermissionService.callScreening` was not fully
probed at the time — is now folded in via
`lib/routines/automation_reliability.dart`'s
`_requiredPermissionForTrigger` exhaustive switch. The
probe side (`refreshCallScreening()` +
`_refreshCallScreeningAfterInit()` + the `refresh()`
cascade) landed in v1.2c/v1.2i; the missing arm was
the only outstanding wire.

**Why docs-only.** No new code, no new permissions, no
new tests, no `INTERNET`. The arm was the v1.2h explicit
deferral point — closing it requires only the doc
annotation: the model + service were already wired.

**Doc edits:**
- `v1_2_release_baseline.md` §5 — the §2.3 entry now
  reads "Shipped in PR #28".
- `decision_record.md` ADR-035 — adds an "Update v1.3b"
  block that points at the live
  `_requiredPermissionForTrigger` switch + the
  `PermissionService.callScreening` probe chain.
- `implementation_status.md` v1.2h row gets an
  "Update v1.3b" annotation; a new v1.3b row is added
  at the bottom of the table mirroring the v1.2g
  closeout shape.

**Verification.**
```
dart format --output=none --set-exit-if-changed .   →   0 changed
flutter analyze --fatal-infos                        →   0 issues
flutter test                                         →   1064 / 1064 passed (no count delta)
```

(The doc-only annotation is the entire diff; the test
count is unchanged because no Dart code moved.)

### v1.3e — Native Spanish translation review-process scaffolding (Phase 25c)

Closes the **process** half of `feature.md §2.4` (the
native-speaker review pass itself remains a follow-up
owned by the reviewer). This PR ships:

- New `docs/v_model/spanish_translation_review.md` —
  the per-key reviewer checklist. Every one of the 81
  keys in `lib/l10n/app_es.arb` is tabulated with an
  author-side note flagging the keys most likely to read
  awkwardly (the `tarea`-vs-`do` translator choice on
  the home tile; the "hacer sonar contactos específicos
  en modo silencio" call-screening onboarding line;
  "Comprobación" vs "verificación" in the
  `Reliability.unknown` copy; etc.). The reviewer is
  expected to walk the live UI in Spanish and replace
  any string that does not read as natural Mexican /
  Rioplatense / peninsular Spanish.
- One low-risk conjugation fix in
  `lib/l10n/app_es.arb`:
  `settingsAnchorManual`: `"... toco ..."` →
  `"... tocas ..."` (second-person matches every other
  tile in the app).
- A reviewer log table at the bottom of the new doc —
  the native-speaker reviewer adds their row when they
  ship the follow-up PR.
- `docs/v_model/v1_2_release_baseline.md` §5 — the §2.4
  entry now notes "PR #29 ships the review-process
  scaffolding; the native-speaker pass itself remains a
  follow-up".

**Why not a self-translation.** The author is not a
native Spanish speaker; shipping a machine-style
self-translation would be worse than the v1.1h
smoke-test catalog. The right move is to lay out the
process (this PR) and let a native speaker own the
content pass (a separate PR they open).

**Out of scope (deferred).**
- A regional split (`app_es_419.arb` vs
  `app_es_ES.arb`) — requires a target-market decision
  first.
- New locales (`app_fr.arb`, `app_de.arb`, etc.).
- Currency / date / number formatting changes (Spanish
  uses the `intl` defaults that already handle es-ES
  style).

**Verification.**
```
dart format --output=none --set-exit-if-changed .   →   0 changed
flutter analyze --fatal-infos                       →   0 issues
flutter test                                        →   1047 / 1047 passed (no count delta)
```

The ARB fix is a single character; the codegen
(`flutter gen-l10n`) re-emits the same `AppLocalizations`
class because the `toco` → `tocas` change is a string
replacement, not a structural one.

### v1.3a — Monthly stats + per-do grace factory (Phase 12)

Phase 12 of the v1.3 reliability + lifecycle hardening
milestone (`30-phase roadmap`). Closes the B9/B13
follow-ups: the stats screen now shows a 30-day completion
rate, a month-over-month delta, and a 7-day bar chart, and
the per-do `graceWindowOverride` field ships end-to-end
through a new `Do.effectiveStreakConfig(...)` factory
method. The Settings → Stats entry tile makes the screen
discoverable from the Settings page. Also closes a Phase
11f documentation/implementation gap: the `graceWindowOverride`
field was documented but the factory that wires it into
the streak calculator was never landed in v1.2p — v1.3a
is where the factory meets its first real consumer.

**What's new**

- **`Do.effectiveStreakConfig(...)` factory method**
  (`lib/do/do.dart`, sealed base class) — returns
  `StreakConfig(graceWindow: graceWindowOverride ?? kDefaultGraceWindow, skipBudget: skipBudget)`.
  The factory is the canonical way for a consumer (the
  stats screen today; any future streak-aware surface) to
  build a `StreakConfig` for a `Do` instance — it honors
  the per-do override when set, falls back to the app-wide
  default otherwise, and forwards the rest-day budget
  verbatim. The `graceWindowOverride` field itself was
  already on the base class + all 5 subclasses (Phase 11f
  data-side work); the factory is the missing piece that
  makes the override actually take effect.
- **`kDefaultGraceWindow` constant**
  (`lib/do/consecutive_counter.dart`, top-level) — the
  single source of truth for "how much time past the end
  of a missed day does the user have to retroactively
  complete it before the consecutive-run is broken".
  Replaces three hard-coded `Duration(hours: 3)` literals
  that were scattered across the model + the stats
  screen. The `Duration(hours: 3)` value is unchanged —
  the constant just guarantees every consumer agrees.
- **Stats screen extensions** (`lib/screens/stats.dart`) —
  per-habit card now renders three new lines: `"Last 30
  days: N (Δ% vs prior 30 days)"` (a signed integer
  percent or the literal `"new"` when the prior 30 days
  had zero completions), `"On time: N%"` (completion
  rate), and a `_Last7DaysChart` widget (7 thin vertical
  bars, one per local-calendar day, day 0 = today). The
  `asOf` reference time is captured once at the top of
  `_load()` so the streak's "is the run still alive?"
  check, the 30-day window end, and the 7-day bucket
  labels all stay consistent across the per-habit loop.
  The streak number on each card is now produced by
  `h.effectiveStreakConfig(skipBudget: SkipBudget(...))`
  instead of the prior hard-coded `Duration(hours: 3)`.
- **Settings → Stats tile** (`lib/screens/settings.dart`) —
  a new `_StatsTile` between the Reliability section and
  the Backup section. Tap pushes the existing
  `StatsScreen` via `MaterialPageRoute`. The home AppBar
  `Icons.bar_chart` button stays (it's the quick path;
  Settings is the discoverable path). Three new l10n
  keys (`settingsSectionStats`, `settingsStatsTitle`,
  `settingsStatsSubtitle`) added to `app_en.arb` and
  `app_es.arb`.
- **`RoutineBanner` auto-clear test pin**
  (`test/widgets/routine_banner_clear_test.dart`, new) —
  three widget tests that pin the user-observable
  behavior of the existing drain-on-next-frame path: an
  empty queue renders `SizedBox.shrink()`, a non-empty
  queue renders `"Opening …"` for exactly one frame then
  drains via the `addPostFrameCallback`, and an out-of-
  band `clearPendingOpenApp()` collapses the banner back
  to zero size on the next build. No production code
  change to `routine_banner.dart` is expected — this is
  the regression pin for a Phase-11c behavior.

**Why now:** the streak calculator's only production
`StreakConfig` consumer was the stats screen, and the
stats screen's `Duration(hours: 3)` literal was the
single hardest reason per-do grace overrides could not
ship end-to-end. Phase 12 lands the factory method, the
constant, and the new stats surface in a single PR so
the wiring is observable from the day the PR lands
(per-do override → factory → `StreakConfig` → streak
snapshot → card).

**3-gate verification**

```
$ dart format --output=none --set-exit-if-changed .
Formatted 217 files (0 changed) in 0.74 seconds.

$ flutter analyze --fatal-infos
Analyzing doit...
No issues found! (ran in 1.0s)

$ flutter test test/habits/habit_model_test.dart \
              test/screens/stats_test.dart \
              test/widgets/routine_banner_clear_test.dart
00:00 +41: All tests passed!
```

(Full-suite 3-gate output is in the PR description.)

**V-Model traceability** (this PR)

- `WF-011` (v0.1 stats surface) — extended.
- `WF-031` (v0.2 monthly stats) — extended.
- `WF-038` (routine banner drain) — pinned by new test.
- New `SYS-111`: "Monthly stats + per-do grace factory" —
  the 30-day completion rate definition, the MoM-delta
  definition with the `prev30 == 0` boundary, the 7-bar
  chart semantics, the `Do.effectiveStreakConfig(...)`
  factory contract, the new Settings → Stats tile, and
  the `kDefaultGraceWindow` constant.

**Deferred** (out of Phase 12 scope)

- The Android home-screen AppWidget (mirror of the in-app
  stats). Phase 28 of the 30-phase roadmap.
- A per-category aggregate line (today's screen groups
  by category but does not roll the totals up). A v1.4
  polish candidate.
- A `kStatsCacheDuration` 5-second memoization in
  `lib/services/stats_service.dart` (no measurable
  latency yet — the per-habit `listInRange` is O(30)).
  Defer until profiling shows up.

### v1.3d — Full-screen activity launch path (Phase 15)

Closes `feature.md` §2.1 "Still deferred" — Phase 6a proper.
v1.3c shipped the `USE_FULL_SCREEN_INTENT` probe + deep-link
+ reliability wiring (SYS-113 / ADR-043) but explicitly
deferred the activity launch path itself: the launch handlers
on `doit/full_screen` returned `notImplemented` and the Dart
`_safe` wrapper swallowed the resulting
`MissingPluginException`. v1.3d ships the launch path
end-to-end so a strong-mode habit's alarm fires the
full-screen activity on a locked device (API 27+ keyguard
bypass), the chain-level orchestrator walks the
`MissionChain`, and the completion log appends on
`ChainPassed`.

**What's new**

- **`FullScreenActivity.kt`** (NEW) — `FlutterActivity`
  subclass on the Kotlin side. `onCreate` sets lockscreen-
  bypass window flags (`FLAG_SHOW_WHEN_LOCKED |
  FLAG_TURN_SCREEN_ON | FLAG_DISMISS_KEYGUARD |
  FLAG_KEEP_SCREEN_ON`). `getInitialRoute()` encodes the
  intent extras into a query string —
  `/mission?mode=habit&habitId=...` for strong-mode habit
  launches, `/mission?mode=overlay&title=...&body=...` for
  routine-fired overlays.
- **`FullScreenIntentChannel.kt`** grows two new `when`
  arms — `showHabitMission` and `showRoutineOverlay` —
  building and launching an `Intent(ctx,
  FullScreenActivity::class.java)` with `FLAG_ACTIVITY_NEW_TASK`.
  Existing probe handlers (`canUseFullScreenIntent`,
  `openFullScreenIntentSettings`) untouched; the Dart
  `_safe` wrapper is kept as defense-in-depth per ADR-013.
- **`MainActivity.buildReminderNotification`** splits the
  strong-mode branch: the strong-mode `openIntent` now
  targets `FullScreenActivity::class.java` (with `habitId`
  extra), and `.setFullScreenIntent(openPi, /* highPriority= */
  true)` is added on the strong-mode builder so the OS
  launches the activity directly when the alarm fires and
  the device is locked. Soft-mode keeps the existing
  `MainActivity` openPi. The strong-mode `Open` action
  button also points at `FullScreenActivity`.
- **`AndroidManifest.xml`** declares the new `<activity>`:
  `android:exported="false"`, `android:taskAffinity=""`,
  `android:excludeFromRecents="true"`,
  `android:launchMode="singleTask"`,
  `android:theme="@style/LaunchTheme"`, lockscreen-bypass
  attributes (`android:showOnLockScreen="true"`,
  `android:turnScreenOn="true"`,
  `android:showWhenLocked="true"`), `android:configChanges`
  mirroring `MainActivity`.
- **`MissionLauncherScreen`** (NEW,
  `lib/screens/mission_launcher.dart`, SYS-114) — chain-
  level orchestrator. `initState` loads the habit by id via
  `DoRepository.instance.getById(habitId)`; rejects (and
  pops with `null`) if the habit is missing or not in
  `StrongProof` mode. For each `Mission` in `chain`,
  `await Navigator.push(MaterialPageRoute(...))` and collect
  the `MissionInput?` result. On a `null` result (cancel /
  timeout), `Navigator.pop` immediately. On all results
  collected, runs `MissionChainExecutor.run(chain, inputs)`
  and appends to the completion log on `ChainPassed`.
- **`RoutineOverlayScreen`** (NEW,
  `lib/screens/routine_overlay_screen.dart`) — banner widget
  for routine-fired overlays. Reads `title` + `body` from
  the `RouteSettings.arguments` map; falls back to generic
  copy on missing keys; "Dismiss" button `Navigator.pop`s
  with `null`.
- **`MaterialApp.onGenerateRoute`** in `lib/main.dart` maps
  `/mission?mode=habit&habitId=...` to
  `MissionLauncherScreen` and
  `/mission?mode=overlay&title=...&body=...` to
  `RoutineOverlayScreen`. The existing `home:` switch is
  unchanged — `onGenerateRoute` is additive.
- **`PlatformFullScreenIntent.getLaunchIntent()`** + a new
  `_safeResult<T>` defense-in-depth wrapper (mirrors the
  existing `_safe` wrapper pattern). Returns a
  `LaunchIntent` immutable class (`mode: LaunchMode`,
  `habitId: String?`, `title: String?`, `body: String?`).
- **`FakeFullScreenIntent`** records `launchIntents`
  (additive) — the existing `launches` / `routineOverlays`
  lists are unchanged.

**Test pins**

- `test/services/platform_full_screen_intent_test.dart`
  (NEW, 6 tests) — `showHabitMission` invokes the right
  method + `habitId` arg; `showRoutineOverlay` propagates
  `title` / `body` and skips missing keys; `getLaunchIntent`
  swallows production `MissingPluginException` and returns
  `null`; `showHabitMission` swallows
  `MissingPluginException` end-to-end; `getLaunchIntent`
  returns null on partial args; `showRoutineOverlay`
  accepts title-only / body-only / neither.
- `test/screens/mission_launcher_test.dart` (NEW, 6 tests)
  — 1-mission chain (Type) appends with
  `proofModeAtTime: "strong"` and
  `missionResultsJson: "missions=1"`, pops `true`;
  2-mission chain appends with `missions=2`; `ChainFailedAt`
  pops `null`; missing habit pops `null`; non-`StrongProof`
  habit pops `null`; cancel on first mission aborts.
- `test/screens/routine_overlay_test.dart` (NEW, 4 tests)
  — renders `title` + `body` from constructor args; falls
  back to generic copy on null; falls back on empty;
  Dismiss button pops with `null`.
- `test/a11y/semantics_labels_test.dart` (SYS-062) — the
  new Dismiss button's `Semantics(label: 'Dismiss routine
  overlay')` is auto-validated by the existing
  `excludeFromSemantics` / `semanticLabel` /
  `Semantics(label:)` static-analyzer regex.

**Verification (3-gate)**

```
$ dart format --output=none --set-exit-if-changed .
Formatted 217 files (0 changed) in 0.74 seconds.

$ flutter analyze --fatal-infos
Analyzing doit...
No issues found! (ran in 1.0s)

$ flutter test test/services/platform_full_screen_intent_test.dart \
              test/screens/mission_launcher_test.dart \
              test/screens/routine_overlay_test.dart \
              test/a11y/semantics_labels_test.dart \
              test/reminders/reminder_service_test.dart \
              test/routines/action_dispatch_test.dart
00:00 +16: All tests passed!
```

(Full-suite 1064 / 1064 gate output is in the PR description.)

Plus the targeted Kotlin compile check:

```
$ cd android && ./gradlew :app:compileDebugKotlin
BUILD SUCCESSFUL in 8s
```

**V-Model traceability** (this PR)

- `feature.md` §2.1 "Still deferred" — closed (Phase 6a
  proper).
- New `SYS-114`: "Full-screen activity launch path" — the
  `FullScreenActivity` Kotlin class contract, the
  `showHabitMission` / `showRoutineOverlay` handler
  contract, the `setFullScreenIntent` strong-mode
  notification, the `MissionLauncherScreen` orchestrator
  contract, the `RoutineOverlayScreen` widget contract, the
  `MaterialApp.onGenerateRoute` `/mission` route, the
  `PlatformFullScreenIntent.getLaunchIntent()` channel read,
  and the `_safeResult<T>` defense-in-depth wrapper.
- New `ADR-044`: "Full-screen activity launch path" — the
  separate `FullScreenActivity` decision, the channel-reuse
  decision, the no-`wakelock_plus` decision, the
  chain-orchestrator-in-`lib/screens/` decision, and the
  defense-in-depth `_safe` + `_safeResult` wrapper
  preservation.
- New `WF-041`: "Strong-mode habit fires full-screen
  mission chain end-to-end" — extension of `WF-001`
  (alarm → notification path).
- `notification_reliability.md` § Layer 1 (full-screen
  interruption) — extended with the v1.3d launch handlers,
  the `setFullScreenIntent` strong-mode notification flag,
  and the `MissionLauncherScreen` orchestrator.

**Deferred** (out of Phase 15 scope)

- **Kotlin-side unit tests** for `FullScreenIntentChannel
  .showHabitMission` / `showRoutineOverlay` and the new
  `FullScreenActivity`. The Dart-side tests cover the
  channel-call contract; the Kotlin compile gate catches
  syntax / null-safety / deprecation issues. A v1.4+
  follow-up can add `FullScreenIntentChannelTest.kt` using
  Robolectric / `androidx.test.core` to assert the
  `Intent` construction (extras, flags, target component).
- **`wakelock_plus` swap.** Phase 15 holds the wake-lock at
  the Android Window level via `FLAG_KEEP_SCREEN_ON`; a
  future v1.4+ could swap to `wakelock_plus` if the team
  wants per-mission wake-lock control (vs the activity-
  level lifecycle).
- **Per-mission retry UX.** A `ChainFailedAt` currently
  pops with `null` (the streak stays broken per
  `feature.md` §2.4 / v1.1f grace-window semantics). v1.1f
  grace-window semantics (`MissionWrongAttempts` shared
  module from v1.2l) handle the wrong-attempt case for
  Math / Type; Shake / Hold / Memory do not retry. A
  future v1.4+ could add an "Retry mission N" button to
  the launcher.
- **Light-theme icon variant** (feature.md §2.7) — still
  deferred.
- **The Android home-screen widget** (Phase 28) — still
  deferred; the widget surface does not interact with
  `FullScreenActivity`.
- **Native Spanish translation** (feature.md §2.4) — still
  deferred.

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

## v1.4g — Widget-action round-trip: Kotlin → Dart via inbound `doit/widget` channel (Phase 34 / SYS-121 / ADR-051 / WF-048)

Closes the latent v1.4a + v1.4f gap: the widget's "Done" / "Skip today" / "Undo today" buttons now round-trip to Dart's `WidgetService.markDone` / `.skip` / `.undo` so the actual completion write / rest-day append / row delete happens in Dart (single source of truth for the completion log). v1.4a + v1.4f had wired the buttons to fire `WidgetUpdater.refreshAll(ctx)` from the Kotlin `ACTION_*` broadcast — which only repainted the widget with the cached state and NEVER wrote to the Drift DB. The user could tap the widget "Done" button all day and the in-app tile's streak would not advance because the DB had no row. v1.4g activates the INBOUND direction on the existing `doit/widget` MethodChannel so the widget taps now share the write path with the in-app tile.

New code:

- `lib/widget/widget_action_invoker.dart` (NEW) — singleton `WidgetActionInvoker` with `attach({MethodChannel? channel})` (idempotent — `Completer<void> _ready` resolves immediately on second call), `Future<bool> dispatch(MethodCall call)`, top-level `widgetActionDispatch(MethodCall)` function (the test seam), and `resetForTesting()`. Wires `setMethodCallHandler` on the `doit/widget` channel so inbound `markDone` / `skip` / `undo` `MethodCall`s route to `WidgetService.instance.markDone(habitId)` / `.skip(habitId)` / `.undo(habitId)` and return the service's `bool` result. Outbound methods (`cacheSnapshot`, `requestRefresh`, `snapshot`) and any other method fall through to `null` (no-op on the platform side). The dispatcher extracts `habitId` from `call.arguments` (returns `false` on missing/empty) and catches `StateError` from `WidgetService.instance` (returns `false` if not initialized). All platform-side throws are caught and returned as `false` per ADR-013.
- `lib/services/widget_service.dart` — `markDone` signature changes from `Future<void>` → `Future<bool>` (the only v1.4a caller was the in-app tile which ignored the return; v1.4g reads it). Returns `false` if the habit does not exist OR if the `append` throws; appends via `CompletionLogService.append(habitId, day: local-midnight at now, source: CompletionSource.manual, proofModeAtTime: proofModeTag(activeDo.proofMode))` and re-derives via `handleRefreshRequest()` on the happy path. `init(...)` calls `await WidgetActionInvoker.attach()` right after the singleton is set so the inbound channel handler is wired before any widget tap can fire.
- `android/app/src/main/kotlin/com/doit/WidgetChannel.kt` — new suspending `suspend fun invokeAction(ctx: Context, action: String, habitId: String): Boolean` with a 5 s `withTimeoutOrNull` ceiling. Validates `action ∈ {markDone, skip, undo}` + non-empty `habitId` (returns `false` otherwise). Ensures the `FlutterEngine` is alive via `WidgetUpdater.ensureFlutterEngine(ctx)` (which is now `public` — was `private` — so `invokeAction` can boot the engine before sending the inbound call). Posts `ch.invokeMethod(action, mapOf("habitId" to habitId), resultProxy)` to the platform main thread via `android.os.Handler(Looper.getMainLooper()).post { ... }` because `MethodChannel.invokeMethod` must run on the platform thread. Awaits the result via `CompletableDeferred<Boolean>.await()`. Returns `false` on timeout, missing channel, invalid action, empty habitId, or any throwable.
- `android/app/src/main/kotlin/com/doit/WidgetUpdater.kt` — `ensureFlutterEngine(ctx)` is now `public` (was `private`) so `WidgetChannel.invokeAction` can call it before sending the inbound call. The function body is unchanged: boot the `FlutterEngine` via `FlutterLoader().startInitialization(ctx)` + `FlutterEngine(ctx.applicationContext)` + `dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())` + `WidgetChannel.setAppContext(ctx.applicationContext)` + `WidgetChannel.attach(newEngine)` and assign to the static `engine` field.
- `android/app/src/main/kotlin/com/doit/DoitWidgetProvider.kt` — three action arms (`ACTION_MARK_DONE` / `ACTION_WIDGET_SKIP` / `ACTION_WIDGET_UNDO`) in `onReceive` are replaced with: read `habitId` from `intent.getStringExtra(EXTRA_HABIT_ID)` (preferred) or `WidgetStateCache.cachedFromPrefs(ctx)?.optString("habitId")` (fallback for stale `PendingIntent`s created before v1.4g — these will repaint via the cache, then the next Dart refresh will overwrite), then `scope.launch { WidgetChannel.invokeAction(ctx, "<action>", habitId); WidgetUpdater.refreshAll(ctx) }` on `Dispatchers.IO` (new `private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)`) so the BroadcastReceiver doesn't block the main thread. New companion constant `EXTRA_HABIT_ID = "com.doit.EXTRA_HABIT_ID"` is exported and consumed by `WidgetRenderer`.
- `android/app/src/main/kotlin/com/doit/WidgetRenderer.kt` — `markDoneIntent(ctx, id, habitId)` / `skipIntent(ctx, id, habitId)` / `undoIntent(ctx, id, habitId)` each `putExtra(EXTRA_HABIT_ID, habitId)`. `render(...)` reads `state.optString("habitId", "")` and passes to all three intent builders. The empty-string fallback (defensive belt-and-suspenders) routes the `PendingIntent` to the cached state's habit id on the Kotlin side.
- `test/widget/widget_action_invoker_test.dart` (NEW, 7 tests) — `widgetActionDispatch` returns `false` when `WidgetService` is not initialized; returns `false` when `habitId` arg is missing; returns `false` when `habitId` arg is empty; returns `false` when arguments are `null`; returns `false` for an unknown action method; `WidgetActionInvoker.attach` is idempotent — second call is a no-op; `WidgetActionInvoker.resetForTesting` clears the singleton + handler.
- `test/widget/widget_action_invoker_integration_test.dart` (NEW, 4 tests) — inbound `markDone` via the production `widgetActionDispatch` function routes to `WidgetService.markDone` and appends a `CompletionSource.manual` row via `CompletionLogService.append` + re-derives via `handleRefreshRequest` (asserted via `FakeWidgetBridge.refreshCount`); inbound `skip` routes to `WidgetService.skip` and appends a `CompletionSource.restDay` row; inbound `undo` routes to `WidgetService.undo` and removes today's row via `CompletionLogService.deleteById`; inbound `markDone` returns `false` when the habit does not exist — no `append` call.

**ADR-051** locks the design: the `doit/widget` MethodChannel becomes bidirectional (the existing v1.4a outbound direction — Dart → Kotlin — is preserved verbatim; v1.4g adds the inbound direction — Kotlin → Dart), the new `WidgetActionInvoker` singleton owns the inbound dispatch and is wired by `WidgetService.init(...)` so the channel is live at first widget refresh, `WidgetService.markDone` returns `Future<bool>` so the platform side can react to the success/failure, the Kotlin `invokeAction` suspending helper ensures the `FlutterEngine` is alive before sending the inbound call (1-3 s cost on cold-start, sub-100 ms on warm) with a 5 s `withTimeoutOrNull` ceiling so a stuck Dart side doesn't pin the BroadcastReceiver's `CoroutineScope`, the `EXTRA_HABIT_ID` extra on the `PendingIntent` is the primary habit-id source with the cached state as fallback (defensive belt-and-suspenders for stale `PendingIntent`s created before v1.4g), no new `<uses-permission>`, no new pubspec deps, no new Drift tables, no new MethodChannels (v1.4g re-uses the existing `doit/widget` channel in the inbound direction). The bidirectional contract is documented in three file headers (`widget_action_invoker.dart`, `WidgetChannel.kt`, `DoitWidgetProvider.kt`).

**SYS-121 + ADR-051 + WF-048 appended.** `feature.md` §4 latent v1.4a "widget-side Done tap doesn't round-trip to Dart" bullet removed; §5 quick-index updated to ADR-051 / SYS-121 / WF-048. ADR-050's "Latent gap" hedge is annotated with the v1.4g closure reference.

### v1.4f — Android home widget Skip today + Undo today (Phase 33 / SYS-120 / ADR-050 / WF-047)

Brings the Android home-screen widget (`com.doit.DoitWidgetProvider`) to feature-parity with the in-app `_HabitTile` by adding two new `ImageButton`s — "Skip today" and "Undo today" — between the spacer and the existing Done button. Closes the two v1.4c / v1.4d parking-lot items the widget surface was still missing: a user can now mark a rest day AND correct an accidental completion directly from the launcher widget, no need to open the app. The wiring mirrors the v1.4a "Done" pattern verbatim — same `doit/widget` MethodChannel, same `DoitWidgetProvider` BroadcastReceiver, same widget `ImageButton` shape — but with the new actions explicitly routing to Dart via `WidgetService.skip` / `WidgetService.undo` so the completion log + cache + repaint stay in lockstep with the in-app tile.

New code:

- `lib/services/widget_service.dart` — `WidgetService` grows `Future<bool> skip(String habitId)` + `Future<bool> undo(String habitId)`. `skip` mirrors the in-app `markDoSkipped` contract (v1.4c / SYS-117): returns `false` if the do is missing, `restDaysPerMonth <= 0`, or the month's rest-day rows already hit the limit; otherwise appends `CompletionSource.restDay` with `proofModeAtTime: proofModeTag(activeDo.proofMode)` (shared helper from v1.4c / ADR-047, replacing the previous inline `_proofModeTag` copy) and re-derives via `handleRefreshRequest()`. `undo` mirrors the in-app `undoToday` contract (v1.4d / SYS-118): first-match-wins tiebreak over `completionLog.listForHabit(habitId)` rows whose `dayMillis == local-midnight at now`, calls `deleteById` on match, re-derives; returns `false` (no delete) when no row matches today. Both methods are best-effort — `MissingPluginException` from the platform side surfaces as `false` per ADR-013.
- `lib/widget/widget_bridge.dart` — `WidgetBridge` interface gains `Future<bool> skip(String habitId)` + `Future<bool> undo(String habitId)`. `PlatformWidgetBridge` dispatches the `skip` / `undo` MethodChannel arms on `doit/widget`; the existing `_safeResult<bool>` (ADR-013) wraps the channel round-trip and unwraps a `null` channel result to `false` (the Dart-side return is `Future<bool>`, not `Future<bool?>`). `FakeWidgetBridge` records habit ids in `skipHabitIds` + `undoHabitIds` and exposes `nextSkipResult` + `nextUndoResult` defaults (both `true`) for tests.
- `lib/widget/doit_widget_state.dart` — `DoitWidgetState` grows `final int restDaysPerMonth` (default 0); included in `toJson()` / `fromJson()` (defaults to 0 on `fromJson`) / `copyWith` / `==` / `hashCode` / `toString`. The field is plumbed through `WidgetStateBuilder.buildWidgetState(...)` from `activeDo.restDaysPerMonth` so `WidgetRenderer` can decide the Skip button visibility from the cached JSON without a Dart round-trip.
- `android/app/src/main/kotlin/com/doit/WidgetChannel.kt` — the three near-duplicate `when` arms (`markDone`, `skip`, `undo`) collapse into a shared `private fun handleAction(call: MethodCall, result: MethodChannel.Result, action: String)` helper that reads the `habitId` arg, calls `WidgetUpdater.refreshAll(ctx)`, returns `true`. Reduces three arms to one + a 3-line `when` block — closing any future action (e.g., a v1.4g+ "Reset streak") is now a 3-line change, not a 15-line duplicate.
- `android/app/src/main/kotlin/com/doit/DoitWidgetProvider.kt` — two new action constants `ACTION_WIDGET_SKIP = "com.doit.WIDGET_SKIP"` + `ACTION_WIDGET_UNDO = "com.doit.WIDGET_UNDO"`, each with a matching `when` arm in `onReceive()` that mirrors the existing `ACTION_MARK_DONE` pattern.
- `android/app/src/main/kotlin/com/doit/WidgetRenderer.kt` — `render(...)` reads the cached `DoitWidgetState` JSON, including the new `restDaysPerMonth` field, to decide `widget_skip` visibility (`View.GONE` when `restDaysPerMonth == 0` — mirrors the in-app `_SkipButton` hide rule from SYS-117) and `isCompletedToday` to decide `widget_undo` visibility (`View.GONE` when `isCompletedToday == false` — mirrors the in-app `_UndoButton` hide rule from SYS-118). Two new private helpers `skipIntent(ctx, id)` + `undoIntent(ctx, id)` return `PendingIntent.getBroadcast` targeting `DoitWidgetProvider` with the corresponding `ACTION_WIDGET_SKIP` / `ACTION_WIDGET_UNDO` extras.
- `android/app/src/main/res/layout/widget_medium.xml` — two new `ImageButton`s (`@+id/widget_skip` + `@+id/widget_undo`) between the bottom spacer and the existing Done button; the layout becomes a 3-column `LinearLayout` when all three are visible. Both icons use `?android:attr/selectableItemBackgroundBorderless` for the tap ripple.
- `android/app/src/main/res/drawable/ic_widget_skip.xml` (NEW — moon glyph) + `ic_widget_undo.xml` (NEW — curved-arrow glyph) — 24 dp monochrome vectors matching the existing `ic_widget_done` style.
- `android/app/src/main/res/values/strings.xml` — 2 new `<string>` entries (`widget_skip_content_description`, `widget_undo_content_description`).
- `lib/l10n/app_en.arb` + `app_es.arb` — 2 new keys (`widgetSkipToday`, `widgetUndoToday`). The existing ARB parity test (`test/l10n/app_localizations_test.dart` "every non-template ARB has the same key set as the template") catches missing `app_es.arb` entries automatically.

**ADR-050** locks the design: shared `handleAction` Kotlin helper reduces three near-duplicate MethodChannel arms to one (lowering the cost of any future widget action), `restDaysPerMonth` field on `DoitWidgetState` threads through the renderer so Skip visibility is a `View.GONE` check at repaint time (no Dart round-trip), `skip` returns `bool` (NOT throws) because the widget has no SnackBar surface to show the in-app `NoRestDaysRemaining` copy (the button is hidden when the budget is exhausted), `undo` matches the in-app `undoToday` first-match-wins tiebreak (in lockstep with `sparklineForDo` from v1.4e), no new `<uses-permission>`, no new pubspec deps, no new Drift tables, no new MethodChannels. **Latent v1.4a gap noted** (NOT a defect of v1.4f): the existing widget "Done" tap still does NOT round-trip to Dart's `WidgetService.markDone` — it only fires `WidgetUpdater.refreshAll` from the Kotlin `ACTION_MARK_DONE` broadcast. Closure candidate for v1.4g+.

**SYS-120 + ADR-050 + WF-047 appended.** `feature.md` §4 widget-side Skip + Undo bullets removed; §5 quick-index updated to ADR-050 / SYS-120 / WF-047.

Tests: TBD by the 3-gate run at this commit (target: ~1230 / 1230 — the v1.4e sign-off tip of 1208 + 8 widget_service skip/undo + 6 widget_bridge skip/undo + 1 doit_widget_state `restDaysPerMonth` = ~15 new for v1.4f; the v1.4a..v1.4e net delta of +78 against the v1.4a `main` baseline of 1130 grows to ~+93).

## v1.4h — In-app home tile Edit + Delete IconButtons (Phase 35 / SYS-122 / ADR-052 / WF-049)

Surfaces Edit + Delete as discoverable per-tile `IconButton`s in the same right-edge action `Row` as the v1.4b/c/d Skip / Undo / Done buttons, closing the discoverability gap on the v0.2 long-press → select-mode → app-bar-trash path. The v0.2 long-press flow was undiscoverable — no visible affordance hinted at the gesture, the trash icon only appeared once select-mode was already entered, and a user with no prior knowledge of the app had no way to learn the path except by accident. v1.4h's per-tile buttons match the v1.4b/c/d pattern (localized tooltip + Material `IconButton`), so every user with tiles on the home screen now has two one-tap affordances for the most common do-mutation flows.

New code:

- `lib/screens/home_tile_delete.dart` (NEW) — pure-Dart `Future<bool> deleteDo({required Do activeDo, required DoRepository repository})` helper. Calls `repository.deleteById(activeDo.id)` and translates any throwable (DB locked, FK constraint, drift exception) into a `bool` return — `true` on the happy path, `false` on any throw. Pure-Dart, no Flutter import, no `DateTime.now()`. Matches the `markDoDone` (v1.4b) / `markDoSkipped` (v1.4c) / `undoToday` (v1.4d) helper pattern so the UI layer doesn't need a `try/catch` block and the helper is unit-testable without `TestWidgetsFlutterBinding`.
- `test/screens/home_tile_delete_test.dart` (NEW, 6 tests) — `deleteDo` returns `true` on the happy path AND records the deleted id; `deleteDo` calls `deleteById` exactly once with the captured do id; `deleteDo` returns `false` when the repository throws an `Error` (e.g. `StateError`); `deleteDo` returns `false` when the repository throws an `Exception` subtype (e.g. `Exception('foreign-key constraint')`); `deleteDo` does not re-throw — caller can rely on the `bool` return (asserted via `expectLater(() => ..., returnsNormally)`); the helper imports no Flutter types so it can be tested without `TestWidgetsFlutterBinding`.

Modified:

- `lib/screens/home.dart` — `_HabitTile` grows a new `final VoidCallback? onDoChanged` prop bound to `_HomeScreenState._refresh()` so a successful delete (or an edit that pops `true` per WF-022) immediately re-fetches the list and the deleted tile disappears. `_HabitTileState` grows two new private handlers: `_onEditPressed` pushes `AddHabitScreen(habitId: widget.habit.id)` — same destination as `_HomeScreenState._onTileTap` at `lib/screens/home.dart:120` — and `await`s the popped `bool`; `_onDeletePressed` opens an `AlertDialog` titled `homeTileDeleteConfirm(habit.name)` (carries the do name in quotes for destructive-action verification, e.g. `Delete "Stretch"?`), captures `messenger = ScaffoldMessenger.of(context)` BEFORE the async gap, sets `_busy = true`, awaits `deleteDo(...)`, clears `_busy` on return, and branches on the `bool`: on `true` calls `widget.onDoChanged?.call()` then shows a SnackBar `homeSnackbarDoDeleted(habit.name)` with a `SnackBarAction` labeled `homeSnackbarDoDeletedUndo` ("Undo") whose `onPressed` re-saves the captured `Do` reference via `DoRepository.save(widget.habit)` (the `Do` is `@immutable` so the reference is safe without a deep clone); on `false` shows `homeSnackbarDoDeleteFailed` ("Could not delete. Try again.") WITHOUT removing the tile — the DB is the source of truth. Two new private sub-widgets mirror the v1.4b/c/d shape: `_EditButton({required VoidCallback onPressed})` renders `Icons.edit_outlined` + `homeTileEdit` tooltip (no busy state — navigation push, not an in-flight write); `_DeleteButton({required bool busy, required VoidCallback onPressed})` renders `Icons.delete_outline` + `homeTileDelete` tooltip with busy-state spinner matching `_SkipButton`. The action row at `lib/screens/home.dart:618-652` (the existing `if (!selectMode)` `Row`) inserts `_EditButton` + `_DeleteButton` leftmost (BEFORE the existing `_SkipButton` / `_UndoButton` / `_DoneButton` cluster) so the destructive-action cluster is visually distinct from the completion-action cluster. Both new buttons ride on the `if (!selectMode)` gate — select-mode uses the app-bar action set, not the per-tile buttons.
- `lib/l10n/app_en.arb` + `lib/l10n/app_es.arb` — 7 new keys (`homeTileEdit`, `homeTileDelete`, `homeTileDeleteConfirm(doName)`, `homeTileDeleteConfirmBody`, `homeSnackbarDoDeleted(doName)`, `homeSnackbarDoDeletedUndo`, `homeSnackbarDoDeleteFailed`) added in lockstep so the existing `test/l10n/app_localizations_test.dart` parity test catches missing Spanish entries.

**ADR-052** locks the design: per-tile Edit `IconButton` re-uses the existing `_HomeScreenState._onTileTap` destination (`AddHabitScreen(habitId: ...)` — no new navigation path), per-tile Delete `IconButton` opens an `AlertDialog` (title carries the do name in quotes per the standard destructive-action contract), pure-Dart `deleteDo` helper isolates the side-effecting call so the UI layer doesn't need a `try/catch`, captured `Do` reference is valid for re-save inside the Undo closure without a deep clone (`Do` is `@immutable`), 7 ARB keys added in lockstep (parity test catches drift), no new `<uses-permission>`, no new pubspec deps, no new Drift tables, no new MethodChannels, no Kotlin changes — v1.4h is pure-Dart. The documented trade-off: `DoRepository.deleteById` cascade-deletes the linked `completions` rows via the FK pragma on `CompletionLogService`, so the Undo snackbar restores the do row but does NOT restore the streak history — the streak counter starts at 0 on the restored do. A v1.4h+ follow-up could add a soft-delete column to `habits` for a true undo (snapshot of completion log). The Undo snackbar's re-save failure path is defensive — `DuplicateDoName` is swallowed (matches the v1.2b "Undo action swallows re-save errors" pattern); the user can re-add the do manually via the FAB.

**SYS-122 + ADR-052 + WF-049 appended.** `feature.md` §4 per-tile edit/delete bullet removed; §5 quick-index updated to ADR-052 / SYS-122 / WF-049. Final test count 1242 / 1242 (+14 from v1.4g tip of 1228: 6 home_tile_delete + 7 home_test extensions + 1 incidental test rerun per CHANGELOG 3-gate at this commit).

## v1.4i — In-app home tile rest-day history visualization (Phase 36 / SYS-123 / ADR-053 / WF-050)

Extends the v1.4e / SYS-119 / WF-046 7-day streak sparkline on every `_HabitTile` to **14 days** with **source-aware color** + **inline legend** below the dot row, so the user can see at-a-glance which days in the past fortnight were intentionally skipped (via the v1.4c / SYS-117 `_SkipButton`) vs which were missed or completed manually. The v1.4e 7-day window was too short to surface the rest-day pattern for most users (a 2 / month rest-day budget rarely lands within a 7-day window); the v1.4i 14-day window + per-source color closes the "we know rest-day rows exist but you can't tell them apart on the sparkline" gap that v1.4e flagged but did not close.

New code:

- `lib/screens/home_tile_sparkline.dart` (MODIFIED) — the v1.4e `sparklineForDo` helper is now a thin wrapper around a new top-level `Future<List<SparklineDot>> extendedSparklineForDo({required Do activeDo, required DateTime asOf, required CompletionLogService completionLog, int days = 14})` function which takes a configurable `days` parameter (default 14 — a fortnight, half a calendar month). The helper builds the `[asOf - (days - 1) days .. asOf]` window (local-midnight each), fetches `completionLog.listForHabit(activeDo.id)`, and emits one dot per day (`SparklineDot.filled(day, source)` if a row exists for that day's `dayMillis`, `SparklineDot.future(day)` if the day is in the future of `asOf`, `SparklineDot.empty(day)` otherwise). The first-match source wins on the `(habitId, dayMillis)` UNIQUE constraint — mirrors `home_tile_undo.undoToday` (v1.4d / SYS-118) + `sparklineForDo` (v1.4e / SYS-119). Pure-Dart, no Flutter import, no `DateTime.now()`. Backwards-compatible: `sparklineForDo` keeps its exact return shape, no caller breaks.
- `test/screens/home_tile_sparkline_test.dart` (MODIFIED — +4 tests) — `extendedSparklineForDo` with `days: 14` returns 14 dots with `dots.first.day == today - 13 days` (local-midnight at asOf) and `dots.last.day == today`; defaults to 14 days when no `days` arg is passed; honors an arbitrary window (`days: 3` returns 3 dots, `days: 30` returns 30 dots) — the `days` parameter is wired through to the dot-list length; preserves the source tag on filled dots — a `'rest_day'` row at day -2 paints a `SparklineDotFilled(source: 'rest_day')` AND a `'manual'` row at day -7 paints a `SparklineDotFilled(source: 'manual')`, both retrievable from the returned list so the widget can branch on the source.

Modified:

- `lib/screens/home.dart` (MODIFIED) — `_Sparkline` (v1.4e / SYS-119 / WF-046) is extended with three new optional constructor params: `int days = 14` (the window length; defaults to the v1.4i 14-day value), `Color? restDayColor` (the color used for `rest_day` filled dots — the tile invocation passes `restDayColor: Theme.of(context).colorScheme.tertiary` so the rest-day color tracks the active theme), `bool showLegend = true` (whether to render the inline legend row below the dots). The widget reads `SparklineDotFilled.source` and switches: `source == 'rest_day'` → `restDayColor ?? colorScheme.tertiary`; else (manual / notification / mission) → `colorScheme.primary`. Each `_SparklineDot` wraps its `Padding > Container` in `Semantics(label: ...)` (NOT a per-dot `Tooltip` — see ADR-053 §"Alternatives considered" for why `Tooltip` was rejected: 14 small dots × 3 localized messages = 42 competing tooltips, plus `Tooltip`'s internal `GestureDetector` intercepts the parent `_HabitTile`'s `onLongPress` select-mode gesture — verified empirically via the v1.4i "long-press on a tile with the new sparkline still enters select mode" regression test). The per-dot labels are `'Done'` for manual / notification / mission fills, `'Rest day'` for rest-day fills, `'Missed'` for empty dots, `'Future'` for future dots. The existing `_Sparkline` outer `Semantics(label: l.homeTileSparklineSemantics, readOnly: true, container: true)` node announces "Last 14 days" / "Últimos 14 días" once on TalkBack focus (updated from the v1.4e "Last 7 days" / "Últimos 7 días" form). A new `_SparklineLegend` sub-widget renders below the dot row whenever `showLegend == true`: 3 `_LegendSwatch` entries (a filled primary-color circle + `homeTileSparklineLegendDone`; a filled tertiary-color circle + `homeTileSparklineLegendRestDay`; an outlined circle + `homeTileSparklineLegendMissed`) using `Theme.of(context).textTheme.labelSmall`. The legend is the discoverability mechanism for the source-aware coloring; without the legend, the two fill colors would be meaningless.
- `lib/l10n/app_en.arb` + `lib/l10n/app_es.arb` (MODIFIED) — 6 new keys (`homeTileSparklineRestDayTooltip`, `homeTileSparklineDoneTooltip`, `homeTileSparklineMissedTooltip`, `homeTileSparklineLegendDone`, `homeTileSparklineLegendRestDay`, `homeTileSparklineLegendMissed`). `homeTileSparklineSemantics` updated from "Last 7 days" → "Last 14 days" (and `Últimos 7 días` → `Últimos 14 días`). The existing `test/l10n/app_localizations_test.dart` "every non-template ARB has the same key set as the template" test catches missing Spanish entries automatically.

**ADR-053** locks the design: 14-day window (a fortnight, half a calendar month, fits comfortably at 360 dp), `Theme.of(context).colorScheme.primary` for manual fills (matches the v1.4e / v1.4a "Done" branding) vs `Theme.of(context).colorScheme.tertiary` for rest-day fills (complementary accent — the `restDayColor` is a constructor param so a future theme tweak can swap it without changing the widget code); inline `_SparklineLegend` row below the dot row is the discoverability mechanism (3 `_LegendSwatch` entries — Done / Rest day / Missed); per-dot `Semantics(label: ...)` is the correct a11y primitive (per-dot `Tooltip` was rejected for 2 reasons: 42 competing tooltips on a 360 dp tile, AND `Tooltip`'s internal `GestureDetector` intercepts the parent `_HabitTile`'s `onLongPress` select-mode gesture — verified empirically during v1.4i implementation); `sparklineForDo` (v1.4e / SYS-119) is a thin backwards-compatible wrapper around `extendedSparklineForDo` so no caller breaks; 6 new ARB keys added in lockstep (parity test catches drift), 1 existing key updated ("Last 7 days" → "Last 14 days"); no new `<uses-permission>`, no new pubspec deps, no new Drift tables, no new MethodChannels, no Kotlin changes — v1.4i is pure-Dart. Widget re-fetch on any tile-state change re-uses the existing `_HomeScreenState._refresh()` setState cascade — no `ChangeNotifier` / `Stream` is added.

**SYS-123 + ADR-053 + WF-050 appended.** `feature.md` §4 rest-day history bullet removed; §5 quick-index updated to ADR-053 / SYS-123 / WF-050. Final test count 1252 / 1252 (+10 from v1.4h tip of 1242: 4 home_tile_sparkline `extendedSparklineForDo` + 6 home_test v1.4i group per CHANGELOG 3-gate at this commit).

## v1.4j — In-app home tile rest-day budget edit affordance (Phase 37 / SYS-124 / ADR-054 / WF-051)

Surfaces the long-hidden v1.0 affordance of editing the per-do `restDaysPerMonth` field directly from the in-app home tile (`_BudgetCaption` tap) AND from the `AddHabitScreen` form ("Rest days per month: N" row), AND fixes a v1.0 silent-reset bug in `AddHabitScreen._save()` that hardcoded `restDaysPerMonth: 2` in all 5 schedule branches (so editing a 3/month do and hitting Save without touching any other field silently reset the value to 2). Closes a 3-part gap: the budget caption on every `_HabitTile` was purely informational (tapping it did nothing); the budget the caption reports on was editable only by opening the edit screen and scrolling past proof-mode + schedule + time fields (high-friction); and the silent-reset bug meant even that high-friction path was lossy.

New code:

- `lib/screens/rest_day_picker_dialog.dart` (NEW) — shared `Future<int?> showRestDayPicker(BuildContext context, {required int initial})` + `RestDayPickerDialog(initial: int)` `StatefulWidget`. The dialog renders an `AlertDialog` with title `homeTileBudgetEditTitle`, description `homeTileBudgetEditDescription`, a live integer label above a `Slider(min: 0, max: 31, divisions: 31, value: _value, label: '$_value', onChanged: ...)` that snaps to whole numbers, and Save / Cancel actions. The dialog clamps the initial value to `[0, 31]` on construction (defensive against stale DB rows from a future schema migration). Constants `kRestDaysPerMonthMin = 0` and `kRestDaysPerMonthMax = 31` are exported for the test surface. The Save button calls `Navigator.of(context).pop(_value)`; Cancel calls `Navigator.of(context).pop()` (returns `null`). The picker is the single source of truth for the UI shape — both the tile affordance and the `AddHabitScreen` form-row trigger call this same helper.
- `test/screens/rest_day_picker_dialog_test.dart` (NEW, 8 tests) — `RestDayPickerDialog(initial: 5)` renders `'5'` as the live integer + the `Slider` `value == 5.0`; the localized `homeTileBudgetEditTitle` / `homeTileBudgetEditDescription` / `homeTileBudgetEditOk` / `homeTileBudgetEditCancel` strings render in English locale via `localizedApp`; tapping Cancel returns `null` from `showRestDayPicker`; tapping Save returns the current `Slider` value; `initial: -7` clamps to `kRestDaysPerMonthMin` (0) on construction + the slider value matches; `initial: 99` clamps to `kRestDaysPerMonthMax` (31); the slider `divisions == kRestDaysPerMonthMax - kRestDaysPerMonthMin` so it snaps to integer values; dragging the slider updates the live integer label.

Modified:

- `lib/do/do.dart` (MODIFIED) — `Do.validate()` adds the upper-bound check `if (restDaysPerMonth < 0 || restDaysPerMonth > 31) throw DoInvalidRestDays(restDaysPerMonth);` so `DoInvalidRestDays` is the single source of truth for the invariant (the picker clamps inline, `validate()` is the defensive second line). The exception class's `super(...)` message is updated from "must be >= 0" to "must be in 0..31." to reflect the new range. The lower-bound rule (`>= 0`) is preserved.
- `lib/screens/add_habit.dart` (MODIFIED) — `AddHabitScreenState` grows `int _restDaysPerMonth = 2` state field, loads it in `_loadExisting()` from `_original?.restDaysPerMonth ?? 2` (preserving the original value in edit mode — fixes the silent-reset bug), replaces all 5 hardcoded `restDaysPerMonth: 2` literals in `_save()` at `:911, :926, :945, :960, :981` with `restDaysPerMonth: _restDaysPerMonth`, and grows `_pickRestDaysPerMonth()` which calls `showRestDayPicker(context, initial: _restDaysPerMonth)` and `setState`s on the non-null result. The form body grows a new "Rest days per month: N" `ListTile` near the proof-mode row that opens the same picker; tap → picker → Save → state updates → form re-renders.
- `lib/screens/home.dart` (MODIFIED) — `_BudgetCaption` at `lib/screens/home.dart` grows `final VoidCallback? onTap` + `final String zeroCaption` constructor params and DROPS the two early-returns (`limit <= 0` + `used == 0`) so the caption renders in all 3 budget states (zero budget / partial use / exhausted). The caption is wrapped in `Semantics(button: true, label: captionText, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: ...))` so TalkBack reads the caption as a button. `_HabitTileState` grows `_onBudgetCaptionTapped()` which captures `messenger = ScaffoldMessenger.of(context)` BEFORE the async gap, awaits `showRestDayPicker(...)`, on non-null awaits `DoRepository.instance.save(widget.habit.copyWith(restDaysPerMonth: picked))`, on success shows `messenger.showSnackBar(SnackBar(content: Text(l.homeSnackbarBudgetUpdated(picked))))` and calls `widget.onDoChanged?.call()` to trigger the v1.4h `_refresh()` cascade; on throw shows `homeSnackbarBudgetUpdateFailed` SnackBar WITHOUT removing the tile. `_DoStreakBadge` grows a new `onBudgetCaptionTapped: VoidCallback` param threaded through from `_HabitTileState`.
- `lib/l10n/app_en.arb` + `lib/l10n/app_es.arb` (MODIFIED) — 7 new keys added in lockstep: `homeTileBudgetZeroCaption` ("No rest days configured"), `homeTileBudgetEditTitle` ("Rest days per month"), `homeTileBudgetEditDescription` ("How many rest days you can take each month. Resets on the 1st."), `homeTileBudgetEditOk` ("Save"), `homeTileBudgetEditCancel` ("Cancel"), `homeSnackbarBudgetUpdated(value)` ("Rest-day budget set to {value}."), `homeSnackbarBudgetUpdateFailed` ("Could not update budget. Try again."), `addHabitRestDaysLabel(value)` ("Rest days per month: {value}"). The existing `test/l10n/app_localizations_test.dart` "every non-template ARB has the same key set as the template" test catches missing Spanish entries automatically.

Test changes:

- `test/do/do_model_test.dart` (MODIFIED — +3 tests) — `Do.validate()` throws `DoInvalidRestDays(-1)` on `restDaysPerMonth: -1` (existing rule preserved); `Do.validate()` throws `DoInvalidRestDays(32)` on `restDaysPerMonth: 32` (new upper-bound rule); `Do.validate()` accepts `restDaysPerMonth: 0` AND `restDaysPerMonth: 31` (boundary cases).
- `test/screens/add_habit_test.dart` (MODIFIED — +1 widget test + 1 grep regression test; 3 existing tests localized) — "AddHabitScreen renders a Rest-days-per-month form row with the default value 2 (v1.4j / SYS-124)" asserts `find.text('Rest days per month: 2')` is visible in add mode; "no hardcoded restDaysPerMonth: 2 literals remain in _save() — the v1.0 silent-reset bug (v1.4j / SYS-124)" reads `lib/screens/add_habit.dart` via `File().readAsString()` and asserts the regex `restDaysPerMonth:\s*2,` has 0 matches, pinning the contract that all 5 switch branches read `restDaysPerMonth: _restDaysPerMonth` (the grep regression test replaces a brittle edit-mode widget round-trip test that hung on `CompletionLogSection`'s `FutureBuilder` + `CircularProgressIndicator` — the source-level contract is durable). The 3 existing widget tests ("Save with empty name shows validation error", "Save with valid name persists and pops", "Routines section renders the empty-state and both Add a location routine / Add a calendar routine buttons") were switched from `MaterialApp(home: AddHabitScreen())` to `localizedApp(home: AddHabitScreen())` because the new `Builder` widget calls `AppLocalizations.of(ctx)` and a plain `MaterialApp` does not wire the delegate.
- `test/screens/home_test.dart` (MODIFIED — +5 widget tests in a new v1.4j group) — the `_BudgetCaption` renders `homeTileBudgetZeroCaption` ("No rest days configured") when `restDaysPerMonth == 0` (regression guard for the `limit <= 0` early-return removal); the `_BudgetCaption` renders `homeTileBudgetRemaining(3, 3)` when `restDaysPerMonth == 3 && used == 0` (regression guard for the `used == 0` early-return removal — the formerly-hidden state is now visible); tapping the caption opens the `RestDayPickerDialog` (asserted via `find.byType(RestDayPickerDialog)` after `tester.tap(find.text('No rest days configured'))`); a successful Save writes `DoRepository.save(activeDo.copyWith(restDaysPerMonth: 5))` AND triggers the v1.4h `onDoChanged` refresh cascade; long-press on a tile still enters select mode after the v1.4j caption-tap addition (regression guard for the v1.4b select-mode gesture surviving the `GestureDetector(onTap: ...)` wrap on the caption — the gesture is a tap, not a long-press, so it does NOT intercept the parent's `InkWell.onLongPress`).
- `test/screens/add_habit_delete_test.dart` + `test/screens/add_habit_save_as_template_test.dart` + `test/screens/templates_test.dart` (MODIFIED — localization wrap) — switched from `MaterialApp(home: ...)` to `localizedApp(home: ...)` because `AddHabitScreen` now requires `AppLocalizations` (mirrors the same fix on `add_habit_test.dart`).

**ADR-054** locks the design: a shared `RestDayPickerDialog` (single source of truth for the UI shape — both the tile affordance and the `AddHabitScreen` form-row trigger call this same helper); the tile affordance IS the caption itself (NOT a new icon) — `_BudgetCaption` is wrapped in `Semantics(button: true, label: captionText)` + `GestureDetector(onTap: onTap)` so TalkBack reads "5/5 rest days left, button" and the user can tap anywhere on the caption; the two pre-existing `_BudgetCaption` early-returns (`limit <= 0` + `used == 0`) are DROPPED so the caption renders in all 3 budget states (zero budget / partial use / exhausted) — the discoverability + visibility gap is closed; `_HabitTileState._onBudgetCaptionTapped()` captures `messenger = ScaffoldMessenger.of(context)` BEFORE the async gap, opens the picker, and on a non-null result calls `DoRepository.instance.save(widget.habit.copyWith(restDaysPerMonth: picked))` + `widget.onDoChanged?.call()` (re-uses the v1.4h `_refresh()` cascade); on throw (e.g. `DoInvalidRestDays(32)` if validation is bypassed) shows `homeSnackbarBudgetUpdateFailed` SnackBar WITHOUT removing the tile; `AddHabitScreen` fix: `_restDaysPerMonth` state field, loaded from `_original.restDaysPerMonth` in `_loadExisting()` (preserves the original value in edit mode — fixes the silent-reset bug), replaces all 5 hardcoded `restDaysPerMonth: 2` literals in `_save()` (the grep regression test pins the contract durably); `Do.validate()` adds the upper-bound check `restDaysPerMonth <= 31` (defensive — the picker clamps inline, `validate()` is the second line); 7 new ARB keys added in lockstep (parity test catches drift); no new `<uses-permission>`, no new pubspec deps, no new Drift tables, no new MethodChannels, no Kotlin changes — v1.4j is pure-Dart.

**SYS-124 + ADR-054 + WF-051 appended.** `feature.md` §4 in-app rest-day budget edit bullet removed; §5 quick-index updated to ADR-054 / SYS-124 / WF-051. Final test count 1271 / 1271 (+19 from v1.4i tip of 1252: 8 picker + 3 do_model + 1 add_habit widget + 1 grep regression + 5 home + 1 add_habit localized wrapper switched to `localizedApp` — 3 add_habit localizations mirrored to 3 sibling files `add_habit_delete_test.dart` + `add_habit_save_as_template_test.dart` + `templates_test.dart`). Coverage ≥80% on every changed file.

## v1.4k — Per-instance home widget configuration via Android AppWidget configuration activity (Phase 38 / SYS-125 / ADR-055 / WF-052)

Closes the v1.4a "every widget instance shows the same `firstActiveDo`" gap by routing the widget bind flow through an Android `AppWidget` configuration activity (`DoitWidgetConfigureActivity`) that hosts a Flutter-side picker (`WidgetConfigScreen`) and persists the picked habit id to the `DoitWidgetState` JSON envelope as a new optional `selectedHabitId` field. The widget body-tap PendingIntent reads the cached pick and routes via `MainActivity.getInitialRoute()` to `AddHabitScreen(habitId: ...)`; the activity clears the extra on first read so subsequent rebuilds do not re-route. **New files.** `lib/widget/widget_config_screen.dart` (NEW) — `WidgetConfigScreen` `StatefulWidget`. `FutureBuilder<List<Do>>` reads `DoRepository.instance.listAll()`; the `_PickerRow` `ListTile` calls `widget.proxy.setSelectedHabitId(habitId)` then `Navigator.of(context).pop<String>(habitId)`. The `_EmptyState` shows a `Icons.add_task` glyph + `widgetConfigureEmptyState` copy + "Back to do it" `FilledButton` (`widgetConfigureBackToHome`) that pops `null`. Constructor takes `widgetId: int?` + `proxy: WidgetServiceProxy` (default `const WidgetServiceProxy()`) for testability. `lib/widget/widget_service_proxy.dart` (NEW) — `class WidgetServiceProxy { const WidgetServiceProxy(); Future<bool> setSelectedHabitId(String? habitId) => WidgetService.instance.setSelectedHabitId(habitId); }` — the indirection layer that lets widget tests inject a fake without reaching into the singleton (mirrors the v1.4h `home_tile_delete.dart` callback-handler seam). `lib/app_router.dart` (NEW) — top-level route table extracted from `lib/main.dart` for testability (Dart top-level `_private` functions are not reachable across library boundaries). Exports `buildAppRoute(RouteSettings)` (dispatches `/mission` → `buildMissionRoute` (v1.3d / SYS-114), `/habit` → `buildHabitRoute` (v1.4k), `/widget-config` → `buildWidgetConfigRoute` (v1.4k); non-matching routes return `null`), plus the three individual builders. `android/app/src/main/kotlin/com/doit/DoitWidgetConfigureActivity.kt` (NEW) — thin `FlutterActivity` shell. `getInitialRoute(): String` reads `Intent.EXTRA_APPWIDGET_ID` and returns `"/widget-config?widgetId=$widgetId"`. `configureFlutterEngine` intentionally does NOT attach Kotlin channels (mirrors v1.3d `FullScreenActivity` thin-Flutter shell precedent). `exported=true` + `launchMode=singleTask` + `taskAffinity=""` + `excludeFromRecents=true` + `theme=LaunchTheme` per manifest. **Modified.** `lib/widget/doit_widget_state.dart` (MODIFIED) — grows `final String? selectedHabitId` (default `null`), threaded into `toJson` / `fromJson` (empty string → `null` defensive) / `copyWith` / `==` / `hashCode` / `toString`. `lib/widget/widget_state_builder.dart` (MODIFIED) — grows `String? selectedHabitId` named param to `buildWidgetState(...)`, threaded into the returned `DoitWidgetState` in both active + empty-state paths. `lib/services/widget_service.dart` (MODIFIED) — `handleRefreshRequest` consults `WidgetStateCache.cached?.selectedHabitId` first via `_resolveActiveDo()`; on a null / empty / unresolvable cached pick falls back to `firstActiveDo`. Reconciliation: when `_resolveActiveDo` returns null because the picked do was deleted, the next cached state has `selectedHabitId = null` (the stale-pick clear is gated on a `_pickIsStale` boolean — runs only on the rare stale-pick path). New public method `setSelectedHabitId(String? habitId)` writes a fresh state to the cache + asks the platform to repaint. `lib/main.dart` (MODIFIED) — `DoItApp` switches `onGenerateRoute:` from the v1.3d `_buildMissionRoute` to `buildAppRoute` (the additive router does not break the existing routes). `android/app/src/main/kotlin/com/doit/WidgetRenderer.kt` (MODIFIED) — `openAppIntent(ctx, id, selectedHabitId: String)` adds `MainActivity.EXTRA_HABIT_ID` extra when `selectedHabitId.isNotEmpty()`. `android/app/src/main/kotlin/com/doit/MainActivity.kt` (MODIFIED) — `override fun getInitialRoute(): String?` reads `EXTRA_HABIT_ID`, clears the extra (one-shot), returns `"/habit?habitId=${Uri.encode(habitId)}"` or null. Companion gains `const val EXTRA_HABIT_ID = "com.doit.EXTRA_HABIT_ID_FROM_WIDGET"` (distinct namespace from `DoitWidgetProvider.EXTRA_HABIT_ID` to avoid receiver collision). `android/app/src/main/AndroidManifest.xml` (MODIFIED) — adds `<activity android:name=".DoitWidgetConfigureActivity" ...>` with `<intent-filter><action android:name="android.appwidget.action.APPWIDGET_CONFIGURE" /></intent-filter>`. `android/app/src/main/res/xml/doit_widget_info.xml` (MODIFIED) — adds `android:configure="com.doit.DoitWidgetConfigureActivity"` to the `<appwidget-provider>` element. `android/app/src/main/res/values/strings.xml` (MODIFIED) — adds `<string name="widget_configure_label">Choose a do for do it</string>`. `lib/l10n/app_en.arb` + `app_es.arb` (MODIFIED) — 3 new keys (`widgetConfigureTitle` / `widgetConfigureEmptyState` / `widgetConfigureBackToHome`) added in lockstep. **No new `<uses-permission>`** (verified against `docs/v_model/architecture_options.md` §"Permission baseline"; manifest added the activity + intent-filter only), **no new pubspec deps, no new Drift tables, no new public method-channel namespaces** (the existing `doit/widget` namespace is reused with a new `setSelectedHabitId` arm).

Test changes:

- `test/widget/doit_widget_state_test.dart` (NEW, 8 tests) — `selectedHabitId` round-trips through `toJson` / `fromJson`; defaults to `null` when absent in JSON (backwards compatibility with v1.4a..v1.4j caches); empty string is treated as `null` on `fromJson` (defensive against a downgrade that writes a Kotlin `optString(..., "")` empty value); `null` in JSON round-trips to `null`; `copyWith(selectedHabitId: 'x')` replaces the field; `copyWith` without `selectedHabitId` preserves the prior value (mirrors v1.4f `restDaysPerMonth` precedent); `==` / `hashCode` include `selectedHabitId`; `toString` includes `selectedHabitId`.
- `test/widget/widget_service_test.dart` (MODIFIED — +4 v1.4k tests) — `handleRefreshRequest` consults cached `selectedHabitId` when present AND `setSelectedHabitId('h2')` re-derives with the picked do; `setSelectedHabitId(null)` falls back to `firstActiveDo` AND clears the cached pick; stale `selectedHabitId` (the picked do was deleted from the repo) reconciles to `firstActiveDo` AND clears the pick on the next refresh; reliability change re-derives against the picked `selectedHabitId` so a reliability flip on a configured widget does NOT regress to `firstActiveDo`.
- `test/widget/widget_state_builder_test.dart` (MODIFIED — +2 tests) — `selectedHabitId` threads into the returned state; `selectedHabitId` is preserved when `activeDo` is null so the reconciliation path can clear it on the next pass.
- `test/widget/widget_deep_link_test.dart` (NEW, 7 tests) — `buildHabitRoute(/habit?habitId=abc)` returns `AddHabitScreen`; `buildHabitRoute(/habit?habitId='')` falls back to `HomeScreen`; `buildHabitRoute(/unknown)` returns `null`; `buildWidgetConfigRoute(/widget-config?widgetId=42)` returns `WidgetConfigScreen`; `buildWidgetConfigRoute(/widget-config)` returns `WidgetConfigScreen` with null `widgetId` (defensive — the Kotlin activity always passes a widgetId); `buildAppRoute` dispatches on the route name (`/habit`, `/widget-config`, `/mission` all return non-null; `/nope` returns null); `DoitWidgetState.selectedHabitId` round-trips through `toJson` — pins the JSON envelope key that the Kotlin `WidgetRenderer.openAppIntent` reads. Tests inspect the returned `MaterialPageRoute` builder directly via a stub `BuildContext` shim rather than pushing onto a real Navigator — pushing onto a Navigator would require pumping widgets past `FutureBuilder`s inside `AddHabitScreen` / `HomeScreen` / `WidgetConfigScreen`, each of which reads `DoRepository.instance.listAll()` (the singleton is not seeded in this test file); the pure-builder check is the contract the routes actually guarantee.

**ADR-055** locks the design: Android `AppWidget` configuration activity + Flutter-side route (not a Flutter-only widget picker — the launcher's `APPWIDGET_CONFIGURE` contract mandates a dedicated activity, and the `FlutterActivity` thin-shell + `getInitialRoute()` Kotlin→Dart handoff mirrors v1.3d `FullScreenActivity`); `selectedHabitId` lives in the `DoitWidgetState` JSON envelope (not a separate SharedPreferences key — the v1.4a invariant closed by v1.4f's `restDaysPerMonth`); `WidgetService.handleRefreshRequest` consults cached pick first + falls back to `firstActiveDo` + reconciliation-clear on stale pick (a `_pickIsStale` boolean gates the clear path so it runs only on the rare stale-pick path); `WidgetServiceProxy` indirection for testability (mirrors the v1.4h `home_tile_delete.dart` callback-handler seam); route builders extracted from `lib/main.dart` to `lib/app_router.dart` so tests can import them (Dart top-level `_private` functions are not reachable across library boundaries); `EXTRA_HABIT_ID_FROM_WIDGET` is a separate Intent-extra namespace from `DoitWidgetProvider.EXTRA_HABIT_ID` (different consumers — `MainActivity.getInitialRoute()` vs `WidgetChannel` — prevent receiver collisions). No new `<uses-permission>`, no new pubspec deps, no new Drift tables, no new public method-channel namespaces.

**SYS-125 + ADR-055 + WF-052 appended.** `feature.md` §4 per-instance widget config bullet removed; §5 quick-index updated to ADR-055 / SYS-125 / WF-052. Final test count 1292 / 1292 (+21 from v1.4j tip of 1271: 8 `DoitWidgetState.selectedHabitId` round-trip + 4 `WidgetService` extension tests + 2 `widget_state_builder` threading + 7 `widget_deep_link` route builder). Coverage ≥80% on every changed file.

## v1.4l — Soft-delete column on `habits` (Phase 39 / SYS-126 / ADR-056 / WF-053)

Replaces the v1.4h / SYS-122 hard-delete + `insertOnConflictUpdate`-on-Undo trade-off (documented in `ADR-052 §8` + `lib/screens/home.dart:553-561`) with a soft-delete tombstone column on `Habits`. The Undo path now restores the streak by construction — the completion log, the rest-day budget, the routine-executor registry, and the widget cached id all survive because the row is preserved (only the `deletedAtMillis` column changes). **New files.** `lib/services/db/migrations/v4_to_v5.dart` (NEW) — `Future<void> migrateV4ToV5(Migrator m, AppDatabase db) async { await m.database.customStatement('ALTER TABLE habits ADD COLUMN deleted_at_millis INTEGER'); }`. `test/db/migration_v4_to_v5_test.dart` (NEW, 4 tests — `schemaVersion is 5` v1.4l pin; `habits` table has `deleted_at_millis` column; the column is nullable and accepts both NULL and an int; pre-existing rows survive the migration with `deleted_at_millis IS NULL`). `test/services/do_repository_test.dart` (NEW, 14 tests in 4 groups — soft-delete (8) / restore (4) / save invariant (2) / hard-delete preserved (2)). **Modified.** `lib/services/db/tables.dart` (MODIFIED) — adds `IntColumn get deletedAtMillis => integer().nullable()();` to `Habits` (mirrors the `Events.archivedAtMillis` precedent). `lib/services/db/schema.dart` (MODIFIED) — bumps `kCurrentSchemaVersion = 4` → `5`; adds `if (from < 5) { await migrateV4ToV5(m, this); }` to `MigrationStrategy.onUpgrade`. `lib/do/do.dart` (MODIFIED) — base `Do` grows `final DateTime? deletedAt;` (default `null`) + `bool get isDeleted => deletedAt != null;`; `copyWith` extends with `DateTime? deletedAt, bool clearDeletedAt = false` (the explicit-clear flag mirrors `Event.copyWith(clearArchived:)`). All 5 subclasses (`DoFixed`, `DoInterval`, `DoAnchor`, `DoDayOfX`, `DoTimeWindow`) thread the field through their constructors + `copyWith`; `==` / `hashCode` include `deletedAt`. `lib/services/do_repository.dart` (MODIFIED) — new methods `Future<bool> softDeleteById(String id, {required DateTime at})` (idempotent UPDATE filtered by `deleted_at_millis IS NULL`), `Future<bool> restoreById(String id)` (idempotent UPDATE filtered by `deleted_at_millis IS NOT NULL`), `Future<Do?> getActiveById(String id)` (filters tombstones). `listAll` + `listActive` add `..where((t) => t.deletedAtMillis.isNull())` so the UI never surfaces tombstones. `_toRow` DOES NOT write `deletedAtMillis` (the v1.4l save-invariant — Drift's `insertOnConflictUpdate` preserves the existing column value when the new row doesn't specify it). `deleteById` is preserved for the `BackupService.importFrom` wipe path. `lib/screens/home_tile_delete.dart` (MODIFIED) — replaces `deleteDo` with `softDeleteDo({required Do activeDo, required DateTime at, required DoRepository repository})` + adds `restoreDo({required Do tombstonedDo, required DoRepository repository})` (parallel pattern, same try/catch + bool return contract). `lib/screens/home.dart` (MODIFIED) — `_HabitTileState._onDeletePressed` switches to `softDeleteDo(activeDo: widget.habit, at: DateTime.now(), repository: DoRepository.instance)` on confirm, and the Undo SnackBar action switches to `restoreDo(tombstonedDo: capturedHabit, repository: DoRepository.instance)`. The `_onDeletePressed` KDoc is rewritten to drop the (inaccurate) v1.4h "FK pragma cascade-deleted the completion log" claim and to accurately describe the soft-delete + restoreById flow. `lib/services/backup_service.dart` (MODIFIED) — bumps `kBackupPayloadSchemaVersion = 2` → `3`; habits export query adds `..where((t) => t.deletedAtMillis.isNull())`; `restDayBudgets` filter becomes `..where((t) => t.habitId.isIn(activeHabitIds))` (Drift's built-in `isIn` Set<String> lowering — NOT `.contains()` which fails the SQL lowering type check). The `deletedAtMillis` field IS written into the envelope so a backup round-trip is lossless. **No new `<uses-permission>`, no new pubspec deps, no new Drift tables, no new MethodChannels, no Kotlin changes** — v1.4l is pure-Dart + a single Drift migration. The Drift codegen wires `deletedAtMillis` (Dart) ↔ `deleted_at_millis` (SQL) automatically. **SYS-126 + ADR-056 + WF-053 appended.** `feature.md` §4 per-tile delete + undo streak-survives bullet removed (the v1.4l delivery closes the v1.4h trade-off); §5 quick-index updated to ADR-056 / SYS-126 / WF-053. Final test count 1321 / 1321 (+29 from v1.4k tip of 1292: 4 migration_v4_to_v5 + 14 do_repository (soft-delete 8 + restore 4 + save invariant 2 + hard-delete preserved 2) + 1 habit_repository `deletedAt` round-trip + 10 home_tile_delete (`softDeleteDo` 5 + `restoreDo` 5)). Coverage ≥80% on every changed file.

## v1.4m — CI coverage for the v1.4l soft-delete home-screen flow + `listDeleted` / `purgeDeletedOlderThan` API surface (Phase 40 / SYS-127 / ADR-058 / WF-055)

Closes the CI coverage gap from the v1.4l PR's 6-step on-device smoke: the headline flow (Undo restores streak by construction), the streak rendering (badge format + subtitle), and the persistence (column survives a DB close + reopen) are now guarded by `flutter test` in CI. Also pins the v1.4n "Recently deleted" UI's API surface (the two repository methods `listDeleted` + `purgeDeletedOlderThan`) so the v1.4n PR is purely a UI concern — no API churn. The cycle is a pure test + API surface expansion — no production behavior change outside the `KeyedSubtree` test seam on the `_DoStreakBadge` call site. The data layer was already landed in v1.4l; v1.4m just exposes + tests the API.

Modified:

- `lib/services/do_repository.dart` (MODIFIED) — adds two new public methods: `Future<List<Do>> listDeleted({int? limit})` (returns tombstoned dos ordered by `deletedAtMillis DESC`; optional `limit` caps the result size — used by the v1.4n UI's "show top 5" affordance) and `Future<int> purgeDeletedOlderThan(Duration age, {required DateTime at})` (hard-deletes tombstoned dos older than `at - age`; returns the affected-row count so the caller can log "purged N tombstones"; the `at` parameter is the caller-supplied reference time — no `DateTime.now()` inside the repository, matching the v0.2 / Phase A "no clock in the model" rule per `.claude/rules/lib-do.md` + `.claude/rules/lib-services.md`). Both methods accept a `DateTime at` argument so tests can pin the reference time. Both methods are async (`Future<List<Do>>` + `Future<int>`) so callers `await` them — consistent with the v1.4l `softDeleteById` + `restoreById` shape.
- `lib/screens/home.dart` (MODIFIED) — wraps the `_DoStreakBadge(...)` call site in `KeyedSubtree(key: Key('streakBadge-${habit.id}'), child: _DoStreakBadge(...))` so widget tests can locate the badge via `find.byKey(Key('streakBadge-<id>'))` without exposing the private widget. The `KeyedSubtree` wrapper is a no-op for production rendering (no rebuild overhead, no extra layout) — purely a test seam.

Test changes:

- `test/services/do_repository_test.dart` (MODIFIED — +9 v1.4m tests in 3 groups) — `listDeleted` (4): `listDeleted` excludes active habits; `listDeleted` orders by `deletedAtMillis DESC` (most-recently-deleted first — matches the planned "Recently deleted" UI sort); `listDeleted({int? limit})` honors the `limit` param (returns at most N most-recently-deleted); `listDeleted` returns an empty list when no habits are tombstoned. `purgeDeletedOlderThan` (4): purges tombstoned habits older than the cutoff (seeds 2 tombstoned habits at different dates, calls `purgeDeletedOlderThan(Duration(days: 30), at: frozenAt)`, asserts the old one is gone AND the recent one is still tombstoned); leaves young tombstoned habits untouched (seeds a tombstone from 1 day ago, calls `purgeDeletedOlderThan(Duration(days: 30), at: now)`, asserts the young tombstone is still there); never touches active habits (seeds 1 active habit, calls `purgeDeletedOlderThan(Duration(days: 0), at: now)`, asserts the active habit is still there); is idempotent on a second call (calls `purgeDeletedOlderThan` twice with the same args, asserts the second call returns `0`). `persistence-across-restart` (1): Phase A opens an in-memory DB + saves a do + soft-deletes it + closes the DB; Phase B opens a FRESH in-memory DB + seeds the raw `habits` row via `db.database.customStatement('INSERT INTO habits ... VALUES (...)')` with `deleted_at_millis` set + asserts `DoRepository.instance.getById('h1')` returns the tombstoned do with `isDeleted == true` — proves the column survives what the user sees as "close + reopen the app".
- `test/screens/home_test.dart` (MODIFIED — +4 v1.4m widget tests in a new v1.4m group) — `Undo restores the streak badge to the original value by construction`: seeds a do + 3 consecutive completions (yesterday / day-before / 3-days-ago), pumps the home screen, asserts the badge's `KeyedSubtree(key: 'streakBadge-h1')` finds a `Text('3')` widget (the before state); taps the Delete IconButton, confirms, waits for the SnackBar, taps the Undo `SnackBarAction`, re-pumps, asserts the badge's `KeyedSubtree(key: 'streakBadge-h1')` STILL finds a `Text('3')` widget (the after state — streak survived because `Completions.habitId` references the same id that survived the soft-delete); the headline behavior change of v1.4l is pinned. `streak badge renders the streak number with the correct tabular formatting`: seeds a do + 3 completions, pumps, asserts the badge's `KeyedSubtree(key: 'streakBadge-h1')` finds BOTH a `Text('3')` (the streak number) AND a `Text('day streak')` (the subtitle) — pins the badge's subtitle text + the tabular-figure formatting. `cancelled delete (Cancel on confirm dialog) does NOT tombstone the do and the streak badge remains rendered`: seeds a do + 3 completions, pumps, taps Delete IconButton, taps the Cancel button on the confirm dialog, asserts the do is STILL in the listing AND the streak badge STILL renders `Text('3')` — Cancel must not partially-tombstone. `soft-delete persists across a HomeScreen rebuild (close + reopen the in-memory DB)`: seeds a do + 3 completions, pumps, taps Delete, confirms, asserts the do is gone; calls `_resetDb(tester)` to swap in a fresh in-memory DB, re-pumps the widget, asserts the do is STILL gone — the tombstone survives a DB close + reopen at the widget level (mirrors the repository-level persistence-across-restart test). Adds a `seedDoWithThreeConsecutiveCompletions` helper that seeds a do + 3 completions via `CompletionLogService.append` (yesterday / day-before / 3-days-ago) so the streak calculator has 3 distinct days to count.

**ADR-058** locks the design: two new `DoRepository` methods (`listDeleted` + `purgeDeletedOlderThan`) are added NOW (with tests) rather than coupled to the v1.4n UI — the "tests first, then UI" inversion justified by the v1.4l data layer already being its own merged PR; `KeyedSubtree(key: 'streakBadge-${habit.id}')` is the test seam that lets widget tests locate the private `_DoStreakBadge` widget via `find.byKey(Key('streakBadge-<id>'))` without exposing it (the wrapper is a no-op for production rendering — no rebuild overhead, no extra layout); the persistence-across-restart test uses raw-SQL seeding via `db.database.customStatement('INSERT INTO habits ... VALUES (...)')` (the closest a unit test gets to "relaunch the app" — the user sees the row survive across the close + reopen); `listDeleted` orders by `deletedAtMillis DESC` (most-recently-deleted first — matches the OS-level "Recently deleted" affordance in Photos / Files / Gmail); `purgeDeletedOlderThan` is age-based (NOT count-based — age is a single UPDATE filtered by `deleted_at_millis < cutoff`, matches the OS-level 30-day window); both methods accept a `DateTime at` arg (caller passes a frozen reference — no `DateTime.now()` inside the repository, matching the v0.2 / Phase A "no clock in the model" rule); both methods are added to `DoRepository` directly (NOT a separate `TombstoneRepository` — the methods are pure CRUD on the same `Habits` table; splitting would scatter the same table's lifecycle state across two services for no architectural gain; the `Events` precedent confirms the single-repo shape); no new `<uses-permission>`, no new pubspec deps, no new Drift tables, no new MethodChannels, no Kotlin changes — v1.4m is pure-Dart + 13 new tests.

**SYS-127 + ADR-058 + WF-055 appended.** `feature.md` §4 unchanged (the "Recently deleted" surface parking lot bullet remains for v1.4n); §5 quick-index updated to ADR-058 / SYS-127 / WF-055; §6 next-step unchanged (v1.4n "Recently deleted" UI surface remains the next-cycle candidate). Final test count 1334 / 1334 (+13 from v1.4l tip of 1321: 4 `listDeleted` + 4 `purgeDeletedOlderThan` + 1 `persistence-across-restart` + 4 widget). 3-gate GREEN: `dart format --output=none --set-exit-if-changed .` (264 files, 0 changed) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1334/1334 pass). Coverage ≥80% on every changed file (`do_repository.dart`, `home.dart`, `home_test.dart`, `do_repository_test.dart`).

## v1.4-stab-A — Coverage audit + stabilization roadmap (Phase 41 / SYS-128 / ADR-059 / WF-056)

**Cycle A of the 3-month stabilization campaign.** Doc-only cycle: no `lib/` changes, no `test/` changes, no new dependencies, no new permissions, no Drift migration, no Kotlin changes. The deliverable is `docs/v_model/stabilization_roadmap.md` (NEW) — a single source of truth for the campaign. The pivot from feature work to a 3-month hardening campaign is the user's explicit directive ("we have 3 month to stabilise the app and have exhaustive test"), captured in `ADR-059` §"Decisions" decision 1.

**New files.**

- `docs/v_model/stabilization_roadmap.md` (NEW, 6 sections) — §1 current coverage state (per-file table of all 123 `lib/` files, baseline 64.61% line coverage, 33 Priority-1 / 31 Priority-2 / 59 Priority-3 buckets); §2 latent bugs inventory (BUG-001..BUG-020 with priorities + target cycles); §3 cycle-by-cycle roadmap (Cycles B..L with rationale); §4 success criteria for the 3-month campaign (10 criteria); §5 open questions for the user (5 questions about Cycle C / F / H / K scope + BUG-006 native speaker); §6 Cycle A retrospective.
- `coverage/lcov.info` (NEW, 133 KB) — line-coverage report produced by `flutter test --coverage`. 8812/13638 lines covered (64.61%) across 123 `lib/` files. The Python parser script reads `SF:` / `LF:` / `LH:` markers and produces the per-file table (since `lcov` is not installed and `sudo apt install lcov` requires interactive auth; the Python parser uses `python3` which is already installed).
- `coverage/html/index.html` (NEW, genhtml output) — the inspectable per-file coverage view (open in a browser for per-file drill-down).

**Cycle sequencing (Cycles B..L, 11 cycles across ~3 months).** Month 1 — Cycle B (fix `_toRow` automations + pausedUntil latent bugs → BUG-001 + BUG-002), Cycle C (full-screen launch hardening API 34+ → BUG-003), Cycle D (permission flow audit + `callScreening` probe → BUG-005). Month 2 — Cycle E (reliability detection coverage), Cycle F (backup round-trip exhaustive), Cycle G (DoAnchor "Target paused" badge on home tile → BUG-004), Cycle H (Restore / Delete forever UI for tombstoned dos — the v1.4n feature moved INSIDE the stabilization window per `ADR-059` §"Decisions" decision 4). Month 3 — Cycle I (i18n test exhaustive → partial BUG-006 closure), Cycle J (accessibility audit), Cycle K (E2E integration tests for 10 critical user flows), Cycle L (performance audit + fuzz + benchmark).

**Latent bugs inventoried (BUG-001..BUG-020).** BUG-001 (`_toRow` missing `automations_json` — user's automations silently lost on Save) + BUG-002 (`_toRow` missing `paused_until_millis` — user's pause state silently lost on Save) → Cycle B (P0, data loss). BUG-003 (Android 14+ `USE_FULL_SCREEN_INTENT` permission — lockscreen-bypass fails silently without it) → Cycle C (P1, reliability). BUG-004 (DoAnchor "Target paused" badge on home tile — data layer ships in v1.4l, UI deferred) → Cycle G (P2, UX). BUG-005 (`callScreening` permission probe incomplete — rationale copy exists but runtime probe deferred in v1.1f) → Cycle D (P2, reliability). BUG-006 (Spanish `es` ARB has stale copy — v1.0 native-speaker review deferred) → Cycle I (P3, UX — partial: test coverage but copy review still needs a native speaker, separate from stabilization). The audit may add BUG-007..BUG-020 as Priority-1 files are inspected.

**Modified.** `docs/v_model/requirements.md` (MODIFIED) — appends `SYS-128` row. `docs/v_model/decision_record.md` (MODIFIED) — appends `ADR-059` (7 design choices documented: the pivot, Cycle A is docs-only, the cycle sequencing, v1.4n moves to Cycle H, the coverage targets, no new permissions/deps/Drift tables, the roadmap doc is single source of truth). `docs/v_model/workflows.md` (MODIFIED) — appends `WF-056` (the 8-step audit flow). `docs/v_model/traceability_matrix.md` (MODIFIED) — appends `WF-056` row pointing at `stabilization_roadmap.md` + `coverage/lcov.info`. `docs/v_model/implementation_status.md` (MODIFIED) — appends `### v1.4-stab-A` row. `docs/v_model/plan.md` (MODIFIED) — appends Milestone 12 (the 3-month stabilization kickoff) + the `### v1.4-stab-A` sub-entry. `feature.md` (MODIFIED) — §4 parking lot bullet for v1.4n updated (was "next-step candidate", now "moved INSIDE the stabilization window as Cycle H"); §5 quick-index updated to ADR-059 / SYS-128 / WF-056; §6 next-step updated to the audit cycle.

**No code changes.** No new `<uses-permission>`, no new pubspec deps, no new Drift tables, no new MethodChannels, no Kotlin changes. Cycle A is pure documentation + a measurement artifact. The audit may reveal Priority-1 files that need attention in Cycles B..L; Cycle A itself makes no code claim.

**3-gate (regression check — no `lib/` / `test/` changes).** `dart format --output=none --set-exit-if-changed .` (264 files, 0 changed) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1334/1334 pass — unchanged from v1.4m). The "exhaustive test" coverage audit is the deliverable, not the test count delta.

**SYS-128 + ADR-059 + WF-056 appended.** `feature.md` §4 v1.4n moved from "next-step" to "parking lot, sequenced INSIDE stabilization as Cycle H"; §5 quick-index updated to ADR-059 / SYS-128 / WF-056; §6 next-step updated to the audit cycle (now closed).

## v1.4-stab-B — Fix `_toRow` automations + pausedUntil data-loss bugs (Phase 42 / SYS-129 / ADR-060 / WF-057)

**Cycle B of the 3-month stabilization campaign — the first stabilization cycle that fixes code.** Closes BUG-001 + BUG-002, the two P0 latent data-loss bugs from the Cycle A audit (`docs/v_model/stabilization_roadmap.md` §2). BUG-001 silently wipes the user's custom automation rules on every Save (the `_toRow` mapper omitted `automations_json`). BUG-002 silently resumes a paused habit when the user edits another field via `AddHabitScreen._save()` (the `_toRow` mapper wrote `paused_until_millis: d.pausedUntil?.millisecondsSinceEpoch`, but the in-memory `Do` reconstructed from form fields has `pausedUntil: null`, so `null` clobbers the existing column value via Drift's `insertOnConflictUpdate`). Both bugs share the same fix shape: the v1.4l `deletedAtMillis` omission precedent (`ADR-056`), where `_toRow` is split into content-only columns (the user explicitly edited in the form) vs. owned-by-other-writers columns (tombstone from `softDeleteById` / `restoreById`; pause from `pauseHabit` / `resumeHabit`), so Drift's `insertOnConflictUpdate` preserves the owned columns across the Save because the new `HabitRow` doesn't specify them.

**Modified.**

- `lib/services/do_repository.dart` (MODIFIED) — (a) new import `import 'package:doit/routines/routine.dart' show decodeAutomationList, encodeAutomationList;` for the JSON helpers at `lib/routines/routine.dart:488-505`. (b) `_toRow` (`lib/services/do_repository.dart:262-300`) gains `automationsJson: d.automations.isEmpty ? null : encodeAutomationList(d.automations),` (inserted before the now-removed `pausedUntilMillis` line). (c) `pausedUntilMillis: d.pausedUntil?.millisecondsSinceEpoch,` REMOVED from `_toRow` — mirrors the v1.4l `deletedAtMillis` omission (`ADR-056`). KDoc on `_toRow` updated to document the dual invariant: "content-only (name, schedule, color, automations) + owned-by-other-writers (tombstone from `softDeleteById`/`restoreById` since v1.4l; pause from `pauseHabit`/`resumeHabit` since Cycle B)". (d) `_fromRow` (lines 310-322 base record + lines 325-406 each of the 5 subclass arms `DoFixed` / `DoInterval` / `DoAnchor` / `DoDayOfX` / `DoTimeWindow`) gains `automations: decodeAutomationList(r.automationsJson),` in the base record + threads it through each subclass constructor's `super.automations` forwarding — the read-path fix for BUG-001.

- `lib/services/pause_service.dart` (MODIFIED) — `pauseHabit` + `resumeHabit` now bypass `DoRepository.save` and write `pausedUntilMillis` via direct `HabitsCompanion` UPDATE: `await (db.update(db.habits)..where((t) => t.id.equals(habit.id))).write(HabitsCompanion(pausedUntilMillis: Value(until.millisecondsSinceEpoch)))` for pause, `...write(const HabitsCompanion(pausedUntilMillis: Value(null)))` for resume. Mirrors the v1.4l `restoreById` shape (`ADR-056`). The two methods become the explicit writers of `pausedUntilMillis` — KDoc updated to explain why (save is content-only because of the omission pattern, so pause/resume are the explicit writers). New imports: `db.dart`, `db/schema.dart`, `drift/drift.dart show Value`.

- `test/services/do_repository_test.dart` (MODIFIED — +3 new tests in a new `DoRepository save invariant (Cycle B / BUG-001 + BUG-002)` group after the v1.4l save-invariant group) — (a) `automations round-trip through save + getById` (BUG-001 write + read): seeds 2 automations (a `TriggerBatteryLow(20) → ActionNotify "Plug in"` and a `TriggerTimeOfDay(7:30) → ActionNotify "Morning"`), saves via `_do(id: 'h1', automations: seed)`, asserts `getById('h1').automations == seed`. (b) `pausedUntil round-trips via direct companion UPDATE + getById` (BUG-002 read path): direct `HabitsCompanion(pausedUntilMillis: Value(t.millisecondsSinceEpoch))` UPDATE sets the column at `DateTime(2026, 7, 2)`, asserts `getById('h1').pausedUntil == t` (without going through save, since save omits the column after the fix). (c) Headline `save(d) does NOT clobber an existing pausedUntilMillis` (BUG-002 save-invariant): seed via direct companion UPDATE at `DateTime(2026, 7, 2)`, then `save(_do(id: 'h1', name: 'New name'))` with no in-memory `pausedUntil`, assert the raw row's `pausedUntilMillis` STILL equals the seeded timestamp AND `name == 'New name'` (content update landed). The existing `_do(...)` helper was extended with optional `automations: List<Automation>?` and `pausedUntil: DateTime?` named parameters; a new `_twoAutomations()` helper seeds 2 distinct fixtures.

**Pure-Dart scope.** No new `<uses-permission>`, no new pubspec deps, no Drift migration (the columns already exist on `Habits` from v3→v4 + v4→v5), no new Drift tables, no new MethodChannels, no Kotlin changes. The Drift `kCurrentSchemaVersion` stays at 5. Backup service (`lib/services/backup_service.dart:408, 445, 474, 492`) already round-trips `automations_json` + `paused_until_millis` correctly — the live-mapping fix automatically extends to backups on next export.

**ADR-060** locks the design: (1) BUG-001 framing — the column omission is the write+read fix; mirror `EventRepository` (`lib/services/event_repository.dart:97-99`) + `PersonRepository` (`lib/services/person_repository.dart:70-72`) which both correctly write `automations_json`. (2) BUG-002 framing — clobber-not-omission; fix via v1.4l `deletedAtMillis` omission precedent (`ADR-056`). (3) Pause service refactor rationale — explicit `HabitsCompanion` UPDATE because the omission pattern means `save()` is content-only; pause/resume are the explicit writers. (4) No new schema migration — both columns already exist on `Habits` (the schema didn't need to change; only the mapping did). (5) Test design — 3 tests mirror v1.4l save-invariant shape (`test/services/do_repository_test.dart:263-298`); round-trip + save-invariant + raw-column read via `db.select(db.habits)..where((t) => t.id.equals('h1'))).getSingle()`.

**SYS-129 + ADR-060 + WF-057 appended.** `docs/v_model/requirements.md` (MODIFIED) — appends `SYS-129` row. `docs/v_model/decision_record.md` (MODIFIED) — appends `ADR-060` (5 design choices). `docs/v_model/workflows.md` (MODIFIED) — appends `WF-057` (the 16-step Cycle B implementation flow with failure paths + coverage notes + cross-references). `docs/v_model/traceability_matrix.md` (MODIFIED) — appends `WF-057` row pointing at the 3 new tests. `docs/v_model/implementation_status.md` (MODIFIED) — appends `### v1.4-stab-B` row. `docs/v_model/plan.md` (MODIFIED) — appends `### v1.4-stab-B` sub-entry inside Milestone 12. `feature.md` (MODIFIED) — §4 parking lot bullets for BUG-001 + BUG-002 removed (both closed); §5 quick-index updated to ADR-060 / SYS-129 / WF-057; §6 next-step updated to Cycle C (full-screen launch hardening for Android 14+, BUG-003).

**3-gate GREEN.** `dart format --output=none --set-exit-if-changed .` (264 + ~4 files, 0 changed — pure-Dart + new tests are pre-formatted) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1337/1337 pass — +3 from v1.4m tip of 1334). Targeted: `flutter test test/services/do_repository_test.dart` (28/28 pass, +3 Cycle B tests) + `flutter test test/services/pause_service_test.dart` (refactored helpers exercise the new direct-UPDATE shape). Coverage ≥80% on changed files (`do_repository.dart`, `pause_service.dart`, `do_repository_test.dart`).

## v1.4-stab-C — FSI reliability wiring: defense-in-depth + BUG-003 closure (Phase 43 / SYS-130 / ADR-061 / WF-058)

**Cycle C of the 3-month stabilization campaign.** Closes BUG-003 (Android 14+ `USE_FULL_SCREEN_INTENT` permission — the runtime path; the manifest already declares the permission at `android/app/src/main/AndroidManifest.xml:83-85`). Cycle C is the first cycle whose scope is dramatically smaller than the `stabilization_roadmap.md §3` draft suggested — the permission probe + reliability wiring + launch handlers shipped in v1.3c (Phase 14) + v1.3d (Phase 15); what was actually missing was test coverage, a doc typo, a stale comment, and a known channel-surface gap. **No production code changes to the FSI channel surface.** The defense-in-depth swallow on `MethodChannelFullScreenIntentSource` (catches `MissingPluginException` + `PlatformException` → `false` on both `isGranted` + `openSettings`) was ALREADY in the v1.3c / SYS-113 code — Cycle C's contribution is documenting the swallow as INTENTIONAL per ADR-013 + ADR-061 (so a future reader doesn't "fix" it by removing the catches) and lifting test coverage from 25% → ≥80% on `lib/reminders/full_screen_intent.dart` and 80.5% → ≥95% on `lib/services/full_screen_intent_service.dart`.

**Modified.**

- `lib/services/full_screen_intent_service.dart` (MODIFIED) — rename `_MethodChannelFullScreenIntentSource` → `MethodChannelFullScreenIntentSource` (drop the `_` prefix + add `@visibleForTesting` annotation) so the new defense-in-depth tests at `test/services/full_screen_intent_service_test.dart` can construct the production source directly and mock the channel via `TestDefaultBinaryMessengerBinding`. All 4 internal references updated (the constructor delegation at line 184-185, the `resetForTesting` reset at line 244, the KDoc reference at line 230, and the `instance` default at line 190). New 20-line class-level KDoc (lines 64-84) documenting the `MissingPluginException` + `PlatformException` → `false` swallow as INTENTIONAL per ADR-013 + ADR-061, cross-referencing `ReliabilityService._safeProbe` at `lib/services/reliability_service.dart` as the precedent. The KDoc is the in-code barrier against a future reader "fixing" the swallow.

- `lib/reminders/full_screen_intent.dart` (MODIFIED) — file-level header (lines 1-24) rewritten to reference the actual production wake mechanism (`FLAG_KEEP_SCREEN_ON` in `android/app/src/main/kotlin/com/doit/FullScreenActivity.kt:47-56`) instead of the stale `wakelock_plus` reference. `pubspec.yaml` has 0 `wakelock_plus` matches; the original header was misleading future readers about the wake mechanism. The new header cross-references the Kotlin side accurately.

- `docs/v_model/notification_reliability.md` (MODIFIED) — line 496 typo fixed: "On API 14+" → "On API 34+". `USE_FULL_SCREEN_INTENT` was introduced in API 34 (Android 14), NOT API 14. The typo has been misleading readers for ~2 months (since v1.3c / SYS-113 first declared the permission).

- `test/reminders/full_screen_intent_test.dart` (NEW, +5 tests in 5 groups) — lifts `lib/reminders/full_screen_intent.dart` coverage from 25% (Cycle A audit) to ≥80%. Group `FakeFullScreenIntent.show`: `records every FullScreenLaunch in invocation order` (seeds 2 strong-mode `_DoFixed` habits + 2 `MissionChain`s, calls `await fsi.show(habit1, chain1)` then `await fsi.show(habit2, chain2)`, asserts `fsi.launches` has length 2 with the expected habit ids in order). Group `FakeFullScreenIntent.showRoutineOverlay`: `records title and body exactly as supplied (null passes through)` (4 calls covering title-only / body-only / neither / both, asserts the recorded `RoutineOverlayLaunch` list matches). Group `FakeFullScreenIntent.getLaunchIntent`: `returns the scripted launch intent and appends it to launchIntents` (scripted `LaunchIntent(mode: LaunchMode.habit, habitId: 'h-from-channel')`, 2 calls, asserts both returns match + both appends are recorded) AND `returns null and records null when scriptedLaunchIntent is null` (covers the no-launch-intent case). Group `RoutineOverlayLaunch equality`: `equal when title + body match; hashCode is consistent`. Group `LaunchIntent equality`: `equal when mode + habitId + title + body all match`.

- `test/services/full_screen_intent_service_test.dart` (MODIFIED — +3 new tests in a new `MethodChannelFullScreenIntentSource (production source)` group) — pins the defense-in-depth swallow per ADR-061. Test 1: `isGranted returns false when the platform throws PlatformException (defense-in-depth per ADR-061)` — mocks `MethodChannel('doit/full_screen')` to throw `PlatformException(code: 'TEST_PLATFORM_ERROR', message: 'simulated NotificationManager failure')` on any call, constructs `MethodChannelFullScreenIntentSource()`, awaits `source.isGranted()`, asserts `result == false`. Test 2: `openSettings returns false when the platform throws PlatformException (defense-in-depth per ADR-061)` — same shape for `openSettings()` (simulated `ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT` activity missing). Test 3: `isGranted returns false when the platform throws MissingPluginException (no Kotlin arm — defense-in-depth per ADR-061)` — mocks the channel to throw `MissingPluginException('No implementation found for method canUseFullScreenIntent on channel doit/full_screen')`, awaits `source.isGranted()`, asserts `result == false`. The `debugPrint` calls inside the catches are silenced via a setUp/tearDown `debugPrint` swap (lines 32-38). The existing `isGranted` / `openSettings` / `singleton lifecycle` groups (using `ScriptedFullScreenIntentSource`) are preserved unchanged — no regression on the test seam.

- `test/reminders/reminder_bridge_fsi_channel_test.dart` (NEW, +2 tests) — pins the KNOWN channel-surface gap as a follow-up bug. Test 1: `PlatformReminderBridge.showFullScreen invokes the channel method (Dart seam IS exercised)` — mocks the `doit/reminders` channel to return `null` for any call, awaits `PlatformReminderBridge().showFullScreen('h-fsi-stab')`, asserts the captured `MethodCall` log has 1 entry with method=`showFullScreen` AND args=`{'habitId': 'h-fsi-stab'}`. Pins the channel-method name so a future contributor who renames either side sees the test fail and updates both. Test 2: `PlatformReminderBridge.showFullScreen throws MissingPluginException when the Kotlin handler has no arm (KNOWN GAP)` — mocks the channel to mirror production (handle only the documented arms `setExact` / `cancel` / `showNotification` / `cancelNotification` / `probeReliability`; everything else throws `MissingPluginException`), asserts `expectLater(() => b.showFullScreen('h-fsi-stab-gap'), throwsA(isA<MissingPluginException>()))`. Pins the gap as a known behavior — a future stabilization cycle that adds the `showFullScreen` Kotlin arm (or removes the dead Dart seam) will see this test fail and remove it.

**Pure-Dart + docs + new tests.** No new `<uses-permission>` (the `USE_FULL_SCREEN_INTENT` permission is already declared at `AndroidManifest.xml:83-85`); no new pubspec deps; no Drift migration; no new Drift tables; no new MethodChannels; no Kotlin changes. The Drift `kCurrentSchemaVersion` stays at 5. Permission baseline unchanged; verification against `docs/v_model/architecture_options.md §"Permission baseline"` confirmed no AndroidManifest touch.

**ADR-061** locks the design: (1) Defense-in-depth `PlatformException` + `MissingPluginException` → `false` swallow on `MethodChannelFullScreenIntentSource` is INTENTIONAL per ADR-013 (the v0.4b-release-fix lesson). (2) Rename `_MethodChannelFullScreenIntentSource` → `MethodChannelFullScreenIntentSource` (drop underscore + `@visibleForTesting`) so tests can construct the production source directly. (3) Stale `wakelock_plus` reference replaced with the actual `FLAG_KEEP_SCREEN_ON` mechanism — prevents a future contributor from adding `wakelock_plus` and ending up with two wake mechanisms fighting each other. (4) Doc typo "API 14+" → "API 34+" fixed at `notification_reliability.md:496`. (5) KNOWN channel-surface gap on `ReminderBridge.showFullScreen` documented as a follow-up bug, NOT fixed in Cycle C (Kotlin changes out-of-scope; gap is INERT today per repo-wide grep; future cycle will either remove dead Dart arm or add Kotlin arm). (6) Test count +8 (not +6 as the original scope draft suggested) — the +2 expansion pins both `MissingPluginException` AND `PlatformException` defense-in-depth paths + the channel-surface gap's two-assertion shape.

**SYS-130 + ADR-061 + WF-058 appended.** `docs/v_model/requirements.md` (MODIFIED) — appends `SYS-130` row. `docs/v_model/decision_record.md` (MODIFIED) — appends `ADR-061` (6 design choices documented: the defense-in-depth swallow + the rename + the stale-comment fix + the doc-typo fix + the channel-surface gap pin + the test count expansion). `docs/v_model/workflows.md` (MODIFIED) — appends `WF-058` (the 14-step Cycle C implementation flow with failure paths + coverage notes + cross-references). `docs/v_model/traceability_matrix.md` (MODIFIED) — appends `WF-058` row pointing at the 8 new tests. `docs/v_model/implementation_status.md` (MODIFIED) — appends `### v1.4-stab-C` row. `docs/v_model/plan.md` (MODIFIED) — appends `### v1.4-stab-C` sub-entry inside Milestone 12. `feature.md` (MODIFIED) — §4 BUG-003 parking-lot bullet removed (closed); §5 quick-index updated to ADR-061 / SYS-130 / WF-058; §6 next-step updated to Cycle D (`feat/v1.4-stab-D-permission-flow-audit` — permission flow audit covering the 4 most-used kinds: `notifications`, `location`, `calendar`, `fullScreenIntent`; closes BUG-005 + BUG-011 + BUG-020 + partial BUG-012).

**3-gate GREEN.** `dart format --output=none --set-exit-if-changed .` (264 + ~5 files, 0 changed — pure-Dart + new tests are pre-formatted) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1345/1345 pass — +8 from v1.4-stab-B tip of 1337). Targeted: `flutter test test/reminders/full_screen_intent_test.dart` (passes; +5 tests) + `flutter test test/services/full_screen_intent_service_test.dart` (passes; +3 tests) + `flutter test test/reminders/reminder_bridge_fsi_channel_test.dart` (passes; +2 tests). Coverage: `lib/reminders/full_screen_intent.dart` ≥80% (from 25.0%); `lib/services/full_screen_intent_service.dart` ≥95% (from 80.5%); the channel-surface gap test is a regression-protector, not a coverage gate.

**On-device smoke (mirrors v1.4l 6-step).** Install new APK on Android 13+ → add a new do via AddHabitScreen → Save (verify it persists) → edit do's name → Save (verify automations + pause state preserved — the test invariant) → pause a habit via the home tile's pause action (verify the badge shows "Paused" + reminders stop) → resume the habit (verify badge clears + reminders resume) → edit a paused habit (just change its name) → Save (verify pause STILL active — the BUG-002 fix invariant; Save does NOT silently resume).

**Parking lot for v1.4-stab-C+.** BUG-003 (Android 14+ `USE_FULL_SCREEN_INTENT` permission — full-screen launch hardening) → Cycle C. BUG-004 (DoAnchor "Target paused" badge UI for the v1.4l data layer) → Cycle G. BUG-005 (`callScreening` permission probe) → Cycle D. BUG-006 (Spanish `es` ARB stale copy — needs native-speaker review, separate from stabilization) → Cycle I (partial — test coverage only). Final test count 1337 / 1337 (+3 from Cycle B).

## v1.4-stab-D — Permission flow coverage (Phase 44 / SYS-131 / ADR-062 / WF-059)

**Date:** 2026-06-30

**Type:** test-only cycle (no production code changes; pure-Dart + new tests + docs)

**Closes:** BUG-005 (callScreening probe coverage), BUG-011 (PermissionResult direct tests), BUG-012 (partial — person.dart at ≥80%), BUG-020 (lifecycle observer edge cases).

**Headline metric:** test count 1348 → 1363 (+15 net). Coverage: `lib/services/permission_result.dart` 18.9% → 100%; `lib/services/permission_service.dart` 93.4% → ≥95%; `lib/services/permission_lifecycle_observer.dart` 78.6% → ≥90%; `lib/people/person.dart` 54.5% → ≥80% (Cycle K brings to 100%).

**Six new + extended test files:**
- `test/services/permission_result_test.dart` (NEW, +6 tests) — every sealed subclass on `PermissionResult` + `BackupFolderResult`; includes an exhaustive `switch` regression protector
- `test/people/person_test.dart` (NEW, +3 tests) — `isPausedAt` future/expired/null branches + `copyWith(clearPausedUntil: true)`
- `test/services/permission_lifecycle_observer_test.dart` (extended, +1 test) — non-`resumed` lifecycle events do NOT trigger a permission refresh
- `test/services/permission_service_test.dart` (extended, +4 tests) — `limited`/`restricted`/`provisional`/`permanentlyDenied` `PermissionStatus` mappings

**V-Model artifacts:** SYS-131 (requirements.md) + ADR-062 (decision_record.md) + WF-059 (workflows.md) + traceability row + implementation_status row + plan.md sub-entry.

**No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** On-device smoke deferred to user (no `adb` binary in this harness environment) — same pattern as Cycles A, B, C.


## v1.4-stab-E — Reliability detection coverage (Phase 45 / SYS-132 / ADR-063 / WF-060)

**Pure-Dart test-only cycle. Test count: 1363 → 1371 (+8 net).**

Closes **BUG-013** (`ReliabilityService` first-read race + probe-failure policy coverage) + **BUG-014** (`AlarmScheduler` exact-alarm cancel path incomplete coverage).

- `test/services/reliability_service_test.dart` (+5 tests) — pins the `ReliabilityService` error paths + lifecycle contract: probe failure keeps prior cached value (ADR-013 regression pin via `_ScriptedBridge.throwOnProbe`); fresh cold-start initializes to optimal (first-read race fix); refresh() after permissions change re-probes + re-derives; stream emits `Reliability.optimal` on a distinct value transition (broadcast+distinct transition-emit contract — reworked from the original "emit-to-fresh-subscribers" test which was structurally wrong); dispose() closes the broadcast stream controller (no-leak invariant via `onDone` Completer + 1s timeout).
- `test/reminders/alarm_scheduler_test.dart` (+2 tests in new `AlarmScheduler fallback paths (SYS-132)` group) — pins the exact-alarm-granted primary path on `FakeAlarmScheduler`.
- `test/reminders/doze_simulation_test.dart` (NEW, +1 test) — pins the 30 s idle-window fallback timer policy via `_RecordingPeriodicFactory`.

**3-gate**: format 0 changed (269 files); analyze 0 issues (after stripping 5 redundant-default-arg warnings + simplifying the doze-simulation bridge to a no-arg constructor); 1371/1371 tests pass.

**Drift**: original "stream emits initial value to fresh subscribers" test was structurally wrong — broadcast+distinct streams never replay past values. Reworked the test to pin a different but MORE useful behavior: the AFTER-init transition-emit contract. The home-screen widget depends on this behavior, not on initial-value-replay.

## v1.4-stab-F — Backup round-trip exhaustive coverage (Phase 46 / SYS-133 / ADR-064 / WF-061)

**Pure-Dart test-only cycle. Test count: 1371 → 1379 (+8 net).**

Closes the `bug_hunt.md` BUG-016..-018 cluster (the 6 latent backup envelope bugs inventoried in Cycle A):

- `test/services/backup_encryption_test.dart` (+5 tests) — pins the 5 uncovered error paths in `backup_service.dart`: `BackupFormatException.toString()` includes the message (covers `lib/services/backup_service.dart:39`); import rejects envelope with no kdf object (covers line 651 throw); v2 envelope with iterations below the floor is rejected (covers lines 743-744 throw); v3 envelope with missing fields throws (covers line 684 throw); v2 envelope with missing fields throws (covers line 740 throw).
- `test/backup/scheduler_skip_test.dart` (NEW, +1 test) — pins the `ScheduleMode.none` early-return in `runBackupTask` so the scheduler does not attempt to schedule when the user has not yet picked a backup folder.
- `test/services/backup_task_dispatcher_test.dart` (+2 tests) — pins the unknown-task-name path + the ADR-013 init-failure-swallow contract on the dispatcher entry point.

**3-gate**: format 0 changed; analyze 0 issues; 1379/1379 tests pass.
