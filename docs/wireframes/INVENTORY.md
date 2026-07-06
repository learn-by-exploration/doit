# doit — Feature Wireframe Inventory (2026-07-06)

This inventory catalogues every user-facing surface of the
`do it` Android app at v1.4-stab (post-cycle-K, 1623 tests,
~67.57% coverage). It is the visual index of the
[requirements matrix](../v_model/traceability_matrix.md)
and the [workflow list](../v_model/workflows.md).

- **Total wireframes**: 38 (W01–W38)
- **Groups**: 9 (A–I)
- **Source**: every entry cites a real `lib/screens/*.dart`
  or `lib/widgets/*.dart` path. Copy is paraphrased; do not
  treat as i18n source (see `lib/l10n/app_en.arb`).
- **Visual elements** lists only what the rendering tree
  paints; **States** lists the enums / futures the screen
  handles.

---

## Group A — Habit lifecycle (W01–W10)

The home screen + add/edit + per-tile actions + scheduling
+ categories + icons + 14-day sparkline + rest-day budget +
sparkline history + streak recovery.

### W01 — Home screen

- **Source**: `lib/screens/home.dart:1-1965`
- **Flows**: WF-003, WF-007, WF-008, WF-053, WF-061
- **SYS**: SYS-101, SYS-112, SYS-113, SYS-116, SYS-117,
  SYS-118, SYS-119, SYS-123, SYS-126, SYS-134
- **Visual elements**:
  - `Scaffold` with `Material 3` `AppBar`, three-icon
    bottom-nav (Home / Settings / Stats), FAB (add)
  - `ReliabilityBanner.fromStream(...)` (top, errorContainer
    when degraded)
  - `RoutineBanner` (passive drainer, hides when queue
    empty)
  - `DstTransitionBanner` (one-shot, dismissable)
  - `StreakRecoveryCard` (one-shot, dismissable)
  - Per-habit `Card` tile: title, icon, category chip, 14-
    day sparkline (v1.4i), streak badge, rest-day budget
    caption
  - Bottom of tile row: `IconButton` row with Skip / Undo /
    Done (v1.4c / v1.4d / v1.4b) plus per-tile Edit +
    Delete (v1.4h, soft-deleted to v1.4l tombstone)
  - Long-press enters select-mode (multi-tile); top-bar
    actions: Restore + Delete Forever
- **Mock copy**:
  - App bar title: "do it"
  - FAB tooltip: "Add habit"
  - Reliability banner: "Reminders may be late. Tap to fix."
  - Streak badge: "🔥 12" or "12 days"
  - Sparkline caption: tap a tile to mark done
- **Caption**: One screen per active habit; the home tile is
  the canonical unit of habit interaction.
- **States**:
  - Empty (no habits) — onboarding CTA
  - Loading — `CircularProgressIndicator`
  - Reload error — Retry button (recently-deleted pattern)
  - Reliability: `optimal` (banner hidden) /
    `degraded` (banner shown) / `unknown` (banner shown)
  - Streak recovery: `state == null` (card hidden) /
    `state != null` (card visible)
  - DST: `drops.isEmpty` (banner hidden) / non-empty (shown)
  - Select-mode: idle / active

### W02 — Add / Edit habit

- **Source**: `lib/screens/add_habit.dart:1-1568`
- **Flows**: WF-002, WF-022, WF-025, WF-031, WF-051
- **SYS**: SYS-102, SYS-124, SYS-125
- **Visual elements**:
  - `Scaffold` with `AppBar` title "New do" or "Edit do"
  - Form sections: Name (`TextFormField`), Category
    (`CategoryChip` → modal sheet), Icon (`IconPicker`
    8×8 grid), Schedule (SegmentedButton: Fixed / Interval
    / Anchor / Day-of-X / Time-Window), Routines
    (read-only summary), Rest-day budget (slider row,
    `RestDayPickerDialog`), Pause row, Completion log
    (edit-mode only — `CompletionLogSection`)
  - Save-as-template checkbox (footer)
  - Action: `FilledButton` "Save" / "Update"
- **Mock copy**:
  - Schedule section: "When?", "How often?", "Pick a
    template…"
  - Anchor target: "I want this to follow: <Do name>"
  - Rest-day row: "Rest days per month: 2"
  - Completion log header: "Recent completions"
- **Caption**: The single source of truth for the habit
  schedule engine + automation wiring.
- **States**:
  - Add vs Edit (different copy + completion-log section)
  - Schedule kind: 5 schedule types (mutually exclusive)
  - Anchor mode: `target == null` (anchor disabled) /
    `target != null` (anchor enabled)
  - Validation: name non-empty, schedule fields
    individually validated

### W03 — Per-tile Skip / Undo / Done actions

- **Source**: `lib/screens/home_tile_skip.dart:1`,
  `lib/screens/home_tile_undo.dart:1`,
  `lib/screens/home_tile_completion.dart:1`
- **Flows**: WF-046 (Skip), WF-047 (Undo), WF-048 (Done)
- **SYS**: SYS-117 (Skip), SYS-118 (Undo), SYS-119 (Done)
- **Visual elements**:
  - 3 × `IconButton` in tile trailing row
  - Skip icon: `Icons.skip_next`
  - Undo icon: `Icons.undo`
  - Done icon: `Icons.check_circle`
  - Skip opens `RestDayPickerDialog` (if budget exhausted:
    "No rest days remaining" SnackBar)
- **Mock copy**:
  - Skip tooltip: "Mark today skipped"
  - Undo tooltip: "Undo today's completion"
  - Done tooltip: "Mark done"
  - SnackBar after Done: "Marked done. Undo" (4-second
    window)
- **Caption**: Three actions that mutate the completion
  log and the rest-day budget on a single tile.
- **States**:
  - Skip: `RestDayBudget.remaining > 0` / exhausted
  - Undo: `today.isCompleted == true` / false
  - Done: idempotent — second tap is a no-op

### W04 — Per-tile Edit / Delete actions

- **Source**: `lib/screens/home.dart` (per-tile Edit +
  Delete `IconButton`s), `lib/screens/home_tile_delete.dart`
- **Flows**: WF-022 (Edit), WF-053 (Delete + Undo)
- **SYS**: SYS-126 (tombstone)
- **Visual elements**:
  - 2 × `IconButton` (Edit pencil + Delete trash) in tile
    leading row
  - Delete → SnackBar "Habit deleted. Undo." with action
    button (v1.4l soft-delete + tombstone)
- **Mock copy**:
  - Edit tooltip: "Edit habit"
  - Delete tooltip: "Delete habit"
- **Caption**: Per-tile discoverability gap closure (v1.4h)
  + soft-delete with safe Undo (v1.4l).
- **States**:
  - Tombstoned (do NOT show on home) → routed to
    `RecentlyDeletedScreen` (W31)
  - Restored → reappears in home list with completion
    history intact

### W05 — 14-day Sparkline visualization

- **Source**: `lib/screens/home_tile_sparkline.dart:1`
- **Flows**: WF-049
- **SYS**: SYS-123
- **Visual elements**:
  - Inline row of 14 dots (`SparklineDot` sealed: empty /
    done / skipped / today)
  - Color-coded: emerald (done), grey (empty), amber
    (skipped), primary (today)
  - Source-aware (manual vs auto vs skipped)
- **Mock copy**: Caption "Last 14 days" (visible on long-
  press or in legend)
- **Caption**: At-a-glance completion rhythm per habit.
- **States**: 14 days × {empty, done, skipped, today}
  (4 states × 14 = 16 possible dots per tile)

### W06 — Rest-day budget picker dialog

- **Source**: `lib/screens/rest_day_picker_dialog.dart:1-117`
- **Flows**: WF-051
- **SYS**: SYS-124
- **Visual elements**:
  - `AlertDialog` with title + slider 0..31 (integer
    divisions) + Cancel/Save buttons
  - Live label "$_value" above slider
- **Mock copy**:
  - Title: "Rest days per month"
  - Description: "How many days can you skip each month
    without breaking your streak?"
  - Save: "Save", Cancel: "Cancel"
- **Caption**: Shared dialog used by both home tile budget
  caption + add-habit form row.
- **States**: idle / dragging / save / cancel

### W07 — Icon picker (8×8 grid)

- **Source**: `lib/widgets/icon_picker.dart:1-237`
- **Flows**: WF-031
- **SYS**: SYS-102
- **Visual elements**:
  - `DraggableScrollableSheet` (70% → 90%)
  - 4-column `GridView` with 64 Material icons across 8
    thematic rows: physical / mind / relational /
    productivity / home / discipline-recovery / food /
    exercise
  - Each tile 56dp (≥ 48dp touch target)
  - Selected tile highlights with `primaryContainer`
- **Mock copy**: Header "Icon", sub-button "Use default"
- **Caption**: Single source of truth for "which icon
  represents this habit".
- **States**: unpicked / picked / cleared

### W08 — Category chip + swatch picker

- **Source**: `lib/widgets/category_chip.dart:1-351`
- **Flows**: WF-002 (chip in form), WF-005 (chip in
  stats)
- **SYS**: SYS-102
- **Visual elements**:
  - `CategoryChip` rounded pill (color disc + label),
    tap opens modal sheet
  - `CategoryPickerSheet` with two sections: category
    `ChoiceChip` row (Health / Mind / Relationships /
    Productivity / Home / Other) + color swatch
    `ListView` (index 0 = default + 7 override swatches)
- **Mock copy**:
  - Chip: "Health" with green disc
  - Sheet title: "Category"
  - Sheet sub-title: "Color"
- **Caption**: The only file in the app that bridges
  `DoCategory` (pure Dart enum) to a Flutter `Color`.
- **States**: default (colorSeed = 0) / override (1..7)

### W09 — Completion-log edit section (edit mode only)

- **Source**: `lib/widgets/completion_log_section.dart:1-245`
- **Flows**: WF-025
- **SYS**: SYS-125
- **Visual elements**:
  - `Card` with `FutureBuilder<List<CompletionRow>>`
  - Title row: "Recent completions" + refresh `IconButton`
  - Up to 30 rows: `ListTile` per completion
    (check-circle leading, `$day · $time` title,
    `$source` subtitle, delete trailing)
  - Overflow message: "$hidden older entries are hidden"
- **Mock copy**:
  - Row: "2026-07-05 · 09:30" / "manual"
  - Confirm dialog: "Delete this completion?", body
    "<date> at <time> (<source>). This will shorten your
    streak by one day."
  - Success SnackBar: "Completion removed."
- **Caption**: Edit-screen recovery path — undo an
  accidental completion without leaving the form.
- **States**: loading / loaded-empty / loaded-with-rows /
  load-error / confirm-dialog / delete-error

### W10 — Streak recovery card

- **Source**: `lib/widgets/streak_recovery_card.dart:1-146`
- **Flows**: WF-050
- **SYS**: SYS-106
- **Visual elements**:
  - `Material` banner with `tertiaryContainer` background
  - Header row: calendar icon + "Streak broken on
    <habitLabel>" + dismiss `IconButton`
  - Body: "<N> days missed. Jump back in at <nextSlot>"
  - CTA: `FilledButton` "I'm back"
- **Mock copy**:
  - Semantics: "Streak broken: <label> missed <N> days in
    a row."
- **Caption**: One-shot home surface for 3+ missed days.
- **States**: `state == null` (hidden) / `state != null`
  (visible)

---

## Group B — People + Cadence (W11–W14)

Contact rotation groups + per-person add/edit + the contact
picker bottom sheet.

### W11 — Add / Edit person

- **Source**: `lib/screens/add_person.dart:1-711`
- **Flows**: WF-009, WF-023
- **SYS**: SYS-104
- **Visual elements**:
  - `Scaffold` + `AppBar` "New person" or "Edit person"
  - Form: Name (`TextFormField`), Channel
    (`SegmentedButton`: Phone / WhatsApp / Telegram /
    Signal / SMS), Handle (`TextFormField`), Cadence
    (`SegmentedButton`: Every N days / Weekly / Monthly /
    Yearly), Routines (read-only summary), Pause row,
    Contact picker `FilledButton` ("Pick contact")
  - Contact picker gated by `PermissionSheet.show(context,
    PermissionKind.contacts)`
- **Mock copy**:
  - Section header: "How to reach them"
  - Channel labels: Phone, WhatsApp, Telegram, Signal, SMS
  - Cadence labels: Every N days, Weekly, Monthly, Yearly
- **Caption**: A person is the cadence habit anchor for
  relational triggers.
- **States**:
  - Add vs Edit
  - Channel: 5 options (sealed `PersonChannel`)
  - Cadence: 4 shapes (sealed `PersonCadence`)
  - Contact picker: permission-granted / denied /
    cancelled

### W12 — Person groups (rotation)

- **Source**: `lib/screens/person_groups.dart:1-621`
- **Flows**: WF-018
- **SYS**: SYS-104
- **Visual elements**:
  - `Scaffold` + `AppBar` "Groups"
  - List of group `Card`s: name + semantic chip
    (rotation / any / all) + member count + cadence chip
  - FAB "+" → create-group flow
  - Tapping a group → group detail view (members +
    cadence editor)
- **Mock copy**:
  - Empty state: "No groups yet. Tap + to create one."
  - Group row: "Weekly call rotation · 4 people"
- **Caption**: Multi-person cadence (e.g. "call one of
  these 4 every Sunday").
- **States**:
  - Empty / populated
  - Group semantic: rotation / any / all
  - Cadence shape: every_n / weekly / monthly / yearly

### W13 — Per-person routines section

- **Source**: `lib/screens/add_person.dart` (routines
  card)
- **Flows**: WF-009
- **SYS**: SYS-104, SYS-079
- **Visual elements**:
  - Card with title "Routines" + summary line "<N>
    routine(s) attached" + expand chevron
  - Expanded view: per-automation row with
    `AutomationReliabilityBadge` trailing
- **Mock copy**: "Routines" / "Add a routine that fires on
  this person."
- **Caption**: Same wiring as habit routines, scoped to
  person triggers (e.g., inbound call → silent).
- **States**: empty / populated / reliability-degraded

### W14 — Contact picker bottom sheet

- **Source**: `lib/screens/contact_picker_screen.dart`
  (referenced; per `lib-people.md` the only file in
  `lib/people/` that imports Flutter)
- **Flows**: WF-009
- **SYS**: SYS-104
- **Visual elements**:
  - Platform contact picker (Android `ACTION_PICK` or
    `contact_picker` plugin)
  - Single-select result → returns `PersonResolver`
    snapshot (display name, lookup key, channel handle)
- **Mock copy**: System contact picker UI
- **Caption**: Bridge from the app's "Add person" form to
  the OS-level contact list.
- **States**: permission-denied / granted-no-contacts /
  granted-with-contacts / selected

---

## Group C — Events (W15–W17)

Event create/edit + the events list (upcoming / past) +
calendar-event automation wiring.

### W15 — Add / Edit event

- **Source**: `lib/screens/add_event.dart:1-643`
- **Flows**: WF-010, WF-024
- **SYS**: SYS-103
- **Visual elements**:
  - `Scaffold` + `AppBar` "New event" or "Edit event"
  - Form: Title, Date (date picker), Time (time picker),
    Lead-time (slider 0..14 days), Repeat
    (`SegmentedButton`: None / Annually), Routines
    (read-only summary)
- **Mock copy**:
  - Lead-time label: "Remind me <N> days before"
  - Repeat options: "Does not repeat", "Annually"
- **Caption**: An event is a date-anchored cadence habit
  with optional calendar triggers.
- **States**:
  - Add vs Edit
  - Repeat: none / annually
  - Validation: title + date non-empty

### W16 — Events list (upcoming + past)

- **Source**: `lib/screens/events.dart:1-223`
- **Flows**: WF-010
- **SYS**: SYS-103
- **Visual elements**:
  - `Scaffold` + `AppBar` "Events" + FAB
  - Two sections: "Upcoming" + "Past"
  - Per-event row: title + date + lead-time caption
    + archive `IconButton` + delete `IconButton`
- **Mock copy**:
  - Empty state: "No events yet. Tap + to add one."
  - Archived section header: "Archived"
- **Caption**: Surface for date-anchored reminders.
- **States**:
  - Empty / populated
  - Section: upcoming / past / archived
  - Action: archive / delete

### W17 — Calendar-event routine (TriggerCalendarEvent)

- **Source**: `lib/widgets/calendar_picker.dart:1-359`,
  automation wiring in `add_event.dart`
- **Flows**: WF-035
- **SYS**: SYS-074
- **Visual elements**:
  - `CalendarPicker` modal bottom sheet with date list
    of upcoming calendar events + per-event title + time
    + multi-select
  - `ActionNotify` row in event form
- **Mock copy**:
  - Sheet title: "Pick a calendar event"
  - Empty: "No upcoming events on your calendar."
- **Caption**: Routine trigger that fires on inbound
  Android calendar events (READ_CALENDAR permission gate).
- **States**:
  - Permission-denied / granted
  - Empty / populated
  - Multi-select: empty / one-or-more

---

## Group D — Missions, 5 types (W18–W23)

The 5 mission UIs + the chain launcher.

### W18 — Shake-N mission

- **Source**: `lib/screens/mission_shake.dart:1-132`,
  `lib/missions/shake_detector.dart`
- **Flows**: WF-005 (Strong proof)
- **SYS**: M-001
- **Visual elements**:
  - Full-screen `Scaffold` with large circular target
    icon + countdown label "Shake N times"
  - Live counter "X / N"
  - `ShakeDetector` consumes `sensors_plus` stream
- **Mock copy**:
  - Header: "Shake the phone <N> times"
  - Sub: "X of N detected"
  - Success: "Done!" → write completion
- **Caption**: Strong-mode proof that requires physical
  motion.
- **States**:
  - Idle (waiting for first shake)
  - In progress (counter < N)
  - Done (counter == N) → completion write
  - Cancelled (back button)

### W19 — Type-phrase mission

- **Source**: `lib/screens/mission_type.dart:1-104`
- **Flows**: WF-005
- **SYS**: M-002
- **Visual elements**:
  - `Scaffold` with phrase label + `TextField` for
    exact-match input
  - Submit `FilledButton`
  - 3-wrong-attempts → fail
- **Mock copy**:
  - Phrase label: "Type this phrase exactly:"
  - Phrase body: e.g. "I am worth the effort."
  - Error inline: "Doesn't match."
- **Caption**: Strong-mode proof that requires cognitive
  engagement.
- **States**:
  - Idle / typing / wrong (1/3, 2/3) / locked-out / passed
  - Cancelled

### W20 — Hold-tap mission

- **Source**: `lib/screens/mission_hold.dart:1-150`
- **Flows**: WF-005
- **SYS**: M-003
- **Visual elements**:
  - `Scaffold` with circular progress + label "Hold for
    N seconds"
  - `GestureDetector` with `onTapDown` + `onTapUp` +
    `onTapCancel`
  - Circular timer animates from 0 to N
- **Mock copy**:
  - "Hold to confirm"
  - "X / N seconds"
  - Released early: "Released. Try again."
- **Caption**: Strong-mode proof that requires sustained
  attention.
- **States**:
  - Idle / holding (timer running) / released-early /
    completed / cancelled

### W21 — Math mission

- **Source**: `lib/screens/mission_math.dart:1-125`,
  `lib/missions/math_problem.dart`
- **Flows**: WF-005
- **SYS**: M-004
- **Visual elements**:
  - `Scaffold` with problem label "12 + 7 =" + numeric
    `TextField`
  - Submit button
  - 3-wrong-attempts → fail
- **Mock copy**:
  - Problem: "What is 12 + 7?"
  - Input hint: "Answer"
  - Wrong: "Not quite. <remaining> tries left."
- **Caption**: Strong-mode proof that requires arithmetic.
- **States**:
  - Idle / typing / wrong (1/3, 2/3) / locked-out /
    correct → completion / cancelled

### W22 — Memory mission

- **Source**: `lib/screens/mission_memory.dart:1-157`,
  `lib/missions/memory_game.dart`
- **Flows**: WF-005
- **SYS**: M-005
- **Visual elements**:
  - `Scaffold` with grid of `MemoryCard`s (rows × cols)
  - Tapping a card flips it; match → both stay face-up
  - Win when all pairs matched
- **Mock copy**:
  - "Memory: <N> pairs matched"
  - Card back: emoji / icon glyph
- **Caption**: Strong-mode proof that requires working
  memory.
- **States**:
  - Idle / one-card-up / two-cards-up-correct /
    two-cards-up-mismatch / all-matched / cancelled

### W23 — Mission chain launcher

- **Source**: `lib/screens/mission_launcher.dart:1-290`
- **Flows**: WF-005, WF-006
- **SYS**: M-001..M-005, SYS-107
- **Visual elements**:
  - `Scaffold` with progress stepper ("Step 2 of 3") +
    per-mission screen body
  - On `ChainPassed` → `CompletionLogService.append(...)`
  - On `ChainFailedAt` → SnackBar "Mission failed"
- **Mock copy**:
  - Stepper: "Mission 2 of 3"
  - Passed: "Marked done."
  - Failed: "Mission failed. Try again next time."
- **Caption**: Routes to the 5 mission UIs via sealed
  `Mission` switch + runs the chain executor.
- **States**:
  - Loading (initializing)
  - Per-mission rendering (one of 5 screens)
  - Passed (write completion + return)
  - Failed (SnackBar + return)
  - Timeout (per-mission `timeout` honored)
  - Cancelled (back button)

---

## Group E — Routines (W24–W25)

Generic apply UX for templates #17–#21 + Japan silent-mode
template #16 + automation reliability badge/dialog.

### W24 — Routine apply (templates #17–#21)

- **Source**: `lib/screens/routine_apply.dart:1-271`
- **Flows**: WF-036, WF-037, WF-034
- **SYS**: SYS-083, SYS-086
- **Visual elements**:
  - `Scaffold` + `AppBar` "Routine" + form sections
    scoped to the trigger kind (location / calendar /
    device-state / time-of-day)
  - Enable toggle (top)
  - Save / Update / Delete action row
- **Mock copy**:
  - Header: "Apply routine"
  - Toggle: "Enabled"
  - Save: "Save", "Update", "Delete"
- **Caption**: Generic apply UX for the 5 routine
  templates (location / calendar / device-state /
  time-of-day / usage-stats).
- **States**:
  - New / edit
  - Save / update / delete
  - Reliability: optimal / degraded / unknown

### W25 — Japan silent-mode call-screening routine (#16)

- **Source**: `lib/screens/add_routine.dart:1-291`
- **Flows**: WF-037
- **SYS**: SYS-075, SYS-079
- **Visual elements**:
  - `Scaffold` + `AppBar` "Japan silent mode"
  - Enable toggle
  - Multi-select contact picker ("Which contacts trigger
    silent?")
  - Target-mode radio: Normal / Vibrate / Silent
- **Mock copy**:
  - Title: "Japan silent mode (call screening)"
  - Description: "When a selected contact calls, switch to
    <target mode>."
- **Caption**: Specialised template #16 — the canonical
  Phase F reference template.
- **States**:
  - Disabled / enabled
  - Contact-set: empty / one-or-more
  - Target-mode: normal / vibrate / silent

---

## Group F — Reliability + Permissions (W26–W28)

The reliability banner + device-state row + on-demand
permission sheet + per-automation reliability dialog.

### W26 — Reliability banner (home + settings)

- **Source**: `lib/widgets/reliability_banner.dart:1-151`
- **Flows**: WF-061
- **SYS**: SYS-112, SYS-113
- **Visual elements**:
  - `Material` strip with `errorContainer` background
  - Warning icon + "Reminders may be late. Tap to fix."
  - Trailing chevron (when interactive)
  - Hides when `reliability == optimal`
- **Mock copy**:
  - "Reminders may be late. Tap to fix."
  - Semantics: "Reminder reliability degraded"
- **Caption**: App-wide alarm-system reliability banner.
- **States**:
  - Optimal (hidden)
  - Degraded (visible, interactive)
  - Unknown (visible, interactive)

### W27 — On-demand permission sheet

- **Source**: `lib/widgets/permission_sheet.dart:1-427`
- **Flows**: WF-067 (per-kind)
- **SYS**: SYS-067, ADR-014, ADR-016, ADR-018
- **Visual elements**:
  - `showModalBottomSheet` with rationale + Allow +
    Open-settings buttons
  - Per-kind icon + title + rationale copy from
    `permissionKindMeta`
  - 9 `PermissionKind` cases handled
- **Mock copy**:
  - Title: "Allow contacts?"
  - Rationale: "do it only uses contacts you add to a
    cadence."
  - Buttons: "Allow" / "Open settings"
- **Caption**: Single on-demand permission gate. Every
  feature that requires a runtime permission calls
  `PermissionSheet.show(context, kind)` first.
- **States**:
  - Already-granted (short-circuits to `true`)
  - Denied (one-shot) — Allow + Open settings
  - Permanently-denied — Open settings only
  - Dismissed (returns `false`)

### W28 — Per-automation reliability badge + dialog

- **Source**: `lib/widgets/automation_reliability_badge.dart:1-112`,
  `lib/widgets/automation_reliability_dialog.dart:1-340`
- **Flows**: WF-061 (per-routine)
- **SYS**: SYS-085, SYS-103
- **Visual elements**:
  - Badge: 40×40 `IconButton` in routine row trailing slot
    (warning icon = degraded, info icon = unknown, hidden
    when optimal)
  - Dialog: `AlertDialog` with Trigger-side and Action-
    side permission sections + "Open settings" CTA
- **Mock copy**:
  - Badge tooltip: "Routine reliability degraded; tap to
    fix"
  - Dialog title: "This routine may not fire"
  - Section headers: "Trigger", "Action"
- **Caption**: Per-routine reliability diagnostic. Visual
  sibling of `ReliabilityBanner` but scoped to one
  automation.
- **States**:
  - Optimal (badge hidden)
  - Degraded / unknown (badge visible)
  - Dialog: open / closed

---

## Group G — Settings + Backup (W29–W31)

The settings screen + restore-from-backup + recently-
deleted.

### W29 — Settings screen

- **Source**: `lib/screens/settings.dart:1-735`
- **Flows**: WF-011..WF-016
- **SYS**: SYS-067..SYS-113
- **Visual elements**:
  - `Scaffold` + `AppBar` "Settings"
  - Sections: Appearance (theme: dark / light / system),
    Anchor (manual / firstUnlock / either),
    Permissions (notifications / contacts / exactAlarm /
    location / fullScreenIntent / callScreening /
    backupFolder), Reliability (live status row),
    DeviceState (`DeviceStateRow`), Stats, Backup (restore
    + recently-deleted entries), About
- **Mock copy**:
  - Section header: "Permissions"
  - Tile: "Notifications", "Contacts", "Exact alarms",
    "Location", etc.
  - Backup tile: "Restore from backup" →
    `SettingsRestoreScreen` (W30)
  - Tombstone tile: "Recently deleted" →
    `RecentlyDeletedScreen` (W31)
- **Caption**: The catch-all system-preferences surface.
- **States**:
  - Each permission tile: granted / denied /
    permanently-denied (color-coded chip)
  - DeviceState: waiting / live / error
  - Theme: dark / light / system

### W30 — Restore from backup

- **Source**: `lib/screens/settings_restore.dart:1-237`
- **Flows**: WF-013
- **SYS**: SYS-108
- **Visual elements**:
  - `Scaffold` + `AppBar` "Restore from backup"
  - `FilledButton.icon` "Pick a backup file" → SAF picker
  - When picked: red `FilledButton.icon` "Replace local
    data with this backup"
  - 5-state machine: `idle` / `picking` / `picked` /
    `restoring` / `restored`
- **Mock copy**:
  - Help text: "Pick a do it backup (.json). The file
    must have been produced by this app."
  - Confirm dialog: "Replace all local data?" / "Restoring
    from a backup will overwrite every do, completion,
    person, and setting currently on this device."
  - Success: "Restored <N> rows."
- **Caption**: SAF-backed destructive restore.
- **States**: idle / picking / picked / restoring /
  restored / error (BackupFormatException / generic)

### W31 — Recently deleted (tombstones)

- **Source**: `lib/screens/recently_deleted_screen.dart:1-266`
- **Flows**: WF-063
- **SYS**: SYS-135
- **Visual elements**:
  - `Scaffold` + `AppBar` "Recently deleted"
  - List of tombstoned `Do`s with title + "Deleted
    <YYYY-MM-DD>" subtitle + restore + delete-forever
    trailing
  - Empty state: centered message
  - Error state: Retry button
- **Mock copy**:
  - Empty: "Nothing here. Deleted habits show up so you
    can restore or remove them permanently."
  - Subtitle: "<Do name> · deleted <when>"
  - Confirm dialog: "Delete forever?" body repeats the
    destructive verb
- **Caption**: v1.4-stab-H deferred UI surface for the
  v1.4l tombstone column.
- **States**:
  - Loading / empty / populated / error
  - Restore success / failure SnackBar
  - Delete-forever confirm / success / failure

---

## Group H — Widget + Stats + Templates (W32–W36)

The Android home-screen widget + stats screen + template
gallery + device-state live row + DST transition banner.

### W32 — Android home-screen widget

- **Source**: `android/app/src/main/kotlin/.../DoitWidget.kt`
  (Kotlin) + `lib/widgets/widget_bridge.dart` (Dart
  side)
- **Flows**: WF-042..WF-045
- **SYS**: SYS-110, SYS-122, ADR-038, ADR-040
- **Visual elements**:
  - RemoteViews layout with habit icon + name + Done
    button + Skip button + streak badge
  - `Glance` / `AppWidgetProvider` with bidirectional
    MethodChannel
- **Mock copy**: Tile shows "<name> · 🔥 12" with two
  action buttons ("Done", "Skip")
- **Caption**: Widget-side Kotlin→Dart round-trip +
  per-instance widget config + body-tap deep-link.
- **States**:
  - Empty (no habits) → "Add a habit in do it"
  - Single habit → 1 × tile
  - Multiple → cycled or 1-of-N (per-instance config)

### W33 — Stats screen

- **Source**: `lib/screens/stats.dart:1-537`
- **Flows**: WF-052
- **SYS**: SYS-116
- **Visual elements**:
  - `Scaffold` + `AppBar` "Stats"
  - Per-category bucket: section header (category label
    + colored chip), 30-day completion rate "X%", 7-day
    bars chart, per-habit row with streak badge
- **Mock copy**:
  - Header: "Health"
  - Rate: "65%"
  - 7-day bars: vertical bars per day
- **Caption**: Materialized stats queries cached for
  5 seconds.
- **States**:
  - Loading / loaded-empty / loaded-populated
  - Per-habit row: streak N / broken / never-completed

### W34 — Templates gallery (25 templates)

- **Source**: `lib/screens/templates.dart:1-451`
- **Flows**: WF-027..WF-030
- **SYS**: SYS-110
- **Visual elements**:
  - `Scaffold` + `AppBar` "Templates"
  - 5 filter chips: All / Do / Event / Person / Routine
  - 2-column `GridView` of `Card`s per template:
    icon, name, category label, description, "Use
    template" button
  - 25 templates: 12 do + 3 person + 4 event + 6 routine
- **Mock copy**:
  - Filter: "All", "Do", "Event", "Person", "Routine"
  - Card: "Drink water" / "Health" / "Tap to apply"
- **Caption**: Curated templates the user can clone.
- **States**:
  - Loading / loaded
  - Filter: all / do / event / person / routine
  - Per-card: tap-to-apply

### W35 — Device-state live row

- **Source**: `lib/widgets/device_state_row.dart:1-105`
- **Flows**: WF-016 (Settings → Device state)
- **SYS**: SYS-079 (DeviceState source)
- **Visual elements**:
  - `StreamBuilder<DeviceStateSnapshot>`
  - `ListTile` with electrical-services icon + "Device
    state" + live subtitle
  - Trailing: timestamp HH:MM:SS
- **Mock copy**:
  - "Battery: 80%, charging. Headphones: connected.
    Screen: on."
  - "Waiting for first snapshot..."
- **Caption**: Diagnostic row that reflects the current
  `DeviceStateSnapshot` published by `DeviceStateService`.
- **States**:
  - Waiting-for-first-snapshot / live / error

### W36 — DST transition banner

- **Source**: `lib/widgets/dst_transition_banner.dart:1-165`
- **Flows**: WF-105 (DST hook)
- **SYS**: SYS-105
- **Visual elements**:
  - `Material` banner with `secondaryContainer` background
  - Header row: schedule icon + "Daylight saving
    changed" + dismiss `IconButton`
  - Body: "<N> habit times were silently rescheduled"
  - Per-drop bullets: "• <originalLabel> → <newLabel>"
  - CTA: "Reschedule now"
- **Mock copy**:
  - Semantics: "Daylight saving time changed. <N> habit
    time(s) were rescheduled."
- **Caption**: One-shot surface for clock-change drops.
- **States**: drops.isEmpty (hidden) / non-empty (visible)

---

## Group I — Onboarding (W37–W38)

The 5-step permission onboarding + welcome flow.

### W37 — Onboarding (5 permission steps)

- **Source**: `lib/screens/onboarding.dart:1-405`
- **Flows**: WF-001
- **SYS**: SYS-067, ADR-014
- **Visual elements**:
  - `Scaffold` + step indicator (5 dots)
  - Steps: 1) Notifications, 2) Contacts, 3) ExactAlarms,
    4) BackupFolder, 5) CallScreening
  - Per-step: icon + title + body + "Allow" `FilledButton`
  - Step progress: progress bar or step counter
  - "Skip" link (top right)
- **Mock copy**:
  - Step 1: "Notifications" / "We'll remind you when
    habits are due."
  - Step 2: "Contacts" / "Pick people to call on a
    cadence. We never store your contact list."
  - Step 3: "Exact alarms" / "Reminders fire on time even
    in Doze."
  - Step 4: "Backup folder" / "Pick a folder for nightly
    backups."
  - Step 5: "Call screening" / "Let do it handle incoming
    calls (optional)."
- **Caption**: First-launch 5-step permission walk.
- **States**:
  - Per-step: not-yet-asked / granted / denied /
    skipped
  - Final step advances to W38

### W38 — Anchor mode + theme (final onboarding)

- **Source**: `lib/screens/onboarding.dart` (final step
  body)
- **Flows**: WF-001, WF-008
- **SYS**: SYS-067 (anchor + theme), ADR-014
- **Visual elements**:
  - Same scaffold + step indicator (step 6 of 6 — or the
    final panel of step 5)
  - Anchor mode `SegmentedButton`: Manual / First unlock
    / Either
  - Theme `SegmentedButton`: Dark / Light / System
  - "Get started" `FilledButton` (final CTA)
- **Mock copy**:
  - "Anchor mode" / "How do you mark your day as
    started?"
  - Options: "Manual button", "First unlock", "Either"
  - "Theme" / "How should do it look?"
  - Options: "Dark", "Light", "System default"
- **Caption**: The two preference picks that close
  onboarding.
- **States**:
  - Anchor: manual / firstUnlock / either
  - Theme: dark / light / system

---

## Cross-references

- **Traceability**: every WF-NNN, SYS-NNN, and ADR-NNN
  cited above links to
  [`docs/v_model/traceability_matrix.md`](../v_model/traceability_matrix.md).
- **Source-of-truth flow list**:
  [`docs/v_model/workflows.md`](../v_model/workflows.md).
- **Source-of-truth requirement list**:
  [`docs/v_model/requirements.md`](../v_model/requirements.md).
- **Decision rationale**:
  [`docs/v_model/decision_record.md`](../v_model/decision_record.md).
- **i18n**: ARB source at `lib/l10n/app_en.arb` /
  `lib/l10n/app_es.arb`. Copy in this file is paraphrased;
  always check the ARB for the canonical string.

## Notes

- Every wireframe is backed by a real `lib/screens/*.dart`
  or `lib/widgets/*.dart` file as of v1.4-stab-K.
- Touch-target audit (≥ 48dp) and contrast (≥ 4.5:1 body,
  ≥ 3:1 large) are tracked by
  `.claude/rules/lib-screens.md` and validated by the
  v1.4-stab-J a11y cycle tests.
- The app is local-only — no network, no telemetry, no
  cloud sync. Wireframes that look like they could fetch
  data (e.g. location map preview W34) are offline-only by
  design (`INTERNET` permission is deliberately omitted).