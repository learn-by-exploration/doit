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
| `decision_record.md` | Done (17 ADRs) | — | Append-only |
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
| v0.4b-release-fix (ADR-013) | `384cfb2` | ✓ | 375 / 375 (373 prior + 2 new: cold-start platform-throw + dispatcher symbol) | Post-mortem on the v0.4b release-mode launch crash. Renamed `_backupTaskDispatcher` to public `backupTaskDispatcher` so `PluginUtilities.getCallbackHandle` resolves it in release AOT. Made `init()` swallow platform exceptions (defense in depth). Wrapped `main()`'s `await BackupScheduler.instance.init()` in try/catch. Rebuilds the release APK. See `decision_record.md` ADR-013. |
| v0.4b-release-fix-2 (ADR-013 follow-up) | `1bcc29f` | ✓ | 377 / 377 (375 prior + 2 new: isMinifyEnabled pin + manifest auto-init pin) | The v0.4b-release-fix was a misdiagnosis — the real cold-start crash was R8 stripping workmanager's `WorkDatabase_Impl` class, triggered by `androidx.work.WorkManagerInitializer` running at process start via `androidx.startup.InitializationProvider` (before any Dart code). Surgical fix: `tools:node="remove"` removes the `WorkManagerInitializer` from the merged manifest. Defense in depth: `isMinifyEnabled = false` and `isShrinkResources = false` are pinned explicitly in `buildTypes.release`. Two new tests pin both invariants. Release APK rebuilt (69.7 MB) and verified launches on a real SM-S918B device. See `decision_record.md` ADR-013 (follow-up). |
| v0.5-pre (docs) | `5379c80` | ✓ | 377 / 377 (no new tests) | Pre-work for the v0.5 milestone. Appended SYS-063 (`POST_NOTIFICATIONS`), SYS-064 (`READ_CONTACTS`), SYS-065 (`SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`), SYS-066 (SAF backup folder picker) to `requirements.md`. Added a 4-row traceability block. Closed open questions #5 (READ_CONTACTS revocation) and #6 (SAF URI revocation) — both answered by v0.5's wiring. |
| v0.5a — rename to "do it" | _pending v0.5a commit_ | ✓ | 377 / 377 + v0.5a pin tests in `release_signing_test.dart` (TBD at v0.5a) | App-level rename from "Streak" to "do it". `applicationId` / `namespace` → `com.doit`. Dart package `name:` → `doit`. Directory `streak/` → `doit/`. Kotlin tree `com/common_games/streak/` → `com/doit/`. `MethodChannel('doit/reminders')`, notification channel `doit.reminders`, WorkManager task `doit.backup.nightly`. Version bump `0.4.0+5` → `0.5.0+6`. `StreakCalculator` / `StreakService` / `StreakSnapshot` / `StreakConfig` / `streak_calculator.dart` / `streak_service.dart` stay (feature identifiers). All user-facing display strings updated. v0.5e-fix corrects the v0.5a draft that picked `com.doit.package` (invalid Java namespace) to `com.doit`. v0.5b (PermissionService) and v0.5c (onboarding wiring) follow. |
| **v0.5b — `PermissionService` + sealed result** | _pending v0.5b commit_ | ✓ | 377 / 377 + 9 permission_service_test (TBD at v0.5b) | New `lib/services/permission_service.dart` singleton with the `_ready`-gated init pattern from `.claude/rules/lib-services.md`. Sealed `PermissionResult` (`granted` / `denied(canOpenSettings)` / `permanentlyDenied`) in `lib/services/permission_result.dart`; sealed `BackupFolderResult` (`picked` / `cancelled` / `error`). Public methods: `requestNotifications`, `requestContacts`, `requestExactAlarm`, `requestBackupFolder`, `openAppSettings`, `init`. 9 service tests pin the result branches. The widget layer is untouched; the seam exists. |
| **v0.5c — wire onboarding CTAs** | _pending v0.5c commit_ | ✓ | 386 / 386 + 3 settings_backup_uri + 6 onboarding_wiring (TBD at v0.5c) | `lib/screens/onboarding.dart` `_handleStepCta` dispatches on `_step` to the right `requestX()` method. The four CTAs now do what the rationale text always promised. `SettingsService.backupFolderUri` is a `ValueNotifier<String?>` (defaults `null`); `setBackupFolderUri(String?)` mutates it. 3 `settings_service_backup_uri_test` and 6 `onboarding_permission_wiring_test` pin the behavior. The widget layer no longer imports `permission_handler` or `file_picker` directly. `lib/screens/onboarding.dart` file-level comment is updated to reflect the new reality. |
| **v0.5d — Settings → Permissions tile** | `a04e392` | ✓ | 406 / 406 (386 prior + 4 settings_permissions + 16 settings_test header; matches the v0.5d row in `v0_5_release_checklist.md`) | New `Permissions` section in `lib/screens/settings.dart` between `Wake-up anchor` and `Reliability`. `_PermissionsRow` subscribes to `PermissionService.instance.statuses` and renders one `ListTile` per permission. `_PermissionTile` shows the status text and a "Settings" `TextButton` for `permanentlyDenied` rows that deep-links to `openAppSettings()`. `_BackupFolderTile` re-picks via `requestBackupFolder()` and persists via `setBackupFolderUri()`. 4 `settings_permissions_test` pin the recovery affordance. `docs/v_model/notification_reliability.md` line 126-127 is updated to point at the onboarding probe + Settings → Permissions tile recovery. ADR-016 is appended to `decision_record.md`. |
| **v0.5e-fix (ADR-017)** | `ce6dd83` (local) | ✓ | 407 / 407 (406 prior + 1 net new assertion in `release_signing_test.dart` — the v0.5a pin test was rewritten in place to assert `com.doit` and a new regression guard `isNot(contains('com.doit.package'))` was added) | The v0.5a draft picked `applicationId = "com.doit.package"` and `namespace = "com.doit.package"`. `flutter build appbundle --release` failed: "Namespace 'com.doit.package' is not a valid Java package name as 'package' is a Java reserved keyword". Five surgical changes: `android/app/build.gradle.kts` (`com.doit` / `com.doit`), `AndroidManifest.xml` (`com.doit.FIRE_ALARM`), `android/app/src/main/kotlin/com/doit/package/` → `com/doit/` via `git mv` with intermediate name (the parent already exists), `test/release_signing_test.dart` rewrite + regression guard, four doc files updated. Release AAB (61.0 MB) and APK (69.8 MB) rebuilt successfully. The user's push of `ce6dd83` to `main` is blocked by the auto-classifier (default-branch push); the v0.5e on-device verification is still pending the user attaching the SM-S918B. See `decision_record.md` ADR-017 for the full post-mortem. |
| **v0.5e — release APK + on-device verification** | _pending user's hands-on step_ | _tbd_ | _tbd_ | The user runs `adb uninstall com.doit` (the v0.5e-fix applicationId; was `com.common_games.streak` pre-v0.5) + `adb install build/app/outputs/flutter-apk/app-release.apk` + `adb shell monkey -p com.doit -c android.intent.category.LAUNCHER 1` + the seven-step on-device verification on a real SM-S918B device. The release APK is the install boundary (applicationId changed). v0.5e is the right-side gate; v0.5f is the sign-off commit. No code lands in v0.5e — the user is the executor. |
| **v1.0a.1 — `Habit` → `Do` class rename** | `fee9694` | ✓ | _see git log_ | Pure rename pass: `Habit` → `Do` (sealed hierarchy kept), `HabitRepository` → `DoRepository`, `HabitFixed`/`HabitInterval`/etc. → `DoFixed`/`DoInterval`/etc. DB column names unchanged (no migration). DB column names stay to avoid a needless v2→v3 rename migration. |
| **v1.0a.2 — user-facing copy rename** | `2e6b69d` | ✓ | _see git log_ | "Habit" → "Do" / "Add a do" / "I'm up" → "Start my day" / "Streak" → "Consecutive done" in every screen and widget. Renamed `HabitCategory` → `DoCategory`, `HabitIcons` → `DoIcons`. DB column names unchanged. |
| **v1.0a.3 — V-Model docs sync** | `373913c` | ✓ | _see git log_ | `conops.md` / `requirements.md` / `workflows.md` updated to the "Do / consecutive done" framing. WF-002 → WF-002a. SYS- IDs renamed in the docs only. |
| **v1.0b.1 — templates: model + Drift v2→v3 + repository** | `5b51714` | ✓ | ≥ template_repository_test + template_library_test | `lib/templates/{template.dart,template_library.dart,template_repository.dart}`. `Templates` table added (v2→v3 migration). 25 hand-crafted templates seeded on first run. |
| **v1.0b.2 — templates: catalog UI + save-as-template** | `142df92` | ✓ | ≥ templates_test + add_event extraction tests | New `lib/screens/templates.dart` grid. "Save as template" action on `AddDoScreen` / `AddEventScreen` / `AddPersonScreen`. FAB on home shows "Browse templates" alongside "Create blank". |
| **v1.0b.3 — V-Model docs (templates)** | `6e44a46` | ✓ | _docs only_ | `requirements.md` SYS-067/068; `workflows.md` WF-032/033; `decision_record.md` ADR-020 (template JSON shape); `conops.md` "Templates" section. |
| **v1.0c.1 — `Trigger` / `Condition` / `Action` sealed types** | `32f807d` | ✓ | ≥ triggers + condition + action unit tests | `lib/triggers/trigger.dart`, `condition.dart`, `lib/actions/action.dart`. Each entity gets optional `List<Automation>` field. Migration v3→v4 (nullable JSON column on each table). `RoutineExecutor` skeleton. |
| **v1.0c.2 — `GeofenceService` + `TriggerLocationEnter`/`Exit`** | `bde1284` | ✓ | ≥ geofence_service_test + location_trigger_test | `lib/services/geofence_service.dart` wraps `flutter_geofence` + `geolocator`. `PermissionKind.location` (ACCESS_COARSE_LOCATION). `RoutineExecutor._onGeofence` wired. ADR-021. |
| **v1.0d.1 — `DeviceStateChannel` + `DeviceStateService`** | `9ed6abe` | ✓ | ≥ device_state_probe_test | Kotlin `DeviceStateChannel.kt` exposes charging / battery range / BT device / Wi-Fi SSID / headphones / ringer / foreground app. `lib/services/device_state_probe.dart` `Stream<DeviceStateSnapshot>`. `PermissionKind.bluetooth` (BLUETOOTH_CONNECT). |
| **v1.0d.2 — `TriggerDeviceState` wired** | `c7035cc` | ✓ | ≥ device_state_trigger_test | All 7 device-state trigger subtypes wired. Settings → Triggers screen (live dashboard). ADR-022. |
| **v1.0e.1 — `CalendarService` + `CalendarChannel.kt`** | `f61b718` | ✓ | ≥ calendar_probe_test | `lib/services/calendar_probe.dart` wraps `device_calendar`. `PermissionKind.calendar` (READ_CALENDAR). `TriggerCalendarEvent` (sealed: starts, ends, busy, free). ADR-023. |
| **v1.0e.2 — `CalendarPicker` + Routines section** | `febeac5` | ✓ | ≥ calendar_picker_test + routines_section_test | UI for calendar account picker; Routines section on home screen lists the user's configured automations. |
| **v1.0f.1 — `CallInterceptor` (Kotlin `CallScreeningService`)** | `e00a97f` | ✓ | ≥ call_intercept_test (TestDefaultBinaryMessengerBinding) | `android/.../CallInterceptor.kt` `CallScreeningService` implementation. `ActionCallIntercept` + `ActionOverrideSilent` Dart wrappers. `PermissionKind.phoneState`. `ReminderBridge` extended with `setCallInterceptorConfig`, `setRingerMode`. ADR-019. |
| **v1.0f.2 — Japan silent-mode template + UI** | `ff56021` | ✓ | 741 / 741 (716 prior + 25 new) — coverage ≥ 80% on every new/changed file: `call_interceptor.dart` 84.2%, `japan_routine_config.dart` 100%, `settings_service.dart` 95%, `templates.dart` 81.7%, `onboarding.dart` 93.1%, `add_routine.dart` 83.6%, `settings.dart` 92.6% | Template #16 from the curated library routes to a real `AddRoutineScreen` (enable toggle + contact picker + target-mode radio). `SettingsService.japanRoutine` persists the config. `Settings` → Call-screening tile surfaces `isCallScreeningRoleHeld()` and offers `requestCallScreeningRole()` via `RoleManager`. Onboarding step 4 (call-screening role) appended. Kotlin `CallInterceptor.kt` extended with `isCallScreeningRoleHeld` + `requestCallScreeningRole`. All six v1.0 phases (A–F) closed. |
| **v1.0g — sign-off + version bump + CHANGELOG `[1.0.0]`** | `<this SHA>` | ✓ | 741 / 741 (no new tests; doc-only + version bump) | `pubspec.yaml` → `1.0.0+7`, `lib/build_info.dart` → `kAppVersion = '1.0.0'` / `kAppVersionCode = 7`. `CHANGELOG.md` `[Unreleased]` block now contains `### v1.0/Phase A — Do rename (ADR-024)`, `### v1.0/Phase D — Device-state triggers (ADR-022)`, `### v1.0/Phase F — CallInterceptor + Japan silent-mode (ADR-019 + 019 follow-up)`. New `docs/v_model/v1_0_release_baseline.md` (left-side) + `v1_0_release_checklist.md` (right-side gate). `notification_reliability.md` Device-state + Calendar + Call-screening trigger sections updated from `(planned)` to shipped state. `plan.md` Milestone 7 (v1.0) + Milestone 8 (v1.1 stub) appended. `workflows.md` WF-036 (Phase D device-state routine workflow) appended. `architecture_options.md` Calendar + CallInterceptor + Device-state PR 2 rows appended. v1.0h is the user's hands-on on-device verification on a real SM-S918B. |
| **v1.1a — `RoutineConfig` value class + per-template persistence** | `<v1.1a SHA>` | ✓ | 760 / 760 (741 prior + 19 new — 12 codec + 5 settings-service + 2 routine-executor dispatch regression) | `lib/services/routine_config.dart` (SYS-080 / ADR-025). Structural `==`, deterministic `hashCode`, `copyWith`, `toJson` / `fromJson` codec with version-free per-shape discriminators. `SettingsService.setRoutine` / `getRoutine` / `deleteRoutine` / `routines` (ValueNotifier<Map>) persisted under `doit.routine.<templateId>`. Singleton-with-`_ready` pattern (`.claude/rules/lib-services.md`). |
| **v1.1b — Routine executor: dispatch + reactive settings** | `<v1.1b SHA>` | ✓ | 776 / 776 (760 prior + 16 new — 4 dispatch + 12 reactive subscription tests) | `RoutineExecutor` consumes `SettingsService.routines` reactively via a `ValueNotifier` listener. `_dispatchAction` is a single exhaustive `is`-switch over all five `Action` leaves. ADR-021 wired. Per the V-Model, no widget code; this PR is the executor-side half of v1.1. |
| **v1.1c — `ActionOpenApp` + `RoutineOpenAppRequest` + `RoutineBanner`** | `<v1.1c SHA>` | ✓ | 780 / 780 (776 prior + 4 new banner tests) | `ActionOpenApp` leaf completed (SYS-082 / ADR-026). `RoutineOpenAppRequest` value class + `pendingOpenApp` `ValueListenable`. Passive `RoutineBanner` widget drains FIFO. Captures `NavigatorState` synchronously inside `build` to avoid stale-BuildContext. Home screen places the banner under `ReliabilityBanner.fromService()`. |
| **v1.1d — generic `RoutineApplyScreen` for templates #17..#21** | `c6a8f48` | ✓ | 807 / 807 (780 prior + 27 new — 12 codec + 13 settings-service + 6 widget + 2 catalog regression updates) | `lib/routines/routine_template_payload.dart` (SYS-083 / ADR-027). Fail-soft decoder for `{k:1, routine:{trigger, condition, action, note}}` envelope. `lib/screens/routine_apply.dart` generic apply UX with enable toggle, Save / Update / Delete, malformed-envelope fallback. `SettingsService.deleteRoutine`. `TemplatesScreen._onUse` routes templates #17..#21 to the new screen; the "Coming in v1.1" badge is removed (replaced by the existing "Use this" button). |

## How to update this file

When you finish a phase, change its status from "Not started" to
"Done" and add a one-line note (e.g., "Phase 1 done on
2026-06-15; tests in test/habits/"). When you start a new phase,
add a new row to the implementation table and a new entry to the
phase plan.

Do not delete rows. The history of "what was done when" is part of
the V-Model audit trail.
