# Concept Of Operations

Status: draft baseline, created 2026-06-13.

## Mission

do it is a general personal-life "do" app for a single user, combining
the best of Alarmy (mission-gated reminders), Google Reminders (task
templates + recurrence), and Samsung Routines (location / device-state
triggers with conditional logic). The app reminds the user to do the
things they said they would — drink water, call Mom, run the morning
routine, pay rent, ring a contact through silent mode — and tracks
the truth of what they actually did. The product is opinionated: it
would rather refuse a fudged "done" than inflate a consecutive-run
counter.

The umbrella entity is the **Do** (formerly "Habit"; renamed in
v1.0/Phase A — see ADR-024). A Do is anything the user wants to
do on a schedule: a daily habit, a one-off event, a contact cadence,
a location-triggered routine, etc. Schedules can be time-of-day,
location-based, device-state-based, calendar-based, or
incoming-call-based; each Do can be a Soft one-tap, a Strong
mission-gated proof, or an Auto interval window.

### Brand voice

The product is named *do it*, and the surface area spans dos, todos,
call/message cadences, events, and anchored routines. Notification
copy should lead with the **thing you do** ("Call Mom", "Drink water",
"Submit report") and end with the consecutive-run count only when it
adds motivation. The name does the work; the copy does not lean on it.

- **Lead with the action.** "Drink water" beats "do it: hydrate".
- **do it number is the period, not the point.** Append it as a
  secondary line, not the headline: "Drink water in 5 min — 12 days
  running".
- **No shame.** Missed days are facts, not failures. Copy says
  "missed" or "skipped", never "broke" or "lost".
- **Tone is calm, slightly stubborn.** do it is the friend who
  doesn't let you off the hook, but doesn't yell either.

## Operational Context

A user carries one Android phone. They want to:

- Drink water at a steady cadence through the day.
- Stay in touch with people they care about (call, message) without
  having to remember whose turn it is.
- Run a morning routine (wake up → workout → shower → breakfast) with the
  alarms chained so the day starts in order.
- Knock out a daily todo list that does not live in their head.
- See honest stats about their consistency.

The app must work in ordinary day-to-day environments:

- During a workday, with the phone in Doze and notifications silenced.
- On a phone with an aggressive OEM battery saver (Xiaomi, Oppo, Vivo,
  Honor, Samsung) that kills background work.
- On a phone that has just rebooted after a security update.
- During a phone call, on top of the lock screen, with the screen off.
- After the user has not opened the app for a week (the app is not
  forgotten; the reminders keep coming).
- When the user is in a different time zone (travel, work trips).
- When the user uninstalls and reinstalls the app (backup file restores
  the world).

## Actors

| Actor | Role |
| --- | --- |
| Primary user | Owns the phone and the data; the only human actor |
| Contact (named) | A person from the phone's contact list that the user has added to a call/message cadence |
| Phone platform | Provides AlarmManager, WorkManager, full-screen intents, contacts, sensors, file picker, storage, settings |
| OEM (Xiaomi / Oppo / Vivo / Honor / Samsung) | Aggressively terminates background work; requires user cooperation (whitelist, auto-start toggle) |
| Backup storage | A user-chosen folder (SAF URI) on the same device; the file is plain JSON in v0.1 |

## Operating Modes

| Mode | Description |
| --- | --- |
| **Catalog mode** | Browse, add, edit, archive, search, and group dos and people. No scheduling fires. |
| **Reminder firing mode** | A scheduled reminder has come due. The system surfaces a notification; the user taps it. |
| **Mission mode** | A strong-mode reminder is open. The user must complete a chain of one or more missions (Shake, Type, Hold, Math, Memory) in declared order. The app is in the foreground. |
| **Calling mode** | The user has tapped a call reminder. The app opens the system dialer with the contact's number pre-filled. The app is no longer in the foreground. |
| **Anchor mode** | A wake-up / wake-event has been recorded. Anchored dos are re-scheduled relative to the anchor's timestamp. |
| **Stats / review mode** | The user opens the stats screen to see per-do consecutive-run, overall consecutive-run, completion rate, best run, and time-of-day distribution. |
| **Routine firing mode** | A non-time trigger has fired (location enter/exit, device state, calendar event, incoming call). The matched `Action` runs. |
| **Backup mode** | The user has chosen a backup folder; the app writes a daily snapshot to it. Restore reads a chosen file. |
| **Settings mode** | Permissions, exact-alarm, Doze whitelist, OEM auto-start prompt, backup folder, mission defaults, theme, sound/vibration, rest-day cap, etc. |

## Default Do Presets (v0.1)

| Preset | Schedule | Proof mode | Notes |
| --- | --- | --- | --- |
| **Drink water** | Interval: every 30 min, 8×/day, 08:00–20:00 | Auto | Time is the proof; one-tap confirms in window |
| **Call / message &lt;person&gt;** | Per-person cadence (e.g. every 3 days, weekly, monthly) | Strong (user-pickable mission) | Tapping opens dialer or IM |
| **Morning routine** | Fixed: 06:30 weekdays, 09:00 weekends; chained steps | Strong (barcode / shake / hold) | Anchored to wake-up event |
| **Daily todo** | One-off, user-defined | Soft (one-tap) or Strong (user-pickable) | Free-form; not auto-recurring |

The preset system must be extensible. A user can create a custom do
that is not on this list (e.g., "Read 20 min", "Stretch", "Practice
guitar") with any of the four schedule types and any of the three proof
modes.

## Normal Operational Scenario

1. User installs do it from a signed APK.
2. Onboarding explains what the app does and asks for permissions in
   order (notifications first, contacts second, exact-alarm third,
   battery optimization last, with rationale for each).
3. User creates the first do (or accepts a default preset).
4. User adds a person (Mom), picks cadence ("every 3 days"), and picks
   mission ("shake 10").
5. User sets a wake-up anchor preference (manual only, first-unlock
   only, or either with confirmation).
6. User picks a backup folder.
7. The first scheduled reminder fires. It surfaces as a notification
   with a full-screen intent if the screen is off or locked.
8. The user taps the notification. The mission UI opens.
9. The user completes the mission chain. The completion is logged with a
   timestamp. The consecutive-run count is updated.
10. The user continues through the day: drink water pings every 30 min
    and they confirm in the window; a "call Mom" reminder surfaces in
    the evening; the user taps it, the dialer opens, the call is made,
    the user returns to do it and taps "Done — I called Mom".
11. Each night, do it writes a snapshot to the user's chosen backup
    folder.
12. After 30 days, the stats screen shows: 28/30 days hit on drink
    water, 10 calls to Mom (cadence kept), morning routine
    consecutive-run of 22, overall consecutive-run of 18 (two rest
    days used).
13. (v1.0+, optional) The user enables the Japan silent-mode
    template: when a contact calls and the phone is on silent, the
    ringer restores and the contact's ringtone plays. A location-based
    "leaving work" reminder fires at 17:30 as the user exits the
    office geofence.

### Templates (v1.0/Phase B)

The home FAB exposes a "Browse templates" tile alongside the
"Create blank" choices (Do / Person / Event). The catalog is an
opt-in affordance — a user who never opens it sees no template
UX in the rest of the app. Templates that ship:

- **12 Do templates** — "Drink water" (interval, Auto),
  "Read 20 min" (fixed evening, Soft), "Stretch break"
  (interval workday, Soft), "Morning walk" (fixed morning,
  Strong), "Journal" (fixed bedtime, Soft), "Meditate" (fixed,
  Soft), "Take vitamins" (fixed, Soft), "Practice guitar"
  (interval evening, Soft), "Weekly review" (fixed Sunday,
  Soft), "Inbox zero" (fixed weekday evening, Soft),
  "Languages lesson" (interval, Soft), "Wind down" (fixed
  late evening, Soft).
- **3 Person templates** — "Call Mom" (weekly, dialer),
  "Text Sam" (every 3 days, WhatsApp), "Check in on a friend"
  (weekly, SMS).
- **4 Event templates** — "Pay rent" (monthly 1st, 1-day lead),
  "Doctor appointment" (one-off, 1-h lead), "Anniversary"
  (yearly, 1-week lead), "Tax deadline" (yearly, 1-day lead).
- **6 Routine templates** — visible with a "Coming in v1.1"
  badge in Phase B; the apply UX lands in Phase F
  (`add_routine.dart`). 5 of the 6 routine templates
  (e.g., "Leaving work → wind down", "Arriving home →
  log dinner") are location-triggered and depend on the
  Phase C PR 2 location picker for the `TriggerLocation`
  parameter at apply time. The 6th is a Japan
  call-screening routine (Phase F).

The user can also save any configured Do / Event / Person as a
user template via the AppBar overflow → "Save as template". The
catalog shows user templates alongside built-ins. Built-ins
are read-only; user templates are deletable via long-press.

Templates restore automatically via the existing backup service
because they are a regular Drift table — no backup-format bump
is required. Phase B ships the data layer, the UI layer, and the
V-Model doc sync; the master plan's quota of 25 curated
templates is met across Phase B + Phase F (19 + 6).

## Routines (v1.0/Phase C–F)

A routine is an `Automation`: a non-time `Trigger` (location,
device-state, calendar event, or incoming call) plus an optional
`Condition` (boolean AND/OR tree over time-window, day-of-week,
calendar-busy, battery-range, silent-mode leaves) plus a
`List<Action>` (notify, fullscreen, call-intercept,
override-silent, open-app). The entity (do / event / person)
carries an optional `List<Automation> automationsJson` envelope;
an entity with an empty list still gets the default
`ActionNotify` synthesized at dispatch time so the existing
alarm-scheduler path keeps working without change.

- **Phase C PR 1** ships the sealed-type spine (`Trigger`,
  `Condition`, `Action`, `Automation`) + the Drift v3 → v4
  migration that adds the `automations_json` column to
  habits / people / events + a no-op `RoutineExecutor`
  skeleton.
- **Phase C PR 2** ships the first concrete non-time trigger
  kind: geofence enter / exit (`TriggerLocationEnter` /
  `TriggerLocationExit`). The user configures a routine from
  the add-do / add-event / add-person screens' "Routines"
  section via the `LocationPicker` bottom sheet
  (ADR-021, SYS-072). `GeofenceService` is the platform seam
  — a `geolocator` ^13.0.1 position stream + a pure-Dart
  Haversine matcher (`computeTransitions`) — and emits
  `GeofenceEntered` / `GeofenceExited` on a broadcast
  `Stream<GeofenceEvent>` that the executor subscribes to.
- **Phase D** adds device-state triggers (charging, battery
  range, bluetooth device, Wi-Fi SSID, headphones, silent
  mode, foreground app).
- **Phase E** adds calendar-event triggers (starts, ends,
  busy, free).
- **Phase F** adds the Japan silent-mode call-screening
  routine (call-intercept + override-silent actions) and
  ships the routine-template apply UX for the 6 routine
  templates seeded in Phase B.

A routine is a first-class field on each entity, parallel
to the existing schedule (time-of-day) path. The two paths
coexist: a do named "Evening walk" can have BOTH a
fixed-time schedule (`DoFixed`) AND a routine that fires
when the user leaves the office geofence. The schedule
and routine are independent — either can fire, both can
fire, neither can fire if `disabled: true`.

Reliability is bounded: a geofence transition fires on
the next position fix after the device crosses the
boundary (typically < 30s of travel; see
[`notification_reliability.md`](notification_reliability.md)
§ "Trigger reliability → Geofence"). A revoked
`ACCESS_COARSE_LOCATION` is a soft failure — the
home-screen reliability banner flips to
`Reliability.degraded` only if the user has at least one
location routine registered; otherwise the denial is
invisible. We do not queue dropped routines.

## Constraints

- **No cloud, no account, no telemetry.** Personal use.
- **No CALL_PHONE permission.** Call reminders open the dialer.
- **No payment cards, no bank data, no credentials.** The app never
  stores anything it could not lose without harm.
- **Android only for v0.1.** iOS is a v0.2+ candidate.
- **Single user, single device.** No sync, no multi-device, no shared
  dos.
- **Data is local.** The app does not perform network calls with user
  data. Any `http(s)://` usage is a defect.
- **Permission-first.** The app explains what it will do with each
  permission before asking.
- **OEM cooperation required.** The app must teach the user how to
  whitelist it from aggressive battery savers, but the user must
  consent to do so. The app must work (with degraded reliability) even
  if the user refuses.

## Success Definition

The app succeeds if, after 30 consecutive days of use, the user can
truthfully answer "yes" to all of the following:

1. do it fired a reminder for each scheduled do within ±60 seconds
   of its target time, for at least 95% of scheduled occurrences.
2. do it survived at least one device reboot without dropping
   reminders.
3. The user called or messaged each named contact at least once per
   cadence window, for at least 80% of windows.
4. The completion log matches the user's honest memory of what they
   did (the app is not lying about consecutive runs).
5. The backup file can be moved off-device, the app can be uninstalled
   and reinstalled, and the backup can be restored with no data loss.
6. The user has not had to fight the app to get it to remind them
   (the OS did not silently kill the alarms).

If even one of these is "no", the app has not yet earned the right to
be the user's daily habit tool. Fix it before adding features.
