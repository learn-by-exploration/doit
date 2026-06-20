# Decision Record

Status: active. Append-only. Each decision has a unique ADR ID.

The format is a slim ADR: context, decision, consequences. Cite the
SYS- IDs affected. If a decision is reversed, do not edit history —
add a new ADR that supersedes it and link both.

---

## ADR-001 — Flutter over native Android (Kotlin)

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** The user already ships `board_box` and `card_box` in
Flutter from the same monorepo. The choice was between adding a
third Flutter app to `common_games` or building do it in native
Kotlin. Native would have been slightly better for the Android
exact-alarm and Doze APIs, but it would have introduced a second
toolchain, second CI, and a second set of conventions.

**Decision.** Use Flutter 3.44, matching the rest of the monorepo.

**Consequences.**
- Reuse the 3-gate, lint rules, and CI scaffolding from `board_box`.
- Reuse the V-Model doc layout from `card_box/docs/v_model/`.
- The exact-alarm and Doze logic is in Kotlin (the platform channel
  side), but the rest of the app is Dart.
- iOS in v0.2 is realistic; native Kotlin would have made it
  impossible.

**SYS-IDs affected:** none directly; this is a meta-decision.

---

## ADR-002 — Android-only for v0.1

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** Android gives the most control over AlarmManager, exact
alarms, full-screen intents, OEM battery-saver behavior, and
contacts. iOS Core NFC, BGTaskScheduler, and CallKit behave
differently; supporting both from day one would double the platform
surface for v0.1.

**Decision.** Android only for v0.1. iOS is a v0.2+ candidate; the
data model and screens are platform-agnostic and the platform
integration is isolated to `lib/reminders/` and `android/app/`.

**Consequences.**
- The V-Model is Android-specific for verification steps that touch
  the platform.
- A future iOS port will need its own conops addendum and a
  notification-reliability doc rewrite.

**SYS-IDs affected:** SYS-016, SYS-017, SYS-030 (all Android-specific).

---

## ADR-003 — Local-first, no cloud, no account

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** The user wants personal use, single device. The
principle is "the user's data is the user's". A cloud sync layer
would be a security and privacy surface that delivers no value to a
single user on a single device.

**Decision.** No cloud, no account, no telemetry, no analytics. All
data in a local SQLite DB. The only "out" path is a user-driven
export to a folder they pick (Storage Access Framework).

**Consequences.**
- `AndroidManifest.xml` does not declare `INTERNET` for user data.
- Any package that requires network access for its core feature is
  rejected (or pinned to an offline mode).
- The CI grep rule in `analysis_options.yaml` flags `import
  'package:http'` outside the dev-only test harness.
- A future multi-device or family feature would require a
  fundamental rethink; tracked in
  [`open_questions.md`](open_questions.md).

**SYS-IDs affected:** SYS-026, SYS-030.

---

## ADR-004 — Notification → dialer pre-filled; no CALL_PHONE

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** "Call Mom" reminders are the headline feature. Two
options:
- Auto-place the call (`Intent.ACTION_CALL`, requires `CALL_PHONE`).
- Open the dialer pre-filled (`Intent.ACTION_DIAL` with `tel:` URI).

`CALL_PHONE` is a "dangerous" runtime permission on Android 9+;
Google Play's review process scrutinizes it; many users will deny
it; and the surprise of an auto-call is jarring.

**Decision.** Tap notification → `Intent.ACTION_DIAL` with
`tel:<number>` URI. No `CALL_PHONE` permission in the manifest.

**Consequences.**
- The user always confirms the call by tapping the dialer's call
  button. This is honest and matches the "you do the thing" spirit
  of the app.
- For IMs (WhatsApp, Telegram, Signal, SMS), use the channel's
  public intent (`Intent.ACTION_VIEW` with the appropriate URI
  scheme). The IM app handles the rest.
- A user who refuses to tap "call" in the dialer does not get the
  streak. This is by design.

**SYS-IDs affected:** SYS-014, SYS-030.

---

## ADR-005 — Three-mode proof hybrid (Soft / Strong / Auto)

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** A one-size-fits-all proof mode either lets users fake
"done" (tap-only) or burns them out (mission for everything).
Habit research (Wendy Wood, BJ Fogg) shows that friction should
match the difficulty of the habit, not be uniform.

**Decision.** Per-habit proof mode. Soft: one-tap. Strong: mission
chain. Auto: interval window. Mode is part of the habit's
identity and is recorded per-completion so changing it later does
not retroactively change the history.

**Consequences.**
- The model has a `HabitProofMode` enum (sealed class) and the log
  records the mode that was in effect.
- A new mode (e.g., "Strict Auto" with a 15-minute late penalty) is
  a v0.2 candidate.
- Strong mode is mandatory for the Call Person and Morning Routine
  presets by default; Soft is the default for Daily Todo and Auto
  for Drink Water.

**SYS-IDs affected:** SYS-007, SYS-013, SYS-019.

---

## ADR-006 — All five mission types in v0.1 (over "Lean" 2)

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** The original Lean v0.1 plan shipped only Shake-N and
Type phrase. The user wanted all five (Shake, Type, Hold-tap, Math,
Memory) because the variety keeps the app engaging and matches
Alarmy's breadth.

**Decision.** Ship all five mission types in v0.1. Lean scope is
preserved in the *number of habit presets* (4) and *number of
people* (no fixed minimum), not in the *number of mission types*.

**Consequences.**
- Larger initial implementation surface.
- The mission engine (`lib/missions/chain.dart`) must support
  arbitrary chain order from day one.
- The `Mission` sealed class hierarchy is the source of truth for
  mission types; new types are added in v0.2 (Barcode, Photo) by
  adding a new subclass, not by editing the enum.

**SYS-IDs affected:** SYS-008, SYS-009, SYS-010, SYS-011, SYS-012,
SYS-013.

---

## ADR-007 — Auto local backup to a user-chosen folder

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** Personal use, single device. If the user uninstalls
the app or loses the phone, the data is gone. Options:
- No backup (uninstall = data loss).
- Manual export (user has to remember).
- Auto to a fixed path (e.g., Documents/do it/) — fragile across
  Android versions and OEM file managers.
- Auto to a user-chosen folder via Storage Access Framework.

**Decision.** Auto backup nightly to a SAF folder the user picks on
first run. Plain JSON, versioned, 30-day retention. No encryption
in v0.1; encrypted backup is a v0.2 candidate.

**Consequences.**
- The `file_picker` package is required to obtain the SAF URI.
- The SAF URI is stored in `shared_preferences`; if the OS
  revokes it (app uninstall, manual revoke), the app surfaces a
  banner and asks the user to pick a new folder.
- Backup is the source of truth for restore. Restore is idempotent.
- A 14-day real-device run must verify the backup runs on ≥ 13 of
  14 nights.

**SYS-IDs affected:** SYS-023, SYS-024.

---

## ADR-008 — Mixed streak model (per-habit + overall + rest days + opt-out)

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** Streaks can be motivating or punishing depending on
the user. Some users want the "day count" pressure; some want
honest stats without the guilt.

**Decision.** do it model is configurable per habit. Defaults:
- Per-habit streak: consecutive successful days.
- Overall streak: % of active habits hit, default threshold 80%.
- Rest-day budget: 2 / month per habit (configurable; can be 0).
- Grace window: until 03:00 next day.
- A habit can opt out of streaks entirely and show raw completion
  rate.

**Consequences.**
- The streak calculator takes a config, not hard-coded constants.
- The completion log is the source of truth; the streak number is
  derived.
- The unit test for `StreakCalculator` must cover: DST, rest day,
  missed-then-backfilled, partial-day edge cases, mode change
  mid-streak.

**SYS-IDs affected:** SYS-019, SYS-020.

---

## ADR-009 — Manual or first-unlock wake-up anchor (user picks)

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** Morning routines need a wake-up event. Detection
options:
- Manual only (an "I'm up" button). Most honest, but easy to
  forget.
- First-unlock only (via `Intent.ACTION_USER_PRESENT` or
  `KeyguardManager`). Automatic, but false positives (midnight
  bathroom, alarm dismiss).
- Both, with confirmation.

**Decision.** User picks in settings. Default: "either with
confirmation" (heads-up on first unlock, dismissible). 4-hour
debounce prevents double-fires.

**Consequences.**
- The `AnchorDetector` model is parameterized.
- A false-positive dismiss is non-destructive (no anchor recorded).
- The widget test for the anchor setting covers all three modes.

**SYS-IDs affected:** SYS-015, SYS-016, SYS-017.

---

## ADR-010 — AlarmManager exact + WorkManager fallback + Doze prompt

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** Reliable reminders on Android are notoriously
difficult. Doze, App Standby, OEM battery savers, and
SCHEDULE_EXACT_ALARM gating on Android 12+ all conspire to delay
or drop alarms.

**Decision.** Layered reliability:
1. Primary: `AlarmManager.setExactAndAllowWhileIdle` (exact alarm).
2. Fallback: `WorkManager` periodic + one-shot with 15-min grace.
3. User prompt: detect denial of `SCHEDULE_EXACT_ALARM` and battery
   optimization, with a one-tap deep link to system settings.
4. Boot receiver: re-schedule all pending reminders on
   `BOOT_COMPLETED`.
5. OEM guide card: detect aggressive OEMs and show a card with
   enable-auto-start steps.
6. Optional: a foreground-service heartbeat (out of scope for
   v0.1; v0.2 if needed).

**Consequences.**
- The exact-alarm path requires a `permission_handler` /
  `android_alarm_manager_plus` integration that the rest of the
  app does not depend on.
- The WorkManager fallback is verified to fire within ±15 min in
  degraded conditions.
- The app does not run a foreground service in v0.1; this keeps
  the notification bar clean. If the 14-day run shows >5% drop
  rate, revisit.

**SYS-IDs affected:** SYS-003, SYS-016, SYS-017.

---

## ADR-011 — Drift over sqflite for local DB

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** Two reasonable SQLite options: `sqflite` (simpler,
lower-level) and `drift` (typed, reactive, larger dependency).

**Decision.** Use Drift. The completion log and streak queries
benefit from typed reactive streams (the home screen auto-updates
when a habit is completed) and from the migration tooling.

**Consequences.**
- Drift's `MigrationStrategy` is the home of schema versioning.
- The completion-log table will be a Drift `Table` with typed
  columns.
- Drift's reactive query streams integrate with `ChangeNotifier` /
  `ValueNotifier` for the home screen.

**SYS-IDs affected:** SYS-022.

---

## ADR-012 — Habit / Person / Mission identity is immutable per record

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** Some properties of a habit (name, schedule) are
editable. Some (proof mode, mission chain) should not silently
flip, because the completion log records which mode was in effect
at the time. Same for a person's channel and a mission's
parameters.

**Decision.** The following are immutable per record after
creation:
- A habit's `proof_mode` (Soft/Strong/Auto).
- A habit's `mission_chain` (if Strong).
- A person's `channel` (dialer, WhatsApp, etc.).
- A mission's `parameters` (e.g., Shake-N's `n`).

To change an immutable field, the user archives the old record
and creates a new one. The completion log is split at the
archive boundary.

**Consequences.**
- The model layer throws `ImmutableFieldChanged` if the field is
  mutated directly.
- The UI hides the field (grayed out) once the record has
  completions.
- The unit test for `Habit`/`Person`/`Mission` covers this rule.

**SYS-IDs affected:** SYS-007, SYS-013.

---

## ADR-014 — Onboarding permission order: notifications, contacts, exact-alarm, battery, OEM, backup, anchor

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** Onboarding has to ask for several platform
permissions and OEM-specific settings. The order matters for two
reasons: (a) each step is contingent on the previous one being
understood by the user, and (b) the user is more likely to grant
the most important permissions when each request is paired with
a clear, in-context rationale rather than a wall of requests at
once.

**Decision.** do it asks in this order, in this order, and
with this rationale:

1. **`POST_NOTIFICATIONS` (Android 13+).** Without this,
   reminders are silent. The app's headline value (a reminder
   that fires) is broken.
2. **`READ_CONTACTS`.** Used only to resolve names the user
   has chosen to add to a cadence. Required for the "Call
   &lt;person&gt;" preset; without it, that preset is hidden.
3. **`SCHEDULE_EXACT_ALARM` (Android 12+).** Without this,
   fixed-time reminders can be 15+ minutes late. Required for
   the Morning Routine preset.
4. **Disable battery optimization.** Required for the alarm
   to fire reliably in Doze. OEM-specific deep link.
5. **OEM auto-start.** Best-effort detection; shows a card
   with a screenshot-style guide for the user's OEM. Without
   this, Xiaomi / Oppo / Vivo / Honor / Samsung may kill
   background work even with the Doze whitelist.
6. **Backup folder (SAF).** Optional. The user may skip and
   enable later from Settings.
7. **Wake-up anchor preference.** Last, because the user has
   just understood the app's value and is ready to make
   configuration choices.

**Consequences.**
- The onboarding workflow WF-001 follows this order; any
  change is a breaking change for the onboarding flow and
  requires updating WF-001 in the same PR.
- The settings page mirrors this order when re-asking for
  permissions.
- A permission that is denied at any step continues the
  onboarding (graceful degradation) — the user is shown what
  is broken and how to fix it later.

**SYS-IDs affected:** SYS-025, SYS-026, SYS-027, SYS-030.

**Workflows affected:** WF-001, WF-012, WF-013.

---

## ADR-015 — Three-strikes policy for retry and nudge

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** Several places in the app involve a finite
number of user attempts or system retries: math mission wrong
answers, snooze taps per occurrence, backup write retries.
The 3-strike count is a UX default that has been chosen
independently in each place (Math: 3-wrong nudge; Snooze:
3-max; Backup: 3 retries with backoff). Without a unifying
decision, the next "finite attempts" feature will be picked
arbitrarily.

**Decision.** do it uses a **3-strikes policy** as the UX
default for any finite-attempt behavior. Beyond 3 attempts,
the app either:

- **Surfaces a nudge** (Math: "take a break" + auto-fail) and
  treats the mission as failed; or
- **Caps the action** (Snooze: "you've snoozed 3 times —
  skip or do it") and offers a manual fallback (Skip with a
  rest day, or accept a streak break); or
- **Retries silently with backoff** (Backup: 1 s, 5 s, 30 s)
  and surfaces a banner only when all retries fail.

The 3-strike count is a UX default, not a hard rule. Specific
policies are pinned in the matching SYS- IDs:

- **SYS-011** (Math): 3 consecutive wrong answers = nudge +
  auto-fail.
- **SYS-018** (Snooze): 3 snoozes per occurrence = cap +
  manual fallback.
- **SYS-023** (Backup): 3 retries with exponential backoff
  (1 s, 5 s, 30 s) = silent retry, banner on full failure.

**Consequences.**
- Any new "finite attempts" feature defaults to 3 unless an
  ADR overrides it. Examples in v0.2+ that may override: the
  5-minute chain timeout cap (SYS-031) which is not a
  3-strike pattern.
- The 3-strike count is configurable per-feature in code, not
  in user settings.
- The unit test for each feature covers the boundary at 3.

**SYS-IDs affected:** SYS-011, SYS-018, SYS-023, SYS-031.

**Workflows affected:** WF-006, WF-009, WF-012.

---

## ADR-013 — v0.4b WorkManager dispatcher must be a public top-level function; cold-start `init()` must not crash the app

**Status:** Accepted 2026-06-15 (post-mortem on the v0.4b
release-mode launch crash).

**Context.** v0.4b (SYS-060) added the WorkManager-backed
nightly backup scheduler. The release APK built at SHA
`8f0ec5c` (and the prior `9290652` build) crashed on first
launch on a real device — the system reported
"App keeps stopping" and the process exited before
`runApp`. The crash repro'd on every cold start and was
independent of the user's onboarding state. The v0.4b unit
tests (`backup_scheduler_test.dart` + `backup_task_dispatcher_test.dart`)
were all green at the v0.4d sign-off, and `flutter test`
reported 373/373. The crash therefore had a release-mode
fingerprint that the test harness did not exercise.

**Root cause.** Two interlocking issues, both in
`lib/services/backup_scheduler.dart`:

1. **The dispatcher was a private top-level function**
   (`_backupTaskDispatcher`, leading underscore).
   `PluginUtilities.getCallbackHandle(callbackDispatcher)`
   resolves the function by name from a background isolate.
   In a release AOT build, private top-level functions are
   not always reachable by name (the AOT compiler can prune
   them or strip the symbol table entry), and
   `Workmanager().initialize(...)` then throws an
   `ArgumentError` ("the callbackDispatcher needs to be
   either a static function or a top level function"). The
   exception propagated out of `main()` and the OS killed
   the process before `runApp`.

2. **`init()` rethrew the platform exception.** Even
   without the dispatcher-name issue, `init()` was
   `try { ... } catch (e, st) { _ready.completeError(...);
   rethrow; }`. The rethrow was the right call for unit
   tests (which need a clear failure signal), but wrong for
   the production cold-start path: `main()` calls
   `await BackupScheduler.instance.init()` *before* `runApp`.
   Any platform exception (a missing keystore, a restricted
   OEM, a transient WorkManager error) becomes a fatal app
   crash.

**Why the unit tests did not catch it.** The unit tests
mock the workmanager method channel. The mock returns
`null` for every call. The mock never goes through
`PluginUtilities.getCallbackHandle`, so the AOT
name-resolution path is never exercised. The release AOT
compiler is also not running — tests use the JIT. The
crash was a release-AOT-only defect.

**Decision.**

1. **The dispatcher is renamed to a public top-level
   function** (`backupTaskDispatcher`, no underscore). The
   `@pragma('vm:entry-point')` annotation stays. The symbol
   is referenced in the unit test as a `const Function ref =
   backupTaskDispatcher;` so a future rename back to
   private would break the test at compile time.

2. **`init()` no longer rethrows.** A platform exception is
   logged (debug-only, via the `assert(() { print(...);
   return true; }())` pattern that compiles to a no-op in
   release) and the gate is left uncompleted. A later retry
   can re-call `init()` if the platform side recovers. A
   follow-up `scheduleNightlyBackup()` throws a clear
   `StateError` so the UI can surface the failure to the
   user, instead of silently missing the schedule.

3. **`main()` wraps the `init()` call in a defensive
   `try/catch`.** Defense in depth — even if a future
   change in `init()` reintroduces a rethrow, the app still
   launches. The `try/catch` body is debug-only
   `debugPrint`; release builds stay silent in logcat.

4. **A new unit test pins both invariants:**
   `test/services/backup_scheduler_test.dart` has two
   new tests (a) `init() swallows platform exceptions` —
   throws a `PlatformException` from the mock's
   `initialize` handler and asserts `init()` does not
   rethrow, the call was made, and the gate is left
   uncompleted (so a follow-up `scheduleNightlyBackup()`
   throws `StateError`); and (b)
   `backupTaskDispatcher is a public top-level function` —
   pins the symbol at compile time via a `const Function
   ref = backupTaskDispatcher;`. The dispatcher-name test
   would have caught the original bug if the test had
   referenced the symbol at the type-system level.

**Consequences.**

- Any future background isolate entry point (a v0.5+
  feature, e.g. a v0.2f VIP escalation that adds a second
  `Workmanager().initialize` for a different cadence)
  **must** be a public top-level function. The pattern is
  documented in `lib/services/backup_scheduler.dart`'s
  file-level comment and in the dispatcher's doc comment.
- A service's `init()` must never block `runApp` for an
  external reason. The contract is:
  `init()` may complete, may complete-with-error-and-leave-
  the-gate-uncompleted, or may swallow-and-log. It must
  never rethrow. The fresh-install integration test
  (`test/integration/fresh_install_test.dart`) is the
  right place to assert this at the call-site level.
- The "no widget test for the release-mode cold-start path"
  gap is closed: a new test
  (`backup_scheduler_test.dart` "init() swallows platform
  exceptions") exercises the platform-throw path under
  a mock that simulates the missing-plugin or
  restricted-WorkManager case. The AOT name-resolution
  path is still not exercised by tests (it cannot be —
  the AOT compiler runs at build time, not test time),
  but the symbol is pinned at the Dart type level so a
  future rename back to private would fail compilation
  rather than fail at runtime.

**SYS-IDs affected:** SYS-060 (WorkManager periodic
backup — the dispatcher is part of the SYS-060 surface).

**Workflows affected:** WF-012 (Auto backup — the
scheduler that runs the periodic export).

**Post-mortem note.** The "no real-device step on the
v0.4b path" is itself a process defect. v0.4d's
right-side gate (`v0_4_release_checklist.md`) lists the
user's hands-on TalkBack pass as the v0.4d step, but a
TalkBack pass on a v0.4b build would have surfaced the
crash immediately. The lesson — the v0.4d sign-off must
include a hands-on cold-start check (not just an a11y
check) — is folded into the v0.4d checklist via the
release-fix commit.

---

## ADR-013 (follow-up) — The v0.4b-release-fix was incomplete; the real crash is R8 stripping workmanager's `WorkDatabase_Impl` at process start

**Date:** 2026-06-16.
**Status:** Accepted.
**Supersedes:** The "root cause" section of ADR-013. The
original two issues (private dispatcher, rethrowing
`init()`) were real but **not** what was crashing the
release APK on a real device.

**Context.** The user installed the v0.4b-release-fix APK
(SHA `384cfb2`, built at 2026-06-15 22:30) on a Samsung
Galaxy S23 (SM-S918B, Android 14) and reported the app
still crashed on cold start. The fix at `384cfb2` had
been unit-tested and the 3-gate was green (375/375), so
the cold-start crash was not what ADR-013 said it was.

**What we got wrong.** ADR-013's root-cause analysis
mapped the symptom ("crash on first launch") to the
Dart-side `Workmanager().initialize(...)` path. That
path **can** throw in release AOT (the dispatcher-name
and rethrow issues are real), but the v0.4b-release-fix
APK was crashing **before** any Dart code ran. Pulling
`adb logcat -b crash` after a fresh install showed:

```
FATAL EXCEPTION: main
Process: com.common_games.streak, PID: 31989
java.lang.RuntimeException: Unable to get provider
  androidx.startup.InitializationProvider
  at android.app.ActivityThread.installProvider(...)
  at androidx.startup.InitializationProvider.onCreate(...)
Caused by: java.lang.RuntimeException: Failed to create
  an instance of class
  androidx.work.impl.WorkDatabase.canonicalName
  at androidx.work.WorkManagerInitializer.create(...)
```

The `r8-map-id-...` prefix and the obfuscated class
names (`j0.c`, `j0.a.b`, `f1.b.c`) confirm R8 had
already run. The crash path is:

1. Process start. `ActivityThread.installContentProviders`
   instantiates the `androidx.startup.InitializationProvider`
   declared in the merged manifest. The provider is
   transitive-declared by the workmanager plugin via
   the `androidx.startup` library.
2. The provider's `onCreate` iterates every registered
   `androidx.startup.Initializer`, including the
   `androidx.work.WorkManagerInitializer` (a Kotlin
   Initializer auto-registered by the workmanager AAR).
3. `WorkManagerInitializer.create` calls
   `WorkManager.getInstance(context)`. That call lazily
   builds the workmanager singleton, which constructs
   the `androidx.work.impl.WorkDatabase` — a
   Room-generated SQLite database. Room's
   `RoomDatabase$Builder.build()` resolves the
   `_Impl` class via `Class.forName("...WorkDatabase_Impl")`.
4. On a release build where R8 has stripped or renamed
   the `_Impl` class, the `Class.forName` lookup throws
   and the provider fails to attach. The process is
   killed before `MainActivity.onCreate` is ever called,
   so no Dart code runs and no `try/catch` in `main()`
   can help. The user's "still the same" report was
   literally true — same stack trace, every time, at
   process start.

**Why the v0.4b-release-fix did not fix it.** The fix
at `384cfb2` only addressed the Dart-side dispatcher
name and `init()` rethrow. Both of those defects were
real (and are still fixed — see ADR-013 above), but
neither was the cause of the release-mode cold-start
crash. The v0.4b-release-fix was symptom-misdiagnosed
because:

- The user reported "app is closing" — a generic
  symptom that could mean "Dart throws before runApp"
  or "the process never reaches Dart at all". The two
  have the same user-facing shape.
- The unit tests stayed green. The release AOT
  runtime path is not testable in `flutter test` (which
  is JIT), and the OS-side `InitializationProvider`
  path is not testable in `flutter test` at all.
- There was no hands-on install of the v0.4b tip on a
  real device. The "Process defect" at the end of the
  original ADR-013 (no real-device step in v0.4b's
  right-side gate) is what let the misdiagnosis
  survive past `384cfb2`.

**The real fix (this commit).** Two complementary
changes:

1. **Disable workmanager's auto-init at the OS level.**
   `android/app/src/main/AndroidManifest.xml` adds a
   `tools:node="remove"` entry inside the
   `InitializationProvider` block to drop the
   `androidx.work.WorkManagerInitializer` meta-data
   from the merged manifest. The provider itself
   stays (other libraries may register Initializers)
   but the workmanager one is removed. The Dart
   `BackupScheduler.init` already does
   `await Workmanager().initialize(backupTaskDispatcher)`
   which is sufficient: the native `InitializeHandler`
   saves the callback handle to SharedPreferences, and
   the WorkManager singleton is built lazily the first
   time `Workmanager().registerPeriodicTask(...)` is
   called from the settings screen. There is no
   pre-existing call that needs the singleton alive
   at process start, and removing the auto-init takes
   the cold-start crash off the boot path.

2. **Pin R8 / minify / resource-shrink off explicitly.**
   `android/app/build.gradle.kts` `buildTypes.release`
   now sets `isMinifyEnabled = false` and
   `isShrinkResources = false` explicitly. The v0.3
   decision ("R8 / minify is OFF") was correct, but
   the build config was relying on the AGP default.
   The default has historically been `false` for
   release, but AGP 9.1.0 (the version this project
   uses) is the first AGP that may run R8 in
   additional cases beyond what `isMinifyEnabled`
   controls. Pinning both flags to `false` is
   defense in depth — a future AGP upgrade that flips
   a default cannot silently re-enable R8 and re-break
   the workmanager `WorkDatabase_Impl` lookup.

**Why both?** The manifest fix (1) is the surgical
fix for the observed crash. The R8 fix (2) is defense
in depth: even with the auto-init removed, future
plugins or future code paths that do trigger R8-class
reflection at process start would re-introduce the
same crash shape. Pinning R8 off makes the v0.3
"minify-off" decision a compile-time invariant
instead of a "default" assumption.

**Consequences.**

- The `androidx.work.WorkManagerInitializer` will not
  be removed from the merged manifest if a future
  PR reverts the manifest change. The new
  `test/release_signing_test.dart` test
  "AndroidManifest disables workmanager
  WorkManagerInitializer auto-init" pins the
  presence of the `xmlns:tools` namespace, the
  `androidx.work.WorkManagerInitializer` reference,
  and the `tools:node="remove"` marker. A future
  revert fails the test.
- The new `test/release_signing_test.dart` test
  "isMinifyEnabled = false is pinned in
  buildTypes.release" pins both
  `isMinifyEnabled = false` and
  `isShrinkResources = false`. A future PR that
  flips either to `true` (or removes the line) fails
  the test.
- 3-gate: 377/377 (was 375 at `384cfb2`; +2 new
  pin-tests). 41 `flutter analyze` infos (matches
  v0.3 baseline). `dart format` clean. The release
  APK rebuilds and the cold-start crash is fixed
  (verified on the user's SM-S918B device).
- The Dart-side dispatcher-name + `init()`-swallow
  fixes from `384cfb2` stay in place. They are real
  defects that would have surfaced on the first
  `Workmanager().initialize` call from a future
  Dart code path; keeping the fixes is correct.
- v0.4d sign-off: the user's hands-on install on a
  real device is now a mandatory step in the right-
  side gate, not a "nice to have". The
  `v0_4_release_checklist.md` 3-gate log row for
  this commit says so explicitly.

**SYS-IDs affected:** SYS-060 (WorkManager periodic
backup — the dispatcher's `WorkDatabase` is part of
the SYS-060 surface).

**Workflows affected:** WF-012 (Auto backup).

**Lessons (project-wide).**

- A Dart-side fix cannot address a crash that happens
  before any Dart code runs. The crash-log pull (via
  `adb logcat -b crash`) is the first thing to do when
  a release APK fails to launch — the OS-side stack
  trace distinguishes "Dart threw" from "process
  never started" in one line.
- "R8 / minify is OFF" must be a compile-time
  invariant, not a default. Pin it.
- Every release-build right-side gate must include
  a real-device cold-start step. The v0.4b
  right-side gate did not, and the misdiagnosis in
  the original ADR-013 was the direct consequence.

---

## ADR-014 — Onboarding permission order: notifications → contacts → exact alarm → backup folder

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** The v0.1 onboarding rationale screens were
written but the runtime permission requests were not
implemented (the visual walkthrough was a stub). When v0.5
wired the runtime path, the order in which the four
permissions are requested had to be pinned because:

- A permission that is requested before a prior one is
  granted can deadlock the user (e.g., requesting
  `READ_CONTACTS` before `POST_NOTIFICATIONS` means a
  notifications-off user can still see a contact-rationale
  step, which is irrational — contacts are optional;
  notifications are the primary delivery channel).
- Android shows the runtime prompt **inline** the moment
  `request()` is called. Re-ordering later means the
  user sees prompts in the wrong order, which they read
  as "the app is confused".
- `SCHEDULE_EXACT_ALARM` on Android 12+ is a **policy**
  permission: the system does not show a runtime dialog
  for it. The path is `request()` returns `denied` on the
  first call, and the user has to go through the system
  Alarms & reminders settings to grant it. This must be
  the third step (after the two runtime prompts the
  user is most likely to grant) so the user is not
  startled by "go to settings" before they have granted
  anything.
- The backup-folder SAF picker is the *last* runtime
  affordance because it is the only one that is
  **skippable** (per the ADR-014 step 6 decision: a
  user who declines the backup folder is a valid
  user, not a broken install).

**Decision.** The four onboarding steps run in this
order:

1. **Step 0 — `POST_NOTIFICATIONS`** (Android 13+).
   SYS-063. Runtime prompt. The system shows the
   "Allow notifications?" dialog inline. The CTA
   `Allow` calls `PermissionService.requestNotifications()`
   and advances on `granted`.
2. **Step 1 — `READ_CONTACTS`** (cadence-style
   habits). SYS-064. Runtime prompt. The system shows
   the "Allow do it to access your contacts?" dialog
   inline. The CTA `Allow` calls
   `PermissionService.requestContacts()` and advances
   on `granted`. Denial is graceful: cadence habits
   remain creatable in the form (the contact picker
   still works in the ad-hoc mode).
3. **Step 2 — `SCHEDULE_EXACT_ALARM`** (best-effort;
   gracefully degrades). SYS-065. Policy permission
   on Android 12+. The runtime `request()` call
   returns `denied` on the first invocation; the
   step surfaces a `FilledButton.tonal` labeled "Open
   Android settings" that calls
   `PermissionService.openAppSettings()`. The user
   re-taps the CTA after returning from system
   settings; the service re-probes and advances on
   `granted`.
4. **Step 3 — backup folder (SAF)**. SYS-066. The
   `file_picker` `getDirectoryPath()` call shows the
   platform folder picker. On a non-null `treeUri`
   the service persists the path to
   `SettingsService.instance.backupFolderUri`. On
   cancellation the step advances **without**
   persisting (skippable, see below). On a picker
   error the rationale text shows the error and the
   step stays.

A `Skip` `TextButton` is present on every step; it
calls `widget.onDone` immediately. Skipping is a
valid user choice; the next launch re-presents
onboarding only if `SettingsService.firstLaunchCompleted`
is still `false` (per SYS-059, v0.4a.3).

**Consequences.**

- The `permission_handler` `Permission` enum is the
  source of truth for the request ordering; the
  onboarding step list and the `PermissionService`
  method list are kept in sync by code review
  (the v0.5a rename test pins the four
  `requestX()` methods exist as a side effect of
  pinning the order).
- A new step (e.g., v0.2f's `READ_PHONE_STATE` for
  VIP escalation) is added by appending to the
  `_steps` list in `lib/screens/onboarding.dart` and
  adding a new `requestX()` method on
  `PermissionService`. The dispatch in
  `_handleStepCta` is a switch on the integer
  `_step`, not a Map lookup, so the new case is
  explicit.
- The v0.5d Settings → Permissions tile (SYS-063..066)
  is the recovery affordance for users who hit
  "Don't ask again" on any of the four steps. The
  tile reads from `PermissionService.instance.statuses`
  (a `ValueNotifier<Map<PermissionKind, PermissionResult?>>`
  populated by `PermissionService.init()` and refreshed
  by every `requestX()` call) and shows the current
  status of each.
- The `firstLaunchCompleted` flag (SYS-059) stays the
  gate for re-presenting onboarding. A user who
  denies all four permissions and taps `Skip` is
  treated as a completed onboarding; the Settings
  → Permissions tile is the in-app recovery path.
- The on-device v0.5e verification is the right-side
  gate for the *order* — the SM-S918B's Alarms &
  reminders settings page must be reachable from
  the step-2 "Open Android settings" button without
  crossing any other system prompt.

**SYS-IDs affected:** SYS-063, SYS-064, SYS-065, SYS-066.

**Workflows affected:** WF-001 (First-run onboarding).

---

## ADR-015 — Backup folder is skippable on onboarding (step 3 / SYS-066)

**Date:** 2026-06-13.
**Status:** Accepted.

**Context.** The four runtime permissions in the v0.5
onboarding flow are not equal: `POST_NOTIFICATIONS`,
`READ_CONTACTS`, and `SCHEDULE_EXACT_ALARM` are
**app-required** (the app cannot deliver reminders
without the first, cannot create a cadence habit
without the second, and degrades silently without the
third to a best-effort schedule). The backup folder
(SAF) is a **user convenience** — it enables the
nightly auto-backup feature, but the app functions
without it (a user who does not pick a folder simply
does not get auto-backup; the in-app restore is still
available from a manually-exported backup file).

Asking the user for the backup folder the same way we
ask for notifications — "Allow" / "Don't allow" with
no skip — is a UX failure: a user who is in a hurry,
who has not yet decided where to put the backups, or
who does not understand SAF is forced to either pick
a folder they will later change or to decline and be
locked out of the rest of the onboarding flow.

**Decision.** The backup-folder onboarding step
treats both the `picked` and the `cancelled` SAF
result as advancing. The user is moved on to the
anchor-mode / theme-mode / finish step in either
case:

- `BackupFolderPicked(:final path)` →
  `SettingsService.instance.setBackupFolderUri(path)`
  is called, then `_step++`.
- `BackupFolderCancelled()` → no
  `setBackupFolderUri` call (the previous `null`
  value of `SettingsService.backupFolderUri` stays);
  `_step++` runs.
- `BackupFolderError(:final message)` → the
  rationale text shows "Folder picker error: $message"
  and the step does **not** advance. The user can
  re-tap `Pick folder` or `Skip`.

The v0.5d Settings → Permissions tile (and its
`_BackupFolderTile`) is the post-onboarding recovery
affordance: a user who skipped step 3 can pick a
folder later from the tile, and a user who picked a
folder and then revoked the SAF grant from system
settings can re-pick from the tile's "Re-pick"
`TextButton`. The tile reads
`SettingsService.instance.backupFolderUri` (a
`ValueNotifier<String?>`) and surfaces the picked
path or "Not picked — tap to pick".

**Consequences.**

- The v0.5c onboarding test
  `'tapping Pick folder on step 3 advances on cancelled (per ADR-014 step 6: skippable)'`
  pins this contract: a scripted SAF cancellation
  must advance the step and must **not** set
  `SettingsService.instance.backupFolderUri`.
- A user who skips the backup folder at onboarding
  gets no auto-backup. This is documented in the
  "Honest caveats" section of `PRIVACY.md` (added
  in v0.5e) and surfaced in the Settings → Backup
  section as a "Pick a backup folder" call-to-action
  (existing v0.4c copy).
- The Settings → `_BackupFolderTile.onTap` is a
  no-op when a folder is already picked (it shows
  the "Re-pick" `TextButton` instead). This avoids
  a confusing "I tapped the row and nothing happened"
  UX for users who have already picked a folder.
- The workmanager nightly backup task is registered
  in `BackupScheduler.init` (v0.4b, SYS-060) only
  if `SettingsService.backupFolderUri` is non-null.
  A user who skipped onboarding step 3 has
  `backupFolderUri == null` and so the periodic
  task is **not** registered. (This is the same
  behavior as a user who never opens the app: no
  background work, no data egress.)

**SYS-IDs affected:** SYS-066.

**Workflows affected:** WF-001, WF-012.

---

## ADR-016 — Permission service seam: sealed result, singleton, on-demand probe

**Date:** 2026-06-16.
**Status:** Accepted.

**Context.** The v0.1 onboarding was shipped as a
"visual walkthrough" — the rationale UI existed, the
runtime request did not. The rationale text in
`lib/screens/onboarding.dart`'s file-level comment
explicitly said "requestX methods are no-op stubs" and
the four `Allow` / `Pick folder` CTAs all did
`setState(() => _step++)`. The runtime call landed in
v0.5 with `permission_handler ^11.3.1` and a
`file_picker` SAF call. The widget layer cannot call
the platform directly per `.claude/rules/lib-screens.md`
("No platform calls in widgets"). The widget layer
cannot call `permission_handler.requestPermission` and
surface a sealed result without a service seam. The
new `PermissionService` is that seam.

**Decision.**

1. A new `lib/services/permission_service.dart` singleton
   with the `_ready`-gated init pattern from
   `.claude/rules/lib-services.md` (mirrors
   `BackupService`, `SettingsService`, `HabitRepository`).
2. A sealed `PermissionResult` in
   `lib/services/permission_result.dart`:
   `PermissionResult.granted()`,
   `PermissionResult.denied({required bool canOpenSettings})`,
   `PermissionResult.permanentlyDenied()`. The widget
   layer never sees `PermissionStatus` (the
   `permission_handler` enum) directly — the
   `_mapStatus` private method folds `restricted` and
   `limited` into `denied` for widget purposes.
3. The onboarding CTAs in
   `_OnboardingScreenState._handleStepCta` dispatch
   on `_step` to the right `requestX()` method
   (`requestNotifications` / `requestContacts` /
   `requestExactAlarm` / `requestBackupFolder`) and
   advance on `granted` / `picked` / `cancelled`
   (per ADR-015). On `denied` the inline rationale
   text and, when `canOpenSettings: true`, the
   "Open Android settings" `FilledButton.tonal` are
   revealed. On `permanentlyDenied` the same
   settings button is shown unconditionally.
4. A new Settings → Permissions tile
   (`_PermissionsRow` + `_PermissionTile` +
   `_BackupFolderTile` in `lib/screens/settings.dart`,
   between `Wake-up anchor` and `Reliability`) is the
   recovery affordance for users who hit "Don't ask
   again" on any of the four steps. The tile reads
   from `PermissionService.instance.statuses` (a
   `ValueNotifier<Map<PermissionKind, PermissionResult?>>`
   populated by `init()` and refreshed by every
   `requestX()` call) and shows one `ListTile` per
   permission with the current status text. A
   "Settings" `TextButton` is rendered only on
   `permanentlyDenied` rows; tapping it deep-links
   to the system app-settings page via
   `PermissionService.openAppSettings()`.
5. The order is the ADR-014 order:
   `POST_NOTIFICATIONS` → `READ_CONTACTS` →
   `SCHEDULE_EXACT_ALARM` → backup folder. Adding
   a new step is appending to the `_steps` list and
   adding a new `requestX()` method.

**Consequences.**

- The `StreakCalculator` / `StreakService` /
  `StreakSnapshot` identifiers are not affected —
  they are feature-level names that describe the
  *consecutive-day tracking* feature, not the app's
  brand.
- The 9 new `PermissionService` tests in
  `test/services/permission_service_test.dart` pin
  the sealed result branches (granted / denied /
  permanentlyDenied for each of the three runtime
  permissions; picked / cancelled / error for
  backupFolder; idempotent init; platform-error
  swallow). The 6 new `OnboardingScreen`
  permission-wiring tests in
  `test/screens/onboarding_permission_wiring_test.dart`
  pin the call-and-advance behavior. The 4 new
  `Settings → Permissions` tests in
  `test/screens/settings_permissions_test.dart` pin
  the recovery tile.
- The `package:permission_handler` import is now in
  the `lib/services/` tree, not the widget tree.
  The widget layer imports
  `package:doit/services/permission_service.dart`
  and `package:doit/services/permission_result.dart`
  and pattern-matches on the sealed class.
- The `open_questions.md` items #5 (READ_CONTACTS
  revocation) and #6 (SAF URI revocation) are
  closed by the v0.5d wiring: both surfaces have
  an in-app recovery affordance now
  (Settings → Permissions tile, deep-link to
  system app-settings on `permanentlyDenied`).
- `docs/v_model/notification_reliability.md` is
  updated: the line "On first scheduling of a
  fixed-time habit, the app detects whether the
  user has granted `SCHEDULE_EXACT_ALARM`" is
  replaced with: "The app probes
  `SCHEDULE_EXACT_ALARM` at onboarding step 2
  (SYS-065) and surfaces the result on the home
  screen reliability banner. If the user denies,
  the `Reliability.degraded` path activates and
  the Settings → Permissions tile is the recovery
  affordance." The "may be late" copy at lines
  60, 69, 199-200 is updated to point at the
  on-demand probe, not the first-schedule
  trigger.
- The "v0.1 onboarding is a visual walkthrough"
  caveat in `lib/screens/onboarding.dart`'s
  file-level comment is updated: the new comment
  block is "Onboarding screen — permission-first
  UX for first launch. v0.5 wires the four
  runtime permission requests to
  `PermissionService`. The order follows
  ADR-014 / ADR-016: `POST_NOTIFICATIONS`,
  `READ_CONTACTS`, `SCHEDULE_EXACT_ALARM`,
  backup folder (SAF). Each step's CTA calls the
  corresponding `requestX()` method and advances
  on `granted`. The `Skip` button remains as a
  user choice."
- `PRIVACY.md` "Honest caveats" section (added in
  v0.5e) is updated to reflect the new reality:
  the four runtime permissions are requested in
  the ADR-014 order with a rationale screen for
  each, and denial is graceful (the Settings →
  Permissions tile is the recovery affordance for
  one-shot and permanent denials; `SCHEDULE_EXACT_ALARM`
  is a system policy permission on Android 12+ and
  is granted via the Android system settings with
  a deep-link from the tile).

**SYS-IDs affected:** SYS-025 (closure — the rationale
UI is now backed by a real runtime call),
SYS-063, SYS-064, SYS-065, SYS-066.

**Workflows affected:** WF-001 (First-run onboarding),
WF-012 (Auto backup — `_BackupFolderTile`).

**Lessons (project-wide).**

- A rationale UI without a runtime call is a
  half-shipped feature. The v0.1 onboarding was
  reviewed and merged because the rationale text
  was there and the buttons were there; the
  absence of a `request()` call on the CTA's
  `onPressed` was missed because the tests
  asserted the UI, not the behavior. v0.5c's test
  pattern (`'tapping Allow on step 0 calls
  requestNotifications and advances on granted'`)
  asserts the call — the test would have failed
  on the v0.1 stub because the channel saw zero
  calls.
- A "skippable" permission is a real product
  decision, not a permission-system default. The
  backup folder is skippable because it is a
  user convenience, not a hard requirement
  (ADR-015). The runtime permission status enum
  has no `skippable` field; the seam
  (`BackupFolderResult`) is a separate sealed
  class that the dispatch in `_handleStepCta`
  matches on.
- The recovery affordance for "Don't ask again"
  is a Settings tile, not a hidden menu. v0.5d's
  `_PermissionsRow` is a single-glance surface
  that the user can find in 1 tap from the home
  screen. The deep-link to the system
  app-settings page is the only recovery path
  for `permanentlyDenied`; the tile is the only
  place it is exposed.

## ADR-017 — v0.5e-fix: `com.doit.package` is an invalid Java namespace; rename to `com.doit`

**Date:** 2026-06-16.
**Status:** Accepted.
**Supersedes:** The v0.5a applicationId / namespace pick of
`com.doit.package`. The earlier choice looked
stylistically right ("com.doit" + the Dart package
name "doit" as a redundant suffix) but is a build
defect: AGP rejected the namespace at release-build
time because `package` is a Java reserved keyword.

**Context.** The v0.5a rename commit picked the
applicationId and namespace as
`com.doit.package`, mirroring the v0.5a Dart
package name `doit` with `package` as a
"namespace segment". The earlier values were
`com.common_games.streak`, the v0.1 through
v0.4b scaffolding. The 3-gate (format / analyze /
test, 407 / 407) was green and the v0.5a pin
tests in `test/release_signing_test.dart`
asserted `applicationId == "com.doit.package"`
and `namespace == "com.doit.package"`.

At v0.5e, `flutter build appbundle --release`
failed with:

```
* What went wrong:
Execution failed for task ':app:processReleaseResources'.
> A failure occurred while executing com.android.build.gradle.internal.res.LinkApplicationAndroidResources$TaskAction
> Android resource linking failed
ERROR:/.../com.doit.package/app-release-unsigned.ap_:
Namespace 'com.doit.package' is not a valid Java package
name as 'package' is a Java reserved keyword
```

**Why the v0.5a pick was wrong.** `package` is a
Java reserved keyword (JLS §3.9). It cannot
appear as a segment of a Java package name —
which means it cannot appear as a segment of an
AGP `namespace` or `applicationId`. The defect
was missed at v0.5a review because:

- The 3-gate did not include
  `flutter build appbundle --release`. The v0.4
  right-side gate is format / analyze / test;
  the release build is the user's hands-on
  step (ADR-013's lesson: the release AOT path
  is not testable in `flutter test`).
- The v0.5a pin tests asserted the
  `applicationId` and `namespace` were *exactly*
  `com.doit.package`. A wrong-but-consistent
  value passes the test.
- `com.doit.package` *looks* fine in a code
  review — it reads as a stylistic choice
  ("the package for the doit app"). The Java
  reserved-keyword check is invisible to
  anyone who does not know the JLS keyword
  list by heart.

**The fix (v0.5e-fix).** Five surgical changes,
all in a single fix commit:

1. `android/app/build.gradle.kts` —
   `namespace = "com.doit"`,
   `applicationId = "com.doit"`. The
   explanatory comment is updated to mention
   the v0.5e-fix history without naming the
   bad value literally (the regression guard
   in test 2 below rejects the literal
   `com.doit.package` string).
2. `android/app/src/main/AndroidManifest.xml`
   — `<action android:name="com.doit.FIRE_ALARM" />`
   (was `com.doit.package.FIRE_ALARM`).
3. `android/app/src/main/kotlin/com/doit/package/`
   → `android/app/src/main/kotlin/com/doit/`
   via `git mv` (with an intermediate name,
   `doit_tmp`, because the target parent
   directory already exists). Every
   `package com.doit.package` declaration in
   the four `.kt` files becomes
   `package com.doit`.
4. `test/release_signing_test.dart` — the
   v0.5a pin test is rewritten to assert
   `applicationId == "com.doit"` and
   `namespace == "com.doit"`. A new
   regression-guard assertion is added:
   `expect(build, isNot(contains('com.doit.package')),
   reason: 'v0.5e-fix: com.doit.package is an
   invalid Java namespace ...')`. A future
   revert of either the applicationId or
   namespace value (or a "fix" that picks
   `com.doit.package` again) fails the test.
5. The four affected doc files
   (`v0_1_baseline.md`, `v0_5_release_baseline.md`,
   `v0_5_release_checklist.md`,
   `implementation_status.md`, plus `CHANGELOG.md`
   and `AGENTS.md`) are updated to record the
   v0.5e-fix history with a parenthetical
   "(earlier draft picked
   `com.doit.package`; v0.5e-fix renames to
   `com.doit`)".

The release AAB (61.0 MB) and APK (69.8 MB)
rebuild successfully and the 3-gate returns
to 407 / 407 (the test count went from 18
to 18 in `release_signing_test.dart` — the
v0.5a pin test is rewritten in place; the
regression-guard assertion is a new
`expect` inside the same test body).

**Consequences.**

- The applicationId is `com.doit`. The launch
  command becomes `adb shell monkey -p
  com.doit -c android.intent.category.LAUNCHER
  1`. The `adb uninstall com.doit` + `adb
  install` cycle replaces the v0.4b uninstall
  of `com.common_games.streak`. The install
  boundary is unchanged from the v0.5a
  plan.
- `com.doit` is shorter than the v0.5a
  pick, and the v0.5a "stylish redundancy"
  (`com.doit.package` repeating the Dart
  package name) is gone. The user-facing
  launcher label is unchanged ("do it").
- The `test/release_signing_test.dart`
  regression guard is the project's first
  static-analysis test for *invalid* values
  (the existing v0.4b-release-fix-2 tests
  pin the absence of R8 / minify). The shape
  — `expect(build, isNot(contains('X')))`
  with a `reason:` — is reusable for future
  defects of the form "this string must
  never appear in the build output".
- The v0.5e-fix is the third post-`flutter
  build appbundle` defect in this project
  (after v0.4b-release-fix and
  v0.4b-release-fix-2). The pattern is
  consistent: the 3-gate is necessary but
  not sufficient; the release-build step is
  the only way to catch these defects, and
  it must run *before* the on-device
  verification.

**SYS-IDs affected:** None. The applicationId
and namespace are build-config, not
requirements. (SYS-025 is the rationale-UI
contract; SYS-063..066 are the runtime
permission contracts; none of them pin the
Java package name.)

**Workflows affected:** None. The v0.5e
on-device verification (WF-001) is unchanged.

**Lessons (project-wide).**

- A green 3-gate does not mean a green
  build. The v0.5e-fix, like the
  v0.4b-release-fix and the
  v0.4b-release-fix-2, was caught only by
  running `flutter build appbundle --release`.
  CI does not run the release build by
  default (the four `ANDROID_*` GitHub
  Secrets are not present in forks); the
  release build is a local-user step.
- Pin tests for *invalid* values matter.
  The v0.5a pin tests asserted the
  `applicationId` was `com.doit.package`
  *exactly*. A future change that re-picks
  the bad value would have passed the test.
  The v0.5e-fix regression guard
  (`isNot(contains('com.doit.package'))`)
  is the negative-space pin the project
  needed.
- "Stylistic redundancy" in identifiers is
  a smell, not a virtue. The v0.5a
  rationale for `com.doit.package` was
  "the applicationId matches the Dart
  package name". The cost of the
  redundancy is a longer string to type
  and review, and the v0.5e-fix
  demonstrates that the redundancy can
  hide a defect: a reviewer is more
  likely to approve a string that *looks
  intentional*. The shorter `com.doit`
  is harder to misread.
- The Java reserved-keyword list
  (JLS §3.9) is a *small, fixed* list
  worth knowing by heart for Android
  package work: `abstract`, `assert`,
  `boolean`, `break`, `byte`, `case`,
  `catch`, `char`, `class`, `const`,
  `continue`, `default`, `do`, `double`,
  `else`, `enum`, `extends`, `final`,
  `finally`, `float`, `for`, `goto`, `if`,
  `implements`, `import`, `instanceof`,
  `int`, `interface`, `long`, `native`,
  `new`, `package`, `private`,
  `protected`, `public`, `return`,
  `short`, `static`, `strictfp`, `super`,
  `switch`, `synchronized`, `this`,
  `throw`, `throws`, `transient`, `true`,
  `false`, `try`, `void`, `volatile`,
  `while`, `_` (and the contextual
  keywords `var`, `yield`, `record`,
  `sealed`, `permits`, `non-sealed`).
  `package` is the only one likely to
  appear in an Android applicationId
  *or* namespace segment.

---

## ADR-018 (reserved)

Reserved (out of order; the v0.5 numbering reached 018 only after
ADR-014..017 and a 013 follow-up. v1.0 keeps the next number free for
the next naming-breaking refactor; this ADR is therefore a placeholder
and not a decision.)

## ADR-019 (reserved)

Reserved. v1.0 has two new templates features on the
roadmap (a curated 25-template library + a user-saveable
template store). When the Templates PR lands it will
take this slot; if a smaller ADR arrives first the
reservation will be renumbered.

## ADR-020 — v1.0/Phase B: Template model + JSON envelope

**Date:** 2026-06-20.
**Status:** Accepted (lands across three PRs: data
layer + migration + library, UI layer, doc sync).
**Supersedes:** none.

**Context.** v1.0/Phase B introduces a curated library
of 25 templates (Do / Event / Person / Routine) that
the user can pick to pre-fill the existing add screens,
plus a "Save as template" action on those add screens so
users can capture their own configurations for reuse
(see SYS-067, SYS-068, WF-032, WF-033).

The first open question is the **shape of a Template**.
Two candidates:

- **Sealed `Template` hierarchy** with
  `TemplateDo / TemplateEvent / TemplatePerson /
  TemplateRoutine` subclasses. Strongly typed; each
  subclass carries its own typed payload. The catalog
  UI needs four `when` branches.
- **Single `Template` class with an `entityType`
  discriminator enum**, storing the typed payload as a
  `String payloadJson` blob. Mirrors the existing
  `Do.scheduleType` discriminator pattern
  (`tables.dart`) and the `MissionChain` JSON-on-row
  pattern (`do_repository.dart:317`). The catalog is one
  `GridView`.

The second open question is **how the payload is
serialized**. Two candidates:

- **Hand-rolled `dart:convert` JSON envelope** with a
  version pin (`kTemplateFormatVersion = 1`), mirroring
  `kBackupFormatVersion` (`backup_service.dart:76`).
- **`freezed` + `json_serializable` codegen.** Matches
  `freezed` is not currently used in this codebase;
  `do_repository.dart:320` uses `jsonEncode` directly,
  and `backup_service.dart:96-104, 124-138` uses
  `dart:convert` for the envelope.

The third open question is **how built-ins are
seeded**. Two candidates:

- **`AppDatabaseService.init()` calls a `seedInto(db)`
  function that runs `INSERT OR IGNORE` keyed on
  `id`**, idempotent.
- **Migration-bound seed inside `migrateV2ToV3`**.
  Bundling a seed with a migration couples a schema
  change to a content change; downgrades are awkward.

**Decision.**

1. **Single-class `Template` with `entityType`
   discriminator.** Mirrors `Do.scheduleType`. The
   `TemplatePayload` (the inner payload map) is the
   strongly-typed concept; the `Template` row is the
   catalog row. The 25 templates share one table, one
   repository, and one catalog grid; the inner payload
   type is validated at apply time per `entityType`.
2. **Hand-rolled `dart:convert` JSON envelope,
   `kTemplateFormatVersion = 1`.** Mirrors
   `kBackupFormatVersion`. Format:
   `{"k":1,"<entityType>":{...inner fields...}}`. A
   mismatch (missing `k`, unknown `k`, or wrong inner
   key) throws `TemplateValidationException` (sealed,
   mirror of `EventValidationException`).
3. **Seed in `AppDatabaseService.init()` AFTER the
   migration runs**, gated on `from < 3` so existing v3
   users do not re-seed. The seed is idempotent:
   `INSERT OR IGNORE` keyed on the built-in `id`
   (`t_builtin_01`..`t_builtin_25`). A user that
   deletes a built-in does NOT get it re-seeded on the
   next launch (idempotency, not "always-present").
4. **Built-ins are read-only.** `TemplateRepository
   .deleteById(id)` refuses `isBuiltIn: true` with
   `TemplateIsBuiltIn`; the catalog's "Your templates"
   tab is the only place a delete affordance lives.
5. **Dart reserved-keyword workaround.** `enum
   TemplateEntityType { doEntity('do'), event('event'),
   person('person'), routine('routine') }`. The enum
   constant is `doEntity` because `do` would shadow the
   imported `Do` model. The wire value is `'do'`,
   matching the `entityType` column in the `Templates`
   table.
6. **Routine entityType is shipped in the schema, not
   in the seed.** Phase B seeds 19 templates (Do +
   Event + Person). The 6 routine templates from the
   master plan are deferred to Phase F
   (`add_routine.dart` does not exist yet). The data
   model already supports `entityType: 'routine'`,
   so Phase F is a seed-only add (no schema change).

**Phasing.**

- **PR 1 (data).** Drift schema v2→v3, `Template`
  model, `kTemplateFormatVersion = 1`, 19-template
  library, `TemplateRepository`. Verification:
  `flutter test test/db/migration_test.dart
  test/services/template_repository_test.dart
  test/templates/`.
- **PR 2 (UI).** `TemplatesScreen` catalog with filter
  chips (Do / Event / Person / Routine), `initialPayload`
  pre-fill on `AddHabitScreen` / `AddPersonScreen` /
  `AddEventScreen` (extracted from `events.dart` into
  its own file), AppBar "Save as template" action on
  all three add screens. Verification:
  `flutter test test/screens/templates_test.dart
  test/screens/home_test.dart
  test/screens/add_habit_test.dart
  test/screens/add_person_test.dart
  test/screens/add_event_test.dart`.
- **PR 3 (docs, this ADR plus SYS-067/068, WF-032/033,
  the conops Templates section, the architecture
  options Templates layer, and the CHANGELOG).
  Doc-only PR; closes the V right-side.**

**Consequences.**

- **Templates restore automatically** via the existing
  backup service (`backup_service.dart`) because they
  are a regular Drift table. No `kBackupFormatVersion`
  bump is needed in Phase B. Phase F's routine
  templates will be backward-compatible at the DB
  level (column already exists in v3).
- **Routine templates in Phase B are visible but
  disabled** with a "Coming in v1.1" badge. The card
  tap shows a `SnackBar` ("Routines land in v1.1.").
  Phase F wires up the `AddRoutineScreen` apply path
  and swaps the badge for the "Use this" button.
- **Routine templates' `payloadJson` is not validated
  in Phase B.** The repository validates the envelope
  shape (`k` + inner key) but the inner routine
  payload is opaque until Phase F. Phase F will add
  the `RoutineTemplatePayload` decoder.
- **Catalog grid is 2-column, not 4-column.** The
  existing 64-icon `icon_picker.dart` is 4-column
  because each tile is icon-only. Template cards carry
  name + description, so 2-column is the readable
  width on a phone screen.
- **`TemplatesScreen` is reached from the home FAB's
  bottom sheet** ("Browse templates" tile), NOT from
  the home screen's tab bar. Templates are an
  opt-in affordance — a user who never opens the
  catalog never sees it. This mirrors the "blank
  add" vs "browse templates" choice the plan calls out.

## ADR-021 (reserved)

Reserved for the geofence library choice
(`flutter_geofence` vs `geofencing` vs platform-channel native).

## ADR-022 (reserved)

Reserved for the device-state polling cadence (60s
default; reactive for charging / silent mode via
platform broadcasts).

## ADR-023 (reserved)

Reserved for the calendar library choice
(`device_calendar` vs `add_2_calendar` vs platform
`CalendarContract`).

## ADR-024 — v1.0/Phase A: rename "Habit" → "Do" across model, UI, and docs

**Date:** 2026-06-20.
**Status:** Accepted (lands across three PRs: class rename,
UI copy, doc sync — see "Phasing" below).
**Supersedes:** The v0.1..v0.5e framing of the
core entity as a "Habit" (`HabitFixed`,
`HabitInterval`, `HabitAnchor`, `HabitDayOfX`,
`HabitTimeWindow`, `HabitProofMode`, `HabitCategory`,
`HabitIcons`, `HabitRepository`, `HabitRow`,
`StreakCalculator`, `RestDayBudget`).

**Context.** The product started as a fused personal
habit coach: time-of-day reminders with mission-gated
proof (Alarmy DNA), contact-cadence for
stay-in-touch (Google Reminders DNA), and an
"anchored" wake-up→routine chain (Samsung Routines
DNA). That framing baked "Habit" into the class
hierarchy, the UI copy, and every V-Model artifact.
v1.0 broadens the surface area to *any* thing the
user wants to do on a schedule: one-off events,
contact cadences, location-triggered routines,
device-state routines, calendar-triggered routines,
incoming-call routines (the Japan silent-mode
template). The "habit" word starts to be a
misdirection the moment a user adds a "Pay rent"
event or a "Ring Mom through silent mode" routine —
neither is a *habit* in any honest reading.

The umbrella entity must read as a **Do**:
whatever the user wants done, on whatever schedule
or trigger makes sense. "Streak" is also wrong:
the user does not care that the counter is shaped
like a streak; they care how many *consecutive
times* they did it. A run is what the number
counts; "consecutive run" is the honest name.

**Decision.** Three mechanical PRs, in order:

1. **PR A1 (class rename).** `Habit*` → `Do*` in
   the model layer; `lib/habits/` → `lib/do/`;
   `HabitRepository` → `DoRepository`; `HabitRow`
   → `DoRow`; `HabitProofMode` → `DoProofMode`;
   `StreakCalculator` → `ConsecutiveCounter` (with
   the `StreakConfig` / `StreakSnapshot` value
   classes unchanged — they are the *data*, not the
   calculator); `RestDayBudget` → `SkipBudget`.
   The DB schema does **not** migrate: column
   names stay `habitId`, `targetHabitId`, etc., to
   avoid a needless v2→v3 column-rename migration.
   The domain field `CompletionLogEntry.doId`
   replaces the old `habitId` (model-side
   translation happens in `DoRepository`).
2. **PR A2 (UI copy).** User-facing strings:
   "habit" → "do"; "streak" → "consecutive
   done"; "rest day" → "skip day". The internal
   `ValueKey` selectors (`'habit_tile.h1'`,
   `'add_habit.save'`, `'home.fab.habit'`) are
   preserved as the test API; they are
   intentionally not the user-facing copy.
3. **PR A3 (doc sync — this PR).** `conops.md`,
   `requirements.md`, `workflows.md` get the
   rename in their prose; SYS- IDs are preserved
   (SYS-001 still says "add a habit" in the row
   but the body is reworded to "add a do" with a
   pointer to this ADR); test file paths in
   requirements.md are left pointing at
   `test/habits/...` because the test directory
   was deliberately not renamed in this phase
   (renaming test paths would invalidate
   coverage reports; defer to a later PR if ever
   needed).

**Why "Do" and not "Task" / "Routine" / "Reminder".**

- **Do** matches the app name "do it" and the
  current `doit` Dart package — every brand cue
  already points at "do".
- **Task** is too generic and reads as a
  one-off to-do (Google Tasks DNA), not a
  repeated action.
- **Routine** is the *trigger* side (Samsung
  Routines), not the *action* side. A routine
  is a `(trigger, condition, action)` triple;
  the entity the user is configuring a
  reminder for is the *action* — a Do.
- **Reminder** is the notification, not the
  thing. The user does not want to "remind me";
  they want to "drink water", "call Mom",
  "pay rent", "ring through silent mode".

**Why "consecutive run" and not "streak".** A
streak implies fire; a missed day is a "break".
A *consecutive run* is a count of days
completed in a row — the number itself is
neutral on shame. This matches the v0.1
brand-voice rule "Missed days are facts, not
failures" (see `conops.md` § Brand voice).

**DB schema policy.** No migration. The
`habitId` / `targetHabitId` column names are
internal — they never appear in user-facing copy
or in any requirement. The cost of a
column-rename migration is real (every backup
file in the field has the old column name; every
restore path must continue to work for v0.5e
backups written before the migration). The
benefit is cosmetic. The 80% coverage floor and
the 3-gate would not catch a missed-rename
defect at this scale. The decision is to
keep the column names and add a one-line note
in `architecture_options.md` § "DB schema
naming" explaining why. (The note will land in
Phase C alongside the v3→v4 automations-column
migration, which is a real schema change and
deserves its own ADR.)

**Phasing.** The three PRs land in sequence on
`main`, each with the 3-gate green and the
matching conventional-commit message:

```
feat(v1.0): rename Habit→Do classes (Phase A, PR 1/3)
feat(v1.0): rename user-facing copy 'habit'→'do', 'streak'→'consecutive done' (Phase A, PR 2/3)
docs(v1.0): sync v_model docs to Do / consecutive run framing (Phase A, PR 3/3)
```

Each PR is independently revertable. Reverting
PR 2 or PR 3 alone leaves the codebase in a
mixed state (new class names, old user copy) —
that is acceptable for a single release because
the user copy is the only user-visible diff and
it does not affect any backup / restore / data
path.

**SYS-IDs affected:** Body text of SYS-001,
SYS-003, SYS-004, SYS-005, SYS-007, SYS-008,
SYS-013, SYS-018..021, SYS-031, SYS-033,
SYS-039..045, SYS-046, SYS-047, SYS-048,
SYS-049, SYS-055, SYS-064. The ID numbers
themselves are preserved (the requirements
contract is stable across the rename). The
*class names* referenced in the Verification
column are updated to the new names
(`DoProofMode`, `ConsecutiveCounter`,
`SkipBudget`, `DoTimeWindow`, `DoCategory`,
`DoFixed`).

**Workflows affected:** WF-002, WF-019,
WF-022, WF-027, WF-029, WF-031 (the six
workflows whose descriptive title mentions a
"habit"). The WF-NNN IDs are preserved. The
class names referenced in the body are updated.

**Out of scope for Phase A (deferred to later
phases).**

- The v0.1..v0.5e `test/habits/` and
  `test/services/habit_repository_test.dart`
  test file paths. The test *contents* are
  already updated to the new class names
  (verified by 438/438 green at v1.0-tip);
  the *file paths* are deferred to avoid
  invalidating coverage reports. The test
  files renamed in this phase:
  - `lib/habits/habit.dart` → `lib/do/do.dart`
  - `lib/habits/category.dart` →
    `lib/do/category.dart`
  - `lib/habits/proof_mode.dart` →
    `lib/do/proof_mode.dart`
  - `lib/habits/streak_calculator.dart` →
    `lib/do/consecutive_counter.dart`
  - `lib/habits/rest_day_budget.dart` →
    `lib/do/skip_budget.dart`
  - `lib/services/habit_repository.dart` →
    `lib/services/do_repository.dart`
- The v0.1..v0.5e `lib/habits/` directory
  itself. After PR A1, the directory is empty
  and the 6 source files have moved to
  `lib/do/`. The directory is removed in the
  same PR (`rmdir`).
- `lib/habits/habit_assets.dart` (the
  `rootBundle` reader for preset definitions).
  The presets will be re-introduced under
  `lib/templates/` in Phase B (curated 25-template
  library). Until Phase B lands, the file is
  preserved in `lib/habits/` for backward
  compat with the v0.5e release.
- The Drift table name `RestDayBudgets`. The
  model class is `SkipBudget`; the Drift table
  stays `RestDayBudgets` for the same schema
  reasons (no migration; the table name is
  internal). The PR renames the *class*, not
  the *table*.
- The Drift table name `Habits`. The model
  class is `Do`; the Drift table stays
  `Habits` for the same reason. The PR renames
  the *class*, not the *table*.

**Lessons (project-wide).**

- "Product" naming in code lags product naming
  in the docs. The decision to ship as a
  "personal habit coach" baked "Habit" into 6
  model files, 8 service files, 14 screen /
  widget files, 4 v_model docs, and 22 test
  files in v0.1..v0.5e. The cost of the
  rename is one PR per layer (class, UI, docs)
  plus a 2-3x-grep sweep on the test paths
  (deferred). A shorter feedback loop from
  product naming to class naming — e.g., naming
  the entity "Do" from the v0.1 first commit —
  would have saved a day of mechanical refactor.
- "Streak" is a loaded word. The product voice
  already forbade shame language ("broke",
  "lost") but the noun itself ("streak")
  implies fire; a missed day reads as a
  "broken streak" by default. The "consecutive
  run" framing is brand-aligned: the number
  is what counts; the failure mode is "missed"
  not "broke". This was a free upgrade the
  rename enabled.
- "No DB migration" is the right default for
  rename-only refactors. The 3-gate will not
  catch a column-rename defect, and the
  restore-from-old-backup path is non-trivial
  to test (every backup file in the field has
  the old column name; the v0.5e backups must
  continue to restore). Keep DB column names
  stable across a code-side rename; reserve
  migrations for actual schema changes.
- v1.0 of an Android app is a good moment to
  do a naming pass: the user base is small,
  the backup files are still local-only, the
  schema has not yet been versioned in the
  field. Defer the rename to a v1.0 minor
  bump; never to a v1.x patch.
