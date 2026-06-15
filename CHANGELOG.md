# Streak — Changelog

All notable changes to the Streak app are documented here. Streak
follows a V-Model process: each release has a left-side baseline
(`docs/v_model/v<major>_<minor>_baseline.md`) and a right-side
checklist (`v<major>_<minor>_release_checklist.md`). This changelog
is the user-facing summary of what shipped in each release; the
V-Model artifacts are the engineering contract.

## [Unreleased] — v0.4 polish + privacy

In flight on 2026-06-14. Closes the v0.3 contract items the v0.3
docs flagged as v0.4 line items. The v0.4 section is appended in
the v0.4d sign-off commit; this entry will be filled in at that
time. The scope is:

- **CI 3-gate** — a `.github/workflows/ci.yml` runs `dart format`,
  `flutter analyze --fatal-infos`, and `flutter test` on every PR
  and push to `main` (SYS-057). Lands in v0.4a.1.
- **`CHANGELOG.md`** — this file; closes [open question
  #20](docs/v_model/open_questions.md#20) (SYS-058). Lands in
  v0.4a.2.
- **`firstLaunch` persisted flag** — `SharedPreferences`-backed
  boolean replaces the hard-coded `true` in `lib/main.dart`. The
  onboarding screen no longer re-appears on every reinstall
  (SYS-059). Lands in v0.4a.3.
- **WorkManager periodic backup** — the dormant `workmanager: ^0.6.0`
  dep is wired up; `BackupService.scheduleNightlyBackup()` registers
  the periodic task (SYS-060). Lands in v0.4b.
- **Backup encryption at rest** — `kBackupFormatVersion` bumps to
  2; AES-256-GCM with PBKDF2-HMAC-SHA256 (≥ 100,000 iterations)
  keyed by a user passphrase (SYS-061). Lands in v0.4c.1.
- **TalkBack / a11y static review** — `Semantics` labels on every
  interactive element in `lib/screens/*.dart` and
  `lib/widgets/*.dart`; a static-analysis test walks the widget
  tree (SYS-062). Lands in v0.4c.2. The user's hands-on TalkBack
  pass on a real device is the v0.4d step.

## [0.3.0] — 2026-06-14 — Sideload-to-friends release

The first release that is not just for the user's primary phone.
Six PR-shaped work items (`6502432` → `5ebb441`):

### v0.3a — Public docs + version constant

- `LICENSE` (MIT) at the repo root. (SYS-050.)
- `PRIVACY.md` at the repo root with the four disclosure sections
  (what the app stores, what the app does NOT do, on-device
  footprint, no-`INTERNET` enforcement). The honest caveats
  include "Onboarding re-appears on every reinstall" (closed in
  v0.4a.3), "WorkManager scheduler dep is in pubspec but not
  wired" (closed in v0.4b), and "Backup files are plain JSON, not
  encrypted" (closed in v0.4c.1). (SYS-051.)
- `lib/build_info.dart` exposes `kAppVersion = '0.3.0'` and
  `kAppVersionCode = 3`. `pubspec.yaml` `version` mirrors it. The
  test `test/build_info_test.dart` asserts they match. (SYS-052.)

### v0.3b — Real release signing

- `android/app/build.gradle.kts` now declares a real
  `signingConfigs.create("release")` block that reads
  `android/key.properties` (gitignored) and falls back to debug
  signing when the file is absent. R8 / minify stays **off** for
  v0.3 (no `proguard-rules.pro`). (SYS-053.)
- `android/key.properties.example` committed as the four-key
  template; the real file is gitignored.
- `test/release_signing_test.dart` parses `build.gradle.kts` and
  asserts the structural shape (release `signingConfigs` block,
  `signingConfigs.getByName("release")` reference, the fallback
  to debug, and the `isMinifyEnabled` block is NOT set).

### v0.3c — In-app About / Open source licenses

- The static "v0.1.0 — local-only" tile in the Settings → About
  section is split into two: an informational tile that reads
  `${kAppVersion} — local-only. See PRIVACY.md for the data we
  store`, plus a tappable "Open source licenses" tile that opens
  `showLicensePage(applicationName: 'Streak',
  applicationVersion: kAppVersion, applicationLegalese: 'Local-only.
  No telemetry. No accounts.')`. (SYS-054.)
- `test/screens/settings_licenses_test.dart` asserts both tiles
  are present and the licenses tile opens the standard Flutter
  route.

### v0.3d — Fresh-install smoke test

- `test/integration/fresh_install_test.dart` simulates a wiped-device
  install end-to-end: close the in-memory DB, re-init with
  `AppDatabase(NativeDatabase.memory())`, reset `ReminderService`
  to the `FakeAlarmScheduler`, pump `OnboardingScreen` (assert
  the rationale text), tap the "Done" CTA, pump `HomeScreen`
  (assert the empty-state placeholder), save a `HabitFixed`,
  schedule a test reminder, and assert the `FakeAlarmScheduler`
  received exactly one entry with `habitId == 'streak.test_reminder'`.
  (SYS-055.)
- The hands-on equivalent for the user is a 2-paragraph checklist
  in `docs/v_model/v0_3_release_checklist.md` § Fresh-install
  smoke test, ticked off on a wiped phone or emulator before
  handing the APK to friends.

### v0.3e — Release build

- The release baseline is `v0_3_release_baseline.md`; the
  right-side gate is `v0_3_release_checklist.md`. The release
  artifact is `build/app/outputs/bundle/release/app-release.aab`,
  built with `flutter build appbundle --release` against the
  user's upload key. The SHA of the build is recorded in the
  checklist.

### v0.3 honest README + back-fills

- The "implementation has not started" line in the README's
  Status section was replaced with a pointer to
  `docs/v_model/implementation_status.md` for the current slice.
  (SYS-056.)
- `SYS-048` (Test reminder, WF-028) and `SYS-049` (Bulk complete,
  WF-029) are back-filled in `requirements.md`. The v0.2 runbook
  cited them; the definitions were missing until v0.3a-prep.

## [0.2.0] — 2026-06-14 — UX completeness + v0.2 run #2

Builds on v0.1. Eight new workflows (WF-017..WF-031), sixteen new
SYS-IDs (SYS-032..SYS-047), four implementation phases (`9c032fc`
→ `fd1a4d9`). v0.2's right-side gate is the 14-day real-device
run #2 documented in `acceptance_run_v2.md`; that run is in
flight in parallel with the v0.3 release.

### v0.2a — Completeness

- A new `habits` table migration (`v2_to_v3`) adds `category`,
  `color_seed`, `icon_name`, `paused_until_millis`. The
  `people` table gains `paused_until_millis`. (SYS-045, SYS-046,
  SYS-047.)
- Edit-habit screen at `lib/screens/edit_habit.dart` preserves
  the completion log. (SYS-042, SYS-043.)
- Pause / resume service at `lib/services/pause_service.dart`; the
  habit-detail screen exposes the toggle. (SYS-047.)
- Category, color, and icon are first-class on every habit; the
  home screen renders the new chips. (SYS-045, SYS-046.)
- All four schedule types are exposed in the UI (`HabitInterval`,
  `HabitAnchor`, `HabitDayOfX` join `HabitFixed`). v0.1 had the
  type system but only Fixed in the add-habit flow.

### v0.2b — Events

- New `Event` sealed model at `lib/events/event.dart` with `name`,
  `at`, `leadTime`, optional `missionChain`, optional recurrence
  (`none` / `annually`), and `archivedAt`. (SYS-032..SYS-035.)
- `lib/services/event_repository.dart` (CRUD) and
  `lib/screens/add_event.dart` + `events_list.dart`. One-shot
  scheduling via the existing `AlarmScheduler` path. (SYS-033,
  SYS-034, SYS-035.)

### v0.2c — Contact groups

- New `PersonGroup` sealed model at
  `lib/people/person_group.dart` with `memberIds`, `cadence`,
  `GroupRotation` / `GroupAny` / `GroupAll` semantics, shared
  `channel`, shared `missionChain`, and a per-member
  `lastContactedByMember` map. (SYS-036..SYS-038.)
- `lib/services/person_group_repository.dart` and the rotation
  selector at `lib/people/rotation.dart`. (SYS-037.)
- `lib/screens/add_group.dart` and the home-screen group
  launcher. (SYS-038.)

### v0.2d — UX delight

- `HabitTimeWindow` (subclass of `Habit`) at
  `lib/habits/habit_time_window.dart` with `start`, `end`,
  `weekdays`, optional `targetDuration`. (SYS-039, SYS-040.)
- `lib/widgets/fasting_timer.dart` renders the live timer for
  time-window habits with a `targetDuration`. (SYS-040.)
- The Settings → About section gains a "Send a test reminder"
  tile that schedules a 5-second one-shot alarm via the
  existing `AlarmScheduler` path. (SYS-048 = WF-028.)
- The home screen gains a "Bulk complete" action that logs 1–4
  completions with timestamps spread across the missed window.
  (SYS-049 = WF-029.)

## [0.1.0] — 2026-06-14 — Personal-use baseline

The first installable Android build. Runs on the user's primary
phone; the 14-day real-device run is at
`docs/v_model/acceptance_run.md`. Five implementation phases
(`e5404ac` → `5f4f31d`); one runbook-only phase (`eeb87a0`).

### Phase 0 — Scaffold

- `flutter create` with `--org com.common_games --project-name
  streak --platforms android`. `pubspec.yaml` is `name:
  common_games` (monorepo convention). 18 lints in
  `analysis_options.yaml`; `minSdk = 28`; core-library desugaring
  enabled (required by `flutter_local_notifications` 17.x);
  `workmanager` pinned to `^0.6.0` because 0.5.x uses the removed
  v1 Flutter plugin embedding. The v0.1 permission baseline is in
  `android/app/src/main/AndroidManifest.xml`.

### Phase 1 — Models and schedule engine

- `lib/habits/habit.dart` (sealed, with `HabitFixed`,
  `HabitInterval`, `HabitAnchor`, `HabitDayOfX`).
- `lib/habits/schedule.dart` — pure-Dart `nextOccurrence()` per
  type. (SYS-001, SYS-002.)
- `lib/habits/proof_mode.dart` (sealed `Soft` / `Strong` /
  `Auto`); immutability after creation. (SYS-007, ADR-012.)
- `lib/habits/streak_calculator.dart` — pure-Dart streak from a
  completion log. (SYS-019.)
- `lib/habits/rest_day_budget.dart` — 2 / calendar month,
  hard-reject on exhaustion. (SYS-020.)
- `lib/people/person.dart` (sealed channel type) and
  `lib/people/cadence.dart` (pure-Dart `nextOccurrence()`).
  (SYS-014.)

### Phase 2 — Local DB (Drift)

- `lib/services/db.dart` (Drift singleton, `Completer<void>
  _ready` gate). The schema version is 2; `lib/services/db/
  migrations/v1_to_v2.dart` is the only migration so far.
  (SYS-022.)
- Tables: `habits`, `people`, `completions`, `missions`,
  `settings`. (SYS-022.)

### Phase 3 — Mission engine

- `lib/missions/mission.dart` (sealed `ShakeMission`,
  `TypeMission`, `HoldMission`, `MathMission`, `MemoryMission`).
  (SYS-008..SYS-012.)
- `lib/missions/chain.dart` — pure-Dart executor. A failure
  aborts the rest; timeouts are a special case. (SYS-013,
  SYS-031.)
- `lib/missions/shake_detector.dart` is the only file in this
  folder that imports `package:sensors_plus`. (SYS-008.)
- Per-mission tests cover happy path, parameter edge cases, and
  at least one fail-fast. (SYS-008..SYS-012.)

### Phase 4 — Reminder scheduling

- `lib/reminders/alarm_scheduler.dart`,
  `lib/reminders/notification_service.dart`,
  `lib/reminders/full_screen_intent.dart`, and
  `lib/reminders/anchor_detector.dart`. (SYS-003, SYS-005,
  SYS-006, SYS-029, SYS-015..SYS-017.)
- `android/app/src/main/.../BootReceiver.kt` — native Kotlin
  receiver for `BOOT_COMPLETED` / `LOCKED_BOOT_COMPLETED` /
  `MY_PACKAGE_REPLACED`; re-schedules all pending alarms from
  the local DB. (SYS-016, SYS-017.)
- `android/app/src/main/.../HomeWidgetProvider.kt` — the
  due-now strip on the launcher widget. (SYS-029.)
- The manifest baseline is at
  `android/app/src/main/AndroidManifest.xml` and is cross-checked
  against `docs/v_model/architecture_options.md` on every PR
  that touches it. (SYS-026, SYS-030.)

### Phase 5 — Screens and onboarding

- `lib/screens/onboarding.dart` — permission-first flow with
  rationale screens for `POST_NOTIFICATIONS`, `READ_CONTACTS`,
  `SCHEDULE_EXACT_ALARM`, battery optimization, OEM auto-start,
  backup folder, and anchor mode. (SYS-025.)
- `lib/screens/home.dart` — catalog + due-now strip + "I'm up"
  anchor button. (SYS-015, SYS-027.)
- `lib/screens/add_habit.dart` and `add_person.dart` — multi-step
  form, mission-chain composer. (SYS-001, SYS-002.)
- `lib/screens/stats.dart` — streaks, completion rate, time-of-day
  histograms; consumes `StreakCalculator` over
  `CompletionLogService`. (SYS-021.)
- `lib/screens/settings.dart` — theme, anchor mode, reliability
  row, restore-from-backup tile, OEM guide card. (SYS-003,
  SYS-025, SYS-027.)
- `lib/screens/mission_<name>.dart` (5 screens) for Shake,
  Type, Hold, Math, Memory; per-screen widget tests. (SYS-008..SYS-012.)

### Phase 6 — Backup

- `lib/services/backup_service.dart` — SAF-based. JSON envelope
  `{version, exportedAtMillis, tables}`. `kBackupFormatVersion = 1`.
  Six tables round-trip: `habits`, `people`, `completions`,
  `restDayBudgets`, `settings`, `eventLogs`. (SYS-023, SYS-024.)
- `lib/screens/settings_restore.dart` — SAF file picker + confirm
  dialog. (SYS-024.)
- `test/services/backup_service_test.dart` covers envelope shape,
  round-trip, missing file, malformed JSON, future version, and
  missing-tables.

### Phase 7 — Acceptance run

- The runbook at `docs/v_model/acceptance_run.md` defines 11
  scenarios, 17 SYS-IDs, 9 WF-IDs, a per-day log template, and
  exit criteria. The run is hands-on (install on the primary
  phone); no code lands in this phase.

## [Pre-1.0] — 2026-06-13 — Project bootstrap

- V-Model artifacts seeded: `plan.md`, `conops.md`, `workflows.md`
  (WF-001..WF-016), `requirements.md` (SYS-001..SYS-030),
  `v0_1_baseline.md`, `architecture_options.md`,
  `decision_record.md`, `traceability_matrix.md`,
  `mission_catalog.md`, `notification_reliability.md`, and
  `open_questions.md` (20 items, all non-blocking for v0.1).
- Twelve ADRs in `decision_record.md`. (Append-only.)
- The 18 lints in `analysis_options.yaml` are inherited from
  `board_box`; they catch the issues the v0.1 baseline cares
  about (`unawaited_futures`, `prefer_final_locals`,
  `always_use_package_imports`, etc.).
