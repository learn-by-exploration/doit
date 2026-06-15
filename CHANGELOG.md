# Streak — Changelog

All notable changes to the Streak app are documented here. Streak
follows a V-Model process: each release has a left-side baseline
(`docs/v_model/v<major>_<minor>_baseline.md`) and a right-side
checklist (`v<major>_<minor>_release_checklist.md`). This changelog
is the user-facing summary of what shipped in each release; the
V-Model artifacts are the engineering contract.

## [Unreleased]

_Empty. The v0.4 sign-off commit (v0.4d) appends the
`[0.4.0]` section below._

## [0.4.0] — 2026-06-15 — Contract closure

Six work items that close the v0.3 contract items the v0.3 docs
flagged as v0.4 line items, plus the "Not started" CI 3-gate. The
release is contract-closure work — no new features beyond what
the v0.3 baseline promised. SHA range:
`608483e` → `efbfbdc` (v0.4a..v0.4d). 373 / 373 tests, 41
analyze infos (matches v0.3 baseline), `dart format` clean at
every commit. Right-side gate: `v0_4_release_checklist.md`.

### v0.4a.1 — CI 3-gate

- `.github/workflows/ci.yml` runs `dart format`,
  `flutter analyze --fatal-infos`, and `flutter test` on every
  PR and push to `main` (SYS-057). Three jobs: `quality` (the
  3-gate), `build-debug` (APK), and `build-android-release`
  (AAB on main, gated on 4 `ANDROID_*` secrets). A coverage
  report is uploaded as a CI artifact.
- `test/ci_workflow_test.dart` parses the workflow and asserts
  the three steps + the trigger set. Closes the "Not started"
  row in the v0.3 implementation status table.

### v0.4a.2 — `CHANGELOG.md`

- This file. Sections for v0.1, v0.2, v0.3, and v0.4
  (Keep-a-Changelog shape) (SYS-058). Closes [open question
  #20](docs/v_model/open_questions.md#20).

### v0.4a.3 — `firstLaunch` persisted flag

- `SettingsService.firstLaunchCompleted` is a
  `SharedPreferences`-backed `ValueNotifier<bool>` (SYS-059).
  The hard-coded `true` in `lib/main.dart` is replaced with a
  `ValueListenableBuilder` that reads the notifier. The
  onboarding screen no longer re-appears on every reinstall.
- `test/services/first_launch_persisted_test.dart` (7 tests) +
  `test/widget_test.dart` (3 tests) cover the flag's
  persistence across "app restarts" and the route-switch
  behavior.
- The "Onboarding re-appears on every reinstall" caveat in
  `PRIVACY.md` is removed.

### v0.4b — WorkManager periodic backup

- The dormant `workmanager: ^0.6.0` dep is wired up (SYS-060).
  `lib/services/backup_scheduler.dart` registers a 24-hour
  periodic task; the top-level
  `@pragma('vm:entry-point')` dispatcher
  (`_backupTaskDispatcher`) is registered via
  `Workmanager().initialize()`. The scheduler is opt-in from
  the settings screen.
- The "scheduling call not yet wired" caveat in `PRIVACY.md` is
  removed.

### v0.4c.1 — Backup encryption at rest

- `kBackupFormatVersion` bumps to 2 (SYS-061). The export flow
  takes a user-supplied passphrase, derives a 32-byte key via
  `PBKDF2-HMAC-SHA256` (100,000 iterations, 16-byte random
  salt), and encrypts the JSON payload with `AES-256-GCM`
  (12-byte nonce, MAC appended). Envelope:
  `{"version": 2, "kdf": {name, iterations, saltB64},
  ciphertextB64, macB64, nonceB64}`.
- The import flow supports v1 (plain JSON, back-compat) and v2
  (passphrase + encrypted). A wrong passphrase surfaces as
  `BackupFormatException`. The KDF iteration floor is
  enforced on read.
- The "plain JSON backups" caveat in `PRIVACY.md` is updated
  to describe both the v1 (read-only) and v2 (encrypted)
  paths.
- New dep: `cryptography: ^2.9.0` (mirrors `card_box`).

### v0.4c.2 — TalkBack / a11y static review

- `test/a11y/semantics_labels_test.dart` walks every
  `lib/screens/*.dart` and `lib/widgets/*.dart`, finds every
  `IconButton`, `ListTile`, button, `GestureDetector`, and
  `InkWell`, and asserts each has a `tooltip` / `semanticLabel`
  / `Text` / `Semantics` wrapper / `excludeFromSemantics: true`
  (SYS-062). 18 per-file tests, all green.
- The static analysis caught 6 real issues in
  `lib/screens/add_habit.dart` (three pairs of `+`/`-`
  IconButtons in the `n` / day-of-month / nth-weekday dialogs
  were missing tooltips). Fixed.
- The user's hands-on TalkBack pass on a real device (or
  emulator) is the v0.4d sign-off step.

### v0.4b-release-fix (ADR-013) — WorkManager cold-start crash

- **Post-mortem on the v0.4b release-mode launch crash.** The
  v0.4b release APK (`build/app/outputs/flutter-apk/app-release.apk`
  at SHA `8f0ec5c`) crashed on every cold start on a real
  device. Root cause: two interlocking defects in
  `lib/services/backup_scheduler.dart` —
  1. The WorkManager dispatcher was a **private** top-level
     function (`_backupTaskDispatcher`). In a release AOT
     build, `PluginUtilities.getCallbackHandle` cannot
     resolve a private symbol by name, and
     `Workmanager().initialize(...)` throws before `runApp`.
  2. `init()` rethrew the platform exception. The exception
     propagated out of `main()` and the OS killed the
     process.
- **The fix.**
  1. The dispatcher is renamed to a **public** top-level
     function `backupTaskDispatcher`. The `@pragma('vm:entry-point')`
     annotation stays. The symbol is pinned at the type
     level by a new test
     (`test/services/backup_scheduler_test.dart`:
     `backupTaskDispatcher is a public top-level function`).
  2. `init()` no longer rethrows. A platform exception is
     logged (debug-only, via the `assert(() { print(...);
     return true; }())` pattern that compiles to a no-op in
     release) and the gate is left uncompleted. A follow-up
     `scheduleNightlyBackup()` throws a clear `StateError`.
  3. `main()` wraps the `await BackupScheduler.instance.init()`
     call in a defensive `try/catch` (debug-only `debugPrint`).
- **The new test** `init() swallows platform exceptions`
  throws a `PlatformException` from the mock's
  `initialize` handler and asserts `init()` does not
  rethrow, the call was made, and the gate is left
  uncompleted.
- **The release APK is rebuilt.** v0.4d's sign-off line
  remains "Pending. Awaiting user's hands-on TalkBack
  pass (SYS-062)"; the v0.4b-release-fix commit is the
  artifact the TalkBack pass should exercise. See
  `decision_record.md` ADR-013.

### v0.4b-release-fix-2 (ADR-013 follow-up) — The real cold-start crash: R8 stripping workmanager's `WorkDatabase_Impl`

- **The v0.4b-release-fix at `384cfb2` was a misdiagnosis.**
  The user installed the rebuilt APK on a Samsung Galaxy S23
  (SM-S918B, Android 14) and reported the app still crashed
  on cold start. The 3-gate stayed green, the Dart-side
  dispatcher-name and `init()`-rethrow fixes from `384cfb2`
  are correct on their own, but they were not the cause of
  the release-mode cold-start crash. Pulling
  `adb logcat -b crash` showed the OS-side stack trace:
  `FATAL EXCEPTION: main` → `Unable to get provider
  androidx.startup.InitializationProvider` →
  `WorkManagerInitializer.create` → `Failed to create an
  instance of class
  androidx.work.impl.WorkDatabase.canonicalName`. The
  `r8-map-id-...` prefix on the stack frames confirms R8 had
  run, renaming Room's generated `WorkDatabase_Impl` class
  such that `Class.forName(...)` inside
  `WorkManagerInitializer.create` throws. The crash fires
  at process start, before any Dart code can run.
- **The real cause.** Two compounding issues:
  1. **workmanager's `androidx.startup` auto-init runs at
     process start.** The workmanager 0.6.0 plugin
     auto-registers an `androidx.startup.Initializer` (the
     `WorkManagerInitializer`) that fires before
     `MainActivity.onCreate` and constructs the workmanager
     singleton (which builds the `WorkDatabase`). Streak
     already owns the WorkManager init order from
     `BackupScheduler.init` in Dart — the OS does not need
     to pre-create the singleton.
  2. **R8 ran in this AGP build.** The v0.3 decision was
     "R8 / minify is OFF" but the build config relied on
     the AGP default. AGP 9.1.0 (the version this project
     uses) ran R8 even with `isMinifyEnabled` not set, and
     R8 stripped/renamed the Room-generated
     `WorkDatabase_Impl` class.
- **The fix.**
  1. **Disable workmanager's auto-init at the OS level.**
     `android/app/src/main/AndroidManifest.xml` adds a
     `tools:node="remove"` entry inside the
     `InitializationProvider` block to drop the
     `androidx.work.WorkManagerInitializer` meta-data from
     the merged manifest. The provider itself stays; only
     the workmanager auto-init is removed.
  2. **Pin R8 / minify / resource-shrink off explicitly.**
     `android/app/build.gradle.kts` `buildTypes.release`
     now sets `isMinifyEnabled = false` and
     `isShrinkResources = false` explicitly. The v0.3
     decision becomes a compile-time invariant instead of a
     default assumption. A future AGP upgrade that flips a
     default cannot silently re-enable R8 and re-introduce
     the same crash shape.
- **Two new tests in `test/release_signing_test.dart`** pin
  both invariants:
  - `isMinifyEnabled = false is pinned in
    buildTypes.release` — asserts the explicit
    `isMinifyEnabled = false` and `isShrinkResources = false`
    lines.
  - `AndroidManifest disables workmanager
    WorkManagerInitializer auto-init` — asserts the
    `xmlns:tools` namespace, the
    `androidx.work.WorkManagerInitializer` reference, and
    the `tools:node="remove"` marker.
  A future revert of either change fails the test.
- **The release APK is rebuilt (69.7 MB, 2026-06-16).** The
  user installed it on the same SM-S918B device and the app
  launched — `pidof com.common_games.streak` is non-zero,
  the crash buffer is empty, first frame rendered, touch
  events flowing. The cold-start crash is fixed. See
  `decision_record.md` ADR-013 (follow-up) for the full
  post-mortem, the lessons, and the consequences.

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
