# V-Model Development Plan

## Purpose

Use the V-model to keep the app honest: user needs and system requirements on
the left side, implementation at the bottom, and explicit verification on
the right side. do it is opinionated — strong reminders, no cloud, single
user — so the V must make those opinions visible at every stage. If a
document stops describing those opinions, it has drifted.

## V-Model Stages

| Left side artifact | Development activity | Right side verification |
| --- | --- | --- |
| User needs | Interviews with self, app-store research (Alarmy, Habit Now, StickK), review of why prior apps failed | User acceptance test (real-day run) |
| Concept of operations | Define actors, modes, scenarios, constraints | Operational scenario validation |
| Operational workflows | Define end-to-end user flows and edge cases | Workflow acceptance tests |
| System requirements | Functional, reliability (Doze/exact-alarm), privacy, platform constraints | System tests |
| Architecture | Flutter app, scheduling layer, mission engine, local DB, backup | Integration tests |
| Module design | Habit / person / mission / reminder models, service singletons | Unit / widget tests |
| Implementation | Flutter code and Android configuration | Static analysis, tests, builds |

The right side is **not optional**. Every requirement has a verification
target. If a requirement cannot be verified, it is not a requirement — it
is a wish. See [`traceability_matrix.md`](traceability_matrix.md).

## Initial Milestones

1. **V0.1 requirements baseline** ✅
   - Lock target user (single user, single device, personal use).
   - Lock target platform (Android only).
   - Lock proof model (3-mode hybrid: Soft / Strong / Auto).
   - Lock mission set (Shake-N, Type, Hold-tap, Math, Memory).
   - Lock schedule set (Fixed, Interval, Anchor, Day-of-week/month/annual).
   - Decide calling flow (notification → dialer pre-filled, no CALL_PHONE).
   - Decide backup (auto local, user-chosen folder).
   - Acceptance: every SYS- ID maps to a test or manual check.

2. **Feasibility prototype** (next)
   - Flutter app shell with theme, navigation, and onboarding.
   - Local DB (sqflite or drift) for habits, people, completions.
   - Reminder scheduling layer (AlarmManager + WorkManager fallback).
   - One mission end-to-end (Shake-N) to prove the engine.
   - One habit preset end-to-end (drink water) to prove the loop.
   - Acceptance: scheduled reminder fires, mission can be completed, log
     written, app survives reboot.

3. **Lean MVP (v0.1)**
   - All 4 habit presets (drink water, call person, morning routine, daily
     todo).
   - All 5 mission types.
   - Full-screen intent + home widget.
   - Wake-up anchor (manual + first-unlock).
   - Auto local backup.
   - do it model with rest days and per-habit + overall.
   - Acceptance: the user runs the app for 14 consecutive days with at
     least 3 of the 4 presets active and >70% completion rate.

4. **Validation**
   - Real-device 30-day run on the user's primary phone.
   - Verify Doze behavior with battery-saver + restricted background.
   - Verify reboot survival, timezone change, DST.
   - Verify backup restore round-trip.
   - Verify streak break rules across a missed rest-day window.
   - Decision gate: ship as personal-use build, or extend scope.

5. **Life-coach richness (v0.2) — committed 2026-06-14**
   - The 8 recommended workflows from
     [`v0_2_proposal.md`](v0_2_proposal.md): events, contact groups,
     time-window habits, edit / pause / test / bulk-complete,
     category + color + icon.
   - 16 new SYS-IDs (SYS-032..SYS-047). The contract is at
     [`v0_2_baseline.md`](v0_2_baseline.md).
   - Phased: v0.2a (foundation) → v0.2b (events) → v0.2c (groups) →
     v0.2d (UX delight) → v0.2e (14-day run #2).
   - Acceptance: 9 criteria in `v0_2_baseline.md`.

## Working Assumptions

- **Tech stack:** Flutter 3.44 / Dart 3.12, matching `board_box` and
  `card_box`. Reuse the 3-gate, lint rules, and CI scaffolding.
- **First release target:** Android only, Android 9+ (API 28+).
- **No cloud, no analytics, no account.** Local-first by mandate.
- **Reliability > features.** A scheduled reminder that fires 15 minutes
  late is a defect, not a quirk. See
  [`notification_reliability.md`](notification_reliability.md).
- **Honesty over gamification.** Streaks are earned, not inflated. The
  completion log is the source of truth; the streak number is derived
  from it.
- **No CALL_PHONE permission.** Calling reminders are user-confirmed by
  tapping a notification that opens the dialer pre-filled.
- **Permission-first UX.** Every platform interface is requested with a
  rationale screen, never on first launch silently.
- **Backup is the user's, not ours.** The export file lives in a folder
  the user picks. We never write to cloud storage automatically.

## V-Model discipline

When a doc changes, the doc on the opposite side of the V is suspect:

| If you change… | Also re-check… |
|---|---|
| `conops.md` (new actor, mode, or scenario) | `workflows.md`, `requirements.md`, `traceability_matrix.md` |
| `workflows.md` (new flow) | `requirements.md` (new SYS- ID), `traceability_matrix.md` |
| `requirements.md` (new or removed SYS- ID) | `traceability_matrix.md`, the matching test |
| `architecture_options.md` (new package or module) | `decision_record.md` (new ADR), `conops.md` (if user-visible) |
| `decision_record.md` (new ADR) | `conops.md`, `architecture_options.md` |
| `mission_catalog.md` (new or changed mission) | `requirements.md`, `mission_catalog.md` invariants, `test/missions/` |
| `notification_reliability.md` (new policy) | `requirements.md` (reliability SYS- IDs), `test/reminders/` |

If you ship a PR that changes a left-side doc but not its right-side
verification (or vice versa), say so in the commit message — the V is
intentionally incomplete for that slice.
