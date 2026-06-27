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
