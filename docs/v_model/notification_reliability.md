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
   app must request this. On first scheduling of a fixed-time
   habit, the app checks `AlarmManager.canScheduleExactAlarms()`.
   If false, it shows a screen with a one-tap deep link to
   `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`. If the user denies,
   the app falls back to WorkManager and shows the "may be
   late" badge.

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
