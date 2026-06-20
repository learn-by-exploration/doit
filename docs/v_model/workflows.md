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
