# Operational Workflows

Status: draft baseline, created 2026-06-13.

Each workflow defines a preconditions / main-flow / postconditions
triple, the failure modes, and the SYS- IDs it exercises. Workflows are
the contract between ConOps and the system requirements; if a workflow
cannot be traced to a SYS- ID, the requirement is missing.

---

## WF-001 — First-time onboarding

**Preconditions:**
- App is freshly installed.
- No prior data.

**Main flow:**
1. App shows welcome screen and explains the three proof modes
   (Soft / Strong / Auto) with examples.
2. App requests `POST_NOTIFICATIONS` (Android 13+) with a rationale
   that says "without this, reminders are silent".
3. App requests `READ_CONTACTS` with a rationale that says "used only
   to resolve names you have chosen to add to a cadence".
4. App requests `SCHEDULE_EXACT_ALARM` (Android 12+) with a rationale
   that says "without this, fixed-time reminders can be 15+ minutes
   late".
5. App prompts the user to disable battery optimization, with a
   one-tap deep link to the system settings.
6. App prompts the user about OEM auto-start (best-effort detection;
   shows a card with a screenshot-style guide for the user's OEM).
7. App asks the user to pick a backup folder (Storage Access
   Framework).
8. App asks the user to pick a wake-up anchor preference
   (manual only / first-unlock only / either with confirmation).
9. App shows the home screen with three default presets ready to
   accept (drink water, call Mom, morning routine).
10. User taps "Enable" on each preset they want.

**Postconditions:**
- All permissions either granted or explicitly denied by the user
  (the app must not silently request again).
- At least one habit is enabled and has its first occurrence
  scheduled.
- A backup folder is recorded in `shared_preferences`.
- The boot receiver is registered.

**Failure modes:**
- User denies notifications → app shows a banner explaining the
  consequences; the rest of the onboarding continues.
- User denies contacts → call/message preset is hidden, but the
  rest of the onboarding continues.
- User denies exact alarm → app schedules via WorkManager with a
  warning that fixed-time reminders can drift.
- User denies storage → backup is disabled, a banner is shown.

**Requirements covered:** SYS-022, SYS-025, SYS-027.

---

## WF-002 — Add a custom habit

**Preconditions:**
- App is installed and onboarded.

**Main flow:**
1. User taps the floating add button on the home screen.
2. User picks "Habit".
3. User enters a name, an optional icon, and an optional description.
4. User picks a schedule type (Fixed / Interval / Anchor / Day-of-X).
5. User configures the schedule parameters.
6. User picks a proof mode (Soft / Strong / Auto).
7. If Strong, user picks a mission chain (one or more missions in
   order).
8. User picks a streak policy (per-day / rest days / per-habit / off).
9. App validates the configuration (e.g., interval must be ≥5 min,
   anchor must reference an existing anchor habit).
10. User saves.

**Postconditions:**
- A habit record is written to the local DB.
- The next occurrence is scheduled via AlarmManager (or
  WorkManager for inexact).
- A "habit added" snackbar is shown.

**Failure modes:**
- Invalid configuration → field-level errors.
- Exact-alarm denied → schedule via WorkManager, show a "may be
  late" badge.
- Anchor references a non-existent or archived anchor → reject.

**Requirements covered:** SYS-001, SYS-002, SYS-003, SYS-004, SYS-007,
SYS-016, SYS-018, SYS-019.

---

## WF-003 — Add a person (contact) to a call / message cadence

**Preconditions:**
- `READ_CONTACTS` has been granted.
- The user has tapped "Add person" or accepted the "Call Mom" preset.

**Main flow:**
1. App opens a contact picker (filtered to phone numbers / IM
   handles).
2. User picks one or more contacts.
3. For each, the user picks:
   - Cadence: every N days, weekly on day X, monthly on day N, or
     custom.
   - Channel: dialer, WhatsApp, Telegram, Signal, SMS (the channel
     must be installed; the app shows a small badge if not).
   - Mission (if Strong mode is selected for the cadence): pick a
     mission chain.
4. User saves.

**Postconditions:**
- A person record per contact is written.
- The next call-occurrence is scheduled.
- The contact's display name and channel are resolved and cached.

**Failure modes:**
- Contact deleted from device → habit is paused, a banner says
  "Mom is no longer in your contacts; pick a new person or archive".
- IM app not installed → channel is greyed out with "install" link.
- `READ_CONTACTS` revoked → habit is paused.

**Requirements covered:** SYS-001, SYS-002, SYS-004.

---

## WF-004 — Reminder fires (general)

**Preconditions:**
- A habit is scheduled and its next occurrence is due.

**Main flow:**
1. AlarmManager fires (or WorkManager fallback fires).
2. The OS surfaces a high-priority notification with the habit's
   name, due time, and a "Done" / "Open" action.
3. If the screen is off and the user has enabled full-screen intents,
   a full-screen activity is launched (like Alarmy's alarm screen).
4. The full-screen activity shows the habit name, the streak at
   stake, and the proof-mode UI.
5. The user either:
   - Completes the proof and the habit is marked done.
   - Taps "Snooze" → picks a snooze duration (5, 15, 30 min).
   - Taps "Skip" → habit is marked skipped, streak is preserved
     if skip is within rest-day budget.

**Postconditions:**
- The completion (or snooze / skip) is logged.
- The next occurrence is rescheduled.
- If snoozed, a new alarm is set for the snooze time.

**Failure modes:**
- App was killed by OEM → boot receiver re-schedules on next boot;
  the missed occurrence is logged as "missed (system)" so the user
  is not penalized for the OS.
- App was killed mid-mission → next launch detects the open
  mission and resumes it.
- User has Doze + no whitelist → reminder fires up to 15 min late;
  the user is shown a banner on next launch.

**Requirements covered:** SYS-003, SYS-005, SYS-006, SYS-013, SYS-016,
SYS-017, SYS-018, SYS-019, SYS-020.

---

## WF-005 — Complete a Soft-mode reminder

**Preconditions:**
- The user has tapped the notification for a Soft habit.

**Main flow:**
1. The full-screen or in-app screen shows the habit name and a big
   "I did it" button.
2. The user taps the button.
3. A success animation plays, the completion is logged, the streak
   increments, and the next occurrence is scheduled.

**Postconditions:**
- The habit is marked done for the current occurrence.
- The streak counter increments (if applicable).
- The next occurrence is scheduled.

**Failure modes:**
- User tapped by accident → an undo snackbar is shown for 5
  seconds.
- Wrong habit tapped → user can correct in the completion log
  within 24 h.

**Requirements covered:** SYS-005.

---

## WF-006 — Complete a Strong-mode reminder (mission chain)

**Preconditions:**
- The user has tapped the notification for a Strong habit.
- The user is on the mission screen.

**Main flow:**
1. Mission 1 is shown. For each mission, the UI differs:
   - **Shake-N:** A counter "shakes: 0 / 10", live updates from
     `sensors_plus`. Holding still does not advance.
   - **Type phrase:** A text field with the expected phrase in a
     hint. Must match exactly (case-insensitive, trim).
   - **Hold-tap:** A circular progress button that fills over
     3-5 seconds. Releasing early resets the progress.
   - **Math:** A problem rendered (e.g., "17 × 8 = ?"). The user
     types the answer. The next problem is harder on Hard, easier
     on Easy.
   - **Memory:** A 4×3 grid of cards face-down. The user flips
     two at a time; matching pairs stay revealed. All pairs
     matched in ≤60 s = success.
2. On success, mission 1 marks complete. If there is a mission 2,
   it animates in.
3. After the last mission, the completion is logged, streak
   increments, and the next occurrence is scheduled.
4. A "Done — strong proof" toast is shown.

**Postconditions:**
- Mission chain result is logged (which missions passed, in what
  time).
- Completion timestamp is logged.
- Next occurrence is scheduled.

**Failure modes:**
- User backs out of the mission → the habit is not marked done;
  a re-entry banner says "you started a strong mission; finish it
  to keep the streak".
- Sensor unavailable (emulator, no permission) → mission shows a
  fallback ("shake detection unavailable on this device, use Hold
  instead").
- Math answer wrong → user can retry; wrong answers are counted
  in the log (3 wrong in a row = nudge to take a break).
- Memory timer expires → mission is failed; user can retry.

**Requirements covered:** SYS-006, SYS-007, SYS-008, SYS-009, SYS-010,
SYS-011, SYS-012, SYS-020.

---

## WF-007 — Complete an Auto-mode (interval) reminder

**Preconditions:**
- An interval habit is active (e.g., drink water every 30 min).
- The user is inside a confirmation window.

**Main flow:**
1. A notification fires (low-priority, no sound) saying
   "Streak window open — drink water".
2. The user taps the notification or the home widget's "I drank"
   button.
3. The completion is logged with the timestamp.
4. The next window is computed (now + interval).
5. A subtle animation confirms: "Logged. Next at 14:30".

**Postconditions:**
- The window is closed.
- The next window is scheduled.
- If the user did not confirm before the window expired, the
  occurrence is marked missed.

**Failure modes:**
- Window missed → streak break check runs; rest-day budget is
  consulted.
- App was killed → reschedule on next launch via persisted
  schedule.

**Requirements covered:** SYS-007, SYS-019, SYS-020.

---

## WF-008 — Mark "I'm up" (wake-up anchor)

**Preconditions:**
- The user has selected an anchor habit (e.g., morning routine).
- Wake-up anchor preference is set to "manual" or "either".

**Main flow (manual):**
1. The user taps a persistent "I'm up" button on the home
   screen or quick-settings tile (v0.2).
2. The app records the wake-up timestamp.
3. All anchored habits are rescheduled relative to this
   timestamp.

**Main flow (first-unlock with confirmation):**
1. The OS sends `Intent.ACTION_USER_PRESENT` (or
   `KeyguardManager` callback).
2. The app shows a heads-up notification: "Did you just wake
   up? Tap to confirm."
3. User taps. The timestamp is recorded.
4. Anchored habits reschedule.

**Postconditions:**
- Wake-up timestamp is logged.
- Anchored habits are rescheduled.
- A new wake-up event is suppressed for 4 hours (to avoid
  double-fires).

**Failure modes:**
- False positive (user unlocked phone at 02:00 for some other
  reason) → user dismisses; no anchor recorded.
- App was killed at the moment of unlock → next launch
  reconstructs an "approximate wake-up" from the first
  foreground event of the day.

**Requirements covered:** SYS-015, SYS-016, SYS-017.

---

## WF-009 — Snooze a reminder

**Preconditions:**
- A reminder is currently firing or has fired within the last
  5 minutes (snooze is local to one occurrence).

**Main flow:**
1. User taps "Snooze" on the notification or the full-screen
   activity.
2. User picks a duration (5, 15, 30, 60 min).
3. A new alarm is set for the snooze time.
4. A "snoozed until HH:MM" snackbar is shown.
5. A repeat snooze within the same occurrence is allowed up to
   3 times; further taps show "you've snoozed 3 times — skip
   or do it".

**Postconditions:**
- The original occurrence is marked "snoozed".
- A new occurrence-time is set.
- Snooze count for the day is incremented.

**Failure modes:**
- Snooze time has already passed by the time the alarm fires →
  fire immediately, do not skip.

**Requirements covered:** SYS-005, SYS-006, SYS-019.

---

## WF-010 — Skip (use a rest day)

**Preconditions:**
- The user wants to skip without breaking the streak.
- A rest-day budget is configured (default 2 / month).

**Main flow:**
1. User taps "Skip" on the notification.
2. App shows "Use one of your N rest days this month?"
3. User confirms.
4. The occurrence is marked "skipped (rest day)".
5. The streak is preserved.

**Postconditions:**
- Rest-day counter for the month is incremented.
- The next occurrence is scheduled.

**Failure modes:**
- Rest-day budget exhausted → "No rest days left; either do it
  or break the streak."
- Skip is offered only on habits that have rest-day enabled.

**Requirements covered:** SYS-019, SYS-020.

---

## WF-011 — Review weekly stats

**Preconditions:**
- At least 7 days of data exist.

**Main flow:**
1. User opens the Stats tab.
2. App shows, per habit:
   - Current streak.
   - Best streak.
   - Completion rate (last 30 / 90 / 365 days).
   - Time-of-day heatmap.
   - Missed-day distribution.
3. Overall section shows:
   - Total habits hit today.
   - 30-day overall completion rate.
   - All-time strongest habit.

**Postconditions:**
- The user has an honest view of their consistency.

**Failure modes:**
- No data → "Start a habit to see stats here."

**Requirements covered:** SYS-021.

---

## WF-012 — Auto backup runs nightly

**Preconditions:**
- A backup folder is set.
- It is past 02:00 local time.

**Main flow:**
1. WorkManager fires the nightly backup task.
2. The app serializes all habits, people, completions, settings
   to a versioned JSON file.
3. The file is written to the user-chosen folder via the
   remembered SAF URI.
4. Older backups (older than 30 days) are pruned.
5. The backup result is logged.

**Postconditions:**
- A backup file exists in the user's folder.
- The user can move it off-device at any time.

**Failure modes:**
- SAF URI revoked → app falls back to a banner: "Backup folder
  unavailable; pick a new one."
- Write fails → app retries up to 3 times with backoff, then
  notifies the user.

**Requirements covered:** SYS-023.

---

## WF-013 — Restore from backup

**Preconditions:**
- The user has a backup file from a previous install.

**Main flow:**
1. User opens Settings → Restore.
2. User picks a backup file via the system file picker.
3. App validates the file's version and schema.
4. App shows a preview: "X habits, Y people, Z completions,
   dated <date>".
5. User confirms. App wipes the current DB and restores.
6. App reschedules all reminders from the restored schedule.

**Postconditions:**
- The DB is the backup's DB.
- The next occurrence of each habit is scheduled.
- The boot receiver is re-registered (it should already be).

**Failure modes:**
- File is not a valid backup → reject with a clear error.
- File is from a newer version → "this backup is from a newer
  version of Streak; please update the app first".
- File is from an older version → run forward-migrations if any
  exist, else restore as-is.
- Restoring the same file twice is idempotent (no duplicates).

**Requirements covered:** SYS-024.

---

## WF-014 — First-unlock wake-up (alternative)

See WF-008. This workflow exists to document the first-unlock
detection path specifically.

**Preconditions:**
- Wake-up anchor preference = "first-unlock" or "either".

**Main flow:**
1. User unlocks the phone for the first time today.
2. App shows a heads-up: "Wake-up recorded at 07:12. Anchor
   morning routine to this?"
3. User confirms → anchor recorded.
4. User dismisses → no anchor recorded; the next unlock of
   the day is also a candidate.

**Postconditions:**
- The first confirmed unlock of the day is the wake-up
  timestamp.
- A 4-hour debounce prevents a second wake-up event.

**Requirements covered:** SYS-015, SYS-016, SYS-017.

---

## WF-015 — Device reboot survival

**Preconditions:**
- The device reboots.
- Streak was installed and had scheduled reminders.

**Main flow:**
1. The OS finishes booting.
2. The boot receiver in Streak fires.
3. The app re-schedules all pending reminders from the local
   DB.
4. The app logs the reboot-reschedule event.

**Postconditions:**
- All scheduled reminders are re-armed.
- The schedule is the same as before the reboot (modulo
  elapsed time — past occurrences are marked missed).

**Failure modes:**
- Boot receiver denied (some OEM settings) → app cannot
  re-schedule until the user opens it. Banner: "Open Streak
  once to re-arm your reminders."
- App data was wiped by the OEM → user starts fresh (this is
  not a bug; it's a factory reset).

**Requirements covered:** SYS-016, SYS-017.

---

## WF-016 — Timezone change / travel

**Preconditions:**
- The user changes time zone, or crosses a zone while traveling.

**Main flow:**
1. The OS fires `ACTION_TIMEZONE_CHANGED`.
2. The app re-computes all schedules in the new zone.
3. Fixed-time habits fire at the same wall-clock time in the
   new zone.
4. Interval habits re-anchor to "next multiple of interval
   from now".
5. Anchor habits reference the last wake-up event, re-mapped
   to the new zone.

**Postconditions:**
- The schedule is sensible in the new zone.
- Past occurrences in the old zone that have not yet been
  logged are marked missed (the user is not penalized for
  travel after the fact).

**Failure modes:**
- DST jump forward → a 02:30 habit is silently dropped (it
  didn't exist). The user is informed on next launch.
- DST jump back → a 02:30 habit fires twice (rare; the
  second one is deduped by occurrence-id).

**Requirements covered:** SYS-016, SYS-017.
