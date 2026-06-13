# `lib/reminders/**` — Reminder scheduling and platform integration

## Layer boundary

`lib/reminders/` is the **only** folder that talks to the
Android platform for alarm scheduling, notifications, full-screen
intents, and wake-up detection. The rest of the app goes
through this layer's public API.

The Android side (Kotlin) is in `android/app/src/main/kotlin/.../`.
Changes to the Kotlin side are part of this folder's review
surface.

## Public API

The rest of the app sees only the following:

- `AlarmScheduler.schedule(Habit h, DateTime at) → AlarmId`
- `AlarmScheduler.cancel(AlarmId id)`
- `AlarmScheduler.snooze(AlarmId id, Duration delay)`
- `NotificationService.show(ReminderEvent event)`
- `NotificationService.dismiss(AlarmId id)`
- `FullScreenIntent.show(Habit h, MissionChain chain)`
- `AnchorDetector.start({required AnchorMode mode})`
- `AnchorDetector.stop()`
- `AnchorDetector.lastAnchor` (a `DateTime?`)

Everything else is private to the folder. Service-level state
(e.g., "the current scheduled alarms") lives in the
singleton-with-`_ready` pattern, see `.claude/rules/lib-services.md`.

## Schedule survival

Per
[`docs/v_model/notification_reliability.md`](../../docs/v_model/notification_reliability.md):

- The scheduler registers a `BroadcastReceiver` for
  `BOOT_COMPLETED`, `LOCKED_BOOT_COMPLETED`, and
  `MY_PACKAGE_REPLACED` (Kotlin).
- The receiver re-schedules all pending alarms from the local
  DB.
- The receiver is short-lived; it does not run in the
  background after rescheduling.

## Reliability detection

`AlarmScheduler` exposes `reliability` which is a sealed enum:

- `Reliability.optimal` — exact alarm granted, no Doze.
- `Reliability.degraded` — exact alarm denied, using
  WorkManager. UI shows the "may be late" badge.
- `Reliability.unknown` — first launch, no info yet.

The home screen and the settings page read this and show the
right copy. The settings page also has deep links to:

- `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`
- `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
- The OEM's auto-start activity (best-effort detection).

## Notifications

- Use `flutter_local_notifications` with a dedicated
  notification channel (`streak.reminders`) at high importance.
- The notification has at least one action: "Done" (or "Open"
  for strong-mode habits). For Soft habits, "Done" marks the
  habit complete directly from the notification.
- For Strong habits, "Open" launches the full-screen intent
  (Layer 1 of the reliability design).
- The notification icon is a custom monochrome
  `ic_streak_notification` (see
  [`docs/v_model/architecture_options.md`](../../docs/v_model/architecture_options.md)).

## Full-screen intent

- Uses `flutter_local_notifications`'s
  `AndroidNotificationDetails.fullScreenIntent` flag.
- The full-screen activity is a thin Kotlin shell that hosts
  a Flutter route (`/mission`).
- The activity holds a `wakelock_plus` lock while the mission
  UI is on screen. Released on close.

## Anchor detection

- `AnchorDetector` listens for `Intent.ACTION_USER_PRESENT`
  (first unlock) and exposes a "mark now" method (manual
  button).
- The mode is selected by the user in settings.
- A 4-hour debounce prevents double-fires.

## Permission checks

- Every public method in this folder checks the relevant
  permission at call time, not at app launch. The check is
  cheap (a static query) and gives a clear error if the
  permission is denied.
- A denied permission surfaces a `PermissionDenied` exception
  with a human-readable message. The caller is expected to
  catch and show a rationale screen.

## Forbidden patterns

- No `print()`.
- No direct `AlarmManager` calls from widgets. Always go
  through `AlarmScheduler`.
- No `DateTime.now()` inside the scheduler. The caller passes
  the target time.
- No side effects in `verify`-style methods. The scheduler
  is a service; methods have effects but are not predicates.

## Tests

- `test/reminders/alarm_scheduler_test.dart` — schedule,
  cancel, snooze, re-schedule after cancellation.
- `test/reminders/reboot_survival_test.dart` — simulate a
  process kill and re-schedule.
- `test/reminders/doze_simulation_test.dart` — schedule with
  exact-alarm denied, observe WorkManager fallback.
- `test/reminders/timezone_test.dart` — schedule in one zone,
  change zone, observe re-computed `nextOccurrence`.
- `test/reminders/anchor_detector_test.dart` — manual mark,
  first-unlock, debounce, dismiss.
- 80%+ coverage on changed files.

## When changing this folder

- Update
  [`docs/v_model/notification_reliability.md`](../../docs/v_model/notification_reliability.md)
  if a reliability policy changes.
- Update the SYS- IDs.
- If a new Android permission is required, append an ADR and
  update
  [`docs/v_model/architecture_options.md`](../../docs/v_model/architecture_options.md).
- A change to the Kotlin side must be reviewed in the same PR
  as the Dart side.
