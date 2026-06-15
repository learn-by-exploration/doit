# v0.2 Proposal — Life-coach, UX, and Workflow Audit

Status: proposal, created 2026-06-14. This is a design exploration, not
a commitment. The user picks; chosen items flow into `workflows.md`,
`requirements.md`, and `traceability_matrix.md`, and the implementation
goes into a v0.2 phase plan.

## 0. Why this doc exists

v0.1 is feature-complete on the model + reminder + mission axis. The
14-day runbook is ready. The user is now asking: "what's next?" Three
things at once:

1. **Options.** Multi-contact groups, food/cooking, going-for-something,
   date-specific alarms — features that map to life domains v0.1
   doesn't yet cover.
2. **Life-coach + UX lens.** The product is positioned as "a slightly
   stubborn coach" (per `conops.md`); does the surface area actually
   behave like one, or is it just a habit tracker with missions bolted
   on?
3. **Lifecycle + workflow audit.** Where are we in the product
   lifecycle, and is every workflow that should exist, actually
   defined and handled?

This doc answers all three. The structure: §1 lifecycle, §2 life-coach
gaps, §3 UX patterns, §4 workflow audit (16 existing + 15 missing), §5
the recommended v0.2 set, §6 rollout, §7 decision points.

## 1. Product lifecycle (where we are, where we go)

| Phase | Outcome | Gates |
|---|---|---|
| v0.1 (shipped) | Model + reminder + mission + backup | 3-gate, 14-day run |
| v0.2 (next) | Life-coach richness + UX delight + workflow completeness | 3-gate, 14-day run #2 |
| v0.3 (later) | Platform expansion (iOS, Wear OS, location, voice) | TBD |
| v1.0 (distant) | Public release | Decisions on sync, account, etc. |

v0.2 is the most consequential: the app either becomes "another
habit tracker" or "the slightly stubborn coach the user actually
wants." The risk of v0.2 is feature creep — adding many small things
when the user only needs the right 6-8. The recommendation below
ship at most 8, with a clear deferral list.

## 2. Life-coach perspective: what v0.1 is missing

A life-coach framework covers: **physical, mental, relational,
productivity, recovery.** v0.1 hits each at a thin layer:

| Domain | v0.1 has | v0.1 missing |
|---|---|---|
| **Physical** | Drink water (interval), morning routine (chained) | Walk/run/gym as first-class. Screen-break reminders. Posture. "Going for something" → the user explicitly named this. |
| **Nutrition** | — (no meal habit) | Eat N meals/day, intermittent fasting window (16:8 etc.), "drink water before meals" anchor, "cook dinner" anchored to home. The user named "eating food and making food" — direct gap. |
| **Mental** | — (no mental habit) | Meditate, journal, gratitude, breath. |
| **Relational** | Call 1 person at a cadence | Call a **group** of contacts (family, friends). Birthday events. The user named "friend list, family list" — direct gap. |
| **Productivity** | Daily todo (one-off) | Deep-work blocks, "no email after 6pm", per-day todo list. |
| **Recovery** | Rest day (per habit) | Evening anchor ("winding down"), wind-down chain, sleep-time reminder. |
| **Events** | — (none) | One-off date-specific reminders: birthday, appointment, deadline. The user named "alarm for particular date in time" — direct gap. |

**The user's three hints (groups, food/exercise, date-specific alarms)
map directly to the three highest-leverage gaps.** v0.2 should center
on those.

### Life-coach heuristics worth honoring

- **Friction is the enemy of consistency.** Every additional tap
  reduces the chance of completion. Strong missions are right for
  some habits; the Auto (one-tap) mode should be the easy default
  for any habit that doesn't need a mission (most physical and meal
  habits).
- **Identity > goals.** A habit of "drink water" becomes part of
  "I am a hydrated person." Streaks serve this. The brand voice
  could lean into identity: "12 days of being a hydrated person"
  rather than "12-day streak." (Tone, not code; defer.)
- **Energy management > time management.** Time-based reminders
  (07:00 sharp) are good, but energy-anchored reminders ("after
  your first meeting", "before lunch") are more effective. The
  `HabitAnchor` schedule type is the technical mechanism; it is
  currently under-promoted in the UI.
- **Recovery is part of the process.** Missing a day is not a
  failure. The "missed/skipped" language is right; the missing
  piece is the re-entry UX (a "Welcome back" card after 3+
  missed days).

## 3. UX designer perspective: six high-leverage patterns

Studying Alarmy, Habit Now, StickK, Fabulous, and the v0.1 surface:

1. **"I'm back" recovery screen.** When a habit is missed for 3+
   days, the next time the user opens the app, show a one-card
   screen: "Welcome back. Here's what you missed. No streak
   penalty — just pick back up." The current "missed" copy is
   right; the re-entry UX is missing.
2. **Category color coding.** Health = green, relational = amber,
   productivity = blue, mental = teal, home = brown. Small but
   high-leverage: makes the home screen scannable and the stats
   screen instantly readable. The current habit model has no
   category field — a one-field addition.
3. **"Test this reminder" button.** A "fire this in 30 seconds"
   affordance on every habit detail. The user can verify the alarm
   works without waiting for 09:00. Most-requested feature in
   alarm apps. Trivial to ship; huge trust gain.
4. **Pre-notification.** For high-stakes habits, a 5-min and 1-min
   "incoming" chime so the user can finish what they're doing.
   Alarmy does this. A small settings toggle.
5. **Habit icons.** v0.1 has "optional icon" in WF-002 but the
   implementation isn't visible. A 64-icon Material Symbols picker
   is the right level. The home screen with icons + category
   colors is delightful.
6. **Bulk completion.** "I drank 4 cups of water this morning
   before I opened the app" — a single tap on "Mark 4 done"
   instead of 4 separate taps. For interval habits, this saves
   real time on busy days.

## 4. Workflow audit

### 4.1 Existing 16

| WF | Status | Audit note |
|---|---|---|
| WF-001 Onboarding | ✓ Solid | "I'm experienced" skip is missing for power users. Long-term: per-rationale "Skip" link that routes back from settings. |
| WF-002 Add custom habit | ✓ Solid | Missing: N-per-week schedule, per-habit grace window, per-habit rest-day budget, category, icon picker, anchor-to-habit (vs anchor-to-wake). |
| WF-003 Add person | ⚠️ Gap | Says "picks one or more contacts" but treats them individually. **Multi-person group** is missing. |
| WF-004 Reminder fires | ✓ Solid | Missing: pre-notification, "incoming in 5 min" heads-up. |
| WF-005 Soft completion | ✓ Solid | References "edit completion log" but no WF exists. **Missing: WF-026.** |
| WF-006 Strong completion | ✓ Solid | "Take a break after 3 wrong" is Math-only. Should be uniform across all missions. (Polish, defer.) |
| WF-007 Auto completion | ✓ Solid | Missing: bulk-completion UI for "I did 4 cups at once." |
| WF-008 Mark "I'm up" | ⚠️ Gap | Only morning anchor. No evening anchor ("winding down"). |
| WF-009 Snooze | ✓ Solid | — |
| WF-010 Skip (rest day) | ✓ Solid | Per-habit rest-day budget not exposed in UI. **Missing: WF-025.** |
| WF-011 Review weekly stats | ✓ Solid | Missing: monthly summary, "compared to last week." (Polish, defer.) |
| WF-012 Auto backup | ✓ Solid | The 02:00-04:00 window is in `v0_1_baseline.md` but not in the WF. Add. |
| WF-013 Restore | ✓ Solid | Destructive wipe is documented; no "merge" option. Fine for personal use, document it. |
| WF-014 First-unlock | ✓ Solid | (deferred to WF-008) |
| WF-015 Reboot survival | ⚠️ Minor | "Open do it once to re-arm" banner is invisible if the user never opens the app. **Missing: home widget indicator.** (Polish, defer.) |
| WF-016 Timezone change | ✓ Solid | DST jump forward "silently drops" 02:30 — should be a banner, not silent. (Polish, defer.) |

### 4.2 Missing workflows (15 proposed for v0.2)

| New WF | Title | Touches |
|---|---|---|
| **WF-017** | Add a one-off date-specific reminder (event) | Alarmy model. Birthday, appointment, deadline. |
| **WF-018** | Add a contact group (friend list, family list) | Multi-person cadence: rotation, any, all. |
| **WF-019** | Add a time-window habit (meal, fasting) | Time-windowed progress UI. |
| **WF-020** | Add a quota habit ("5 cups water, any time today") | Soft mode, hit-by-end-of-day. |
| **WF-021** | Add a per-day todo list | List of ≤ 7 items, reset at midnight. |
| **WF-022** | Edit an existing habit | Change schedule, mission, etc. — without losing the completion log. |
| **WF-023** | Archive / delete a habit | Soft delete (preserve log) or hard delete (purge). |
| **WF-024** | Configure per-habit grace window | Override the 03:00 default. |
| **WF-025** | Configure per-habit rest-day budget | Override the 2/month default. |
| **WF-026** | Edit a completion log entry | Within 24h. Mark wrong habit, change timestamp, undo. |
| **WF-027** | Pause / resume a habit or person | User-initiated. e.g., "Pause Call Mom for my vacation week." |
| **WF-028** | Fire a test reminder in 30 seconds | Per habit. The trust-builder. |
| **WF-029** | Bulk-complete N occurrences of an interval habit | "I drank 4 cups" → 4 completions in 1 tap. |
| **WF-030** | Set an evening anchor ("I'm winding down") | Mirror of WF-008. |
| **WF-031** | Add a category / color / icon to a habit | Health/Mind/Relationships/Productivity/Home. 64-icon picker. |

The 15 above plus 6 from §3 (UX patterns) and the 4 from §2
(life-coach gaps) overlap. The de-duplicated v0.2 candidate set is
~12 items, of which I recommend **shipping 8 in v0.2** and parking
the rest for v0.3.

## 5. The recommended v0.2 — concrete workflows and requirements

Each item: workflow title, the user's "why," the UX summary, the new
SYS-IDs to add, and an effort estimate (in phase units, where 1 phase
≈ the Phase 5/6 effort for the do it team).

### 5.1 WF-017 — One-off date-specific reminder (the Alarmy "appointment" model)

- **Priority: highest. v0.2 must-have.**
- **Why:** A birthday reminder, a doctor appointment, a tax deadline,
  "call the bank before they close" — these are NOT habits, they're
  events. v0.1 has no way to express "March 15 at 14:30, do this
  once." This is the single most-missed feature when you use the
  app for a week.
- **UX:** A new "Events" tab on the home screen, separate from
  Habits and People. Add event → name, date+time, optional lead time
  (default 1 day, configurable per event), optional mission
  (default: just a notification), optional recurrence (none,
  annually — for birthdays). On the date, fires like a habit. After
  the date, auto-archives to an "archive" view.
- **New SYS-IDs:** SYS-032 (event model), SYS-033 (one-off
  scheduling), SYS-034 (lead time), SYS-035 (auto-archive).
- **Effort:** 1 phase. Reuse `lib/reminders/alarm_scheduler.dart`
  with a one-shot flag.

### 5.2 WF-018 — Contact group with rotation / any / all cadence

- **Priority: highest. v0.2 must-have.**
- **Why:** "I want to stay in touch with my 4 closest friends, but
  not call the same one every time." Currently you add 4 people,
  each with their own cadence, and you end up calling the same
  friend every Sunday. The user wants a "rotation" semantics:
  "remind me to contact one of these 4, every 3 days." This is what
  the user explicitly named as "friend list, family list."
- **UX:** Add person → "Add multiple" toggle. Pick 2-10 contacts.
  Pick group cadence: **rotation** (next contact each time, with a
  "last contacted" tracker per member), **any** (any one of them
  in the window — mark whichever you did), **all** (all of them
  in the window — multiple completions per cadence). Pick channel
  (shared), mission (shared).
- **New SYS-IDs:** SYS-036 (group model), SYS-037 (rotation logic),
  SYS-038 (any/all semantics).
- **Effort:** 1 phase. New `PersonGroup` table;
  `PersonGroup.nextContact(now)` returns the next person to remind.

### 5.3 WF-019 — Time-window habit (meal, fasting)

- **Priority: high. v0.2 recommended.**
- **Why:** "16:8 intermittent fasting" is a huge use case. The
  user wants a fasting timer with start time, end time, and a
  current-state UI ("Fasting, 6h 12m elapsed, 1h 48m remaining").
  Also for meals: "eat between 12:00-14:00." This is what the
  user named as "eating food and making food" (cooking anchored
  to "I'm home" is a related, simpler variant).
- **UX:** New schedule type "Time window" with start, end, and a
  "current-state" display on the home screen widget. The widget
  shows the live timer when the window is active. When the window
  closes without action, mark missed.
- **New SYS-IDs:** SYS-039 (time-window schedule), SYS-040 (live
  elapsed display).
- **Effort:** 1 phase. New `HabitTimeWindow` subclass of `Habit`.
  Widget update.

### 5.4 WF-022 — Edit an existing habit (without losing the log)

- **Priority: must-have. v0.2 must-have.**
- **Why:** v0.1 has WF-002 (add) but no edit. The user is stuck
  with a bad schedule. Currently you archive + add new, which
  loses the streak history attached to the old habit.
- **UX:** Long-press a habit on home → "Edit" / "Pause" / "Archive"
  / "Delete". Edit opens the same flow as add, pre-filled. The
  completion log is preserved (the habit `id` is stable; only
  fields change).
- **New SYS-IDs:** SYS-042 (immutable id + mutable fields),
  SYS-043 (edit preserves log).
- **Effort:** 0.5 phase. The data model already has stable ids;
  just add the edit flow.

### 5.5 WF-027 — Pause / resume a habit or person

- **Priority: must-have. v0.2 must-have.**
- **Why:** "I'm on vacation for a week, don't bug me to call
  Mom." Currently you have to archive. Pausing preserves the
  schedule and the log, and resumes cleanly.
- **UX:** Long-press a habit/person → "Pause for 7 days / Until I
  resume / Specific date". The reminders are suppressed; the log
  is preserved. Resume re-anchors to the current time without a
  gap penalty.
- **New SYS-IDs:** SYS-047 (paused state).
- **Effort:** 0.3 phase.

### 5.6 WF-031 — Category / color / icon on a habit

- **Priority: high. v0.2 recommended.**
- **Why:** The home screen currently shows habit name + streak.
  Adding color + icon makes it scannable. The stats screen can
  group by category. Small effort, high UX value.
- **UX:** Add/edit habit → pick category (Health, Mind,
  Relationships, Productivity, Home, Other) → pick color
  (auto-assigned by category, user-overridable) → pick icon
  (64 Material Symbols).
- **New SYS-IDs:** SYS-045 (category enum), SYS-046 (icon).
- **Effort:** 0.3 phase. New `category`, `colorSeed`, `iconName`
  fields on `HabitRow`. Tiny migration v3_to_v4.

### 5.7 WF-028 — Fire a test reminder in 30 seconds

- **Priority: high. v0.2 recommended.**
- **Why:** Trust. The user just added a habit and wants to see the
  alarm work without waiting hours. Most-requested feature in
  alarm apps. Trivial to ship; huge trust gain.
- **UX:** On every habit detail screen, a "Test in 30s" button.
  Shows a countdown. Fires the full-screen / notification as it
  would at the real time. A "Cancel test" affordance during the
  countdown.
- **New SYS-IDs:** SYS-041 (test-fire API).
- **Effort:** 0.3 phase. Wrapper around
  `AlarmScheduler.schedule(habit, now + 30s, test: true)`.

### 5.8 WF-029 — Bulk-complete N occurrences of an interval habit

- **Priority: medium. v0.2 recommended.**
- **Why:** "I drank 4 cups of water this morning before I opened
  the app." Currently you have to tap 4 times to log 4
  completions. For interval habits, this saves real time on
  busy days.
- **UX:** On the home screen, an interval habit with missed
  completions shows "Mark 1, 2, 3, or 4 done" buttons. Or a "+N"
  counter that logs that many. The streak and the next-window
  computation handle the bulk log normally.
- **New SYS-IDs:** SYS-044 (bulk completion log).
- **Effort:** 0.3 phase.

### 5.9 Items explicitly DEFERRED to v0.3+

- **WF-020 Quota habit** ("5 cups water, any time today") —
  interesting but doable as a variant of interval in v0.3.
- **WF-021 Per-day todo list** — v0.1's "Daily todo" already
  covers the one-off case; a multi-item list adds UX complexity
  for marginal gain.
- **WF-023 Hard delete** — risk of accidental data loss; defer
  until v0.3 (and require explicit confirmation).
- **WF-024 Per-habit grace window** — useful, but the 03:00
  default works for most. Defer.
- **WF-025 Per-habit rest-day budget** — same; defer.
- **WF-026 Edit completion log** — moderate complexity. Defer
  to v0.3.
- **WF-030 Evening anchor** — defer (the morning anchor
  covers the highest-value case first).
- **WF-006 3-wrong take-a-break uniform** — small polish, defer.
- **WF-015 Re-arm widget indicator** — defer (widget exists;
  the indicator is a v0.3 polish).
- **DST banner** — defer (one-line polish, not a new workflow).
- **"I'm back" recovery screen** (§3.1) — defer; it can land
  as a Phase 8 polish after the 14-day run.
- **Pre-notification** (§3.4) — defer; alarm channels exist
  in v0.1 and the user can opt-in via the system.

## 6. Lifecycle recommendation: how to ship v0.2

If the user accepts, the v0.2 plan is a multi-phase rollout. Effort
estimates assume the model is stable and the work is mostly new
screens + new schedule variants.

| v0.2 sub-phase | Scope | Effort |
|---|---|---|
| **v0.2a — Completeness** | Edit habit (WF-022), pause/resume (WF-027), category+color+icon (WF-031) | 1 phase |
| **v0.2b — Events** | One-off date reminder (WF-017) | 1 phase |
| **v0.2c — Groups** | Contact group (WF-018) | 1 phase |
| **v0.2d — UX delight** | Test reminder (WF-028), bulk complete (WF-029), fasting/meal window (WF-019) | 1 phase |
| **v0.2e — Run #2** | 14-day runbook #2 with the new features | runbook only |

Total: 4 implementation phases + 1 run. About 2-3× the v0.1
implementation effort, because the model is stable and the work
is mostly new screens + new schedule variants.

## 7. Decision points for the user

Before I touch `workflows.md` and `requirements.md`, I need the
user's call on:

1. **Do you want v0.2 at all, or is v0.1 enough for personal
   use?** If the 14-day run is enough, v0.2 is optional. If the
   user wants a v2 to ship to other people, v0.2 is the path.
2. **Of the 8 recommended v0.2 items, which should ship?** The
   list is in §5 ranked. I can take "all 8" or "just the top
   4" or "skip v0.2 entirely" — all are valid.
3. **WF-017 (events) and WF-018 (groups) are the two big new
   domains.** They each need their own phase. Are both in scope,
   or pick one?
4. **Do you want me to also handle the "I'm experienced, skip
   onboarding" UX?** Small but high-trust touch.
5. **Do you want me to write the v0.2 phase plan (like the
   Phase 5 plan I wrote earlier) before any code, or jump
   into implementation?**

## 8. What this doc is NOT

- It is not a code change. Nothing here is in `lib/`.
- It is not a commitment. The user picks what to ship; the
  chosen items flow into the V-Model docs.
- It is not a critique of v0.1. v0.1 is feature-complete on its
  scope. v0.2 is the natural next step.

## Traceability

| Artifact | This doc references |
|---|---|
| `plan.md` | § 1 lifecycle (the v0.1 → v0.2 → v0.3 → v1.0 ladder) |
| `conops.md` | § 2 life-coach framework (the 7 domains) |
| `conops.md § Brand voice` | § 2 "Identity > goals" — informs the v0.2 tone |
| `workflows.md` | § 4 audit (16 existing) + § 5 new workflows (WF-017, 018, 019, 022, 027, 028, 029, 031) |
| `requirements.md` | § 5 new SYS-IDs (SYS-032..SYS-047) |
| `traceability_matrix.md` | Will be updated when the user picks |
| `mission_catalog.md` | § 5.7 test reminder — uses existing mission engine |
| `notification_reliability.md` | § 5.1 events reuse the existing alarm scheduler |
| `acceptance_run.md` | § 6 v0.2e run #2 is the analog of the v0.1 runbook — lives at [`acceptance_run_v2.md`](acceptance_run_v2.md) |
