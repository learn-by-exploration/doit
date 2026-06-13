# Implementation Status

Status: draft, created 2026-06-13.

This doc tracks what is done, what is in flight, and what is next,
mapped to the V-Model stages. Update it as work progresses.

## V-Model stage: left side (requirements)

| Artifact | Status | Owner | Notes |
| --- | --- | --- | --- |
| `plan.md` | Done | — | V-Model stages + milestones + working assumptions |
| `conops.md` | Done | — | Mission, actors, modes, normal scenario, constraints, success |
| `workflows.md` | Done | — | WF-001..WF-016 |
| `requirements.md` | Done | — | SYS-001..SYS-030 |
| `v0_1_baseline.md` | Done | — | Lean v0.1 scope, decisions, acceptance criteria |
| `architecture_options.md` | Done | — | Tech stack, packages, modules, manifest baseline |
| `decision_record.md` | Done (12 ADRs) | — | Append-only |
| `traceability_matrix.md` | Done | — | Need ↔ Requirement ↔ Design ↔ Verification |
| `mission_catalog.md` | Done | — | Spec for each of the 5 mission types |
| `notification_reliability.md` | Done | — | Doze, exact-alarm, boot survival |
| `open_questions.md` | Done (20 items) | — | Not blocking; can be answered in v0.2 |

## V-Model stage: right side (verification)

| Artifact | Status | Owner | Notes |
| --- | --- | --- | --- |
| `test/` directory | Not started | — | Empty |
| 3-gate in CI | Not started | — | Inherit from `board_box` workflow |
| Coverage ≥ 80% on changed files | Not started | — | Inherit from `board_box` workflow |
| 14-day real-device acceptance run | Not started | — | Acceptance criteria in `v0_1_baseline.md` |

## V-Model stage: bottom (implementation)

| Slice | Status | Notes |
| --- | --- | --- |
| Flutter app scaffold | Done (2026-06-13) | `flutter create` with package `com.common_games.streak`; `flutter build apk --debug` succeeds. See commit `e5404ac` plus the workmanager/desugaring fixes in the same commit. |
| `analysis_options.yaml` (18 lints) | Done (2026-06-13) | Inherited from `board_box`; in commit `e5404ac`. |
| `lib/habits/` model + schedule engine | Not started | Pure Dart, ≥ 80% coverage |
| `lib/people/` model + contact resolution | Not started | Pure Dart + thin platform channel |
| `lib/missions/` 5 types + chain executor | Not started | Pure Dart where possible |
| `lib/reminders/` scheduler + service | Not started | Platform channel to Kotlin |
| `android/app/src/main/.../BootReceiver.kt` | Not started | Native Kotlin |
| `android/app/src/main/.../HomeWidgetProvider.kt` | Not started | Native Kotlin |
| `lib/services/db.dart` (Drift) | Not started | Migrations live in `lib/services/migrations/` |
| `lib/services/backup_service.dart` | Not started | SAF-based |
| `lib/screens/onboarding.dart` | Not started | Permission-first UX |
| `lib/screens/home.dart` | Not started | Catalog + due-now strip + "I'm up" |
| `lib/screens/stats.dart` | Not started | Streaks, completion rate, time-of-day |
| `lib/screens/settings.dart` | Not started | Permissions, exact-alarm, Doze, OEM card, theme |

## Phase plan (proposed)

The v0.1 baseline has 4 phases (see
[`plan.md`](plan.md#initial-milestones)). The implementation is
sliced into the following sub-phases. Each ends with a green
3-gate and at least one new test:

### Phase 0 — Scaffold

- `flutter create`.
- Copy `analysis_options.yaml`, `.gitignore`, `lib/main.dart`
  theme.
- Add the 6 confirmed dependencies (`flutter_local_notifications`,
  `android_alarm_manager_plus`, `workmanager`, `permission_handler`,
  `drift`, `flutter_contacts`).
- Confirm 3-gate passes on the empty app.

**Status: Done (2026-06-13).** `flutter create` ran with
`--org com.common_games --project-name streak --platforms android`,
pubspec set to `name: common_games` (monorepo convention), the
v0.1 permission baseline added to `AndroidManifest.xml`, the
18-lint analysis options in place, `minSdk = 28`, and core
library desugaring enabled (required by
`flutter_local_notifications` 17.x). `workmanager` was bumped
to `^0.6.0` because 0.5.x uses the removed v1 Flutter plugin
embedding. 3-gate green (`dart format` clean, `flutter analyze
--fatal-infos` reports "No issues found!", `flutter test` passes
the placeholder widget test); `flutter build apk --debug`
produces `build/app/outputs/flutter-apk/app-debug.apk`. See
commit `e5404ac` ("docs+chore(playbook): finish streak sync —
pointer table, doc notices, Phase 0 scaffold").

### Phase 1 — Models and schedule engine

- `lib/habits/habit.dart` (sealed, with `HabitFixed`,
  `HabitInterval`, `HabitAnchor`, `HabitDayOfX`).
- `lib/habits/schedule.dart` (pure-Dart `nextOccurrence()` per
  type).
- `lib/habits/proof_mode.dart` (sealed Soft/Strong/Auto).
- `lib/habits/streak_calculator.dart` (pure-Dart streak from a
  completion log).
- `lib/habits/rest_day_budget.dart`.
- `lib/people/person.dart` (sealed channel type).
- Unit tests for all of the above.
- 3-gate green.

### Phase 2 — Local DB

- `lib/services/db.dart` (Drift).
- Tables: `habits`, `people`, `completions`, `missions`,
  `settings`.
- `lib/services/migrations/` with `v1_to_v2` placeholder.
- Migrations test (downgrade → upgrade round-trip).
- 3-gate green.

### Phase 3 — Mission engine

- `lib/missions/mission.dart` (sealed Shake/Type/Hold/Math/Memory).
- `lib/missions/chain.dart` (chain executor).
- `lib/missions/shake_detector.dart` (sensor integration).
- `test/missions/<name>_test.dart` for each.
- 3-gate green.

### Phase 4 — Reminder scheduling

- `lib/reminders/alarm_scheduler.dart`.
- `lib/reminders/notification_service.dart`.
- `lib/reminders/full_screen_intent.dart`.
- `lib/reminders/anchor_detector.dart`.
- `android/app/src/main/.../BootReceiver.kt`.
- `android/app/src/main/.../HomeWidgetProvider.kt`.
- `AndroidManifest.xml` (manifest baseline from
  `architecture_options.md`).
- Integration test for alarm + boot survival.
- 3-gate green.

### Phase 5 — Screens and onboarding

- `lib/screens/onboarding.dart` (permission-first flow).
- `lib/screens/home.dart` (catalog + due-now + "I'm up").
- `lib/screens/add_habit.dart`, `add_person.dart`.
- `lib/screens/stats.dart`.
- `lib/screens/settings.dart` (with OEM guide card).
- Widget tests for each.
- 3-gate green.

### Phase 6 — Backup

- `lib/services/backup_service.dart`.
- `lib/screens/settings_restore.dart`.
- `test/backup/auto_backup_test.dart`.
- `test/backup/restore_test.dart` (idempotent).
- 3-gate green.

### Phase 7 — 14-day real-device run

- Install on primary phone.
- Run all 4 presets + 1 custom habit.
- Verify the 8 acceptance criteria in `v0_1_baseline.md`.
- File any defects as `fix:` commits; do not start v0.2 until
  every criterion is "yes".

## How to update this file

When you finish a phase, change its status from "Not started" to
"Done" and add a one-line note (e.g., "Phase 1 done on
2026-06-15; tests in test/habits/"). When you start a new phase,
add a new row to the implementation table and a new entry to the
phase plan.

Do not delete rows. The history of "what was done when" is part of
the V-Model audit trail.
