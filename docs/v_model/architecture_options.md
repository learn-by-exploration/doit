# Architecture Options

Status: draft baseline, created 2026-06-13.

## Baseline Tech Stack

Use Flutter, matching the existing `board_box` and `card_box` projects
in the same monorepo. Flutter 3.44 / Dart 3.12 / JVM 17. Android-only
for v0.1.

## Candidate Packages

| Capability | Candidate | Notes |
| --- | --- | --- |
| **Local notifications** | `flutter_local_notifications` | De facto standard; supports Android Notification Channels, full-screen intents, action buttons. Pinned version: `^17.x`. |
| **Scheduled local notifications** | `flutter_local_notifications` + `timezone` package | Schedules the actual alarm trigger from Dart; uses Android's AlarmManager under the hood. |
| **Exact alarm** | `android_alarm_manager_plus` | For exact `setExactAndAllowWhileIdle` triggers. The `flutter_local_notifications` API does not always grant `setExact` reliably on Android 12+. |
| **WorkManager fallback** | `workmanager` | Periodic and one-shot background work; used as the degraded-reliability path when exact-alarm is denied or Doze is in effect. |
| **Contacts** | `flutter_contacts` (preferred) or `contacts_service` | `flutter_contacts` is more actively maintained; supports Android 11+ scoped storage. |
| **Sensors (Shake-N)** | `sensors_plus` | Accelerometer stream; magnitude + inter-sample timing derived in-app. |
| **Permissions** | `permission_handler` | Centralized runtime permission flow with rationale helpers. |
| **Local DB** | `drift` (preferred) or `sqflite` | Drift gives typed, reactive SQLite. `sqflite` is simpler but lower-level. Either is fine; Drift wins for the completion-log queries. |
| **Migrations** | `drift`'s `MigrationStrategy` | Versioned schema upgrades. |
| **Preferences** | `shared_preferences` | Settings only; never sensitive data. |
| **File picker / SAF** | `file_picker` | For backup folder selection on Android (Storage Access Framework URI). |
| **Path provider** | `path_provider` | App-internal cache for the staging file before the SAF write. |
| **Date / time** | `timezone` + `intl` | `timezone` for tz-aware schedule computation; `intl` for locale-aware formatting. |
| **URL launcher / dialer** | `url_launcher` | For `tel:+15555550100` to open the dialer pre-filled. |
| **Home widget** | `home_widget` | Bridges Flutter state to the Android home-screen widget. |
| **Wakelock** | `wakelock_plus` | Keeps the screen on during full-screen intent UI. |
| **Boot receiver** | Native Kotlin in `android/app/src/main/.../BootReceiver.kt` | The Flutter engine cannot reliably register a `BOOT_COMPLETED` receiver from Dart; it must be declared in `AndroidManifest.xml` and implemented in Kotlin. |
| **Encryption (v0.2)** | `flutter_secure_storage` + `cryptography` or `encrypt` | Out of scope for v0.1; flagged for v0.2. |
| **Camera (v0.2)** | `camera` or `image_picker` | Out of scope for v0.1; flagged for the Photo mission in v0.2. |
| **Barcode/QR (v0.2)** | `mobile_scanner` | Out of scope for v0.1. |

## Sources checked

- https://pub.dev/packages/flutter_local_notifications
- https://pub.dev/packages/android_alarm_manager_plus
- https://pub.dev/packages/workmanager
- https://pub.dev/packages/flutter_contacts
- https://pub.dev/packages/sensors_plus
- https://pub.dev/packages/permission_handler
- https://pub.dev/packages/drift
- https://pub.dev/packages/sqflite
- https://pub.dev/packages/shared_preferences
- https://pub.dev/packages/file_picker
- https://pub.dev/packages/timezone
- https://pub.dev/packages/url_launcher
- https://pub.dev/packages/home_widget
- https://pub.dev/packages/wakelock_plus

> Sources list is illustrative. Each package's current `pubspec`
> version and CHANGELOG must be re-checked at the time of the
> dependency-add PR, per the global development-workflow rule.

## Proposed Logical Modules

| Module | Responsibility | File scope |
| --- | --- | --- |
| **Habits** | Habit model, schedule types, proof modes, streak rules | `lib/habits/` |
| **People** | Contact resolution, person record, cadence, channel selection | `lib/people/` |
| **Missions** | The 5 mission types and the chain executor | `lib/missions/` |
| **Reminders** | Alarm scheduling, notification service, full-screen intent, anchor detection, boot survival | `lib/reminders/` + `android/app/src/main/.../` |
| **Streaks & stats** | do it calculator, rest-day budget, stats service | `lib/habits/streak_calculator.dart`, `lib/services/stats_service.dart` |
| **Local DB** | Drift database, migrations, queries | `lib/services/db.dart`, `lib/services/migrations/` |
| **Backup** | Auto backup, restore, file picker integration | `lib/services/backup_service.dart`, `lib/screens/settings_restore.dart` |
| **Settings** | Permissions, exact-alarm, Doze prompt, OEM guide, theme, sound | `lib/screens/settings.dart` |
| **UI shell** | Navigation, theme, onboarding, home, widget-host activity | `lib/screens/`, `lib/main.dart` |
| **Templates (v1.0/Phase B)** | Curated library of 25 templates (Do / Event / Person / Routine), `Template` model, `kTemplateFormatVersion = 1` JSON envelope, repository, catalog screen, save-as-template affordance on add screens | `lib/templates/`, `lib/services/template_repository.dart`, `lib/screens/templates.dart` |
| **Triggers / Conditions / Actions (v1.0/Phase C)** | Sealed `Trigger` (time-of-day, location enter/exit, device-state, calendar, call-incoming), sealed `Condition` (time-window, day-of-week, calendar-busy, battery-range, silent-mode, AND/OR boolean tree), sealed `Action` (notify, fullscreen, call-intercept, override-silent, open-app). Each entity's optional `List<Automation>` field is the attachment point. | `lib/triggers/`, `lib/actions/action.dart`, `lib/routines/routine.dart` |
| **Routines (v1.0/Phase C PR 1)** | The `RoutineExecutor` singleton that consumes non-time triggers and dispatches the matching `Action`. The executor subscribes to `GeofenceService.events` (Phase C PR 2) and will subscribe to `DeviceStateProbe` (Phase D), `CalendarProbe` (Phase E), and `CallInterceptor` (Phase F). | `lib/routines/routine_executor.dart` |
| **Call-screening role (v1.0/Phase F PR 2)** | The `doit/call_interceptor` method channel gains `isCallScreeningRoleHeld()` + `requestCallScreeningRole()` methods that wrap `RoleManager.createRequestRoleIntent(ROLE_CALL_SCREENING)`. The role is **opt-in on Android Q+** (no runtime permission); the bound permission `BIND_SCREENING_SERVICE` is signature-protected and granted at install time. The Settings → Permissions → Call-screening tile and an onboarding step (step 4, after backup folder) surface the role status. The home-screen reliability banner shows "Japan routine unavailable — grant the call-screening role in Settings" when a Japan routine is configured but the role is not held. The routine silently no-ops on Android < Q (the role does not exist) and on missing plugin (test seam returns `false`). | `android/app/src/main/kotlin/com/doit/CallInterceptor.kt`, `lib/services/call_interceptor.dart`, `lib/screens/settings.dart`, `lib/screens/onboarding.dart` |
| **Geofence (v1.0/Phase C PR 2)** | `GeofenceService` singleton — thin position-stream adapter (`geolocator` ^13.0.1, ADR-021) with a pure-Dart Haversine matcher. Emits `GeofenceEntered` / `GeofenceExited` on a broadcast `Stream<GeofenceEvent>`. `PositionSource` is the platform seam (production: `_GeolocatorPositionSource`; test: `ScriptedPositionSource`). | `lib/services/geofence_service.dart` |
| **Device-state probe (v1.0/Phase D PR 1)** | `DeviceStateService` singleton — thin platform adapter for battery / charging / headphones / screen state. Production wires a `_MethodChannelDeviceStateSource` that talks to the `doit/device_state` method channel; tests wire a `ScriptedDeviceStateSource`. The Kotlin side registers a single `BroadcastReceiver` for the four reactive events (`ACTION_POWER_CONNECTED` / `DISCONNECTED`, `ACTION_AUDIO_BECOMING_NOISY`, `ACTION_SCREEN_ON` / `OFF`); battery is read on demand via `BatteryManager.BATTERY_PROPERTY_CAPACITY`. PR 2 wires `RoutineExecutor` to the stream and adds the Settings → Triggers debug screen. ADR-022 covers the polling cadence (reactive only in PR 1; 60s poll reserved for any future state that lacks a reactive broadcast). | `lib/services/device_state_probe.dart`, `android/app/src/main/kotlin/com/doit/DeviceStateChannel.kt` |
| **Services (singleton)** | `AppStateService`, `HabitRepository`, `PersonRepository`, `CompletionLogService`, `StreakService`, `BackupService`, `StatsService`, `NotificationService`, `AlarmScheduler`, `AnchorDetector`, `TemplateRepository` | `lib/services/` |

### Format-version pins

The app keeps a small set of version pins for forward-compatible
file / payload formats. A mismatch (lower-than-supported) is
migrated forward; a higher-than-supported mismatch is rejected
with a sealed exception.

| Constant | Value | Location | On mismatch |
| --- | --- | --- | --- |
| `kBackupFormatVersion` | 2 | `lib/services/backup_service.dart` | Forward-migrate via `lib/services/db/migrations/`; reject `version > 2` with `BackupFormatTooNew` |
| `kTemplateFormatVersion` | 1 | `lib/templates/template_library.dart` | Reject `k != 1` with `TemplateValidationException` (no forward migration path in Phase B; future bumps follow the same envelope pattern as `kBackupFormatVersion`) |
| `kAutomationFormatVersion` | 1 | `lib/triggers/automation_codec.dart` | Reject `k != 1` with `AutomationValidationException` (v1.0/Phase C PR 1 — the `automationsJson` envelope on habits / people / events rows). Future bumps follow the same envelope pattern as `kBackupFormatVersion`. |

## App identity (v0.5a, v0.5e-fix)

- **Dart package name:** `doit` (was `common_games` pre-v0.5a).
- **Android `applicationId` / AGP `namespace`:** `com.doit`
  (was `com.common_games.streak` pre-v0.5a; the v0.5a
  draft picked `com.doit.package` — v0.5e-fix renames to
  `com.doit` because `package` is a Java reserved
  keyword, JLS §3.9). The applicationId is the install
  boundary on the user's device; an applicationId change
  forces `adb uninstall` + `adb install`. See
  [`decision_record.md` ADR-017](decision_record.md#adr-017--v0_5e-fix_comdoitpackage_is_an_invalid_java_namespace_rename_to_comdoit).
- **Kotlin tree:** `android/app/src/main/kotlin/com/doit/`
  (was `com/common_games/streak/` pre-v0.5a; the v0.5a
  draft picked `com/doit/package/` — v0.5e-fix renames
  to `com/doit/`).
- **Launcher label (`android:label`):** "do it" (was "Streak"
  pre-v0.5a).

## Permission Baseline (`AndroidManifest.xml`)

```xml
<!-- Notifications and exact alarm for reliable reminders -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.VIBRATE" />

<!-- Contacts for "call Mom" / "message Sam" presets -->
<uses-permission android:name="android.permission.READ_CONTACTS" />

<!-- Coarse location for TriggerLocationEnter / TriggerLocationExit
     (geofence triggers). v1.0 / Phase C PR 2 / SYS-072 / SYS-076 /
     ADR-021. City-block accuracy is sufficient for the 50m..5000m
     radius the trigger model enforces. ACCESS_FINE_LOCATION stays
     out of scope (see below). -->
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Read calendar for TriggerCalendarEvent (event-start, event-end,
     event-reminder, free-busy). v1.0 / Phase E PR 1 / SYS-074 /
     SYS-078 / ADR-023. Read-only; we never write to the calendar.
     The app reads event metadata (id, calendar id, title, time)
     to drive routine matches; no event bodies, attendees, or notes
     are stored or transmitted off-device. -->
<uses-permission android:name="android.permission.READ_CALENDAR" />

<!-- Camera permission only requested at the moment a photo-based mission
     is enabled in v0.2. Not in v0.1. -->
```

**Explicitly NOT in the manifest:**

- `CALL_PHONE` — call reminders open the dialer only.
- `INTERNET` — local-only data, no network.
- `READ_CALL_LOG` — cadence is configured manually or per-person, not
  derived from the call log.
- `ACCESS_FINE_LOCATION` — out of scope; coarse location is
  sufficient for the 50m..5000m radius bounds the geofence
  trigger model enforces (`TriggerLocation.validate()` rejects
  radii outside that range). Re-evaluated only if a future
  feature needs sub-50m accuracy. v1.0 / Phase C PR 2 / ADR-021.
- `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` — backup uses SAF
  with a user-chosen folder; no broad storage access.
- `RECORD_AUDIO` — out of scope.

Any PR that adds a new permission must include an ADR in
[`decision_record.md`](decision_record.md) and a row in this file.

## OEM Detection

`lib/services/oem_detector.dart` reads `Build.MANUFACTURER` /
`Build.BRAND` and returns one of: `xiaomi`, `oppo`, `vivo`, `honor`,
`samsung`, `oneplus`, `huawei`, `google`, `other`. The Settings
screen shows the relevant guide card for the detected OEM.

## Early Design Decisions To Make

- **Drift vs. sqflite.** Drift preferred for typed queries and
  reactive streams. sqflite is fine if the team prefers a smaller
  dependency. **Decision:** Drift, for the completion-log and
  streak queries.
- **Notification icon.** Custom monochrome white-on-transparent for
  the status bar; full-color for the app icon. Asset path:
  `android/app/src/main/res/drawable/ic_streak_notification.xml`.
- **Sound.** Default: Android's `RingtoneManager` default
  notification sound. User can change in settings.
- **Locale.** v0.1: English only. i18n is v0.2.
- **Theme.** Dark mode by default (matches the Alarmy-like feel).
  Light theme is a setting.
- **Time-zone data.** Use the `timezone` package's IANA tz database;
  the app picks up the device's current zone on launch and on
  `ACTION_TIMEZONE_CHANGED`.
- **Encryption at rest for v0.2.** The DB will be encrypted with
  SQLCipher via Drift's `NativeDatabase` + `OpenHelper`. Out of
  scope for v0.1.
- **Accessibility.** Every actionable element ≥ 48dp touch target.
  TalkBack labels for the mission UI, the home widget, and the
  full-screen activity.

## Anti-Patterns We Will Avoid

- **Global `static` state outside the service-singleton pattern.**
  All cross-cutting state goes through a service with `_ready`.
- **Side effects in model classes.** Models are pure Dart; side
  effects (DB writes, alarm scheduling) live in services.
- **Direct platform calls in widgets.** Widgets consume services via
  `Provider` / `ChangeNotifier` / `ValueNotifier` (decision pending).
- **Hidden network calls.** If a package wants to phone home
  (analytics, crash reporting), the integration PR is rejected.
- **Mixing proof modes silently.** A habit's mode is part of its
  identity; the model refuses to silently flip it.
