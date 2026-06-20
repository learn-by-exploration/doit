# System Requirements

Status: draft baseline, created 2026-06-13.

This document is the contract. Every SYS- ID maps to a test or a manual
check via the [traceability matrix](traceability_matrix.md). If a
requirement cannot be verified, it is not a requirement — it is a wish.

## User Need

A single user wants to build daily dos and maintain important
relationships on one Android phone, without the app lying to them about
consecutive runs, without their data leaving the device, and without
the operating system silently killing the alarms. The product fuses
do-tracking, contact-cadence, Alarmy-style strong enforcement, and
(v1.0+) location / device-state / calendar / call-screening routines.

## Product Scope

### In scope for v0.1

- Add a do with name, icon, schedule, proof mode, mission chain,
  consecutive-run policy.
- Add a person from device contacts with cadence, channel, and (if
  Strong) mission chain.
- Schedule a do to fire at the right time on Android.
- Fire the reminder, surface as a high-priority notification, and
  optionally a full-screen intent.
- Complete the reminder in three modes: Soft (one-tap), Strong
  (mission chain), Auto (interval window).
- Track completions, misses, snoozes, and skips honestly in a local log.
- Compute consecutive runs: per-do and overall, with a configurable
  skip-day budget (renamed from rest-day in v1.0/Phase A — see ADR-024).
- Show stats: consecutive run, best run, completion rate, time-of-day.
- Survive device reboot, timezone change, and OEM battery savers
  (with a user prompt to whitelist).
- Auto backup to a user-chosen folder, once per day.
- Restore from a backup file.
- Permission-first UX: every platform interface is explained and
  requested with rationale.
- Local-only data. No network calls with user data.
- All 4 do presets (drink water, call person, morning routine,
  daily todo) work end-to-end.
- All 5 mission types (Shake, Type, Hold, Math, Memory) work
  end-to-end.
- Home screen widget shows next 3 due items.

### Possible later scope (v0.2+)

- iOS port.
- Quick-settings tile for "I'm up" / "Snooze next".
- Voice quick-add ("OK, add: call Dad this Sunday").
- Location-anchored dos (e.g., "At the office, start work routine").
- Barcode / QR mission (with home-printed codes).
- Photo mission (with on-device scene match).
- Encrypted backup (with user passphrase).
- Multiple home widget layouts.
- App lock (biometric / passcode) — to keep family from snoozing for you.
- Theming: dark mode is v0.1; light + custom themes are v0.2.
- Watch / Wear OS companion for quick-done.
- Web companion for read-only stats.

### In scope for v0.2 (committed 2026-06-14)

See [`v0_2_proposal.md`](v0_2_proposal.md) and
[`v0_2_baseline.md`](v0_2_baseline.md) for the full scope. The
8 workflows and 16 SYS-IDs that v0.2 adds (SYS-032..SYS-047) are
committed; the model layer will be extended (categories, events,
groups, time-window schedule, paused state, edit flow). v0.2 does
NOT loosen any v0.1 constraint (still no `INTERNET`, no
`CALL_PHONE`, no cloud, no telemetry).

### Out of scope unless re-approved

- Multiple named users on one device (no family / partner profiles).
- Multi-device sync.
- Cloud backup of any kind (auto or manual).
- A web app.
- Any feature that requires a backend.
- Telemetry, analytics, crash reporting that leaves the device.
- Storing payment cards, bank data, or any credentials.
- CALL_PHONE permission. Always dialer pre-fill.
- Access-card / RFID / NFC emulation. do it reminds you to take
  action; it does not pretend to be the thing.

## System Requirements

| ID | Requirement | Verification |
| --- | --- | --- |
| **SYS-001** | The app shall allow a user to add a do with name, schedule type, schedule parameters, proof mode, mission chain (if Strong), consecutive-run policy. Do names shall be unique within the local DB (case-insensitive, trim); a duplicate shall be rejected at save time with `DuplicateDoName`. | Widget test (`test/screens/add_habit_test.dart`) + manual acceptance |
| **SYS-002** | The app shall allow a user to add a person from device contacts with display name, cadence, channel, mission chain (if Strong). | Widget test (`test/people/add_person_test.dart`) + manual acceptance |
| **SYS-003** | The app shall schedule a do's next occurrence to fire within ±60 sec of the target time on a non-Doze device, via AlarmManager exact alarm. | Unit test for `AlarmScheduler.nextOccurrence()` + integration test (`test/reminders/alarm_scheduler_test.dart`) + manual device check |
| **SYS-004** | The app shall expose four schedule types: Fixed (time-of-day), Interval (every N units), Anchor (relative to a wake-up or other do), Day-of-X (week / month / year). | Unit test for each schedule type's `nextOccurrence()` + widget test for the schedule picker |
| **SYS-005** | A reminder shall surface as a high-priority notification with the do name, due time, and a "Done" / "Open" action. The app shall create one or more Android notification channels for reminders (default channel id: `do.reminders`, importance HIGH). The user may configure sound and vibration per-channel in the system settings. | Widget test + manual device check |
| **SYS-006** | A reminder shall optionally surface as a full-screen intent when the screen is off, locked, or the user has the app in the background. The full-screen activity must show the proof-mode UI. | Integration test (mock Activity) + manual device check on a locked phone |
| **SYS-007** | The app shall support three proof modes per do: Soft (one-tap), Strong (mission chain), Auto (interval window). | Unit test for `DoProofMode` + widget test for each mode's UI |
| **SYS-008** | The Shake-N mission shall derive the count from the accelerometer, must require a magnitude threshold AND an inter-shake spacing, and must not advance when the phone is still. The default magnitude threshold shall be 14.0 m/s², the minimum inter-shake spacing shall be 250 ms, and the maximum inter-shake spacing shall be 1500 ms. These defaults may be overridden per-do; all three values are immutable after the do has at least one completion (see ADR-012). | Unit test for `ShakeDetector.isShake(sample)` + manual device check on a desk |
| **SYS-009** | The Type phrase mission shall require an exact (case-insensitive, trim) match of the user-entered text against the expected phrase. | Unit test for `TypeMission.verify()` |
| **SYS-010** | The Hold-tap mission shall require a continuous press of 3-5 seconds (configurable). Releasing early shall reset the progress. | Unit test for `HoldMission.tick(progress, dt)` + widget test |
| **SYS-011** | The Math mission shall present a random math problem and require a correct answer. Difficulty shall scale (Easy: 1-digit × 1-digit; Hard: 2-digit × 2-digit with addition). After 3 consecutive wrong answers on the same problem, the app shall surface a "take a break" nudge and auto-fail the mission (no fourth attempt); the wrong-answer count is logged. | Unit test for `MathProblem.next(difficulty)` + widget test for the 3-wrong nudge |
| **SYS-012** | The Memory mission shall present a 4×3 grid of card pairs and require all matches within 60 s. Failed attempts shall be logged. | Unit test for `MemoryMission` + widget test |
| **SYS-013** | Strong-mode dos shall require a chain of one or more missions in declared order. Skipping or reordering shall invalidate the proof. | Unit test for `MissionChain.next(current, completed)` |
| **SYS-014** | A call reminder, when tapped, shall open the system dialer with the contact's number pre-filled. The app shall not call `ACTION_CALL`. | Unit test (intent inspect) + manual device check; `AndroidManifest.xml` must not declare `CALL_PHONE` |
| **SYS-015** | The app shall support a wake-up anchor with two detection modes (manual, first-unlock) selectable in settings, plus a "either with confirmation" hybrid. A 4-hour debounce shall prevent a second wake-up anchor event from being recorded within 4 hours of the previous one. | Unit test for `AnchorDetector` + widget test for the anchor setting |
| **SYS-016** | The app shall re-schedule all pending reminders on device boot, timezone change, and DST change. | Integration test (`test/reminders/reboot_survival_test.dart`) + manual device check |
| **SYS-017** | The app shall survive Doze by combining exact-alarm (primary), a foreground-service heartbeat for "I'm up" (best effort), and a user-driven Doze whitelist prompt. | Manual device check with battery-saver + Doze simulation; banner surfaced if not whitelisted |
| **SYS-018** | The app shall re-schedule a snoozed reminder at the chosen snooze time and track the snooze count per occurrence. A snoozed reminder may be snoozed up to 3 times within a single occurrence; further snooze taps shall surface "you've snoozed 3 times — skip or do it" and offer no further snooze option (the user may still Skip with a skip day or accept a consecutive-run break). | Unit test for `ReminderScheduler.snooze()` + widget test for the 3-strike cap |
| **SYS-019** | The app shall compute consecutive runs per do and overall. A run breaks only on a missed day past the grace window. The completion log is the source of truth; the run count is derived. The default grace window shall be 03:00 local time the next day — a do completed between 00:00 and 03:00 shall count for the previous day; the grace window is per-do configurable. | Unit test for `ConsecutiveCounter.compute()` in `test/habits/streak_calculator_test.dart` across at least 20 cases (DST, skip day, missed-then-backfilled, mode change mid-run, partial-day edge cases) |
| **SYS-020** | The app shall support a configurable skip-day budget per do (default 2 / month; class name: `SkipBudget` — was `RestDayBudget` pre-v1.0). A skip day preserves the consecutive run. | Unit test for `SkipBudget.consume()` in `test/habits/rest_day_budget_test.dart` |
| **SYS-021** | The app shall display per-do and overall stats: current consecutive run, best consecutive run, completion rate (30/90/365 days), time-of-day heatmap, missed-day distribution. | Widget test for the stats screen + manual acceptance |
| **SYS-022** | The app shall store all user data in a local SQLite database. The DB schema shall be versioned; a forward-migration shall run on launch if the schema version is older. | Unit test for migrations (`test/db/migration_test.dart`) + DB inspection on a real device |
| **SYS-023** | The app shall auto-backup the local DB to a user-chosen folder once per day, in a versioned JSON file. Files older than 30 days shall be pruned. The backup envelope shall be `{"version": 1, "exported_at": <ISO8601>, "data": {...}}`; a file with `version` higher than the app's supported version shall be rejected with "backup from a newer version"; a file with a lower `version` shall be migrated forward via `lib/services/db/migrations/`. If the SAF write fails, the app shall retry up to 3 times with exponential backoff (1 s, 5 s, 30 s); if all retries fail, a banner shall be shown and the user notified via a "last backup failed" status in Settings. | Integration test (`test/backup/auto_backup_test.dart`) + manual device check |
| **SYS-024** | The app shall restore from a backup file picked via the system file picker. Restore shall be idempotent (re-importing the same file twice produces no duplicates). | Integration test (`test/backup/restore_test.dart`) |
| **SYS-025** | The app shall request all platform permissions with a rationale screen that explains the consequence of denial. | Widget test for the onboarding flow + manual acceptance |
| **SYS-026** | The app shall not perform any network call with user data. Any `http(s)://` or `dart:io` HTTP usage shall be a security defect and shall be removed. | Code search + a CI grep rule that fails on `import 'package:http'` and `Uri.https` outside the dev-only test harness |
| **SYS-027** | The app shall follow the existing `board_box` 3-gate: `dart format --output=none --set-exit-if-changed .` → `flutter analyze --fatal-infos` → `flutter test`. All three must pass with zero failures. | CI run on every PR |
| **SYS-028** | The app shall maintain ≥ 80% test coverage on changed files. Coverage report shall be uploaded as a CI artifact. | `flutter test --coverage` + `genhtml` + report check |
| **SYS-029** | The app shall display a home screen widget that shows the next 3 due items, each with a "Done" button. Tapping "Done" shall mark the item done and refresh the widget. | Widget test + manual device check |
| **SYS-030** | The app shall provide a permission baseline in `AndroidManifest.xml` that matches the v0.1 scope. No permission shall be added without an ADR. | `AndroidManifest.xml` review + diff in PRs that touch it |
| **SYS-031** | The total mission-chain timeout (sum of per-mission `timeout` values) shall not exceed 5 minutes at do-save time. A chain whose total exceeds 5 min shall be rejected with `ChainTimeoutTooLong`. Chains longer than 5 min shall require an explicit user confirmation in v0.2. | Unit test in `test/missions/chain_test.dart` validates that a chain with timeout sum > 5 min throws on save |
| **SYS-032** | The app shall allow a user to add a one-off date-specific reminder ("event") with name, date+time, lead time, optional mission chain, optional recurrence (none / annually). The event shall surface on the home screen "Events" tab. After the event fires, it shall auto-archive (move to an "Archived" list, never deleted for 90 days). | Widget test for the add-event flow + integration test for the one-shot alarm schedule + manual acceptance |
| **SYS-033** | The app shall schedule an event as a one-shot alarm at `event.at - event.leadTime`. The one-shot alarm shall use the same `AlarmScheduler` path as do alarms (exact alarm primary, WorkManager fallback). A duplicate fire of the same event-id shall be deduped. | Unit test for the one-shot schedule computation + integration test for the alarm manager call |
| **SYS-034** | The app shall support a per-event lead time of 5 min, 15 min, 1 h, 1 day, or 1 week. The lead time must be less than the gap from `now` to `event.at`. A lead-time violation at save time shall throw `InvalidLeadTime`. | Unit test for the lead-time validator |
| **SYS-035** | The app shall auto-archive an event 24 h after it fires. Archived events shall be retained for 90 days, then purged by the next nightly backup. The user can browse archived events from the Events tab. | Integration test for the auto-archive job |
| **SYS-036** | The app shall allow a user to add a contact group with 2-10 contacts, a name, a shared cadence, a shared channel, and a shared mission chain. The group shall be a first-class entity in the local DB (separate from `PersonRow`). | Widget test for the add-group flow + integration test for the group CRUD |
| **SYS-037** | For a `Rotation` group, the scheduler shall pick the next contact by `least_recently_contacted`, breaking ties by `id` ascending. The picked contact is recorded in the `person_groups.lastContactedPersonId` field after a completion. | Unit test for the rotation selector across 4 cases (single member, all same timestamp, all different timestamps, ties) |
| **SYS-038** | For an `Any` group, the completion log records which specific contact was contacted. For an `All` group, the next reminder is the member with the oldest `lastContactedAt`. An `All` group with any unresolved members is still schedulable; the user is shown a banner. | Unit test for the any/all selector |
| **SYS-039** | The app shall support a `DoTimeWindow` schedule type (renamed from `HabitTimeWindow` in v1.0/Phase A — see ADR-024) with start time, end time, and weekdays. The `nextOccurrence(from)` shall return the next `start` time on the next active weekday, or `now` if `now` is inside the window. The window's end-time shall be the deadline for completion. | Unit test for `DoTimeWindow.nextOccurrence()` across DST, weekday wrap, and within-window |
| **SYS-040** | The home screen shall display a live timer for any active time-window do: "Fasting, 6h 12m elapsed, 1h 48m remaining" (or "Lunch window, 2h 18m left"). The timer shall update every minute via a `Ticker`. | Widget test + manual device check |
| **SYS-041** | The do detail screen shall expose a "Test in 30s" button. The test fire shall use the existing `AlarmScheduler` with a `test: true` flag, fire the same notification / full-screen intent the real reminder would, and NOT log a completion or reschedule the next occurrence. | Widget test for the test button + integration test for the test fire |
| **SYS-042** | The do `id` shall be immutable after creation. All other fields (name, schedule, proof mode, mission chain, consecutive-run policy, category, color, icon, pausedUntilMillis) shall be mutable via the edit flow. | Unit test for the immutable-id invariant |
| **SYS-043** | An edit of a do shall preserve the completion log and the consecutive-run history. The `id` is stable; only fields change. The run is recomputed from the unchanged log. | Integration test: edit a do, assert the log is intact, assert the run is unchanged |
| **SYS-044** | The app shall allow the user to bulk-complete N occurrences of an interval do (1 ≤ N ≤ daily target, capped at 4 per tap). Each bulk-logged completion shall have a timestamp spread across the missed window range, not all at the bulk-log moment. | Widget test for the bulk button + integration test for the timestamp spread |
| **SYS-045** | The app shall support a `DoCategory` enum (renamed from `HabitCategory` in v1.0/Phase A — see ADR-024): `health`, `mind`, `relationships`, `productivity`, `home`, `other`. A new `category` field on `DoRow` (DB row, `category` column) defaults to `other`. The stats screen shall group by category. | Unit test for the enum + widget test for the stats grouping |
| **SYS-046** | The app shall support a per-do icon from a 64-icon Material Symbols set. The icon shall be stored as a string key on `DoRow` (DB column `iconName`; e.g., `local_drink`, `directions_run`, `self_improvement`). A null icon defaults to the category's canonical icon. | Widget test for the icon picker |
| **SYS-047** | The app shall support a paused state for dos and persons. A `pausedUntilMillis` field on `DoRow` and `PersonRow` (nullable). When set and in the future, the scheduler shall not fire reminders for that row. A paused period shall not break consecutive runs. | Unit test for the paused-state guard + widget test for the pause UI |
| **SYS-048** | The app shall expose a "Send a test reminder" tile in Settings → About. Tapping the tile shall schedule a one-shot alarm 10 seconds in the future via the same `AlarmScheduler` path as a real do alarm, with a `test: true` flag on the `AlarmEvent`. The test fire shall render the same notification / full-screen intent the real reminder would, and shall NOT log a completion or reschedule the next occurrence. (Back-fill; originally cited by `acceptance_run_v2.md` for WF-028.) | Widget test for the tile + integration test for the test fire |
| **SYS-049** | The home screen shall expose a "Bulk complete" action for interval dos with ≥ 2 missed occurrences. The action shall log 1–4 completions per tap, each with a timestamp spread across the missed window range (not all at the tap moment). A SnackBar shall confirm the count landed. (Back-fill; originally cited by `acceptance_run_v2.md` for WF-029.) | Widget test for the bulk button + integration test for the timestamp spread |
| **SYS-050** | The repository shall include a `LICENSE` (MIT) at the project root, copyright the project owner, and be the sole license for the project. The license text shall be the verbatim text from the Open Source Initiative. No `LICENSE` change shall land without an ADR. | File check on `LICENSE` exists at repo root + grep that the text matches the MIT template |
| **SYS-051** | The repository shall include a `PRIVACY.md` at the project root that discloses (1) the on-device data inventory, (2) what the app does **not** do (no server, no analytics, no telemetry, no advertising ID, no install ID, no crash reporter, no cloud backup), (3) the no-`INTERNET` enforcement, and (4) honest caveats about unimplemented features whose schema slots exist. The privacy notice shall not claim more than the code does. | File check on `PRIVACY.md` exists at repo root + manual review of the four sections |
| **SYS-052** | The app's version string shall be a single source of truth: a `kAppVersion` / `kAppVersionCode` constant in `lib/build_info.dart` that mirrors the `pubspec.yaml` `version:` field. A test (`test/build_info_test.dart`) shall parse `pubspec.yaml` and assert the two stay in sync; the 3-gate shall fail on drift. | Unit test in `test/build_info_test.dart` |
| **SYS-053** | The release build shall read `android/key.properties` (gitignored) and wire a real `signingConfigs.release` block in `android/app/build.gradle.kts`. The `release` buildType shall reference `signingConfigs.getByName("release")` and shall NOT set `isMinifyEnabled` (R8 / minify is off for v0.3). If `key.properties` is missing, the build shall fall back to the debug signing config so dev builds keep working. The keystore files (`*.jks`, `*.der`, `key.properties`) shall never be committed. | Unit test in `test/release_signing_test.dart` parses the build file + `.gitignore` check + hands-on `flutter build appbundle --release` |
| **SYS-054** | The Settings → About section shall include a "Open source licenses" `ListTile` that opens the standard Flutter `showLicensePage` (passing `applicationName: 'do it'`, `applicationVersion: kAppVersion`, `applicationLegalese: 'Local-only. No telemetry. No accounts.'`). The static version row in the About section shall read `kAppVersion`. (See `WF-032`.) | Widget test in `test/screens/settings_licenses_test.dart` |
| **SYS-055** | A widget test in `test/integration/fresh_install_test.dart` shall simulate a wiped-device install: empty Drift DB → `OnboardingScreen` renders → "done" path is exercised → `HomeScreen` renders → add a `DoFixed` → fire a test reminder via `ReminderService.scheduleTestReminder()` → assert the scheduler received the request. A 2-paragraph wiped-device checklist in `docs/v_model/v0_3_release_checklist.md` § Fresh-install smoke test shall be ticked off by the user on a wiped phone (or emulator) before handing the apk to friends. | Widget test in `test/integration/fresh_install_test.dart` + manual checklist sign-off |
| **SYS-056** | The `README.md` Status section shall be honest: it shall not say "Implementation has not started" once v0.1 code has shipped, and shall not claim a future milestone as "done". It shall point to `docs/v_model/implementation_status.md` for the current slice. | Manual review on every commit that touches `README.md` |
| **SYS-057** | The repository shall include a `.github/workflows/ci.yml` file that runs the 3-gate (`dart format` → `flutter analyze --fatal-infos` → `flutter test`) on every `pull_request` and `push` to `main`. A static-analysis test (`test/ci_workflow_test.dart`) shall parse the workflow file and assert the three steps are present in the right order. | Unit test in `test/ci_workflow_test.dart` parses the workflow + green CI run on the v0.4a.1 tip |
| **SYS-058** | The repository shall include a `CHANGELOG.md` at the project root with sections for v0.1, v0.2, v0.3, and v0.4. Each section shall list the headline features and the bug fixes. The v0.4 section shall be appended in the v0.4d sign-off commit. Closes open question #20. | File check on `CHANGELOG.md` exists at repo root + section review |
| **SYS-059** | The `firstLaunch` flag shall be persisted across app restarts via `SharedPreferences` (or an equivalent in the `SettingsService`). The hard-coded `firstLaunch = true` in `lib/main.dart` shall be replaced with a service read. A test (`test/services/first_launch_persisted_test.dart`) shall close the service, reopen it, and assert the flag is still the value it was set to. | Unit test in `test/services/first_launch_persisted_test.dart` |
| **SYS-060** | `BackupService.scheduleNightlyBackup()` shall register a `workmanager` periodic task (24-hour frequency) that invokes the existing `runBackup()` entrypoint. The Kotlin side shall register the Dart callback via `WorkmanagerPlugin`'s `setPluginRegistrantCallback`. A test shall mock the `Workmanager` interface and assert the call. `PRIVACY.md` shall no longer disclose the "scheduling call not yet wired" caveat. | Unit test for the scheduler call + the Kotlin `BackupWorker.kt` registering the callback |
| **SYS-061** | `kBackupFormatVersion` shall be 2. The export flow shall (1) generate a 16-byte salt via `Random.secure()`, (2) derive a 32-byte AES-256-GCM key via PBKDF2-HMAC-SHA256 with ≥ 100,000 iterations, (3) generate a 12-byte nonce, (4) encrypt the JSON envelope, (5) write `{"version": 2, "kdf": {...}, "ciphertextB64": "...", "nonceB64": "..."}` to the file. The import flow shall support v1 (plain JSON, back-compat) and v2 (passphrase + encrypted). A test (`test/services/backup_encryption_test.dart`) shall round-trip with a passphrase. `PRIVACY.md` shall no longer disclose the "plain JSON backups" caveat. | Unit test in `test/services/backup_encryption_test.dart` |
| **SYS-062** | Every interactive element in `lib/screens/*.dart` and `lib/widgets/*.dart` (every `Button`, `IconButton`, `ListTile`, `TextField`, and tap-able `GestureDetector`) shall have a `Semantics` label, a `tooltip`, or a `semanticLabel`. A static-analysis test (`test/a11y/semantics_labels_test.dart`) shall walk the widget tree of every public screen and assert the labels. The user's hands-on TalkBack pass on a real device or emulator is the v0.4d step. | Unit test in `test/a11y/semantics_labels_test.dart` + manual device check |
| **SYS-063** | Onboarding step 0 shall invoke `PermissionService.requestNotifications()` to request `POST_NOTIFICATIONS` (Android 13+). The CTA advances the step on `granted`; on `denied` (one-shot) the CTA stays enabled and a "Try again" affordance is rendered; on `permanentlyDenied` a "Go to Android Settings" button is rendered that calls `PermissionService.openAppSettings()`. The widget layer shall not call `permission_handler` directly — the call goes through the service seam. (v0.5 / ADR-016.) | Service test (`test/services/permission_service_test.dart`) + widget test (`test/screens/onboarding_permission_wiring_test.dart`) + manual device check |
| **SYS-064** | Onboarding step 1 shall invoke `PermissionService.requestContacts()` to request `READ_CONTACTS`. Same shape as SYS-063. Revoking `READ_CONTACTS` after adding a person pauses all person-based dos and surfaces a banner; re-granting resumes. (v0.5 / ADR-016. Closes open question #5.) | Service test + widget test for the onboarding step + manual device check |
| **SYS-065** | Onboarding step 2 shall invoke `PermissionService.requestExactAlarm()` to request `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` (Android 12+). On Android 12+ this is a system policy permission, not a runtime permission, so the most common result is `denied` with the deep-link affordance as the primary recovery path. The home-screen reliability banner shall reflect the SYS-065 result. (v0.5 / ADR-016.) | Service test + widget test for the onboarding step + manual device check |
| **SYS-066** | Onboarding step 3 shall invoke `PermissionService.requestBackupFolder()` to open the SAF folder picker (`ACTION_OPEN_DOCUMENT_TREE`). On a non-null `treeUri`, the URI is persisted to `SettingsService.backupFolderUri` (a `ValueNotifier<String?>`) and the step advances. On cancellation, the step advances anyway — the backup folder is skippable per ADR-014 step 6. A revoked SAF URI pauses auto-backup and surfaces a banner; the user re-picks from Settings → Restore. (v0.5 / ADR-016. Closes open question #6.) | Service test + widget test for the onboarding step + `test/services/settings_service_backup_uri_test.dart` + manual device check |
| **SYS-067** | The app shall ship a curated library of at least 25 templates (Do / Event / Person / Routine) seeded into the `Templates` Drift table on first run via `TemplateLibrary.seedBuiltIns(TemplateRepository.instance)`. Phase B ships 19 templates (12 Do + 3 Person + 4 Event). Phase F adds 6 routine templates to reach the 25-template quota. The seed is idempotent (`INSERT OR IGNORE` keyed on `id`) and runs from `AppDatabaseService.init()` AFTER the v2→v3 migration completes, guarded by `from < 3` so existing v3 users do not re-seed. A user that deletes a built-in does not get it back on the next launch. Each built-in carries `kTemplateFormatVersion = 1` envelope with the matching inner key (`"do"`, `"event"`, `"person"`). Routine templates' inner payload is opaque in Phase B (Phase F adds the `RoutineTemplatePayload` decoder). | Widget test (`test/screens/templates_test.dart`: 25 cards render after first seed; idempotent re-seed returns 0) + service test (`test/services/template_repository_test.dart`: `seedBuiltIns` is idempotent across two runs; `deleteById` refuses built-ins) |
| **SYS-068** | The user shall be able to save any configured Do / Event / Person as a reusable user-saved template from the AppBar overflow action "Save as template" on `AddHabitScreen` / `AddEventScreen` / `AddPersonScreen`. The action captures the current form state (NOT the persisted row) into a new `Template` row with `isBuiltIn: false`. The catalog screen lists user templates alongside built-ins (a flat list per `ADR-020` § decision 4). A user template may be deleted via long-press → confirm → `TemplateRepository.instance.deleteById(id)`. Built-ins are read-only — `deleteById` on a built-in throws `TemplateIsBuiltIn`. Templates are restored automatically via the existing backup service (they are a regular Drift table). | Widget test (`test/screens/add_event_test.dart`: save-as-template writes a row with `isBuiltIn: false` and the right envelope) + integration test (`test/services/template_repository_test.dart`: round-trip a user-saved template through save + listAll + delete) |

## Platform Constraints

- **Android 9+ (API 28+).** API 28 is the floor; minSdkVersion 28.
- **Compile/target SDK 34.** Matches `board_box` / `card_box`.
- **Exact alarm permission on Android 12+** is a user-granted
  permission. The app must detect denial and fall back gracefully.
- **Notification permission on Android 13+** is a runtime permission.
  The app must request it with rationale.
- **Doze mode** suspends alarms. The app must prompt the user to
  disable battery optimization and the OEM's auto-start toggle, with
  a one-tap deep link to the system settings.
- **OEM battery savers** (Xiaomi, Oppo, Vivo, Honor, Samsung) kill
  background work even with whitelist. The app must show an OEM-aware
  guide card.
- **No `CALL_PHONE` permission.** Call reminders open the dialer via
  `Intent.ACTION_DIAL` with the number pre-filled in the URI.
- **No `READ_CALL_LOG` permission.** The app does not read call logs
  for cadence auto-priority; the user configures cadence manually or
  per-person.
- **No `INTERNET` permission** for user data. The app must function
  fully offline.

## MVP Success Criteria

A v0.1 build is acceptable if, after a 14-day real-device run on the
user's primary phone, all of the following are true:

1. do it fired a reminder for each of the 4 active presets within
   ±60 seconds of its target time, for ≥ 95% of scheduled occurrences.
2. The user completed at least 70% of the reminders with the
   configured proof mode.
3. The completion log matches the user's honest memory.
4. The app survived at least one device reboot without dropping
   reminders.
5. The app survived at least one timezone change without producing
   duplicate or dropped occurrences.
6. The backup file was written on at least 13 of the 14 nights.
7. The backup was successfully restored on a second device (or after
   uninstall / reinstall).
8. The 3-gate passed with zero failures on every commit during the
   14 days.

> **Note (v1.0/Phase A, see ADR-024):** The MVP criteria above were
> written before the rename. They still apply, but the entity under
> test is now a **Do** (not a "habit") and the consecutive-run counter
> replaces the term "streak".

If any criterion fails, fix it before adding features.
