# Streak — Privacy Notice

Streak is a personal, local-first Android habit and relationship app. The
short version: **your data lives on your phone, period**. This document
spells out exactly what the app stores, what it does not do, and the
caveats a careful reviewer should know.

## What Streak stores on your device

Streak persists the following to a local SQLite database managed by the
[Drift](https://drift.simonbinder.eu/) library (the schema lives in
[`lib/services/db/schema.dart`](lib/services/db/schema.dart), schema
version 2):

- **Habits** — name, schedule, proof mode, mission chain, streak
  policy, category, color, icon, paused state.
- **People** — display name, contact lookup key, channel handle
  (phone, WhatsApp, Telegram, Signal, SMS), cadence, paused state.
- **Person groups** — group name, member list, shared cadence,
  shared mission chain, last-contacted member (for rotation groups).
- **Events** — one-off or annually-recurring reminders, lead time,
  optional mission chain, archive state.
- **Completions** — the full completion log, with timestamps, per
  habit and per person. This is the source of truth for streak
  numbers.
- **Rest day budgets** — a small per-habit counter so the streak
  calculator knows when a missed day was a deliberate rest day.
- **Settings** — the user's reliability preferences (anchor mode,
  backup folder URI, theme choice, OEM guide dismissed state).
- **Event logs** — diagnostic rows written when reminders fire, get
  completed, or are missed. Used by the Stats screen.

Streak also writes a JSON backup file to a folder you pick via the
system Storage Access Framework (SAF). The backup envelope is
`{"version": 1, "exportedAtMillis": ..., "tables": ...}`. The file
is plain text, scoped to the folder you choose, and lives on your
device's shared storage. Uninstalling the app removes the database
but does not remove the backup file (it is in your SAF folder, not
the app's private storage).

In memory, Streak holds the in-app `SettingsService`, a handful of
singleton services, and the in-memory copy of the Drift tables. None
of that crosses a process boundary.

## What Streak does NOT do

- **No server.** Streak has no backend, no API, no remote config.
- **No analytics.** No Firebase Analytics, no Mixpanel, no Segment,
  no Amplitude, no Crashlytics, no Sentry, no Bugsnag, no Datadog.
- **No telemetry.** No install ID, no advertising ID, no device
  fingerprint, no usage ping, no A/B test framework.
- **No cloud backup.** The SAF backup is local. The app does not
  upload it to Google Drive, iCloud, Dropbox, or anywhere else.
- **No account.** There is no sign-in, no profile, no sync.
- **No advertising SDK.** No AdMob, no Facebook Ads, no Unity Ads.
- **No third-party crash reporter.** If the app crashes, the
  Android system writes a local tombstone; the app does not phone
  home.
- **No network calls with user data.** This is enforced at the
  manifest level: the `android.permission.INTERNET` permission is
  not declared. The platform itself will not let the app make a
  network call.

## How the no-`INTERNET` rule is enforced

The release `AndroidManifest.xml` does not declare the `INTERNET`
permission. The Play Store's installer and the Android package
manager both enforce this: an app without `INTERNET` cannot open a
socket. There is no opt-out, no hidden switch, no debug build that
turns it on. The CI grep in [`docs/engineering/ci-cd.md`](docs/engineering/ci-cd.md)
fails on any `import 'package:http'` or `Uri.http(s)` outside the
dev-only test harness. The PRIVACY.md is not a promise — the
absence of the permission in the manifest is the contract.

## Permissions Streak does request

These are the runtime permissions Streak asks for, with a rationale
screen in onboarding for each:

- **`POST_NOTIFICATIONS`** (Android 13+) — to show reminders.
- **`SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`** — to fire
  reminders at the target time. The fallback to
  `android_alarm_manager_plus` is automatic if the user denies
  exact alarm.
- **`RECEIVE_BOOT_COMPLETED`** — to re-schedule all pending
  reminders after a device reboot.
- **`WAKE_LOCK` / `FOREGROUND_SERVICE`** — to power the full-screen
  intent that runs the mission chain.
- **`VIBRATE`** — for the reminder vibration pattern.
- **`READ_CONTACTS`** — strictly to resolve names you have chosen
  to add to a cadence. The app does not bulk-import your contacts
  and does not store the full vCard; it stores a stable lookup
  key, the cached display name, and the channel handle.

Streak does **not** request `CALL_PHONE`, `READ_CALL_LOG`,
`RECORD_AUDIO`, `READ_PHONE_STATE`, `READ_SMS`, `ACCESS_FINE_LOCATION`,
or `CAMERA`. The "Call a person" reminder opens the system dialer
with the number pre-filled via `Intent.ACTION_DIAL` — it does not
place the call for you.

## On-device footprint

| Data | Where | Lifetime | Wiped on uninstall? |
|------|-------|----------|---------------------|
| Drift database | App's private storage (`/data/data/com.common_games.streak/`) | Until uninstall | Yes |
| SAF backup file | The folder you chose in onboarding | Until you delete the file | **No** (it is in your shared-storage folder) |
| In-memory services | Process RAM | Process lifetime | Yes (with the process) |
| Notification channel `streak.reminders` | System settings | Until the app is uninstalled or the user clears it | Yes |

## Honest caveats

A privacy notice that claims more than the code does is a defect. As
of the v0.3 release:

- The `displayName` field on `PersonRow` is declared but currently
  always written empty by the v0.2 repository; the app resolves
  the contact's name on read instead.
- The `Settings`, `EventLogs`, and `RestDayBudgets` Drift tables
  exist in the schema but are not yet fully populated by the v0.2
  screen layer. They will land in subsequent runs.
- The on-device `WorkManager` periodic backup scheduler is
  wired (v0.4b / SYS-060). Once the user opts in from
  Settings, the OS runs a 24-hour periodic task that exports
  a JSON snapshot of the local DB to the user's SAF folder.
  The scheduling is strictly local; the scheduler makes no
  network call. v0.3 users had to trigger backups manually
  from Settings; v0.4 users get the auto-backup.
- The `PersonResolver` (a service in `lib/services/`) is
  forward-referenced in the rules but not yet implemented.
  Contacts are resolved at write time only.
- Backup files are **plain JSON, not encrypted**. A user with
  access to your SAF folder can read them. Encryption is a v0.4
  line item behind a user passphrase.
- The first-launch onboarding screen shows the permission
  rationale (and the backup-folder + anchor-mode walkthrough)
  the **first time** you launch the app on a given install.
  A "done" flag is persisted in `SharedPreferences` so the
  screen does not re-appear on subsequent launches. v0.4
  (SYS-059).

## Reporting a privacy concern

Streak is a personal project. If you received a copy and have a
concern, raise it with the person who handed you the apk. There is
no public issue tracker. The PRIVACY.md and the
`AndroidManifest.xml` are the source of truth — any code change
that loosens a constraint here is a defect, and the
[`decision_record.md`](docs/v_model/decision_record.md) will
record the ADR.
