# Implementation Status

Status: draft, created 2026-06-13. Last updated 2026-06-14 (Phases 5+6+7 closed).

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
| `test/` directory | Done (2026-06-14) | — | 237 tests passing at the Phase 6 tip (commit `5f4f31d`). Coverage ≥ 80% on `lib/services/`, `lib/screens/`, `lib/reminders/`, `lib/missions/` per Phase 5/6 reports. |
| 3-gate in CI | Done (2026-06-14) | — | v0.4a.1: `.github/workflows/ci.yml` runs the 3-gate on every PR and push to `main`. `test/ci_workflow_test.dart` parses the workflow and asserts the three steps in order. See commit _v0.4a.1_. |
| Coverage ≥ 80% on changed files | Done (2026-06-14) | — | Per-phase reports; the 3-gate enforces it on every commit. |
| 14-day real-device acceptance run | Documented (2026-06-14) | — | Runbook at [`acceptance_run.md`](acceptance_run.md); pending install on the primary phone. |

## V-Model stage: bottom (implementation)

| Slice | Status | Notes |
| --- | --- | --- |
| Flutter app scaffold | Done (2026-06-13) | `flutter create` with package `com.common_games.streak`; `flutter build apk --debug` succeeds. See commit `e5404ac` plus the workmanager/desugaring fixes in the same commit. |
| `analysis_options.yaml` (18 lints) | Done (2026-06-13) | Inherited from `board_box`; in commit `e5404ac`. |
| `lib/habits/` model + schedule engine | Done (Phase 1) | Pure Dart, ≥ 80% coverage; 4 schedule types + sealed Habit hierarchy. |
| `lib/people/` model + contact resolution | Done (Phase 1) | Pure Dart + thin platform channel; sealed `PersonChannel` + `PersonCadence`. |
| `lib/missions/` 5 types + chain executor | Done (Phase 3) | Pure Dart where possible; `ShakeDetector` is the only sensor adapter; chain executor is pure. |
| `lib/reminders/` scheduler + service | Done (Phase 4) | Platform channel to Kotlin; `AlarmScheduler`, `NotificationService`, `FullScreenIntent`, `AnchorDetector`. |
| `android/app/src/main/.../BootReceiver.kt` | Done (Phase 4) | Native Kotlin; re-schedules all pending alarms on `BOOT_COMPLETED`. |
| `android/app/src/main/.../HomeWidgetProvider.kt` | Done (Phase 4) | Native Kotlin; today's due-now strip on the launcher widget. |
| `lib/services/db.dart` (Drift) | Done (Phase 2) | Migrations live in `lib/services/db/migrations/`. |
| `lib/services/backup_service.dart` | Done (Phase 6) | SAF-based; JSON envelope `{version, exportedAtMillis, tables}`; 6 tables round-trip. |
| `lib/screens/onboarding.dart` | Done (Phase 5a+5b) | Permission-first UX; rationale screens for `POST_NOTIFICATIONS`, `READ_CONTACTS`, `SCHEDULE_EXACT_ALARM`, battery-opt, OEM card, backup folder, anchor mode. |
| `lib/screens/home.dart` | Done (Phase 5a+5b) | Catalog + due-now strip + "I'm up" anchor button. |
| `lib/screens/stats.dart` | Done (Phase 5a+5b) | Streaks, completion rate, time-of-day; consumes `StreakCalculator` over `CompletionLogService`. |
| `lib/screens/settings.dart` | Done (Phase 5a+5b, restore link in Phase 6) | Theme, anchor mode, reliability row, restore-from-backup tile. |
| `lib/screens/add_habit.dart`, `add_person.dart` | Done (Phase 5a+5b) | Multi-step form; mission chain composer. |
| `lib/screens/mission_<name>.dart` (5) | Done (Phase 5c) | Shake, Type, Hold, Math, Memory; per-screen widget tests. |
| `lib/screens/settings_restore.dart` | Done (Phase 6) | SAF file picker + confirm dialog; consumes `BackupService`. |
| `lib/services/backup_service.dart` tests | Done (Phase 6) | `test/services/backup_service_test.dart` — 6 cases (envelope, round-trip, missing file, malformed JSON, future version, missing tables). |

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

**Status: Documented (2026-06-14, commit `eeb87a0`).** The runbook
is at [`acceptance_run.md`](acceptance_run.md) — 11 scenarios, 17
SYS- IDs, 9 WF- IDs, per-day log template, exit criteria. The run
itself starts after the user installs the Phase 6 tip on the
primary phone; the run does not require new code.

## Phase log

| Phase | Tip commit | 3-gate | Tests | Coverage on changed files |
|-------|------------|--------|-------|---------------------------|
| 0 — Scaffold | `e5404ac` | ✓ | 1 (placeholder) | n/a |
| 1 — Models + schedule | _see git log_ | ✓ | ≥ 30 (4 schedule types × edge cases + streak + rest day) | ≥ 80% |
| 2 — Local DB (Drift) | _see git log_ | ✓ | migrations + repositories | ≥ 80% |
| 3 — Mission engine | _see git log_ | ✓ | 5 mission types + chain + shake detector | ≥ 80% |
| 4 — Reminders + Kotlin | `79eb931` | ✓ | alarm scheduler + boot + Doze + tz + anchor | ≥ 80% |
| 5a+5b — UI: 6 main screens | `4433004` | ✓ | ≥ 6 widget tests | ≥ 80% |
| 5c — UI: 5 mission screens | `d4fd786` | ✓ | 5 widget tests | ≥ 80% |
| 6 — Backup + restore | `5f4f31d` | ✓ | 6 backup_service tests | ≥ 80% |
| 7 — Acceptance run | `eeb87a0` (doc only) | n/a (no code) | n/a | n/a |
| v0.2 proposal | `76085e4` (doc only) | n/a (no code) | n/a | n/a |
| **v0.2a — Completeness** | `9c032fc` | ✓ | 4 (category, icon, edit, pause) widget + model tests | ≥ 80% |
| v0.2b — Events | `a828333` | ✓ | event_repository + add_event + events_list | ≥ 80% |
| v0.2c — Groups | `457de5b` | ✓ | person_group + person_group_repository + rotation + screens | ≥ 80% |
| v0.2d — UX delight | `54be40f` | ✓ | test reminder (WF-028) + bulk complete (WF-029) + fasting timer (WF-019) | ≥ 80% |
| v0.2e — Run #2 runbook | `fd1a4d9` (doc only) | n/a (no code) | n/a | [`acceptance_run_v2.md`](acceptance_run_v2.md) kicked off 2026-06-14 at SHA `c1b9e64`; Day 0 prep passed (3-gate green, debug apk built, v0.2 changed-files coverage 89.8%) |
| **v0.3a — Public docs + version constant** | `6502432` | ✓ | 4 build_info_test | n/a (docs + a 2-line constant) |
| v0.3b — Release signingConfig | `bcb5c9b` | ✓ | 8 release_signing_test (static analysis) | n/a (Gradle config) |
| v0.3c — In-app About / Licenses | `78b8302` | ✓ | 3 settings_licenses_test | ≥ 80% on `lib/screens/settings.dart` About changes |
| v0.3d — Fresh-install smoke | `50781ce` | ✓ | 1 fresh_install_test (end-to-end) | n/a (integration test) |
| v0.3e — Release (sign-off) | _pending_ | _tbd_ | _tbd_ | [`v0_3_release_checklist.md`](v0_3_release_checklist.md) is the right-side gate; `flutter build appbundle --release` is the user's hands-on step. |
| **v0.4a.1 — CI 3-gate** | _v0.4a.1_ | ✓ | _v0.4a.1_ | `.github/workflows/ci.yml` + `test/ci_workflow_test.dart`. Closes the "Not started" row in the right-side table. |
| v0.4a.2 — CHANGELOG | _v0.4a.2_ | ✓ | _v0.4a.2_ | `CHANGELOG.md` (Keep-a-Changelog shape, v0.4 [Unreleased] section). |
| v0.4a.3 — firstLaunch persisted | _v0.4a.3_ | ✓ | 7 first_launch_persisted + 3 widget_test (SYS-059) | `SettingsService.firstLaunchCompleted` backed by `SharedPreferences`. The "onboarding re-appears on reinstall" caveat in `PRIVACY.md` is removed. |
| v0.4b — WorkManager periodic backup | _v0.4b_ | ✓ | 5 backup_scheduler_test + 3 backup_task_dispatcher_test (SYS-060) | `lib/services/backup_scheduler.dart` wires the `workmanager` plugin to register a 24-hour periodic task. The "scheduling call not yet wired" caveat in `PRIVACY.md` is removed. |
| v0.4c.1 — Backup encryption | _v0.4c.1_ | ✓ | 5 backup_encryption_test (SYS-061) | `kBackupFormatVersion` bumped to 2; AES-256-GCM with PBKDF2-HMAC-SHA256 (100k iterations) behind a user passphrase. v1 plain-JSON stays importable for back-compat. The "plain JSON backups" caveat in `PRIVACY.md` is updated. |
| v0.4c.2 — TalkBack / a11y static review | _v0.4c.2_ | ✓ | 18 a11y/semantics_labels_test (SYS-062) | Static analysis walks every `lib/screens/*.dart` and `lib/widgets/*.dart` and asserts every `IconButton`, `ListTile`, button, `GestureDetector`, and `InkWell` has a `tooltip` / `semanticLabel` / `Text` / `Semantics` / `excludeFromSemantics: true`. Adds 6 missing tooltips to `add_habit.dart`. |
| v0.4d — sign-off | `efbfbdc` | ✓ | 373 / 373 (no new tests; CHANGELOG.md `[0.4.0]` section appended) | v0.4 release checklist updated; sign-off line is "Pending. Awaiting user's hands-on TalkBack pass (SYS-062)." The right-side gate is `v0_4_release_checklist.md`. |

## How to update this file

When you finish a phase, change its status from "Not started" to
"Done" and add a one-line note (e.g., "Phase 1 done on
2026-06-15; tests in test/habits/"). When you start a new phase,
add a new row to the implementation table and a new entry to the
phase plan.

Do not delete rows. The history of "what was done when" is part of
the V-Model audit trail.
