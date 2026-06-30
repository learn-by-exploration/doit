# Notification Reliability

Status: draft baseline, created 2026-06-13.

Reminders are the product. If they fire late, the user loses trust
in two days and never comes back. This document is the spec for
how do it fights Doze, App Standby, OEM battery savers, and
Android 12+'s `SCHEDULE_EXACT_ALARM` gating.

## Goals

- A scheduled reminder fires within **±60 seconds** of its target
  time on a non-Doze device.
- A scheduled reminder fires within **±15 minutes** of its target
  time on a Doze device, unless the user has whitelisted the app.
- A scheduled reminder survives a device reboot, a timezone
  change, and a DST transition with no duplicates and no drops
  (modulo the "DST jumps forward" edge case documented below).
- The user understands what they need to do (one-tap deep link)
  when an OEM or the OS would otherwise kill the alarms.

## Layers of defense

do it uses five layers, in order. Each one is verified by a test
or a manual check.

### Layer 1 — Exact alarm (primary)

The primary scheduling primitive is `AlarmManager.setExactAndAllowWhileIdle`.
This bypasses Doze for the alarm's broadcast. The Flutter side
uses `android_alarm_manager_plus` to call into this API from
Dart.

```dart
// lib/reminders/alarm_scheduler.dart (sketch)
Future<void> scheduleNext(Habit h) async {
  final next = h.schedule.nextOccurrence(DateTime.now());
  await AndroidAlarmManager.oneShotAt(
    // The receiver in Kotlin that wakes the Flutter side.
    AlarmId.fromHabit(h),
    next,
    // Exact alarm: fires even in Doze.
    exact: true,
    allowWhileIdle: true,
    // Reschedule: handled in the receiver.
    rescheduleOnReboot: true,
  );
}
```

**Verification.**
- Unit test: `test/reminders/alarm_scheduler_test.dart` — the
  computed `nextOccurrence` is correct for each schedule type
  and edge case (DST, timezone, leap second).
- Integration test: schedule a 5-second-out alarm in a debug
  build, observe it fires within 1 second.
- Manual device check: schedule a 1-minute-out alarm, observe
  it fires.

### Layer 2 — WorkManager fallback (degraded)

If exact alarm is denied (Android 12+ `SCHEDULE_EXACT_ALARM`
gating) or if the device is in Doze without whitelist, the app
falls back to `WorkManager` periodic + one-shot. WorkManager
runs in a maintenance window every ~15 minutes in Doze; the
reminder fires within that window.

The scheduler detects the denial and switches modes silently.
A small badge on the home screen ("may be late") tells the user.

**Verification.**
- Integration test: simulate exact-alarm denial, schedule via
  WorkManager, observe the reminder fires within 15 minutes
  (test runs for 20 minutes; this is slow but necessary).
- Manual device check: deny exact alarm, schedule a reminder,
  observe the badge.

### Layer 3 — Boot survival

A native Kotlin `BroadcastReceiver` listens for
`BOOT_COMPLETED` and `LOCKED_BOOT_COMPLETED`. On boot, it
queries the local DB and re-schedules all pending reminders.

```kotlin
// android/app/src/main/kotlin/.../BootReceiver.kt (sketch)
class BootReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
    val pending = context.pendingHabitOccurrences()
    for (occ in pending) {
      AlarmScheduler.schedule(occ)
    }
  }
}
```

`LOCKED_BOOT_COMPLETED` is preferred (Android 7+) so the
rescheduling happens before the user unlocks the phone, but
requires the receiver to be in the `android.permission.RECEIVE_BOOT_COMPLETED`
permission set.

**Verification.**
- Integration test: in a debug build, force-stop the app, then
  reboot the device. Verify all pending reminders are still
  scheduled.
- Manual device check: reboot with a reminder scheduled 1
  hour out; observe the reminder fires.

### Layer 4 — Foreground service heartbeat (optional, v0.2)

Out of scope for v0.1. If the 14-day acceptance run shows > 5%
drop rate, v0.2 adds a foreground service with a low-priority
persistent notification ("do it is keeping your reminders
accurate"). The service is purely a heartbeat — it does not
do work — and the persistent notification is the cost.

**Why deferred.** A persistent notification is a UX cost. We
want to know if it is necessary before paying it.

### Layer 5 — User-driven whitelist

The app cannot force the OS to keep its alarms alive. It can
ask the user to help. There are three asks:

1. **`SCHEDULE_EXACT_ALARM` permission.** On Android 12+, the
   app must request this. The app probes
   `SCHEDULE_EXACT_ALARM` at onboarding step 2 (SYS-065) and
   surfaces the result on the home screen reliability banner.
   If the user denies, the `Reliability.degraded` path
   activates and the Settings → Permissions tile is the
   recovery affordance — it deep-links to
   `ACTION_REQUEST_SCHEDULE_EXACT_ALARM` on
   `permanentlyDenied`. (v0.5d / ADR-016 — pre-v0.5 the probe
   was triggered on the first fixed-time-habit schedule,
   which left users who declined without a recovery
   affordance for the lifetime of the install.)

2. **Battery optimization.** On first scheduling, the app checks
   `PowerManager.isIgnoringBatteryOptimizations(packageName)`.
   If false, it shows a screen with a one-tap deep link to
   `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. If the user
   denies, the app surfaces a banner on each launch reminding
   them.

3. **OEM auto-start.** On first launch, the app detects the OEM
   (Xiaomi, Oppo, Vivo, Honor, Samsung). For aggressive OEMs,
   it shows a card with enable-auto-start instructions, with a
   deep link to the OEM's settings activity where possible.

**Verification.**
- Widget test: the permission-request screen has the right
  deep-link extras.
- Manual device check: with battery optimization on and OEM
  auto-start off, schedule a 1-minute-out reminder; observe
  it fires within 15 minutes (WorkManager fallback).
- Manual device check: with battery optimization off, schedule
  a 1-minute-out reminder; observe it fires within 1 minute
  (exact alarm).

## Trigger reliability (v1.0 / Phase C–F)

The time-of-day layers above cover the AlarmScheduler path. A
different surface owns the non-time triggers added in v1.0 —
`TriggerLocationEnter` / `TriggerLocationExit`
(Phase C PR 2 / ADR-021), `TriggerDeviceState` (Phase D),
`TriggerCalendarEvent` (Phase E), and `TriggerCallIncoming`
(Phase F). Each trigger has its own reliability story.

### Geofence (Phase C PR 2 — `geolocator`)

`GeofenceService` is a thin `Geolocator.getPositionStream(...)`
adapter. The match itself is a pure-Dart Haversine comparison
in `computeTransitions(...)` (see
`lib/services/geofence_service.dart`). The platform gives us
a position every ~25m of travel (the `distanceFilter: 25`
setting in `_GeolocatorPositionSource`).

- **Accuracy:** ±30m in cities with the coarse-location fix
  (city-block). The 50m..5000m radius bound in
  `TriggerLocation.validate()` is well above the noise floor
  of a single fix; a 200m "home" geofence is comfortably
  matched by a 30m-accurate position.
- **Latency:** enter/exit transitions fire on the next fix
  after the device crosses the boundary. In practice this is
  < 30s of travel; on a stopped device it fires on the next
  cold start of the position stream.
- **Doze behavior:** the position stream is throttled in Doze
  (the OS treats it like a sensor). When the device wakes
  for any other reason, the next fix is delivered and
  accumulated transitions fire together. This is the v0.1
  behavior; the Phase D device-state debug screen surfaces
  "stream throttled" copy when it detects the gap.
- **Permission revoke:** if the user revokes
  `ACCESS_COARSE_LOCATION` mid-flight, the platform stream
  emits a `PositionServiceException` on
  `_onPositionError(...)`. The service logs and continues —
  the next re-grant resumes the stream. A routine whose
  trigger would have fired is silently dropped; we do not
  queue. The home-screen reliability banner
  (`Reliability.degraded`) flips on when the user has at
  least one `TriggerLocation*` automation registered and
  the permission is denied, with a one-tap deep link to
  the permission settings.

### Device-state (Phase D — shipped, ADR-022)

The `DeviceStateChannel` Kotlin bridge is **reactive-first**:
it registers a `BroadcastReceiver` for the seven
device-state broadcasts the OS actually fires, and emits
a `DeviceStateSnapshot` to Dart via a `Stream` for each.
Per ADR-022, the executor never polls; the 60-second
polling slot is reserved for the Settings → Triggers
debug screen only. The seven reactive sources are:

- `ACTION_POWER_CONNECTED` / `ACTION_POWER_DISCONNECTED`
  — charging state.
- `BATTERY_LOW` / `BATTERY_OKAY` — battery-range edges.
- `ACTION_HEADSET_PLUG` — headphones.
- `BluetoothDevice.ACTION_ACL_CONNECTED` /
  `ACTION_ACL_DISCONNECTED` — paired BT device.
- `WifiManager.NETWORK_STATE_CHANGED_ACTION` — Wi-Fi SSID.
- `AudioManager.RINGER_MODE_CHANGED_ACTION` — ringer mode.

Foreground-app detection (`PACKAGE_USAGE_STATS`) is a
**best-effort** v1.0 entry; the trigger fires on the
"package was foreground" reactive broadcast, which the
OS delivers without the permission. A user who has not
granted `PACKAGE_USAGE_STATS` sees a v1.0 banner on the
debug screen but the routine still runs.

- **Latency budget:** all 7 reactive sources fire within
  ±1s of the OS broadcast (no polling drift).
- **Doze behavior:** reactive broadcasts fire even in
  Doze; if the device is in Doze the Dart isolate is
  suspended, so the next routine match runs when the
  isolate wakes. The debug screen surfaces "isolate
  asleep" copy when it detects a > 30s gap.
- **Permission revoke:** `BLUETOOTH_CONNECT` is the only
  runtime permission Phase D adds. A revoke surfaces the
  same banner pattern as coarse-location (SYS-077).

### Calendar (Phase E — shipped, ADR-023)

The `CalendarChannel` Kotlin bridge is **reactive**:
it registers a `ContentObserver` on
`CalendarContract.Instances` (the local view, no
`device_calendar` dependency). Per ADR-023, the OS calls
us back when an instance row is inserted / updated /
deleted; we match the change against the registered
`TriggerCalendarEvent` set on the main isolate. No
5-minute poll in production. The debug screen has a
"Force re-scan" button that triggers a manual scan for
parity with the original poll UX.

- **Latency budget:** sub-second from the OS notification
  to the routine dispatch (no polling jitter). The user's
  perceived latency is bounded by their calendar
  provider's sync freshness (Google Calendar syncs every
  ~15 minutes).
- **Doze behavior:** `ContentObserver` callbacks fire
  even in Doze; if the Dart isolate is suspended the
  match runs when the isolate wakes. The debug screen
  surfaces "isolate asleep" copy.
- **Permission revoke:** `READ_CALENDAR` revoke stops the
  observer entirely; the next re-grant resumes. The
  banner pattern is the same as the other permissions.

### Call-screening (Phase F — shipped, ADR-019 + 019 follow-up)

`CallInterceptor` is a Kotlin `CallScreeningService`
declared in `AndroidManifest.xml` with the
`BIND_SCREENING_SERVICE` permission and the
`ROLE_CALL_SCREENING` role. Per ADR-019, this is the
right shape for incoming-call matching and ringer-mode
override; `PhoneAccount` is for *outgoing* calls. Per
ADR-019 follow-up, the routine config lives in
`SharedPreferences` (not in `automationsJson`) because
the interceptor reads it on every call, before the Dart
isolate is warm.

- **Latency budget:** synchronous — the OS delivers the
  call event to `onScreenCall(...)` before the dialer
  sees it. The routine matches, snaps the ringer via
  `AudioManager.setRingerMode(RINGER_MODE_SILENT)` (or
  `RINGER_MODE_VIBRATE`), and returns the
  `CallResponse` with the appropriate
  `CallScreeningService.Response` flags. Sub-100ms total.
- **Role not granted:** the user may install v1.0 and
  grant `READ_PHONE_STATE` / `ANSWER_PHONE_CALLS` but
  decline the call-screening role. The interceptor
  registers as a no-op: incoming calls pass through
  untouched, the routine's notification still fires (the
  Dart `ActionNotify` arm), but the silent-mode override
  is skipped. The Settings → Permissions tile surfaces a
  "Role not granted" banner with a one-tap deep link to
  `RoleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)`.
- **Dart isolate warm-up:** the interceptor does not
  depend on the Dart isolate. The Japan routine config is
  read from `SharedPreferences` on every call.

### Full-screen access (v1.3c / Phase 14 / SYS-113)

The strong-mode interruption contract relies on the
app launching the full-screen mission screen the
moment a habit's alarm fires. On Android 14+ the OS
**suppresses** full-screen intents from background-
launched apps that do not hold `USE_FULL_SCREEN_INTENT`
— the user sees a notification instead of the full-
screen activity, defeating the contract. v1.3c ships
the probe + the deep-link + the reliability wiring so
this state is discoverable + recoverable.

**API asymmetry** (resolved on the Kotlin side; Dart is
platform-agnostic):

- **API < 32 (`S_V2`):** the permission is implicit-
  granted. Every app may launch full-screen intents.
  The probe returns `true`; no Settings activity exists
  to deep-link to (the user did not need to opt in).
- **API 32 / 33 (`TIRAMISU`):** the probe reads
  `NotificationManager.canUseFullScreenIntent()`. The
  deep-link falls back to `Settings.ACTION_APPLICATION_SETTINGS`
  (the app-info page); OEMs that surface a per-app FSI
  toggle on these API levels route the user to it from
  there.
- **API 34+ (`UPSIDE_DOWN_CAKE`):** the probe reads
  `NotificationManager.canUseFullScreenIntent()`; the
  deep-link uses
  `Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`
  which lands the user directly on the FSI toggle.

**Implementation:**

- Kotlin: `android/app/src/main/kotlin/com/doit/FullScreenIntentChannel.kt`
  — owns the `doit/full_screen` MethodChannel, exposes
  `canUseFullScreenIntent()` + `openFullScreenIntentSettings()`.
  Attached in `MainActivity.configureFlutterEngine`,
  detached in `onDestroy`.
- Dart: `lib/services/full_screen_intent_service.dart` —
  the `FullScreenIntentService` singleton mirrors
  `UsageStatsService`. `PermissionService.requestFullScreenIntent()`
  deep-links via `openSettings()`; `refreshFullScreenIntent()`
  re-probes the channel and merges the result into
  `statuses`. The probe runs as a sequential special-
  access probe in `PermissionService.refresh()` (after
  the parallel `Future.wait` batch).
- Reliability: `PermissionKind.fullScreenIntent` joins
  the `_kReliabilityGatedKinds` set in
  `ReliabilityService` (now 5 elements). A denial flips
  the unified stream to `Reliability.degraded`; the
  home banner shows "may be late" and (new in v1.3c)
  is tappable — one tap lands the user on Settings →
  Permissions where the 5th `_PermissionTile` for
  `fullScreenIntent` is rendered.

**Permission baseline:**

`<uses-permission android:name=
"android.permission.USE_FULL_SCREEN_INTENT"
tools:ignore="ProtectedPermissions" />` — the
`tools:ignore` marker mirrors the v1.1g
`PACKAGE_USAGE_STATS` precedent: the permission is
opt-in only. Declining does NOT block any feature —
the notification still fires; the user just has to tap
it. The strong-mode interruption contract is the only
behavior that depends on the permission.

**Out of scope (deferred to Phase 6a proper):** the
activity launch path itself
(`PlatformFullScreenIntent.showHabitMission` /
`showRoutineOverlay`). The new channel is shaped so
Phase 6a can extend it with the launch handlers
without re-doing the probe wiring.

### Full-screen launch (v1.3d / Phase 15 / SYS-114)

v1.3d closes the "Phase 6a proper" gap that v1.3c
explicitly deferred. The launch path is wired end-to-end
on API 27+:

**The `FullScreenActivity` Kotlin class.** A thin
`FlutterActivity` subclass
(`android/app/src/main/kotlin/com/doit/FullScreenActivity.kt`)
that:

- Sets lockscreen-bypass window flags in `onCreate`:
  `WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED |
  FLAG_TURN_SCREEN_ON | FLAG_DISMISS_KEYGUARD |
  FLAG_KEEP_SCREEN_ON`. On API 27+ the activity surfaces
  directly on the lockscreen; on API < 27 the activity
  still launches but without keyguard dismissal (the
  `DISMISS_KEYGUARD` and `TURN_SCREEN_ON` flags are
  silently ignored).
- Overrides `getInitialRoute()` to encode the intent
  extras into a query string: `/mission?mode=habit
  &habitId=<id>` for strong-mode habit launches,
  `/mission?mode=overlay&title=<t>&body=<b>` for
  routine-fired overlays. The Dart-side route resolver
  in `lib/main.dart`'s `MaterialApp.onGenerateRoute`
  reads the query string and pushes the matching widget.
- The manifest declares the activity with
  `exported="false"` (only our own code can launch it),
  `taskAffinity=""` (won't pollute `MainActivity`'s back
  stack), `excludeFromRecents="true"` (the user does
  not see it in Recents), `launchMode="singleTask"`,
  `showOnLockScreen="true"`, `turnScreenOn="true"`,
  `showWhenLocked="true"`, and `@style/LaunchTheme`
  (shared with `MainActivity`).

**The launch handlers on `FullScreenIntentChannel.kt`.**
Two new `when` arms extend the v1.3c probe channel
without re-doing the wiring:

- `showHabitMission(ctx, args)` builds
  `FullScreenActivity.habitIntent(ctx, habitId)` and
  starts the activity with `FLAG_ACTIVITY_NEW_TASK`
  (required because the alarm fires from a background
  context).
- `showRoutineOverlay(ctx, args)` builds the overlay
  intent with optional `title` / `body` extras.

The Dart `_safe` wrapper at
`lib/services/platform_full_screen_intent.dart` swallows
the `MissingPluginException` end-to-end (defense-in-
depth per ADR-013). In production the handlers always
succeed; the wrapper remains a no-op.

**Strong-mode notification uses `setFullScreenIntent`.**
`MainActivity.buildReminderNotification` splits the
strong-mode branch: the strong-mode `openIntent`
targets `FullScreenActivity` (with `habitId` extra), and
`NotificationCompat.Builder.setFullScreenIntent(openPi,
/* highPriority= */ true)` is added so the OS launches
the activity directly when the alarm fires on a locked
device. The strong-mode `Open` action button reuses the
same `fsiPi`. Soft-mode notifications keep the existing
`MainActivity` openPi (no FSI) and the "Done" action
button — soft habits do not need the full-screen
interruption contract.

**The chain-level orchestrator widget
(`lib/screens/mission_launcher.dart`).** The Flutter
route resolver in `lib/main.dart`'s
`MaterialApp.onGenerateRoute` maps
`/mission?mode=habit&habitId=<id>` to
`MissionLauncherScreen`. The widget:

1. Loads the habit by id via
   `DoRepository.instance.getById(habitId)`. If the
   habit is missing, not in `StrongProof` mode, or
   carries an empty `MissionChain`, the widget pops
   with `null` (the streak stays untouched).
2. Iterates the `MissionChain`, pushing the matching
   `MissionXxxScreen` (`MissionShakeScreen`,
   `MissionTypeScreen`, `MissionHoldScreen`,
   `MissionMathScreen`, `MissionMemoryScreen`) for
   each `Mission` and `await`ing the pop value. A
   `null` pop (cancel / timeout / dismiss) aborts the
   chain immediately.
3. On all inputs collected, runs
   `MissionChainExecutor.run(chain, inputs)`. On
   `ChainPassed`, the completion is appended via
   `CompletionLogService.instance.append` with
   `source: CompletionSource.mission`,
   `proofModeAtTime: <strong|soft|auto>`, and
   `missionResultsJson: "missions=<N>"`; the widget
   pops with `true`. On `ChainFailedAt` /
   `ChainTimedOut`, the widget pops with `null` (the
   streak stays broken per the v1.1f grace-window
   contract — `MissionWrongAttempts` covers the
   wrong-attempt case for Math / Type).

**The routine overlay widget
(`lib/screens/routine_overlay_screen.dart`).** The
Flutter route resolver maps
`/mission?mode=overlay&title=<t>&body=<b>` to
`RoutineOverlayScreen`. The widget is a simple
dismissable banner — the routine executor has already
published `AutomationFired` so no further Dart-side
action is needed. The Dismiss button is ≥ 64 dp
(matching the mission primary action size) and wrapped
in `Semantics(button: true, label: "Dismiss routine
overlay", ...)` per `.claude/rules/lib-screens.md`
(SYS-062).

**No `wakelock_plus` package added.** The wake-lock is
held at the Android Window level via
`FLAG_KEEP_SCREEN_ON` on the activity (released
automatically when the activity is destroyed). This
matches the v1.2e precedent (`feature.md` §2.1 lines
8-12). A v1.4+ follow-up may swap to `wakelock_plus` if
the team wants per-mission wake-lock control.

**No new `<uses-permission>`.** The v1.3c
`USE_FULL_SCREEN_INTENT` baseline (SYS-113) covers the
launch path. On API 34+ the OS no longer suppresses the
full-screen intent because (a) the app holds
`USE_FULL_SCREEN_INTENT` (v1.3c manifest) and (b) the
notification uses `setFullScreenIntent` so the OS
handles the launch itself.

**The launch-intent read.** The Dart-side
`PlatformFullScreenIntent` gains
`Future<LaunchIntent?> getLaunchIntent()` which reads
`getLaunchIntent` over the `doit/full_screen` channel.
The `_safeResult<T>` wrapper swallows the production
`MissingPluginException` and returns `null` (the Kotlin
side does NOT implement the read; the canonical read
is the initial-route query string). The method exists
for symmetry with the `FullScreenIntent` interface and
for test fixtures that drive the channel seam directly.
`LaunchIntent` is a new immutable class +
`LaunchMode` enum (a v1.3d additive in
`lib/reminders/full_screen_intent.dart`).

## Timezone and DST

`flutter_local_notifications` and `android_alarm_manager_plus`
take a `DateTime` that the OS interprets in the device's
current zone. do it stores all schedules in **local wall-clock
time** (no UTC normalization), and re-computes `nextOccurrence`
on `ACTION_TIMEZONE_CHANGED`.

- **DST jumps forward (e.g., 02:00 → 03:00).** A reminder at
  02:30 on that day is silently dropped (it never existed).
  The app logs this and informs the user on next launch.
- **DST jumps back (e.g., 02:00 → 01:00).** A reminder at
  01:30 fires twice (the OS sees the wall-clock time twice).
  The scheduler dedupes by `(habit_id, scheduled_local_dt)`
  so the second fire is a no-op.

**Verification.**
- Unit test: `test/reminders/schedule_dst_test.dart` exercises
  fixed-time habits across `America/Los_Angeles` DST
  transitions.
- Manual device check: change the device zone from
  `America/Los_Angeles` to `Asia/Kolkata` while reminders are
  pending; observe the next reminder fires at the new-zone
  wall-clock equivalent.

## Boot survival — full design

The Kotlin `BootReceiver` is registered in
`AndroidManifest.xml` with `android:enabled="true"` and
`android:exported="true"`. It handles three actions:

- `ACTION_BOOT_COMPLETED` — device finished booting.
- `ACTION_LOCKED_BOOT_COMPLETED` — direct-boot area is ready
  (preferred; allows rescheduling before unlock).
- `ACTION_MY_PACKAGE_REPLACED` — the app itself was updated
  (the OS may have cleared the alarm table).

The receiver is short-lived (it just re-schedules and returns).
The actual scheduling logic is in the same Kotlin module so the
receiver can call it directly without round-tripping through
Dart.

## User-facing surfaces for reliability

- **Home screen banner** when the app detects degraded
  reliability: "Your reminders may be late. Tap to fix."
- **Settings → Reminders** page shows the current state of
  exact alarm, battery optimization, and (best-effort) OEM
  auto-start, with deep links to fix each.
- **Notification action "Why am I getting this late?"** on any
  late-fired reminder; tapping it opens the same settings page
  with a one-tap fix.
- **do it at risk** in the streak-grace window: if a habit
  was missed, the user gets a notification at 22:00 saying
  "do it at risk: 2 habits still due today. Tap to open."

## What we do NOT do

- We do not run a foreground service in v0.1 (deferred to v0.2
  if needed).
- We do not poll the system for the OEM auto-start state; we
  ask the user to verify visually.
- We do not bypass battery optimization by abusing
  `AccessibilityService` or `DeviceAdmin` — those are
  privacy-intrusive and Play Store will reject the app.
- We do not show a persistent notification in v0.1.

## Acceptance criteria for reliability

- A scheduled reminder fires within ±60 sec of its target
  on a non-Doze device, ≥ 95% of the time over 100 scheduled
  occurrences.
- A scheduled reminder fires within ±15 min of its target
  on a Doze device without whitelist, ≥ 95% of the time.
- The schedule survives a device reboot, a timezone change,
  and a DST transition with no duplicates and no more than 1
  dropped occurrence per transition.
- The user is never more than 1 tap away from the settings
  that would improve reliability.

If any criterion fails in the 14-day real-device run, fix it
before adding features.
