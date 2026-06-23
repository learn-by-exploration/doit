# do it — Changelog

All notable changes to the do it app are documented here. do it
follows a V-Model process: each release has a left-side baseline
(`docs/v_model/v<major>_<minor>_baseline.md`) and a right-side
checklist (`v<major>_<minor>_release_checklist.md`). This changelog
is the user-facing summary of what shipped in each release; the
V-Model artifacts are the engineering contract.

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
