# v0.2 Requirements Baseline

Status: committed 2026-06-14. The proposal is at
[`v0_2_proposal.md`](v0_2_proposal.md); this doc is the contract.

## Product Scope

v0.2 builds on v0.1. Everything in
[`v0_1_baseline.md`](v0_1_baseline.md) still holds. v0.2 adds:

### 8 new workflows (WF-017..WF-031, the recommended set)

| WF | Title | Why |
| --- | --- | --- |
| **WF-017** | One-off date-specific reminder (event) | The most-missed feature in v0.1: birthdays, appointments, deadlines. Alarmy model. |
| **WF-018** | Contact group (rotation / any / all) | "Friend list", "family list". The v0.1 "Call person" is one contact at a time; v0.2 makes groups first-class. |
| **WF-019** | Time-window habit (meal, fasting) | 16:8 intermittent fasting, meal windows. The user named "eating food, making food". |
| **WF-022** | Edit existing habit (preserves log) | v0.1 has add but no edit. This is CRUD completeness. |
| **WF-027** | Pause / resume habit or person | "I'm on vacation, don't bug me to call Mom." |
| **WF-028** | Test reminder in 30s | Trust-builder. Verify the alarm works without waiting hours. |
| **WF-029** | Bulk-complete N occurrences | "I drank 4 cups" → 1 tap, 4 completions. |
| **WF-031** | Category / color / icon on a habit | Health/Mind/Relational/Productivity/Home. Home screen scannable. |

### 16 new SYS-IDs (SYS-032..SYS-047)

See [`requirements.md`](requirements.md) § System Requirements. Each
maps to a test in the
[`traceability_matrix.md`](traceability_matrix.md).

## Model additions (v0.2)

| New model | Location | Notes |
| --- | --- | --- |
| `Event` (sealed) | `lib/events/event.dart` | Name, `at` (DateTime), `leadTime` (Duration), optional `missionChain`, optional `recurrence` (`none` / `annually`), `archivedAt` (DateTime?). |
| `PersonGroup` (sealed) | `lib/people/person_group.dart` | `memberIds: List<String>`, `cadence`, `semantic: GroupRotation` / `GroupAny` / `GroupAll`, shared `channel`, shared `missionChain`, `lastContactedByMember: Map<String, DateTime>`. |
| `HabitTimeWindow` | `lib/habits/habit_time_window.dart` | Subclass of `Habit` (or new sealed sibling). `start`, `end`, `weekdays`, optional `targetDuration` (for fasting). |
| `HabitCategory` | `lib/habits/category.dart` | Enum: `health`, `mind`, `relationships`, `productivity`, `home`, `other`. Plus a `colorOf(category)` and `defaultIconOf(category)`. |

## Schema migration (v0.2)

`lib/services/db/migrations/v2_to_v3.dart` adds:

- `habits`: `category TEXT NOT NULL DEFAULT 'other'`, `color_seed INTEGER NOT NULL DEFAULT 0`, `icon_name TEXT`, `paused_until_millis INTEGER`.
- `people`: `paused_until_millis INTEGER`.
- New `events` table (`id`, `name`, `at_millis`, `lead_time_millis`, `mission_chain_json`, `recurrence`, `archived_at_millis`, `created_at_millis`).
- New `person_groups` table (`id`, `name`, `cadence_type`, `cadence_params_json`, `semantic`, `channel`, `handle`, `mission_chain_json`, `created_at_millis`).
- New `person_group_members` table (`group_id`, `person_id`, `last_contacted_millis`, PRIMARY KEY (`group_id`, `person_id`)).

## Backup format

`kBackupFormatVersion` is bumped to **2**. The new envelope includes
`events` and `personGroups` tables. v0.1 backups (`version: 1`)
restore cleanly into a v0.2 DB (forward-migration: the new tables
are simply absent; old data is preserved).

## Constraints (unchanged from v0.1)

- No `INTERNET` permission. No cloud, no sync.
- No `CALL_PHONE` permission. Dialer pre-fill only.
- No telemetry, no analytics, no account.
- Local-only data. Backup is local (SAF folder the user picks).
- Single user, single device.
- Android-only v0.2.
- The 3-gate (format, analyze, test) must pass on every commit.

## Defaults (new in v0.2)

- Default `category` for a new habit: `other`.
- Default `color_seed` for a new habit: 0 (grey).
- Default `icon_name`: null (the home screen falls back to the
  category's canonical icon).
- Default `pausedUntilMillis` for a new habit / person: null
  (not paused).
- Default event lead time: 1 day.
- Default event recurrence: none.
- Default group semantic: rotation.

## Phase plan

The v0.2 work is sliced into 4 implementation phases plus a run #2:

| Phase | Scope | Effort | Commit-on-green gate |
| --- | --- | --- | --- |
| **v0.2a — Completeness** | DB migration v2→v3, edit habit (WF-022), pause/resume (WF-027), category/color/icon (WF-031) | 1 phase | 3-gate |
| **v0.2b — Events** | Event model + repo + screens + one-shot scheduling (WF-017) | 1 phase | 3-gate |
| **v0.2c — Groups** | PersonGroup + repo + rotation logic + screens (WF-018) | 1 phase | 3-gate |
| **v0.2d — UX delight** | HabitTimeWindow + fasting timer (WF-019), test reminder (WF-028), bulk complete (WF-029) | 1 phase | 3-gate |
| **v0.2e — Run #2** | 14-day real-device run #2 with the new features | runbook only | acceptance |

## Acceptance (v0.2 exit criteria)

A v0.2 build is acceptable if, after a 14-day real-device run #2 on
the user's primary phone, all of the following are true:

1. **v0.1 acceptance holds.** Every criterion in
   [`acceptance_run.md`](acceptance_run.md) is still "yes".
2. **Events work.** The user added at least 2 events (a birthday
   + a deadline), both fired on time, both auto-archived.
3. **Groups work.** The user added at least 1 group (family or
   friends) and contacted at least 80% of the group members
   during the window.
4. **Time-window works.** The user added at least 1 time-window
   habit (a meal or a fast); the live timer was visible; the
   streak updated.
5. **Edit / pause / test work.** The user edited a habit at least
   once without losing the log; paused a habit for at least 1
   day; fired at least 1 test reminder.
6. **Bulk complete works.** The user used bulk-complete at least
   once on a busy day; the timestamp spread is correct.
7. **Category color works.** The user assigned at least 3
   different categories; the home screen renders icons + colors;
   the stats screen groups by category.
8. **The 3-gate passed with zero failures on every commit during
   the 14 days.**
9. **Coverage ≥ 80% on the v0.2 changed files.**

The per-day log, per-scenario acceptance table, and 3-gate log
that gate these 9 criteria live in
[`acceptance_run_v2.md`](acceptance_run_v2.md) — the v0.2 runbook
that this baseline cites for the right-side verification.

If any criterion fails, fix it before v0.3.

## Approval status

This baseline is committed. The user has approved the v0.2 scope
(see [`v0_2_proposal.md`](v0_2_proposal.md) § 7 — decision points).
Any change to a v0.2 commitment (adding / removing a workflow or
SYS-ID, changing a default) requires an updated
`v0_2_proposal.md` and a fresh sign-off in the same change.
