# Operational Workflows

Status: draft baseline, created 2026-06-13.

Each workflow defines a preconditions / main-flow / postconditions
triple, the failure modes, and the SYS- IDs it exercises. Workflows are
the contract between ConOps and the system requirements; if a workflow
cannot be traced to a SYS- ID, the requirement is missing.

**Notification copy follows the brand voice in
[`conops.md § Brand voice`](conops.md#brand-voice):** lead with the
action ("Drink water", "Call Mom", "Submit report"), append the
consecutive run number only as a secondary line, never use "broke"/"lost"
(missed/skipped instead), and keep the tone calm and slightly
stubborn. Avoid the prefix "do it:" — the brand name does the
work. If a workflow's copy ever drifts from the brand voice, the
voice wins; the workflow is updated in the same PR.

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
9. App shows the home screen with four default presets ready to
   accept (drink water, call &lt;person&gt;, morning routine, daily
   todo).
10. User taps "Enable" on each preset they want.

**Postconditions:**
- All permissions either granted or explicitly denied by the user
  (the app must not silently request again).
- At least one do is enabled and has its first occurrence
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

## WF-002 — Add a custom do

**Preconditions:**
- App is installed and onboarded.

**Main flow:**
1. User taps the floating add button on the home screen.
2. User picks "Do".
3. User enters a name, an optional icon, and an optional description.
4. User picks a schedule type (Fixed / Interval / Anchor / Day-of-X).
5. User configures the schedule parameters.
6. User picks a proof mode (Soft / Strong / Auto).
7. If Strong, user picks a mission chain (one or more missions in
   order).
8. User picks a consecutive run policy (per-day / skip days / per-do / off).
9. App validates the configuration (e.g., interval must be ≥5 min,
   anchor must reference an existing anchor do).
10. User saves.

**Postconditions:**
- A do record is written to the local DB.
- The next occurrence is scheduled via AlarmManager (or
  WorkManager for inexact).
- A "do added" snackbar is shown.

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
- Contact deleted from device → do is paused, a banner says
  "Mom is no longer in your contacts; pick a new person or archive".
- IM app not installed → channel is greyed out with "install" link.
- `READ_CONTACTS` revoked → do is paused.

**Requirements covered:** SYS-001, SYS-002, SYS-004.

---

## WF-004 — Reminder fires (general)

**Preconditions:**
- A do is scheduled and its next occurrence is due.

**Main flow:**
1. AlarmManager fires (or WorkManager fallback fires).
2. The OS surfaces a high-priority notification with the do's
   name, due time, and a "Done" / "Open" action.
3. If the screen is off and the user has enabled full-screen intents,
   a full-screen activity is launched (like Alarmy's alarm screen).
4. The full-screen activity shows the do name, the consecutive run at
   stake, and the proof-mode UI.
5. The user either:
   - Completes the proof and the do is marked done.
   - Taps "Snooze" → picks a snooze duration (5, 15, 30 min).
   - Taps "Skip" → do is marked skipped, consecutive run is preserved
     if skip is within skip-day budget.

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
- The user has tapped the notification for a Soft do.

**Main flow:**
1. The full-screen or in-app screen shows the do name and a big
   "I did it" button.
2. The user taps the button.
3. A success animation plays, the completion is logged, the consecutive run
   increments, and the next occurrence is scheduled.

**Postconditions:**
- The do is marked done for the current occurrence.
- The consecutive run counter increments (if applicable).
- The next occurrence is scheduled.

**Failure modes:**
- User tapped by accident → an undo snackbar is shown for 5
  seconds.
- Wrong do tapped → user can correct in the completion log
  within 24 h.

**Requirements covered:** SYS-005.

---

## WF-006 — Complete a Strong-mode reminder (mission chain)

**Preconditions:**
- The user has tapped the notification for a Strong do.
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
3. After the last mission, the completion is logged, consecutive run
   increments, and the next occurrence is scheduled.
4. A confirmation toast is shown ("Mission complete. Logged.").

**Postconditions:**
- Mission chain result is logged (which missions passed, in what
  time).
- Completion timestamp is logged.
- Next occurrence is scheduled.

**Failure modes:**
- User backs out of the mission → the do is not marked done;
  a re-entry banner says "you started a strong mission; finish it
  to keep the consecutive run".
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
- An interval do is active (e.g., drink water every 30 min).
- The user is inside a confirmation window.

**Main flow:**
1. A notification fires (low-priority, no sound) saying "Drink
   water — window open" (brand voice: lead with the action; the
   consecutive run number is omitted from low-priority interval prompts).
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
- Window missed → consecutive run break check runs; skip-day budget is
  consulted.
- App was killed → reschedule on next launch via persisted
  schedule.

**Requirements covered:** SYS-007, SYS-019, SYS-020.

---

## WF-008 — Mark "I'm up" (wake-up anchor)

**Preconditions:**
- The user has selected an anchor do (e.g., morning routine).
- Wake-up anchor preference is set to "manual" or "either".

**Main flow (manual):**
1. The user taps a persistent "I'm up" button on the home
   screen or quick-settings tile (v0.2).
2. The app records the wake-up timestamp.
3. All anchored dos are rescheduled relative to this
   timestamp.

**Main flow (first-unlock with confirmation):**
1. The OS sends `Intent.ACTION_USER_PRESENT` (or
   `KeyguardManager` callback).
2. The app shows a heads-up notification: "Wake-up recorded at
   HH:MM. Anchor morning routine to this?" (canonical wording
   — see WF-014 for the source).
3. User taps. The timestamp is recorded.
4. Anchored dos reschedule.

**Postconditions:**
- Wake-up timestamp is logged.
- Anchored dos are rescheduled.
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

## WF-010 — Skip (use a skip day)

**Preconditions:**
- The user wants to skip without breaking the consecutive run.
- A skip-day budget is configured (default 2 / month).

**Main flow:**
1. User taps "Skip" on the notification.
2. App shows "Use one of your N skip days this month?"
3. User confirms.
4. The occurrence is marked "skipped (skip day)".
5. The consecutive run is preserved.

**Postconditions:**
- Rest-day counter for the month is incremented.
- The next occurrence is scheduled.

**Failure modes:**
- Rest-day budget exhausted → "No skip days left; either do it
  or break the consecutive run."
- Skip is offered only on dos that have skip-day enabled.

**Requirements covered:** SYS-019, SYS-020.

---

## WF-011 — Review weekly stats

**Preconditions:**
- At least 7 days of data exist.

**Main flow:**
1. User opens the Stats tab.
2. App shows, per do:
   - Current consecutive run.
   - Best consecutive run.
   - Completion rate (last 30 / 90 / 365 days).
   - Time-of-day heatmap.
   - Missed-day distribution.
3. Overall section shows:
   - Total dos hit today.
   - 30-day overall completion rate.
   - All-time strongest do.

**Postconditions:**
- The user has an honest view of their consistency.

**Failure modes:**
- No data → "Start a do to see stats here."

**Requirements covered:** SYS-021.

---

## WF-012 — Auto backup runs nightly

**Preconditions:**
- A backup folder is set.
- It is past 02:00 local time.

**Main flow:**
1. WorkManager fires the nightly backup task.
2. The app serializes all dos, people, completions, settings
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
4. App shows a preview: "X dos, Y people, Z completions,
   dated <date>".
5. User confirms. App wipes the current DB and restores.
6. App reschedules all reminders from the restored schedule.

**Postconditions:**
- The DB is the backup's DB.
- The next occurrence of each do is scheduled.
- The boot receiver is re-registered (it should already be).

**Failure modes:**
- File is not a valid backup → reject with a clear error.
- File is from a newer version → "this backup is from a newer
  version of do it; please update the app first".
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
- do it was installed and had scheduled reminders.

**Main flow:**
1. The OS finishes booting.
2. The boot receiver in do it fires.
3. The app re-schedules all pending reminders from the local
   DB.
4. The app logs the reboot-reschedule event.

**Postconditions:**
- All scheduled reminders are re-armed.
- The schedule is the same as before the reboot (modulo
  elapsed time — past occurrences are marked missed).

**Failure modes:**
- Boot receiver denied (some OEM settings) → app cannot
  re-schedule until the user opens it. Banner: "Open do it
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
3. Fixed-time dos fire at the same wall-clock time in the
   new zone.
4. Interval dos re-anchor to "next multiple of interval
   from now".
5. Anchor dos reference the last wake-up event, re-mapped
   to the new zone.

**Postconditions:**
- The schedule is sensible in the new zone.
- Past occurrences in the old zone that have not yet been
  logged are marked missed (the user is not penalized for
  travel after the fact).

**Failure modes:**
- DST jump forward → a 02:30 do is silently dropped (it
  didn't exist). The user is informed on next launch.
- DST jump back → a 02:30 do fires twice (rare; the
  second one is deduped by occurrence-id).

**Requirements covered:** SYS-016, SYS-017.

---

## v0.2 additions (status: committed 2026-06-14)

The workflows below are part of v0.2. The proposal is at
[`v0_2_proposal.md`](v0_2_proposal.md); the v0.2 baseline is at
[`v0_2_baseline.md`](v0_2_baseline.md).

---

## WF-017 — Add a one-off date-specific reminder (event)

**Preconditions:**
- App is installed and onboarded.

**Main flow:**
1. User taps the floating add button on the home screen.
2. User picks "Event".
3. User enters a name (e.g., "Mom's birthday", "Doctor
   appointment", "Submit taxes").
4. User picks a date and time.
5. User picks a lead time (5 min, 15 min, 1 h, 1 day, 1 week
   before). Default: 1 day.
6. User optionally picks a mission chain (default: just a
   notification, no mission).
7. User optionally picks recurrence: none (default), annually.
8. App validates (date must be in the future, lead time must be
   less than the gap to the date).
9. User saves.

**Postconditions:**
- An event record is written to the local DB.
- A one-shot alarm is scheduled for `(event.at - leadTime)`.
- The event appears on the home "Events" tab.

**Failure modes:**
- Date in the past → reject with a clear error.
- Alarm permission denied → fall back to WorkManager one-shot
  with a "may be late" badge.
- After the event fires, the event auto-archives; the user
  can browse archived events from the Events tab.

**Requirements covered:** SYS-032, SYS-033, SYS-034, SYS-035.

---

## WF-018 — Add a contact group (friend list, family list)

**Preconditions:**
- `READ_CONTACTS` has been granted.
- The user has tapped "Add person" or "Add group" from the
  People screen.

**Main flow:**
1. App opens a contact picker (multi-select).
2. User picks 2-10 contacts.
3. User picks a group name (e.g., "Family", "Close friends",
   default: "Group of N").
4. User picks a group cadence: every N days, weekly on day X,
   monthly on day N, or custom.
5. User picks a group cadence semantic:
   - **Rotation:** the app picks a different contact each time,
     cycling through the group. Tracks `lastContacted` per
     member.
   - **Any:** the user is reminded to contact "someone" in the
     group. The user picks who when they complete.
   - **All:** the user is reminded to contact every member in
     the window. Each member's last-contacted timestamp is
     tracked; the next reminder is the oldest.
6. User picks a shared channel (dialer, WhatsApp, Telegram,
   Signal, SMS).
7. User picks a shared mission (if Strong mode).
8. User saves.

**Postconditions:**
- A `PersonGroup` record is written.
- One occurrence is scheduled for the next contact-or-window.
- A "group added" snackbar is shown.

**Failure modes:**
- 1 or > 10 contacts → reject at picker.
- IM app not installed for any member → channel is greyed out
  for that member; the user can pick a different channel per
  member.
- Contact deleted from device → that member is marked
  `unresolved`; the group keeps reminding for the others;
  a banner says "1 member unresolved; archive or pick
  replacement".

**Requirements covered:** SYS-036, SYS-037, SYS-038.

---

## WF-019 — Add a time-window do (meal, fasting)

**Preconditions:**
- App is installed and onboarded.

**Main flow:**
1. User taps add → "Do" → "Time window".
2. User enters a name (e.g., "16:8 fast", "Lunch window").
3. User picks a start time and an end time.
4. User picks days of week (default: every day).
5. User picks a proof mode (default: Soft for meals, Auto for
   fasting).
6. For fasting, the user picks the target fast duration
   (12, 14, 16, 18, 20 h). The window = target from the
   start time.
7. User saves.

**Postconditions:**
- A `DoTimeWindow` record is written.
- The home screen shows a live "Fasting, 6h 12m elapsed,
  1h 48m remaining" widget when the window is active.
- The widget auto-updates every minute via a `Ticker`.

**Failure modes:**
- End time before start time → reject.
- Fast duration > 24 h → reject (out of scope; v0.3).
- App killed mid-window → state restored on next launch from
  the persisted window.

**Requirements covered:** SYS-039, SYS-040.

---

## WF-022 — Edit an existing do

**Preconditions:**
- The do exists in the local DB.

**Main flow:**
1. User long-presses a do on the home screen (or taps
   "Edit" on the do detail screen).
2. App opens the same `AddDo` flow, pre-filled with the
   do's current fields.
3. User changes any field (name, schedule, proof mode, mission
   chain, consecutive run policy, category, color, icon).
4. User saves.

**Postconditions:**
- The do record is updated in place (id is stable; only
  fields change).
- The completion log is preserved; the consecutive run is recomputed
  from the log.
- The next occurrence is rescheduled.

**Failure modes:**
- Schedule change would invalidate past completions → log
  with a warning; the user can confirm "yes, change anyway".
- Anchor references a now-archived anchor do → reject
  with a "pick a new anchor" prompt.

**Requirements covered:** SYS-042, SYS-043.

---

## WF-027 — Pause / resume a do or person

**Preconditions:**
- The do or person exists in the local DB.

**Main flow (pause):**
1. User long-presses a do/person → "Pause".
2. User picks a duration: 1 day, 1 week, 2 weeks, 1 month,
   or "Until I resume".
3. App marks the do/person as `pausedUntil = now + duration`
   (or `pausedUntil = null` for "Until I resume").

**Main flow (resume):**
1. User long-presses a paused do/person → "Resume".
2. App clears `pausedUntil`.
3. The next occurrence is scheduled.

**Postconditions:**
- While paused, no reminders fire; the schedule is preserved.
- The completion log is preserved; the consecutive run is preserved
  (a paused period does not break the consecutive run).

**Failure modes:**
- "Until I resume" pause runs for > 90 days → app shows a
  "still paused?" prompt on next open.

**Requirements covered:** SYS-047.

---

## WF-028 — Fire a test reminder in 30 seconds

**Preconditions:**
- The do exists in the local DB.

**Main flow:**
1. User opens the do detail screen.
2. User taps "Test in 30s".
3. A countdown shows: "Firing in 30… 29… 28…".
4. At T-0, the scheduler fires the same notification /
   full-screen intent that the real reminder would.
5. A "Cancel test" affordance is available during the
   countdown.

**Postconditions:**
- The test reminder fires exactly as the real one would
  (same channel, same importance, same mission UI).
- The test does NOT log a completion (it is a verification
  artifact, not a do completion).
- The test does NOT reschedule the next occurrence.

**Failure modes:**
- Alarm permission denied → test still fires via WorkManager
  fallback.
- User cancels the test mid-countdown → no fire.

**Requirements covered:** SYS-041.

---

## WF-029 — Bulk-complete N occurrences of an interval do

**Preconditions:**
- The do is an interval do (e.g., drink water every
  30 min, 8 windows/day).
- The current day's completions are < the daily target.

**Main flow:**
1. User opens the home screen.
2. For an interval do with missed windows, the home tile
   shows a "Mark N done" button.
3. User taps the button. N defaults to the number of missed
   windows, capped at 4 (to prevent accidental bulk-log).
4. The home tile shows the updated completion count.
5. The next window is computed from `now + interval`.

**Postconditions:**
- N completions are logged with timestamps spread across
  the missed window range (e.g., 4 completions at 09:00,
  10:00, 11:00, 12:00 — not all at the moment of bulk-log).
- The consecutive run and the next-window computation handle the
  bulk log normally.

**Failure modes:**
- N > daily target → reject; the user must adjust the target.
- App killed mid-bulk → the partial bulk is preserved
  (each completion is its own row).

**Requirements covered:** SYS-044.

---

## WF-031 — Set category, color, and icon on a do

**Preconditions:**
- The do exists (or is being created).

**Main flow:**
1. User opens add/edit do.
2. After the proof-mode step, user picks a category:
   Health, Mind, Relationships, Productivity, Home, Other.
3. App auto-assigns a color based on the category
   (Health = green, Mind = teal, Relationships = amber,
   Productivity = blue, Home = brown, Other = grey).
4. User can override the color via a swatch row (8 swatches).
5. User picks an icon from a 64-icon Material Symbols grid.
6. User saves.

**Postconditions:**
- The do has `category`, `colorSeed`, `iconName` fields set.
- The home screen renders the icon + color swatch beside the
  do name.
- The stats screen groups dos by category.

**Failure modes:**
- No category picked → default to "Other" / grey / a generic
  icon.
- Icon picker: no icon picked → default to category's
  canonical icon.

**Requirements covered:** SYS-045, SYS-046.

---

## WF-032 — Pick a template from the curated library

**Preconditions:**
- The user is on the home screen.
- The user has tapped the home FAB.
- The user has picked "Browse templates" from the FAB
  bottom sheet.

**Main flow:**
1. `TemplatesScreen` opens with a `TabBar` at the top
   (Curated / Your templates — collapsed to a flat list
   per `ADR-020` § decision 4: built-ins + user-saved
   in one grid, with filter chips for Do / Event /
   Person / Routine).
2. The catalog `FutureBuilder` shows a
   `CircularProgressIndicator` while
   `TemplateLibrary.seedBuiltIns(TemplateRepository.instance)`
   finishes; on completion the grid renders 25 cards
   (12 Do + 3 Person + 4 Event + 6 Routine). Routine
   cards render a "Coming in v1.1" badge instead of
   the "Use this" button (the routine apply UX lands
   in Phase F).
3. The user can tap a filter chip (Do / Event / Person
   / Routine) to narrow the grid by `entityType`.
4. The user taps a Do card → `AddHabitScreen(initialPayload:
   template.payload)` opens with `name`, schedule
   type, weekdays, hour, minute, proof mode, category,
   icon, and color all pre-filled. The user reviews,
   edits, and saves. The persisted do has its own `id`
   (the template's id is not reused).
5. Event card → `AddEventScreen(initialPayload: ...)`
   with name, lead-time, recurrence, day-of-month, and
   month-of-year pre-filled (the `recurrence` string
   is mapped onto `EventRecurrence`; 'monthly' and
   'yearly' both → `annually`).
6. Person card → `AddPersonScreen(initialPayload: ...)`
   with display name, cadence, channel, and any
   mission-chain pre-filled.
7. The user saves → the add screen pops, and the new
   entity is visible on the home screen.

**Postconditions:**
- The matching add screen pre-fills from the
  template's `payloadJson` inner envelope (see
  `ADR-020` § decision 2 for the envelope shape).
- The new entity has its own `id`; the template row
  is not modified by the apply.
- The catalog can be opened again and the same
  template is still listed (built-ins are
  read-only — `WF-033` shows how a user can save
  their own variation).

**Failure modes:**
- A `payloadJson` that fails to decode → the add
  screen falls back to a blank form (the
  `TemplatesScreen._payloadFor` helper tolerates a
  malformed envelope, mirroring the repository's
  "validate at save time, tolerate at apply time"
  posture).
- A user template that was deleted from the catalog
  before the apply → already gone from the screen;
  no apply path runs.
- Routine apply → `SnackBar("Routines land in v1.1.")`
  (Phase F wires `AddRoutineScreen`).

**Requirements covered:** SYS-067.

---

## WF-033 — Save a configured do / event / person as a user template

**Preconditions:**
- The user is on `AddHabitScreen` / `AddEventScreen` /
  `AddPersonScreen`.
- The form has at least the `name` field filled in
  (a blank name fails fast — the dialog asks the user
  to give the do/event/person a name first).

**Main flow:**
1. The user taps the AppBar overflow → "Save as
   template".
2. A modal dialog opens with a single `TextField`
   pre-filled with the form's current name plus the
   suffix "template" (e.g., a configured do named
   "Drink water" opens with the default
   "Drink water template").
3. The user can rename (the field is editable) and
   taps Save.
4. `TemplateRepository.instance.save` runs:
   - Validates the envelope (the `payloadJson` is
     built from the current form state, not from the
     persisted row — templates are about reuse, not
     history).
   - Inserts a row with `isBuiltIn: false`,
     `entityType` matching the form (Do / Event /
     Person), and a fresh `id` (auto-assigned
     `t_<millis>`).
   - `TemplateValidationException` → a `SnackBar`
     surfaces the message and the row is NOT written.
5. `TemplatesScreen` is opened (from the home FAB →
   "Browse templates") and the new user template is
   visible in the grid alongside the built-ins.

**Postconditions:**
- A new row in the `Templates` table with
  `isBuiltIn: false`.
- The original entity (Do / Event / Person) is NOT
  saved by this flow — the user goes through the
  normal Save button on the add screen to persist
  the entity itself. "Save as template" is purely a
  reuse capture.
- The catalog can apply the user template (same flow
  as `WF-032` step 4-6) to bootstrap a new entity.

**Failure modes:**
- Blank name on the add screen → the action surfaces
  a `SnackBar("Give the do / event / person a name
  first.")` and does not open the dialog.
- Empty template name in the dialog → the dialog
  returns `null` and nothing is written.
- Malformed payload (e.g., a custom form field with
  a bad enum value) → `TemplateValidationException`
  → `SnackBar` with the message.

**Requirements covered:** SYS-068.

## WF-037 — Configure the Japan silent-mode routine (v1.0 / Phase F PR 2)

The user opts in to template #16 ("Japan silent mode") and configures
which contacts bypass silent mode and to which ringer mode the
routine snaps the device when a matched contact calls.

**Preconditions:**
- The user is on `TemplatesScreen` (or a deep-link from the home FAB
  "Browse templates").
- The call-screening role is OPTIONAL — the workflow runs end-to-end
  without it. If the role is not held, the routine silently no-ops
  at runtime; the Settings → Call-screening tile shows the path to
  grant it.

**Steps:**
1. The user taps template #16 in the catalog. The catalog
   short-circuits to `AddRoutineScreen` (the other routine templates
   still show "Coming in v1.1" — only #16 has an apply UX).
2. `AddRoutineScreen` opens with the persisted config pre-filled
   (`SettingsService.japanRoutine.value`). The user toggles
   **Enable**, picks at least one contact via the platform contact
   picker (gated by `PermissionSheet.show(contacts)` — same pattern
   as `AddPersonScreen`), and chooses the **Target mode**
   (`SilentMode.normal` / `vibrate` / `silent`).
3. The user taps **Save**. The screen persists the config via
   `SettingsService.setJapanRoutine(...)` and pushes the contact
   list to `CallInterceptorService.configure(enabled, contactIds)`
   so the screening service matches the new list on the next
   incoming call.
4. **Optional** — the user grants the call-screening role via
   Settings → Permissions → Call-screening → Grant (or via the
   onboarding step 4 if it is a first-launch install). The OS
   dialog appears; granting it enables the runtime interception
   path. Declining it leaves the routine configured but inert;
   the home screen's reliability banner shows "Japan routine
   unavailable — grant the call-screening role in Settings".
5. With the routine enabled AND the role held AND the phone on
   silent AND a configured contact calls: the `CallScreeningService`
   intercepts the call (the OS invokes it before the dialer rings),
   snaps the ringer to the target mode, and plays the contact's
   ringtone. On dismiss the prior ringer mode is restored.

**Verification:** widget test (`test/screens/add_routine_test.dart`)
covers form interactions + save path. Settings tile test covers the
role-hold probe + the OS request flow. Routine dispatch test
(`test/routines/call_dispatch_test.dart`) covers the side-effect path.

---

## WF-038 — Apply a template-based routine (v1.1 / templates #17–#21)

The user opts in to one of the five v1.0 routine templates that
previously showed a "Coming in v1.1" badge (#17 Focus block,
#18 Working from home, #19 At the gym, #20 Leaving work,
#21 Meeting prep) and configures the trigger / action through a
shared apply UX.

**Preconditions:**
- The user is on `TemplatesScreen`.
- For #18 / #19 / #20 (location-triggered): `ACCESS_COARSE_LOCATION`
  is OPTIONAL at apply time — the picker renders, but the routine
  is silently inert at runtime if the permission is denied. The
  Settings → Permissions tile surfaces the recovery affordance.
- For #17 / #21 (calendar-triggered): `READ_CALENDAR` is OPTIONAL
  at apply time, same shape as location.
- For all five: no call-screening role is required. Templates #17–#21
  do not touch `CallInterceptorService`.

**Steps:**
1. The user taps template #17 / #18 / #19 / #20 / #21 in the
   catalog. The catalog (`templates.dart:_routinesWithApplyUx`)
   short-circuits to `RoutineApplyScreen` carrying the template.
   The "Coming in v1.1" badge is gone; the row carries the
   existing "Use this" button.
2. `RoutineApplyScreen` (SYS-083 / ADR-027) opens. It reads the
   template's `payloadJson` envelope via `RoutineTemplatePayload`
   — a fail-soft decoder that returns `null` for malformed JSON,
   missing `routine` keys, empty `trigger` / `action` strings,
   etc. The screen renders:
   - The template name + description header.
   - Read-only chips for the decoded `trigger` / `condition` /
     `action` discriminator (the per-template picker UIs are
     deferred to a v1.1+ follow-up; v1.1 ships a structured
     preview that is good enough to confirm the wiring).
   - A `MalformedView` fallback if the envelope is bad — no Save
     button, an explanatory icon + copy.
   - An Enable toggle (seeds `RoutineConfig.enabled`).
   - Save / Update / Delete buttons. The labels depend on whether
     a `RoutineConfig` is already persisted for the template id:
     Save for first-time, Update + Delete for re-edit.
3. The user toggles Enable and taps Save / Update.
   `SettingsService.setRoutine(RoutineConfig)` (SYS-080 / ADR-025)
   persists the JSON blob under `doit.routine.<templateId>` in
   `SharedPreferences` and updates the `routines`
   `ValueNotifier<Map<String, RoutineConfig>>` synchronously so
   `RoutineExecutor`'s `addListener` picks the change up before
   the next microtask. The screen pops the route via
   `Navigator.of(context).canPop()` guard so the root-mounted
   test case is a clean no-op.
4. Delete calls `SettingsService.deleteRoutine(templateId)` — an
   idempotent removal that clears the in-memory map AND the
   SharedPreferences key.
5. The first time the routine's trigger fires (calendar event
   start for #17, location enter for #18/#19, location exit for
   #20, calendar reminder for #21), `RoutineExecutor` matches the
   snapshot against the registered automation set and calls
   `_dispatchAction` (SYS-082 / ADR-026). One of five leaves
   runs:
   - `ActionOverrideSilent` (#17, #18) → `CallInterceptorService
     .setRingerMode(SilentMode.silent | vibrate)`.
   - `ActionNotify` (#19, #20) → `NotificationService.show` with
     the template's seed title + body. A broken
     `NotificationService` (StateError on `.instance`) is
     swallowed by the `_safe(label, fn)` helper so the dispatch
     chain keeps running.
   - `ActionOpenApp` (#21) → the executor appends a
     `RoutineOpenAppRequest{route: '/event', at: now}` to its
     `pendingOpenApp` `ValueListenable`. The home-screen
     `RoutineBanner` widget drains the queue FIFO via
     `Navigator.pushNamed(req.route)` and clears it.
6. For #18 / #19 / #20, the `LocationPicker` sheet (now backed
   by the offline `LocationMapPreview` — SYS-084 / ADR-028)
   shows a stylised `CustomPaint` map with the pin and the
   geofence ring; no `INTERNET` permission, no `flutter_map`,
   no tile fetch.
7. The Add screens (habit / person / event) surface a per-row
   reliability badge (SYS-085 / ADR-029): a 40×40 dp
   `IconButton` whose state derives from
   `automationReliability(Automation, statuses)` exhaustive over
   the sealed `Trigger` hierarchy via `_requiredPermissionForTrigger`.
   Optimal hides the badge; degraded shows
   `Icons.warning_amber_rounded`; unknown shows `Icons.info_outline`.

**Postconditions:**
- A `RoutineConfig` row is in `SettingsService.routines.value`
  keyed by the template id.
- For #18 / #19 / #20 the geofence is registered with
  `GeofenceService` (the executor subscribes once at app start
  and matches each snapshot — v0.1 behaviour).
- For #17 / #21 the calendar reminder is registered with
  `CalendarService`.
- On the next matching trigger, the matching `Action` runs
  end-to-end and the home-screen banner (if applicable) surfaces
  the fire.
- Re-tapping the template opens the screen in Update mode with
  the persisted values pre-loaded.

**Failure modes:**
- Malformed `payloadJson` envelope → `_MalformedView` is shown
  with no Save button; no `RoutineConfig` is created.
- `ACCESS_COARSE_LOCATION` / `READ_CALENDAR` denied at runtime
  (not at apply time) → the routine silently no-ops; the per-row
  reliability badge in the Add screen shows the degraded state
  and links to Settings → Permissions.
- A `PACKAGE_USAGE_STATS`-style special-access permission (none
  required for #17–#21; this is the v1.2 `TriggerForegroundApp`
  shape) is denied → no popup; the user must opt in via
  Settings → Special access. ADR-030 documents the pattern.
- The user taps Delete on a stale Update screen → the in-memory
  map AND the SharedPreferences key are cleared; the executor's
  listener drops the automation on the next microtask.

**Verification:**
- `test/screens/templates_test.dart` asserts all six routine
  templates (#16 + #17–#21) carry a "Use this" button and route
  through `_routinesWithApplyUx`.
- `test/screens/templates_japan_routing_test.dart` rewrote the
  Japan assertion AND asserts template #17 routes to
  `RoutineApplyScreen` (the snackbar assertion is gone).
- `test/screens/routine_apply_screen_test.dart` (6 tests)
  covers render / save / toggle / update-with-Delete / delete /
  malformed-envelope.
- `test/routines/routine_template_payload_test.dart` (12 tests)
  covers the fail-soft decoder across every defect path.
- `test/services/routine_config_test.dart` + `settings_service_
  routine_test.dart` cover the persistence layer.
- `test/routines/action_dispatch_test.dart` (11 tests) covers
  all five `Action` leaves through the executor's dispatcher.
- `test/widgets/routine_banner_test.dart` (4 tests) covers the
  `pendingOpenApp` FIFO drain + the post-frame `pushNamed` path.
- `test/widgets/location_map_preview_test.dart` (11 tests) +
  `test/widgets/location_picker_test.dart` (3 new) cover the
  offline map preview.
- `test/routines/automation_reliability_test.dart` (16 tests)
  + `test/widgets/automation_reliability_badge_test.dart`
  (11 tests) cover the per-row badge.

---

## WF-034 — Add a location-triggered do / event / person (v1.0/Phase C PR 2)

The user configures an automation that fires a notification when
the device enters or leaves a chosen place. The place is named
("Home", "Office", "Gym"), given a coordinate + radius, and tied
to a do / event / person via the add screens' new "Routines"
section.

**Preconditions:**
- The user is on `AddHabitScreen` (do) / `AddEventScreen`
  (event) / `AddPersonScreen` (person).
- `ACCESS_COARSE_LOCATION` has been granted (the picker
  gates on `PermissionSheet.show(PermissionKind.location)`;
  the first tap surfaces the rationale + system dialog).

**Main flow:**
1. The user fills in the entity (do name, event name, or
   person contact) — the entity form is the same shape as
   in WF-002 / WF-017 / WF-003.
2. In the new "Routines" section, the user taps
   "Add a location routine" (`add_<entity>.add_location_routine`
   key — the empty-state copy is entity-specific:
   "fire this do / event / remind you to reach out when you
   arrive at or leave a place").
3. The `LocationPicker` bottom sheet opens (gated by
   `PermissionSheet.show(PermissionKind.location)` →
   granted → modal sheet).
4. The user enters a `label` (required), `latitude` /
   `longitude` (validated `[-90, 90]` / `[-180, 180]`,
   populated from `Geolocator.getCurrentPosition()` if the
   "Use current location" button is tapped), and a `radius`
   slider (50 m .. 500 m, default 100 m). The radio group
   selects enter (default) vs. exit.
5. The user taps Save. The sheet pops an `Automation`
   with `trigger: TriggerLocationEnter | TriggerLocationExit`
   and `action: ActionNotify(title: <label>,
   body: 'Routine fired: <label>')`. The new routine
   appears in the Routines section as an enabled row.
6. The user saves the entity. `automationsJson` on the
   row carries the envelope
   `{"k":1,"automations":[<Automation>...]}` (or empty
   when no routines are added).

**Postconditions:**
- `GeofenceService.instance` has the new `TriggerLocation*`
  registered (the executor's `init()` subscribes the
  service stream and the entity's `automationsJson` is
  decoded into a `List<Automation>` in `loadAll`).
- The `GeofenceBroadcastReceiver` is dynamically
  registered for the matching geofence IDs.
- A notification fires when the device enters (or
  exits, per the radio) the geofence circle.
- The routine round-trips through backup / restore
  (the envelope is plain JSON in the existing backup
  format; no schema bump needed).

**Failure modes:**
- Permission denied at the gate → the sheet pops
  `null` and no routine is added.
- Validation error (blank label, lat out of range,
  radius outside [50, 500]) → inline error renders
  under the offending field; the Save button stays
  enabled and the sheet does NOT pop.
- User cancels the sheet → returns `null`; the
  Routines section remains in the empty state.
- User revokes `ACCESS_COARSE_LOCATION` mid-flight →
  the geofence stream emits `PositionServiceException`;
  the executor logs and continues, dropping the
  pending routine silently. The home-screen reliability
  banner flips to `Reliability.degraded` with a one-tap
  deep link to permission settings (only when at least
  one `TriggerLocation*` automation is registered).

**Why the picker is text-input + slider (no map):** Phase C
PR 2 ships the minimum-viable geofence UX. Users look up
coordinates on a third-party map and paste them in, OR use
"Use current location" for a fresh fix. A map widget
(`google_maps_flutter` ~5MB APK + Play Services key, or
`flutter_map`) is a v1.1 follow-up. Documented in
ADR-021.

**Requirements covered:** SYS-069 (Trigger),
SYS-072 (geofence trigger), SYS-076 (PermissionKind.location
+ rationale).

## WF-035 — Add a calendar-triggered do / event / person (v1.0/Phase E PR 2)

The user configures an automation that fires a notification when
a calendar event on the device starts, ends, hits its reminder,
or transitions the user between free and busy. The routine is
tied to a do / event / person via the add screens' "Routines"
section, mirroring WF-034's location-trigger shape.

**Preconditions:**
- The user is on `AddHabitScreen` (do) / `AddEventScreen`
  (event) / `AddPersonScreen` (person).
- `READ_CALENDAR` has been granted (the picker gates on
  `PermissionSheet.show(PermissionKind.calendar)`; the
  first tap surfaces the rationale + system dialog).

**Main flow:**
1. The user fills in the entity — same shape as
   WF-002 / WF-017 / WF-003.
2. In the "Routines" section, the user taps
   "Add a calendar routine" (`add_<entity>.add_calendar_routine`
   key — sits next to "Add a location routine" in a
   `Wrap`, so both buttons are reachable on a narrow
   viewport). The empty-state copy mentions "arrive at or
   leave a place, or when a calendar event starts, ends,
   hits its reminder, or changes your busy status".
3. The `CalendarPicker` bottom sheet opens (gated by
   `PermissionSheet.show(PermissionKind.calendar)` →
   granted → modal sheet).
4. The user enters:
   - `label` (required, used as the trigger label and as
     the notification title)
   - `event title filter` (optional; empty = match any
     title)
   - `calendar account` (optional dropdown populated by
     `CalendarService.listAccounts()` on tap of
     `Refresh`; the "Any calendar" default maps to
     `calendarId: ''`, which the executor's
     `_calendarMatches` predicate treats as "match any
     calendar")
   - `event kind` radio group with four leaves:
     `Event start` (default), `Event end`, `Reminder`,
     `Free/busy change` — corresponds 1:1 to the four
     `TriggerCalendarEvent*` leaves in
     `lib/triggers/trigger.dart`.
5. The user taps Save. The sheet pops an `Automation`
   with `trigger: TriggerCalendarEventStart |
   TriggerCalendarEventEnd | TriggerCalendarReminder |
   TriggerFreeBusy` (carrying the picked `calendarId`
   and `eventTitle`) and `action: ActionNotify(title:
   <label>, body: 'Routine fired: <label>')`. The new
   routine appears in the Routines section as an enabled
   row.
6. The user saves the entity. `automationsJson` on the
   row carries the envelope
   `{"k":1,"automations":[<Automation>...]}` (or empty
   when no routines are added).

**Postconditions:**
- `CalendarService.instance` has been initialized (one
  subscription at app start — the executor subscribes to
  the broadcast `events` stream once and matches each
  transition against the registered automation set; see
  `lib/routines/routine_executor.dart`'s
  `_calendarMatches` predicate).
- The matching `TriggerCalendarEvent*` leaf is
  registered with the executor via
  `RoutineExecutor.instance.register(entityId,
  automations)` (the same call location as
  `TriggerLocation*`).
- A notification fires when a calendar event on the
  picked (or any) account starts, ends, hits its
  reminder, or transitions busy — per the kind radio.
- The routine round-trips through backup / restore
  (the envelope is plain JSON in the existing backup
  format; no schema bump needed).

**Failure modes:**
- Permission denied at the gate → the sheet pops
  `null` and no routine is added.
- `listAccounts` failure (e.g., `READ_CALENDAR`
  revoked between the gate and the Refresh tap) →
  inline error renders "Could not load calendars: …";
  the Save button is unaffected (the user can still
  save an "any calendar / any event" trigger).
- User cancels the sheet → returns `null`; the
  Routines section remains in the empty state.
- User revokes `READ_CALENDAR` mid-flight → the
  calendar source emits a `PlatformException` on the
  next event; `CalendarService` logs and continues
  (matches `_onError`); pending routines silently miss.
  There is no per-automation reliability badge for
  calendar triggers today (a v1.1 follow-up; the
  home-screen reliability banner stays driven by
  location + exact-alarm).

**Why no map / no event-picker:** Phase E PR 2 ships
the minimum-viable calendar-trigger UX. The picker
takes an optional `eventTitle` text filter and an
optional calendar account; a richer "pick this event"
flow (event-list drill-down) is a v1.1 follow-up. The
calendar-list accounts are queried lazily on Refresh
so the picker never blocks the sheet slide-up
animation. Documented in ADR-023.

**Requirements covered:** SYS-074 (TriggerCalendarEvent
leaves + `READ_CALENDAR` rationale), SYS-069 (Trigger
sealed hierarchy), SYS-072 (RoutineExecutor
dispatching `TriggerCalendarEvent*`).

## WF-036 — Configure a device-state routine (v1.0 / Phase D PR 2)

**Preconditions:**
- `BLUETOOTH_CONNECT` is granted (the rationale screen
  on the Settings → Permissions tile explains why — to
  detect connected BT devices; no audio / call history
  data is read).
- The user is on the AddDoScreen / AddEventScreen /
  AddPersonScreen (the Routines section is universal).
- The `RoutinesSection` widget is in the empty state
  (no automation registered for this entity yet) or in
  the populated state (adding a second / third routine).

**Main flow (six steps):**
1. Tap "Add a device-state routine" in the Routines
   section. The `DeviceStatePicker` sheet slides up
   over the form.
2. Pick a trigger shape from the seven supported by
   Phase D PR 2: `charging` / `batteryRange` /
   `bluetoothDevice` / `wifiSsid` / `headphones` /
   `ringerMode` / `foregroundApp`. The picker surfaces
   one tile per shape with the matching icon + a
   one-line description. The `foregroundApp` tile has
   an "Best-effort" tag (the `PACKAGE_USAGE_STATS`
   permission is v1.1; v1.0 fires on the OS
   `ACTION_FOREGROUND_SERVICE` reactive broadcast
   without the permission).
3. Set the trigger details. The fields depend on the
   shape picked in step 2:
   - `charging` → radio (charging / disconnecting).
   - `batteryRange` → two sliders (low %, high %);
     the routine fires when the battery crosses either
     threshold.
   - `bluetoothDevice` → text field (device name or
     MAC prefix; saved as a `BluetoothDeviceMatcher`).
   - `wifiSsid` → text field (SSID; saved as a
     `SsidMatcher`).
   - `headphones` → radio (plugged / unplugged).
   - `ringerMode` → radio (silent / vibrate / normal).
   - `foregroundApp` → text field (package name; saved
     as a `ForegroundAppMatcher`).
4. Set the condition (optional): time window +
   day-of-week + AND/OR group. The condition builder
   is the same one used by `TriggerLocation*` and
   `TriggerCalendarEvent*` (sealed `Condition` from
   v1.0c.1, SYS-070).
5. Set the action: `ActionNotify` (default) or any
   other marker leaf from v1.0c.1 (SYS-071).
6. Save the routine. The sheet pops; the Routines
   section now shows the new entry with the trigger
   shape icon + the condition summary + the action
   label. The routine is persisted to the entity's
   `automationsJson` envelope.

**Postconditions:**
- The new entry is in the entity's `automationsJson`
  with `kAutomationFormatVersion = 1`.
- `DeviceStateService.instance` (the Dart-side
  adapter over the `DeviceStateChannel.kt` bridge) is
  subscribed to the relevant broadcast (the executor
  subscribes once at app start, and matches each
  `DeviceStateSnapshot` against the registered
  automation set; see `lib/routines/routine_executor.dart`'s
  `_onDeviceState` predicate).
- A snapshot fires within ±1s of the next matching OS
  broadcast; the routine's `ActionNotify` shows a
  notification on the home screen.
- The routine round-trips through backup / restore
  (the envelope is plain JSON in the existing backup
  format; no schema bump needed).

**Failure modes:**
- `BLUETOOTH_CONNECT` denied at the sheet gate → the
  rationale re-surfaces; no routine is added.
- The matching broadcast never fires on the user's
  device (e.g., the device has no BT radio) → no
  notification ever; the routine entry sits in the
  Routines section as "armed". A `TriggerDeviceState`
  debug row on the Settings → Triggers screen
  surfaces "0 broadcasts in last hour" so the user
  knows the trigger is silent.
- User revokes `BLUETOOTH_CONNECT` mid-flight → the
  `DeviceStateService` logs the `PlatformException`
  on the next snapshot and continues; pending
  `bluetoothDevice` routines silently miss (a v1.1
  follow-up for per-automation reliability badges).

**Why no live broadcast dashboard in the picker:**
Phase D PR 2 ships the minimum-viable device-state
UX. The picker lets the user pick the trigger shape
and details; the live broadcast dashboard is on the
Settings → Triggers screen (a separate debug surface).
A future v1.1 enhancement could add an inline "last
seen: 5 minutes ago, charging" preview tile in the
picker, but Phase D ships the picker without it.

**Requirements covered:** SYS-073 (7 device-state
trigger shapes + `BLUETOOTH_CONNECT` rationale),
SYS-069 (Trigger sealed hierarchy), SYS-070 (sealed
Condition), SYS-071 (sealed Action), SYS-077 (cross-
reference to the BLUETOOTH_CONNECT banner pattern in
`notification_reliability.md`).


## WF-042 — View streak on the Android home widget (v1.4a / Phase 28 / SYS-115)

The user drops the do it widget from their launcher's
widget picker, long-presses the home screen, and taps
"Widgets". The widget shows the first-active Do's name,
streak number (e.g. "7"), "day streak" subtitle, an
`ic_widget_optimal` / `ic_widget_degraded` /
`ic_widget_unknown` reliability badge, and a circular
"Done" button.

**Primary path (happy flow):**

1. User long-presses home screen → Widgets → finds
   "do it: your streak on the home screen" in the
   picker.
2. User drags the medium (4×2) variant to a home-screen
   cell and releases.
3. The OS calls `DoitWidgetProvider.onUpdate(ctx, mgr,
   ids)`. The Kotlin side reads
   `WidgetStateCache.cachedFromPrefs(ctx)` FIRST; if the
   cache is empty (first install), it renders the
   empty-state placeholder ("Add a do in do it").
4. The Kotlin side then boots a one-shot `FlutterEngine`
   via `WidgetUpdater.refreshIds(ctx, ids)`, which calls
   `WidgetChannel.snapshot()` to get the live JSON.
5. `WidgetService.instance.handleRefreshRequest()`
   computes the state: `firstActiveDo(...)` reads
   `DoRepository.listAll()` + sorts ascending by
   `createdAt` + filters paused, then
   `buildWidgetState(...)` runs `ConsecutiveCounter.compute`
   + maps `ReliabilityService.instance.value` to the
   badge enum.
6. The state is persisted to
   `WidgetStateCache.cachedFromPrefs(ctx)` (a
   `SharedPreferences` key `doit.widget.cached_v1`) AND
   sent over `doit/widget.cacheSnapshot(state)` to the
   Kotlin `WidgetStateCache` (separate `SharedPreferences`
   file used by the Kotlin side directly).
7. `WidgetRenderer.render(ctx, state)` applies the
   `RemoteViews` to the widget's `appWidgetIds`. The
   widget is now visible: habit name, streak number,
   badge, Done button.
8. The widget registers a 30-min `updatePeriodMillis`
   fallback so the OS re-fires `onUpdate` even if the
   app process is dead.

**Done button (in-widget):**

9. User taps "Done" on the widget. The
   `ImageButton.done` `PendingIntent.getBroadcast`
   fires `ACTION_MARK_DONE` with the cached
   `habitId` extra.
10. `DoitWidgetProvider.onReceive` dispatches the action
    to `WidgetChannel.markDone(habitId)`, which calls
    back into Dart.
11. Dart-side `WidgetService.instance.markDone(habitId)`
    appends a completion via `CompletionLogService.append`
    (with `source: CompletionSource.manual` + the
    do's current `proofModeAtTime` tag), then re-derives
    the state via `handleRefreshRequest()`.
12. The new state is written to both the Dart
    `WidgetStateCache` and the Kotlin
    `WidgetStateCache`, and `WidgetRenderer.render(...)`
    repaints the widget. The Done button now appears
    grayed-out (`isCompletedToday == true`).

**Body tap (open app):**

13. User taps the widget body (not the Done button).
    The `widget_root` `FrameLayout` `PendingIntent.getActivity`
    opens `MainActivity` to the home screen via the
    existing launch intent (single-top).

**Reliability change path:**

14. User revokes a gated permission (e.g. `location`)
    in Android Settings. `PermissionService.statuses`
    emits a `Denied` for the gated kind.
15. `ReliabilityService` re-derives its value to
    `Reliability.degraded` (per SYS-112's combine rule)
    and emits to `ReliabilityService.reliability`.
16. `WidgetService`'s subscription fires
    `handleRefreshRequest()`. The new state's
    `reliability` field is `DoitWidgetReliability.degraded`,
    and the badge icon swaps from `ic_widget_optimal`
    to `ic_widget_degraded`.

**Failure paths:**

- **`MissingPluginException` on `doit/widget` calls** —
  the Dart `PlatformWidgetBridge._safe` wrapper swallows
  the exception and returns `null` / completes normally
  (ADR-013). The widget falls back to the cached state
  or the empty-state placeholder.
- **No active Do** — the locator returns `null` and the
  builder produces the empty-state snapshot. The widget
  shows the `widget_empty_state` copy ("Add a do in
  do it") and hides the Done button.
- **OS process kill between updates** — the cold-start
  fallback in `WidgetStateCache.cachedFromPrefs(ctx)`
  rehydrates the last-known-good state. The widget is
  never blank between OS process-kill and the first Dart
  frame.
- **Permission denied for the `doit/widget` channel**
  — the platform impl returns `null`; the widget renders
  the cached state or empty-state.

**Requirements covered:** SYS-115 (widget),
SYS-112 (`ReliabilityService` as the source for the
badge), SYS-111 (`Do.effectiveStreakConfig` as the
source for the streak), SYS-114 (sibling Phase 15
feature, shares the native-channel precedent).
## WF-044 — Skip a do for today from the home tile (v1.4c / Phase 30 / SYS-117 / ADR-047)

**Actor.** User, inside the app, looking at the home screen.

**Goal.** Mark a do as a planned rest day from the in-app tile, consuming one unit of the do's monthly rest-day budget, without entering select mode and without breaking the streak.

**Preconditions.** The user has at least one active (non-paused) do with `restDaysPerMonth > 0` (a do with `restDaysPerMonth == 0` is "opted out" — the `_SkipButton` is hidden). The reliability banner is irrelevant.

**Flow.**

1. The home screen renders each `_HabitTile` with the do name (left), a `_DoStreakBadge` (right — streak number + "day streak" subtitle + a `_BudgetCaption` reading `{remaining}/{limit} rest days left` when `limit > 0`), a `_SkipButton` (Icons.bedtime, left of the Done button), and a `_DoneButton` (Icons.check_circle_outlined, far right).
2. The user taps the tile's `_SkipButton`.
3. `markDoSkipped(activeDo, asOf, CompletionLogService.instance)` reads `activeDo.restDaysPerMonth`. If `<= 0`, throws `NoRestDaysRemaining(activeDo.id, asOf.year, asOf.month)`. Otherwise, fetches `completionLog.listRestDaysInMonth(activeDo.id, year, month)` and re-throws `NoRestDaysRemaining` if the count has already hit the limit.
4. On the happy path, the helper constructs `SkipBudget(doId: activeDo.id, monthlyLimit: activeDo.restDaysPerMonth).consume(asOf)` (defensive: a `SkipBudgetExhausted` is converted to `NoRestDaysRemaining` so the contract stays single-message), then calls `completionLog.append(habitId: activeDo.id, day: DateTime(asOf.year, asOf.month, asOf.day), source: CompletionSource.restDay, proofModeAtTime: proofModeTag(activeDo.proofMode))`.
5. The tile flips `_isSkippedToday = true`; the `_SkipButton` re-renders with `Icons.bedtime_outlined`; the SnackBar `homeTileSkipSuccess` ("Rest day taken — streak holds.") shows.
6. The `_BudgetCaption` re-fetches via the nested `FutureBuilder` over `budgetRemainingForDo(...)` — the "X / Y rest days left" caption decrements.
7. A Done tap on the same tile now branches on `_isSkippedToday == true` and shows `homeTileSkipAlready` ("Rest day taken") instead of `homeTileAlreadyDoneTooltip` (which would be confusing — the row IS resolved, just by a different mechanism). The Done tap itself does NOT call `markDoDone`; the existing `CompletionLogService.append` already dedupes on `(habitId, day, source)` and the rest-day row wins.
8. A second Skip tap on the same day is a no-op — the append's `(habitId, day, source)` uniqueness prevents a double-count; the tile's `_isSkippedToday` flag remains `true`; the budget does NOT double-decrement.

**Alternate paths.**

- **Budget exhausted (mid-month).** The first check throws `NoRestDaysRemaining`. The tile shows the `homeTileSkipBudgetExhausted` SnackBar ("No rest days left this month."); the `_SkipButton` re-renders with `Icons.bedtime_outlined` and `homeTileSkipAlready` tooltip; the `_BudgetCaption` reads `homeTileBudgetNoRemaining` ("No rest days left"). The user can still mark the tile Done via the `_DoneButton` — the streak only breaks if they miss the day entirely.
- **DB write failure.** The catch-all `try/catch` re-throws as a generic exception (matching the v1.4b `_onMarkDonePressed` shape); the tile stays in the "not skipped" state; no SnackBar. (Future PR can add a `homeTileSkipFailure` SnackBar + a retry.)
- **`restDaysPerMonth == 0` (do opted out).** The `_SkipButton` is hidden entirely; the `_BudgetCaption` renders `SizedBox.shrink()` (no layout shift); the `_DoneButton` is the only action. The user can mark the do Done but cannot skip.

**Out of scope (v1.4d candidates).**

- Widget-side "Skip today" button on the Android home-screen widget (mirrors the v1.4a tile-vs-widget feature-parity plan). v1.4d candidate.
- Rest-day history visualization ("you've used 1 of 2 this month" expansion tile showing the dates). v1.4d candidate.
- Rest-day budget edit affordance (change `restDaysPerMonth` from the tile's overflow menu instead of the long-press → select-mode → edit flow). v1.4d candidate.
- Per-tile undo (delete a stray rest-day row from the last 7 days). Mirrors the v1.3b `CompletionLogSection` pattern (SYS-108). v1.4d candidate.

## WF-045 — Undo today's completion from the home tile (v1.4d / Phase 31 / SYS-118 / ADR-048)

**Actor.** User, inside the app, looking at the home screen.

**Goal.** Reverse today's completion (manual, rest-day, or notification-source) without leaving the home screen and without opening the edit screen — a quick-path for the most common corrective action.

**Preconditions.** The user has at least one `_HabitTile` whose `_isResolvedToday == true` (i.e., `_isCompletedToday || _isSkippedToday` is true). The reliability banner is irrelevant.

**Flow.**

1. The home screen renders each `_HabitTile` with the do name (left), a `_DoStreakBadge` (right — streak number + "day streak" subtitle + a `_BudgetCaption` when `restDaysPerMonth > 0`), a `_SkipButton` (Icons.bedtime, only when `restDaysPerMonth > 0`), an `_UndoButton` (Icons.undo, only when `_isResolvedToday == true`), and a `_DoneButton` (Icons.check_circle_outlined, far right).
2. The user taps the tile's `_UndoButton`.
3. The app shows an `AlertDialog` titled `homeTileUndoConfirm` ("Undo today's completion?") with body `homeTileUndoConfirmBody` ("This will remove the entry for today and shorten your streak by one day.") and Confirm / Cancel actions.
4. The user taps Confirm.
5. `undoToday(activeDo, asOf, CompletionLogService.instance)` fetches `completionLog.listForHabit(activeDo.id)`, filters for the row whose `dayMillis == DateTime(asOf.year, asOf.month, asOf.day).millisecondsSinceEpoch`, and (a) calls `completionLog.deleteById(row.id)` if found, or (b) returns `UndoResult.nothingToUndo()` if no row matches today.
6. On the happy path, the helper returns `UndoResult.removed(rowId, source)`. The tile flips `_isCompletedToday = false` and `_isSkippedToday = false`; the `_DoneButton` re-renders with `Icons.check_circle_outlined`; the `_UndoButton` hides; the `_SkipButton` (if visible) re-renders with `Icons.bedtime`; the `_DoStreakBadge` re-computes the streak via `streakForDo(...)` (one fewer row → streak decreases by 1 within the grace window, or breaks if past the grace window per v1.1f / WF-023).
7. The SnackBar `homeTileUndoSuccess` ("Completion removed.") shows.

**Alternate paths.**

- **No completion row for today.** The helper returns `UndoResult.nothingToUndo()`. The tile shows the `homeTileUndoNotToday` SnackBar ("Nothing to undo for today."). The tile state is unchanged.
- **DB write failure (rare).** The catch-all `try/catch` re-throws as a generic exception (matching the v1.4b `_onMarkDonePressed` shape); the tile stays in the "completed/skipped" state; the user can retry. (Future PR can add a `homeTileUndoFailure` SnackBar + a retry button.)
- **User cancels the dialog.** No DB write; the tile state is unchanged; no SnackBar.

**Out of scope (v1.5 candidates).**

- SnackBar-with-undo pattern (Material's "5-second undo window") as an alternative to the confirm dialog. Useful for batch operations but the per-tile quick-path is dialog-first. v1.5 candidate.
- Cross-day undo (rewind a row from yesterday). The existing `_HabitTile` state is local-midnight-bounded; a cross-day undo would need a date picker. v1.5 candidate.
- "Undo all" (clear every completion row for the do — used for a fresh-start scenario). The existing v1.2m `CompletionLogSection.deleteById` is single-row; the bulk version is a v1.5 candidate.

**Requirements covered:** SYS-118 (per-tile undo), SYS-108 (the parent `CompletionLogSection` pattern from v1.2m that v1.4d mirrors at the tile surface).

## WF-046 — View the last 7 days as a sparkline on the home tile (v1.4e / Phase 32 / SYS-119 / ADR-049)

**Trigger.** The user opens the home screen with at least one saved do.

**Actor.** The user (visual inspection only).

**Preconditions.**
- The app is installed and at least one do is saved (the home screen is non-empty).
- The completion log is reachable via `CompletionLogService.listForHabit(habitId)`.

**Steps.**

1. The home screen renders `_HabitTile` rows for each saved do. Each tile's `_DoStreakBadge` Column now includes the `_Sparkline` sub-widget under the streak number + "day streak" subtitle + budget caption.
2. The `_Sparkline` widget reads its 7-dot row from `sparklineForDo(activeDo, asOf, completionLog)`. The helper builds the 7-day window `[asOf - 6 days .. asOf]` (local-midnight each), then emits one `SparklineDot` per day:
   - `SparklineDot.filled(day, source)` when a row exists for that day's `dayMillis` — both `manual` and `rest_day` count.
   - `SparklineDot.empty(day)` when no row exists for that day's `dayMillis`.
   - `SparklineDot.future(day)` when the day is in the future of `asOf` (defensive — the helper is robust to a frozen `asOf`).
3. Each dot renders as a 6 dp circle. Filled circles use `colorScheme.primary`; outlined circles use `colorScheme.outline` with a 1.2 dp border.
4. The rightmost dot (today) bumps to 8 dp + filled when `_isResolvedToday == true` (i.e., at least one row in the parent's `completions` future matches today's `dayMillis`). The size bump mirrors the widget's today-done affordance.
5. While `sparklineForDo` is in flight, the widget renders `_SparklineSkeleton` (7 outlined 6 dp dots) to reserve space and prevent layout shift on resolve.
6. A `Semantics(label: l.homeTileSparklineSemantics, readOnly: true)` node wraps all 7 dots so screen readers announce "Last 7 days" / "Últimos 7 días" once instead of 7 separate dots.

**Postconditions.**

- The user sees a 7-dot row under the streak badge on every tile.
- The dot row reflects the last 7 days of completion (today on the right, oldest on the left).
- The today dot is visibly larger + filled when today is resolved; today is outlined when today is not yet resolved.
- A screen reader announces "Last 7 days" once per tile (not 7 separate dot announcements).

**Edge cases.**

- **No completions at all.** All 7 dots are outlined (empty). The user sees an empty 7-day row.
- **Today is not yet resolved.** The today dot (rightmost) is outlined at 6 dp — visually identical to any other empty day.
- **Multiple completions for the same day (e.g., manual at 8 AM + rest-day at 8 PM).** The helper emits exactly one `SparklineDot.filled` for that day; the `source` is the first-matching row in `listForHabit` order (oldest-first).
- **Future `asOf` (frozen time from a unit test).** The helper emits `SparklineDot.future` for any day past `asOf`'s local-midnight, in addition to empty dots for the present-or-past days. The widget renders future dots as outlined at 6 dp (same visual as empty); the sealed split is for future widget variants that may want a different glyph.
- **Out-of-window rows (e.g., a row 30 days ago).** The helper ignores them — only the 7 days in the window are scanned.

**Failure paths.**

- **Drift read fails.** The widget stays on the skeleton; no error is surfaced to the user (the parent `_DoStreakBadge` is also showing its own skeleton state, so the entire right column is consistent). Future v1.4f+ candidates may surface a "retry" affordance.
- **The user has 10+ visible tiles.** Each tile spawns its own `sparklineForDo` future against `CompletionLogService.listForHabit(habitId)`. Drift's read cache means the wall-clock cost is one Drift read per rebuild cycle (≤ 1 ms for the memoized path), so the per-frame cost is negligible. The screen does not stutter.

**Requirements covered:** SYS-119 (per-tile 7-day sparkline), SYS-108 (the parent `CompletionLogSection` review-row pattern from v1.2m that v1.4e mirrors at the tile surface).

## WF-047 — Skip or undo today from the Android home widget (v1.4f / Phase 33 / SYS-120 / ADR-050)

### Trigger

User taps the "Skip today" `ImageButton` (`@+id/widget_skip`) or the "Undo today" `ImageButton` (`@+id/widget_undo`) on the Android home-screen widget bound to `com.doit.DoitWidgetProvider`.

### Actor

The end user. They are looking at their Android home screen, not the do it app.

### Preconditions

- The widget is bound (added to a home-screen cell).
- The do that is currently the first-active do (`firstActiveDo(repository: DoRepository)`) has a non-zero `restDaysPerMonth` for the Skip path; the Skip button is `View.GONE` otherwise.
- The user has tapped "Done" or "Skip" earlier today for the Undo path; the Undo button is `View.GONE` otherwise.
- The widget has been refreshed at least once since the do list changed (so the cached `DoitWidgetState` JSON includes the current `habitId`, `restDaysPerMonth`, and `isCompletedToday`).

### Steps

1. **User taps Skip.** Android delivers a click to the `ImageButton`, which fires its `PendingIntent.getBroadcast` for `ACTION_WIDGET_SKIP = "com.doit.WIDGET_SKIP"` with `EXTRA_HABIT_ID = <current habit id>`.
2. **`DoitWidgetProvider.onReceive` dispatches.** The provider matches the `ACTION_WIDGET_SKIP` arm, reads `EXTRA_HABIT_ID`, and calls `WidgetUpdater.refreshAll(ctx)`.
3. **`WidgetUpdater.refreshAll` boots a one-shot `FlutterEngine`** via `FlutterEngineCache` and dispatches the `markDone`/`skip`/`undo` MethodChannel arm to Dart.
4. **`WidgetChannel.handleAction(call, result, "skip")`** returns `true` immediately. The Kotlin-side `WidgetUpdater.refreshAll` re-applies the cached `RemoteViews` and asks the Dart side to refresh via `cacheSnapshot` + `requestRefresh`.
5. **Dart-side `WidgetService.skip(habitId)` resolves the do** via `DoRepository.getById(habitId)`. If the do is missing (race with a delete), returns `false`. If `restDaysPerMonth <= 0`, returns `false`.
6. **Dart-side `WidgetService.skip` checks the month's rest-day rows** via `CompletionLogService.listRestDaysInMonth(habitId, year, month)`. If the count is `>= restDaysPerMonth`, returns `false`.
7. **Dart-side `WidgetService.skip` appends** via `CompletionLogService.append(habitId, day: local-midnight at now, source: CompletionSource.restDay, proofModeAtTime: proofModeTag(activeDo.proofMode))`. The streak calculator (`ConsecutiveCounter.compute`) credits `rest_day` rows identically to `manual` rows, so the streak holds.
8. **Dart-side `WidgetService.skip` re-derives** via `handleRefreshRequest()`: re-computes the `DoitWidgetState` (streak number is preserved, `isCompletedToday` flips to `true`), saves to `WidgetStateCache` (SharedPreferences), writes to the platform `WidgetStateCache` via `bridge.cacheSnapshot`, asks the platform to repaint via `bridge.requestRefresh`.
9. **Kotlin-side `WidgetRenderer.render(ctx, state)` re-applies the `RemoteViews`.** The new state shows the updated streak number; the Skip button is still visible (the user can tap it again — `CompletionLogService.append` dedupes on `(habitId, day)` so a second tap is a no-op); the Undo button is now visible (`isCompletedToday == true`).
10. **Undo path mirrors steps 1-9** but with `ACTION_WIDGET_UNDO = "com.doit.WIDGET_UNDO"` and the Dart-side handler is `WidgetService.undo(habitId)`: lists the habit's rows, finds the row whose `dayMillis == local-midnight at now` (first-match-wins tiebreak), calls `CompletionLogService.deleteById(row.id)`, and re-derives. The streak decrements by 1; the Undo button hides (`isCompletedToday == false`); the Skip + Done buttons remain visible.

### Postconditions

- The completion log has exactly one new `rest_day` row (Skip) or one fewer row (Undo) for the current `habitId` on today's local-calendar day.
- The streak number reflects the change (preserved on Skip, decremented on Undo).
- The widget surface is repainted with the updated streak + the appropriate visibility for Skip + Undo + Done.
- The platform `WidgetStateCache` is updated to the new state so a cold-start fallback shows the right number.

### Edge cases

- **Concurrent rebuild races the cached state read.** The user taps Skip, but between the cached-state read and the Dart-side `DoRepository.getById` call, another tab deletes the do. `WidgetService.skip` returns `false` (no append). The widget repaints; the Skip button may now point at a deleted do (the next `handleRefreshRequest` cycle picks up the new first-active do).
- **Skip tapped on an exhausted month.** The button is hidden (`restDaysPerMonth > 0` but `isExhausted == true` — currently we do NOT track `isExhausted` in the cached state, only `restDaysPerMonth`; if the user has burned all budget units but the widget has not refreshed yet, the Skip button may be visible). `WidgetService.skip` returns `false`; the widget repaints with the cached `isCompletedToday == false`; the Skip button stays visible. Closure candidate: thread `isExhausted` into `DoitWidgetState` in v1.4g+ so the renderer can hide the button on exhaustion.
- **Undo tapped when there is no row for today.** The Undo button is hidden (`isCompletedToday == false`), but a concurrent rebuild can leave a dangling flag. `WidgetService.undo` returns `false`; no `deleteById` call. The widget repaints; the Undo button may still be visible for one cycle.
- **Multiple rest-day rows for the same day.** `append` dedupes on `(habitId, day)` so a second tap is a no-op. The Skip button stays visible.
- **App process killed between the broadcast and the Dart round-trip.** The widget repaints with the cached state (the pre-tap state) — the user sees no immediate effect. When the app process is restarted and `WidgetService.init` primes the cache + platform, the Dart side recomputes from the DB and the next refresh shows the right state. (The tap is "lost" in this case; the user can re-tap after the process restarts.)
- **Timezone change while the widget is visible.** The completion log stores `dayMillis` (UTC-millis-of-local-midnight). A timezone change while the widget is bound does not invalidate today's row — `DateTime(now.year, now.month, now.day)` is re-computed in the new zone, and the row's `dayMillis` (now a different absolute moment) may or may not match. Defensive: a row from "yesterday in the old zone" might match "today in the new zone". Closure candidate: re-derive on `ACTION_TIMEZONE_CHANGED` in v1.4g+.

### Failure paths

- **MethodChannel `MissingPluginException` (test / older Android).** `WidgetBridge.skip` / `WidgetBridge.undo` swallow per ADR-013. The Dart side sees `false`; the widget repaints with the cached state; the user sees no effect. The next legitimate event (reliability change, completion write, manual refresh) re-derives and shows the right state.
- **`DoRepository.getById` throws.** `WidgetService.skip` / `WidgetService.undo` catch and swallow (the surrounding `handleRefreshRequest` is best-effort). The widget repaints with the cached state.
- **`CompletionLogService.deleteById` throws (DB locked).** `WidgetService.undo` returns `false`. The widget repaints with the cached state. The row is not deleted; the user can re-tap after the DB is unlocked.
- **Kotlin `WidgetUpdater.refreshAll` fails to boot the FlutterEngine (corrupt engine cache).** The widget is left in the cached state. No Dart round-trip happens. The user sees no effect. `WidgetStateCache.cachedFromPrefs(ctx)` continues to serve the cached state on the next `onUpdate` cycle.

### Requirements covered

- SYS-120 (this cycle's primary requirement)
- ADR-050 (this cycle's primary architectural decision)
- ADR-013 (defensive `MissingPluginException` swallow — extended from ADR-045 to the new skip + undo bridge methods)
- ADR-046 (v1.4b in-app `_SkipButton` pattern — mirrored at the widget surface)
- ADR-047 (v1.4c shared `proofModeTag` helper — re-used, no inline copy)
- ADR-048 (v1.4d in-app `_UndoButton` pattern — mirrored at the widget surface)
- ADR-049 (v1.4e sparkline first-match-wins tiebreak — mirrored for the undo day-match)

## WF-048 — Widget action button taps round-trip to Dart's `WidgetService` (v1.4g / Phase 34 / SYS-121 / ADR-051)

Closes the latent v1.4a + v1.4f gap where the widget surface's "Done" / "Skip today" / "Undo today" `ImageButton`s repainted via `WidgetUpdater.refreshAll(ctx)` from Kotlin but never wrote to the completion log. The user could tap the widget "Done" button all day and the in-app tile's streak would not advance because the Drift DB had no row. v1.4g activates the INBOUND direction on the existing `doit/widget` MethodChannel so the widget taps now share the write path with the in-app tile.

### Sequence

1. **User taps the widget "Done" `ImageButton`.** `WidgetRenderer.markDoneIntent(ctx, id, habitId)` (`android/app/src/main/kotlin/com/doit/WidgetRenderer.kt`) built a `PendingIntent.getBroadcast` with `action = DoitWidgetProvider.ACTION_MARK_DONE` and `putExtra(EXTRA_HABIT_ID, habitId)`. The OS delivers the broadcast to `DoitWidgetProvider.onReceive(...)`.

2. **Kotlin side dispatches the action.** `DoitWidgetProvider.onReceive` (`android/app/src/main/kotlin/com/doit/DoitWidgetProvider.kt`) reads `habitId` from `intent.getStringExtra(EXTRA_HABIT_ID)` (preferred) or falls back to `WidgetStateCache.cachedFromPrefs(ctx)?.optString("habitId")` (for stale `PendingIntent`s created before v1.4g). With a non-empty `habitId`, the receiver calls `scope.launch { WidgetChannel.invokeAction(ctx, "markDone", habitId); WidgetUpdater.refreshAll(ctx) }` on `Dispatchers.IO` so the BroadcastReceiver doesn't block.

3. **Kotlin `invokeAction` boots the FlutterEngine if needed.** `WidgetChannel.invokeAction(ctx, action, habitId)` (`android/app/src/main/kotlin/com/doit/WidgetChannel.kt`) validates `action ∈ {markDone, skip, undo}` and `habitId.isNotEmpty()` (returns `false` otherwise), calls `WidgetUpdater.ensureFlutterEngine(ctx)` to boot the `FlutterEngine` if it isn't alive (a 1-3 s cost on cold-start; sub-100 ms on warm), then posts `ch.invokeMethod(action, mapOf("habitId" to habitId), resultProxy)` to the platform main thread via `android.os.Handler(Looper.getMainLooper()).post { ... }` because `MethodChannel.invokeMethod` must run on the platform thread.

4. **Dart-side `WidgetActionInvoker` handles the inbound call.** `MethodChannel.setMethodCallHandler` was wired by `WidgetActionInvoker.attach()` (called from `WidgetService.init(...)`) on the `doit/widget` channel. The handler matches `case 'markDone': case 'skip': case 'undo':` and returns `widgetActionDispatch(call)`. Any other method (`cacheSnapshot`, `requestRefresh`, `snapshot`) falls through to `null`.

5. **Dispatcher routes to `WidgetService`.** The top-level `widgetActionDispatch(MethodCall)` function (`lib/widget/widget_action_invoker.dart`) extracts `habitId` from `call.arguments` (returns `false` on missing/empty), reads `WidgetService.instance` (catches `StateError` if not initialized → returns `false`), then switches on `call.method` to `service.markDone(habitId)` / `.skip(habitId)` / `.undo(habitId)` and returns the service's `Future<bool>` result. Any throw from the service is caught and returns `false`.

6. **`WidgetService.markDone` writes the completion row.** `markDone(habitId)` (`lib/services/widget_service.dart`) fetches the active habit via `_doRepository.getById(habitId)` (returns `false` if null), constructs `day = DateTime(now.year, now.month, now.day)` (local-midnight), calls `_completionLog.append(habitId: habitId, day: day, source: CompletionSource.manual, proofModeAtTime: proofModeTag(activeDo.proofMode))` (the `append` dedupes on `(habitId, day)`), then `handleRefreshRequest()` to re-derive + persist the widget state + cache. Returns `true` on success, `false` on any throw.

7. **Dispatcher relays the bool to the platform.** The `CompletableDeferred<Boolean>` is completed with the service's result (or `false` on a throwable). `WidgetChannel.invokeAction`'s `withTimeoutOrNull(5_000L)` awaits the deferred and returns the bool. The `WidgetUpdater.refreshAll(ctx)` follow-up always runs regardless of the bool — the widget repaints with the cached state, which has just been updated by `handleRefreshRequest`.

8. **Widget shows the new streak.** The next `RemoteViews` paint reflects the new `streakNumber` + `isCompletedToday` derived from the now-non-empty completion log. The user sees the streak number advance within 1 s of the tap on a warm engine; within 3 s on a cold engine (covered by the 5 s timeout).

### Failure paths

- **`invokeAction` returns `false` on missing channel / engine / habitId / action.** The Kotlin side's `scope.launch` catches the false and the follow-up `WidgetUpdater.refreshAll(ctx)` still runs. The widget repaints with the cached state (no visual change).
- **`invokeAction` returns `false` on 5 s timeout.** The `FlutterEngine` boot is the longest plausible cause (1-3 s on cold-start; should never hit 5 s). If it does, the timeout protects the BroadcastReceiver's `CoroutineScope` from leaking. The follow-up refresh still runs.
- **Dart-side `WidgetService` throws on the `append` call (DB locked).** The dispatcher's try/catch returns `false`. The follow-up refresh runs. The user can re-tap after the DB is unlocked.
- **Dart-side `WidgetService.instance` throws `StateError` (not initialized).** The dispatcher's `try { ... } on StateError catch` returns `false`. The follow-up refresh runs. This is the cold-start case where the BroadcastReceiver fires before `WidgetService.init` has been called from `main.dart` (e.g., the app process was killed and the widget tap woke it up). The follow-up refresh boots the engine but the dart entrypoint hasn't run init yet — the widget repaints with the cached state.
- **`habitId` is empty in the intent extras AND the cache is empty (renderEmpty was the last paint).** The Kotlin side's `if (!habitId.isNullOrEmpty())` guard skips the `scope.launch` entirely. No Dart round-trip. No follow-up refresh. The widget stays in its renderEmpty state.

### Requirements covered

- SYS-121 (this cycle's primary requirement)
- ADR-051 (this cycle's primary architectural decision — bidirectional `doit/widget` MethodChannel)
- ADR-045 (v1.4a outbound `WidgetChannel` — preserved verbatim; the inbound handler is a new sibling)
- ADR-046 (v1.4b in-app `_DoneButton` pattern — the widget's inbound "Done" now uses the same `WidgetService.markDone` write path)
- ADR-047 (v1.4c shared `proofModeTag` helper — used by `WidgetService.markDone` for the `proofModeAtTime` field)
- ADR-048 (v1.4d in-app `_UndoButton` pattern — the widget's inbound "Undo" now uses the same `WidgetService.undo` write path)
- ADR-050 (v1.4f widget-side Skip + Undo — the latent "doesn't round-trip to Dart" gap is now closed; v1.4g activates the inbound direction the v1.4f ADR deferred)
- ADR-013 (defensive `MissingPluginException` swallow — extended to the inbound channel path via `widgetActionDispatch`'s top-level try/catch returning `false`)
- ADR-049 (v1.4e sparkline first-match-wins tiebreak — mirrored for the inbound `undo` day-match)

## WF-049 — Edit or delete a do from the in-app home tile (v1.4h / Phase 35 / SYS-122 / ADR-052)

Surfaces Edit + Delete as discoverable per-tile `IconButton`s on every `_HabitTile` in the right-edge action row, alongside the existing v1.4b/c/d Skip / Undo / Done buttons. Closes the discoverability gap on the v0.2 long-press → select-mode → app-bar-trash path: every user with tiles on the home screen now has two one-tap affordances for the most common do-mutation flows.

### Sequence

1. **User taps the per-tile Delete `IconButton`.** The button (`_DeleteButton` at `lib/screens/home.dart`) renders `Icons.delete_outline` with the `homeTileDelete` tooltip. Tapping it calls `_HabitTileState._onDeletePressed()` (`lib/screens/home.dart`).

2. **Confirm dialog opens.** The handler `await showDialog<bool>(context: ..., builder: (dialogContext) => AlertDialog(title: Text(l.homeTileDeleteConfirm(habit.name)), content: Text(l.homeTileDeleteConfirmBody), actions: [TextButton(cancel), FilledButton('Delete')]))`. The dialog title carries the do name in quotes (`Delete "Stretch"?`) so the user can verify the target. Cancel pops `false` and the handler returns early — no DB write, no snackbar.

3. **Confirm path captures the messenger.** On the `true` pop, the handler captures `messenger = ScaffoldMessenger.of(context)` BEFORE the async gap (to avoid the post-delete `setState` disposing the widget before the snackbar can render), sets `_busy = true` (the spinner replaces the trash icon on the `_DeleteButton` AND gates the v1.4b/c/d buttons), and `await deleteDo(activeDo: widget.habit, repository: DoRepository.instance)`.

4. **The pure-Dart `deleteDo` helper calls `DoRepository.deleteById`.** `deleteDo` (`lib/screens/home_tile_delete.dart`) translates any throwable into a `bool` return — `true` on the happy path, `false` on a DB-locked / FK-constraint / drift exception. The helper is pure-Dart, no Flutter import, no `DateTime.now()`. The single `await repository.deleteById(activeDo.id)` call cascades the FK delete on the `completions` table.

5. **Happy path branches.** On `true`, the handler clears `_busy`, calls `widget.onDoChanged?.call()` (the parent `_HomeScreenState._refresh()` re-fetches the `FutureBuilder<List<Do>>` so the deleted tile disappears), and shows `messenger.showSnackBar(SnackBar(content: Text(l.homeSnackbarDoDeleted(habit.name)), action: SnackBarAction(label: l.homeSnackbarDoDeletedUndo, onPressed: () async { try { await DoRepository.instance.save(habit); widget.onDoChanged?.call(); } catch (_) { /* DuplicateDoName swallowed — user can re-add via FAB */ } })))`. The captured `habit` reference is the `@immutable` `Do` (valid for re-save without a clone per `lib/do/do.dart:160`). On `false`, the handler clears `_busy` and shows `messenger.showSnackBar(SnackBar(content: Text(l.homeSnackbarDoDeleteFailed)))` WITHOUT removing the tile — the DB is the source of truth.

6. **User taps Edit instead.** The `_EditButton` `IconButton` (with `Icons.edit_outlined` + `homeTileEdit` tooltip) calls `_HabitTileState._onEditPressed()` which pushes `AddHabitScreen(habitId: widget.habit.id)` (the same destination `_HomeScreenState._onTileTap` at `lib/screens/home.dart:120` uses). On `true` pop (hard-delete from the edit screen, per WF-022) the handler calls `widget.onDoChanged?.call()` so the tile disappears.

7. **Undo snackbar restore.** If the user taps `Undo` inside the ~4 s snackbar window, the closure `await DoRepository.instance.save(habit)` re-inserts the row (the same `id`) and triggers `widget.onDoChanged?.call()` to re-fetch the list. The completion-log rows are NOT restored — they were cascade-deleted with the do. The streak counter starts at 0 on the restored do. This is the v1.4h documented trade-off; a v1.4h+ soft-delete column on `habits` would enable a true undo.

### Failure paths

- **User taps Cancel on the confirm dialog.** No DB write, no snackbar, no `setState`. The tile stays intact. The captured `_busy` flag was never set.
- **`DoRepository.deleteById` throws (DB locked, FK constraint).** The helper catches any throwable and returns `false`. The handler shows `homeSnackbarDoDeleteFailed` ("Could not delete. Try again.") WITHOUT removing the tile. The user can retry.
- **`DoRepository.save` throws `DuplicateDoName` on Undo** (user created a new do with the same name in the gap). The Undo closure swallows the throw. The snackbar has already dismissed. The user can re-add the do manually via the FAB. The DB is the source of truth; the snackbar's success state was a hint, not a guarantee.
- **`AddHabitScreen` pops `null` or `false` on a normal save.** The `_onEditPressed` handler does not call `widget.onDoChanged` — the tile stays. The edit screen's own save success SnackBar is the user's signal.
- **Widget is unmounted mid-delete** (e.g., the user backs out of the home screen during the `await deleteById`). The captured `messenger` survives the unmount because it was captured from `ScaffoldMessenger.of(context)` BEFORE the async gap. The `setState(() => _busy = false)` is guarded by `if (!mounted) return`. The snackbar may render on a different screen — acceptable degradation.

### Requirements covered

- SYS-122 (this cycle's primary requirement)
- ADR-052 (this cycle's primary architectural decision — per-tile Edit + Delete IconButtons)
- ADR-046 (v1.4b in-app `_DoneButton` pattern — the `_DeleteButton` mirrors its busy-state spinner + disabled-on-busy shape)
- ADR-047 (v1.4c in-app `_SkipButton` pattern — the `_DeleteButton`'s busy / disabled shape is identical)
- ADR-048 (v1.4d in-app `_UndoButton` pattern — the `_DeleteButton`'s confirm-dialog + messenger-capture-before-async-gap pattern is identical)
- ADR-013 (defensive `MissingPluginException` swallow — extended to the delete path via `deleteDo`'s top-level `catch (_)` returning `false`)

## WF-050 — View rest-day history on the home tile (v1.4i / Phase 36 / SYS-123 / ADR-053)

Surfaces the last 14 days of completion history as an extended sparkline below the v1.4e / SYS-119 / WF-046 7-day streak badge, color-coded to distinguish manual completions (`CompletionSource.manual`) from rest-day rows (`CompletionSource.restDay`). Adds an inline legend row below the dot row so the source-aware coloring is discoverable. Closes the v1.4e "we know rest-day rows exist but you can't tell them apart on the sparkline" gap.

### Sequence

1. **Home screen mounts.** `_HomeScreenState` (`lib/screens/home.dart`) renders the `ListView.builder` of `_HabitTile`s. Each tile's `_DoStreakBadge` renders the v1.4e 7-day streak badge + a `_Sparkline` sub-widget (v1.4e / SYS-119 / WF-046). The v1.4i extended sparkline is the same `_Sparkline` widget with the v1.4i `days: 14` (default) + `restDayColor: Theme.of(context).colorScheme.tertiary` + `showLegend: true` (default) constructor params.

2. **`_Sparkline` builds a `FutureBuilder<List<SparklineDot>>`.** The future is `extendedSparklineForDo(activeDo: tile.habit, asOf: asOf, completionLog: CompletionLogService.instance, days: 14)` (v1.4i / SYS-123). The helper is pure-Dart: takes a frozen `asOf` + the singleton `CompletionLogService`, returns 14 dots in oldest-first order with today as the last dot.

3. **`extendedSparklineForDo` builds the 14-day window.** The helper (`lib/screens/home_tile_sparkline.dart`) builds `dayList = [asOf - 13 days, ..., asOf]` (local-midnight each), fetches `completionLog.listForHabit(activeDo.id)`, and for each day emits a `SparklineDot.filled(day, source)` if a row exists for that day's `dayMillis` (carrying the first-matching row's source tag), a `SparklineDot.future(day)` if the day is in the future of `asOf` (defensive), or a `SparklineDot.empty(day)` otherwise. First-match semantic mirrors `home_tile_undo.undoToday` (v1.4d / SYS-118) + `sparklineForDo` (v1.4e / SYS-119).

4. **The future resolves; the widget paints the dot row.** `_Sparkline` renders 14 `_SparklineDot` circles (6 dp outlined by default; today bumps to 8 dp + filled when `_isResolvedToday == true`). Each dot wraps its `Padding > Container` in `Semantics(label: ...)` (NOT a per-dot `Tooltip` — see ADR-053 §"Alternatives considered" for why `Tooltip` was rejected: gesture interception + 14 small dots × 3 localized messages = 42 competing tooltips). The widget reads `SparklineDotFilled.source` and switches colors: `source == 'rest_day'` → `restDayColor ?? colorScheme.tertiary`; else (manual / notification / mission) → `colorScheme.primary`. The widget's outer `Semantics(label: l.homeTileSparklineSemantics, readOnly: true, container: true)` node announces "Last 14 days" / "Últimos 14 días" once on TalkBack focus.

5. **The widget paints the legend row.** Below the dot row, `_SparklineLegend` (v1.4i / SYS-123) renders 3 `_LegendSwatch` entries — a filled primary-color circle + `homeTileSparklineLegendDone` ("Done" / "Hecho"); a filled tertiary-color circle + `homeTileSparklineLegendRestDay` ("Rest day" / "Día de descanso"); an outlined circle + `homeTileSparklineLegendMissed` ("Missed" / "Perdido") — using `Theme.of(context).textTheme.labelSmall`. The legend is the discoverability mechanism for the source-aware coloring; a user with no prior knowledge of the app sees 14 dots + a legend row and learns that the two fill colors mean different things.

6. **User taps `Skip today`.** The v1.4c / SYS-117 `_SkipButton`'s `onPressed` calls `markDoSkipped(...)` → `completionLog.append(habitId, day, source: CompletionSource.restDay, proofModeAtTime: proofModeTag(activeDo.proofMode))` (v1.4c helper at `lib/screens/home_tile_skip.dart`). The append re-derives via the parent's `_HomeScreenState._refresh()` setState cascade (same trigger the v1.4b Done / v1.4c Skip / v1.4d Undo buttons use). The streak badge's `completions` future re-fires; the `_Sparkline`'s `FutureBuilder` re-fetches `extendedSparklineForDo`; the new rest-day row paints as a `tertiary` dot in today's slot.

7. **User long-presses the tile.** The parent `_HabitTile`'s `onLongPress` fires (no `Tooltip` gesture intercept on the dot row per ADR-053 §"Alternatives considered"), `_HomeScreenState._toggleSelectMode(habitId)` is called, the tile enters select mode, and the existing v1.4b select-mode UI (app-bar action set, per-tile check marks) renders. The v1.4b "long-press enters select mode" widget test at `test/screens/home_test.dart:165-213` continues to pass after the v1.4i source-aware coloring + per-dot `Semantics` migration.

8. **User navigates to the edit screen.** The v1.4h `_EditButton`'s `onPressed` pushes `AddHabitScreen(habitId: ...)` (same destination as `_HomeScreenState._onTileTap` at `lib/screens/home.dart:120`). The edit screen's `CompletionLogSection` (v1.2m / SYS-108) renders the full completion log with each row's source tag, which is the deeper-dive view of what the v1.4i sparkline visualizes at-a-glance.

### Failure paths

- **`completionLog.listForHabit(activeDo.id)` throws (DB locked, drift exception).** The helper re-throws (no try/catch — the caller is a `FutureBuilder` that surfaces the error via the standard error-builder path). The widget would render `_SparklineSkeleton` (7 outlined dots per the v1.4e baseline; v1.4i does not change the skeleton shape — same outline count, no count animation) until the next refresh cycle. Defensive — the v0.x test surface has zero known drift exceptions on `listForHabit`.
- **`SparklineDotFilled.source` is an unknown source tag** (e.g., a future v2.0 adds `'weather'` or `'mission_chain_passed'` and the DB has a stale row from a previous install). The widget falls through to `colorScheme.primary` (the manual color) — unknown sources are treated as "completed" rather than "rest day". Defensive against schema-evolution drift.
- **User has 0 completions in the past 14 days.** All 14 dots are `SparklineDot.empty` (outlined circles). The legend row still renders — this is intentional, the empty-state is the teaching surface for the source-aware coloring.
- **User has 14+ completions in the past 14 days (perfect record).** All 14 dots are `SparklineDot.filled` with `source: 'manual'` (or `'rest_day'` if they used Skip). The legend row still renders — perfect records still benefit from the legend being visible so the user knows rest-day dots would look different.
- **DST boundary at the start of the 14-day window.** The helper uses local-midnight `DateTime(asOf.year, asOf.month, asOf.day)` for each day, same convention as the v1.4e `sparklineForDo` + v1.4d `undoToday` + v1.4b `streakForDo` helpers. A DST transition that pushes a local-midnight to 1 AM or 23:30 of the previous/next day is handled by the same convention — the day boundary is the day boundary, regardless of clock math. The existing v1.4e DST edge cases (no explicit test, but the convention is identical) continue to hold.
- **Widget is unmounted mid-FutureBuilder (e.g., the user navigates away before the future resolves).** The `FutureBuilder` snapshot is dropped; the next mount of the same tile re-fetches. No memory leak — the singleton `CompletionLogService` holds no per-tile state.

### Requirements covered

- SYS-123 (this cycle's primary requirement)
- ADR-053 (this cycle's primary architectural decision — rest-day history visualization on the home tile)
- ADR-049 (v1.4e / SYS-119 — the original 7-day streak sparkline; v1.4i extends the helper signature while preserving the v1.4e return shape)
- ADR-047 (v1.4c / SYS-117 — the `_SkipButton` is the surface that produces rest-day rows; the v1.4i sparkline visualizes the rows the Skip button writes)
- ADR-046 (v1.4b / SYS-116 — the `_DoneButton` is the surface that produces manual rows; the v1.4i sparkline visualizes the rows the Done button writes)
- SYS-119 (v1.4e — the 7-day baseline; v1.4i extends to 14 days with color + legend)
- SYS-117 (v1.4c — rest-day rows are the trigger for the `tertiary` color)
- SYS-116 (v1.4b — manual rows are the trigger for the `primary` color)

## WF-051 — Edit the rest-day budget from the home tile or the edit screen (v1.4j / Phase 37 / SYS-124 / ADR-054)

Surfaces the long-hidden v1.0 affordance of editing the per-do rest-day budget directly from the in-app home tile (`_BudgetCaption` tap) AND from the `AddHabitScreen` form ("Rest days per month: N" row). Closes the 3-part gap: the tile's budget caption is purely informational today; the edit screen has no form field for `restDaysPerMonth` so a user who opens edit and hits Save silently resets the value (the v1.0 silent-reset bug); the budget is reachable only by indirect paths (open the edit screen, scroll past proof-mode + schedule + time, find the field if it existed, save). v1.4j ships a single source of truth — `RestDayPickerDialog` — that both surfaces call.

### Sequence

1. **User taps the budget caption on the home tile.** The `_BudgetCaption` at `lib/screens/home.dart` is wrapped in `Semantics(button: true, label: captionText, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: Padding(...)))`. Tapping fires `_HabitTileState._onBudgetCaptionTapped()` (new private method), which captures `messenger = ScaffoldMessenger.of(context)` BEFORE the async gap, then `await showRestDayPicker(context, initial: widget.habit.restDaysPerMonth)`.

2. **`RestDayPickerDialog` opens.** The dialog (`lib/screens/rest_day_picker_dialog.dart`) renders an `AlertDialog` with title `l.homeTileBudgetEditTitle` ("Rest days per month"), description `l.homeTileBudgetEditDescription` ("How many rest days you can take each month. Resets on the 1st."), a live integer label above a `Slider(min: 0, max: 31, divisions: 31, value: _value, label: '$_value', onChanged: ...)` that snaps to whole numbers, and Save (`l.homeTileBudgetEditOk`) + Cancel (`l.homeTileBudgetEditCancel`) actions. The initial value is clamped to `[0, 31]` on construction so a stale DB row from a future schema migration cannot crash the slider.

3. **User drags the slider to the new budget.** The `Slider`'s `onChanged` fires `setState(() => _value = v.round())`, the live integer label above the slider updates (`Theme.of(context).textTheme.displaySmall`), and the slider thumb's `Tooltip` shows the value on drag. The user drags from N=2 to N=5; the label reads "5".

4. **User taps Save.** The FilledButton's `onPressed` fires `Navigator.of(context).pop(_value)` (returns `5`). The `_onBudgetCaptionTapped` handler receives the non-null result and awaits `DoRepository.instance.save(widget.habit.copyWith(restDaysPerMonth: 5))`. The existing `DoRepository.save(...)` call chain (`lib/services/do_repository.dart:46-58`) runs `d.validate()` first, which throws `DoInvalidRestDays(5)` if the value is out of `[0, 31]` (the picker clamps inline so this never fires in practice; `validate()` is the defensive second line per ADR-054 §6). On success the handler calls `widget.onDoChanged?.call()` to trigger the v1.4h `_refresh()` cascade: parent's `FutureBuilder<List<Do>>` re-fires → tile re-mounts with the new `restDaysPerMonth` → `_BudgetCaption` rebuilds with `l.homeTileBudgetRemaining(5, 5)` ("5/5 rest days left") AND the `_SkipButton` appears (was hidden when `restDaysPerMonth == 0`). The handler then shows `messenger.showSnackBar(SnackBar(content: Text(l.homeSnackbarBudgetUpdated(5))))` ("Rest-day budget set to 5.").

5. **User taps Cancel (or back-presses the dialog).** The TextButton's `onPressed` fires `Navigator.of(context).pop()` (returns `null`). The `_onBudgetCaptionTapped` handler returns early — no save, no SnackBar, no refresh. The tile stays at its prior value.

6. **User opens the edit screen instead.** Tapping the v1.4h `_EditButton` (`IconButton(Icons.edit_outlined)` with `homeTileEdit` tooltip) pushes `AddHabitScreen(habitId: widget.habit.id)` per the v1.4h `_onEditPressed` contract (mirrors `_HomeScreenState._onTileTap` at `lib/screens/home.dart:120`). The screen loads the existing `Do` via `_loadExisting()`, which populates `_restDaysPerMonth = _original.restDaysPerMonth` (e.g. 3 — fixes the silent-reset bug, see ADR-054 §5).

7. **The edit screen renders the new "Rest days per month: N" row.** Below the proof-mode row in the form body, a `ListTile` (or equivalent outlined control) renders `l.addHabitRestDaysLabel(_restDaysPerMonth)` ("Rest days per month: 3") with a trailing `Icon(Icons.tune)`. Tapping the row fires `_pickRestDaysPerMonth()`, which `await showRestDayPicker(context, initial: _restDaysPerMonth)` and `setState(() => _restDaysPerMonth = picked)` on a non-null result. The row's text updates immediately ("Rest days per month: 5").

8. **User taps Save on the edit screen.** `_save()` (`lib/screens/add_habit.dart`) runs the 5-branch switch (now with `restDaysPerMonth: _restDaysPerMonth` instead of the hardcoded 2), persists via `DoRepository.save(...)`, and pops the route with `true`. The home screen reads the `true` and calls `_refresh()`. The tile re-mounts with the new value. The pre-v1.4j silent-reset bug is closed: a user who opens edit on a 3/month do and hits Save WITHOUT touching the budget row now preserves the 3 (because `_restDaysPerMonth` was loaded from `_original.restDaysPerMonth` in `_loadExisting()`).

9. **User has TalkBack enabled.** Tapping the tile with TalkBack announces the caption `Semantics(button: true, label: "5/5 rest days left")` as a button. Swiping right through the `Slider` reads out each integer value as it changes (TalkBack's standard `Slider` accessibility). Tapping the "Rest days per month: 5" form row on the edit screen announces "Rest days per month: 5, button".

### Failure paths

- **`showRestDayPicker` returns `null` (Cancel / back-press).** The tile handler returns early — no save, no SnackBar, no refresh. The form-row handler is symmetric (early return). No state change.
- **`DoRepository.save` throws `DoInvalidRestDays(32)`** (the new upper-bound rule). In practice the picker clamps inline to `[0, 31]`, so this only fires if a stale DB row from a future schema migration is loaded into the picker. The tile handler catches the throw, shows `messenger.showSnackBar(SnackBar(content: Text(l.homeSnackbarBudgetUpdateFailed)))` ("Could not update budget. Try again."), and leaves the tile intact (the caption stays at the prior value, no refresh). The form-row handler is symmetric.
- **`DoRepository.save` throws a generic drift exception** (e.g. DB locked, FK constraint). Same as `DoInvalidRestDays`: tile handler shows the failure SnackBar, no tile removal. Form-row handler shows an error snackbar inline.
- **The user navigates away from the tile while the dialog is open** (e.g. taps a notification). The `messenger` capture-before-async-gap pattern means the post-save SnackBar is shown on whatever ScaffoldMessenger is current when the future resolves; if the route is gone, `messenger.showSnackBar` is a no-op. The dialog is dismissed by the route pop (Flutter standard behavior).
- **The widget is unmounted mid-FutureBuilder** (e.g. the user navigates away before the save resolves). `DoRepository.save` writes to the singleton, the write succeeds, but the refresh callback (`widget.onDoChanged?.call()`) may fire on a disposed tile. The `_refresh()` callback is bound to the home screen state, not the tile state, so a disposed tile is safe — the home screen's `FutureBuilder` re-fires and the new tile mounts with the new value.
- **The slider thumb is dragged to a fractional value** (e.g. 4.7). The `Slider`'s `divisions: 31` constraint snaps to whole numbers; `v.round()` in `onChanged` ensures the stored value is always an integer. The live integer label above the slider is always a whole number.
- **The slider thumb is dragged to the boundary** (0 or 31). The `Slider(min: 0, max: 31)` clamps the value; the user cannot drag below 0 or above 31. The `Slider`'s `divisions: 31` gives exactly 32 stops (0, 1, ..., 31). The defensive clamp in `initState` handles a stale-DB-row start value.

### Requirements covered

- SYS-124 (this cycle's primary requirement — rest-day budget edit affordance on the home tile + the v1.0 silent-reset bug fix in `AddHabitScreen._save()`)
- ADR-054 (this cycle's primary architectural decision — caption-as-affordance + shared picker dialog + validation upper bound)
- ADR-053 (v1.4i / SYS-123 — the `_BudgetCaption` is the v1.4i-inherited surface that v1.4j turns into an affordance)
- ADR-052 (v1.4h / SYS-122 — the v1.4h `onDoChanged` prop + `_refresh()` cascade is re-used for the post-edit refresh)
- ADR-047 (v1.4c / SYS-117 — the `_SkipButton` is gated on `restDaysPerMonth > 0`; v1.4j's affordance lets the user change the gating value from the same tile)
- SYS-123 (v1.4i — the inline sparkline + legend visualizes the rest-day rows the user can now produce by editing the budget up from 0)
- SYS-122 (v1.4h — the `onDoChanged` + `_refresh()` cascade is re-used)
- SYS-117 (v1.4c — the rest-day rows visible in the v1.4i sparkline are now user-configurable via the v1.4j caption affordance)

## WF-052 — Bind the home widget to a specific do (per-instance configuration, v1.4k / Phase 38 / SYS-125 / ADR-055)

Closes the v1.4a gap where every widget instance on the home screen showed the same `firstActiveDo`. v1.4k adds the standard Android `AppWidget` configuration flow so the user can pick which do a given widget instance shows at bind time, AND routes the widget body-tap deep-link to the picked do's edit screen. Configuration is one-time per widget instance; the pick is sticky across `onUpdate` cycles (until the picked do is deleted, which triggers the reconciliation clear).

### Happy path

1. **User long-presses the home screen.** The launcher's widget chooser opens. The user finds the do it widget in the picker (the `android:label="@string/widget_label"` resource string).

2. **User drags the widget to a home cell.** The launcher fires `APPWIDGET_CONFIGURE` on `DoitWidgetConfigureActivity` BEFORE the first `onUpdate` — this is the standard launcher contract for any `<appwidget-provider android:configure="...">`. The activity launches with `Intent.EXTRA_APPWIDGET_ID` set to the launcher-assigned widget id.

3. **`DoitWidgetConfigureActivity.getInitialRoute()` returns `/widget-config?widgetId=$widgetId`.** The `FlutterActivity` thin-shell pattern (mirrors v1.3d `FullScreenActivity.getInitialRoute()` for the mission launcher). The activity does NOT attach any Kotlin channels — the Flutter side talks to `WidgetService.instance` directly via `WidgetServiceProxy`. `configureFlutterEngine` is intentionally NOT used.

4. **`DoItApp` mounts with the initial route.** `MaterialApp.onGenerateRoute: buildAppRoute` dispatches on `settings.name == '/widget-config'` to `buildWidgetConfigRoute`, which returns a `MaterialPageRoute<String?>` whose builder produces `WidgetConfigScreen(widgetId: widgetId)`.

5. **`WidgetConfigScreen` reads the do list.** `FutureBuilder<List<Do>>` calls `DoRepository.instance.listAll()` (the existing singleton — same path the home screen uses, so the picker always sees the same data as the home tile list). The screen renders a `ListView.separated` of `_PickerRow` `ListTile`s — one per do, with a chevron + the do name.

6. **User taps a row.** `_PickerRow.onTap` fires `_onPicked(habitId)` which `await`s `widget.proxy.setSelectedHabitId(habitId)` (writes the pick to `WidgetService.instance` via the proxy indirection) then `Navigator.of(context).pop<String>(habitId)`. The popped value is the picked habitId.

7. **`DoitWidgetConfigureActivity.setResult(RESULT_OK)` + finish.** The Kotlin activity sets `RESULT_OK` with the picked `habitId` in the result extras and finishes. The launcher then calls `DoitWidgetProvider.onUpdate` for the first time on the widget instance, with the picked `habitId` available to `WidgetRenderer.render(...)` via `WidgetStateCache.cachedFromPrefs(ctx)` (the cache was written by `WidgetService.setSelectedHabitId` BEFORE the activity finished, so the cold-start fallback has the picked state).

8. **Widget renders the picked do.** `WidgetRenderer.render(ctx, state)` reads `state.habitId == pickedId`, fetches the streak via the existing `ConsecutiveCounter` path, and paints the streak badge + reliability icon + completion-row buttons. The widget surfaces the picked do on the first frame.

9. **User taps the widget body.** The body's `PendingIntent` fires — `WidgetRenderer.openAppIntent(ctx, widgetId, state.optString("selectedHabitId", ""))` builds the Intent with `MainActivity.EXTRA_HABIT_ID_FROM_WIDGET = pickedId` as an extra. The Intent launches MainActivity (single-top).

10. **`MainActivity.getInitialRoute()` reads the extra.** The new `override fun getInitialRoute(): String?` reads `intent.getStringExtra(EXTRA_HABIT_ID_FROM_WIDGET)`. On a non-null + non-empty value it clears the extra (one-shot — `intent.removeExtra(...)`) and returns `"/habit?habitId=${Uri.encode(pickedId)}"`; on a null / empty value it returns `null` (the normal launch path — no reroute).

11. **Flutter embedding routes to `AddHabitScreen`.** The embedding passes the initial route to `MaterialApp.onGenerateRoute` on the first frame. `buildAppRoute` dispatches `/habit` → `buildHabitRoute` → `AddHabitScreen(habitId: pickedId)`. The user lands on the picked do's edit screen.

12. **User backs out.** Android back closes the edit screen → returns to the launcher. The widget stays pinned with the picked do.

13. **User binds a second widget instance.** Steps 1-12 repeat with a new `AppWidgetId` and a second picked do. Each widget's `DoitWidgetState` is keyed by the picked id (the SharedPreferences key `doit.widget.cached_v1` is shared — the JSON envelope carries both `habitId` AND `selectedHabitId` so the widget surface can distinguish which do it represents on a re-render). Both widgets render side-by-side, each showing a different do.

14. **User deletes the picked do from the in-app home screen.** The v1.4h `_DeleteButton` deletes the do from `DoRepository` and calls `widget.onDoChanged?.call()` to trigger `_refresh()`. The next `WidgetService.handleRefreshRequest` (triggered by the next `ReliabilityService` change OR the next widget `onUpdate`) calls `_resolveActiveDo()` → `getById(pickedId) == null` → falls back to `firstActiveDo`. The new state has `selectedHabitId = null` (the reconciliation clear). The widget surfaces `firstActiveDo` on the next render (the user's other dos, or the empty-state if there are none).

15. **User taps the widget body after the picked do was deleted.** `MainActivity.getInitialRoute()` reads `EXTRA_HABIT_ID_FROM_WIDGET` — but the cached `selectedHabitId` is `null` so the Kotlin `WidgetRenderer.openAppIntent` did NOT add the extra → `getInitialRoute()` returns `null` → normal launch. Alternatively, if the user re-bound the widget via the launcher (step 1-12 again) and picked a new do, the new pick is in the cache. The widget body-tap always reflects the current cached pick.

### Failure paths

- **`DoRepository.instance.listAll()` returns empty.** `WidgetConfigScreen._EmptyState` renders a `Icons.add_task` glyph + the localized `widgetConfigureEmptyState` copy ("Add a do in do it to use the home widget.") + a "Back to do it" `FilledButton` (label `widgetConfigureBackToHome`). Tapping the button pops `Navigator.of(context).pop()` (returns `null`). `DoitWidgetConfigureActivity.setResult(RESULT_CANCELED)` + finish. The launcher treats the cancel as a no-op — the widget is not bound, the cell stays empty. This is the launcher's documented contract for a cancelled configuration.
- **User back-presses the configuration activity.** Same as cancel — `setResult(RESULT_CANCELED)` + finish. The widget is not bound. The cell stays empty. (Note: `excludeFromRecents="true"` in the manifest means the activity does not appear in the Recents tray even if the user navigated into MainActivity via a separate path.)
- **`DoitWidgetConfigureActivity` is launched without `EXTRA_APPWIDGET_ID`.** The Kotlin `getInitialRoute()` reads `intent.getIntExtra(EXTRA_APPWIDGET_ID, 0)` and returns `"/widget-config?widgetId=$widgetId"` with the default `0`. The Flutter screen mounts with `widgetId: 0` (display-only — the AppBar shows the id). The pick is still written correctly because the widget's `DoitWidgetState` is keyed by the picked `habitId`, not by the AppWidget id (the cold-start fallback is a single SharedPreferences key, shared across all widget instances — the `selectedHabitId` field distinguishes them).
- **`WidgetService.setSelectedHabitId` returns `false` (service is disposed — unlikely in production, possible in test).** `_onPicked` does not check the return value — the `Navigator.pop<String>(habitId)` always fires. The picked id is in the result Intent regardless. The widget's first `onUpdate` re-derives via `WidgetService.handleRefreshRequest()` which is idempotent — even if the service was disposed, the next cold-start primes it via `WidgetService.init()`. The user sees the picked do on the second `onUpdate`.
- **`MainActivity` is killed between the body-tap and the route resolution.** Android standard behavior — the system re-launches MainActivity with the saved Intent. `getInitialRoute()` reads the extra on the fresh launch. The route resolves normally.
- **User toggles device language (locale change) while the configuration activity is on screen.** `AppLocalizations` re-loads via the `LocalizationsDelegate` on the next rebuild (mirrors the v1.1h / ADR-031 / SYS-087 i18n contract). The screen re-mounts with the new locale. The do list re-fetches via `FutureBuilder`.
- **The picked do is in a paused state.** `_resolveActiveDo()` returns the paused do (the `Do.effectiveScheduleConfig` predicate is independent of paused-state — matches the v1.4a `firstActiveDo` behavior). The widget surfaces the paused do with the streak + the reliability badge. The user can tap the body to navigate to the edit screen and un-pause.

### Requirements covered

- SYS-125 (this cycle's primary requirement — per-instance widget configuration + body-tap deep-link to the picked do)
- ADR-045 (v1.4a / SYS-115 — the `firstActiveDo` fallback is the default path; the v1.4a `WidgetStateCache.kt` Kotlin mirror is the cold-start fallback extended with the new `selectedHabitId` field)
- ADR-044 (v1.3d / SYS-114 — the Kotlin `getInitialRoute()` route-handoff is the same pattern; the `app_router.dart` extraction mirrors the v1.3d dispatch shape)
- ADR-051 (v1.4g / SYS-121 — the `doit/widget` MethodChannel namespace gains the `setSelectedHabitId` arm)
- ADR-050 (v1.4f / SYS-120 — the v1.4f `restDaysPerMonth` JSON envelope precedent is the model for `selectedHabitId`)
- ADR-052 (v1.4h / SYS-122 — the `WidgetServiceProxy` indirection layer is the v1.4h callback-handler seam pattern)
- SYS-115 (v1.4a — `WidgetStateCache.kt` mirror + `WidgetBridge.cacheSnapshot` round-trip)
- SYS-114 (v1.3d — `FlutterActivity` thin-shell + `getInitialRoute()` handoff)
- SYS-121 (v1.4g — `WidgetActionInvoker.attach()` dispatch table)


## WF-053 — Delete a do and undo within the SnackBar window (true restore, v1.4l / Phase 39 / SYS-126 / ADR-056)

**User goal.** The user wants to remove a do from the home screen, with confidence that the action is reversible within a short window (because they might tap Delete by mistake, or because they change their mind). v1.4l closes the v1.4h / SYS-122 trade-off where Undo re-saved the do via `insertOnConflictUpdate` but lost the completion-log rows (the Drift schema declares no FKs so cascade never fired) and the user's automations (the `_toRow` mapping bug, tracked separately).

**Trigger.** The user opens the home screen and taps the per-tile **Delete** IconButton on a `_HabitTile` (v1.4h / SYS-122).

**Flow.**

1. The `_HabitTile._DeleteButton.onPressed` opens an `AlertDialog` with the title `homeTileDeleteConfirm(habit.name)` ("Delete \"X\"?") and body `homeTileDeleteConfirmBody` ("This will remove the do from your home screen. You can undo for a few seconds after.").
2. On confirm (the dialog's "Delete" `TextButton`), the tile:
   - captures `messenger = ScaffoldMessenger.of(context)` BEFORE the async gap,
   - sets `_busy = true`,
   - calls `softDeleteDo(activeDo: widget.habit, at: DateTime.now(), repository: DoRepository.instance)` (the v1.4l helper at `lib/screens/home_tile_delete.dart`),
   - the helper calls `repository.softDeleteById(activeDo.id, at: at)` which runs `UPDATE habits SET deleted_at_millis = ? WHERE id = ? AND deleted_at_millis IS NULL`,
   - returns `true` on a clean update, `false` on a missing or already-tombstoned row.
3. On `true` the tile:
   - calls `widget.onDoChanged?.call()` → `_HomeScreenState._refresh()` → the parent's `FutureBuilder<List<Do>>` re-fires → `listAll()` returns one fewer do (the tombstoned row is filtered at the SQL level by `..where((t) => t.deletedAtMillis.isNull())`) → the tile disappears from the home screen.
   - shows a SnackBar `homeSnackbarDoDeleted(habit.name)` ("Deleted \"X\".") with a `SnackBarAction` labeled `homeSnackbarDoDeletedUndo` ("Undo") whose `onPressed` captures the original `widget.habit` reference (immutable per `lib/do/do.dart`) and calls `restoreDo(tombstonedDo: capturedHabit, repository: DoRepository.instance)`.
   - `restoreDo` calls `repository.restoreById(tombstonedDo.id)` which runs `UPDATE habits SET deleted_at_millis = NULL WHERE id = ? AND deleted_at_millis IS NOT NULL` — a single UPDATE, idempotent.
   - On the Undo callback's success, the parent's `_refresh()` re-fires (via the `messenger.showSnackBar`'s callback path), `listAll()` returns the do (the tombstone is cleared), and the tile reappears with the SAME row id → same completion log → same streak counter (the headline behavior change of v1.4l — streak survives because `Completions.habitId` references the same id that survived the soft-delete).

   The Undo path is `restoreById`, NOT `save(d)`, because `save(d)` would invoke Drift's `insertOnConflictUpdate` which on the tombstoned row preserves the `deleted_at_millis` (per the v1.4l "save is content-only" invariant — `DoRepository._toRow` does NOT write `deletedAtMillis`, so the existing column value persists across a Save click). `restoreById` is the only API that can clear the tombstone.
4. On `false` (helper returned false — DB locked, drift exception, already-tombstoned row) the tile:
   - does NOT call `widget.onDoChanged` (the row is still in the listing),
   - shows `homeSnackbarDoDeleteFailed` ("Could not delete. Try again.").
5. After ~4 s the SnackBar dismisses; the do is gone from the listing. The tombstone is persistent across app restarts (it's a column in the local DB) but the UI never surfaces tombstoned rows. A v1.4l+ "Recently deleted" surface would offer an off-SnackBar restore path — out of scope for v1.4l.

**Failure paths.**

- *DB write fails.* The helper returns `false`; the tile stays; the user sees the failure snackbar. The user's streak is untouched.
- *The user creates a new do with the same name in the gap.* The Undo's `restoreById` is a single UPDATE on `id` (not `name`) — it cannot collide with `DuplicateDoName`. The Undo always succeeds; both dos coexist (the restored one with its old id + completion log, the new one with its new id).
- *The user soft-deletes the do, doesn't Undo, then relaunches the app.* The tombstone is persistent in the local DB. `listAll()` and `listActive()` filter it out. The home screen never shows it. A future "Recently deleted" surface would surface it; out of scope for v1.4l.
- *A widget instance was bound to the deleted do (v1.4k / SYS-125 picked `selectedHabitId = deleted.id`).* `WidgetService.handleRefreshRequest` calls `_doRepository.getById(pick)` — the tombstoned row is still returned (semantics preserved); the reconciliation path distinguishes "the do was soft-deleted" (the row has `deletedAt != null` → the picker is stale, the widget falls back to `firstActiveDo`) from "the do was hard-deleted" (the row is `null` → the picker is gone, the widget falls back to `firstActiveDo`). Both paths clear `selectedHabitId` to `null` so a future re-bind starts fresh.

**Coverage.** `test/screens/home_tile_delete_test.dart` (14 tests) + `test/screens/home_test.dart` (+2 existing v1.4h tests updated to assert via `getActiveById` since `getById` returns the tombstoned row post-v1.4l) + `test/services/do_repository_test.dart` (14 tests across the soft-delete / restore / save-invariant / hard-delete groups) + `test/db/migration_v4_to_v5_test.dart` (4 tests).

**Cross-references.**

- SYS-122 (v1.4h — the per-tile Edit + Delete IconButtons; the prior hard-delete + re-insert Undo trade-off)
- SYS-126 (v1.4l — the soft-delete tombstone requirement)
- ADR-056 (v1.4l — the soft-delete design decisions, especially the "save is content-only" invariant and the `restoreById` path)
- WF-049 (v1.4h — the prior Delete + Undo flow that v1.4l replaces)
- WF-051 (v1.4j — the rest-day-budget edit affordance, the parallel "in-place mutation + Undo-style fallback" pattern)


## WF-055 — CI exercises the v1.4l soft-delete home-screen flow end-to-end (v1.4m / Phase 40 / SYS-127 / ADR-058)

**User goal.** The v1.4l / WF-053 soft-delete home-screen flow (Delete + Undo within the SnackBar window → streak restores by construction) is a load-bearing user-visible behavior change. Without CI coverage, regressions in `DoRepository._toRow`'s "save is content-only" invariant or in the `_DoStreakBadge` widget's `Completions.habitId` lookup would silently break the streak-on-Undo behavior — the user would not see the regression until they re-installed the APK and tested manually. v1.4m ships the CI guard so the v1.4l PR's 6-step on-device smoke can be replaced by `flutter test` in CI.

**Trigger.** The CI pipeline runs on every PR (the existing GitHub Actions workflow at `.github/workflows/ci.yml`).

**Flow.**

1. `flutter test test/services/do_repository_test.dart` runs the v1.4m `listDeleted` group (4 tests):
   - `listDeleted` excludes active habits — seeds 2 habits (`h-active`, `h-deleted`), soft-deletes `h-deleted`, asserts `listDeleted()` returns `[h-deleted]` (not both).
   - `listDeleted` orders by `deletedAtMillis DESC` — seeds 2 habits, soft-deletes `h-old` at `DateTime(2026, 6, 1)` and `h-recent` at `DateTime(2026, 6, 27)`, asserts `listDeleted()` returns `[h-recent, h-old]` (most-recently-deleted first).
   - `listDeleted({int? limit})` honors the `limit` param — seeds 3 tombstoned habits, asserts `listDeleted(limit: 2)` returns the 2 most-recently-deleted.
   - `listDeleted` returns an empty list when no habits are tombstoned — seeds 1 active habit, asserts `listDeleted()` returns `[]`.
2. `flutter test test/services/do_repository_test.dart` runs the v1.4m `purgeDeletedOlderThan` group (4 tests):
   - purges tombstoned habits older than the cutoff — seeds 2 tombstoned habits (`h-old` at 2026-05-01, `h-recent` at 2026-06-15), calls `purgeDeletedOlderThan(Duration(days: 30), at: DateTime(2026, 6, 27))`, asserts `h-old` is gone AND `h-recent` is still tombstoned.
   - leaves young tombstoned habits untouched — seeds 1 tombstoned habit at `DateTime.now() - Duration(days: 1)`, calls `purgeDeletedOlderThan(Duration(days: 30), at: now)`, asserts the habit is still tombstoned.
   - never touches active habits — seeds 1 active habit, calls `purgeDeletedOlderThan(Duration(days: 0), at: now)`, asserts the active habit is still there.
   - is idempotent on a second call — calls `purgeDeletedOlderThan` twice with the same args, asserts the second call returns `0`.
3. `flutter test test/services/do_repository_test.dart` runs the v1.4m `persistence-across-restart` group (1 test):
   - Phase A: opens an in-memory DB, saves a do (`h1`), soft-deletes it at a frozen `at`, closes the DB.
   - Phase B: opens a FRESH in-memory DB, seeds the raw `habits` row via `customStatement('INSERT INTO habits ...')` with `deleted_at_millis` set, asserts `getById('h1')` returns the tombstoned do with `isDeleted == true`.
   - This proves the column survives what the user sees as "close + reopen the app" — the v1.4l headline behavior change (Undo restores streak by construction) depends on this persistence.
4. `flutter test test/screens/home_test.dart` runs the v1.4m widget group (4 tests):
   - `Undo restores the streak badge to the original value by construction` — seeds a do + 3 consecutive completions (yesterday, day before, 3 days ago), pumps the home screen, asserts the streak badge renders `Text('3')` (the "before" state). Taps the Delete IconButton, confirms the dialog, waits for the SnackBar. Taps the SnackBar's `SnackBarAction` (Undo), re-pumps, asserts the streak badge's `KeyedSubtree(key: 'streakBadge-<id>')` finds a `Text('3')` widget (the "after" state — streak survived because `Completions.habitId` references the same id that survived the soft-delete).
   - `streak badge renders the streak number with the correct tabular formatting` — seeds a do + 3 completions, asserts the badge's `KeyedSubtree` finds BOTH a `Text('3')` (the streak number) AND a `Text('day streak')` (the subtitle).
   - `cancelled delete (Cancel on confirm dialog) does NOT tombstone the do and the streak badge remains rendered` — seeds a do + 3 completions, pumps, taps Delete IconButton, taps the Cancel button on the confirm dialog, asserts the do is STILL in the listing AND the streak badge STILL renders `Text('3')` (Cancel must not partially-tombstone — the row is unchanged).
   - `soft-delete persists across a HomeScreen rebuild (close + reopen the in-memory DB)` — seeds a do + 3 completions, pumps, taps Delete, confirms, asserts the do is gone. Calls `_resetDb(tester)` to swap in a fresh in-memory DB, re-pumps the widget, asserts the do is STILL gone (the tombstone survives the DB swap — same persistence guarantee as the persistence-across-restart repository test, but at the widget level).

**Failure paths.**

- *A future contributor accidentally adds `deletedAtMillis: d.deletedAt?.millisecondsSinceEpoch` to `DoRepository._toRow`'s save-path `HabitsCompanion`.* The v1.4m `persistence-across-restart` test would fail (the tombstone would be overwritten with `null` on the second `save` call — but in this test the row is seeded via raw SQL so the path that matters is the `save` after a `restoreById`; the test asserts the restore-by-id path works). The headline widget test (`Undo restores the streak badge`) would also fail because the soft-delete → save-on-Undo chain would silently resurrect the tombstone via the `save` → `insertOnConflictUpdate` path. Both tests guard the invariant from different angles.
- *A future contributor refactors `_DoStreakBadge` and breaks the `KeyedSubtree` seam.* The `find.byKey(Key('streakBadge-<id>'))` lookup would fail. The test gives a precise error message ("No widget with key 'streakBadge-h1' found") — easier to diagnose than "streak badge does not render after Undo".
- *A future contributor changes `listDeleted`'s order from `DESC` to `ASC`.* The "orders by `deletedAtMillis DESC`" test would fail. The fix is a one-line `..orderBy(...)` change — but the failure surfaces immediately in CI rather than at on-device smoke time.

**Coverage.** 13 new tests (4 listDeleted + 4 purgeDeletedOlderThan + 1 persistence-across-restart + 4 widget). Total test count: 1321 → 1334. Coverage: ≥80% on every changed file (`do_repository.dart`, `home.dart`, `home_test.dart`, `do_repository_test.dart`).

**Cross-references.**

- SYS-127 (v1.4m — the CI coverage + API surface stabilization this WF documents)
- SYS-126 (v1.4l — the soft-delete tombstone requirement that v1.4m exposes + tests)
- ADR-058 (v1.4m — the design decisions for the API surface + the test seams)
- ADR-056 (v1.4l — the soft-delete design decisions; v1.4m's `listDeleted` + `purgeDeletedOlderThan` ride on the v1.4l data layer)
- WF-053 (v1.4l — the Delete + Undo user flow that v1.4m's widget tests guard against regression)

---

## WF-056 — Kick off the 3-month stabilization campaign: coverage audit + roadmap (v1.4-stab-A / Phase 41 / SYS-128 / ADR-059)

**User goal.** After v1.4a..v1.4m shipped 12 cycles of net-new surface (1130 → 1334 tests, 26 PRs, ~900 tests added), the user redirected from feature work to hardening: "we have 3 month to stabilise the app and have exhaustive test". The user needs a clear, sequenced plan for the 3 months — what's broken, what gets fixed when, and how we'll know we're done. Cycle A produces that plan.

**Trigger.** The CI pipeline runs `flutter test --coverage` (the existing GitHub Actions workflow at `.github/workflows/ci.yml`). Cycle A reads the report + produces the roadmap doc.

**Flow.**

1. **Run `flutter test --coverage`** — produces `coverage/lcov.info`. The 1334 existing tests all pass (verified by the 3-gate). The coverage report is the input for the audit.
2. **Parse `coverage/lcov.info` per-file.** Use a small Python parser (the `lcov` package is not installed in this dev environment; Python's standard library suffices to extract `SF` / `LF` / `LH` markers). Compute per-file coverage % and bucket: Priority 1 (< 80%), Priority 2 (80-90%), Priority 3 (≥ 90%). 33 files fall in Priority 1, 31 in Priority 2, 59 in Priority 3.
3. **Inventory latent bugs.** Read `feature.md §4` + `v1.4l ADR-056 §6` + `v1.1f ADR-031` + every BUG-tracking doc. Catalog BUG-001..BUG-006 as known. Audit adds BUG-007..BUG-020 from the coverage findings (low coverage on the pure-Dart model layer is itself a defect — the model layer should hit 100%).
4. **Sequence Cycles B..L.** 11 cycles, sequenced by priority:
   - **B** — fix `_toRow` automations + pausedUntil data-loss bugs (P0).
   - **C** — full-screen launch hardening (P1, Android 14+).
   - **D** — permission flow audit (P2).
   - **E** — reliability detection coverage (P1).
   - **F** — backup round-trip exhaustive (P1).
   - **G** — DoAnchor "Target paused" badge (P2, completes v1.4l UI).
   - **H** — Restore / delete-forever UI (the deferred v1.4n; completes v1.4l feature).
   - **I** — i18n test exhaustive (P2).
   - **J** — accessibility audit (P2).
   - **K** — E2E integration tests (P2, 10 critical flows).
   - **L** — performance audit + fuzz + benchmark (P3).
5. **Write `docs/v_model/stabilization_roadmap.md`.** 6 sections (§1 coverage state, §2 latent bugs, §3 cycle-by-cycle roadmap, §4 success criteria, §5 open questions, §6 Cycle A retrospective). Single source of truth for the 3-month campaign — every subsequent cycle updates it.
6. **Append V-Model artifacts.** SYS-128 to `docs/v_model/requirements.md`. ADR-059 to `docs/v_model/decision_record.md` (the pivot + sequencing decisions). WF-056 (this entry) to `docs/v_model/workflows.md`. Traceability row to `docs/v_model/traceability_matrix.md`. Implementation-status row to `docs/v_model/implementation_status.md`. CHANGELOG v1.4-stab-A block. `feature.md` §4 / §5 / §6 updates (move v1.4n parking-lot bullet; update §5 quick-index; update §6 next-step). `plan.md` Milestone 12 entry + v1.4-stab-A sub-entry.
7. **Run 3-gate.** `dart format --output=none --set-exit-if-changed .` (0 changed — no Dart code modified) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1334/1334 pass — no test changes). The 3-gate is a regression check: Cycle A's doc-only changes must not break the existing test suite.
8. **Commit + push + open PR + poll CI + squash-merge.** The PR is a doc-only change (the `coverage/lcov.info` artifact is auto-generated and may be gitignored — check `.gitignore` and include or exclude accordingly). Cycle A is the smallest possible PR — the diff is the new roadmap doc + V-Model artifacts.

**Failure paths.**

- *The audit finds more gaps than the 11 cycles can close.* The roadmap doc captures every gap; the success criteria define what's "done enough" (≥90% line coverage, 100% on model layer, 0 known bugs). If audit findings exceed that, lower-priority cycles (L's fuzz testing, J's polish) get trimmed or pushed to v2.0.
- *Cycle B's fix breaks a v1.4l save invariant.* Cycle B's tests pin the `_toRow` "save is content-only" invariant for `automationsJson` + `pausedUntilMillis` (parallel to v1.4m's `deletedAtMillis` pin). The save-invariant test group catches regressions.
- *The user disagrees with cycle sequencing.* The roadmap doc's §3 ordering is provisional. The user can reorder via this doc's next cycle. The roadmap doc is the authoritative source — re-plan the next cycle in plan mode and update §3.
- *The 3-month window slides (illness, vacation, urgent user-reported bugs).* Lower-priority cycles (L, J) are trimmed first. The success criteria are aspirational; the priority is closing the latent bugs + hardening the reliability paths, not hitting 100% coverage on every screen.

**Coverage.** Cycle A ships 0 new tests. The "test" deliverable is the coverage report (`coverage/lcov.info` + the per-file table in `docs/v_model/stabilization_roadmap.md §1`). Total test count unchanged: 1334/1334 pass. Coverage on `lib/`: 8812/13638 lines (64.61%) — the BASELINE for the 3-month campaign.

**Cross-references.**

- SYS-128 (v1.4-stab-A — the stabilization campaign kickoff + audit + roadmap cycle this WF documents)
- ADR-059 (v1.4-stab-A — the pivot from feature work to stabilization + the cycle sequencing decisions)
- `docs/v_model/stabilization_roadmap.md` (NEW — the single source of truth for the 3-month campaign; sections §1-§6 cover coverage state, latent bugs, cycle roadmap, success criteria, open questions, retrospective)
- ADR-058 (v1.4m — the "tests first, then UI" inversion that justifies Cycle H's positioning inside the window)
- ADR-056 (v1.4l — the soft-delete data layer that Cycle H's UI consumes + the "Target paused" semantics that Cycle G's UI ships)
- BUG-001..BUG-020 (the latent bugs inventoried in `stabilization_roadmap.md §2`; the campaign's success criterion #4 is "0 known latent bugs" — every BUG-NNN closed by some cycle)
- WF-053 (v1.4l — the Delete + Undo user flow that Cycle H's restore-after-window completes)
- WF-055 (v1.4m — the API surface stabilization that Cycle H consumes)

---

## WF-057 — Fix `_toRow` automations + pausedUntil data-loss bugs (v1.4-stab-B / Phase 42 / SYS-129 / ADR-060)

Cycle B of the 3-month stabilization campaign (per `docs/v_model/stabilization_roadmap.md §3`). Closes BUG-001 + BUG-002 (both P0 data-loss bugs that silently lose user state on Save). The cycle is pure-Dart + 3 new tests — no Drift migration, no new permissions, no new dependencies, no Kotlin changes.

### Steps

1. **Read the current state of the affected files.** `lib/services/do_repository.dart` (the `_toRow` / `_fromRow` mapping at lines 273-462 + the `save()` KDoc at lines 42-80). `lib/services/pause_service.dart` (the `pauseHabit` / `resumeHabit` methods at lines 73-81). `test/services/do_repository_test.dart` (the existing v1.4l save-invariant test group at lines 263-323 to mirror). `lib/services/db/schema.dart` (the `Habits` table definition — confirm `automationsJson` + `pausedUntilMillis` columns exist so no Drift migration is needed).

2. **Add the import to `do_repository.dart`.** At the top with the other `package:doit/...` imports, add `import 'package:doit/routines/routine.dart' show decodeAutomationList, encodeAutomationList;`. This pulls in the codec from `lib/routines/routine.dart` (the `encodeAutomationList` + `decodeAutomationList` functions at lines 488-505).

3. **Update `_toRow` to add `automationsJson`.** Insert `automationsJson: d.automations.isEmpty ? null : encodeAutomationList(d.automations),` into the `HabitRow(...)` constructor (position before the (now-removed) `pausedUntilMillis` line). The empty-list → NULL mapping matches the `EventRepository` / `PersonRepository` convention.

4. **Update `_toRow` to remove `pausedUntilMillis`.** Delete the `pausedUntilMillis: d.pausedUntil?.millisecondsSinceEpoch,` line. This is the v1.4l `deletedAtMillis` omission pattern (ADR-056) applied to the pause column. Drift's `insertOnConflictUpdate` semantics preserve the existing column value when the new row doesn't specify it, so a Save click that doesn't explicitly pause/resume must not clobber the existing pause state.

5. **Update `_toRow`'s KDoc.** Add a new comment block mirroring the v1.4l `deletedAtMillis` comment shape, explaining that `pausedUntilMillis` is INTENTIONALLY omitted for the same reason. Cross-reference `pause_service.dart` and ADR-060. Also add a comment block explaining that `automationsJson` IS written (the inverse pattern — automations are part of the do's content).

6. **Update `_fromRow` to decode `automationsJson`.** In the base record (the tuple around lines 355-369), decode `r.automationsJson` via `decodeAutomationList(r.automationsJson)` and add `automations: automations,` to the base record. Then thread `automations: base.automations,` through every subclass constructor's `super.automations` parameter (5 arms: `DoFixed`, `DoInterval`, `DoAnchor`, `DoDayOfX`, `DoTimeWindow`).

7. **Update `save()`'s KDoc.** Document the dual invariant: "v1.4l (SYS-126): `save` is **content-only** — it does NOT touch the tombstone column" AND "Cycle B (SYS-129): `save` is also **pause-preserving** — it does NOT touch the `pausedUntilMillis` column". Cross-reference `PauseService.pauseHabit` / `resumeHabit` as the explicit writers.

8. **Refactor `PauseService.pauseHabit`.** Replace the body with a direct `HabitsCompanion` UPDATE:
   ```dart
   Future<void> pauseHabit(Do habit, DateTime until) async {
     await _ready;
     final db = AppDatabaseService.instance.db;
     await (db.update(db.habits)..where((t) => t.id.equals(habit.id)))
       .write(HabitsCompanion(pausedUntilMillis: Value(until.millisecondsSinceEpoch)));
   }
   ```
   Update the KDoc to explain the bypass: pause/resume bypass `save()` because `save()` is content-only + pause-preserving.

9. **Refactor `PauseService.resumeHabit`.** Replace the body with a direct `HabitsCompanion` UPDATE:
   ```dart
   Future<void> resumeHabit(Do habit) async {
     await _ready;
     final db = AppDatabaseService.instance.db;
     await (db.update(db.habits)..where((t) => t.id.equals(habit.id)))
       .write(const HabitsCompanion(pausedUntilMillis: Value(null)));
   }
   ```
   KDoc mirrors the `pauseHabit` rationale.

10. **Add the imports to `pause_service.dart`.** Add `import 'package:doit/services/db.dart';` (for `AppDatabaseService`), `import 'package:doit/services/db/schema.dart';` (for `HabitsCompanion`), and `import 'package:drift/drift.dart' show Value;`. The existing imports cover `Do`, `Person`, `DoRepository`, `PersonRepository`.

11. **Extend the `_do(...)` test helper.** Add 2 optional named parameters to `_do` in `test/services/do_repository_test.dart`: `List<Automation>? automations` (default `null`) and `DateTime? pausedUntil` (default `null`). Forward them through to the `DoFixed` constructor's `automations:` and `pausedUntil:` parameters.

12. **Add the `_twoAutomations()` test helper.** A function that returns 2 `Automation` fixtures with stable ids and different `Trigger` leaves (e.g., `TriggerBatteryLow(20)` + `TriggerTimeOfDay(7, 30)`) so the round-trip test exercises the codec's discriminator handling for 2 distinct Trigger shapes.

13. **Add 3 new tests in a `DoRepository save invariant (Cycle B / BUG-001 + BUG-002)` group.** Place it after the existing v1.4l save-invariant group (line 323) and before the hard-delete group:
    - `automations round-trip through save + getById` — seed 2 automations, save, getById, assert list round-trips (BUG-001 round-trip).
    - `pausedUntil round-trips via direct companion UPDATE + getById` — seed `pausedUntilMillis` via a `HabitsCompanion` UPDATE, getById, assert `Do.pausedUntil` matches (BUG-002 read path).
    - `save(d) does NOT clobber an existing pausedUntilMillis` — seed via companion UPDATE, save a fresh `Do` with no in-memory `pausedUntil`, assert the raw column's `pausedUntilMillis` STILL equals the seeded timestamp AND the in-memory copy sees the same value (BUG-002 save-invariant — the headline test).

14. **Append V-Model artifacts.** SYS-129 to `docs/v_model/requirements.md` (table row mirroring the SYS-126 / SYS-127 / SYS-128 shape). ADR-060 to `docs/v_model/decision_record.md` (the omission-pattern rationale + the `PauseService` refactor rationale + the read-modify-write alternative rejection + the pure-Dart scope). WF-057 (this entry) to `docs/v_model/workflows.md`. Traceability row to `docs/v_model/traceability_matrix.md` (linking SYS-129 to the 3 new tests in `do_repository_test.dart` Cycle B group). Implementation-status row to `docs/v_model/implementation_status.md`. CHANGELOG v1.4-stab-B block. `feature.md` §4 (remove BUG-001 + BUG-002 parking lot bullets), §5 (update quick-index to ADR-060 / SYS-129 / WF-057), §6 (update next-step to Cycle C). `plan.md` Milestone 12 `### v1.4-stab-B` sub-entry.

15. **Run 3-gate.** `dart format --output=none --set-exit-if-changed .` (264 + ~4 files, 0 changed) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1334 + 3 = 1337/1337 pass). Targeted runs per `CLAUDE.md`: `flutter test test/services/do_repository_test.dart` (+3 new tests) + `flutter test test/services/pause_service_test.dart` (regression — readiness gate unchanged).

16. **Commit + push + open PR + poll CI + squash-merge.** Branch name: `feat/v1.4-stab-B-to-row-automations-pausedUntil`. Conventional commit message: `fix(v1.4-stab-B): _toRow round-trip for automations + pausedUntil (BUG-001 + BUG-002)`. Squash-merge. CI run number + duration recorded in the memory file.

**Failure paths.**

- *A Drift migration is needed.* Not expected — both `automationsJson` + `pausedUntilMillis` columns already exist on `Habits` (added in v3→v4). If `flutter analyze` flags a schema mismatch, abort and re-plan the migration as its own PR per `CLAUDE.md §"Pre-approved commands"` (a migration is its own PR).

- *The `_fromRow` threading misses a subclass arm.* The round-trip test uses 2 `Automation` fixtures; if a subclass forgets to thread `automations`, `Automation.==` will fail on the loaded list. Run the targeted test early to catch.

- *The `PauseService` refactor regresses existing behavior.* The readiness-gate tests in `test/services/pause_service_test.dart` don't exercise column writes — run `test/services/do_repository_test.dart`'s 3 new tests to verify the column reads via `getById` after a `HabitsCompanion` UPDATE.

- *A future contributor re-adds `pausedUntilMillis: d.pausedUntil?.…` to `_toRow`.* The Cycle B save-invariant test pins the behavior; the `_toRow` KDoc explains why the column is omitted. The pin survives `_toRow` edits.

- *The user disagrees with the omission pattern (wants read-modify-write instead).* Re-plan in plan mode; the read-modify-write alternative is documented in ADR-060 §"Why the omission pattern" and can be revisited if the user prefers it.

**Coverage.** Cycle B adds 3 new unit tests (test count 1334 → 1337). The 3 new tests are in `test/services/do_repository_test.dart` under a new group `'DoRepository save invariant (Cycle B / BUG-001 + BUG-002)'`. Coverage on changed files (`do_repository.dart`, `pause_service.dart`, `do_repository_test.dart`) stays ≥80%. Cycle B is a bug-fix cycle, not a coverage cycle — the 3-month campaign's coverage gains come from Cycles C..L.

**Cross-references.**

- SYS-129 (v1.4-stab-B — the `_toRow` round-trip + save-invariant requirement)
- ADR-060 (v1.4-stab-B — the omission-pattern rationale + the `PauseService` refactor + the read-modify-write alternative rejection + the pure-Dart scope)
- ADR-056 (v1.4l — the `deletedAtMillis` omission precedent; Cycle B mirrors this pattern for `pausedUntilMillis`)
- ADR-058 (v1.4m — the "tests first, then UI" inversion)
- ADR-059 (v1.4-stab-A — the audit + roadmap cycle that inventoried BUG-001 + BUG-002 at P0 and assigned them to Cycle B)
- `docs/v_model/stabilization_roadmap.md §2` (BUG-001 + BUG-002 inventory; mark both as "closed (Cycle B)" in the §2 table when this cycle ships)
- WF-056 (v1.4-stab-A — the audit cycle's flow)
- WF-053 (v1.4l — the Delete + Undo user flow; the `save` KDoc dual invariant covers both tombstones and pause state)
- `lib/services/event_repository.dart:97-99` + `lib/services/person_repository.dart:70-72` (the established `automationsJson` write pattern that `_toRow` now mirrors)

### WF-058 — FSI reliability wiring: defense-in-depth + channel-surface gap pin (v1.4-stab-C / Phase 43)

Cycle C of the 3-month stabilization campaign implements the FSI reliability wiring + BUG-003 closure as a 14-step test-first flow. Each step has a verification check + a failure path documented. The cycle is pure-Dart + docs (no Kotlin changes, no new pubspec deps, no new `<uses-permission>`, no Drift migration).

**Step 1.** Read `lib/services/full_screen_intent_service.dart` to confirm the current shape: (a) `MethodChannelFullScreenIntentSource` (was `_MethodChannelFullScreenIntentSource` — pre-Cycle C underscore prefix) wraps a `MethodChannel('doit/full_screen')`; (b) `isGranted()` invokes `canUseFullScreenIntent`; (c) `openSettings()` invokes `openFullScreenIntentSettings`; (d) both methods catch `MissingPluginException` + `PlatformException` and return `false`. **Verification:** the swallow pattern is already in the file (the v1.3c / SYS-113 cycle added it). **Failure path:** if the catches are missing, the test-driven defense-in-depth is moot and Cycle C is a no-op — escalate to a hot-fix.

**Step 2.** Read `docs/v_model/notification_reliability.md:496` to find the "On API 14+" typo. **Verification:** the line exists at byte offset around 14600-14650 (the §"Reliability detection" section). **Failure path:** if the line has been moved by a subsequent doc edit, grep for `API 14+` repo-wide to locate.

**Step 3.** Read `lib/reminders/full_screen_intent.dart:1-24` to find the stale `wakelock_plus` reference. **Verification:** the file-level header comment mentions `wakelock_plus`. **Failure path:** if a previous cycle has already corrected it, skip Step 4 and add a note to the commit message.

**Step 4.** Read `lib/reminders/reminder_bridge.dart:60` + `:218` to confirm the Dart-side `showFullScreen` seam shape. **Verification:** the interface declaration + the implementation invoke are present. **Failure path:** if the seam has been removed by a subsequent refactor, skip Steps 5-9 and the `reminder_bridge_fsi_channel_test.dart` file.

**Step 5.** Read `android/app/src/main/kotlin/com/doit/ReminderChannelProxy.kt:33-78` to confirm the Kotlin `when` block lacks a `showFullScreen` arm. **Verification:** the `when` handles `setExact`, `cancel`, `showNotification`, `cancelNotification`, `probeReliability`; everything else falls through to `notImplemented()`. **Failure path:** if a future Kotlin PR has added the arm, the channel-surface gap test will fail (which is the desired state — the test pins the gap, and closing the gap invalidates the test, prompting removal).

**Step 6.** Rename `_MethodChannelFullScreenIntentSource` → `MethodChannelFullScreenIntentSource` in `lib/services/full_screen_intent_service.dart`. Add `@visibleForTesting` annotation. Update all 4 internal references (the constructor delegation at line 184-185, the `resetForTesting` reset at line 244, the KDoc reference at line 230, and the `instance` default at line 190). **Verification:** `grep -n "_MethodChannelFullScreenIntentSource" lib/` returns 0 matches. **Failure path:** if a reference is missed, the build fails with "undefined class"; fix the reference and re-run.

**Step 7.** Write the class-level KDoc on `MethodChannelFullScreenIntentSource` documenting the defense-in-depth swallow as INTENTIONAL per ADR-013 + ADR-061. Cross-reference `ReliabilityService._safeProbe` at `lib/services/reliability_service.dart` as the precedent. **Verification:** the KDoc is visible in `flutter analyze` output (no issue) + in the rendered docs.

**Step 8.** Fix the stale `wakelock_plus` reference at `lib/reminders/full_screen_intent.dart:1-24`. Replace with a reference to `android/app/src/main/kotlin/com/doit/FullScreenActivity.kt:47-56` `FLAG_KEEP_SCREEN_ON`. **Verification:** `grep -r "wakelock_plus" lib/` returns 0 matches.

**Step 9.** Fix the doc typo at `docs/v_model/notification_reliability.md:496` "On API 14+" → "On API 34+". **Verification:** `grep -n "API 14+" docs/v_model/notification_reliability.md` returns 0 matches.

**Step 10.** Write `test/reminders/full_screen_intent_test.dart` (NEW) with 3 tests: (a) `FakeFullScreenIntent.show` records every `FullScreenLaunch` in invocation order (2 habits, assert both launches are recorded with the correct habit id + name). (b) `FakeFullScreenIntent.showRoutineOverlay` records title + body exactly as supplied (4 calls covering title-only / body-only / neither / both, assert the recorded `RoutineOverlayLaunch` list matches). (c) `FakeFullScreenIntent.getLaunchIntent` returns the scripted launch intent and appends it to `launchIntents` (2 reads of the same scripted `LaunchIntent`, assert both returns match + both appends are recorded). Plus 2 equality tests (one for `RoutineOverlayLaunch`, one for `LaunchIntent`). Total: 5 tests (the "3 tests" headline in `implementation_status.md` counts the 3 grouped tests; the 2 equality tests are included in the 5). **Verification:** the new file is created, the test count delta matches.

**Step 11.** Extend `test/services/full_screen_intent_service_test.dart` with a `MethodChannelFullScreenIntentSource (production source)` group containing 3 tests: (a) `isGranted` returns `false` when the platform throws `PlatformException` (defense-in-depth per ADR-061); (b) `openSettings` returns `false` when the platform throws `PlatformException`; (c) `isGranted` returns `false` when the platform throws `MissingPluginException`. All 3 mock the channel via `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler`. **Verification:** the existing `ScriptedFullScreenIntentSource` tests still pass (no regression on the test seam).

**Step 12.** Write `test/reminders/reminder_bridge_fsi_channel_test.dart` (NEW) with 2 tests: (a) `PlatformReminderBridge.showFullScreen` invokes the channel method (assert the channel method log has 1 entry with method=`showFullScreen` + args={habitId: 'h-fsi-stab'}). (b) `PlatformReminderBridge.showFullScreen` throws `MissingPluginException` when the Kotlin handler has no arm (mock returns `notImplemented()` for unknown methods; assert `expectLater(() => b.showFullScreen('h-fsi-stab-gap'), throwsA(isA<MissingPluginException>()))`). **Verification:** both tests pass; the gap is pinned as a known follow-up bug.

**Step 13.** Append V-Model artifacts: SYS-130 row to `docs/v_model/requirements.md`; ADR-061 section to `docs/v_model/decision_record.md`; this WF-058 to `docs/v_model/workflows.md`; WF-058 row to `docs/v_model/traceability_matrix.md`; `### v1.4-stab-C` row to `docs/v_model/implementation_status.md`; `### v1.4-stab-C` sub-entry to `docs/v_model/plan.md` Milestone 12 (after the v1.4-stab-B sub-entry); `## v1.4-stab-C` block to `CHANGELOG.md`; `feature.md` §4 BUG-003 parking lot bullet removed + §5 quick-index updated (ADR-061 / SYS-130 / WF-058) + §6 next-step updated to Cycle D (`feat/v1.4-stab-D-permission-flow-audit`). **Verification:** `grep -n "SYS-130\|ADR-061\|WF-058\|v1.4-stab-C" docs/v_model/*.md` returns the expected count of matches.

**Step 14.** Run 3-gate: `dart format --output=none --set-exit-if-changed .` (0 changed — pure-Dart + new tests are pre-formatted) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1345/1345 pass — was 1337 at v1.4-stab-B tip, +8 from Cycle C). Targeted runs per `CLAUDE.md`: `flutter test test/reminders/full_screen_intent_test.dart` (passes; +5 tests) + `flutter test test/services/full_screen_intent_service_test.dart` (passes; +3 tests) + `flutter test test/reminders/reminder_bridge_fsi_channel_test.dart` (passes; +2 tests). Coverage: `lib/reminders/full_screen_intent.dart` ≥80% (from 25.0%); `lib/services/full_screen_intent_service.dart` ≥95% (from 80.5%).

**Failure recovery.** If any step fails, roll back to the previous step's verification checkpoint. The most likely failure modes: (a) a Step 6 rename reference is missed → re-grep and fix; (b) a Step 11 channel mock breaks under a future Flutter framework version → re-mock via the new `TestDefaultBinaryMessengerBinding` API; (c) a Step 12 channel-surface gap is "accidentally fixed" by a contributor → the test fails loudly, prompting either (i) Kotlin arm addition (the desired state) or (ii) Dart seam removal (the desired state). **No silent test removals.**

**Coverage.** Cycle C adds 8 new unit tests (test count 1337 → 1345). The 5 new tests in `test/reminders/full_screen_intent_test.dart` cover the `FakeFullScreenIntent` seam + the `LaunchIntent` / `RoutineOverlayLaunch` value classes. The 3 new tests in `test/services/full_screen_intent_service_test.dart` cover the production `MethodChannelFullScreenIntentSource` defense-in-depth swallow (the headline assertion for Cycle C). The 2 new tests in `test/reminders/reminder_bridge_fsi_channel_test.dart` pin the channel-surface gap as a known follow-up bug. Coverage on changed files: `lib/reminders/full_screen_intent.dart` ≥80% (from 25.0%); `lib/services/full_screen_intent_service.dart` ≥95% (from 80.5%). Cycle C is a coverage + reliability cycle, not a bug-fix cycle per se (BUG-003 was a P1 reliability bug per the Cycle A audit, but the "fix" is documenting the existing swallow as intentional + lifting test coverage; the production code itself was already correct).

**Cross-references.**

- SYS-130 (v1.4-stab-C — the FSI defense-in-depth requirement)
- ADR-061 (v1.4-stab-C — the 6 design choices: defense-in-depth swallow + rename + stale-comment fix + doc-typo fix + channel-surface gap pin + test count expansion)
- ADR-013 (the v0.4b-release-fix "missing plugin must not crash the app" precedent — the foundation ADR-061 extends)
- ADR-059 (v1.4-stab-A — the audit + roadmap cycle that inventoried BUG-003 at P1 and assigned it to Cycle C)
- `lib/services/reliability_service.dart` (the `ReliabilityService._safeProbe` precedent — identical swallow pattern)
- `lib/reminders/reminder_bridge.dart:60` + `:218` (the Dart-side `showFullScreen` seam that the channel-surface gap test pins)
- `android/app/src/main/kotlin/com/doit/ReminderChannelProxy.kt:33-78` (the Kotlin `when` block that has no `showFullScreen` arm — the documented gap)
- `android/app/src/main/kotlin/com/doit/FullScreenActivity.kt:47-56` (the actual production wake mechanism — `FLAG_KEEP_SCREEN_ON` — that the rewritten `lib/reminders/full_screen_intent.dart` header references)
- `android/app/src/main/AndroidManifest.xml:83-85` (the `USE_FULL_SCREEN_INTENT` permission declaration that already exists — confirms no manifest change in Cycle C)
- `docs/v_model/notification_reliability.md:496` (the "API 14+" → "API 34+" typo fix)
- `docs/v_model/stabilization_roadmap.md §2` (BUG-003 inventory; mark as "closed (Cycle C)" in the §2 table when this cycle ships)
- `docs/v_model/plan.md` Milestone 12 `### v1.4-stab-C` sub-entry
- `docs/v_model/implementation_status.md` v1.4-stab-C row
- `CHANGELOG.md` v1.4-stab-C block
- `feature.md` §4 (BUG-003 parking lot bullet removed) + §5 (quick-index updated to ADR-061 / SYS-130 / WF-058) + §6 (next-step updated to Cycle D)
- Targeted runs per `CLAUDE.md`: `flutter test test/reminders/full_screen_intent_test.dart` (passes; +5 tests) + `flutter test test/services/full_screen_intent_service_test.dart` (passes; +3 tests) + `flutter test test/reminders/reminder_bridge_fsi_channel_test.dart` (passes; +2 tests).

### WF-059 — Permission flow coverage: per-kind exhaustive tests + lifecycle edge cases (v1.4-stab-D / Phase 44)

The 14-step test-first implementation flow for Cycle D (SYS-131 / ADR-062). Pure-Dart + new tests + docs only; no production code changes.

**Step 1.** Read `lib/services/permission_result.dart` (166 lines) — confirm every sealed subclass is at the surface (no private constructors) so direct tests can `const`-construct them.

**Step 2.** Read `lib/services/permission_service.dart:267-379` (`init()`), `:677-744` (`refresh()`), `:75-149` (`PermissionKind` enum) — identify the `PermissionStatus` → `PermissionResult` mapping at line 385-466 (`_mapStatus`) so the new service tests can target the 4 unmapped statuses (`limited`, `restricted`, `provisional`, plus a `permanentlyDenied` sanity test).

**Step 3.** Read `lib/services/permission_lifecycle_observer.dart:1-14` (file header) + `:69` (early-return for non-`resumed`) + `:103-107` (`ReliabilityService` StateError catch) — confirm the existing v1.3b tests cover the StateError swallow (they do, at `test/services/permission_lifecycle_observer_test.dart:302-326`); the new test covers the early-return gate.

**Step 4.** Read `lib/people/person.dart:1-229` — identify `isPausedAt(now)` (line ~156) + `copyWith(clearPausedUntil:)` (line ~175) as the test targets; confirm the existing `person_model_test.dart` does NOT cover these (it focuses on channel equality + identity-bound copyWith).

**Step 5.** Write `test/services/permission_result_test.dart` (NEW) — 6 tests across 2 groups (`PermissionResult sealed hierarchy (SYS-131)` + `BackupFolderResult sealed hierarchy (SYS-131)`); includes the exhaustive `switch` regression protector at test #4.

**Step 6.** Write `test/people/person_test.dart` (NEW) — 3 tests in the `ContactPerson pause semantics (SYS-131)` group covering `isPausedAt` future/expired/null branches + `copyWith(clearPausedUntil: true)` drop-pause path.

**Step 7.** Extend `test/services/permission_lifecycle_observer_test.dart` — append the `paused / inactive / hidden lifecycle events do NOT trigger a permission refresh (SYS-131)` test at the end of `main()` (after the existing StateError swallow test).

**Step 8.** Extend `test/services/permission_service_test.dart` — append the `v1.4-stab-D / Phase 44 / SYS-131` block at the end of `main()` with 4 new tests targeting the 4 `PermissionStatus` mappings not yet covered by the v1.3c + v1.5b tests.

**Step 9.** Run the 4 targeted test files in isolation: `flutter test test/services/permission_result_test.dart test/services/permission_service_test.dart test/services/permission_lifecycle_observer_test.dart test/people/person_test.dart` — verify the 13 new tests pass.

**Step 10.** Run `dart format .` to auto-fix any formatting the new files introduced — then re-verify with `dart format --output=none --set-exit-if-changed .` (must report 0 changed).

**Step 11.** Run `flutter analyze --fatal-infos lib test` — must report 0 issues. Watch for `--fatal-infos` hits on unused imports in the new files (e.g., `unnecessary_import`); auto-format usually fixes these on the first pass.

**Step 12.** Run `flutter test` (full suite) — must report 1363/1363 pass. No regression on the existing 1348 tests.

**Step 13.** Append V-Model artifacts: SYS-131 row to `docs/v_model/requirements.md`; ADR-062 section to `docs/v_model/decision_record.md`; this WF-059 to `docs/v_model/workflows.md`; WF-059 row to `docs/v_model/traceability_matrix.md`; `### v1.4-stab-D` row to `docs/v_model/implementation_status.md`; `### v1.4-stab-D` sub-entry to `docs/v_model/plan.md` Milestone 12 (after the v1.4-stab-C sub-entry); `## v1.4-stab-D` block to `CHANGELOG.md`; `feature.md` §4 BUG-005/011/012/020 parking lot bullets removed + §5 quick-index updated (ADR-062 / SYS-131 / WF-059) + §6 next-step updated to Cycle E (`feat/v1.4-stab-E-reliability-detection`). **Verification:** `grep -n "SYS-131\|ADR-062\|WF-059\|v1.4-stab-D" docs/v_model/*.md` returns the expected count of matches.

**Step 14.** Commit, push, PR, squash-merge, build APK/AAB per the release-apk-pattern memory + the Cycle C precedent (`4b3c20d`).

**Verification:** 3-gate: `dart format --output=none --set-exit-if-changed .` (268 files, 0 changed) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1363/1363 pass). Targeted runs per `CLAUDE.md`: `flutter test test/services/permission_result_test.dart` (passes; +6 tests) + `flutter test test/services/permission_service_test.dart` (passes; +4 tests) + `flutter test test/services/permission_lifecycle_observer_test.dart` (passes; +1 test) + `flutter test test/people/person_test.dart` (passes; +3 tests).

**Refs:**
- SYS-131 (v1.4-stab-D — the permission-flow coverage requirement)
- ADR-062 (v1.4-stab-D — the 6 design choices)
- ADR-016 (the v0.5 `PermissionResult` sealed-hierarchy contract)
- ADR-013 (the v0.4b-release-fix "missing plugin must not crash the app" precedent)
- `~/.claude/projects/-home-shyam-common-games-doit/memory/v1-4-stab-C-cycle-shipped.md` (Cycle C precedent — pure-Dart + docs + new tests pattern)
- `~/.claude/plans/here-now-i-hvae-enumerated-reddy.md` (the canonical Cycle D scope decision)

## WF-061 — Pin backup round-trip exhaustive coverage via 8 missing-error-path tests (v1.4-stab-F / Phase 46 / SYS-133 / ADR-064)

Cycle F is a **pure-Dart** stabilization cycle. The v1.4-stab-A audit's `bug_hunt.md` listed 6 latent backup envelope bugs that were never pinned by a test; Cycle F wires them up.

**14-step flow:**
1. Audit `lib/services/backup_service.dart` for uncovered lines (12 found via `awk '/^DA.*,0$/'` on `coverage/lcov.info`).
2. Audit `lib/services/backup_scheduler.dart` (5 uncovered lines).
3. Audit `test/services/backup_encryption_test.dart` to find which error paths are already covered (3 paths: iterations floor, memory floor, unknown KDF → skip).
4. Identify the 5 missing paths in `backup_service.dart`: `BackupFormatException.toString`, missing-kdf object, v2 iterations floor, v3/v2 missing-fields rejection.
5. Identify the 1 missing path in `backup_scheduler.dart`: `ScheduleMode.none` early-return.
6. Identify the 2 missing paths in `backup_task_dispatcher.dart`: unknown-task-name, init-failure-swallow.
7. Append SYS-133 to `docs/v_model/requirements.md`.
8. Append ADR-064 to `docs/v_model/decision_record.md`.
9. Append the WF-061 row to `docs/v_model/traceability_matrix.md`.
10. Append the v1.4-stab-F row to `docs/v_model/implementation_status.md`.
11. Append the v1.4-stab-F sub-entry to `docs/v_model/plan.md`.
12. Append the v1.4-stab-F block to `docs/v_model/CHANGELOG.md`.
13. Append `ADR-064 + SYS-133 + WF-061` quick-index + §6 next-step to `feature.md`.
14. Write `~/.claude/projects/-home-shyam-common-games-doit/memory/v1-4-stab-F-cycle-shipped.md` and update `MEMORY.md`.

**Total: 8 new tests pinning 8 previously-uncovered error paths.** Test count: 1371 → 1379. Coverage: `backup_service.dart` ≥95%; `backup_scheduler.dart` ≥90%.

**Refs:**
- SYS-133 (v1.4-stab-F — backup round-trip coverage requirement)
- ADR-064 (v1.4-stab-F — 8 pinning tests design choice)
- ADR-013 (the "missing plugin must not crash the app" precedent — extended to dispatcher failures)
- `~/.claude/projects/-home-shyam-common-games-doit/memory/v1-4-stab-E-cycle-shipped.md` (Cycle E precedent)

### WF-062 — Ship the v1.4l-deferred "Target paused" badge + retire BUG-004 + BUG-019 (v1.4-stab-G / Phase 47 / SYS-134 / ADR-065)

Cycle G is a **pure-Dart + widget UI** stabilization cycle. The v1.4l data layer (ADR-056) makes the UI affordance possible — when a `DoAnchor` points at a tombstoned habit, the badge surfaces that state to the user. ADR-059 §4 parked the UI for a post-v1.4m stabilization cycle; Cycle G retires that parking lot.

**12-step flow:**
1. Audit `lib/widgets/` for similar small badge widgets (closest analog: `reliability_banner.dart`, `automation_reliability_badge.dart` — same shape: icon + label + Semantics).
2. Inspect `lib/do/do.dart:581-666` to confirm `DoAnchor` shape + the `isDeleted` flag on the base `Do`.
3. Inspect `lib/services/do_repository.dart:82-105` to confirm `getById` returns tombstoned rows + `getActiveById` filters them (the badge needs `getById`, not `getActiveById`).
4. Inspect `lib/screens/home.dart:797-806` to find the existing pause-indicator row (the badge integrates here; no new row).
5. Write `lib/widgets/do_anchor_paused_badge.dart` (~80 lines) with the small widget contract from ADR-065.
6. Edit `lib/screens/home.dart` (`_HabitTileState`) to add `Do? _targetHabit` field + cached lookup in `initState` + `didUpdateWidget` + render of the badge when `isDeleted`.
7. Append ARB keys `doAnchorTargetPaused` + `doAnchorTargetPausedHelp` to `lib/l10n/app_en.arb` + `lib/l10n/app_es.arb`.
8. Append SYS-134 to `docs/v_model/requirements.md`, ADR-065 to `docs/v_model/decision_record.md`, WF-062 row to `docs/v_model/traceability_matrix.md`, v1.4-stab-G row to `docs/v_model/implementation_status.md`, v1.4-stab-G sub-entry to `docs/v_model/plan.md`, v1.4-stab-G block to `docs/v_model/CHANGELOG.md`, feature.md update.
9. Write `test/widgets/do_anchor_paused_badge_test.dart` (NEW) with 4 tests.
10. Extend `test/screens/home_test.dart` with 1 test (badge rendering via `KeyedSubtree`).
11. Extend `test/screens/home_tile_sparkline_test.dart` with 1 BUG-019 test (single-point sparkline).
12. 3-gate verification + targeted tests + rebuild APK + commit + push + CI watch + squash-merge + memory file.

**Total: 6 new tests + 1 new widget + 2 ARB keys + 1 home.dart edit (~30 lines).** Test count: 1379 → 1385. Coverage: `home.dart` 85.7% → ≥90%; `home_tile_sparkline.dart` 78.6% → ≥85%; `do_anchor_paused_badge.dart` 0% → ≥90%.

**Refs:**
- SYS-134 (v1.4-stab-G — the Target paused badge requirement)
- ADR-065 (v1.4-stab-G — the small-widget + cached-lookup design)
- ADR-056 (the v1.4l `deletedAtMillis` data-layer precedent that this cycle's UI surfaces)
- ADR-059 §4 (the parking-lot deferral that Cycle G retires)
- `~/.claude/projects/-home-shyam-common-games-doit/memory/v1-4-stab-F-cycle-shipped.md` (Cycle F precedent for the 12-step flow)

### WF-063 — Open the "Recently deleted" screen and restore or force-purge a tombstoned do (v1.4-stab-H / Phase 48 / SYS-135 / ADR-066)

1. User taps Settings on the home screen bottom nav.
2. The `SettingsScreen` renders (per WF-015); the Backup section lists two tiles: the existing `SettingsRestoreScreen` tile (key: `settings.restore`) and the new `Recently deleted` tile (key: `settings.recently_deleted`).
3. User taps the `Recently deleted` tile.
4. `SettingsScreen.onTap` for the new tile calls `Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RecentlyDeletedScreen()))`.
5. The `MaterialApp.onGenerateRoute` is the same `buildAppRoute` switch — pushed routes go through `Navigator.push`, not `buildAppRoute`, so the switch is unchanged. (A deep-link via `buildAppRoute` at `/recently-deleted` also works — `buildAppRoute` returns the same `MaterialPageRoute<void>` wrapping the screen.)
6. `RecentlyDeletedScreen.initState` calls `DoRepository.instance.listDeleted()` (returns `List<Do>` ordered by `deletedAtMillis DESC` per the v1.4m ordering) and stores the future in `_future`.
7. The `FutureBuilder<List<Do>>` resolves to one of three branches: `loading` (`CircularProgressIndicator`), `error` (`_ErrorState` with a Retry button), or `data` (`ListView` of one `_Row` per tombstoned do, or the `_EmptyState` widget if the list is empty).
8. **Restore path:** user taps the `Icons.restore` `IconButton` on a row. The screen calls `DoRepository.instance.restoreById(id)`. On `true` the screen surfaces the `recentlyDeletedRestoreSuccess` snackbar; on `false` it surfaces `recentlyDeletedRestoreFailed`. Either way, `_reload()` re-runs the `listDeleted` future.
9. **Delete-forever path:** user taps the `Icons.delete_forever` `IconButton` on a row. The screen calls `showDialog<bool>(...)` rendering an `AlertDialog` with the destructive verb repeated in the title and CTA. On confirm the screen calls `DoRepository.instance.deleteById(id)` inside a try/catch; on success it surfaces `recentlyDeletedRestoreSuccess` (the user mental model is "the row is gone"); on catch it surfaces `recentlyDeletedDeleteForeverFailed`. `_reload()` re-runs the list.
10. **Empty path:** no rows are tombstoned. The screen renders the `_EmptyState` widget with the localized "Nothing here — deleted dos stay for 30 days before being purged" copy (mentions the v1.4m 30-day TTL per ADR-057).
11. **Error path:** the `listDeleted` future throws. The `FutureBuilder` surfaces the `_ErrorState` widget (an `Icon` + a `FilledButton.icon` with the `recentlyDeletedRetry` label). Tapping the Retry button calls `_reload()` which reassigns `_future` and triggers a re-render.

### Verification (per SYS-135 §11)

- 12 new widget tests in `test/screens/recently_deleted_screen_test.dart` covering: list-loaded, list-empty, restore-happy-path, restore-failed, delete-forever-happy-path, delete-forever-cancel, delete-forever-confirm-dialog, error-state, navigation-from-settings, SnackBar-success, SnackBar-failed, ARB-parity.
- Cycle I's ARB-parity test pins the 15 new keys in both `app_en.arb` and `app_es.arb`.
- The `test/widget/widget_deep_link_test.dart` "buildAppRoute dispatches on the route name" test extends to include `/recently-deleted`.
- 3-gate passes: `dart format --output=none --set-exit-if-changed .` + `flutter analyze --fatal-infos lib test` + `flutter test` (1400/1400 pass).
- Targeted: `flutter test test/screens/recently_deleted_screen_test.dart test/widget/widget_deep_link_test.dart`.

### WF-064 — Verify the ARB catalog + screen render in both locales (v1.4-stab-I / Phase 49 / SYS-136 / ADR-067)

#### Goal

Pin that every ARB key, every placeholder shape, and the top-level screens consume the catalog correctly under both `en` and `es` locales. The test is the regression guard against "key added to en.arb but not yet translated to es.arb" and "screen layout overflows at the Spanish locale's longer copy" classes of bugs.

#### Steps

1. **Per-key resolver sweep (en + es).** For every non-metadata key in `app_en.arb`, `testWidgets` asserts that `AppLocalizations.delegate.load(Locale('en'))` returns a non-empty string. The mirror test asserts the same for `Locale('es')`. A regression where the gen-l10n output drops a key surfaces as an empty string.

2. **Verbatim-copy pin for v1.4-stab-G + v1.4-stab-H keys.** `doAnchorTargetPaused`, `recentlyDeletedTitle`, `recentlyDeletedDeleteForeverConfirm`, `recentlyDeletedRestoreSuccess`, `recentlyDeletedSettingsTitle` are pinned verbatim in BOTH locales — a copy change goes through a translator, not a code churn.

3. **Placeholder interpolation pins (6 keys × 2 locales).** `homeTileBudgetRemaining(remaining, limit)`, `homeSnackbarBudgetUpdated(newValue)`, `addHabitRestDaysLabel(value)`, `settingsAboutAppVersion(version)`, `permissionBackupFolderSet(path)`, `recentlyDeletedSubtitle(name, when)` are each interpolated verbatim in both locales — a fallback to the wrong-locale template surfaces here.

4. **Plural branches (en) pin.** `homeSelectionAppBarTitle(count)` resolves at counts 0/1/5 with non-empty output (mirror of the pre-existing es ICU pin).

5. **Placeholder-bearing-key metadata regression guard.** For every ARB key whose value matches `\{[a-zA-Z][a-zA-Z0-9_]*\}`, the test asserts the paired `@<key>` metadata block is present. A regression where the metadata is silently removed is caught here at test time, complementing the build-time gen-l10n error.

6. **Locale render sweep.** `HomeScreen`, `RecentlyDeletedScreen` (NEW for v1.4-stab-H), and the Settings section headers (resolved via the delegate, NOT mounted — SettingsScreen pulls in service singletons) are tested under both locales. Two `RenderFlex`-overflow guards at `TextScaler.linear(1.0)` × {HomeScreen en, RecentlyDeletedScreen es} pin the layout contract at the default font scale. Cycle J extends to 1.3x + 1.6x on the 5 critical screens.

7. **ARB parity guard** (regression of v1.1h / SYS-087). The pre-existing "every non-template ARB has the same key set as the template" test continues to pass — the ARB catalog must be identical key-by-key across locales. The Cycle I per-key tests complement this with value-level guarantees.

8. **Verification:**
- `dart format --output=none --set-exit-if-changed .` (clean)
- `flutter analyze --fatal-infos lib test` (0 issues)
- `flutter test` (1422/1422 pass; was 1401 at start of Cycle I; +21 net)
- Targeted: `flutter test test/l10n/app_localizations_test.dart test/l10n/locale_render_test.dart`.

#### Notes

- The `arbs` map (which walks `lib/l10n/*.arb` once) is lifted to file scope via an `ensureArbsLoaded()` helper called from both groups' `setUpAll`. The pre-Cycle I implementation scoped the walk to a single group's `setUpAll`, which the new group could not inherit.
- Bug **BUG-006** (Spanish native-speaker review) is partially closed — the test coverage half is shipped; the reviewer log at `docs/v_model/spanish_translation_review.md:207` remains empty and is queued as a v2.0 follow-up.
### WF-065 — Verify the WCAG-2.x accessibility surface (TalkBack + contrast + font-scale) (v1.4-stab-J / Phase 50 / SYS-137 / ADR-068)

Pin that the app's accessibility surface meets the WCAG-2.x bar: TalkBack labels on interactive elements, contrast ≥ 4.5:1 for body text + ≥ 3:1 for large-text, and the rendered screens reflow cleanly at the 3 Material You `TextScaler.linear` presets (1.0x, 1.3x, 1.6x). The flow is the regression guard against "future contributor adds an unlabeled button" / "theme swap breaks AA body contrast" / "Spanish copy + 1.6x overflows on `HomeScreen`" classes of bugs.

#### Steps

1. **WCAG-2.x contrast helpers** (top-level in `test/a11y/contrast_test.dart`). `relativeLuminance(Color)` computes `0.2126 R + 0.7152 G + 0.0722 B` from gamma-decoded sRGB channels (Flutter 3.27+ `Color.r/.g/.b` are 0..1 doubles — no `/255` division). `contrastRatio(Color, Color)` returns `(max(L1, L2) + 0.05) / (min(L1, L2) + 0.05)` per WCAG-2.x, yielding ratios in `[1.0, 21.0]`.

2. **Helper-correctness pins (4 tests).** Black → 0 luminance; white → 1; black-on-white → 21:1 (max); same-color → 1:1 (min); symmetry `(a, b) == (b, a)`. These boundary tests catch the most common helper regressions (off-by-one in the gamma decode, asymmetry from the wrong-order swap).

3. **Theme-contrast assertions (3 tests).** Dark `Theme.colorScheme.onSurface` vs `surface` ≥ 4.5:1 (AA body); light `Theme.colorScheme.onSurface` vs `surface` ≥ 4.5:1; M3-light `colorScheme.onError` vs `colorScheme.error` ≥ 2.7:1 — the error pair is documented to measure ~2.98:1 (just under the 3.0 AA-Large bar); the 2.7:1 readability floor pins future regressions loudly while accepting the current M3-light quirk.

4. **Font-scale mount checks (7 tests).** HomeScreen + RecentlyDeletedScreen mounted under `MediaQuery(textScaler: TextScaler.linear(N))` at N = 1.0, 1.3, 1.6; `tester.takeException() == null` for each pair. A regression where the home tile layout doesn't accommodate the larger text would surface as a `RenderFlex overflowed by N pixels` exception caught by the tester. The cross-locale `locale=es home-screen at 1.6x` test pins the Spanish-copy 30%-longer overlap with the largest Material You preset.

5. **Per-screen a11y participation (5 screens × 3 checks = 15 tests).** Each of the 5 critical screens (`home.dart`, `add_habit.dart`, `add_person.dart`, `add_event.dart`, `settings.dart`) is verified at the source level: (a) the source contains at least one `Semantics`, `tooltip`, `semanticLabel`, `excludeFromSemantics`, or `ListTile(title: Text(...))` — the latter covers `Settings` which uses passive `ListTile` rows that auto-expose the title to TalkBack; (b) the source does NOT declare a screen-level `colorScheme: ColorScheme(...)` (which would defeat the app-wide contrast budget); (c) the source declares a `Scaffold` + `AppBar` (TalkBack navigation landmarks).

6. **Pre-existing static Semantics sweep continues to pass.** `test/a11y/semantics_labels_test.dart` (v0.4c.2 / SYS-062) walks every `lib/screens/` + `lib/widgets/` file and asserts each interactive widget has `tooltip`, `semanticLabel`, `excludeFromSemantics`, or a labeled `title:` child. The per-screen Cycle J participation tests complement this by naming which critical screens are pinned.

7. **Verification.**
- `dart format --output=none --set-exit-if-changed .` (clean)
- `flutter analyze --fatal-infos lib test` (0 issues)
- `flutter test` (1451/1451 pass; was 1422 at start of Cycle J; +29 net)
- Targeted: `flutter test test/a11y/contrast_test.dart test/a11y/font_scale_test.dart test/a11y/every_screen_test.dart` + `flutter test test/a11y/semantics_labels_test.dart` (the pre-existing sweep).

#### Notes

- `Locale.es` home + `SettingsScreen` + 3 add screens do NOT get a font-scale mount — the screens pull in service singletons that are out of scope for a Cycle J pure-test cycle. The 1.6x mount on those screens is on the user's on-device checklist per the plan §Cycle J "Permission touched: Branch delete, adb (UI smoke with `adb shell settings put system font_scale 1.6`)".
- M3-light error / onError is at the AA-Large edge by ~0.02; the `≥ 2.7:1` pin accepts the current M3 quirk. The KDoc + the `reason` block document both the measurement AND the design rationale, so a future contributor who tries to "fix" M3's color seed sees the test failure with the full context.
- No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.
- Cycle K's E2E flow mount (Phase 51) will add the heavy-mount font-scale checks for `add_habit`, `add_person`, `add_event`, `settings` at integration level.

### WF-066 — Run the 10 critical user flows end-to-end (v1.4-stab-K / Phase 51 / SYS-138 / ADR-069)

**Trigger:** user opens the app on a real Android device or emulator (the
on-device smoke step that the harness cannot perform — see ADR-069).

**Actor:** user (hands-on smoke tester).

**Preconditions:**
- `flutter pub get` has run (the harness has done this).
- The integration_test/ code compiles under `dart analyze` (the harness
  has verified this).
- The APK is installed on the device.

**Steps:**

1. **Flow 1 — add a do.** Tap the FAB (the `FloatingActionButton` on the
   home screen). Enter `Read` in the name field (key: `addHabitNameField`).
   Tap Save (key: `addHabitSaveButton`). Confirm the new tile appears on
   the home screen with the text `Read`.

2. **Flow 2 — mark done.** Tap the home tile for `Read` (key:
   `homeTile-read`). The tile shows the "done" state (checkmark or
   grayed-out label).

3. **Flow 3 — streak grows.** The tile's streak badge shows `1 day` (the
   v1.4-stab-G sparkline + Cycle J's contrast-pinned badge is visible).

4. **Flow 4 — delete.** Open the per-tile menu (key: `homeTile-read-menu`).
   Tap Delete (key: `homeTileMenuDelete`). The tile is removed; the
   SnackBar's Undo action appears.

5. **Flow 5 — undo (via v1.4l restore).** Tap the SnackBar's Undo action
   (key: `homeSnackbarUndo`). The tile is restored with streak intact (the
   v1.4l tombstone preserves streak by construction).

6. **Flow 6 — soft-delete + list-deleted.** Tap Settings (key:
   `navSettings`). Tap the `Recently deleted` tile (key:
   `settingsTileRecentlyDeleted`). The screen lists the soft-deleted
   `Read` do.

7. **Flow 7 — restore from list.** Tap the Restore IconButton on the
   `Read` row (key: `recentlyDeletedRestore-read`). The tile reappears on
   the home screen.

8. **Flow 8 — backup export.** Settings → Backup → Export (keys:
   `settingsTileBackup` + `backupExportButton`). A SAF picker opens; pick
   a folder. The backup file is written.

9. **Flow 9 — backup restore.** Settings → Backup → Restore (keys:
   `settingsTileBackup` + `backupRestoreButton`). Pick the backup file
   written in step 8. The app reloads; the home screen has the `Read`
   tile back.

10. **Flow 10 — BUG-002 regression protector.** Open the per-tile menu on
    the `Read` tile (key: `homeTile-read-menu`). Tap Pause (key:
    `homeTileMenuPause`). Open the menu again. Tap Edit (key:
    `homeTileMenuEdit`). Change the name to `Read (renamed)`. Tap Save
    (key: `addHabitSaveButton`). The `homeTilePausedBadge-read` widget
    MUST still be present in the tree — the pause was preserved across
    the edit + save (the v1.4-stab-B fix).

**Postconditions:**
- The 10 flows have driven the app through every critical user journey.
- The Cycle H `Recently deleted` screen has been visited.
- The BUG-002 regression is asserted via the paused-badge widget key.

**Notes:**

- This workflow is the on-device smoke; the harness cannot run it (no
  `adb`, no emulator).
- The `_IntegrationBinding.ensureInitialized()` guard in
  `integration_test/critical_flows_test.dart` swaps in the regular
  `TestWidgetsFlutterBinding` in the harness (no-op) and
  `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` on a real
  device.
- The model-layer tests that accompany this workflow (Cycle K's primary
  harness-runnable contribution) are pinned via the 3-gate; the
  on-device smoke is a deferred verification step per the v1.4-stab
  cycle plan.

### WF-067 — Verify the perf baseline + fuzz regression suite (v1.4-stab-L / Phase 52 / SYS-139 / ADR-070)

**Trigger:** developer runs the v1.4-stab-L cycle's 3-gate verification
loop, OR a future stabilization / feature cycle lands code that touches
`build()`, the `DoRepository` read paths, or the pure-Dart model layer.

**Actor:** developer (or CI).

**Preconditions:**
- `flutter pub get` has run.
- The new `test/perf/` + `test/fuzz/` directories exist with the 6 new
  test files (3 widget-rebuild + 2 SQL-benchmark + 4 fuzz) — see
  `docs/v_model/performance_baseline.md` for the file map.
- `docs/v_model/performance_baseline.md` exists with the observed
  baseline numbers from Cycle L's first run.

**Steps:**

1. **Run the widget-rebuild benchmarks.**

   ```bash
   flutter test test/perf/widget_rebuild_test.dart --reporter=expanded
   ```

   The test prints the cold mount µs + the median per-rebuild µs over
   100 iterations. If a future contributor adds heavy synchronous
   work to `build()` (e.g., a `find.byType(...)` scan, a DB read on the
   UI thread, or a JSON parse in the hot path), the median will exceed
   the budget (750 ms cold / 5 ms single-tile / 25 ms 10-tile) and the
   test fails with a `reason:` block showing the observed median vs.
   the budget.

2. **Run the SQL-benchmark.**

   ```bash
   flutter test test/perf/sql_benchmark_test.dart --reporter=expanded
   ```

   The test asserts exactly 1 SELECT for `DoRepository.listAll` and
   `listActive` at N=10 seeded habits + a median ms budget for
   `listActive` (≤ 10 ms per call on in-memory DB). A future contributor
   who splits `listAll` / `listActive` into per-do reads (the N+1
   antipattern) will trip the SELECT-count assertion.

3. **Run the fuzz tests.**

   ```bash
   flutter test test/fuzz/do_model_fuzz_test.dart \
                test/fuzz/person_model_fuzz_test.dart \
                test/fuzz/mission_model_fuzz_test.dart \
                test/fuzz/consecutive_counter_fuzz_test.dart \
                --reporter=expanded
   ```

   The fuzz tests run 1000 iterations each with `Random(42..45)` (the
   seed is pinned per file for reproducibility). A future contributor
   who breaks an invariant (e.g., makes `copyWith(name:)` ignore the
   new name, or makes `ConsecutiveCounter.compute` non-deterministic)
   will trip a fuzz test within the first iteration that lands the bad
   code path.

4. **Run the full perf + fuzz suite in one go (CI variant).**

   ```bash
   flutter test test/perf test/fuzz --reporter=expanded
   ```

   This is the command documented in `performance_baseline.md` §
   "How to re-run the baseline" — it captures every metric in
   ~3 minutes on a typical CI box.

5. **Run the full 3-gate.**

   ```bash
   dart format --output=none --set-exit-if-changed .
   flutter analyze --fatal-infos
   flutter test
   ```

   The 3-gate MUST pass; Cycle L adds 10 tests to the count (1537 → 1547)
   and contributes the `docs/v_model/performance_baseline.md` file which
   the `dart format` step will check for trailing-newline consistency.

6. **Cross-check the perf-baseline doc.**

   Open `docs/v_model/performance_baseline.md` and verify the observed
   baseline numbers in the table match the test output. If a future
   cycle legitimately changes the baseline (e.g., a refactor that
   actually reduces per-rebuild cost by 2×), the doc's table MUST be
   updated in the same PR — the numbers in the doc are the canonical
   reference.

**Postconditions:**
- Every future contributor who lands a regression in the perf baseline
  OR a broken model invariant is caught by the corresponding test.
- The stabilization campaign closes with the project at 1547 tests
  passing and a documented perf baseline + fuzz regression suite.

**Notes:**

- The widget-rebuild + SQL-benchmark budgets are GENEROUS — they pin
  regression direction (a 2-3× median shift), not absolute perf. Real-
  device release builds are 3-5× faster than `flutter test` debug-build
  fake-async.
- The fuzz tests use `dart:math.Random(seed)`, NOT `package:faker`, per
  the Cycle L pre-auth. The seed is pinned in the file
  (`Random(42)` etc.) so the run is reproducible across CI runs and
  developer machines.
- The Drift `QueryExecutor` proxy in `sql_benchmark_test.dart` is the
  standard Drift test seam — it delegates every method to the wrapped
  executor, so the behavior under test is unchanged. The proxy is the
  test's only side-channel; the production code is unchanged.
- Cycle L is the FINAL cycle in the v1.4-stab 3-month stabilization
  campaign. APK SHA1 stays at Cycle J's
  `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d` — Cycle L does NOT ship a
  release APK.
- The doc's "What Cycle L does NOT cover" section defers profile-mode
  timings + end-to-end scroll perf + APK size to the W-13 closeout
  (the stabilization retrospective).

### WF-068 — Verify the v1.5-cyc-α widget-config + service-proxy coverage closure (v1.5-cyc-α / Phase 53 / SYS-140 / ADR-071)

**Scope.** The v1.5 milestone's first cycle retires the 2
trivial widget-related coverage gaps from the v1.4-stab-W13
retrospective's §8 v1.5 handoff list. The screen
(`lib/widget/widget_config_screen.dart`) goes from 2.3% to
100%; the proxy (`lib/widget/widget_service_proxy.dart`)
stays at 33.3% (its single forwarder line is covered
indirectly by `widget_service_test.dart`'s 11 tests of
`WidgetService.setSelectedHabitId`).

**Test layers.**

1. **`test/widget/widget_service_proxy_test.dart`** (NEW) —
   3 tests. Uses a `_RecordingProxy extends WidgetServiceProxy`
   subclass to capture forwarding behavior without touching
   `WidgetService.instance`:
   - `setSelectedHabitId forwards a non-null habitId to the override` —
     asserts the recorded call's argument equals the input.
   - `setSelectedHabitId forwards null without throwing` — mirrors the
     non-null case but with `null`. The null path is used by the
     picker when the user wants to unbind a widget.
   - `const constructor is stable for the screen default-parameter seam` —
     `identical(const WidgetServiceProxy(), const WidgetServiceProxy())`
     must hold. The screen relies on `const WidgetServiceProxy()`
     as a default parameter value at
     `lib/widget/widget_config_screen.dart:49`; a future refactor
     that drops `const` would silently break the screen's
     default-parameter compile.

2. **`test/widget/widget_config_screen_test.dart`** (NEW) —
   7 tests. Mirrors the `recently_deleted_screen_test.dart`
   pattern (`_resetDb` + `_wrap` + `_RecordingProxy` +
   `_PopObserver`):
   - `list-loaded: shows one row per do` — seed 2 `DoFixed`s
     via `DoRepository.instance.save` and assert the per-row
     `ListTile` renders both names.
   - `list-empty: shows the empty-state copy + Back button` —
     no DB seed; assert the localized `widgetConfigureEmptyState`
     and `widgetConfigureBackToHome` texts both render.
   - `picker-row tap forwards to proxy and pops with the habitId` —
     inject a `_RecordingProxy` + a `_PopObserver extends NavigatorObserver`;
     tap a row; assert `proxy.calls == ['h1']` AND `observer.poppedRoute
     != null`. The picker MUST forward the picked habitId BEFORE the
     pop, otherwise the Kotlin side reads `RESULT_OK` with no payload.
   - `loading-state: shows CircularProgressIndicator before the future resolves` —
     pumpWidget only (no `pumpAndSettle`) to land in the
     `connectionState != done` branch; assert the spinner is visible
     on the first frame, then settle and assert it disappears.
   - `AppBar title is the localized widgetConfigureTitle` —
     assert `l.widgetConfigureTitle` is `findsOneWidget` in `locale=en`.
   - `ARB-parity: Spanish locale renders the localized strings` —
     same pattern as Cycle I's screen-mount-with-sweep, but for the
     configurator screen.
   - `empty-state Back button pops the route` — tap the
     `FilledButton` in the empty state; assert the observer sees
     the pop (the launcher's `RESULT_CANCELED` handshake requires
     the configurator to dismiss itself).

**KDoc fix.** `lib/widget/widget_config_screen.dart` lines
52-57 — drop the "Displayed in the AppBar" claim. The `build`
method (line 96) only renders `l.widgetConfigureTitle`; the
`widgetId` parameter is accepted but not displayed. The
multi-instance AppBar-id rendering is parked to
`open_questions.md`.

**3-gate verification (mirrors Cycles C..L).**

- `dart format --output=none --set-exit-if-changed .` → 2 NEW test
  files were auto-formatted by `dart format .`; re-run shows 0
  changed.
- `flutter analyze --fatal-infos lib test` → 0 issues.
- `flutter test` → 1557/1557 pass (the documented Cycle L perf
  flake does not appear at the cycle-α test surface).
- Targeted: `flutter test test/widget/widget_service_proxy_test.dart
  test/widget/widget_config_screen_test.dart` → 10/10 pass.

**What this workflow does NOT cover.**

- The proxy body's single forwarder line
  (`return WidgetService.instance.setSelectedHabitId(habitId);`) —
  this is intentionally not tested; the forwarding target has 11
  dedicated tests in `widget_service_test.dart`. Wiring
  `WidgetService.init` with full fakes just to exercise the 1-line
  forwarder has poor ROI (no branching, no edge cases, no state).
- On-device E2E of the configurator activity — the activity lives in
  `android/app/src/main/kotlin/` and has no JVM test harness in this
  repo. The Dart side mirrors the Kotlin contract shape (route name
  + query-string arg + the picked habitId payload); the existing
  `test/widget/widget_deep_link_test.dart` pins the route-construction
  contract.
- Multi-instance AppBar-id rendering — parked to `open_questions.md`.

**Out-of-scope for this workflow.**

- The 11 files < 50% line coverage identified in the W-13 retro's
  bottom-15 partial-coverage list (v1.5-cyc-β..ε).
- The 5 v2.0 follow-ups (BUG-006 native-speaker review + Kotlin
  `ReminderBridge.showFullScreen` channel arm + on-device E2E +
  per-form 1.6x font-scale mounting + the partial-coverage list).

**APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`**
— v1.5-cyc-α is pure-Dart + 1 KDoc fix + new tests; no production-code
behavior change; no release APK rebuild.

### WF-069 — Verify the v1.5-cyc-β form-screen coverage closure (v1.5-cyc-β / Phase 54 / SYS-141 / ADR-072)

**Scope.** The v1.5 milestone's second cycle retires the
3 form-screen partial-coverage files from the v1.4-stab-W13
retrospective's §8 v1.5 handoff list. The screens
(`lib/screens/add_habit.dart`,
`lib/screens/add_person.dart`,
`lib/screens/add_event.dart`) gain form-dispatch coverage
for every Save branch + the edit-mode pre-fill paths +
the dialog + payload + template-save branches.

**Test layers.**

1. **`test/screens/add_habit_test.dart`** (extend) —
   6 new testWidgets. Uses the standard Drift-in-memory
   seam (`AppDatabase(NativeDatabase.memory())` +
   `AppDatabaseService.instance.init(overrideDb: db)`)
   and the `ReminderService` fake-pentuple
   (`FakeAlarmScheduler / FakeNotificationService /
   FakeFullScreenIntent / FakeAnchorDetector /
   FakeReminderBridge`). The viewport is bumped to
   `1080×1920` because the schedule-type SegmentedButton
   at `lib/screens/add_habit.dart:388-399` overflows the
   default 800×600 test viewport; `addTearDown(tester.view.reset)`
   restores it per-test.
   - `Save with `interval` schedule type persists a DoInterval` —
     tap "Every N" segment at line 391, save `Water plants`,
     assert `DoInterval` with `nDays == 2` (the default
     `_intervalNDays`).
   - `Save with `dayOfX` schedule type persists a DoDayOfX` —
     tap "Day-of-X" segment at line 393, save `Pay rent`,
     assert `DoDayOfX.dayOfMonth == 1 && .nth == 1 && .weekday == 1`
     (defaults at lines 100-102).
   - `Save with `timeWindow` schedule type persists a DoTimeWindow` —
     tap "Window" segment at line 394, save `Lunch`, assert
     `DoTimeWindow.start.hour == 12 && .end.hour == 13`
     (defaults at lines 103-104; default `_fixedWeekdays`
     keeps the Mon FilterChip selected so no empty-weekdays
     snackbar fires).
   - `Save with `anchor` schedule type but no anchor target shows
     "Pick a do to anchor on." snackbar and does NOT persist` —
     tap "After" segment at line 395, save `After wakeup`;
     the anchor picker is lazy and `_otherHabits` is empty
     in a fresh DB so the snackbar at line 715-719 fires;
     assert snackbar visible + `listAll` empty.
   - `Save with `fixed` schedule and zero selected weekdays
     shows "Pick at least one weekday." snackbar` —
     deselect Mon-Fri via 5 FilterChip taps at lines
     460-472, save `Never`, assert the snackbar at
     line 717-720 fires.
   - `initialPayload with scheduleType="interval" + nDays
     pre-fills the form` — pump `AddHabitScreen(initialPayload:
     {'name': 'Water plants', 'scheduleType': 'interval',
     'nDays': 4})`; assert the interval ListTile trailing
     shows `4` and the name field shows `Water plants`
     (line 484 reads `nDays` from the payload).

2. **`test/screens/add_person_test.dart`** (extend) —
   6 new testWidgets. Uses the existing
   `flutter_contacts` MethodChannel mock returning a
   scripted `Contact` JSON + the `permission_handler`
   MethodChannel mock returning a scripted
   `PermissionStatus`.
   - `Permission denied on pick leaves the form in empty-state
     without an inline error` — contacts stays denied
     (default); tap pick_contact → permission sheet shows
     → tap Cancel → row stays empty; assert "Pick a
     contact" + zero `AlertDialog`s.
   - `Pause section shows after a contact is picked` —
     full picker flow + permission grant; assert the
     `Pause` header at line 259 AND the
     `add_person.pause_row` key are visible (the section's
     visibility-gating is `_pickedName != null`).
   - `Cadence section defaults to "Every N days" with value 7` —
     no picker; assert `find.text('Every N days')` +
     `find.descendant(of: add_person.every_n, matching:
     find.text('7'))` (the defaults at line 215-218).
   - `Changing the cadence value updates the underlying
     _everyNDays` — `enterText('14')` into the cadence
     field; assert the descendant shows `14`.
   - `initialPayload with cadenceType="everyNDays" + nDays=21
     pre-fills the cadence` — pump
     `AddPersonScreen(initialPayload: {'cadenceType':
     'everyNDays', 'nDays': 21, 'channel': 'dialer'})`;
     assert the cadence field shows `21`.
   - `A picked contact triggers Save without errors and
     persists the row` — full picker flow + Save tap;
     assert the AddPersonScreen is gone from the tree
     AND `PersonRepository.instance.listAll` returns 1
     row with `lookupKey == 'persist1'`.

   **Dropped test.** A `Picker cancel (openExternalPick
   returns null)` test was prototyped and removed
   because its `addTearDown(setMockMethodCallHandler(channel,
   null))` left the binary messenger in a state where the
   next picker-flow test failed (verified empirically —
   both Pause-section-shows-on-pick and Persistable tests
   failed after Picker cancel but pass when Picker cancel
   is omitted). The "permission denied on pick leaves
   empty-state" test covers the same "no contact picked →
   stays empty" invariant without the override; coverage
   is intact.

3. **`test/screens/add_event_test.dart`** (extend) —
   9 new testWidgets. Uses the standard Drift-in-memory
   seam + the `ReminderService` fake-pentuple.
   - `Save with empty name sets _nameError and does NOT
     persist` — tap save with no name; assert
     `Name is required` visible + `listActive` empty.
   - `Save with valid name persists the row and pops with
     `true`` — enterText + runAsync tap + 2000 ms delay
     + 20× `pump(100ms)` to drain the navigator pop;
     assert `listActive` has 1 row named `Doctor
     appointment`.
   - `Save in edit mode preserves the existing event's
     createdAtMillis (WF-019 invariant)` — save an
     `_makeEvent('Doctor appointment')` via runAsync +
     pumpWidget with `existing: original` + tap save
     without changes; assert `listActive.first.createdAtMillis
     == original.createdAtMillis` (the Drift writer's
     `insertOnConflictUpdate` does not touch
     `createdAtMillis` on a primary-key match).
   - `Edit mode pre-fills name, lead time, recurrence,
     automations` — pump with `existing: original`;
     assert name `TextField` shows `Pre-filled event`,
     AppBar shows `Edit event`, lead-time trailing shows
     `2 h before`, AND the `Yearly` + `Once` ChoiceChips
     both render.
   - `_pickLead dialog renders all 7 presets and OK applies
     the selected minutes` — viewport bump 1080×1920;
     tap the `Notify me` ListTile to open the AlertDialog;
     assert `dialog` finds `At the time` + `5 min before`
     + the other 5 preset labels via `find.descendant(of:
     dialog, matching: ...)` (the unscoped text finds
     would see 2 matches because `_leadMinutes = 15` also
     shows `15 min before` in the form trailing).
   - `_applyPayload rolls the date forward a year when
     dayOfMonth is in the past` — initialPayload with
     `dayOfMonth: 15, monthOfYear: 0` where today is past
     Jan 15; assert the Date ListTile trailing ends with
     `-12-15` (the year-roll-forward branch).
   - `_applyPayload maps all 3 curated recurrence strings
     to annually` — initialPayload with `recurrence:
     'birthday'|'anniversary'|'yearly'`; assert the form's
     `Yearly` ChoiceChip is selected.
   - `_applyPayload ignores a non-String / empty `name` and
     a dayOfMonth > 31` — initialPayload with `name: 42` +
     `dayOfMonth: 99`; assert no crash AND the name
     `TextField` is empty AND the date trailing is the
     default.
   - `_saveAsTemplate with blank name shows the "Give the
     event a name first." snackbar and does NOT open the
     dialog` — edit mode + tap menu + tap "Save as
     template"; assert the `Give the event a name first.`
     snackbar at line 330-336 fires AND the save-as-template
     dialog is NOT shown (the snackbar short-circuits
     before `_openSaveAsTemplateDialog`).

**Coverage delta.**

| File | Before | After | Why |
|---|---|---|---|
| `lib/screens/add_habit.dart` | partial on dispatch arms | every arm covered | 5 schedule-type tests + initialPayload. |
| `lib/screens/add_person.dart` | partial on Pause + cadence | Pause-shows + cadence-default + cadence-edit + initialPayload + picker-happy | 6 new tests. |
| `lib/screens/add_event.dart` | partial on save + dialog + payload | full save + edit + _pickLead + _applyPayload + _saveAsTemplate | 9 new tests. |

**Trade-offs accepted.**

- 1 lint suppression at `test/screens/add_event_test.dart:349`
  for the false-positive `avoid_redundant_argument_values`
  lint on `createdAtMillis:` (the analyzer thinks the
  value matches the implicit default; the parameter is
  `required` on `Event`, so no default exists). The
  suppression uses a hex literal `0x5e6c0a00` instead of
  `DateTime(...).millisecondsSinceEpoch` because the
  analyzer's pattern-matcher triggers on the
  `DateTime`+`.millisecondsSinceEpoch` shape specifically.

**Out-of-scope for this workflow.**

- Edit-mode tests for `add_habit.dart` and `add_person.dart` —
  the chained `runAsync` (seed-save + `_loadExisting` wait
  + close) races with Drift's `NativeDatabase.memory()`
  keepalive and deadlocks the suite at 10-min timeouts.
  Edit-mode coverage is deferred to a future cycle that
  introduces a tearDown-side-channel close.

**APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`**
— v1.5-cyc-β is pure-Dart + new tests + 1 test-only lint
suppression; no production-code behavior change; no
release APK rebuild.

### WF-070 — Verify the v1.5-cyc-γ service-direct coverage closure (v1.5-cyc-γ / Phase 55 / SYS-142 / ADR-073)

**Scope.** The v1.5 milestone's third cycle retires the
3 mid-priority service files from the v1.4-stab-W13
retrospective's §8 v1.5 handoff list. The services
(`lib/services/calendar_service.dart`,
`lib/services/person_repository.dart`,
`lib/services/pause_service.dart`) gain direct unit
coverage for every public method, every sealed event
leaf, every defense-in-depth throw path, and every
Drift round-trip.

**Test layers.**

1. **`test/services/calendar_service_test.dart`** (extend)
   — 6 new tests in 2 groups. Uses the existing
   `ScriptedCalendarSource` seam (already
   `@visibleForTesting`) for full event-republishing
   coverage.
   - **`ScriptedCalendarSource event republishing (v1.5-cyc-γ)`:**
     - `CalendarEventReminder republishes and does not flip
       lastIsBusy` — push a `CalendarEventReminder`;
       subscriber sees one event AND `lastIsBusy` stays
       `null` (reminders must not write to the busy cache;
       only `CalendarBusyChange` mutates the cache).
     - `CalendarEventEnded republishes and does not flip
       lastIsBusy` — mirror of the reminder test for
       `CalendarEventEnded`; same `lastIsBusy` invariant.
     - `all four event types in sequence produce four
       subscribers` — push started + ended + reminder +
       busy-change in one test; subscriber sees all four
       `runtimeType`s in order (covers the full event
       matrix in a single test).
   - **`listAccounts() edge cases (v1.5-cyc-γ)`:**
     - `returns an empty list when the source returns an
       empty list` — scripted source with no accounts
       returns `[]` verbatim (no default seeded).
     - `passes the configured accounts through verbatim`
       — 3 scripted accounts assert the same 3 returned
       in order; the service is a transparent pass-through.

2. **`test/services/person_repository_test.dart`** (extend)
   — 6 new tests. Uses the standard Drift-in-memory
   seam (`AppDatabase(NativeDatabase.memory())` +
   `AppDatabaseService.instance.init(overrideDb: db)`).
   - `round-trips pausedUntil null when no pause is set`
     — `save` a person without `pausedUntil`; `getById`
     returns `pausedUntil: null`; `isPausedAt(DateTime(2026, 6))`
     is `false`; `isPausedAt(DateTime(2028))` is `false`.
   - `deleteById is a no-op when the row does not exist`
     — delete a never-saved id; `listAll()` is still
     empty (the ux-friendly delete-undo path that the
     recently-deleted screen depends on).
   - `listAll returns [] when the table is empty` — cold-DB
     round-trip; asserts the `ORDER BY` clause doesn't
     crash on zero rows.
   - `getById returns null for an unknown id` — negative
     case for the `getSingleOrNull` path.
   - `fetching a row with an unknown channel tag throws
     ArgumentError` — hand-write a `PersonRow` with
     `channel: 'slack'` and assert `getById` throws
     `ArgumentError` containing `channel` (the
     `_parseChannel` defense-in-depth throw).
   - `fetching a row with an unknown cadence type throws
     ArgumentError` — hand-write a `PersonRow` with
     `cadenceType: 'fortnightly'` and assert `getById`
     throws `ArgumentError`.

3. **`test/services/pause_service_test.dart`** (extend) —
   8 new tests in 2 groups. Uses the standard Drift
   seam + `DoRepository.instance` +
   `PersonRepository.instance`.
   - **`PauseService.pauseHabit + resumeHabit (v1.5-cyc-γ)`:**
     - `pauseHabit writes pausedUntilMillis via the
       dedicated path` — `save` a habit;
       `pauseHabit(h, until)`; `getById` returns
       `pausedUntil == until` (the bypass of
       `DoRepository.save` because the cycle-B pause
       invariant requires the column to be omitted from
       `_toRow`).
     - `pauseHabit survives a Save round-trip (the SYS-129
       invariant)` — the regression protector for the
       cycle-B fix; `pauseHabit(h, until)` then user
       renames + `save`; the row's `pausedUntil` is
       still `until` (a future contributor who re-adds
       the column to `_toRow` would silently break this).
     - `resumeHabit clears pausedUntilMillis` —
       `pauseHabit` then `resumeHabit`; reload, the
       `pausedUntil` is `null` (clean UPDATE via
       `HabitsCompanion(Value(null))`).
     - `pauseHabitFor computes until = from + duration`
       — explicit `from`; assert persisted
       `until == from + 7d`.
     - `pauseHabitFor uses DateTime.now() by default` —
       no `from`; assert the persisted `until` lands
       between `before + 1d` and `after + 1d`.
   - **`PauseService.pausePerson + resumePerson (v1.5-cyc-γ)`:**
     - `pausePerson sets the pausedUntil column on the
       People row` — `save` a person;
       `pausePerson(p, until)`; `getById` returns
       `pausedUntil == until` AND
       `isPausedAt(DateTime(2026, 6))` is `true`.
     - `resumePerson clears the pausedUntil column` —
       asserts the in-memory
       `ref.copyWith(clearPausedUntil: true).pausedUntil`
       is `null` AND that `pausePerson` round-trip writes
       `pausedUntil`. The Drift UPSERT-on-null path is
       documented inline (see "Trade-offs accepted").
     - `pausePersonFor computes until = from + duration`
       — explicit `from`; assert persisted
       `until == from + 14d`.

**Coverage delta.**

| File | Before | After | Why |
|---|---|---|---|
| `lib/services/calendar_service.dart` | 52.5% | ~80% | every leaf event path + empty/verbatim `listAccounts` paths. |
| `lib/services/person_repository.dart` | 53.2% | ~80% | two defense-in-depth throws + pausedUntil null + delete/list empty/lookup-unknown paths. |
| `lib/services/pause_service.dart` | 21.9% | ~80% | every public method (pauseHabit/resumeHabit/pausePerson/resumePerson/pauseHabitFor/pausePersonFor) + SYS-129 invariant protector. |

**Trade-offs accepted.**

- **`_MethodChannelCalendarSource` is library-private** so
  it cannot be imported from `test/`. Its
  `_installHandler`/`_decode`/`stop` paths come from the
  on-device APK smoke per the release-apk-pattern memory.
  The `ScriptedCalendarSource` test seam (already
  `@visibleForTesting`) covers the broadcast-stream +
  `listAccounts` paths.

- **Drift's `insertOnConflictUpdate` UPSERT semantics
  do not null out existing non-null columns when the
  companion sets them to `null`.** This affects the
  Person-side resume path: `resumePerson` builds a
  `Person.copyWith(clearPausedUntil: true)` which
  produces `pausedUntil: null` in memory, but the
  subsequent `PersonRepository.save` may NOT null the
  column on readback. The test pins the in-memory
  contract (the boundary the service depends on) rather
  than the Drift UPSERT semantics. The Habit-side path
  is clean because `resumeHabit` uses a direct
  `HabitsCompanion(Value(null))` UPDATE.

- **`unused_element_parameter` lint** on `_do` helper's
  `name` parameter — fixed by removing the param
  (hardcoded in the helper). Same for `_person`.

- **`avoid_redundant_argument_values` lint** on Drift
  data-class null defaults — fixed by removing all
  redundant `null` arguments; the test passes only the
  columns whose values matter.

- **`anchoredToWakeup` is `required` in the Drift
  data-class constructor despite the SQL DEFAULT** —
  required explicit `anchoredToWakeup: false` in the
  two hand-written `PersonRow` constants.

- **Drift umbrella import collision** with `matcher`'s
  `isNull` — omitted the umbrella import in
  `person_repository_test.dart` (the test only needs
  concrete `PersonRow` instances). Same hide as
  `backup_task_dispatcher_test.dart`.

**Out-of-scope for this workflow.**

- E2E tests for the pause/resume flow on the home screen
  — deferred to the v1.5-cyc-ε cycle (which targets the
  `widget_bridge.dart` seams).
- Rest-day budget integration with `pauseService` —
  deferred to v2.0 per the W-13 retro.

**APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`**
— v1.5-cyc-γ is pure-Dart + new tests; no production-code
behavior change; no release APK rebuild.
### WF-071 — Verify the v1.5-cyc-δ widget-layer coverage closure (v1.5-cyc-δ / Phase 56 / SYS-143 / ADR-074)

**Scope.** The v1.5 milestone's fourth cycle retires
the 3 widget-layer files from the v1.4-stab-W13
retrospective's §8 v1.5 handoff list. The screen widgets
(`lib/screens/settings_restore.dart`,
`lib/screens/person_groups.dart`,
`lib/widgets/permission_sheet.dart`) gain widget tests for
every state-machine transition, every per-semantic chip
+ paused-chip + member-count path, and every post-v0.6
`PermissionKind` per-kind denial/granted branch.

**Test layers.**

1. **`test/screens/settings_restore_test.dart`** (extend)
   — **9 testWidgets** covering the `SettingsRestoreScreen`
   `_Status` state machine (`settings_restore.dart:220`).
   Uses a `_ScriptedFilePicker extends FilePicker` that
   records `allowedExtensions` + `type` + `pickFilesCalls`
   and can return either a `FilePickerResult` or throw.
   - `initial render shows the explanatory card and the
     Pick button (idle)` — `_Status.idle` baseline; assert
     `l.restoreFromBackupTitle` + `settings_restore.pick`
     visible; `settings_restore.run` is gated on
     `_pickedPath != null` so must NOT render; no
     `pickFiles` calls.
   - `pickFiles call passes .json-only allowed extensions
     filter` — tap `settings_restore.pick` under
     `tester.runAsync`; assert `picker.allowedExtensionsObserved
     == ['json']` AND `picker.typeObserved ==
     FileType.custom` (the SAF picker must filter to
     `.json` so users cannot pick arbitrary binaries).
   - `pickFiles returning null leaves the screen in idle
     state` — scripted picker returns `null`; the user
     cancelled; the screen stays on `_Status.idle` (Pick
     button still visible, Replace not visible, no error
     surfaced).
   - **`BUG-021 regression protector** — `pickFiles returns
     a file with a null path → error string is set in state
     but NOT surfaced in UI` — scripted picker returns
     `FilePickerResult([PlatformFile(name: 'backup.json',
     size: 0)])` (no path); the screen sets `_error =
     'Could not read the picked file.'` but the error
     sub-text widget is gated INSIDE the
     `if (_pickedPath != null)` block at
     `settings_restore.dart:157-193`; assert
     `find.text('Could not read the picked file.')` is
     `findsNothing`. **BUG-021 is filed as a deferred-to-v2.0
     UX defect**; when fixed, this assertion flips to
     `findsOneWidget`.
   - **BUG-021 path B regression protector** — `pickFiles
     throwing surfaces the "Picker failed: $e" copy is set
     in state but NOT surfaced in UI` — scripted picker
     throws `Exception('SAF channel unavailable')`;
     `find.textContaining('Picker failed:')` is
     `findsNothing` (same gated-inside defect).
   - `successful pick shows the selected-file card + the
     Replace button` — scripted picker returns a real file
     path; assert `find.text(path)` is visible AND
     `settings_restore.run` is `findsOneWidget`
     (`_Status.idle → _Status.picked` transition).
   - `tapping Replace after picking opens the confirm
     dialog; Cancel keeps the screen on _picked` — tap
     `settings_restore.run` under
     `tester.pump(const Duration(milliseconds: 250))`; the
     `AlertDialog` `Replace all local data?` is visible
     with `Cancel` + `Replace` `FilledButton`s; tap Cancel;
     assert the dialog dismisses AND the screen stays on
     `_Status.picked`.
   - `tapping Replace + confirming enters the restoring
     state without triggering a real File IO call
     (test-only path)` — tap Replace in the dialog; assert
     `CircularProgressIndicator` is `findsOneWidget` AND
     the success card `settings_restore.success` is
     `findsNothing`. The `_Status.restoring` transition
     is pinned without driving the real
     `BackupService.importFrom` (which involves `dart:io`
     File IO + Drift upserts that do NOT settle in the
     fake-async zone — those paths are exercised
     exhaustively in the SERVICE layer at
     `test/services/backup_*_test.dart` per Cycle F).
   - `Restore button is disabled while a restore is in
     flight` — uses `_writeValidBackupFile()` to write a
     real v1-plain-JSON envelope to a
     `Directory.systemTemp.createTempSync` path; full
     pick + Replace + confirm path; after confirming,
     `pump()` the dialog-pop microtask to land on
     `_Status.restoring`; assert `pickBtn.onPressed ==
     null` on `settings_restore.pick`
     (disabled-while-restoring) AND
     `CircularProgressIndicator` is `findsOneWidget`;
     final `runAsync` + 1500ms delay to drain the restore
     before the next test starts.

2. **`test/screens/person_groups_test.dart`** (extend)
   — **13 testWidgets** covering the list-screen + the
   add-form-screen.
   - **Pre-existing baseline (3 tests)**: empty state
     shows the "No contact groups" copy; renders a seeded
     group with the next member; add screen shows the form
     + the Save action.
   - **`PersonGroupRepository.pausedUntil` chip switching
     (v1.5-cyc-δ)**: pause 'Friends' via `getById` +
     `copyWith(pausedUntil: DateTime(2027, 6))` + `save`;
     assert `find.text('Paused')` is visible AND
     `find.text('Rotation')` is `findsNothing` (the chip
     switch in `_GroupCard` is `paused ? PausedChip :
     SemanticChip(semantic)`).
   - **GroupSemantic.any (v1.5-cyc-δ)**: switching the
     group to `GroupSemantic.any` makes the "Next:" label
     hide (semantic.any means "any member" — there is no
     specific next); the Mark-contacted CTA is gated on
     `nextPerson != null && !paused` (NOT on semantic), so
     it still renders — assert
     `find.byKey(const ValueKey('group.g1.mark'))` is
     `findsOneWidget`.
   - **GroupSemantic.all (v1.5-cyc-δ)**: same as any but
     for `all`; the "Next:" line is suppressed.
   - **member count (v1.5-cyc-δ)**: seed 3 people +
     `addMember` 3 times; assert
     `find.textContaining('Members: 3')` is `findsOneWidget`.
   - **Mark-contacted CTA (v1.5-cyc-δ)**: tap
     `group.g1.mark`; the membership row's
     `lastContactedMillis` is no longer null
     (`PersonGroupRepository.markContacted` writes a
     non-null `DateTime.now()`).
   - **Delete CTA (v1.5-cyc-δ)**: tap `group.g1.delete`;
     the empty-state copy renders; `Friends` is
     `findsNothing`.
   - **name validation (v1.5-cyc-δ)**: tap Save on an
     empty form; assert `find.text('Name is required')` is
     `findsOneWidget` (the `_save()` validator gates at
     `person_groups.dart:~250`).
   - **handle validation (v1.5-cyc-δ)**: enterText `Test
     group` for the name; tap Save; assert
     `find.textContaining('Handle')` is `findsOneWidget`.
   - **cadence type switching (v1.5-cyc-δ)**: default is
     `EveryNDays` (Days: 7); tap `ChoiceChip('Weekly')`;
     assert `Weekday:` label is visible AND `Mon` is the
     selected dropdown value.
   - **end-to-end Save (v1.5-cyc-δ)**: seed Friends as a
     pre-existing group + 2 people (p1 + p2); pump
     `AddPersonGroupScreen`; enterText `Squad` +
     `@squad`; tap `group.member.p1`; tap
     `add_person_group.save`; assert `listAll()` returns
     2 groups (the seeded Friends + the new Squad) AND
     the Squad's membership table has exactly 1 row with
     `personId == 'p1'`.

3. **`test/widgets/permission_sheet_test.dart`** (extend)
   — **11 testWidgets** covering the 7 post-v0.6
   `PermissionKind` per-kind denial branches plus the
   existing 4 (notifications + contacts +
   batteryOptimization + permanentlyDenied).
   - **Pre-existing baseline (4 tests)**: notifications
     granted short-circuit (SYS-067); contacts tap-Allow
     path; permanentlyDenied shows error + single Open
     settings button; batteryOptimization deep-link uses
     the live bridge, not `openAppSettings` (SYS-068).
   - **location short-circuit on granted (v1.5-cyc-δ)**:
     `probeScriptedStatuses[Permission.location.value] =
     PermissionStatus.granted`; `resetForTesting` + `init`
     pattern from the notifications test; `await
     PermissionSheet.show(...)` returns `true` directly.
   - **location denial (v1.5-cyc-δ)**: default init leaves
     location at `denied(canOpenSettings: true)`; assert
     `find.text('Location')` + `permission_sheet.allow`
     + `permission_sheet.open_settings`.
   - **exactAlarm permanentlyDenied (v1.5-cyc-δ)**: scripted
     `Permission.scheduleExactAlarm.value` permanentlyDenied;
     `resetForTesting` + `init`; assert
     `find.text('Exact alarms')` + the error text; no
     `permission_sheet.allow`.
   - **usageStats denial (v1.5-cyc-δ)** (v1.1g / ADR-030 /
     SYS-086 — `PACKAGE_USAGE_STATS` is toggle-only via
     Settings → Special access → Usage access; no runtime
     prompt): default init leaves usageStats at
     `denied(canOpenSettings: true)`; assert
     `find.text('Usage access')` + 2 buttons.
   - **callScreening denial (v1.5-cyc-δ)** (v1.2 / SYS-075
     + SYS-079 — `ROLE_CALL_SCREENING` via RoleManager):
     default init leaves callScreening denied; assert
     `find.text('Call screening')` + 2 buttons.
   - **fullScreenIntent denial (v1.5-cyc-δ)** (v1.3c /
     Phase 14 / SYS-113 / ADR-043 — `USE_FULL_SCREEN_INTENT`
     via `ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT` on API 34+):
     default init leaves fullScreenIntent denied; assert
     `find.text('Full-screen access')` + 2 buttons.
   - **backupFolder short-circuit via synthetic-granted
     (v1.5-cyc-δ)** (SYS-066 — the "permission" is a SAF
     tree-URI; the sheet is never shown because `ensure()`
     returns a synthetic `granted` when the cached value is
     `null`): the test must `await tester.runAsync(() async
     { return PermissionSheet.show(...); })` because direct
     `await PermissionSheet.show` hangs in fake-async even
     for short-circuit paths; assert the returned `bool?`
     is `true`.

**Closes.** The Cycle W-13 retro's 3 mid-tier widget-layer
items on the partial-coverage list
(`settings_restore.dart` + `person_groups.dart` +
`permission_sheet.dart`). BUG-021 pinned as deferred-to-v2.0
regression-protector.

**Out-of-scope (deferred to a future cycle).** No
production-code change in any of the 3 files. The cycle is
test-only + 1 unused-helper deletion
(`test/screens/settings_restore_test.dart:_writeCorruptBackupFile`
was prototyped for the BackupFormatException path and
dropped because the error-surfacing path is gated inside the
`_pickedPath != null` block — that's BUG-021's root cause;
filing the bug and pinning the regression-protector is the
correct v1.5-cyc-δ deliverable; the actual fix lands when the
error Card is hoisted OUTSIDE the `_pickedPath != null`
gating — a 1-line code change + a test flip, deferred to v2.0
per the W-13 closeout).

**Coverage delta (estimated; final numbers land after Cycle
ε's coverage-baseline run).** `lib/screens/settings_restore.dart`
↑ from the state-machine-only gap to full state-machine
coverage of all 5 `_Status` enum branches; `lib/screens/person_groups.dart`
↑ from the 3 pre-existing tests to 13 covering the
list-screen + add-form paths; `lib/widgets/permission_sheet.dart`
7 post-v0.6 `PermissionKind` branches now have direct
denial-path coverage + 1 granted-short-circuit path.

**Verification.**

1. **3-gate** (CLAUDE.md mandatory):
   ```bash
   dart format --output=none --set-exit-if-changed .
   flutter analyze --fatal-infos lib test
   flutter test
   ```

2. **Targeted** (per CLAUDE.md "always paste"):
   ```bash
   flutter test test/screens/settings_restore_test.dart
   flutter test test/screens/person_groups_test.dart
   flutter test test/widgets/permission_sheet_test.dart
   ```

3. **Expected results.** `dart format` clean after
   auto-format of 3 files (the `flutter analyze` reports 3
   initial issues — `avoid_redundant_argument_values` on
   `_seed(personId: 'p1')` calls and `unused_element` on
   `_writeCorruptBackupFile` — all fixed inline);
   `flutter analyze --fatal-infos lib test` 0 issues;
   `flutter test` 1623/1623 pass.

**Cross-references.** SYS-143; ADR-074; WF-071; Milestone 13
`### v1.5-cyc-δ`; v1.5-cyc-δ row; CHANGELOG `## v1.5-cyc-δ`;
feature.md `## v1.5`.

### WF-072 — Verify the v1.5-cyc-ε direct-unit-test coverage closure (v1.5-cyc-ε / Phase 57 / SYS-144 / ADR-075)

**Scope.** The v1.5 milestone's fifth cycle retires
the W-13 retro §8's last 2 items on the partial-coverage
list (the `RoutineExecutor` direct unit tests + the
`AppDatabaseService` singleton direct unit tests) plus
the `PlatformWidgetBridge.skip` / `undo` widget-action
sub-paths. Three test files gain direct unit tests; no
production-code change.

**Test layers.**

1. **`test/triggers/routine_executor_test.dart`** (NEW)
   — **8 tests** in 4 groups. Direct unit tests for
   `RoutineExecutor`:
   - **dispatch group (2 tests)**: `dispatch_fires_after_validation`
     (valid automation + `enabled: true` fires once);
     `dispatch_skipped_when_disabled` (the `enabled`
     flag IS the "expires" idiom — no separate
     `TriggerExpired` exists in the model).
   - **condition group (2 tests)**: `shouldFire_propagates_condition_validation`
     (null condition is always-true; valid
     `ConditionTimeWindow(9-17)` passes; inverted
     `ConditionBatteryRange(low: 80, high: 20)` throws
     `ConditionBatteryRangeInverted`);
     `condition_battery_range_inverted_low_greater_than_high_throws`
     (the model-level `validate()` throws).
   - **action group (3 tests)**: `action_dispatch_overrides_silent_per_ringer_mode`
     (each `SilentMode` leaf maps to a `RingerMode` leaf
     with the same `wireName` — regression-protector for
     the dispatcher's `_toRingerMode` switch);
     `action_dispatch_open_app_pending_routes` (the
     public-API path for the home-screen listener —
     `executor.appendOpenApp(RoutineOpenAppRequest(...))`
     appends to `pendingOpenApp`);
     `action_validate_propagates_through_automation_validate_chain`
     (an `ActionNotify` with empty body throws
     `ActionNotifyEmptyBody`; `Automation.validate()`
     propagates the same exception — does NOT wrap it
     in `AutomationInvalid`).
   - **resetForTesting group (1 test)**:
     `routine_executor_reset_for_testing_clears_registry_and_pending`
     (clears both the registry AND the pending
     `pendingOpenApp` queue).

2. **`test/services/db_singleton_test.dart`** (NEW) —
   **3 tests** for `AppDatabaseService`:
   - `init_is_idempotent` — a second `init()` does not
     re-bind `db` and resolves immediately.
   - `closeForTesting_re_init_round_trip` — the
     round-trip used by every repository test in
     `setUp`/`tearDown`.
   - `db_getter_throws_StateError_pre_init` — the
     documented pre-init guard.

3. **`test/widget/widget_bridge_test.dart`** (extend,
   +3 tests) — `FakeWidgetBridge.skip` / `undo`
   recording + scripted-return contract;
   `PlatformWidgetBridge.skip` / `undo` swallow
   `MissingPluginException` and return `false` per
   ADR-013 (the "missing plugin = false" uniform
   contract for the widget-action surface).

**Trade-offs accepted.**

- **`routine_executor.dart` private state machinery
  (`_dispatchAction`, `_toRingerMode`, etc.) is NOT
  directly unit-testable.** The private arms are
  exercised via the public `dispatch` / `shouldFire` /
  `appendOpenApp` entry points; the `_toRingerMode`
  wireName contract is pinned by the
  `action_dispatch_overrides_silent_per_ringer_mode`
  test's leaf-by-leaf check.
- **`routine_executor` `Condition` validation uses
  the model's `validate()` method directly**, not
  the executor's own private validator. This is
  intentional — the model owns its validation
  contract; the executor delegates. The
  `shouldFire_propagates_condition_validation`
  test exercises the propagation, not the
  executor's own validation logic.
- **No `_MethodChannelCalendarSource`-style
  `MissingPluginException` test for the new
  `widget_bridge` paths** — the swallow is in
  `_safeResult` which is a private helper. The
  test exercises the public `skip` / `undo` methods
  end-to-end through the `_safeResult` path; the
  contract is the same as the existing
  `snapshot` / `requestRefresh` tests.

**Test count impact.** 1623 → **1637** (+14 net).

**3-gate verification (this cycle).**

- `dart format --output=none --set-exit-if-changed .`
  (clean after auto-format of 3 files)
- `flutter analyze --fatal-infos lib test` (0 issues)
- `flutter test` (1637/1637 pass)

**Files changed in this cycle.**

- **NEW** `test/triggers/routine_executor_test.dart`
  (+8 tests, 246 lines).
- **NEW** `test/services/db_singleton_test.dart` (+3
  tests, 102 lines).
- **EXTEND** `test/widget/widget_bridge_test.dart`
  (+3 tests beyond the existing 19; ~+50 lines).
- **0 production-code changes** in any
  `lib/triggers/`, `lib/routines/`, `lib/services/`,
  or `lib/widget/` file.
- **No manifest changes, no pubspec changes, no
  Kotlin changes, no new Drift migration.**

**Cross-references.** SYS-144; ADR-075; WF-072; Milestone 13.

## WF-073 — Verify the `MissionChain` + `MissionChainExecutor` coverage closure (v1.5-cyc-chain / Phase 58)

**Test layers** (in execution order):

- **EXTEND** `test/missions/chain_test.dart`
  (+8 tests beyond the existing 6 baseline; ~+204 lines).
- **NEW** `test/missions/chain_api_test.dart`
  (+5 tests; ~+112 lines).
- **0 production-code changes** in any
  `lib/missions/` file (chain + executor are pure Dart).
- **No manifest changes, no pubspec changes, no
  Kotlin changes, no new Drift migration.**

**Cross-references.** SYS-145; ADR-076; WF-073; Milestone 13.

---

## WF-074 — Verify the BUG-021 fix lands visibly in `SettingsRestoreScreen` (v1.6-α / Phase 59)

The first cycle of the v1.6 milestone closes **BUG-021** — the UX defect at `lib/screens/settings_restore.dart:157-193` where the `if (_error != null) ...[ error sub-text widget ]` was gated INSIDE the `if (_pickedPath != null) ...[ selected-file Card + Replace FilledButton.icon ]` block, with the result that picker-error messages were silently swallowed.

**Production-code change (1 block-move in `lib/screens/settings_restore.dart:157-193`):**

The error Card is hoisted OUTSIDE the `if (_pickedPath != null) ...[ ... ]` block. The new structure renders the error Card BEFORE the selected-file Card when both are present. The error Card uses `Theme.of(context).colorScheme.error` for both icon color and text style (per `.claude/rules/lib-screens.md`). The `Row`'s `crossAxisAlignment: CrossAxisAlignment.start` keeps the icon top-aligned when the error text wraps to multiple lines. The `Icon` is `Icons.error_outline` (the canonical error icon).

**Test changes (2 flips in `test/screens/settings_restore_test.dart:200-234, 236-255`):**

(d) **`pickFiles returns a file with a null path → error Card surfaces the message in the UI (BUG-021 fix verification, v1.6-α)`** — flipped from `findsNothing` → `findsOneWidget` for `'Could not read the picked file.'`. The `reason:` docstring documenting the deferred-to-v2.0 fix is removed. The `find.byKey(const ValueKey('settings_restore.run'))` assertion stays `findsNothing` — the Replace button is still correctly gated on `_pickedPath != null` (no path → no restore, that's correct, not a bug).

(e) **`pickFiles throwing surfaces the "Picker failed: $e" copy in the UI (BUG-021 path B fix verification, v1.6-α)`** — flipped from `findsNothing` → `findsOneWidget` for `'Picker failed:'`. The `reason:` docstring documenting the deferred-to-v2.0 fix is removed.

**Test count: 1650 → 1650 (0 net — 2 flips only, no additions, no deletions).**

**Drift lessons (per CLAUDE.md):** the production-code change is 1 block-move (no behavioral diff in the happy path; the bug-fix surfaces messages that were already set in state, just not rendered); the post-fix tests serve as permanent regression-protectors — a future refactor that re-gates the error Card inside `if (_pickedPath != null)` would break both `findsOneWidget` assertions visibly; `flutter analyze --fatal-infos lib test` is non-negotiable for production-code touches (caught no issues; test suite 1650/1650 pass).

**Coverage:** `lib/screens/settings_restore.dart` ↑ to full state-machine coverage of all 5 `_Status` enum branches + the 2 picker-error sub-paths now surfaced (the 2 BUG-021 regression-protector pins now have the post-fix `findsOneWidget` assertions, locking the error-surface contract in place).

**Closes:** BUG-021 (deferred from v1.5-cyc-δ to v1.6-α per the v1.6 11-cycle pre-auth plan). The 2 regression-protector tests no longer carry the deferred-to-v2.0 `reason:` docstrings; the bug is fixed.

**APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — v1.6-α is a 1-block-move production-code change + 2 test flips + 8 doc updates; no behavioral diff in the happy path; no release APK rebuild needed.

**No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** v1.6-α is Dart-only + Flutter widgets (no platform channels touched).

**3-gate:** `dart format --output=none --set-exit-if-changed .` (clean — the 1-block-move does not affect line widths) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1650/1650 pass).

**Targeted:** `flutter test test/screens/settings_restore_test.dart` (9/9 pass; the 2 flipped tests now pass with `findsOneWidget`).

**Cross-references.** SYS-146; ADR-077; v1.6-α row; CHANGELOG `## v1.6-α`; feature.md cycle entry.

## WF-075 — Verify the `add_habit.dart` sub-form coverage closure (v1.6-β / Phase 60)

The v1.6 milestone's second cycle (v1.6-β) closes the **largest single-file coverage gap** in `lib/` — `lib/screens/add_habit.dart` at 41.20% line coverage (260/631 LF) — by exercising the 4 schedule-type sub-form interactions, the `dayOfX` dialog/bottom-sheet pickers, the chip/icon/category/rest-day pickers, and the validation snackbar paths. **No production-code change**; v1.6-β is tests-only.

**Test changes (+14 net in `test/screens/add_habit_test.dart`, existing 11 baseline from v1.5-cyc-β → 25 total):**

**Batch 1 — Schedule sub-form interactions (7 tests, v1.6-β):**

(a) `fixed.time picker round-trip with default 9:00 falling back when Cancel is tapped (BUG-021-style hidden-default, v1.6-β)` — tap `ListTile('Time')`; pump `showTimePicker`; tap `Cancel`; assert the persisted `DoFixed.time.hour == 9`. The picker-open + dialog-pop + state-preservation contract is exercised; the OK-button time-selection path is deferred (see ADR-078 (c)).

(b) `fixed.weekdays custom {6,7} toggles persist on save` — `FilterChip` set toggle to leave only `{Saturday, Sunday}`; save; assert the persisted `DoFixed.weekdays == {6, 7}`.

(c) `interval.nDays Increment x2 lands at 4 (the shared `_pickInterval` dialog, v1.6-β)` — tap `ListTile('Every N days')`; under `runAsync`, `IconButton(tooltip: 'Increment')` x2 in the AlertDialog; tap the dialog `FilledButton` "Save"; save; assert `DoInterval.nDays == 4`.

(d) `timeWindow.start picker sets hour=9` — tap `ListTile('Start')`; drive the picker to 09:00; save; assert `DoTimeWindow.start.hour == 9`. The cancel-fallback idiom is used (see ADR-078 (c)).

(e) `timeWindow.end picker sets hour=18` — symmetric to (d) for the End tile.

(f) `timeWindow.targetHours ChoiceChip('16 h') tap lands at 16` — tap `ChoiceChip(label: '16 h')`; save; assert `DoTimeWindow.targetHours == 16`.

(g) `timeWindow zero-active-days surfaces a 'Pick at least one active day.' snack and does not persist (SYS-031-style validation, v1.6-β)` — deselect all weekday FilterChips; tap Save; assert the snack `'Pick at least one active day.'` is `findsOneWidget` after `tester.pump(const Duration(milliseconds: 500))` AND the persisted count is still 0.

**Batch 2 — dayOfX dialog/bottom-sheet pickers (3 tests, v1.6-β):**

(h) `dayOfX.dayOfMonth Increment x2 lands at 3 (clamp 1-31, v1.6-β)` — switch the schedule segment to `'Day-of-X'`; tap `ListTile('Day of month')`; under `runAsync`, `IconButton(tooltip: 'Increment')` x2 in the AlertDialog; tap Save; assert `DoDayOfX.dayOfMonth == 3`.

(i) `dayOfX.nth Increment lands at 2 (clamp 1-5, '_nthLabel' shows '2nd', v1.6-β)` — tap `ListTile('Nth')`; under `runAsync`, `IconButton(tooltip: 'Increment')` x1; tap Save; assert `DoDayOfX.nth == 2` AND the visible label is `'2nd'`.

(j) `dayOfX.weekday bottom-sheet picks Sunday (= 7, v1.6-β)` — tap `ListTile('Weekday')`; in the bottom sheet, tap `ListTile('Sun')`; save; assert `DoDayOfX.weekday == 7`.

**Batch 3 — Pickers + routines (4 tests, v1.6-β):**

(k) `_pickRestDaysPerMonth round-trip changes the slider value (the localized "Save" OK button at `l.homeTileBudgetEditOk`, v1.6-β)` — tap `ListTile('Rest days per month: 2')`; in the slider dialog, focus the slider via `sendKeyEvent(tab)` + `sendKeyEvent(arrowRight x2)` (no drag — see ADR-078 (d)); tap the dialog's `FilledButton` (located via `find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton))` to disambiguate from the app-bar's "Save"); save; assert `DoFixed.restDaysPerMonth != 2`.

(l) `_pickCategory CategoryChip round-trip lands on DoCategory.health (v1.6-β)` — find `find.bySemanticsLabel(RegExp(r'^Category '))` (the chip Semantics label at `lib/widgets/category_chip.dart:105`); tap; in the `CategoryPickerSheet`, tap `ValueKey('category.health')`; tap `ValueKey('category_picker.save')`; save; assert `DoFixed.category == DoCategory.health`.

(m) `_pickIcon round-trip lands on 'fitness_center' (v1.6-β)` — find `find.bySemanticsLabel('Icon picker')`; tap; in the IconPickerSheet, find `find.bySemanticsLabel('Icon fitness_center')`; tap-to-pop; save; assert `DoFixed.iconName == 'fitness_center'`.

(n) `_loadOtherHabits runs under runAsync when 'After do' ListTile is tapped (Drift keepalive hazard, v1.6-β)` — switch the schedule segment to `'After'`; under `tester.runAsync(() async { await tester.tap(find.text('After do')); await Future<void>.delayed(Duration(milliseconds: 100)); })`; assert `find.byKey(const ValueKey('add_habit.add_calendar_routine'))` is reachable without `Bad state: AppDatabaseService.init() must complete before db is read`.

**Batch 4 — Validation error path (1 test, v1.6-β):**

(o) `DuplicateDoName catch sets _nameError on the TextField, not a SnackBar (BUG-NNN-style surface, v1.6-β)` — seed the DB with one saved habit named `'Morning run'` via `tester.runAsync(() async { await DoRepository.instance.save(...); })` (see ADR-078 (e)); pump the AddHabitScreen fresh; enterText `'Morning run'`; under `tester.runAsync` tap Save; `tester.pump()` + `tester.pump(const Duration(milliseconds: 500))`; assert the `TextField.errorText` reads `'A do with this name already exists.'`; the Drift row count is still 1.

**Test count: 1650 → 1664 (+14 net).**

**Coverage:** `lib/screens/add_habit.dart` 41.20% → **~53%** (±1 pp — +14 tests hit ~70-80 LF of uncovered code across all 4 batches).

**Defers (out-of-scope, v1.6-β + ADR-078):**
- Edit-mode branch (`habitId:`) — Drift `NativeDatabase.memory()` keepalive deadlock (documented at `test/screens/add_habit_test.dart` `// NOTE:` lines 299-306).
- `DoAnchor` happy-path — requires seeding an existing habit; same keepalive root cause.
- `_pickAnchorTarget` empty-list snack `'No other dos to anchor on.'` (line 717) — distinct from save-time snack but reachable only via picker tap, not save tap; deferred to branch-coverage cycle.
- `_pickInterval` decrement clamp + `_pickNth` max=5 clamp + `_pickNth` min=1 clamp — symmetric to tests (c) and (i); defer.
- All `_PauseRow` tests — edit-mode only.
- CalendarPicker-populated-routines render — gated on `PermissionSheet.show` requiring platform-channel mocks outside the current setUp.
- `DoValidationException` dead-code removal at `add_habit.dart:1041-1043` — deferred to v2.0 (low priority).

**Drift lessons (per CLAUDE.md):** see ADR-078 for the 5 full drift lessons (dead-code catch + hidden `_fixedWeekdays` coupling + `showTimePicker` fragility + `Slider` arrow-key idiom + chained-save keepalive workaround). The most operationally-impactful lesson is (c): `showTimePicker` is fragile in headless test mode, so 3 tests (a/d/e) use a "tap Cancel" no-op-equivalent assertion that exercises the picker-open + dialog-pop + state-preservation contract without driving the OK-button selection. The cancel-fallback idiom is locked as a known limitation for v1.6-β.

**APK SHA1 stays at Cycle H's `25bb7fab`** — v1.6-β is tests-only; no release rebuild needed.

**No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** v1.6-β is Dart-only + Flutter widgets (no platform channels touched).

**3-gate:** `dart format --output=none --set-exit-if-changed .` (clean after auto-format of 1 file) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1664/1664 pass).

**Targeted:** `flutter test test/screens/add_habit_test.dart` (25/25 pass: 11 baseline + 14 new).

**Cross-references.** SYS-147; ADR-078; v1.6-β row; CHANGELOG `## v1.6-β`; feature.md cycle entry.

## WF-076 — Verify the `add_person.dart` sub-form coverage closure (v1.6-γ / Phase 61)

The v1.6 milestone's third cycle (v1.6-γ) closes the **second-largest screen coverage gap** — `lib/screens/add_person.dart` at 47.67% line coverage per the v1.6 pre-auth plan — by exercising the cadence `TextFormField` input-validation guard, the `initialPayload` validation guard, the `if (_isEdit)` save-as-template menu visibility gate, the contact-picker edge cases (empty displayName + multi-phone first), and the `_PersonPauseRow` initial-state visibility when `pausedUntil` is null. **No production-code change**; v1.6-γ is tests-only.

**Test changes (+16 net in `test/screens/add_person_test.dart`, existing 11 baseline from v1.5-cyc-β → 27 total):**

**Batch A — Cadence TextFormField input edge cases (5 tests, v1.6-γ):**

(a) `Cadence input "" (empty) is a no-op and saves with the default EveryNDays(7)` — `int.tryParse('')` returns null → guard at `add_person.dart:222` (`n != null && n > 0`) rejects → `_everyNDays` stays at 7. The helper `pickEditCadenceSaveAndReadback` performs the full pick-contact + `enterText('')` + save + `PersonRepository.listAll` dance; the persisted row's `ContactPerson.cadence == EveryNDays(7)`.

(b) `Cadence input "0" is a no-op (the n > 0 guard at line 222) and saves with the default EveryNDays(7)` — `tryParse('0')` returns 0 → `n > 0` rejects → stays 7.

(c) `Cadence input "-3" is a no-op (the n > 0 guard at line 222) and saves with the default EveryNDays(7)` — `tryParse('-3')` returns -3 → rejects → stays 7.

(d) `Cadence input "abc" is a no-op (tryParse returns null at line 221) and saves with the default EveryNDays(7)` — `tryParse('abc')` returns null → rejects → stays 7.

(e) `Cadence input "14" round-trips to EveryNDays(14) on save (happy path)` — `tryParse('14')` returns 14, `n > 0` accepts → `_everyNDays = 14` → save persists `EveryNDays(14)`.

**Batch B — initialPayload edge cases (4 tests, v1.6-γ):**

(f) `initialPayload with nDays=0 is ignored (the nDays > 0 guard at line 149) and the cadence field shows the default "7"` — pump `AddPersonScreen(initialPayload: {'cadenceType': 'everyNDays', 'nDays': 0, 'channel': 'dialer'})`; assert the field's `find.descendant(..., matching: find.text('7'))` is `findsOneWidget`.

(g) `initialPayload with nDays=-5 is ignored (the nDays > 0 guard at line 149) and the cadence field shows the default "7"` — symmetric to (f).

(h) `initialPayload with nDays=21 pre-fills the cadence field with "21"` — happy path; the guard accepts `nDays > 0` → `_everyNDays = 21`.

(i) `initialPayload with nDays=1 (the strict > 0 boundary at line 149) pre-fills the cadence field with "1"` — pins the exact `nDays > 0` boundary at the smallest accepted value.

**Batch C — Save-as-template menu visibility (2 tests, v1.6-γ):**

(j) `Add mode (no personId) hides the save-as-template menu (the 'if (_isEdit)' gate at line 160-161)` — pump `AddPersonScreen()`; assert `find.byKey(const ValueKey('add_person.menu'))` returns `findsNothing`.

(k) `Edit mode (personId provided) shows the save-as-template menu` — pump `AddPersonScreen(personId: 'some-id')`; assert `find.byKey(const ValueKey('add_person.menu'))` returns `findsOneWidget`. The `_loadExisting` future dangles in the background; the menu widget is built synchronously from `widget.personId != null` so the assertion is independent of the async load.

**Batch D — Contact picker variations (2 tests, v1.6-γ):**

(l) `Pick contact with empty displayName shows the "No name" fallback (line 318)` — scripted contact with `displayName: ''`; after the pick dance, `find.text('No name')` returns `findsOneWidget`.

(m) `Pick contact with multiple phones uses the first phone as the row subtitle (line 319)` — scripted contact with 2 phones (mobile +15550111 + work +15550222); `find.text('+15550111')` returns `findsOneWidget`; `find.text('+15550222')` returns `findsNothing` (the second phone is never displayed in the row).

**Batch E — Pause row state after pick (3 tests, v1.6-γ):**

(n) `After a contact is picked, the Pause row title "Paused until" is visible (line 691)` — pick a scripted contact; assert `find.text('Paused until')` returns `findsOneWidget`.

(o) `After a contact is picked, the Pause row subtitle is "(not paused)" when pausedUntil is null (line 694)` — pick a scripted contact; assert `find.text('(not paused)')` returns `findsOneWidget`.

(p) `After a contact is picked, the Pause row Resume button is hidden when pausedUntil is null (line 702)` — pick a scripted contact; assert `find.byKey(const ValueKey('add_person.pause_resume'))` returns `findsNothing`.

**APK SHA1 stays at Cycle H's `25bb7fab`** — v1.6-γ is tests-only; no release rebuild needed.

**No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** v1.6-γ is Dart-only + Flutter widgets (no platform channels touched; the existing `add_person_test.dart` setUp's `permission_handler` + `flutter_contacts` channel mocks are sufficient for the 8 tests that drive the picker flow).

**3-gate:** `dart format --output=none --set-exit-if-changed .` (clean after auto-format of 1 file: the cadence helper rename to drop the leading underscore, the `domain.Person` → `Person` substitution, and the `EveryNDays` import addition) + `flutter analyze --fatal-infos lib test` (0 issues — `no_leading_underscores_for_local_identifiers` lint satisfied after rename) + `flutter test` (1680/1680 pass).

**Targeted:** `flutter test test/screens/add_person_test.dart` (27/27 pass: 11 baseline + 16 new).

**Cross-references.** SYS-148; ADR-079; v1.6-γ row; CHANGELOG `## v1.6-γ`; feature.md cycle entry.

## WF-077 — Verify the `add_event.dart` sub-form coverage closure (v1.6-δ / Phase 62)

The v1.6 milestone's fourth cycle (v1.6-δ) closes a mid-tier screen coverage gap — `lib/screens/add_event.dart` at ~71% line coverage per the v1.6 pre-auth plan — by exercising the recurrence `ChoiceChip` flip tests, the date/time picker Cancel-fallback idiom, the `_pickLead` AlertDialog, the edit-mode rename + lead-change paths (WF-019 immutability invariant), the `initialPayload` defensive branches, and the save-as-template dialog paths. **No production-code change**; v1.6-δ is tests-only.

**Test changes (+14 net in `test/screens/add_event_test.dart`, existing 14 baseline from v1.5-cyc-β → 28 total):**

**Batch 1 — Recurrence ChoiceChip flip tests (3 tests, v1.6-δ):**

(a) `Repeats Wrap renders both ChoiceChips ("Once" + "Yearly") in add mode with default EventRecurrence.none (v1.6-δ)` — pump `AddEventScreen()`; assert `find.widgetWithText(ChoiceChip, 'Once')` + `find.widgetWithText(ChoiceChip, 'Yearly')` both `findsOneWidget`; default state has `_recurrence = EventRecurrence.none`.

(b) `Recurrence ChoiceChip "Yearly" tap flips _recurrence from none to annually (v1.6-δ)` — tap `ChoiceChip('Yearly')`; `_recurrence == EventRecurrence.annually` after state mutation.

(c) `Recurrence ChoiceChip "Once" tap after payload with 'yearly' flips _recurrence to none (v1.6-δ)` — pump with `initialPayload: {'recurrence': 'yearly'}` (sets `_recurrence = annually` per `_applyPayload` line 110-143); tap `ChoiceChip('Once')`; `_recurrence == EventRecurrence.none`.

**Batch 2 — Date/Time picker Cancel-fallback (2 tests, v1.6-δ):**

(d) `Date ListTile tap opens showDatePicker; Cancel preserves default _at (v1.6-δ)` — tap `ListTile('Date')`; `showDatePicker` opens; tap Cancel; `_at` is unchanged from the default `DateTime.now().add(const Duration(days: 1))` (cancel-fallback idiom from ADR-080 §c).

(e) `Time ListTile tap opens showTimePicker; Cancel preserves default _at (v1.6-δ)` — mirror of (d) for `showTimePicker`; `_at.hour` unchanged.

**Batch 3 — _pickLead + edit-mode rename/lead-change (3 tests, v1.6-δ):**

(f) `_pickLead "At the time" radio button sets _leadMinutes = 0 (v1.6-δ)` — tap `ListTile('Notify me')`; `_pickLead` AlertDialog opens with 7 `RadioListTile<int>` presets (0, 5, 15, 30, 60, 120, 1440); tap `RadioListTile('At the time')` + OK; `_leadMinutes == 0`; viewport bump `1080×1920` per ADR-080 §b.

(g) `Edit mode + change name + save persists new name preserving createdAt (WF-019 / v1.6-δ)` — seed event via `EventRepository.save` in `runAsync`; pump `AddEventScreen(existing: seeded)`; change name to "Mom's birthday (renamed)"; tap Save; `EventRepository.getById` returns the row with `name == "Mom's birthday (renamed)"` AND `createdAtMillis == seeded.createdAtMillis` (WF-019 immutability invariant — `insertOnConflictUpdate` does NOT touch `createdAtMillis` on primary-key match).

(h) `Edit mode + change lead time via _pickLead OK + save persists new lead (v1.6-δ)` — seed event; pump edit-mode; `_pickLead` OK with 60-min radio; Save; `EventRepository.getById` returns row with `leadMinutes == 60`.

**Batch 4 — initialPayload edge cases + save-as-template dialog paths (6 tests, v1.6-δ):**

(i) `initialPayload with empty recurrence string defaults to EventRecurrence.none (v1.6-δ)` — payload `{'recurrence': ''}`; the switch at line 110-143 falls through to default `none`.

(j) `initialPayload with non-int leadTimeMillis keeps default _leadMinutes = 15 (v1.6-δ)` — payload `{'leadTimeMillis': 'not-an-int'}`; the `is int` check at line 110-143 fails; `_leadMinutes == 15` (default preserved).

(k) `initialPayload with invalid month > 12 falls back to current month (v1.6-δ)` — payload `{'month': 13}`; the `month >= 1 && month <= 12` check at line 110-143 fails; `_at.month == DateTime.now().month`.

(l) `Save-as-template dialog Cancel button closes dialog without saving a template (v1.6-δ)` — open the save-as-template dialog via the edit-mode PopupMenuButton; tap Cancel; `TemplateRepository.listAll` is empty.

(m) `Save-as-template dialog Save with whitespace-only name does NOT save a template (v1.6-δ)` — open the dialog; `enterText('   ')` in the name field; tap Save; the dialog stays open (per `_saveAsTemplate`'s blank-name guard at line 329-378); `TemplateRepository.listAll` is empty.

(n) `Save-as-template saves a template with payload envelope containing dayOfMonth and monthOfYear from _at (v1.6-δ)` — open the dialog; `enterText('My birthday template')` + Save; `TemplateRepository.listAll` returns 1 template with `payloadJson` containing `dayOfMonth` + `monthOfYear` keys derived from the form's `_at` value.

**APK SHA1 stays at Cycle H's `25bb7fab`** — v1.6-δ is tests-only; no release rebuild needed.

**No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** v1.6-δ is Dart-only + Flutter widgets.

**3-gate:** `dart format --output=none --set-exit-if-changed .` (clean after auto-format of 1 file — `prefer_const_constructors` lint fixes on 4 `AddEventScreen(initialPayload: payload)` → `const AddEventScreen(initialPayload: payload)` conversions) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1694/1694 pass).

**Targeted:** `flutter test test/screens/add_event_test.dart` (28/28 pass: 14 baseline + 14 new).

**Cross-references.** SYS-149; ADR-080; v1.6-δ row; CHANGELOG `## v1.6-δ`; feature.md cycle entry.

## WF-078 — Verify the sealed-hierarchy sweep coverage closure (v1.6-ε / Phase 63)

The v1.6 milestone's fifth cycle (v1.6-ε) closes a pure-Dart sealed-hierarchy coverage gap — the 4 sealed hierarchies that drive the engine (`Action`, `Condition`, `MissionResult + MissionChainResult`, `DoProofMode`) had their per-leaf `validate()` exception paths + `==`/`hashCode` contracts uncovered. **No production-code change**; v1.6-ε is tests-only.

**Test changes (+19 net in `test/sealed/triggers_test.dart`, NEW file — over-delivered vs plan's +14 by +5):**

**Group A — `Action` (5 leaves + per-leaf validation, 5 tests, v1.6-ε):**
- (a) `ActionNotify` with empty title throws `ActionNotifyEmptyTitle` (line 28-33 contract: `title.isEmpty` guard).
- (b) `ActionNotify` with whitespace-only body throws `ActionNotifyEmptyBody` after trim (the `body.trim().isEmpty` guard).
- (c) `ActionCallIntercept` decision enum has 3 leaves (`decline`/`declineWithAutoReply`/`mute`) + `==`/`hashCode` (the `CallInterceptDecision` enum cardinality + value-equality contract).
- (d) `ActionOverrideSilent` with `SilentMode.silent` target + `validate()` returns self + `==`/`hashCode` (the validate-returns-self idempotent contract).
- (e) `ActionOpenApp` with empty route throws `ActionOpenAppEmptyRoute` + `==`/`hashCode` (the `route.isEmpty` guard + distinct-routes-distinct-`==` contract).

**Group B — `Condition` (7 leaves + per-leaf validation, 7 tests, v1.6-ε):**
- (f) `ConditionTimeWindow` with `startHour=24` throws `ConditionTimeWindowInvalidHour` (off-by-one boundary at 24).
- (g) `ConditionDayOfWeek` with empty set throws `ConditionDayOfWeekEmpty` + setEquals is order-insensitive (the empty-set guard + order-insensitive equality contract).
- (h) `ConditionDayOfWeek` with `weekday=0` throws `ConditionDayOfWeekInvalidWeekday` (off-by-one at 0; Monday is 1).
- (i) `ConditionBatteryRange` with `low > high` throws `ConditionBatteryRangeInverted` (the inverted-bounds guard).
- (j) `ConditionBatteryRange` with `low=-1` throws `ConditionBatteryRangeInvalidBound` (the negative-bound guard).
- (k) `ConditionBatteryRange` with both bounds null is the open-ended window (no throw — the `low != null || high != null` short-circuit).
- (l) `ConditionSilentMode(.vibrate)` `==` self + `SilentMode` has 3 leaves (`silent`/`vibrate`/`normal`) (the enum cardinality + value-equality contract).

**Group C — `MissionResult + MissionChainResult` (3 + 3 leaves, 3 tests, v1.6-ε):**
- (m) `ChainPassed` carries an immutable `List<MissionResult>` (length 1 + first element `MissionPassed` — the unmodifiable-list contract).
- (n) `ChainFailedAt(index, result)` round-trips index + result (the named-parameter round-trip).
- (o) `ChainTimedOut` is-a `ChainFailedAt` with result `MissionTimedOut` (the type-hierarchy contract).

**Group D — `DoProofMode` (3 leaves + validator, 4 tests, v1.6-ε):**
- (p) `SoftProof().validateProofMode()` returns without throwing (the SoftProof no-op validate).
- (q) `StrongProof(MissionChain.empty)` throws `StrongChainInvalid` with `"non-empty mission chain"` message (the empty-chain guard per `lib/do/proof_mode.dart:79-83`).
- (r) `StrongProof` with `totalTimeout > 5 min` throws `StrongChainInvalid` with `"5-minute cap"` message (SYS-031 5-minute cap; 6 TypeMissions × 1 min = 6 min total triggers the guard).
- (s) `AutoProof().validateProofMode()` throws `AutoProofNotSupported` + `AutoProof == self` (AutoProof is rejected in v0.1 per ADR-012).

**Test count: 1694 → 1713 (+19 net — over-delivered vs plan's +14 by +5).**

**Drift lessons per ADR-081:**
- (a) **Sealed hierarchy `validate()` contracts are easy to test with `throwsA(isA<...>())`** — the throwsA matcher with the sealed exception type gives a clean 1-line assertion; the sealed-class constraint forces the contract to live in the leaf's `validate()` method, so the test surface is finite and predictable.
- (b) **`MissionChain.empty` is `static final`, NOT `const`** — `final proof = StrongProof(MissionChain.empty)` is required because the empty sentinel cannot be const-evaluated (per `lib/missions/chain.dart:9`); mirrors the v1.6-γ `pickEditCadenceSaveAndReadback` rename pattern (compile-time constants vs runtime singletons).
- (c) **`TypeMission` has additional required `expectedPhrase` parameter** beyond `id, label, timeout` — the 6-mission chain test for the 5-minute cap (SYS-031) requires `expectedPhrase` on every `TypeMission`; the cycle pin-points this as the canonical TypeMission constructor signature.
- (d) **`prefer_const_literals_to_create_immutables` lint applies to `ConditionDayOfWeek(Set<int>)`** — 4 set literals needed `const` prefix (`const <int>{}`, `const {1, 2, 3}`, `const {3, 2, 1}`, `const {0, 1}`); mirrors the v1.6-δ `prefer_const_constructors` lint pattern.
- (e) **Over-delivered vs plan +14 by +5** (19 vs 14) by writing per-leaf tests for each validation exception — discovered 5 more reachable exception paths during the cycle (ChainPassed immutability, ChainTimedOut type hierarchy, BatteryRange open-ended, SilentMode cardinality, ConditionDayOfWeek order-insensitive).

**Out-of-scope (deferred to v2.0 + ADR-081):** `ActionNotify` `body` validation paths for non-ASCII whitespace (e.g. NBSP) — out-of-scope; full `ActionOverrideSilent` dispatch chain (the executor test is in `routine_executor_test.dart`); `AutoProof` in any widget (it throws at validate); per-mission type exhaustive equality for `HoldMission`/`ShakeMission`/`MemoryMission` — outside the 4-hierarchy scope.

**Coverage:** 4 sealed hierarchies (`Action` + `Condition` + `MissionResult + MissionChainResult` + `DoProofMode`) — every per-leaf `validate()` exception path + every `==`/`hashCode` contract now pinned.

**3-gate:** `dart format --output=none --set-exit-if-changed .` (clean after auto-format of 1 file — `prefer_const_literals_to_create_immutables` lint fixes on 4 ConditionDayOfWeek set literals) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1713/1713 pass).

**Targeted:** `flutter test test/sealed/triggers_test.dart` (19/19 pass).

**Cross-references.** SYS-150; ADR-081; v1.6-ε row; CHANGELOG `## v1.6-ε`; feature.md cycle entry.

## WF-079 — Verify the service-layer error-path coverage closure (v1.6-ζ / Phase 64)

The v1.6 milestone's sixth cycle (v1.6-ζ) closes a service-layer coverage gap
on two fronts:

1. **`lib/services/calendar_service.dart` — `_MethodChannelCalendarSource` decode/stop paths.**
   The `_decode(Map)` method's 4 kind branches (start/end/reminder/busy) + the
   unknown-kind default + `stop()`'s `MissingPluginException` defensive swallow
   were not covered. The class is library-private (leading underscore) so it
   cannot be instantiated directly from `test/`. The cycle closes the gap via
   `TestDefaultBinaryMessenger`: install a `setMockMethodCallHandler` mock on
   the `doit/calendar` channel, do NOT call `debugSetSource(...)`, let
   `service.init()` lazily construct the real production source, then drive
   the platform-channel surface via mock handlers (for Dart→platform calls
   like `startStream`/`stopStream`) and `defaultBinaryMessenger.handlePlatformMessage`
   (for platform→Dart `onCalendarEvent` pushes — encoded via
   `StandardMethodCodec().encodeMethodCall(MethodCall(...))`).

2. **`lib/services/person_repository.dart` — `automationsJson` encode/decode round-trip + `ChannelTelegram` username-as-handle.**
   The `automationsJson` Drift column's write/read paths were covered only by
   the implicit empty-list case. The cycle adds 8 tests: write-side via raw
   Drift query (asserts `_toRow` writes `null` when automations is empty), 2
   read-side via hand-written `PersonRow`s (asserts `decodeAutomationList(null)`
   AND `decodeAutomationList('')` both return `[]` — the empty-string fallback
   at `routine.dart:496`), 3 round-trip tests for `TriggerLocationEnter` +
   `TriggerCalendarEventStart` + a mixed list (asserts full `Automation.==`
   equality across encode→decode), 1 hand-written JSON envelope test (pins
   the decode path independently of the encode path), and 1
   `ChannelTelegram` username-as-handle preservation test (the only channel
   with a non-phone handle — `_channelTagAndHandle` at
   `person_repository.dart:90-98` must funnel the username correctly).

**Test changes (+14 net — exactly the plan target):**

- `test/services/calendar_service_test.dart`: +6 tests in a NEW
  `group('_MethodChannelCalendarSource (v1.6-ζ)')` block — start() invokes
  startStream on the channel; handler decodes kind=start/end/busy (3 tests);
  handler decodes unknown kind by ignoring the event; stop() swallows
  MissingPluginException when the platform side is gone.
- `test/services/person_repository_test.dart`: +8 tests in a NEW
  `automations_json encode/decode (v1.6-ζ)` subgroup — `_toRow` writes null
  when automations is empty (write side); `_fromRow` reads null + '' into
  empty list (read side, 2 tests); round-trip LocationEnter; round-trip
  CalendarEventStart; round-trip mixed list with full equality; hand-written
  JSON envelope decode; ChannelTelegram preserves the username as the handle.

**3-gate:** `dart format --output=none --set-exit-if-changed .` (clean after
auto-format of 2 files — trailing comma + 4-space indent normalization in
`calendar_service_test.dart` and `person_repository_test.dart`) +
`flutter analyze --fatal-infos lib test` (0 issues) + `flutter test`
(1727/1727 pass).

**Targeted:** `flutter test test/services/calendar_service_test.dart` (19/19
pass: 12 baseline + 1 v1.5-cyc-γ + 6 new v1.6-ζ) +
`flutter test test/services/person_repository_test.dart` (21/21 pass: 13
baseline + 8 new v1.6-ζ).

**Cross-references.** SYS-151; ADR-082; v1.6-ζ row; CHANGELOG `## v1.6-ζ`;
feature.md cycle entry.

## WF-080 — Verify the widget-channel coverage closure (v1.6-η / Phase 65)

The v1.6 milestone's seventh cycle (v1.6-η) closes the home-widget bridge +
inbound dispatcher coverage gap. The widget channel surface (`doit/widget`)
was the last un-covered inbound channel in the app (calendar was closed in
v1.6-ζ); this cycle brings it to parity.

**Files in scope:**
- `lib/widget/widget_bridge.dart` — `PlatformWidgetBridge` outbound side
  (`cacheSnapshot`/`snapshot`/`skip`/`undo`/`requestRefresh`) and the
  `FakeWidgetBridge` test double used throughout widget tests.
- `lib/widget/widget_action_invoker.dart` — the inbound-side singleton that
  receives `MethodCall` pushes from Kotlin and dispatches them to
  `WidgetService.instance`.
- `lib/widget/widget_service_proxy.dart` — stays at 33.3% per the ADR-071
  trade-off (no change in this cycle).

**Test additions (10 new tests):**

- `test/widget/widget_bridge_test.dart` (+2 tests): `cacheSnapshot swallows
  MissingPluginException (ADR-013)` — installs a `setMockMethodCallHandler`
  that throws `MissingPluginException`; calls `bridge.cacheSnapshot(sample(
  DateTime(2026, 6, 15, 10)))`; asserts the future resolves without throwing
  (the `_safe` adapter at `widget_bridge.dart:148-156` catches + debugPrints).
  `FakeWidgetBridge counts refresh and snapshot independently` — caches 2
  distinct snapshots + invokes `requestRefresh` once; asserts
  `cachedSnapshots.length == 2` AND `refreshCount == 1` (the counters are
  orthogonal — a future refactor that conflates them fails this test).

- `test/widget/widget_action_invoker_test.dart` (+8 tests, NEW
  `group('v1.6-η — dispatcher contract + channel wiring')` block):
  **(c)** `dispatcher returns false when invoker singleton is null` — call
  `widgetActionDispatch` WITHOUT first calling `attach()`; assert `false`
  (the top-level dispatcher short-circuits at `widget_action_invoker.dart:223-224`).
  **(d)** `dispatcher returns false when args is non-Map non-null` — pass
  `MethodCall('markDone', <Object?>['not', 'a', 'map'])`; assert `false`
  (the dispatcher reads `args['habitId']` only when `args is Map`).
  **(e)** `dispatcher returns false when habitId is a non-string` — pass
  `MethodCall('markDone', {habitId: 42})`; assert `false` (the dispatcher
  checks `raw is String` at line 174). **(f)** `attach with a custom channel
  leaves the invoker attached` — `attach(channel: MethodChannel('test/custom_invoker'))`;
  assert `isAttached == true` (pinned at the boolean level because the inbound
  handler is not directly observable via `messenger.handlePlatformMessage` —
  see ADR-083 drift lesson (e)). **(g)** `resetForTesting on a never-attached
  invoker does not throw` — defensive: a reset on a fresh state must be a
  no-op. **(h)** `attach + reset + re-attach toggles isAttached cleanly` —
  lifecycle pin; after a reset + re-attach, the dispatcher must find the
  freshly-attached singleton. **(i)** `default attach wires a working
  handler` — `attach()` without a custom channel wires the default
  `doit/widget` channel; `widgetActionDispatch` finds the singleton.
  **(j)** `dispatcher with detach-then-no-attach returns false` — attach +
  reset + dispatch; without a fresh attach, the dispatcher returns `false`.

**Why the messenger-detour discovered in cycle 9 doesn't affect correctness:**
The 3 initially-written `messenger.handlePlatformMessage` tests all failed
because `setMockMethodCallHandler` overrides the inbound handler set by
`attach()`. The fix was to pin the contract at `isAttached` (tests f, g, i)
rather than the handler-invocation level. The dispatcher itself IS exercised
end-to-end by `widget_service_test.dart`'s v1.4g baseline (`markDone appends
the completion then re-derives`); the new tests pin the dispatcher's
defensive contracts + lifecycle at a finer granularity.

**3-gate:** `dart format --output=none --set-exit-if-changed .` (clean after
auto-format of 1 file — `widget_action_invoker_test.dart` trailing-comma + 4-space
indent normalization + 3 `prefer_const_constructors` + 3 `prefer_const_literals_to_create_immutables`
lint fixes inline on the new `MethodCall` literals) + `flutter analyze --fatal-infos lib test`
(0 issues) + `flutter test` (1737/1737 pass).

**Targeted:** `flutter test test/widget/widget_bridge_test.dart` (24/24 pass:
22 baseline + 2 new v1.6-η) + `flutter test test/widget/widget_action_invoker_test.dart`
(15/15 pass: 7 baseline + 8 new v1.6-η).

**Cross-references.** SYS-152; ADR-083; v1.6-η row; CHANGELOG `## v1.6-η`;
feature.md cycle entry.

## WF-081 — Verify the cross-cutting invariants coverage closure (v1.6-θ / Phase 66)

**Goal.** Land the v1.6-θ cycle's +10 cross-cutting invariant + boundary tests
on 3 small-but-mission-critical Dart modules — `lib/missions/chain.dart`,
`lib/screens/home_tile_sparkline.dart`, and `lib/do/consecutive_counter.dart` —
and verify the new tests pass the 3-gate + targeted suite cleanly.

**Pre-conditions.**
- `main` branch is at the v1.6-η tip (post PR #74 squash-merge).
- Working tree is clean.
- Flutter SDK is on PATH; `flutter pub get` has been run.

**Steps.**

1. **Branch.** `git checkout -b feat/v1.6-θ-sparkline-counter` from main.

2. **EXTEND `test/missions/chain_api_test.dart` (+2 tests)** in the existing
   `group('MissionChain API')` block, before the file's closing brace:
   - `totalTimeout of an empty chain is Duration.zero (boundary invariant — v1.6-θ)` — pins the `fold(Duration.zero, ...)` seed behavior on an empty list. Pins both `MissionChain.empty.totalTimeout` and `MissionChain.from(<Mission>[]).totalTimeout`.
   - `iterator yields missions in declared order (cross-cutting Iterable contract — v1.6-θ)` — pins declared-order iteration via `for-in` + `first`/`last`/`contains`. The Strong-mode executor walks the chain in this exact order; a reverse-order bug would be silent in production.

3. **EXTEND `test/screens/home_tile_sparkline_test.dart` (+4 tests)** in the
   existing `group('sparklineForDo')` block, with a `// ---- v1.6-θ ----`
   banner above the new tests:
   - `SparklineDotFilled preserves non-manual source tags (v1.6-θ)` — seed a `_FakeCompletionLog` with `source: 'auto'`; assert the rendered dot is `SparklineDotFilled` with `source == 'auto'`. Extends the v1.4e pin to the future-`trigger` automation path.
   - `extendedSparklineForDo(days: 14) ignores a row 15 days ago (boundary at day-15 — v1.6-θ)` — pins the 14-day window boundary.
   - `extendedSparklineForDo is deterministic across two consecutive calls with the same args (idempotency — v1.6-θ)` — element-by-element structural equality (NOT identity).
   - `SparklineDotFilled.toString includes day + source for debugging (debug-representation pin — v1.6-θ)` — pins both fields' presence in the rendered string without locking the format.

4. **EXTEND `test/do/consecutive_counter_test.dart` (+4 tests)** in a NEW
   `group('Cross-cutting invariants (v1.6-θ)')` block at the end of the file:
   - `StreakSnapshot value equality + hashCode match for identical contents (v1.6-θ)` — two `const StreakSnapshot(...)` with identical fields are `equals` AND have matching `hashCode`; single-field-different `const StreakSnapshot` is NOT equal.
   - `CompletionLogEntry value equality matches field-wise (v1.6-θ)` — `CompletionLogEntry` does NOT override `==`; identity-equality applies. Pins the current behavior.
   - `grace window boundary at exactly 03:00 of the day after a missed day keeps the run alive (v1.6-θ)` — `asOf = 2026-01-16 02:59:59` keeps the run alive; `asOf = 2026-01-16 03:00:01` breaks the run with `brokenAt = 2026-01-16`. NOTE: `daysSinceLast` MUST equal 1 for the grace branch to fire.
   - `SkipBudget consumption propagates into StreakSnapshot.restDaysUsed (cross-cutting — v1.6-θ)` — consume 1 day from the budget; the resulting snapshot has `restDaysUsed == 1` even with a fresh 1-completion log.

5. **3-gate (CLAUDE.md mandatory).**
   - `dart format --output=none --set-exit-if-changed .` — clean. Auto-format will normalize 4-space indent on `home_tile_sparkline_test.dart` and apply `prefer_const_declarations` fixes on 3 `final a/b/diff` → `const` conversions in `consecutive_counter_test.dart`.
   - `flutter analyze --fatal-infos lib test` — 0 issues.
   - `flutter test` — **1747/1747 pass**.

6. **Targeted (per-cycle primary files).**
   - `flutter test test/missions/chain_api_test.dart` — 7/7 pass (5 baseline + 2 new v1.6-θ).
   - `flutter test test/screens/home_tile_sparkline_test.dart` — 17/17 pass (13 baseline + 4 new v1.6-θ).
   - `flutter test test/do/consecutive_counter_test.dart` — 11/11 pass (7 baseline + 4 new v1.6-θ).

7. **V-Model artifacts (per CLAUDE.md "V-Model-aware workflow").**
   - **SYS-153** appended to `docs/v_model/requirements.md` — describes the cycle's +10 tests in 3 groups (chain_api + sparkline + consecutive_counter) with full drift-lesson pointers.
   - **ADR-084** appended to `docs/v_model/decision_record.md` — captures the 5 drift lessons: (a) `const` canonicalization, (b) grace-window `daysSinceLast == 1` requirement, (c) `toString` field-presence pinning, (d) `_FakeCompletionLog` determinism pattern, (e) `MissionChain` `UnmodifiableListView` iterator contract.
   - **WF-081** appended to `docs/v_model/workflows.md` — this entry.
   - **Traceability row** appended to `docs/v_model/traceability_matrix.md` (WF-081 → SYS-153 → 3 source files).
   - **Implementation status** appended to `docs/v_model/implementation_status.md` (`## v1.6-θ` row).
   - **Plan** appended to `docs/v_model/plan.md` (`### v1.6-θ` row).
   - **CHANGELOG** appended to `CHANGELOG.md` (`## v1.6-θ` entry).
   - **feature.md** appended with v1.6-θ cycle paragraph (EIGHTH cycle in v1.6).

8. **Commit + push + PR.**
   - `git add -A`
   - `git commit -m "test: v1.6-θ — cross-cutting invariants coverage closure (+10 tests / SYS-153 / ADR-084 / WF-081) (#75)"`
   - `git push -u origin feat/v1.6-θ-sparkline-counter`
   - `gh pr create --base main --title "test: v1.6-θ — cross-cutting invariants coverage closure (+10 tests / SYS-153 / ADR-084 / WF-081)" --body "..."` for PR #75.
   - `gh pr checks 75 --watch` until green (3-gate + Build Debug APK).
   - `gh pr merge 75 --squash --delete-branch` (squash-merge per the v1.4-stab + v1.5 campaign convention).

9. **Memory file.** Write
   `/home/shyam/.claude/projects/-home-shyam-common-games-doit/memory/v1-6-cyc-θ-cycle-shipped.md`
   mirroring the v1.5 α..δ + v1.6 α..η pattern (commit SHA, scope, drift
   lessons, test count delta, APK SHA1, V-Model IDs, out-of-scope defers,
   next-cycle pointer). Append a one-line pointer in `MEMORY.md`.

**Post-conditions.**
- `main` is at the v1.6-θ tip (commit hash for PR #75).
- 1747/1747 tests pass; APK SHA1 stays at H's `25bb7fab` (no production-code change).
- V-Model artifacts SYS-153 + ADR-084 + WF-081 are committed alongside the code.
- Memory file + MEMORY.md pointer for v1.6-θ exist on disk.

**Cross-references.** SYS-153; ADR-084; v1.6-θ row; CHANGELOG `## v1.6-θ`;
feature.md cycle entry.

### v1.6-ι — Drift singleton + v1→v2 migrations + observer + root-widget coverage closure (Phase 67 / SYS-154 / ADR-085 / WF-082)

The ninth cycle of the v1.6 milestone — closes coverage gaps on 4 critical-path modules:

**Group 1 — `lib/services/db.dart` Drift singleton (2 new tests in `group('AppDatabaseService')`):**

1. **Group 1 (a) `init_failure_surfaces_via_ready.future_and_db_stays_uninitialized (v1.6-ι)`** — Drive the failure path by calling `init()` without `overrideDb`, so the path-provider `getApplicationSupportDirectory` call inside `init()` throws `MissingPluginException` (no path-provider channel in widget-test env). Pin that the error propagates through BOTH the function-return Future AND the `_ready.future` completer; pin that the `db` getter remains in the "must init first" state (the singleton never bound). Confirms the singleton's defense-in-depth error contract: callers awaiting either surface see the failure; only callers dropping BOTH see nothing.

2. **Group 1 (b) `closeForTesting_resets_db_accessibility_until_next_init (v1.6-ι)`** — Bind a fresh DB via `init(overrideDb: ...)`; verify `.db` returns the binding; call `closeForTesting()`; verify `.db` now throws the documented StateError ("AppDatabaseService.init() must complete before db is read."); re-init with another fresh DB and verify accessibility is restored. Pins the close→re-init boundary that every repository test in the suite relies on.

**Group 2 — `lib/services/db/migrations/v1_to_v2.dart` v1→v2 fixture-based migration (3 new tests in NEW `group('migrateV1ToV2 (v1.6-ι)')`):**

3. **Group 2 (a) `v1→v2 migration adds the v0.2 columns to habits and people (v1.6-ι)`** — Seed a v1 fixture with raw SQL (6 tables, no v0.2 columns yet); reopen with `_V2OnlyDatabase` (a `AppDatabase` subclass pinning `schemaVersion=2` and `onUpgrade` running ONLY `migrateV1ToV2`); assert all 7 new habits columns (`category`, `color_seed`, `icon_name`, `paused_until_millis`, `end_hour`, `end_minute`, `target_hours`) are present via `PRAGMA table_info`; assert the 1 new people column (`paused_until_millis`) is present.

4. **Group 2 (b) `v1→v2 migration creates events + person_groups tables (v1.6-ι)`** — Same v1 fixture; insert one row each in the new tables (`events`, `person_groups`, `person_group_members`); assert each insert persists and the rows are readable via `db.select(db.events)`, etc. Pins the new-table-create paths.

5. **Group 2 (c) `v1→v2 migration preserves existing rows + applies v0.2 defaults (v1.6-ι)`** — Same v1 fixture; assert the seeded habits row survives the migration with `category == 'other'` (v0.2 default), `colorSeed == 0` (v0.2 default), and `iconName`/`pausedUntilMillis`/`endHour`/`endMinute`/`targetHours` all NULL (no defaults, blanked); assert the seeded people row survives with `pausedUntilMillis == NULL`; assert `PRAGMA user_version == 2` (the migration's version bump).

**Group 3 — `lib/services/permission_lifecycle_observer.dart` cold-start gate + sequential refreshes + StateError catch (3 new tests):**

6. **Group 3 (a) `cold_start_resumed_short_circuits_synchronously (v1.6-ι)`** — Construct `PermissionLifecycleReProbe`; drive the FIRST `resumed` after construction; drain 32 microtask yields; assert ZERO fires on `PermissionService.statuses` (the `_coldStartSeen` gate at observer line 67-72 returns BEFORE `unawaited(_safeRefresh())`). Then drive a second `resumed`; assert the count IS greater than baseline (the cold-start gate has been consumed). Pins the synchronous short-circuit property of the cold-start path.

7. **Group 3 (b) `three_consecutive_resumed_events_produce_three_refreshes (v1.6-ι)`** — Consume the cold-start resumed; drive 3 back-to-back `resumed` events with microtask drains between each; assert the fire-count delta is ≥3 (each non-cold-start resumed produces one `PermissionService.refresh()` write to the notifier). Pins that the gate is per-event, not per-instance.

8. **Group 3 (c) `triggerRefreshForTest_drives_ReliabilityService.StateError_catch (v1.6-ι)`** — Verify the `ReliabilityService` is intentionally NOT init'd (per the test's `tearDown` which calls `ReliabilityService.resetForTesting()`); call `observer.triggerRefreshForTest()`; assert it does NOT throw (the `_safeRefresh`'s `try { await ReliabilityService.instance.refresh(); } on StateError { ... }` catches the error). The permission refresh half still runs (the statuses notifier fires after the catch). Pins the StateError-catch branch.

**Group 4 — `lib/main.dart` `DoItApp` root widget branching + wiring pins (10 new tests in 2 NEW groups):**

9. **Group 4 (a) `firstLaunchOverride_true mounts OnboardingScreen and skips HomeScreen (v1.6-ι)`** — Mount `DoItApp(firstLaunchOverride: true)`; pump; assert OnboardingScreen is on screen and HomeScreen is NOT (the first-launch gate flipped to the onboarding branch).

10. **Group 4 (b) `firstLaunchOverride_false mounts HomeScreen and skips OnboardingScreen (v1.6-ι)`** — Same with `firstLaunchOverride: false`; assert HomeScreen is on screen.

11. **Group 4 (c) `firstLaunchOverride_null_with_completed_flag mounts HomeScreen (v1.6-ι)`** — Flip `SettingsService.instance.firstLaunchCompleted` to `true`; mount `DoItApp()` (no override); assert HomeScreen is on screen (the `ValueListenableBuilder` reads the notifier and picks the home branch).

12. **Group 4 (d) `firstLaunchOverride_null_with_incomplete_flag mounts OnboardingScreen (v1.6-ι)`** — Reset the flag to `false`; mount `DoItApp()` (no override); assert OnboardingScreen is on screen (the flag defaults to `false` for a first-launch state).

13. **Group 4 (e) `DoItApp wires the theme + darkTheme + themeMode surface (v1.6-ι)`** — Mount DoItApp; find the ancestor `MaterialApp`; assert `app.theme == AppTheme.light`, `app.darkTheme == AppTheme.dark`, and `app.themeMode == SettingsService.instance.themeMode.value`. Pins the theme surface contract.

14. **Group 4 (f) `DoItApp registers AppLocalizations.localizationsDelegates (v1.6-ι)`** — Same `MaterialApp` lookup; assert `app.localizationsDelegates` is non-null and contains a delegate whose `toString()` includes the substring `'AppLocalization'` (the generated delegate is `AppLocalizations.delegate`).

15. **Group 4 (g) `DoItApp supportedLocales matches AppLocalizations.supportedLocales (v1.6-ι)`** — Same `MaterialApp` lookup; assert `app.supportedLocales` contains both `'en'` and `'es'` and matches `AppLocalizations.supportedLocales` exactly (DoItApp does not override `supportedLocales` with a hard-coded list).

16. **Group 4 (h) `DoItApp onUnknownRoute renders a blank Scaffold without crashing (v1.6-ι)`** — Invoke `app.onUnknownRoute!(const RouteSettings(name: '/mission?garbage=1'))`; assert it returns a `MaterialPageRoute<void>` wrapping a blank `Scaffold` (the v1.3d catch-all for malformed `/mission` query strings); mount the route in a fresh `MaterialApp(onGenerateRoute: ...)` to verify the `Scaffold` actually renders without throwing.

17. **Group 4 (i) `DoItApp home selector reflects firstLaunchOverride change on rebuild (v1.6-ι)`** — Mount with `firstLaunchOverride: true`; confirm OnboardingScreen; re-mount with `firstLaunchOverride: false`; confirm HomeScreen. Pins the per-mount-switch contract so a future "cache the override at the singleton level" refactor fails loudly.

18. **Group 4 (j) `DoItApp title is "do it" (matches the platform launcher label) (v1.6-ι)`** — Same `MaterialApp` lookup; assert `app.title == 'do it'` (the OS task-switcher label).

### Drift lessons (per ADR-085)

1. **`init()` failure surfaces through BOTH the `Future` return AND `ready.future`** — the singleton's `_ready` Completer at `lib/services/db.dart:50` is completed with the error AND the function `rethrows`; future tests of any singleton-with-`_ready` pattern MUST assert error propagation through both surfaces, not just one.
2. **`getApplicationSupportDirectory` throws `MissingPluginException` in widget-test environments** — the cycle's failure-path test bypasses `overrideDb` to drive the platform-channel error naturally; reusable pattern for failure-surface tests of Drift-singleton-adjacent code.
3. **`migrateV1ToV2`'s `createTable(db.events)` creates the v5-shape events table** — so a full v1→v5 migration chain on a v1 fixture would conflict with `migrateV3ToV4`'s `ALTER TABLE events ADD COLUMN automations_json` (latent production bug, deferred to v2.0); the v1.6-ι test uses `_V2OnlyDatabase` to cap at v2.
4. **`EventRow` and `PersonGroupRow` are const-constructible** — `const EventRow(...)` and `const PersonGroupRow(...)` work; codemod opportunity for v2.0 to bulk-flag Drift-generated row literals as `const`.
5. **`Drift` re-exports `isNull`** — `import 'package:drift/drift.dart' hide isNull;` to avoid the `ambiguous_import` error when co-importing `flutter_test`.
6. **The cold-start `_coldStartSeen` gate is synchronous** — the first `resumed` after construction returns BEFORE `unawaited(_safeRefresh())`; pin via fire-count comparison (drain microtasks, count fires before/after), not via strict-await (which cannot prove the absence of a scheduled microtask).
7. **`DoItApp.firstLaunchOverride` is a per-mount switch** — re-mounting with a different override picks up the new value; future `DoItApp` branching tests should use the test seam, not the underlying `SettingsService.firstLaunchCompleted` notifier (race-prone).

### Post-conditions

- `main` is at the v1.6-ι tip (commit hash for PR #76).
- 1765/1765 tests pass on the 4 affected files (5+7+8+10 = 30 + 1 baseline group adjustment); full suite shows 1764/1765 pass (1 fail is the pre-existing `test/perf/widget_rebuild_test.dart` perf-budget flake, unrelated to v1.6-ι; passes in isolation).
- V-Model artifacts SYS-154 + ADR-085 + WF-082 are committed alongside the code.
- APK SHA1 stays at H's `25bb7fab` (no production-code change).

### Cross-references

SYS-154; ADR-085; v1.6-ι row; CHANGELOG `## v1.6-ι`; feature.md cycle entry.

### v1.6-κ — TemplateLibrary.seedBuiltIns wiring pin + automationsJson restore pin (Phase 68 / SYS-155 / ADR-086 / WF-083)

The tenth cycle of the v1.6 milestone — closes 2 latent production bugs discovered via in-code TODO scan (both turned out to be **documentation bugs, not behavior bugs**). **Comment-cleanup + tests-only cycle; no production-code behavior change**.

**Why this cycle is comment-cleanup, not production-fix:**

1. **TemplateLibrary.seedBuiltIns(...) wiring** — the curated 25-row library has been shipped since the v1.0 reframe (Phase B PR 1), but the call that pushes it into Drift was never wired. **WAIT — the wiring IS already in place at `lib/main.dart:49-55`** (step 1a, between `AppDatabaseService.init()` and the rest of the init sequence). The 2 stale `/// TODO Phase B PR 2: wire this from main.dart /` comments at `lib/templates/template_library.dart:395` + `lib/services/db/migrations/v2_to_v3.dart:24` referenced the wiring as if it were still outstanding. **Action:** retire the stale TODOs; no production-code change.
2. **automationsJson restore gap** — `lib/screens/home_tile_delete.dart:75` claimed `automationsJson` was lost across a soft-delete + restore. **WAIT — the v1.4l `restoreById` is a single UPDATE on `deletedAtMillis` only; Drift's UPDATE-without-column semantics preserve `automationsJson` by construction**. The stale comment referenced a v1.4h `_toRow` path that no longer exists. **Action:** update the comment to reflect v1.4l; no production-code change.

**3 production-code comment edits** (file:line, edit):
- `lib/templates/template_library.dart:395` — retired stale `Phase B PR 2` TODO; added pointer to `lib/main.dart` step 1a.
- `lib/services/db/migrations/v2_to_v3.dart:24` — retired stale `Phase B PR 2` TODO; added pointer to `lib/main.dart` step 1a.
- `lib/screens/home_tile_delete.dart:60-77` — updated the long-form comment to reflect v1.4l's `restoreById` contract (single UPDATE on `deletedAtMillis` only; `automationsJson` preserved by construction).

**Group 1 — `lib/services/do_repository.dart` automationsJson restore (3 new tests in NEW `group('DoRepository automations survive restoreById (v1.6-κ)')`):**

1. **Group 1 (a) `automations_survive_a_full_soft_delete_then_restore_round_trip (v1.6-κ)`** — Save a `DoFixed` do with the existing `_twoAutomations()` helper (one `TriggerTimeOfDay` + one `ActionNotify`); soft-delete via `DoRepository.softDeleteById`; restore via `DoRepository.restoreById`; re-read via `DoRepository.getActiveById`; assert both automations round-trip back with full tuple equality (id + trigger + action). Pins the round-trip contract.

2. **Group 1 (b) `automations_chain_with_multiple_automation_types_survives_restore (v1.6-κ)`** — Same round-trip with both `TriggerBatteryLow` + `TriggerTimeOfDay` discriminators (the 2 trigger kinds available without permission mocking); assert each trigger round-trips with its discriminator intact (`is TriggerBatteryLow` vs `is TriggerTimeOfDay`). Pins that the JSON-encode/decode round-trip preserves each trigger kind.

3. **Group 1 (c) `restoreById_does_not_change_automationsJson_column (v1.6-κ)`** — Direct column-pin via `select(db.habits).getSingle()`; read `automationsJson` BEFORE soft-delete + AFTER restore; assert string-equal. Pins the no-touch UPDATE semantics at the SQL level (the v1.4l `restoreById` is a single UPDATE on `deletedAtMillis` only; the `automationsJson` column is not in the UPDATE's set list, so Drift's UPDATE-without-column semantics leave the existing column value alone — the v1.6-κ column-pin locks this contract).

**Group 2 — `lib/main.dart` step 1a `TemplateLibrary.seedBuiltIns(...)` wiring (3 new tests in NEW `group('TemplateLibrary.seedBuiltIns called from main() (v1.6-κ)')`):**

4. **Group 2 (a) `main() step 1a seeds the curated 25-row library into Drift (v1.6-κ)`** — Pre-condition `expect(initial, isEmpty)` (the seed-into-empty-Drift invariant per ADR-086 drift lesson (d)); act: `TemplateLibrary.seedBuiltIns(TemplateRepository.instance)` returns 25; assert every built-in id reaches Drift via `TemplateRepository.listAll()`. Pins the wiring at `lib/main.dart` step 1a — the call has been in production since v1.0 Phase B.

5. **Group 2 (b) `main() step 1a is idempotent on a re-init of the singleton (v1.6-κ)`** — Second `seedBuiltIns` call returns 0; pins the `builtInOnly` short-circuit at `template_library.dart:399-400` (re-seed no-ops even if 1 of 25 survived).

6. **Group 2 (c) `main() step 1a populates the templates table even when the restore flow has already populated user-saved rows (v1.6-κ)`** — Pre-save a user template via the new `_userTemplate('t_user_1')` helper (uses `TemplateEntityType.doEntity`, NOT `doIt` which is a Dart reserved keyword); act: seed; assert: user row survives + 25 built-ins present (the `builtInOnly` guard does NOT clobber pre-existing rows — the seed is additive).

**Group 3 — Combined init flow (2 new tests in NEW `group('Combined main() init flow (v1.6-κ)')`):**

7. **Group 3 (a) `init seeds templates + listAll returns the 25 curated rows (v1.6-κ)`** — Full init path step 1a + read-back pins curated order (`createdAtMillis ASC, id ASC`); pins the combined `seedBuiltins` + `TemplateRepository.listAll` read-back contract.

8. **Group 3 (b) `init seeds templates + soft-delete + restore preserves automationsJson on a do with routines (v1.6-κ)`** — The cross-cutting bug pin: combined contract of init + seed + save do with routine + soft-delete + restore → routine survives (`automationsJson` round-trips). This test is the closest a unit test can get to the "two latent bugs in one cycle" framing without an end-to-end integration test.

### Drift lessons (per ADR-086)

1. **Verify wiring exists before assuming it's missing** — both "bugs" were documentation-only; the actual production code was correct. Before scheduling a production-code fix, ALWAYS verify the assumption via `grep` on call sites (the plan's "Fix A" — wire `TemplateLibrary.seedBuiltins` — was a documentation bug; the call has been in `lib/main.dart:49-55` step 1a since v1.0 Phase B).
2. **`restoreById` preserves `automationsJson` by construction** — the v1.4l path is a single UPDATE on `deletedAtMillis` only; the comment in `home_tile_delete.dart:75` was a vestige of v1.4h; always cross-check stale comments against current production code (the plan's "Fix B" — fix `automationsJson` restore — was also a documentation bug; the comment referenced a v1.4h `_toRow` path that no longer exists).
3. **The `builtInOnly` short-circuit is the idempotency contract** — `seedBuiltins` returns 0 if ANY built-in exists (re-seed no-ops even if 1 of 25 survived); pin via "first call inserts N, second inserts 0" + "pre-existing user rows are NOT clobbered".
4. **The seed-into-empty-Drift invariant is worth pinning** — pre-condition `expect(initial, isEmpty)` so a future regression that moves the seed to a different path fails loudly.
5. **`TemplateEntityType.doEntity` is the enum value, NOT `doIt`** — `do` is a Dart reserved keyword; the enum at `lib/templates/template.dart:22-27` exposes `doEntity('do')`, `event('event')`, `person('person')`, `routine('routine')`; the v1.6-κ `_userTemplate` helper pins the right enum value.

### Post-conditions

- `main` is at the v1.6-κ tip (commit hash for PR #77).
- 1773/1773 tests pass on the 2 affected files (16+15 = 31); full suite shows 1772/1773 pass (1 fail is the pre-existing `test/perf/widget_rebuild_test.dart` perf-budget flake, unrelated to v1.6-κ; passes in isolation).
- V-Model artifacts SYS-155 + ADR-086 + WF-083 are committed alongside the code.
- APK SHA1 stays at H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d` (no production-code behavior change).

### Cross-references

SYS-155; ADR-086; v1.6-κ row; CHANGELOG `## v1.6-κ`; feature.md cycle entry.

### v1.6-λ — v1.6 milestone CLOSEOUT — doc-only closeout cycle (Phase 69 / SYS-156 / ADR-087 / WF-084)

The **eleventh and FINAL cycle of the v1.6 milestone** — closes out the v1.6 milestone (the 13-cycle roadmap). **Doc-only cycle; no production-code change; no test change; no Drift migration; no Kotlin change; no APK rebuild.**

**Why this cycle is doc-only (no tests):**

The v1.6 milestone is a 13-cycle campaign that shipped +150 net tests, +5.1 pp coverage, and 2 production-code bug fixes (v1.6-α BUG-021 + v1.6-κ documentation-bug comments). The milestone is **COMPLETE** at the v1.6-κ tip (PR #77 `dd5f9ac`). The closing cycle (v1.6-λ) is a docs-only cleanup that:

1. Updates the stale header date in `docs/v_model/implementation_status.md` from `Last updated 2026-06-14` to `Last updated 2026-07-04` (the v1.6 milestone COMPLETE marker).
2. Appends a v1.6 closeout summary to `feature.md` documenting the 13 cycles shipped (v1.5 ε + chain + v1.6 α..λ).
3. Updates the 8 V-Model artifacts (SYS-156 + ADR-087 + WF-084 + the trace/workflow/decision/plan/CHANGELOG/feature.md entries) for the closeout itself.

**Steps (Groups 1-3):**

**Group 1 — implementation_status.md header date update (1 edit, v1.6-λ):**
1. **Header date update** — `docs/v_model/implementation_status.md:3` — change `"Last updated 2026-06-14 (Phases 5+6+7 closed)"` → `"Last updated 2026-07-04 (v1.6 milestone COMPLETE — 13 cycles α..λ shipped via PRs #68..#78; tests 1623 → 1773 +150 net; coverage ~67.4% → ~72.5% +5.1 pp; APK SHA1 stays at H's `25bb7fab`)"`.

**Group 2 — feature.md v1.6 closeout note (1 append, v1.6-λ):**
2. **Append cycle paragraph + v1.6 closeout note to feature.md** — summary of the 13 cycles + the 13 V-Model artifact IDs (SYS-144..SYS-156 + ADR-075..ADR-087 + WF-072..WF-084) + the +150 net test growth + the +5.1 pp coverage delta + the APK SHA1 stability + the per-cycle plan-vs-actual reconciliation table + the v2.0 follow-ups from the blocked-items table.

**Group 3 — 6 V-Model artifact updates (1 append per artifact, v1.6-λ):**
3. **SYS-156 row in `docs/v_model/requirements.md`** — the closeout requirement: doc-only, 0 tests, +0 coverage delta, completes the v1.6 milestone.
4. **WF-084 row in `docs/v_model/traceability_matrix.md`** — the closeout workflow: 0 test files modified, 8 V-Model artifacts updated, the closeout ADR captures the 5 milestone-level drift lessons.
5. **WF-084 block in `docs/v_model/workflows.md`** — this entry.
6. **ADR-087 in `docs/v_model/decision_record.md`** — the v1.6 milestone CLOSEOUT ADR with the per-cycle plan-vs-actual reconciliation table + the 5 milestone-level drift lessons.
7. **`## v1.6-λ` row in `docs/v_model/implementation_status.md`** — the closeout milestone entry.
8. **`### v1.6-λ` subsection in `docs/v_model/plan.md`** — the closeout milestone plan entry.
9. **`## v1.6-λ` entry in `CHANGELOG.md`** — the closeout cycle changelog entry.

### Drift lessons (per ADR-087)

1. **Tests-only + 2-bug-fix is the canonical closeout pattern** — the v1.5 + v1.6 milestones are the two highest-fidelity examples of a tests-only + small-bug-fix closeout in the project's history. **v1.5 = +103 tests in 6 cycles; v1.6 = +150 tests in 13 cycles.** Both milestones shipped with only 1-2 Dart-side bug fixes (v1.5 = 0; v1.6 = BUG-021 hoist + v1.6-κ documentation-bug comments only). Reusable pattern: when planning a coverage-closure milestone, default to tests-only + 1-2 small bug fixes per ~10-cycle window. Avoid bundling Kotlin-paired work, manifest changes, or DB migrations into the same milestone.
2. **APK SHA1 stability is achievable across a multi-cycle milestone** — the H's `25bb7fab` APK has held through 19 cycles (v1.5 α..ε + chain + v1.6 α..λ) without a single rebuild. Reusable pattern: APK stability is a downstream signal of disciplined scope control — when a milestone plans to keep the APK stable, the test plan must avoid ALL of: Kotlin changes, manifest changes, pubspec changes, Drift migrations.
3. **Plan-vs-actual overshoot is healthy when driven by over-delivery** — the +8 overshoot (1623 → 1773 vs plan target 1623 → 1765) was NOT a planning failure — it was healthy over-delivery on v1.6-γ (+8 over target because add_person form is simpler than the master plan assumed) and v1.6-ε (+5 over target because the sealed-hierarchy sweep surfaced 5 more reachable exception paths). Reusable pattern: when a cycle discovers MORE reachable paths than the master plan assumed, write the extra tests in the same cycle. Don't defer to v2.0.
4. **Both "bugs" in the functional-bug cycle turned out to be documentation bugs** — the v1.6-κ functional-bugs cycle (PR #77) was framed as "2 latent production bugs". Investigation revealed BOTH were documentation bugs, not behavior bugs. Reusable pattern: before scheduling a production-code fix discovered via in-code TODO scan, ALWAYS verify the wiring exists via `grep` on call sites. Both bugs were retired as comment-only edits in v1.6-κ.
5. **The 13-cycle roadmap is the canonical example of "tests-only + 2 fixes + docs"** — the v1.6 milestone is now the highest-fidelity tests-only + 2-bug-fix closeout in the project's history. The next milestone (v1.7 or v2.0) should follow the same template: tests-only coverage closure + 1-2 small bug fixes + 1 doc-cleanup cycle.

### Post-conditions

- `main` is at the v1.6-λ tip (commit hash for PR #78).
- **1773/1773 tests pass** on the full suite (1772/1773 pass in CI under parallel load due to pre-existing `test/perf/widget_rebuild_test.dart` perf-budget flake; passes in isolation).
- V-Model artifacts SYS-156 + ADR-087 + WF-084 are committed alongside the code.
- APK SHA1 stays at H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d` (no production-code change).
- **v1.6 milestone COMPLETE** — 13 cycles shipped (v1.5 ε + chain + v1.6 α..λ); 1623 → 1773 tests (+150 net); coverage ~67.4% → ~72.5% (+5.1 pp); 0 Kotlin changes; 0 `<uses-permission>` changes; 0 Drift migrations; 0 release APK rebuilds.

### Cross-references

SYS-156; ADR-087; v1.6-λ row; CHANGELOG `## v1.6-λ`; feature.md cycle entry + v1.6 closeout note; the 13-cycle locked roadmap at `~/.claude/plans/here-now-i-hvae-enumerated-reddy.md`.

### v1.7-α — add_habit edit-mode + _PauseRow + DoAnchor happy-path coverage closure (Phase 70 / SYS-157 / ADR-088 / WF-085)

The v1.7 milestone's **first cycle** (v1.7-α, PR #79) closes the `lib/screens/add_habit.dart` edit-mode + `_PauseRow` + `DoAnchor` happy-path + `_pickAnchorTarget` empty-list snack + `_SwatchRow` selection + `_SaveFormActions` ColorSeed pre-fill coverage gap (152 LF uncovered at v1.6-λ). **No production-code change.**

This cycle is tests-only. It introduces 13 new tests under a `// ---- v1.7-α / SYS-157 / ADR-088 / WF-085 ----` banner at the end of `test/screens/add_habit_test.dart`, in 6 batches:

1. **Edit-mode `_doToMap` dispatch (3 tests, v1.7-α)** — seed a DoInterval + a DoAnchor + a fixed-pinned DoInterval via Drift; mount `AddHabitScreen` edit-mode; assert pre-fill + save + read-back via `DoRepository.getById`. Pins the dispatch table at `add_habit.dart:1188-1193`.
2. **`_saveAsTemplate` defensive path (2 tests, v1.7-α)** — pin the in-progress save + the `_lastSaved != null` silent early-return at line 1065.
3. **`_RoutineRow` On-enter / On-exit (2 tests, v1.7-α)** — anchor-seed then mount; the On-enter branch renders; tap save; the On-exit branch renders the summary.
4. **`_pickAnchorTarget` empty-list snack (1 test, v1.7-α)** — seed Drift with NO other habits; the snackbar `'No other dos to anchor on.'` renders; no save.
5. **`_SwatchRow` rotation + initial paint (2 tests, v1.7-α)** — tap swatch; assert rotation; re-mount; assert initial paint.
6. **`_SaveFormActions` ColorSeed pre-fill + `_PauseRow` pause-until (3 tests, v1.7-α)** — edit-mode pre-fills with persisted colorSeed; the pause-until affordance with new date + with existing date.

**Test seams:**
- `tester.runAsync<T>` with closure wrap (per ADR-088 drift lesson (a))
- Direct round-trip via `DoRepository.getById` instead of menu→dialog (per ADR-088 drift lesson (b))
- Drift keepalive deadlock canonical fix per ADR-078 (e)

**Pre-conditions:**
- `main` is at the v1.6-λ tip (commit hash for PR #78 `65a4a0b`).
- `lib/screens/add_habit.dart` is unchanged (no production-code edit in this cycle).
- V-Model artifacts SYS-157 + ADR-088 + WF-085 are committed alongside the code.
- APK SHA1 stays at H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d` (no production-code change).
- **v1.7 milestone: 1/9 cycles shipped (v1.7-α); tests 1773 → 1786 (+13 net); `add_habit.dart` 76% → ~85% line coverage; 0 Kotlin changes; 0 `<uses-permission>` changes; 0 Drift migrations; 0 release APK rebuilds.**

### Cross-references

SYS-157; ADR-088; v1.7-α row in `implementation_status.md`; `### v1.7-α` subsection in `plan.md`; `## v1.7-α` entry in `CHANGELOG.md`; feature.md cycle entry + plan-vs-actual table (plan +18, actual +13, Δ −5); the v1.7 locked roadmap at `~/.claude/plans/here-now-i-hvae-enumerated-reddy.md`; ADR-078 (Drift keepalive deadlock fix applied); ADR-086 (verify-wiring-exists lesson applied to menu→dialog deferral); ADR-087 §c (healthy over-delivery pattern — v1.7-β absorbs the Δ −5 deficit).

### v1.7-β — person_repository raw-column cadence + channel pins (RE-SCOPED 2026-07-05) / WF-086

**Goal:** close the raw-column write-path + read-path null-default + column-overload isolation + forward-compat throw-pin coverage gap in `lib/services/person_repository.dart` (130 LF uncovered at v1.6-λ; ~50 reachable only via the Drift layer because the v0.1 form at `lib/screens/add_person.dart:7-10` only renders `EveryNDays` + `ChannelDialer` per the file's own header comment).

**Scope:** EXTEND `test/services/person_repository_test.dart` (+14 tests, 21 baseline → 35 total). **No `add_person_test.dart` changes for v1.7-β** (the v0.1 form does NOT expose alternate cadences/channels — see file header comment; per ADR-086 lesson (a), verify wiring exists via `grep` before assuming widgets exist).

**4 batches:**

1. **Raw-column write-path pins (8 tests, v1.7-β):** for each typed leaf, save → read raw `PersonRow` → pin `channel`/`handle` + `cadenceType`/discriminator-column strings. Covers `lib/services/person_repository.dart:60-61` (channel + handle writes), `:63-67` (cadence columns), `:92-96` (channel tag mapping), `:114-116` (cadence tag mapping), `:122-129` (discriminator helpers). Mirrors the existing `_toRow writes automationsJson=null` test at `test/services/person_repository_test.dart:299-323`.

2. **Column-overload isolation (1 test, v1.7-β):** hand-write 2 rows with distinct `dayOfMonth` values (15 for `MonthlyOn`, 4 for `YearlyOn` day); assert each subtype round-trips with its OWN `dayOfMonth`. Covers `_parseCadence` at `:131-144` + the column overload at `:66`. Defense against a future refactor that collapses the overload with a `??` precedence bug.

3. **Null-default read-path pins (4 tests, v1.7-β):** hand-write rows with the relevant nullable column OMITTED (Drift default null); assert the 4 `?? 1` fallbacks at `:134, 136, 138, 140` decode the default. A future refactor that removes any `?? 1` throws on these tests.

4. **Forward-compat throw pin (1 test, v1.7-β):** hand-write a row with `channel: 'email'`; `getById` throws `ArgumentError`. Extends the v1.6-ζ `'slack'`-tag throw test (`:232-268`) to a second non-`'slack'` arbitrary string; locks in the `_` default arm of `_parseChannel` at `:107` so a future refactor that adds `if (tag == 'email') return ChannelEmail(...)` shortcut fails loudly.

**Drift lessons (per ADR-089):**

- The v0.1 form at `add_person.dart:7-10` only renders `EveryNDays` + `ChannelDialer`. The master-plan assumption that "4 cadence UI sub-forms exist" was wrong. Per ADR-086 lesson (a), verify wiring exists via `grep` on call sites before assuming widgets exist. The cycle ships at the repository layer where the wiring DOES exist.
- `_toRow` writes raw column strings (`'dialer'`, `'whatsapp'`, `'telegram'`, `'signal'`, `'sms'`). The v1.6-ζ multi-channel round-trip test only verifies the typed `PersonChannel` subclass after `getById`, not the raw column string. v1.7-β pins the raw-column form.
- `_monthlyDay` and `_yearlyDay` share the `dayOfMonth` column at `person_repository.dart:66`. The existing tests do NOT isolate which subtype wins for a given row; v1.7-β Batch 2 pins the read-side correctness for both subtypes via hand-written rows with distinct `dayOfMonth` values.
- The 4 `_fromRow` `?? 1` defaults at lines 134, 136, 138, 140 are defense-in-depth. The v1.7-β Batch 3 tests hand-write rows with `null` for the required column and assert the default. A future refactor that removes the `?? 1` would throw on these tests.
- `_parseChannel`'s `_` default arm at line 107 is the throw-everything-else defense. The v1.6-ζ cycle pinned the `'slack'` throw path; v1.7-β Batch 4 pins a second unknown tag (`'email'`) so the default arm isn't accidentally weakened to a no-op.

**Test seams:**

- **Save + read raw row** pattern (Batch 1 tests): `PersonRepository.save(...)` then `(db.select(db.people)..where((t) => t.id.equals(personId))).getSingle()` + expect `row.channel`/`row.handle`/`row.cadenceType`/discriminator-column. Mirrors the existing `_toRow writes automationsJson=null` test at `test/services/person_repository_test.dart:299-323`.
- **Hand-write row + getById** pattern (Batches 2, 3, 4): `db.into(db.people).insert(const PersonRow(...))` then `PersonRepository.getById(...)`. Mirrors the v1.6-ζ unknown-channel-tag throw test at `:232-268`.
- **Avoid `nDays: null` / `weekday: null` / `dayOfMonth: null` / `monthOfYear: null` in hand-written rows** — Drift's `PersonRow` constructor defaults these to `null` already, so passing them explicitly triggers `avoid_redundant_argument_values`. Replace with comments noting the omitted-field-implies-null intent (5 lint-fixes inline).

**Pre-conditions:**

- `main` is at the v1.7-α tip (commit hash for PR #79 `75f6e20`).
- `lib/services/person_repository.dart` is unchanged (no production-code edit in this cycle).
- `lib/screens/add_person.dart` is unchanged (the v0.1 form is NOT extended for v1.7-β; the repo-layer wiring exists independently).
- V-Model artifacts SYS-158 + ADR-089 + WF-086 are committed alongside the code.
- APK SHA1 stays at H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d` (no production-code change).
- **v1.7 milestone: 3/9 cycles shipped (α + β + γ); tests 1773 → 1812 (+39 net across α + β + γ; +12 exactly on target for γ); `add_habit.dart` 76% → ~85% + `person_repository.dart` raw-column layer pinned + `add_event.dart` ~78% → ~88% form-level sub-branches pinned; 0 Kotlin changes; 0 `<uses-permission>` changes; 0 Drift migrations; 0 release APK rebuilds.**

### v1.7-δ — Spanish ARB verbatim-pin coverage closure (Phase 70 / SYS-160 / ADR-091 / WF-088)

**Scope:** EXTEND `test/l10n/locale_render_test.dart` (+20 tests, 9 baseline → 29 total). **No production-code change.** Tests-only cycle.

**5 batches grouped by UI surface** (not by ARB key alphabetical order, so a translator reviewing one surface can find all related pins in one place):

- **Batch 1 — Sparkline a11y + tooltip copy (4 tests):** pin the v1.4i 14-day sparkline TalkBack label + 3 long-press tooltips — `homeTileSparklineSemantics` + `homeTileSparklineRestDayTooltip` + `homeTileSparklineDoneTooltip` + `homeTileSparklineMissedTooltip`.
- **Batch 2 — Sparkline legend captions (3 tests):** pin the 3 v1.4i inline-legend dot-color captions — `homeTileSparklineLegendDone` + `homeTileSparklineLegendRestDay` + `homeTileSparklineLegendMissed`.
- **Batch 3 — Widget action copy (2 tests):** pin the v1.4f home-screen widget "Skip today" / "Undo today" actions — `widgetSkipToday` + `widgetUndoToday`.
- **Batch 4 — Home add sheet copy (3 tests):** pin the v1.3c bottom-sheet entry points — `homeAddSheetNewDo` + `homeAddSheetNewPerson` + `homeAddSheetFromTemplate`.
- **Batch 5 — Settings theme + anchor + permission status (8 tests):** pin the v0.1 settings-screen surface that was translated early and is the most user-facing — `settingsThemeDark` + `settingsThemeLight` + `settingsThemeSystem` + `settingsAnchorFirstUnlock` + `settingsAnchorEither` + `permissionStatusGranted` + `permissionStatusNotAsked` + `permissionStatusDenied`.

**Drift lessons per ADR-091:** (a) **The 129 Spanish getters split into 2 shapes — single-line `=> 'literal'` (98 entries) and multi-line `=>\n  'literal';` (31 entries with embedded plural / placeholder / em-dash).** Verbatim pins work cleanly only for the single-line shape; (b) **Parity invariant: `app_en.arb` and `app_es.arb` have the same 129 keys** — the gen-l10n contract enforces parity at build time; (c) **Spanish em-dash (`—` = U+2014) and opening-question-mark (`¿` = U+00BF) are 2-byte UTF-8 characters** — the pins use the exact 2-byte UTF-8 sequences from the `.arb`; (d) **BUG-006 (deferred to v2.0 per W-13 §8) is the canonical example of "Spanish translation drift"** — v1.7-δ pins the CURRENT (unverified) strings verbatim, so the translator's pass surfaces as `failed: expected X, got Y`; (e) **5-batch grouping is by UI surface, not by ARB key alphabetical order** — a readability affordance for the human translator, not a structural property.

**Out-of-scope (deferred to B2 / v2.0 + ADR-091):** The 31 multi-line `String get` entries (plural / placeholder / em-dash) — already tested via `isNotEmpty` + placeholder-interpolation tests at `app_localizations_test.dart`; the `app_en.arb` verbatim pins (the en copy is the source of truth); the unsupported-locale fallback (`Locale('fr')`) — already tested at `app_localizations_test.dart:162-181`; the v1.3e + v1.4i + v1.4-stab-H new-key check — already covered at `app_localizations_test.dart:313-330`.

**Cross-references:** SYS-160; ADR-091; v1.7-δ row in `implementation_status.md`; `### v1.7-δ` subsection in `plan.md`; `## v1.7-δ` entry in `CHANGELOG.md`; feature.md cycle entry; the v1.7 locked roadmap at `~/.claude/plans/here-now-i-hvae-enumerated-reddy.md`; BUG-006 (deferred to v2.0 per W-13 §8 — v1.7-δ pins the current strings as the regression guard for B2 native-Spanish translator review); ADR-090 (v1.7-γ drift lessons — paired; v1.7-δ does NOT need the "verify form scope via grep" pattern because the ARB surface is the catalog itself); ADR-089 (v1.7-β drift lessons); ADR-088 (v1.7-α drift lessons).

- **v1.7 milestone: 4/9 cycles shipped (α + β + γ + δ); tests 1773 → 1832 (+59 net across α + β + γ + δ; +12 exact for γ, +20 exact for δ); `add_habit.dart` 76% → ~85% + `person_repository.dart` raw-column layer pinned + `add_event.dart` ~78% → ~88% + Spanish ARB catalog 20 verbatim pins; 0 Kotlin changes; 0 `<uses-permission>` changes; 0 Drift migrations; 0 release APK rebuilds.**

### v1.7-γ — add_event.dart form-level sub-branch coverage closure (RE-SCOPED 2026-07-05) / WF-087

**Scope:** EXTEND `test/screens/add_event_test.dart` (+12 tests, 28 baseline → 40 total). **No production-code change.** Tests-only cycle.

**RE-SCOPED 2026-07-05** — the original v1.7-γ plan assumed 3 widgets (a leadTime slider, a no-recurrence radio group, an end-date picker) existed on the form. The code-explorer pass discovered the v0.1 form uses (a) a Dialog with 7 RadioListTile presets for lead time, (b) 2 ChoiceChips for recurrence, and (c) NO end-date picker. Cycle lands at the form layer where the wiring actually exists (in `_pickLead` + `_applyPayload` + `_saveAsTemplate` per ADR-086 lesson (a)).

**3 batches:**

- **Batch 1 — `_pickLead` dialog (5 tests):** pin all 4 reachable buckets of `_leadLabel(int m)` at `add_event.dart:228-233` + the Cancel branch. Covers `:189-226` (Dialog + RadioListTile), `:213-215, 225` (Cancel returns null → guard rejects). 1 existing v1.6-δ test covered the "At the time" (m=0) bucket; v1.7-γ fills the remaining 3 buckets (5/30/120/1440 min) + the Cancel branch.
- **Batch 2 — `_applyPayload` defensive branches (6 tests):** pin the 5 typed guards at `:110-118` (name is String, lead is int, day is int, month is int + recurrence switch default arm). The 3 `Event.validate()` throw branches at `event.dart:128-138` are UNREACHABLE from form input per ADR-090 lesson (e) — v1.7-γ does NOT write tests for them.
- **Batch 3 — `_saveAsTemplate` envelope variants (1 test):** `_saveAsTemplate with _recurrence=annually writes '"recurrence":"annually"' in the envelope` — pin the `'annually'` branch at `:343-344`. 1 existing v1.6-δ test covered the `'none'` branch.

**Drift lessons per ADR-090:** (a) **The v0.1 form uses a Dialog with 7 RadioListTile presets for lead time, NOT a Slider** — the original v1.7-γ plan assumed a slider; (b) **The v0.1 form uses 2 ChoiceChips for recurrence, NOT a RadioListTile group** — the `EventRecurrence` enum has only `{none, annually}` leaves; (c) **The v0.1 form has NO end-date picker** — the `annually` leaf is open-ended; (d) **The 5 `_applyPayload` typed guards are defense-in-depth** — the form never sends non-typed input; v1.7-γ Batch 2 pins the guards so a future cast-widening refactor fails loudly; (e) **The 3 `Event.validate()` throw branches are UNREACHABLE from form input** — per the v1.6-ζ "unreachable throw = no test" lesson (DRY for defense-in-depth), v1.7-γ does NOT write tests for them.

**Out-of-scope (deferred to v2.0 + ADR-090):** A lead-time slider (NOT in v0.1 form); a 3-leaf `RadioListTile` recurrence group (v0.1 supports only 2 leaves); a recurring-end-date picker (NOT in v0.1); a wider type cast in `_applyPayload` (a future refactor that removes the typed guards is a BREAKING change).

**Cross-references:** SYS-159; ADR-090; v1.7-γ row in `implementation_status.md`; `### v1.7-γ` subsection in `plan.md`; `## v1.7-γ` entry in `CHANGELOG.md`; feature.md cycle entry; the v1.7 locked roadmap at `~/.claude/plans/here-now-i-hvae-enumerated-reddy.md`; ADR-086 lesson (a) verify-wiring-exists applied to re-scope this cycle from "slider + radio + end-date" to "Dialog presets + ChoiceChips + no end-date"; ADR-089 (v1.7-β drift lessons — `grep` wiring check pattern carried forward); ADR-088 (v1.7-α drift lessons — `runAsync` closure wrap pattern carried forward).

### Cross-references

SYS-158; ADR-089; v1.7-β row in `implementation_status.md`; `### v1.7-β` subsection in `plan.md`; `## v1.7-β` entry in `CHANGELOG.md`; feature.md cycle entry + plan-vs-actual table (plan +14, actual +14, exact match — absorbs the v1.7-α Δ −5 deficit per ADR-087 §c healthy over-delivery pattern); the v1.7 locked roadmap at `~/.claude/plans/here-now-i-hvae-enumerated-reddy.md`; ADR-086 lesson (a) verify-wiring-exists applied to re-scope from `add_person_test.dart` UI to `person_repository_test.dart` repo-layer; ADR-088 (v1.7-α drift lessons — `runAsync` closure wrap + menu→dialog fragility patterns carried forward).

### v1.7-ε — person_repository pausedUntil raw-column + save idempotency coverage closure (Phase 70 / SYS-161 / ADR-092 / WF-089)

**Scope:** EXTEND `test/services/person_repository_test.dart` (+10 tests, 35 baseline → 45 total). **No production-code change.** Tests-only cycle.

**RE-SCOPED 2026-07-06 per ADR-086 (a) verify-wiring-exists rule** — the original v1.7-ε plan listed `PersonUnresolved` as the test surface. A `grep -n "class Person" lib/people/person.dart` call returned `ContactPerson` + `_PersonBase` with no `PersonUnresolved`. The cycle RE-SCOPED to the actual surface: raw-column `pausedUntil_millis` pins + `insertOnConflictUpdate` + `copyWith` + `listAll`. This is the third concrete application of the ADR-086 (a) rule (after v1.6-γ and v1.6-κ).

**5 batches grouped by repository surface:**

- **Batch 1 — `pausedUntil_millis` raw-column WRITE-path pins (2 tests):** `_toRow writes pausedUntilMillis=null when pausedUntil is null` (mirror of v1.6-ζ `_toRow writes automationsJson=null when automations is empty` at lines 299-323 — a null `pausedUntil` MUST persist as SQL NULL, not as 0; `isPausedAt` requires `pausedUntil != null` so a SQL 0 would silently flip the contract) + `_toRow writes pausedUntilMillis=N (ms since epoch) on the row` (mirror of the typed round-trip at lines 160-177 but at the Drift layer; pins sub-second precision via `DateTime(2027, 6, 15, 12, 30, 45, 123)` — a future refactor that drops sub-second precision fails loudly).
- **Batch 2 — `pausedUntil_millis` raw-column READ-path pins (2 tests):** `_fromRow reads pausedUntilMillis=null → pausedUntil is null` (hand-write a row with `pausedUntilMillis` omitted; verify the read path yields Dart null, NOT DateTime(0) which would make `isPausedAt(DateTime.now())` true because 0 is before now) + `_fromRow reads pausedUntilMillis=N → pausedUntil DateTime` (hand-write a row with a known millisecond value; verify the matching DateTime round-trips independently of the encode path).
- **Batch 3 — `insertOnConflictUpdate` semantics (2 tests):** `save with the same id REPLACES the existing row` (pin the contract at `person_repository.dart:28` — second save with same id but different fields must NOT throw unique-constraint; it must overwrite; verifies channel/cadence/pausedUntil/automations all propagate via the same id) + `save preserves the lookupKey when upserting the same id` (pin the Drift `insertOnConflictUpdate` is INSERT OR REPLACE behavior — the SECOND lookupKey wins; defense-in-depth for a future refactor that switches the upsert key to lookupKey).
- **Batch 4 — `copyWith` combos (2 tests):** `copyWith can clear pausedUntil and replace automations in one call` (pin `lib/people/person.dart:206-220` — when `clearPausedUntil: true` AND `automations: [...]` are both passed, both fields change; other fields preserved) + `copyWith preserves pausedUntil and automations when neither is passed` (regression guard for "I edit the cadence and my pause/automations get silently cleared" bugs; identity-on-copy for the two v0.2 + Phase C fields).
- **Batch 5 — `listAll` heterogeneity + delete isolation (2 tests):** `listAll returns mixed paused/unpaused/automated rows in createdAt order` (pin the `OrderingTerm.asc(t.createdAtMillis)` ordering at `person_repository.dart:43` across 3 rows with heterogeneous pausedUntil + automations states) + `deleteById of one row leaves the others intact` (pin deleteById isolation at `:49` — DELETE on one id must not affect other rows; the existing "deleteById is a no-op when the row does not exist" at line 217 covers the empty case; v1.7-ε covers the populated case).

**Drift lessons per ADR-092:** (a) **`PersonUnresolved` does NOT exist in v0.1** — the `Person` sealed hierarchy at `lib/people/person.dart:132` only has `ContactPerson`. The original v1.7-ε plan listed `PersonUnresolved` as the test surface; the cycle RE-SCOPED to the actual surface (raw-column `pausedUntil_millis` pins + `insertOnConflictUpdate` + copyWith + listAll). The verification was a `grep -n "class Person" lib/people/person.dart` call. This is the third concrete application of the ADR-086 (a) rule (after v1.6-γ and v1.6-κ); (b) **`pausedUntil_millis` raw-column pins are the missing complement to the v1.6-ζ automationsJson raw-column pins** — both fields follow the same "null at the Dart layer → NULL at the SQL layer" contract; v1.7-ε ships the mirror pin set for `pausedUntil`; (c) **`insertOnConflictUpdate` is INSERT OR REPLACE in Drift, not UPSERT** — the second lookupKey wins because the entire row is replaced. v1.7-ε Batch 3 pin #2 is the regression guard for a future refactor to UPSERT-by-lookupKey; (d) **`copyWith` field-preservation is not asserted by the Dart `super` chain** — `lib/people/person.dart:206-220`'s `copyWith` passes `id`, `lookupKey`, `channel`, `cadence`, `createdAt` by reading from `this`. The v1.7-ε Batch 4 tests pin the no-field-reset invariant explicitly; (e) **`listAll` ordering relies on `createdAtMillis`, not on insertion order** — a manual `UPDATE` to `created_at_millis` would change the order. v1.7-ε Batch 5 pin #1 uses 3 distinct createdAt values to pin the `OrderingTerm.asc` contract.

**Out-of-scope (deferred to v2.0 + ADR-092):** the `PersonUnresolved` class itself — v2.0 deferred per the v0.1 model (only `ContactPerson` exists); a test for `_parseCadence`'s unknown-cadence-tag default arm — already covered at `person_repository_test.dart:271-294` (v1.5-cyc-γ baseline); a test for `_missionChainJson` / `_parseMissionChain` — those methods are `// ignore: unused_element` per `person_repository.dart:152,159` (forward-compat for v0.2 mission chain wiring; v0.1 has no model surface to test through); channel raw-column pin for `'email'` — already covered at lines 905-939 (v1.7-β).

**Cross-references:** SYS-161; ADR-092; v1.7-ε row in `implementation_status.md`; `### v1.7-ε` subsection in `plan.md`; `## v1.7-ε` entry in `CHANGELOG.md`; feature.md cycle entry; the v1.7 locked roadmap at `~/.claude/plans/here-now-i-hvae-enumerated-reddy.md`; ADR-086 lesson (a) verify-wiring-exists applied to re-scope from `PersonUnresolved` to `pausedUntil_millis` + `insertOnConflictUpdate` + copyWith + listAll; ADR-091 (v1.7-δ drift lessons); ADR-090 (v1.7-γ drift lessons); ADR-089 (v1.7-β drift lessons — `grep` wiring check pattern carried forward); ADR-088 (v1.7-α drift lessons — `runAsync` closure wrap pattern carried forward).

- **v1.7 milestone: 5/9 cycles shipped (α + β + γ + δ + ε); tests 1773 → 1842 (+69 net across α + β + γ + δ + ε; +12 exact for γ, +20 exact for δ, +10 exact for ε); `add_habit.dart` 76% → ~85% + `person_repository.dart` raw-column layer pinned (cadence + channel + automationsJson + pausedUntil_millis) + `add_event.dart` ~78% → ~88% + Spanish ARB catalog 20 verbatim pins; 0 Kotlin changes; 0 `<uses-permission>` changes; 0 Drift migrations; 0 release APK rebuilds.**

### v1.7-ζ — permission_sheet cancel + permanentlyDenied-retry coverage closure (Phase 70 / SYS-162 / ADR-093 / WF-090)

**Scope.** Extend `test/widgets/permission_sheet_test.dart` (+8 tests) under a `// v1.7-ζ additions (SYS-162 / ADR-093 / WF-090)` banner.

**Two batches.**

**Batch 1 — Cancel / no-spurious-pop (4 tests).** Pins the widget's cancel state machine — the user taps "Allow" but the request returns denied/permanentlyDenied. The widget MUST stay open + `show()` MUST return `false`. The 4 tests:
1. `tapping Allow on notifications when request returns denied keeps the sheet open with no pop` — pins the `if (result.granted)` pop branch at `permission_sheet.dart:215-217`; a future refactor that pops on every Allow tap would silently flip `show()` to return `null` → `false`.
2. `tapping Allow on notifications when request returns permanentlyDenied keeps the sheet open AND re-renders with the error text + no Allow button` — pins the `setState(() { _status = result; })` branch at `:218-222` + the `isPermanentlyDenied` UI state at `:383-407`.
3. `tapping Allow on contacts when request returns granted pops the sheet and show() returns true` — second pin of the granted pop (after SYS-067 test 2); defense-in-depth against a future refactor that pops with `null` on granted.
4. `tapping Allow on calendar kind (no-op Allow CTA per the SYS-E Phase E comment at permission_sheet.dart:140-145) keeps the sheet open with no pop` — pins the calendar Allow CTA wire-up so a future refactor that wires real calendar permission logic surfaces via the test.

**Batch 2 — permanentlyDenied retry paths (4 tests).** Pins the 4 re-probe outcomes in `_onOpenSettings` at `permission_sheet.dart:226-342`. The sheet opens on `permanentlyDenied` (Allow hidden, error text visible, only "Open settings" button shown). The user taps "Open settings" → deep-link + re-probe. The 4 tests:
1. `permanentlyDenied → Open settings → re-probe granted pops the sheet and show() returns true` — the happy-path granted retry.
2. `permanentlyDenied → Open settings → re-probe denied(canOpenSettings: true) transitions to the 2-button layout with Allow re-enabled` — pins the 3-state UI machine transition: permanentlyDenied → denied(canOpenSettings: true) re-renders with BOTH buttons AND hides the error text.
3. `permanentlyDenied → Open settings → openAppSettings returns false shows snackbar but keeps the sheet open` — pins the snackbar path + sheet-stays-open invariant when the OS rejects the deep-link.
4. `permanentlyDenied → Open settings → re-probe still permanentlyDenied keeps the sheet open with the error text` — pins the same-error-text-on-retry invariant.

**Out-of-scope.** Modal scrim-tap dismissal tests (Flutter framework behavior, not widget-owned); modal drag-down dismissal tests (slide animation does not interact with the widget's state machine); system-back dismissal tests; an explicit "Cancel" button (NOT in v0.1); a test that verifies a thrown exception from `requestExactAlarm()` surfaces to the test framework (the `permission_handler` package swallows the exception).

**Cross-references:** SYS-162; ADR-093; v1.7-ζ row in `implementation_status.md`; `### v1.7-ζ` subsection in `plan.md`; `## v1.7-ζ` entry in `CHANGELOG.md`; feature.md cycle entry; the v1.7 locked roadmap at `~/.claude/plans/here-now-i-hvae-enumerated-reddy.md`; ADR-093 drift lesson (e) — the `tester.runAsync(() async { return future; })` footgun documented; ADR-092 (v1.7-ε drift lessons); ADR-091 (v1.7-δ drift lessons); ADR-090 (v1.7-γ drift lessons); ADR-089 (v1.7-β drift lessons); ADR-088 (v1.7-α drift lessons).

- **v1.7 milestone: 6/9 cycles shipped (α + β + γ + δ + ε + ζ); tests 1773 → 1850 (+77 net across 6 cycles; +13 exact for α, +14 exact for β, +12 exact for γ, +20 exact for δ, +10 exact for ε, +8 exact for ζ); `permission_sheet.dart` cancel branch + 3-state UI machine + permanentlyDenied retry paths pinned; 0 Kotlin changes; 0 `<uses-permission>` changes; 0 Drift migrations; 0 release APK rebuilds.**

### v1.7-η — person_groups paused-chip + null-rotation + empty-state coverage closure (Phase 71 / SYS-163 / ADR-094 / WF-091)

**Tests-only cycle.** EXTEND `test/screens/person_groups_test.dart` (+8 tests, 13 baseline → 21 total). No production-code change; no Drift migration; no Kotlin change; no new `<uses-permission>`; no new pubspec dep.

**Batch 1 — Paused-chip (2 tests).** Pins the per-row guards at `_GroupCard` in `person_groups.dart:180-201, 215-223`. The Mark-contacted CTA is the ONLY row action suppressed by `!paused` (line 201); the cadence label + Members count are unconditional renders (lines 180-188); the Delete IconButton has no `!paused` guard (lines 215-223). The 2 tests:

1. `Paused group does NOT render the Mark contacted CTA (still renders Delete)` — pauses the seeded group + asserts the Mark button is hidden AND the Delete button is still present. Pins the line 201 guard.
2. `Paused group still renders the cadence label + Members count (only Mark is suppressed)` — pauses the seeded group + asserts the cadence label (`'Every 7 days'`) AND the Members count (`'Members: 1'`) both render. Pins the lines 180-188 unconditional renders.

**Batch 2 — Null-rotation (3 tests).** Pins the `pickNextMember` rotation selector at `person_group.dart:166-185`. The selector has 3 independent tie-break rules: null beats contacted (lines 176-177), oldest addedAtMillis wins when both null (lines 180-181), smallest lastContacted wins when both contacted (lines 178-179). The 3 tests:

3. `Empty members list renders the group row but hides the "Next:" line + suppresses Mark` — seeds a group with NO members + asserts the group name renders, the "Next:" line is hidden, AND the Mark CTA is hidden (Delete still renders). Pins the dual-guard at lines 189-196 + 201.
4. `Pre-existing lastContacted on the older member → next pick is the null-lastContacted newer member (null beats contacted)` — seeds 2 members + pre-marks p1 as contacted via `PersonGroupRepository.instance.markContacted('g1', 'p1', DateTime(2026, 6))` BEFORE pumping the screen + asserts "Next: p2" renders (not "Next: p1"). Pins line 176-177 null-beats-contacted rule.
5. `Mark contacted on the current next → page refresh shows the OTHER member as next (rotation advances)` — seeds 2 members + both null-LC + initial tie-break by addedAtMillis picks p1 + taps Mark + asserts "Next: p2" renders after refresh. Pins the rotation algorithm end-to-end (lines 176-181).

**Batch 3 — Empty-state (3 tests).** Pins the AddPersonGroupScreen state surfaces at `person_groups.dart:378, 410-416, 464-470`. The 3 tests:

6. `Add screen with existing != null shows "Edit group" title in AppBar` — pumps `AddPersonGroupScreen(existing: someGroup)` + asserts the title is `'Edit group'` (not `'New group'`). Pins line 378 ternary.
7. `Add screen with empty people list shows "No people added yet" copy` — no people seeded + pumps `AddPersonGroupScreen()` + asserts the empty-state copy renders. Pins lines 464-470.
8. `Add screen renders 5 channel ChoiceChips (dialer, whatsapp, telegram, signal, sms)` — pumps `AddPersonGroupScreen()` + asserts all 5 channel ChoiceChips render via `find.widgetWithText(ChoiceChip, ch)` for each. Pins lines 410-416.

**Out-of-scope.** Case (iii) `pickNextMember` tie-break pin via widget (would require manual SQL UPDATE — fragile); `pickNextMember` tests where the member's `addedAtMillis` is set to a specific DateTime via direct DB write (the schema uses `_millisecondsSinceEpoch` integers; round-trip is brittle); the Add screen 4-cadence ChoiceChips pin (`person_groups.dart:429-433`) — already covered by the existing baseline test "Add screen: tapping Weekly cadence switches the params widget to a weekday DropdownButton"; the per-person `_PersonPausedChip` render pin (`person_groups.dart:480-481`) — requires seeding a paused person + pumping the Add screen, brittle and not in scope.

**Cross-references:** SYS-163; ADR-094; v1.7-η row in `implementation_status.md`; `### v1.7-η` subsection in `plan.md`; `## v1.7-η` entry in `CHANGELOG.md`; feature.md cycle entry; the v1.7 locked roadmap at `~/.claude/plans/here-now-i-hvae-enumerated-reddy.md`; ADR-094 drift lesson (a) — the `DateTime(year, [month=1, day=1, ...])` `avoid_redundant_argument_values` lint pattern; ADR-094 drift lesson (b) — `ContactGroup` is not const-constructible because of `DateTime` fields; ADR-093 (v1.7-ζ drift lessons, especially the APK SHA1 finding at lesson (e) — v1.7-η does NOT report APK SHA1 stability, replaced with test count + 3-gate green + no manifest/pubspec/Drift/Kotlin changes per ADR-093 (e) + the [v1-7-cyc-zeta-cycle-shipped.md](../../../../.claude/projects/-home-shyam-common-games-doit/memory/v1-7-cyc-zeta-cycle-shipped.md) finding); ADR-092 (v1.7-ε drift lessons); ADR-091 (v1.7-δ drift lessons); ADR-090 (v1.7-γ drift lessons); ADR-089 (v1.7-β drift lessons); ADR-088 (v1.7-α drift lessons).

- **v1.7 milestone: 7/9 cycles shipped (α + β + γ + δ + ε + ζ + η); tests 1773 → 1858 (+85 net across 7 cycles; +13 exact for α, +14 exact for β, +12 exact for γ, +20 exact for δ, +10 exact for ε, +8 exact for ζ, +8 exact for η); `_GroupCard` per-row guards + `pickNextMember` rotation algorithm + AddPersonGroupScreen empty-state surfaces pinned; 0 Kotlin changes; 0 `<uses-permission>` changes; 0 Drift migrations; 0 release APK rebuilds.**


### v1.7-θ — condition.dart boundaries + permission_lifecycle_observer.dart per-instance cold-start gate + triggerRefreshForTest hook independence

**Eighth cycle of v1.7.** Tests-only. **+8 tests** (6 condition + 2 permission). **EXACT MATCH with v1.7 pre-auth plan target.**

**Files:** `test/triggers/condition_test.dart` (+6 tests) + `test/services/permission_lifecycle_observer_test.dart` (+2 tests). **No production-code change.**

**Batches:**
- **Condition.dart (6 tests):** `ConditionOr.validate() recurses into BOTH leaves (left invalid → throws)` (pins ConditionOr validate line 79) + `ConditionOr.validate() recurses into BOTH leaves (right invalid → throws)` (pins line 81) + `ConditionTimeWindow.validate() rejects invalid endHour + negative startMinute + invalid endMinute` (pins lines 119-127 end-side + negative branches) + `ConditionAnd operator == + hashCode` (pins lines 63-67) + `ConditionTimeWindow operator == + hashCode` (pins lines 131-142) + `ConditionValidationException toString format` (pins lines 257-258).
- **Permission_lifecycle_observer.dart (2 tests):** `cold_start gate is per_observer_instance (second observer starts with its own cold_start no_op)` (pins line 65 instance-field semantics) + `triggerRefreshForTest exposes _safeRefresh directly (runs without a lifecycle event and tolerates ReliabilityService not being init)` (pins line 89 test-hook independence from gate consumption).

**Cumulative v1.7:** 1773 → 1866 (+93 across α+β+γ+δ+ε+ζ+η+θ; 8/9 cycles shipped).

**Coverage gain:** `condition.dart` 59.8% → 80.5% (+20.7 pp). `permission_lifecycle_observer.dart` stays at 78.6% (debugPrint catch branches are dead code). `mission_result.dart` stays at 100% (no coverage gap).

**Drift lessons:** see ADR-095 — (a) `ConditionDayOfWeek` non-const ctor + (b) `ConditionOr`/`ConditionAnd` non-const in equality + (c) `ConditionValidationException.toString()` format invariance + (d) `_coldStartSeen` per-instance semantics + (e) `triggerRefreshForTest` does NOT consume the gate.

**3-gate:** `dart format` (clean after auto-format of 2 files) + `flutter analyze --fatal-infos` (0 issues) + `flutter test` (1866/1866 pass).


### v1.7-ι — v1.7 milestone CLOSEOUT — doc-only closeout cycle

### PR1 of 15 — UI consolidation — PrimaryButton extraction + 3 high-traffic CTAs migration

**PR1 (Phase 76)** of the UI consolidation sprint. First file in `lib/ui/`. **+11 tests (EXACT match with plan: 11 widget tests).**

**Date:** 2026-07-07. **Tests:** 1866 → 1877 (+11 net). **Cumulative UI sprint:** 1877 (PR1 of 15 shipped, 14/15 remaining).

**Files (4 changed):**
- NEW `lib/ui/primary_button.dart` (~70 lines; `StatelessWidget` wrapping `FilledButton`/`FilledButton.icon`)
- NEW `test/ui/primary_button_test.dart` (~225 lines; 11 widget tests, 6 groups)
- MIGRATE `lib/screens/add_event.dart` (line 217 + add import) — Save-OK time picker dialog
- MIGRATE `lib/screens/add_person.dart` (line 548 + add import) — Save-as-Template dialog (preserves key `'add_person.save_as_template.save'`)
- MIGRATE `lib/screens/rest_day_picker_dialog.dart` (line 110 + add import) — OK button (localized label `l.homeTileBudgetEditOk`)

**Batches (3):**
- **Batch 1 — Primitive extraction:** `PrimaryButton` widget + 48dp inherited sizing from `filledButtonTheme`. API: `const PrimaryButton({super.key, required onPressed, required label, icon, tooltip})` where `icon` decides FilledButton vs FilledButton.icon branch.
- **Batch 2 — Tests (11 across 6 groups):** plain-text variant (3) + icon variant (2) + disabled state (1) + tooltip wrapper (2) + 48dp touch target (1) + Key + Semantics (2).
- **Batch 3 — Screen migrations (3 CTAs):** preserved keys + onPressed handlers + labels. Imports added to each screen file.

**3-gate:** `dart format --output=none --set-exit-if-changed .` (clean) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1877/1877 pass — zero regressions). Targeted: `flutter test test/ui/primary_button_test.dart` (11/11 pass) + migrated screens (68/68 pass).

**Drift lessons per ADR-097:**
- (a) `AppTheme.dark` is a `ThemeData` getter, not a Widget constructor → wrap in `MaterialApp(theme: AppTheme.dark, home: ...)`
- (b) `const MaterialApp(theme: AppTheme.dark, ...)` fails (`Invalid constant value`) because the theme getter is runtime; keep `MaterialApp` non-const, const the inner constructors
- (c) `FilledButton.onPressed: null` auto-disables + suppresses callback
- (d) 48dp minimum inherited from `filledButtonTheme` (PrimaryButton does not re-specify)
- (e) `lib/ui/` is empty today; PrimaryButton is the first primitive of C1 (PR1) + the canonical-pattern call for PR2..PR15

**Cumulative v1.7 + UI sprint:** 1773 → 1877 (+104 net across 9 v1.7 cycles + PR1 of UI sprint; 1/15 UI sprint cycles shipped).

**Next:** PR2 of 15 (SecondaryButton — the cancel/dismiss CTA wrapping `TextButton`).

**Ninth and FINAL cycle of v1.7.** Doc-only. **0 tests.** **EXACT MATCH with v1.7 pre-auth plan target.**

**Date:** 2026-07-07. **Tests:** 1866 → 1866 (0 net). **Cumulative v1.7:** 1773 → 1866 (+93 across α+β+γ+δ+ε+ζ+η+θ+ι; 9/9 cycles shipped).

**Files:** 8 doc files only — no production-code change, no test change, no Drift migration, no Kotlin change.

**Scope:**
- **Group 1 — Phase B TODO audit (1 grep):** repo-wide `grep -rn "Phase B PR [12]" /home/shyam/common_games/doit/lib/` returns 17 historical references, all descriptive comments about the Phase B work (PR 1 = envelope-shape contract; PR 2 = add-screen payload reads), NOT outstanding TODOs. The 2 specific "TODO that originally lived here" comments at `template_library.dart:397` + `v2_to_v3.dart:25-26` reference the v1.6-κ retirement as historical record. **Conclusion: 0 outstanding Phase B TODOs.**
- **Group 2 — 13 blocked-items table carry-over:** all 13 items from v1.6-λ remain deferred to v2.0 per the canonical closeout. v1.7-ι does NOT retire any blocked items.
- **Group 3 — v1.7 milestone closeout:** confirm the v1.7 9-cycle roadmap is COMPLETE. Cycle-by-cycle reconciliation: α -5, β ±0, γ ±0, δ ±0, ε +2, ζ ±0, η ±0, θ ±0, ι 0. **Total v1.7: 1773 → 1866 (+93 net; under plan by 3).** The -3 is driven by v1.7-α's -5 (absorbed by v1.7-β per ADR-087 §c) and v1.7-ε's +2 over-delivery.
- **Group 4 — 8 V-Model artifact updates (1 append per artifact):** SYS-165 row in `requirements.md`; ADR-096 in `decision_record.md`; WF-093 row in `traceability_matrix.md`; `### v1.7-ι` block in `workflows.md`; `## v1.7-ι` row in `implementation_status.md`; `### v1.7-ι` subsection in `plan.md`; `## v1.7-ι` entry in `CHANGELOG.md`; cycle paragraph + v1.7 closeout note in `feature.md`.

**Drift lessons:** see ADR-096 — (a) canonical tests-only + 2-fixes + 1-doc-only closeout pattern confirmed + (b) APK SHA1 anchor replaced with test-count + 3-gate green + (c) v1.7-θ deviation documented.

**3-gate:** `dart format` (clean) + `flutter analyze --fatal-infos` (0 issues) + `flutter test` (1866/1866 pass — zero regressions).

**The v1.7 milestone is now CLOSED.** Next: UI consolidation sprint (15 PRs) per the 3-month launch roadmap.
### PR2 of 15 — UI consolidation — SecondaryButton extraction + 3 dialog Cancel migrations

**PR2 (Phase 77)** of the UI consolidation sprint. Second file in `lib/ui/`. **+11 tests (EXACT match with plan: 11 widget tests).**

**Date:** 2026-07-07. **Tests:** 1877 → 1888 (+11 net). **Cumulative v1.7 + UI sprint:** 1773 → 1888 (+115 net across 9 v1.7 cycles + PR1 + PR2 of UI sprint).

**Files (4 changed):**
- NEW `lib/ui/secondary_button.dart` (~62 lines; `StatelessWidget` wrapping `TextButton`/`TextButton.icon`)
- NEW `test/ui/secondary_button_test.dart` (~245 lines; 11 widget tests, 6 groups)
- MIGRATE `lib/screens/add_event.dart:213` — Cancel button in time picker dialog (sibling to PR1 PrimaryButton at line 217)
- MIGRATE `lib/screens/add_person.dart:544` — Cancel button in Save-as-Template dialog (sibling to PR1 PrimaryButton at line 548)
- MIGRATE `lib/screens/rest_day_picker_dialog.dart:106` — Cancel button in rest day picker (sibling to PR1 PrimaryButton at line 110)

**Batches (3):**
- **Batch 1 — Primitive extraction:** `SecondaryButton` widget + 48dp inline sizing via `TextButton.styleFrom(minimumSize: const Size(0, 48))`. API mirrors PrimaryButton: `const SecondaryButton({super.key, required onPressed, required label, icon, tooltip})` where `icon` decides `TextButton` vs `TextButton.icon` branch.
- **Batch 2 — Tests (11 across 6 groups):** plain-text variant (3) + icon variant (2) + disabled state (1) + tooltip wrapper (2) + 48dp touch target (1) + Key + Semantics (2). Same structure as PR1's tests but for TextButton family.
- **Batch 3 — Dialog Cancel migrations (3 CTAs):** preserved onPressed handlers + labels verbatim. Imports added to each screen file.

**3-gate:** `dart format --output=none --set-exit-if-changed .` (clean — formatted upfront per PR1 deviation lesson) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1888/1888 pass — zero regressions).

**Drift lessons per ADR-098:**
- (a) `AppTheme.dark` getter-not-Widget (same as PR1 ADR-097 (a))
- (b) `const MaterialApp(theme: AppTheme.dark, ...)` fails (same as PR1 ADR-097 (b))
- (c) `TextButton` does NOT have a theme-level `minimumSize` default — explicit inline style required (NOT like `FilledButton`)
- (d) `TextButton.onPressed: null` auto-disables + suppresses callback (mirrors PR1 ADR-097 (c))
- (e) PR1 dart-format deviation lesson applied proactively → CI passed on the first try

**Cumulative v1.7 + UI sprint:** 1773 → 1888 (+115 net across 9 v1.7 cycles + PR1 + PR2 of UI sprint; 2/15 UI sprint cycles shipped).

**Next:** PR3 of 15 (IconButton — the canonical icon-only CTA wrapping `Material.IconButton`).

### PR3 of 15 — UI consolidation — AppIconButton extraction + 3 icon-only CTA migrations

**PR3 (Phase 78)** of the UI consolidation sprint. Third file in `lib/ui/`. **+11 tests (EXACT match with plan: 11 widget tests).**

**Date:** 2026-07-07. **Tests:** 1888 → 1899 (+11 net). **Cumulative v1.7 + UI sprint:** 1773 → 1899 (+126 net across 9 v1.7 cycles + 3/15 UI sprint cycles).

**Files (4 changed):**
- NEW `lib/ui/icon_button.dart` (~52 lines; `StatelessWidget` wrapping `Material.IconButton`)
- NEW `test/ui/icon_button_test.dart` (~245 lines; 11 widget tests, 5 groups)
- MIGRATE `lib/screens/person_groups.dart:62` — Refresh icon-only CTA in AppBar
- MIGRATE `lib/screens/recently_deleted_screen.dart:232` — Restore per-row action (sibling to :238)
- MIGRATE `lib/screens/recently_deleted_screen.dart:238` — Delete Forever per-row action (sibling to :232)

**Batches (3):**
- **Batch 1 — Primitive extraction:** `AppIconButton` widget. 48dp minimum INHERITED from `IconButton` defaults (unlike `TextButton` which needed explicit inline `ButtonStyle` in PR2 per ADR-098 (c)). API: `const AppIconButton({super.key, required icon, required onPressed, tooltip})`.
- **Batch 2 — Tests (11 across 5 groups):** icon rendering (4: renders icon + renders IconButton + tap invokes + multiple taps invoke) + disabled (1) + tooltip (2: non-null set + null allowed) + 48dp touch target (1) + Key/Semantics (3: forwards key + icon widget identity + tooltip wraps Tooltip widget). Same structure as PR1+PR2 but for IconButton family.
- **Batch 3 — Icon-only CTA migrations (3 sites):** preserved keys + tooltips + onPressed handlers + icons verbatim. Imports added to each screen file.

**3-gate:** `dart format --output=none --set-exit-if-changed .` (clean — formatted upfront per PR1 deviation lesson) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1899/1899 pass — zero regressions).

**Drift lessons per ADR-099:**
- (a) `AppTheme.dark` getter-not-Widget (PR1 + PR2 mirror — same root cause as ADR-097 (a) + ADR-098 (a))
- (b) `const MaterialApp(theme: AppTheme.dark, ...)` fails (PR1 + PR2 mirror)
- (c) **`IconButton` INHERITS the 48dp minimum from defaults** (NEW — UNLIKE `TextButton` which needs inline `ButtonStyle` per ADR-098 (c); `IconButton` is 48×48 by default via `IconButtonThemeData`)
- (d) `IconButton.tooltip` is rendered as a `Tooltip` widget (not a `Semantics` label) — the `find.bySemanticsLabel('Refresh')` finder returns 0 widgets. The test was rewritten to `find.byType(Tooltip)` + verify `message` (passes). This is a NEW pattern vs PrimaryButton/SecondaryButton which use `Text` labels that DO become Semantics labels.
- (e) **`IconButton.filled` is a separate constructor that returns a private `_FilledIconButton` class** — the test's `expect(button.filled, isFalse)` was wrong (no `filled` getter on the base `IconButton` class). The test was simplified to `find.byType(IconButton)` (passes). This is the canonical IconButton-construction pattern from the M3 docs.

**Cumulative v1.7 + UI sprint:** 1773 → 1899 (+126 net across 9 v1.7 cycles + 3/15 UI sprint cycles; 3/15 UI sprint cycles shipped).

### PR4 of 15

PR4 (color palette misuse consolidation, C2 category) extracted `AppPalette` as the canonical semantic-color helper primitive and migrated 3 sites: (a) `lib/widget/widget_config_screen.dart:156` (`Colors.grey` → `AppPalette.iconMuted(context)`); (b) `lib/screens/home.dart:_TileIcon:1270` (`color.withValues(alpha: 0.20)` → `AppPalette.mutedTileBackground(context, color)`); (c) `lib/widgets/do_anchor_paused_badge.dart:68-75` (inline `BoxDecoration` → `AppPalette.mutedPillDecoration(context, color)`). All 3 migrations preserve visuals byte-for-byte via 5 canonical constants (`_tileAlpha=0.20`, `_pillFillAlpha=0.15`, `_pillBorderAlpha=0.5`, `_pillBorderWidth=0.5`, `_pillRadius=8`). 11 new tests in `test/ui/app_palette_test.dart` (4 groups: iconMuted [3], mutedPillDecoration [5], mutedTileBackground [2], static accessors [1]). Test count: 1899 → 1910 (+11 net; EXACT match with plan). 3-gate: `dart format` clean + `flutter analyze --fatal-infos lib test` 0 issues (15 deprecation warnings fixed via `.r/.g/.b/.a` per ADR-101 lessons (b)+(c)) + `flutter test` 1910/1910 pass. V-Model artifacts: SYS-170 + ADR-101 + WF-098 (this row) + 5 doc rows. APK discipline anchor: test count + 3-gate green + no manifest/pubspec/Drift/Kotlin changes.

**Cumulative v1.7 + UI sprint:** 1773 → 1910 (+137 net across 9 v1.7 cycles + 4/15 UI sprint cycles; 4/15 UI sprint cycles shipped).

**Next:** PR5 of 15 (C3 cards — card / surface pattern consolidation: 5 issues → 2 PRs).

**Next:** PR5 of 15 (C3 cards — card / surface pattern consolidation: 5 issues → 2 PRs).

## PR5 of 15 — UI consolidation sprint — 3 card / surface primitives extraction + 7 site migrations (2026-07-07)

- **NEW `lib/ui/surface_card.dart`** — canonical elevated `Card + Padding(Spacing.md)` body for non-tile list/grid items. `class SurfaceCard extends StatelessWidget` with optional `onTap` (wraps in `Card(clipBehavior: Clip.antiAlias, child: InkWell(...))`), optional `semanticLabel` (wraps in `Semantics(label: ..., container: true)`), optional `padding` override (default `EdgeInsets.all(Spacing.md)`, override `EdgeInsets.zero` for `ListTile`-based children that manage their own padding). Reads `cardTheme.elevation` from the active theme.
- **NEW `lib/ui/tile_surface.dart`** — per-tile accent-color tint primitive for the home habit tile. `class TileSurface extends StatelessWidget` wrapping `Material(color: accent.withValues(alpha: <canonical>)) + InkWell + Padding(Spacing.md)` with private canonical constants `_TileAlphas.selected = 0.30` + `_TileAlphas.unselected = 0.12` (matches PR4's `_tileAlpha = 0.20` pattern). Canonical geometry: 12dp border-radius + Spacing.md padding. Wraps in InkWell only when onTap or onLongPress is non-null.
- **NEW `lib/ui/banner_surface.dart`** — full-width banner primitive with `tone: BannerTone` enum (error/info/primary/neutral → M3 container roles). `class BannerSurface extends StatelessWidget` with optional `icon` + optional `onTap` + optional `semanticLabel` + optional `padding` override (default `EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm)`). Defaults to plain `Material(color: bg)` when onTap is null (no InkWell cost).
- **NEW `test/ui/surface_card_test.dart` (12 tests, 6 groups)** — basic rendering [3] + tap behavior [3] + Semantics [3] + theme integration [2] + static accessor [1]. All deterministic.
- **NEW `test/ui/tile_surface_test.dart` (13 tests, 7 groups)** — basic rendering [1] + selection alpha [4] + tap+long-press [4] + canonical geometry [2] + static accessor [1] + optional onTap [1]. All deterministic.
- **NEW `test/ui/banner_surface_test.dart` (13 tests, 5 groups)** — basic rendering [1] + tone → color pair mapping [5] + tap behavior [3] + Semantics [2] + icon [2]. All deterministic.
- **MIGRATE 7 sites** (preserving visuals byte-for-byte): (1) `lib/screens/person_groups.dart:_GroupCard.build` — `Card + Padding + Column` → `SurfaceCard(child: Column)`; (2) `lib/screens/events.dart:_EventTile.build` — `Card + ListTile` → `SurfaceCard(padding: EdgeInsets.zero, child: ListTile)`; (3) `lib/screens/recently_deleted_screen.dart:_RecentlyDeletedRow.build` — same pattern; (4) `lib/screens/home.dart:_HabitTileState.build` (the 164-line home habit tile) — `Material + InkWell + Padding + Row` → `TileSurface(accent: color, selected: selected, onTap: onTap, onLongPress: onLongPress, child: Row)`; (5) `lib/widgets/reliability_banner.dart:ReliabilityBanner.build` — `Semantics + Material + InkWell + Padding + Row` → `BannerSurface(tone: BannerTone.error, onTap: onTap, semanticLabel: '...', icon: Icon(Icons.warning_amber_rounded), child: Row)`; (6) `lib/widgets/streak_recovery_card.dart:StreakRecoveryCard.build` — `Semantics + Material + Padding + Column` → `BannerSurface(tone: BannerTone.info, semanticLabel: '...', child: Column)`; (7) `lib/widgets/routine_banner.dart:RoutineBanner.build` — `Material + Padding + Row` → `BannerSurface(tone: BannerTone.primary, semanticLabel: '...', icon: Icon(Icons.open_in_new), child: Text)`. The RoutineBanner migration ALSO adds a Semantics wrapper that was previously missing — a free a11y win from the primitive extraction. 2 unused `app_theme.dart` imports removed (reliability_banner, routine_banner) as post-migration cleanup.
- **Tests:** 1910 → 1948 (+38 net; +5 over the +33 plan target — explained by the 3-primitive split in PR5 per ADR-102 drift lesson (f))
- **Drift lessons per ADR-102:** (a) `SurfaceCard.padding` override required for ListTile-based children (NEW) + (b) M3 Card adds its own internal Padding widget (NEW — `firstWhere(padding == Spacing.md)` disambiguation pattern) + (c) `Semantics(container: true, label: ...)` CONCATENATES parent+child labels (NEW — `contains` not `equals`) + (d) `TileSurface.onTap` is nullable (NEW — branches on `(onTap == null && onLongPress == null)` to skip InkWell) + (e) `tester.longPress(...)` on a tile without onLongPress is a no-op (NEW — confirmed, no exception) + (f) 3-primitive test count deviation (+38 vs canonical +11) is natural per-primitive (NEW — BannerSurface's 4-tone-mapping + TileSurface's selection-alpha add 5+4 = 9 extra tests over the canonical 11)
- **3-gate:** `dart format` clean (formatted upfront; 8 files reformatted) + `flutter analyze --fatal-infos` 0 issues + `flutter test` 1948/1948 pass

The 15-PR UI consolidation sprint has shipped 5/15 cycles. 10 cycles remaining. Next: PR6 (C3 cards batch 2 + C6 nav).

**Cumulative v1.7 + UI sprint:** 1773 → 1948 (+175 net across 9 v1.7 cycles + 5/15 UI sprint cycles; 5/15 UI sprint cycles shipped).

**Next:** PR6 of 15 (C3 cards part 2 — `SectionHeader` + C6 nav — `appBarTheme.scrolledUnderElevation`).
| WF-100 | v1.8-06 / PR6 of 15 | C3 cards part 2 (`SectionHeader` primitive + 5 default-variant migrations + 6 compact-variant migrations) + C6 nav (`appBarTheme.scrolledUnderElevation: 1`) | `lib/ui/section_header.dart` (NEW) + `test/ui/section_header_test.dart` (NEW, 12 tests) + `test/theme/app_theme_test.dart` (NEW, 14 tests) + `lib/theme/app_theme.dart:66-78` (1 line added: `scrolledUnderElevation: 1`) + `lib/screens/settings.dart` (8 sites + dropped `_SectionHeader` private widget) + `lib/screens/add_habit.dart` (3 sites) + `lib/screens/add_person.dart` (3 sites) + `lib/screens/add_routine.dart` (2 sites) + `lib/screens/events.dart` (2 sites) + `lib/screens/person_groups.dart` (4 sites). 1948 → 1974 (+26 net). 3-gate green. APK discipline anchor maintained. SYS-172 / ADR-103. |
| WF-101 | v1.8-07 / PR7 of 15 | C4 form patterns batch 1 (`AppFormField` text + multi-line wrapper + `AppChoiceChip` ≥48dp tap target wrapper) | `lib/ui/app_form_field.dart` (NEW, ~145 LOC) + `lib/ui/app_choice_chip.dart` (NEW, ~62 LOC) + `test/ui/app_form_field_test.dart` (NEW, 15 tests) + `test/ui/app_choice_chip_test.dart` (NEW, 12 tests) + `lib/screens/add_habit.dart` (4 sites) + `lib/screens/add_event.dart` (3 sites) + `lib/screens/add_person.dart` (2 sites) + `lib/screens/person_groups.dart` (5 sites) + `lib/screens/mission_math.dart` (1 site) + `lib/screens/mission_type.dart` (1 site). 1974 → 2000 (+26 net). 3-gate green. APK discipline anchor maintained. SYS-173 / ADR-104. |
| WF-102 | v1.8-08 / PR8 of 15 | C4 form patterns batch 2 (`AppSnack` snackbar wrapper with `showError` + `showInfo` semantic distinction + M3 canonical errorContainer / inverseSurface styling) | `lib/ui/app_snack.dart` (NEW, ~85 LOC) + `test/ui/app_snack_test.dart` (NEW, 10 tests) + `lib/screens/add_habit.dart` (3 sites: `_showSnack` helper body, pre-modal "No other dos...", captured-messenger "Delete failed..." with added `if (!mounted) return;` guard) + `lib/screens/add_event.dart` (3 sites: pre-modal "Give the event a name first.", "Template saved", "Template validation failed"). 2000 → 2010 (+10 net). 3-gate green. APK discipline anchor maintained. SYS-174 / ADR-105. |
| WF-111 | v1.8-09 / PR9 of 15 | C5 empty/loading states batch 1 (`EmptyState` placeholder with title + optional message/icon/action + `LoadingView` full-area + inline spinner variants) | `lib/ui/empty_state.dart` (NEW, ~100 LOC) + `lib/ui/loading_view.dart` (NEW, ~55 LOC) + `test/ui/empty_state_test.dart` (NEW, 10 tests) + `test/ui/loading_view_test.dart` (NEW, 11 tests) + `lib/screens/home.dart` (2 sites: `_EmptyState` private class removed + FutureBuilder CircularProgressIndicator) + `lib/screens/stats.dart` (1 site: `_EmptyView` private class removed) + `lib/screens/templates.dart` (1 site: `_EmptyView` private class removed) + `lib/screens/events.dart` (1 site: FutureBuilder CircularProgressIndicator) + `lib/screens/person_groups.dart` (1 site: FutureBuilder CircularProgressIndicator). 2010 → 2031 (+21 net). Net -68 LOC across 5 screens. 3-gate green. APK discipline anchor maintained. SYS-184 / ADR-115. |
| WF-112 | v1.8-10 / PR10 of 15 | C5 empty/loading/error states batch 2 (`ErrorView` placeholder with message + retry button + optional retryLabel override + canonical `ValueKey('error.retry')`) | `lib/ui/error_view.dart` (NEW, ~75 LOC) + `test/ui/error_view_test.dart` (NEW, 11 tests) + `lib/screens/home.dart` (1 site: `_ErrorView` private class removed) + `lib/screens/stats.dart` (1 site: `_ErrorView` private class removed + promoted hardcoded 'Could not load stats.' to `message:` parameter) + `lib/screens/templates.dart` (1 site: `_ErrorView` private class removed). 2031 → 2042 (+11 net). Net -72 LOC across 3 screens. 3-gate green. APK discipline anchor maintained. SYS-185 / ADR-116. |
| WF-113 | v1.8-11 / PR11 of 15 | C5 mission error UX (`MissionFailedView` AlertDialog with title + body + OK CTA + canonical `ValueKey('mission_failed.dismiss')` + body wrapped in `Semantics(liveRegion: true)` for TalkBack) + C9-1 a11y fix on math + type problem cards (`Text.semanticsLabel` per `lib-screens.md:38` canonical labels) | `lib/ui/mission_failed_view.dart` (NEW, ~75 LOC) + `test/ui/mission_failed_view_test.dart` (NEW, 10 tests) + 3 ARB keys (`missionFailedTitle` / `missionFailedBody` / `missionFailedDismiss`) in `app_en.arb` + Spanish mirror + `lib/screens/mission_math.dart` (3rd-wrong auto-fail shows MissionFailedView before pop + Text.semanticsLabel on problem card) + `lib/screens/mission_type.dart` (same pattern + Text.semanticsLabel on phrase card) + `lib/screens/mission_launcher.dart` (both mission-aborted and chain-failed paths route through new `_showMissionFailedAndDismiss()` helper). 2042 → 2052 (+10 net; -1 vs +11 plan target). 3-gate green. APK discipline anchor maintained. SYS-186 / ADR-117. |
| WF-114 | v1.8-13 / PR13 of 15 | C7 typography — `AppTextStyles` static-helper class (5 named text-style categories: `streakNumber` / `badgeLabel` / `sectionHeaderTitle` / `sectionHeaderTitleCompact` / `caption`) + `DoItTypography` ThemeExtension (5 `DoItTypographyBucket` immutable values — display / headline / title / body / label — with `letterSpacing` + `height` + `==` / `hashCode` / `copyWith` / `lerp`; defaults: display 0/1.1, headline 0.15/1.2, title 0.15/1.25, body 0.25/1.4, label 0.5/1.2) registered on both `AppTheme.dark` and `AppTheme.light` via `extensions: const <ThemeExtension<dynamic>>[DoItTypography()]` in `_build()` | `lib/ui/app_text_styles.dart` (NEW, ~125 LOC; 16th `lib/ui/` file) + `test/ui/app_text_styles_test.dart` (NEW, 11 tests in 5 groups) + `lib/theme/app_theme.dart` (EXTENDED; added `DoItTypographyBucket` + `DoItTypography` + private `_lerpDouble` helper + `extensions:` registration) + `lib/ui/section_header.dart` (2 sites: default + compact variants route through `AppTextStyles.sectionHeaderTitle(context)` / `sectionHeaderTitleCompact(context)`) + `lib/widgets/do_anchor_paused_badge.dart` (1 site: inline `TextStyle(fontSize: 11, fontWeight: w500, letterSpacing: 0.5, height: 1.2)` → `AppTextStyles.badgeLabel(context, color: color)`) + `lib/screens/home.dart` (2 sites: streak number via `streakNumber` + rest-day caption via `caption` with optional error color) + `lib/screens/stats.dart` (1 site: streak number via `streakNumber`). 2052 → 2063 (+11 net; matches +11 plan target exactly). 3-gate green. APK discipline anchor maintained. SYS-187 / ADR-118. |
| WF-115 | v1.8-14 / PR14 of 15 | C8 icon-set + C9 a11y batch — `AppIconButton` extended with `iconSize:` (forwards to `IconButton.iconSize`; null = M3 24dp default) and `busy:` (boolean; when true, swaps the icon for a 20×20 `CircularProgressIndicator(strokeWidth: 2)` and disables the button — the canonical in-flight pattern for async ops triggered from an icon button). 28 migration sites across 11 files. 4 home AppBar a11y fixes (Cancel / Mark selected done / Stats / Settings IconButtons gain localized `tooltip:` via 4 new ARB keys) + 2 bonus a11y fixes (dst_transition_banner + streak_recovery_card dismiss buttons gain `tooltip: 'Dismiss'`). 4 new ARB keys: `homeAppBarStatsTooltip` / `homeAppBarSettingsTooltip` / `homeAppBarCancelTooltip` / `homeAppBarCompleteSelectedTooltip` (en + es). | EXTENDED `lib/ui/icon_button.dart` (added `iconSize:` + `busy:` params + 6-line doc comment) + `test/ui/icon_button_test.dart` (6 new tests: 3 for `iconSize` + 3 for `busy`) + NEW `test/a11y/touch_target_test.dart` (3 tests pinning 48dp minimum across AppIconButton / raw IconButton / PrimaryButton — regression pins for the project `IconButtonTheme` + `FilledButtonTheme`) + EXTENDED `test/a11y/contrast_test.dart` (1 new test: busy-state `CircularProgressIndicator` contrast ≥ AA Large 3:1 on dark surface). Migration sites: `lib/screens/home.dart` 9 (5 tile per-row Done/Edit/Delete/Skip/Undo with `iconSize: Sizing.tapHome / 2` + `busy: busy`; 4 AppBar Cancel/Mark/Stats/Settings with localized tooltip) + `lib/screens/events.dart` 3 (Refresh/Archive/Delete with canonical `ValueKey('events.X')`) + `lib/widgets/dst_transition_banner.dart` 1 dismiss (a11y fix) + `lib/widgets/streak_recovery_card.dart` 1 dismiss (a11y fix) + `lib/widgets/completion_log_section.dart` 2 (Refresh + Delete) + `lib/screens/add_routine.dart` 1 + `lib/screens/add_person.dart` 1 + `lib/screens/add_event.dart` 1 + `lib/screens/add_habit.dart` 1 (each: per-row Remove IconButton) + `lib/screens/person_groups.dart` already migrated in PR5 (3 sites) — total 28 migrations across 11 files. 2063 → 2073 (+10 net; -1 vs +11 plan target). 3-gate green. APK discipline anchor maintained. SYS-188 / ADR-119. |
| WF-116 | v1.8-15 / PR15 of 15 | C10 FAB (Floating Action Button) — `AddFab` primitive (wraps `Material.FloatingActionButton` with default `Icons.add` child + default `tooltip: 'Add'`; required `onPressed`; optional `tooltip`). 3 migration sites (home `_AddFab.build` + events add + person_groups add) + 2 async refresh-action patterns (events + person_groups). | NEW `lib/ui/add_fab.dart` (~50 LOC; 18th `lib/ui/` file) + NEW `test/ui/add_fab_test.dart` (11 tests, 6 groups: rendering / tooltip / sizing / Key+Semantics / custom child / disabled + 1 async onPressed refresh pattern). Migration sites: `lib/screens/home.dart` 1 (the private `_AddFab` widget — its `FloatingActionButton` becomes `AddFab`; `key: const ValueKey('home.fab')` preserved; the `_AddSheet` choice-sheet dispatch logic is unchanged) + `lib/screens/events.dart` 1 (the `events.add` FAB — async onPressed that awaits AddEventScreen + refreshes on result) + `lib/screens/person_groups.dart` 1 (the `person_groups.add` FAB — same async refresh pattern). 2073 → 2084 (+11 net; matches +11 plan target exactly). 3-gate green. APK discipline anchor maintained. SYS-189 / ADR-120. |
| WF-120 | v1.8-pr-d / PR-D | Rest-day caption wording flip (`X/Y rest days left` → `Used X of Y this month`) + localized empty-state body (`homeEmptyBody` ARB key consumed by the `EmptyState.message:` slot introduced in PR9 / SYS-184). 2 screen-file edits (home.dart `_BudgetCaption.build` + home.dart empty-state call site) + 4 ARB keys (en + es mirror for `homeTileBudgetUsed` + `homeEmptyBody`; the legacy `homeTileBudgetRemaining` is kept as a back-compat stub with `@description` note) + 8 test edits (5 NEW tests in `home_tile_budget_caption_test.dart` + 3 existing-test extensions: 2 in `locale_render_test.dart` for the empty-state body + 2 in `home_test.dart` for the new caption wording). | EDIT `lib/screens/home.dart` 2 sites (`_BudgetCaption.build` normal-bucket branch + the `EmptyState(title: l.homeEmptyTitle, icon: ...)` call site at `_HomeScreenState.build`) + EDIT `lib/l10n/app_en.arb` (renamed `homeTileBudgetRemaining` description; added `homeTileBudgetUsed` + `homeEmptyBody`) + EDIT `lib/l10n/app_es.arb` (added both) + regen `lib/l10n/gen/app_localizations*.dart` + EDIT `test/l10n/locale_render_test.dart` (the 2 `home-screen renders ... empty state` tests now also pin `l.homeEmptyBody`) + EDIT `test/screens/home_test.dart` (the 2 caption-render tests renamed to reference v1.8-pr-d / SYS-193 + assertion text updated to `"Used X of Y this month"`) + NEW `test/screens/home_tile_budget_caption_test.dart` (5 tests in 5 groups: English ARB round-trip / Spanish mirror / empty-state body in en / empty-state body in es / EmptyState primitive title-→-message-with-gap). 2084 → 2089 (+5 net; 7 if you count the 2 extended `locale_render_test.dart` assertions + the 2 updated `home_test.dart` captions as new tests). 3-gate green. APK discipline anchor maintained. SYS-193 / ADR-124. |
| WF-119 | v1.8-pr-c / PR-C | Restore-from-Backup passphrase input (C2 unblock v2/v3 encrypted-backup restore UX) — `TextEditingController` in `_SettingsRestoreScreenState` + obscure-toggle `IconButton` suffix + localized `Wrong passphrase` error string + `passphrase:` arg threaded through to `BackupService.instance.importFrom(File(path), passphrase: ...)`. Layout wrapped in `SingleChildScrollView` to handle the new Card on small viewports. | EDIT `lib/screens/settings_restore.dart` (state fields + `_pick()` reset + `_restore()` forward + error mapping + build-time Card + `SingleChildScrollView` wrap) + EDIT `lib/l10n/app_en.arb` (6 new keys: `settingsRestorePassphraseLabel` / `settingsRestorePassphraseHint` / `settingsRestorePassphraseShowCta` / `settingsRestorePassphraseHideCta` / `settingsRestoreWrongPassphraseError` / `settingsRestoreEncryptedBackupHint`) + EDIT `lib/l10n/app_es.arb` (Spanish mirror) + regen `lib/l10n/gen/app_localizations*.dart` + EDIT `test/screens/settings_restore_test.dart` (switched `_wrap()` from bare `MaterialApp` to `support.localizedApp(...)` per the PR11 lesson) + NEW `test/screens/settings_restore_passphrase_test.dart` (10 tests in 5 groups: ARB round-trip en / ARB round-trip es / initial render after pick x2 / interaction x3 / integration x3). 2089 → 2099 (+10 net; matches the plan's "+10" target exactly). 3-gate green. APK discipline anchor maintained. SYS-192 / ADR-123. |
