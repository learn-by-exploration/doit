# Traceability Matrix

Status: draft baseline, created 2026-06-13.

Every row ties a left-side artifact to a right-side verification. The
matrix is the right-side of the V. If a row has no verification, it is
not yet a real requirement.

## Need → Requirement → Design → Verification

| Need / Decision | Requirement IDs | Design Area | Verification |
| --- | --- | --- | --- |
| Add habits with schedules, proof, and missions | SYS-001, SYS-002, SYS-004, SYS-007 | `lib/habits/`, `lib/screens/add_habit.dart` | `test/habits/add_habit_test.dart`, manual acceptance |
| Schedule reminders reliably | SYS-003, SYS-016, SYS-017, SYS-018, SYS-030 | `lib/reminders/`, `AlarmScheduler`, `BootReceiver` | `test/reminders/alarm_scheduler_test.dart`, `test/reminders/reboot_survival_test.dart`, manual device check |
| Surface reminders that interrupt | SYS-005, SYS-006, SYS-029 | `lib/reminders/notification_service.dart`, `lib/reminders/full_screen_intent.dart`, `lib/screens/widget_home.dart` | Widget test, manual device check on locked phone |
| Three proof modes (Soft / Strong / Auto) | SYS-007, SYS-013, SYS-031 | `lib/habits/proof_mode.dart`, `lib/missions/chain.dart` | `test/habits/proof_mode_test.dart`, `test/missions/chain_test.dart` (chain-timeout test) |
| Five mission types | SYS-008, SYS-009, SYS-010, SYS-011, SYS-012 | `lib/missions/shake.dart`, `lib/missions/type.dart`, `lib/missions/hold.dart`, `lib/missions/math.dart`, `lib/missions/memory.dart` | `test/missions/<name>_test.dart` for each |
| Call reminders open dialer | SYS-014 | `lib/reminders/call_action.dart`, `AndroidManifest.xml` (no `CALL_PHONE`) | Intent inspection test, manual device check, manifest diff in PRs |
| Wake-up anchor | SYS-015, SYS-016, SYS-017 | `lib/reminders/anchor_detector.dart`, `lib/screens/widget_home.dart` | Unit test, widget test, manual device check on first unlock |
| Streaks and rest days | SYS-019, SYS-020 | `lib/habits/streak_calculator.dart`, `lib/habits/rest_day_budget.dart` | `test/habits/streak_calculator_test.dart` covering DST, rest day, missed-then-backfilled, partial-day edge cases |
| Stats | SYS-021 | `lib/screens/stats.dart`, `lib/services/stats_service.dart` | Widget test, manual acceptance |
| Local-only data | SYS-026, SYS-030 | `lib/services/`, `AndroidManifest.xml` (no `INTERNET`) | Code search, CI grep rule, manifest review |
| Auto backup | SYS-023, SYS-024 | `lib/services/backup_service.dart`, `lib/screens/settings_restore.dart` | `test/backup/auto_backup_test.dart`, `test/backup/restore_test.dart` |
| Local DB and migrations | SYS-022 | `lib/services/db.dart`, `lib/services/migrations/` | `test/db/migration_test.dart`, manual DB inspection on real device |
| Permission-first UX | SYS-025 | `lib/screens/onboarding.dart` | Widget test, manual acceptance |
| 3-gate and coverage | SYS-027, SYS-028 | CI workflow, `analysis_options.yaml` | CI run on every PR; coverage report artifact |
| Home widget | SYS-029 | `android/app/src/main/.../HomeWidgetProvider.kt`, `lib/services/widget_sync.dart` | Widget test, manual device check |

## Workflow → Requirement → Verification

| Workflow | Requirement IDs | Verification |
| --- | --- | --- |
| WF-001 First-time onboarding | SYS-022, SYS-025, SYS-027 | Widget test, manual acceptance |
| WF-002 Add a custom habit | SYS-001, SYS-002, SYS-003, SYS-004, SYS-007, SYS-016, SYS-018, SYS-019, SYS-031 | Widget test, manual acceptance |
| WF-003 Add a person | SYS-001, SYS-002, SYS-004 | Widget test, manual acceptance |
| WF-004 Reminder fires (general) | SYS-003, SYS-005, SYS-006, SYS-013, SYS-016, SYS-017, SYS-018, SYS-019, SYS-020 | Integration test, manual device check |
| WF-005 Soft completion | SYS-005, SYS-019, SYS-020 | Widget test |
| WF-006 Strong completion (mission chain) | SYS-006, SYS-007, SYS-008, SYS-009, SYS-010, SYS-011, SYS-012, SYS-013, SYS-020, SYS-031 | Unit + widget tests for each mission, integration test for the chain |
| WF-007 Auto completion (interval) | SYS-007, SYS-019, SYS-020 | Unit test, widget test |
| WF-008 Mark "I'm up" | SYS-015, SYS-016, SYS-017 | Unit test, manual device check on first unlock |
| WF-009 Snooze | SYS-005, SYS-006, SYS-018, SYS-019 | Unit test, widget test |
| WF-010 Skip (rest day) | SYS-019, SYS-020 | Unit test |
| WF-011 Review weekly stats | SYS-021 | Widget test, manual acceptance |
| WF-012 Auto backup | SYS-023, SYS-026 | Integration test, manual device check |
| WF-013 Restore | SYS-024, SYS-026 | Integration test, manual device check |
| WF-014 First-unlock wake-up | SYS-015, SYS-016, SYS-017 | Unit test, manual device check |
| WF-015 Reboot survival | SYS-016, SYS-017, SYS-030 | Integration test, manual device check |
| WF-016 Timezone change / travel | SYS-016, SYS-017, SYS-019 | Unit test for `nextOccurrence` across DST + zone change |

## How to use this matrix

- **Adding a new SYS- ID:** add a row to the top table and a row to
  the workflow table (if applicable). The verification column must
  name a test file or a manual check.
- **Removing a SYS- ID:** remove the row. The related tests are
  candidates for deletion (review with the user).
- **Changing a test name or path:** update the verification column.
  If the test no longer covers the requirement, that is a defect
  in the test, not the requirement.
- **Adding a workflow:** add a row to the workflow table; every step
  in the workflow must reference at least one SYS- ID.
