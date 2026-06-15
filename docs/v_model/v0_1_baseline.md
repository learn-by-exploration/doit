# v0.1 Requirements Baseline

Status: draft baseline, created 2026-06-13. Renamed from "Streak" to
"do it" in v0.5a (commit in v0.5).

## Product Name

Working name: **do it** (originally "Streak" until v0.5a).

Short, action-focused, voice-friendly. Reads naturally in a
notification ("do it: Call Mom — due in 12 min"). May be revisited
before any public release if a simpler or more creative name appears.

The package id is `com.doit.package`. The display name in the
launcher is "do it".

## Prototype Strategy

- **Tech stack:** Flutter 3.44 / Dart 3.12, matching `board_box` and
  `card_box`.
- **First target:** Android only, Android 9+ (API 28+).
- **iOS support** is a v0.2+ candidate. The model layer is
  platform-agnostic; the platform integration layer
  (`lib/reminders/`, `lib/services/`) is Android-only in v0.1.
- **Local-first.** All data on-device. No cloud, no account, no
  analytics.
- **Single user, single device.** No sync.
- **No `CALL_PHONE`, no `INTERNET`-with-data.** Calling reminders open
  the dialer pre-filled.
- **Permission-first.** Every platform interface is requested with a
  rationale.

## Habit Presets (v0.1)

Four presets ship out of the box. The user can accept or skip each.

| Preset | Schedule | Proof mode | Notes |
| --- | --- | --- | --- |
| **Drink water** | Interval: every 30 min, 8×/day, 08:00–20:00 | Auto (one-tap in window) | Time is the proof |
| **Call / message &lt;person&gt;** | Per-person cadence (e.g. every 3 days, weekly on Sunday, monthly on the 1st) | Strong (mission required) | Default mission: Shake-N=10 |
| **Morning routine** | Fixed: 06:30 weekdays, 09:00 weekends; chained steps (workout → shower → breakfast) | Strong (mission required) | Default mission: Hold-tap 4s; anchored to "I'm up" |
| **Daily todo** | One-off, user-defined | Soft (one-tap) or Strong (user-pickable) | Free-form; not auto-recurring |

The preset system is extensible. Users can add custom habits beyond
these four (e.g., "Read 20 min", "Stretch", "Practice guitar") with
any of the four schedule types and any of the three proof modes.

## Schedule Types (v0.1)

All four are first-class:

| Type | Example | Engine |
| --- | --- | --- |
| **Fixed** | "Every day at 07:00" | `nextOccurrence()` = next wall-clock 07:00 in the device's zone |
| **Interval** | "Every 30 min, 8×/day, 08:00–20:00" | `nextOccurrence()` = next multiple of 30 min inside the window |
| **Anchor** | "30 min after I mark I'm up" | Re-scheduled when anchor event is recorded |
| **Day-of-X** | "Mon/Wed/Fri at 18:00" / "On the 1st at 09:00" / "Annually on Mar 15" | Cron-like evaluator over the date |

## Mission Types (v0.1)

All five are first-class:

| Mission | Engine | Sensors / Inputs |
| --- | --- | --- |
| **Shake-N** | `sensors_plus` accelerometer; magnitude + inter-shake spacing | Accelerometer |
| **Type phrase** | TextField with exact match (case-insensitive, trim) | Keyboard |
| **Hold-tap** | Press-and-hold circular progress, 3-5 s | Touch |
| **Math** | Random problem; difficulty scales (Easy / Normal / Hard) | Keyboard |
| **Memory** | 4×3 card-match grid, 60 s timer | Touch |

Each habit's Strong-mode can chain multiple missions in declared
order. Chains execute in order; a failure in mission N forces a retry
of mission N (not a restart of the chain).

Defer to v0.2: Barcode/QR, Photo.

## do it Model (v0.1)

User-configurable per habit; defaults are sensible.

- **Per-habit streak:** consecutive successful days (or, for
  interval habits, consecutive successful windows).
- **Overall streak:** % of active habits hit per day, threshold
  configurable (default 80%).
- **Rest-day budget:** default 2 / month per habit. The user can
  consume a rest day to skip without breaking the streak.
- **Grace window:** default "until 03:00 next day", so a habit
  completed just past midnight still counts for the previous day.
- **do it off:** a habit can opt out of streaks entirely and just
  show raw completion rate.

## Proof Modes (v0.1)

| Mode | When to use | Behavior |
| --- | --- | --- |
| **Soft** | Cheap, honest habits (todo, daily check-in) | One-tap "I did it". Friction: ~1 second. |
| **Strong** | Habits the user tends to skip (workout, call Mom) | Mission chain required. Friction: 10-60 seconds. |
| **Auto** | Interval habits (drink water, posture) | Time is the proof. Window-based confirm. No mission. |

The mode is per-habit. A user can change it later, but the
completion log records which mode was in effect at the time of each
completion (so changing mode mid-streak does not retroactively
invalidate the history).

## Wake-up Anchor (v0.1)

User picks one of three in settings:

- **Manual only:** a persistent "I'm up" button on the home screen
  and (v0.2) a quick-settings tile.
- **First-unlock only:** the first confirmed unlock of the day
  anchors the routine.
- **Either with confirmation:** first unlock shows a heads-up; user
  confirms to anchor.

A 4-hour debounce prevents double-fires.

## Reliability (v0.1)

- **Primary:** AlarmManager exact alarm (`setExactAndAllowWhileIdle`).
- **Fallback:** WorkManager periodic + one-shot, with a 15-minute
  grace.
- **User prompt:** on first scheduling of a fixed-time habit, the
  app detects whether the user has granted
  `SCHEDULE_EXACT_ALARM` and whether battery optimization is on. If
  not, it shows a one-tap deep link to the system settings.
- **Boot survival:** `RECEIVE_BOOT_COMPLETED` broadcast receiver
  re-schedules all pending reminders.
- **OEM guide card:** if the OEM is detected as aggressive (Xiaomi,
  Oppo, Vivo, Honor, Samsung with battery-saver), the app shows a
  card with screenshots-style text on how to enable auto-start.

See [`notification_reliability.md`](notification_reliability.md) for
the full design and verification plan.

## Backup (v0.1)

- **Format:** plain JSON, versioned (`"version": 1`).
- **Schedule:** once per day, between 02:00 and 04:00 local.
- **Location:** user-chosen folder via Storage Access Framework.
- **Retention:** 30 days. Older files pruned.
- **Restore:** user picks a file via the system file picker. App
  validates, previews, and confirms before replacing the DB.
- **Encryption:** out of scope for v0.1. Planned for v0.2 with a
  user passphrase.

## Acceptance Test Set

For the 14-day real-device run, the user will exercise:

- A Drink Water habit, default settings.
- A Call Mom habit, every-3-days cadence, Strong mode with Shake-N=10.
- A Morning Routine habit, 06:30 weekdays, Strong mode with Hold-tap
  4 s, anchored to first-unlock.
- A Daily Todo habit (e.g., "Submit report"), Soft mode.
- One custom habit, e.g., "Read 20 min", Fixed 21:00, Strong mode
  with Type phrase.
- A rest day on the Morning Routine habit.
- One snooze of the Call Mom habit.
- One backup restore after a fresh install.
- One forced reboot during a scheduled reminder.
- One timezone change (set the device zone forward 3 hours while
  reminders are pending).

The 3-gate must pass on every commit during the 14 days. The CI
must be green.

## Approval Status

This baseline is ready to drive initial Flutter scaffolding and
prototype implementation. If the user changes any of the product
decisions above, the affected SYS- IDs and the
[traceability matrix](traceability_matrix.md) must be updated in the
same change.
