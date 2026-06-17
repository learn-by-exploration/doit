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

## Milestone 6 — v0.5e-fix (ADR-017): the v0.5 release namespace defect

- **Date:** 2026-06-16.
- **Status:** accepted; commit `ce6dd83` is local; push
  to `main` is pending user approval.
- **The defect.** The v0.5a rename commit picked
  `applicationId = "com.doit.package"` and
  `namespace = "com.doit.package"` for the v0.5 release
  (mirroring the Dart package name `doit` with `package`
  as a namespace segment). The 3-gate was green (407/407)
  and the v0.5a pin tests asserted the value *exactly*. At
  v0.5e, `flutter build appbundle --release` failed:
  `Namespace 'com.doit.package' is not a valid Java
  package name as 'package' is a Java reserved keyword`
  (JLS §3.9).
- **The fix (commit `ce6dd83`, ADR-017).** Five surgical
  changes — `android/app/build.gradle.kts` (`com.doit` /
  `com.doit`), `AndroidManifest.xml`
  (`com.doit.FIRE_ALARM`),
  `android/app/src/main/kotlin/com/doit/package/` →
  `android/app/src/main/kotlin/com/doit/` via `git mv`
  with intermediate name `doit_tmp` (the target parent
  already exists), `test/release_signing_test.dart`
  rewrite + new regression-guard
  `isNot(contains('com.doit.package'))`, four doc files
  updated. The release AAB (61.0 MB) and APK (69.8 MB)
  rebuild successfully.
- **Lessons (project-wide).**
  - A green 3-gate does not mean a green build. The 3-gate
    is `dart format` + `flutter analyze --fatal-infos` +
    `flutter test`; the release AOT build is the user's
    hands-on step (ADR-013's lesson, restated). The
    v0.5e-fix is the third post-`flutter build appbundle`
    defect in this project (after v0.4b-release-fix and
    v0.4b-release-fix-2).
  - Pin tests for *invalid* values matter as much as pin
    tests for *exact* values. The v0.5a pin tests asserted
    `applicationId == "com.doit.package"` *exactly*; a
    future re-pick of the bad value would have passed the
    test. The v0.5e-fix regression guard
    (`isNot(contains('com.doit.package'))`) is the
    negative-space pin the project needed.
  - "Stylistic redundancy" in identifiers is a smell, not
    a virtue. The v0.5a rationale for `com.doit.package`
    was "the applicationId matches the Dart package name".
    The cost of the redundancy is a longer string to type
    and review, and the redundancy can hide a defect: a
    reviewer is more likely to approve a string that
    *looks intentional*. The shorter `com.doit` is harder
    to misread.
  - The Java reserved-keyword list (JLS §3.9) is a small,
    fixed list. `package` is the only one likely to
    appear in an Android `applicationId` or `namespace`
    segment. See ADR-017 for the full list.
- **Right-side gate.** `docs/v_model/v0_5_release_checklist.md`
  is updated; the v0.5e on-device verification is still
  pending the user attaching the SM-S918B.
