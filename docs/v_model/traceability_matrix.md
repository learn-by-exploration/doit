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
| One-off date reminder (event) | SYS-032, SYS-033, SYS-034, SYS-035 | `lib/events/event.dart`, `lib/events/event_repository.dart`, `lib/screens/add_event.dart`, `lib/screens/events_list.dart` | `test/events/event_repository_test.dart`, widget test for add-event, integration test for the one-shot schedule |
| Contact group | SYS-036, SYS-037, SYS-038 | `lib/people/person_group.dart`, `lib/people/group_repository.dart`, `lib/screens/add_group.dart` | `test/people/group_repository_test.dart`, `test/people/group_rotation_test.dart` |
| Time-window habit | SYS-039, SYS-040 | `lib/habits/habit_time_window.dart`, `lib/widgets/fasting_timer.dart` | `test/habits/time_window_schedule_test.dart`, widget test for the fasting timer |
| Edit habit | SYS-042, SYS-043 | `lib/screens/edit_habit.dart` (extends `add_habit.dart`) | `test/screens/edit_habit_test.dart`, integration test that edit preserves log |
| Pause / resume | SYS-047 | `lib/services/pause_service.dart`, `lib/screens/habit_detail.dart` | `test/services/pause_service_test.dart`, widget test for the pause UI |
| Test reminder (30s) | SYS-041 | `lib/services/test_fire_service.dart`, `lib/screens/habit_detail.dart` | `test/services/test_fire_test.dart`, widget test for the test button |
| Bulk complete | SYS-044 | `lib/services/bulk_completion_service.dart`, `lib/screens/home.dart` | `test/services/bulk_completion_test.dart`, widget test for the bulk button |
| Category / color / icon | SYS-045, SYS-046 | `lib/habits/category.dart`, `lib/widgets/category_chip.dart`, `lib/widgets/icon_picker.dart`, `lib/screens/home.dart` | `test/habits/category_test.dart`, widget test for the icon picker |
| Test reminder — v0.1 aspirational (habit-detail "Test in 30s") | SYS-041 | `lib/services/test_fire_service.dart`, `lib/screens/habit_detail.dart` | Deferred in v0.2; superseded by the Settings tile (SYS-048). |
| Test reminder — v0.2 actual (Settings → "Send a test reminder") | SYS-048 | `lib/screens/settings.dart` (About section), `lib/services/reminder_service.dart` | `test/screens/settings_test_reminder_test.dart`, `test/services/reminder_service_test.dart` |
| Bulk complete — v0.1 aspirational (interval bulk) | SYS-044 | `lib/services/bulk_completion_service.dart` | Subsumed by the v0.2 home-screen bulk action (SYS-049). |
| Bulk complete — v0.2 actual (home-screen bulk) | SYS-049 | `lib/screens/home.dart`, `lib/services/completion_log_service.dart` | `test/services/bulk_complete_test.dart` |
| v0.3 release docs (LICENSE, PRIVACY) | SYS-050, SYS-051 | `LICENSE` (MIT), `PRIVACY.md` | File checks at repo root; reviewed against the v0.3 floor. |
| v0.3 version constant | SYS-052 | `lib/build_info.dart`, `pubspec.yaml` | `test/build_info_test.dart` parses pubspec + asserts constants. |
| v0.3 release signing | SYS-053 | `android/app/build.gradle.kts`, `android/key.properties.example`, `.gitignore` | `test/release_signing_test.dart` parses the build script + gitignore. Hands-on `flutter build appbundle --release` with the user's env vars. |
| v0.3 in-app About / Licenses | SYS-054 | `lib/screens/settings.dart` (About section) | `test/screens/settings_licenses_test.dart` |
| v0.3 fresh-install smoke | SYS-055 | `test/integration/fresh_install_test.dart` | The widget test + the user's hands-on wiped-device checklist in `v0_3_release_checklist.md`. |
| v0.3 honest README | SYS-056 | `README.md` | Manual review on every commit that touches `README.md`. |
| v0.4 CI 3-gate | SYS-057 | `.github/workflows/ci.yml` | `test/ci_workflow_test.dart` parses the workflow and asserts the three steps + the trigger set. |
| v0.4 `CHANGELOG.md` | SYS-058 | `CHANGELOG.md` (repo root) | Manual review on every commit that touches the changelog; `open_questions.md` #20 closed by this row. |
| v0.4 firstLaunch persisted | SYS-059 | `lib/services/settings_service.dart` (firstLaunchCompleted ValueNotifier + SharedPreferences round-trip), `lib/main.dart` (route switch) | `test/services/first_launch_persisted_test.dart` (7 tests) + `test/widget_test.dart` (3 tests: wiped install, mark+remount, override). |
| v0.4 WorkManager periodic backup | SYS-060 | `lib/services/backup_scheduler.dart` (Workmanager register/cancel + top-level dispatcher) | `test/services/backup_scheduler_test.dart` (5 tests) + `test/services/backup_task_dispatcher_test.dart` (3 tests). |
| v0.4 backup encryption | SYS-061 | `lib/services/backup_service.dart` (v2 envelope: PBKDF2-HMAC-SHA256 + AES-256-GCM) | `test/services/backup_encryption_test.dart` (5 tests: round-trip, wrong passphrase, missing passphrase, v1 back-compat, KDF floor). |
| v0.4 TalkBack / a11y static review | SYS-062 | `lib/screens/*.dart`, `lib/widgets/*.dart` (every interactive element with a `tooltip` / `semanticLabel` / `Semantics` wrapper) | `test/a11y/semantics_labels_test.dart` (18 per-file tests: walks every screens + widgets file and asserts the labels). User's hands-on TalkBack pass on a real device is the v0.4d sign-off step. |
| v0.5 permission service seam | SYS-063, SYS-064, SYS-065, SYS-066, SYS-025 (closure) | `lib/services/permission_service.dart`, `lib/services/permission_result.dart` (sealed result: `granted` / `denied(canOpenSettings)` / `permanentlyDenied`); `lib/screens/onboarding.dart` (CTA dispatch on `_step`); `lib/screens/settings.dart` (new `Permissions` tile above `Reliability`); `lib/services/settings_service.dart` (`ValueNotifier<String?> backupFolderUri`); `lib/services/backup_service.dart` reads the URI at backup time | `test/services/permission_service_test.dart` (9 tests: each `requestX()` × each `PermissionStatus` branch + idempotent init + platform-error swallow) + `test/services/settings_service_backup_uri_test.dart` (3 tests) + `test/screens/onboarding_permission_wiring_test.dart` (6 tests: each step CTA × granted/denied/permanentlyDenied + skip + backupUri persistence) + `test/screens/settings_permissions_test.dart` (4 tests: row renders, "Settings" button on `permanentlyDenied`, deep-link tap, on-demand probe) + manual device check on the user's SM-S918B |

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
| WF-017 Add a one-off date reminder (v0.2) | SYS-032, SYS-033, SYS-034, SYS-035 | Widget test for the add-event flow + integration test for the one-shot alarm |
| WF-018 Add a contact group (v0.2) | SYS-036, SYS-037, SYS-038 | Widget test for the add-group flow + unit test for the rotation selector |
| WF-019 Add a time-window habit (v0.2) | SYS-039, SYS-040 | Unit test for `HabitTimeWindow.nextOccurrence()` + widget test for the live timer |
| WF-022 Edit a habit (v0.2) | SYS-042, SYS-043 | Widget test for the edit flow + integration test that edit preserves the log |
| WF-027 Pause / resume (v0.2) | SYS-047 | Unit test for the paused-state guard + widget test for the pause UI |
| WF-028 Test reminder in 30s (v0.2) | SYS-041, SYS-048 | v0.1 aspirational (SYS-041, habit detail button) deferred in v0.2; the v0.2 actual surface is the Settings → About "Send a test reminder" tile (SYS-048). Widget test for the tile + integration test for the test fire. |
| WF-029 Bulk complete (v0.2) | SYS-044, SYS-049 | v0.1 aspirational (SYS-044, interval bulk) subsumed by the v0.2 home-screen bulk action (SYS-049). Widget test for the bulk button + integration test for the timestamp spread. |
| WF-031 Category / color / icon (v0.2) | SYS-045, SYS-046 | Widget test for the icon picker + stats grouping |
| WF-032 Open source licenses (v0.3) | SYS-054 | Widget test for the licenses tile + the route push |

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
