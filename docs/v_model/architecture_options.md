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
| **Services (singleton)** | `AppStateService`, `HabitRepository`, `PersonRepository`, `CompletionLogService`, `StreakService`, `BackupService`, `StatsService`, `NotificationService`, `AlarmScheduler`, `AnchorDetector` | `lib/services/` |

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

## Permission Baseline (`AndroidManifest.xml` v0.1)

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

<!-- Camera permission only requested at the moment a photo-based mission
     is enabled in v0.2. Not in v0.1. -->
```

**Explicitly NOT in the manifest:**

- `CALL_PHONE` — call reminders open the dialer only.
- `INTERNET` — local-only data, no network.
- `READ_CALL_LOG` — cadence is configured manually or per-person, not
  derived from the call log.
- `ACCESS_FINE_LOCATION` — out of scope; location-anchored habits are
  v0.2.
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
