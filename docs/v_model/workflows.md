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


## WF-042 — Mark a do done from the Android home-screen widget (v1.4a / Phase 28 / SYS-115 / ADR-045)

**Actor.** User, on the Android home screen, looking at the `DoitAppWidgetProvider` widget surface.

**Goal.** Mark a do done without opening the app, from the home-screen widget.

**Preconditions.** The widget has been added to the home screen; `DoitAppWidgetProvider` is registered; the user is signed in.

**Flow.**

1. The widget renders the first-active do (via `WidgetStateLocator.firstActiveDo(...)` ordered by `createdAt` ascending), the streak number (via `WidgetStateBuilder.buildWidgetState(...)` using `ConsecutiveCounter.compute`), and the reliability caption.
2. The user taps "Mark done" on the widget.
3. The widget fires a `BroadcastReceiver` over the `doit/widget` MethodChannel; the Dart side calls `WidgetService.markDone(habitId: do.id, day: <local-midnight at now>)`.
4. `WidgetService.markDone` calls `CompletionLogService.instance.append(...)` with `source: CompletionSource.manual` + `proofModeAtTime: <soft|strong|auto>`. The append dedupes on `(habitId, day)`.
5. The widget refreshes (via `handleRefreshRequest`) and re-renders with the new streak.
6. (Strong-mode only.) The widget deep-links to `MissionLauncherScreen` via the existing v1.3d path; the chain UI runs; on `ChainPassed` the completion is appended by the mission UI itself (`MissionLauncherScreen` is the single writer for strong-mode completions on the widget surface too).

**Alternate paths.**

- **Channel missing (no native side, e.g. tests / web).** `MissingPluginException` is swallowed; the mark-done call is a no-op. (ADR-013.)
- **Strong-mode chain timeout / cancel.** `MissionLauncherScreen` pops with `null`; the streak stays broken per the v1.1f grace-window contract.

**Out of scope (v1.4c candidates).**

- Widget small / large variants, widget config activity, widget list (scrolling), widget deep-link to a specific do.

## WF-043 — Mark a do done from the home tile (v1.4b / Phase 29 / SYS-116 / ADR-046)

**Actor.** User, inside the app, looking at the home screen.

**Goal.** Mark a do done without entering select mode, from the home tile.

**Preconditions.** The user has at least one active (non-paused) do. The reliability banner is irrelevant.

**Flow.**

1. The home screen renders each `_HabitTile` with the do name (left), a `_DoStreakBadge` (right — streak number + "day streak" subtitle), and a `_DoneButton` (far right).
2. The user taps the tile's "Mark done" button.
3. (Soft / Auto do.) `markDoDone(activeDo, asOf, CompletionLogService.instance)` calls `completionLog.append(habitId: activeDo.id, day: <local-midnight at asOf>, source: CompletionSource.manual, proofModeAtTime: <soft|strong|auto>)`. The tile flips `_isCompletedToday = true`; the SnackBar `homeSnackbarMarkedDone` ("Marked done.") shows; the `IconButton` re-renders as a filled `Icons.check_circle`.
4. (Strong do.) The tile pushes `MissionLauncherScreen(habitId: do.id)` via `Navigator.push<bool>(...)` and `await`s the pop. The mission UI runs the chain end-to-end. On `ChainPassed` the launcher pops with `true`; the tile flips `_isCompletedToday = true`. On a `null` pop (cancel / timeout), the tile does NOT flip the bool — the streak stays broken per the v1.1f grace-window contract.
5. A re-tap on an already-done tile shows the `homeTileAlreadyDoneTooltip` SnackBar — no second append (the dedupe happens upstream inside `CompletionLogService.append`).

**Alternate paths.**

- **DB write failure.** The `_busy` flag reverts in `setState`; the tile stays in the "not done" state; no SnackBar. (The service's append throws — caller catches upstream; the tile currently does not surface a SnackBar on failure; the existing `_completeSelected` SnackBar pattern is the model.)

**Out of scope (v1.4c candidates).**

- In-app tile reliability badge inside the tile body (currently shown as a small icon at the top-right; the v1.4b streak is added next to the name, not replacing the badge).
- Tile "Skip today" button (consumes a rest-day budget).
- Tile streak history visualization (7-day sparkline).
- Tile edit / delete affordance (currently in the long-press select-mode only).

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
