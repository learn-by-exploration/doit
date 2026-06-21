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

## ADR-019 — v1.0/Phase F PR 1: call-screening implementation — `CallScreeningService` over `PhoneAccount`

**Date:** 2026-06-20.
**Status:** Accepted (v1.0 / Phase F PR 1 / SYS-075).

**Context.** v1.0 Phase F wires the "Japan silent-mode"
routine (SYS-075): when an incoming call matches a
configured contact AND the device ringer is silent, the
app (a) snaps the ringer to `RINGER_MODE_NORMAL`,
(b) plays the contact's ringtone at max volume,
(c) launches the existing full-screen `FullScreenActivity`
with the caller's name + photo, and (d) on dismiss
restores the prior ringer mode. The implementation needs
three capabilities:

1. **Per-call interception.** The OS hands each incoming
   call to a callback before the dialer rings. The
   callback returns a `CallResponse` (allow / silence /
   reject) that the dialer honors.
2. **Per-call metadata.** The callback receives the
   caller's number (E.164), and a `ContactsContract.PhoneLookup`
   lookup is cheap enough to resolve the contact's
   display name and photo URI inline.
3. **Ringer override + restore.** A snapshot of the
   current `AudioManager.RINGER_MODE_NORMAL/SILENT/VIBRATE`
   is taken at the moment of interception and restored
   on dismiss.

The two Android-native surfaces that meet these
capabilities are:

| Surface | Notes |
|---|---|
| `CallScreeningService` (API 24+) | OS-routed callback. Each incoming call invokes `onScreenCall(Call.Details)`. The service returns a `CallResponse` (disconnect / silence / skip). The OS then routes the call to the dialer per the response. No `READ_PHONE_STATE` needed; only `BIND_SCREENING_SERVICE` (a signature-protected system permission granted at install time). |
| `PhoneAccount` + `Connection` (API 26+ via Telecom) | Register a self-managed `PhoneAccountHandle`; the OS routes all calls through our `ConnectionService`. Lets us implement UI on top of the call, mute / unmute, hang up, etc. Requires the user to enable our `PhoneAccount` in the system dialer settings — a two-step opt-in the user rarely completes. Also requires `MANAGE_OWN_CALLS` and (for connection-level control) `READ_PHONE_STATE`. |

**Decision.** `CallScreeningService` over a thin
`doit/call_interceptor` method channel. The Kotlin side
lives at
`android/app/src/main/kotlin/com/doit/CallInterceptor.kt`;
the matching Dart singleton is
`lib/services/call_interceptor.dart`. The bridge mirrors
the Phase D `DeviceStateChannel` pattern: Kotlin owns the
screening service and the channel, Dart owns the matching
engine and the action dispatch.

**Rationale.**

- **Zero new user-facing permission.** `CallScreeningService`
  needs `BIND_SCREENNING_SERVICE` only, which is a
  signature-or-system permission automatically granted
  at install time. `PhoneAccount` requires the user to
  enable our `PhoneAccount` in the dialer settings (a
  step most users skip) plus `MANAGE_OWN_CALLS` and
  potentially `READ_PHONE_STATE`. The `READ_PHONE_STATE`
  permission was previously deferred to v0.2f
  (`acceptance_run_v2.md`) — going `PhoneAccount` would
  force it into v1.0. `CallScreeningService` keeps it out.
- **Synchronous interception is exactly the model we want.**
  The screening service's `onScreenCall` runs on the main
  thread before the dialer rings; the `CallResponse`
  return value is honored by the OS. By contrast
  `PhoneAccount` requires us to build a `Connection` and
  present our own UI for the entire call — we do not
  need to replace the dialer, we just need to silence
  the dialer's ring for a specific contact.
- **Ringer override + restore is straightforward.**
  `AudioManager.getRingerMode()` returns the current
  mode (we cache it), `setRingerMode(RINGER_MODE_NORMAL)`
  snaps to ring, and on the user's dismiss we restore
  the cached value. The `CallScreeningService` does not
  own the lifecycle of the dismiss — the routine's
  `ActionCallIntercept` calls back into the bridge with
  a `restorePriorRinger()` method when the user dismisses
  the full-screen activity.
- **Reactive-first, no polling.** The screening service
  is invoked exactly when the OS has a call for us. No
  timer, no observer, no background service. Same
  reactive-first principle as ADR-021 (geofence),
  ADR-022 (device-state), ADR-023 (calendar).

**Permission.** No new user-facing permission. The
manifest declares the `<service>` for the screening
service with `android:permission="android.permission.BIND_SCREENING_SERVICE"`
and the intent-filter for
`android.telecom.CallScreeningService`. A `<queries>`
entry for `android.intent.action.ANSWER` (Android 11+
package-visibility fix) lets the screening service call
into the dialer for the dismiss flow. `READ_PHONE_STATE`
stays out of scope; the privacy policy's existing
"out-of-scope" disclosure for it is unchanged.

**Reliability.** The screening service runs in the app
process. When the OS routes an incoming call to it the
app process is started (cold start) if needed; a warm
process is preferred. The screening service returns its
`CallResponse` synchronously — the dialer honors it
before ringing. The dismiss → restore flow goes via a
Dart-side `restorePriorRinger()` call; on cold-start
misses (the user dismissed the call before our process
was up) the ringer is NOT overridden (the screening
service returns `SKIP_CALL` for unknown contact ids).
The home screen surfaces a "Japan routine unavailable"
banner if the screening role is not granted.

**Consequences.**

- The Kotlin side is a `CallScreeningService` +
  `MethodChannel` (~210 lines). No third-party
  dependency; the Android `android.telecom` API has been
  stable since API 24 and is documented in the official
  "Build a call-screening app" guide.
- The Dart side is the `CallSource` seam +
  `CallInterceptorService` singleton + the
  matching / dispatch arms in `RoutineExecutor`. Tests
  use `ScriptedCallSource` to drive the stream
  deterministically.
- `ActionCallIntercept` and `ActionOverrideSilent` (the
  two Phase F action leaves) are now wired: the executor
  switches on the action runtime type and invokes the
  bridge methods (`setCallInterceptorEnabled`,
  `setCallInterceptorContactIds`, `setRingerMode`,
  `restorePriorRinger`) for each. No `UnimplementedError`
  fallthroughs remain in the dispatch path.
- `TriggerCallIncoming.fromContacts` (the spec text in
  SYS-075) is implemented as
  `TriggerCallIncomingKnownContact` (the existing model
  leaf at `lib/triggers/trigger.dart` line 373). The two
  names describe the same trigger; the model leaf wins
  on code reuse. The ADR notes the rename so future
  readers do not hunt for a `fromContacts` class.

**SYS-IDs affected.** SYS-075 (Japan routine).

## ADR-019 follow-up — v1.0/Phase F PR 2: Japan-routine apply UX + role opt-in

**Date:** 2026-06-20.
**Status:** Accepted (v1.0 / Phase F PR 2 / SYS-075 /
SYS-079). Builds on ADR-019.
**Supersedes:** none.

**Context.** Phase F PR 1 (commit `e00a97f`) shipped the
call-screening plumbing end-to-end. PR 2 wires the
user-facing surfaces: a dedicated `AddRoutineScreen` for
template #16, a `Settings → Permissions → Call-screening`
tile, and an onboarding step for the role opt-in.

Three small decisions were made in PR 2:

1. **Role methods land on the existing
   `doit/call_interceptor` channel**, not `doit/reminders`.
   `isCallScreeningRoleHeld()` and `requestCallScreeningRole()`
   are conceptually owned by the call interceptor; the
   channel already houses `setEnabled` / `setContactIds` /
   etc. The Kotlin side wraps `RoleManager` (API 29+); on
   pre-Q the methods return `false` / no-op.
2. **Standalone routine persistence.** Per the v1.0 plan,
   routines attach to a Do/Event/Person. The Japan routine
   has no parent entity; the config is persisted as
   `JapanRoutineConfig { enabled, contactIds, targetMode }`
   in `SettingsService` under three keys
   `doit.japan_routine.{enabled,contact_ids,target_mode}`.
   The contactIds use `setStringList` — the first
   list-typed entry in the codebase, mirroring the
   SharedPreferences API exactly.
3. **Template routing.** Template #16 short-circuits
   `_onUse` to push `AddRoutineScreen`. Other routine
   templates (17..21) keep the "Coming in v1.1" badge.
   The apply UX for #17..#21 lands in v1.1 with the
   generic routine screen.

**Consequences.**

- The role opt-in is **not** a runtime permission. The
  bound permission `BIND_SCREENING_SERVICE` is
  signature-protected and granted at install time; the
  only user gesture is opting into the role via
  `RoleManager`. The Settings tile + onboarding step are
  the only places that surface the role status.
- The Japan routine silently no-ops when the role is not
  held. The home-screen reliability banner surfaces "Japan
  routine unavailable — grant the call-screening role in
  Settings" so the user has a recovery affordance without
  having to read docs.
- The `AddRoutineScreen` form writes to BOTH
  `SettingsService` (persistence) AND
  `CallInterceptorService.configure(...)` (live runtime
  push). On Save, the screening service matches the new
  contact list on the next incoming call — no app restart
  required.

**SYS-IDs affected.** SYS-075 (Japan routine — UX +
persistence surface) + SYS-079 (call-screening role opt-in,
new in PR 2).

---

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

## ADR-021 — v1.0/Phase C PR 2: geofence library choice (`geolocator` over `flutter_geofence` / `geofence_service`)

**Date:** 2026-06-20.
**Status:** Accepted (lands in Phase C PR 2).
**Drives:** SYS-072 (geofence triggers), SYS-076
(`PermissionKind.location`), and the `GeofenceService`
singleton at `lib/services/geofence_service.dart`.

**Context.** Phase C adds two trigger shapes —
`TriggerLocationEnter` and `TriggerLocationExit` — to the
sealed `Trigger` hierarchy. The trigger must subscribe to a
position stream, run Dart-side geofence matching against
the registered circles, and emit
`GeofenceEntered` / `GeofenceExited` events on a broadcast
stream. The matcher itself is a pure-Dart Haversine
comparison; the only platform dependency is the position
stream. We evaluated three options.

**Option A — `flutter_geofence` (the obvious choice).** A
purpose-built plugin wrapping the Android `Geofence` API.
The pitch is "the OS does the matching" — you register a
geofence and the OS calls you back when you cross its
boundary.

- Pro: zero Dart-side matcher; the OS does the work.
- Pro: well-documented; many tutorials.
- Con: **stale**. The last meaningful release on pub.dev is
  `0.0.5` (mid-2022), predating the
  `com.doit.package`-fix AGP 8 / Kotlin 2 namespace work
  and the Android 14+ background-location restrictions
  that now apply to `Geofence` registrations without a
  foreground service.
- Con: the OS-side `Geofence` API requires fine-location
  and is capped at 100 active geofences per app, which
  complicates the v1.0 "register one geofence per Do with
  an automation" model — power users will hit the cap
  with no warning.
- Con: pull-in brings a transitive `play-services-location`
  dependency we don't otherwise need.

**Option B — `geofence_service`.** A higher-level wrapper
that does its own position polling, foreground-service
keepalive, and Dart-side state machine. Aims to be a
"batteries-included" replacement for `flutter_geofence`.

- Pro: actively maintained (last release 2026-Q1).
- Pro: a built-in foreground service handles background
  reliability.
- Con: **overlaps responsibility** with our own
  `RoutineExecutor`. The library wants to own the position
  stream AND the geofence state machine AND fire user
  callbacks when the user crosses a boundary. We already
  have a `RoutineExecutor` that owns dispatch (Phase C
  PR 1) and a `Reliability` enum that owns degraded-mode
  copy (v0.5d). Layering `geofence_service` underneath
  would either (a) split the dispatch model across two
  patterns or (b) require us to use the library purely as
  a position-source adapter — at which point we are not
  using its value-add.
- Con: its foreground service would conflict with the v0.2
  heartbeat pattern documented in
  `notification_reliability.md` Layer 4.

**Option C — `geolocator` (chosen).** A thin position-stream
adapter. We run Dart-side geofence matching in our own
`GeofenceService` and publish `GeofenceEntered` /
`GeofenceExited` events on a broadcast stream that
`RoutineExecutor` subscribes to.

- Pro: **one dep**, no transitive `play-services-*`.
- Pro: the only API surface we need is
  `Geolocator.getPositionStream(...)` — a thin wrapper
  over `FusedLocationProviderClient`. We do not get a
  state machine we don't want.
- Pro: matches the project's "thin platform adapters,
  pure-Dart matchers" convention (mirrors the streak
  calculator, the math problem generator, the memory
  game, the shake detector).
- Pro: coarse-only (city-block) is sufficient for the
  50m..5000m radius bounds the trigger model enforces,
  which keeps us under the v0.1
  `ACCESS_FINE_LOCATION`-out-of-scope carve-out
  (`architecture_options.md` § Permission Baseline). The
  `geolocator` API does not require fine-location for
  the stream; `LocationAccuracy.low` + a 25m
  `distanceFilter` is enough.
- Con: we own the foreground-service / Doze story. This
  is mitigated by the existing
  `notification_reliability.md` Layer 2 (WorkManager
  fallback) and the v0.5d `Reliability` enum
  (`Reliability.degraded` already covers "may be late"
  copy for any time-based reminder; the same badge can
  fire when position updates are throttled).

**Decision.** `geolocator` ^13.0.1 (Option C). The
`GeofenceService` singleton is the thin platform adapter;
`computeTransitions(...)` in the same file is the pure
matcher. The `PositionSource` abstract class
(`_GeolocatorPositionSource` production,
`ScriptedPositionSource` test) keeps the platform side
mockable; the matcher is exposed `@visibleForTesting` so
unit tests can drive it without going through the
service's `register` path.

**Consequences.**

- `lib/services/geofence_service.dart` is the only
  geofence-aware file. A new `PositionSource` is a 20-line
  change; a new matcher is a 5-line change.
- The 50m..5000m radius bound (enforced by
  `TriggerLocation.validate()`) keeps the
  `ACCESS_COARSE_LOCATION` accuracy floor honest — we
  cannot claim to need fine location at any radius the
  user can pick.
- The v0.1 carve-out for `ACCESS_FINE_LOCATION` stays
  intact. Re-evaluating it is a separate ADR when (and
  if) a feature needs sub-50m accuracy.
- `Reliability.degraded` copy on the home-screen banner
  extends to cover the "position stream is throttled"
  case in Phase D when `DeviceStateProbe` ships its
  settings → triggers debug screen.

## ADR-022 — v1.0/Phase D: device-state polling cadence (reactive-first; reserve a 60s poll slot for future state)

Status: accepted (v1.0 / Phase D PR 1 + PR 2).
Date: 2026-06-20.
Owners: backend (kotlin), frontend (dart), QA.

### Context

`TriggerDeviceState` (SYS-073) needs to know when the
device's battery, charging, headphone, and screen state
change. The Android side can produce these events in two
fundamentally different ways:

1. **Reactive broadcasts.** `BatteryManager` posts
   `ACTION_POWER_CONNECTED` / `ACTION_POWER_DISCONNECTED`
   on the charging state; `AudioManager` posts
   `ACTION_AUDIO_BECOMING_NOISY` when headphones plug in;
   `PowerManager` posts `ACTION_SCREEN_ON` / `ACTION_SCREEN_OFF`
   on the screen state. Each of these is a system-wide
   sticky broadcast the app can listen to with a
   `BroadcastReceiver`. Battery *level* is a one-shot read
   via `BatteryManager.BATTERY_PROPERTY_CAPACITY` and is
   best updated reactively off the same receiver (every
   charging / disconnect fires a level re-read).
2. **Polling.** The app would re-read the relevant API on
   a fixed cadence (e.g. every 60 s) and emit a snapshot
   per tick. Polling is reliable but burns CPU + battery
   proportional to the cadence and is always *worse* than
   reactive for the four state dimensions above.

The question is which mechanism to use as the default,
and how much polling to leave in place as a safety net.

### Decision

**Reactive-first. No periodic polling in v1.0.** The
Kotlin `DeviceStateChannel` registers a single
`BroadcastReceiver` for the four reactive events
(`ACTION_POWER_CONNECTED` / `DISCONNECTED`,
`ACTION_AUDIO_BECOMING_NOISY`, `ACTION_SCREEN_ON` /
`OFF`); battery percent is re-read inside the receiver's
onReceive and pushed over the `doit/device_state` method
channel as a fresh `DeviceStateSnapshot`.

The Dart side is a pure publisher. `DeviceStateService`
is the source of truth for "which snapshots are
interesting"; the matching engine in `RoutineExecutor`
(Phase D PR 2) decides whether each snapshot is a
trigger edge for any registered automation.

**Reservation for a 60 s poll slot.** If a future
device-state dimension (e.g. Wi-Fi SSID, foreground
app) does not have a clean reactive broadcast, the
existing infrastructure has a `currentSnapshot()` method
on the source that the receiver can call on a periodic
ticker. The ticker itself is **not wired in PR 1 / PR 2**;
shipping it would burn battery for no v1.0 benefit.

### Consequences

- **Battery friendliness.** No periodic wakeup for
  device-state. The app only wakes when the OS itself
  fires a state-change broadcast.
- **Edge detection at the receiver.** A charging
  transition (true→false) and a screen-off transition
  (true→false) are both delivered as a single
  snapshot, not a sequence. The matching engine's
  edge logic (Phase D PR 2) reads `previous?.isCharging`
  / `previous?.screenOn` to decide the edge direction;
  this requires the executor to remember the last
  snapshot. `lastDeviceState` is held on the executor
  for that reason.
- **First-snapshot default.** With no previous snapshot,
  `(previous?.isCharging ?? false)` defaults to `false`,
  so the first snapshot that goes `false→true` will
  fire `TriggerChargingStarted`. This is the right
  default — the user just plugged in.
- **No data loss during Doze.** The broadcasts above are
  delivered even when the app is in Doze (they are
  system broadcasts, not user-initiated). Reliability
  for charging / headphones / screen is ~99% on stock
  Android; aggressive OEM battery savers (Xiaomi, Honor,
  Vivo) may delay broadcasts but never drop them. OEM
  detection (`lib/services/oem_detector.dart`) plus the
  existing `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
  flow (SYS-068) covers the worst cases.
- **Future poll cadence.** If a new trigger needs
  Wi-Fi SSID, foreground app, or any other state that
  lacks a reactive broadcast, the wiring is a 3-line
  change in the Kotlin side (add a `Handler.postDelayed`
  in `MainActivity.configureFlutterEngine`) plus a
  `Stream.periodic` adapter in `DeviceStateSource`. The
  ADR will be revised (or a new ADR-025 added) at that
  point.

### Alternatives considered

- **60 s periodic poll, no reactive.** Reliable but
  always at least 60 s late on a charging transition. The
  reactive broadcasts are free; using only polling is
  needless work.
- **Reactive + 60 s safety poll.** Two paths to maintain
  (the broadcast handler and the ticker) for no real
  benefit in v1.0. The ticker would only catch a missed
  broadcast, which is rare enough on stock Android that
  the added complexity is not justified. Reserved for
  any future state that lacks a broadcast.
- **`WorkManager` periodic worker.** Same trade-off as
  polling, with the added constraint of the 15-minute
  minimum interval. Strictly worse than the broadcast
  path for the four state dimensions we care about.

## ADR-023 — v1.0/Phase E PR 1: calendar read source — native CalendarContract over device_calendar / add_2_calendar

**Date:** 2026-06-20.
**Status:** Accepted (v1.0 / Phase E PR 1 / SYS-074 / SYS-078).

**Context.** v1.0 Phase E wires `TriggerCalendarEvent`
(event-start / event-end / event-reminder / free-busy)
into the routine executor. The trigger needs three
capabilities from the calendar layer:

1. **Reactive transition stream.** When an event transitions
   from upcoming to in-progress (start), in-progress to
   ended (end), or hits its reminder offset, the trigger
   must fire within seconds. The OS already exposes this via
   `ContentObserver` on `CalendarContract.Instances`.
2. **One-shot account list.** An on-demand permission
   sheet shows the user which calendars exist on their
   device (Google account work calendar, iCloud personal,
   etc.) so they can pick which one to scope a routine to.
   This is a single `query()` against
   `CalendarContract.Calendars`.
3. **No write access.** The app reads the calendar; it
   never creates, updates, or deletes events.

The candidates were:

| Library | Notes |
|---|---|
| `device_calendar` (pub.dev) | Most popular Flutter wrapper. Read + write access via a generic `Calendar` / `Event` model. Last published 2022-Q4; the underlying platform-channel calls are stale relative to Android 14+. |
| `add_2_calendar` (pub.dev) | Write-only (event creation). Useless for our read-only trigger model. |
| Native `CalendarContract` over a MethodChannel | Direct read access via `ContentResolver.query` + a `ContentObserver` on `Instances.CONTENT_URI`. ~190 lines of Kotlin; no package dependency churn; full access to reminder metadata (`MIN_REMINDER` / `MAX_REMINDER`). |

**Decision.** Native `CalendarContract` over a thin
`doit/calendar` method channel. Same pattern as the
Phase D `DeviceStateChannel`: Kotlin owns the platform
channel, Dart owns the matching engine. The Kotlin
side is in
`android/app/src/main/kotlin/com/doit/CalendarChannel.kt`;
the Dart side is `lib/services/calendar_service.dart`.

**Rationale.**

- **Reactive stream is a first-class requirement.** A
  polling loop is wasteful (and out of scope per the
  Phase D ADR-022 polling-cadence decision — we keep
  triggers reactive-first). `ContentObserver` fires on
  every insert/update/delete and is the platform's
  built-in reactivity primitive. `device_calendar`
  exposes only synchronous query helpers; turning it
  into a reactive stream would mean running our own
  timer (which violates the reactive-first policy).
- **Read-only.** `device_calendar`'s write-side helpers
  are irrelevant; we never call them. Avoiding the
  package also avoids requesting `WRITE_CALENDAR` —
  the manifest lists `READ_CALENDAR` only. See
  `docs/v_model/architecture_options.md` permission
  baseline.
- **No dependency churn.** `device_calendar` has not
  shipped a release in 18+ months and its
  platform-channel call patterns are stale relative to
  Android 14. We get to evolve the Kotlin side
  alongside the rest of the reminder-reliability work
  without a package-mediated breaking change.
- **Reminder metadata.** `CalendarContract.Reminders`
  is a first-class table; reading the per-event
  `MINUTES` / `METHOD` is straightforward via the
  `ContentResolver.query` path. `device_calendar`
  surfaces reminders as opaque integers.

**Permission.** `READ_CALENDAR` (added to the manifest
in Phase E PR 1). The user-facing rationale is "used to
trigger routines when meetings start / end / hit their
reminder time, or when your free/busy status changes"
(see `PermissionKind.calendar` in
`lib/services/permission_service.dart`).

**Reliability.** Calendar transitions are best-effort
when the app process is backgrounded: the OS suspends
the process and the `ContentObserver` does not fire.
When the user returns to the app, the
`CalendarChannel.startStream` re-issues a busy-state
probe so `TriggerFreeBusy` catches up. See
`docs/v_model/notification_reliability.md` § Trigger
reliability.

**Consequences.** The Kotlin side is a
`MethodChannel` + `ContentObserver` (~190 lines); the
Dart side is the `CalendarSource` seam + the matching
engine in `RoutineExecutor`. Test coverage uses
`ScriptedCalendarSource` so tests are deterministic
without a real `CalendarContract`.

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

## ADR-025 — v1.1: `RoutineConfig` value class for template-driven routines (templates #17–#21)

**Date:** 2026-06-21.
**Status:** Accepted (lands across v1.1a — the
value class + JSON codec + ADR — and v1.1b — the
`SettingsService.setRoutine` / `getRoutine` wire).
**Supersedes:** None.
**Refs:** SYS-080 (this ADR writes the SYS row);
[v1_1_handoff_from_v1_0g.md](v1_1_handoff_from_v1_0g.md);
`lib/services/routine_config.dart`.

**Context.** v1.0 introduced 25 curated templates
across four kinds (Do / Event / Person / Routine).
The first 16 are auto-creating: tapping a template
in `lib/screens/templates.dart` writes a new row
and lands the user on the relevant editor. The
last 5 — **templates #17..#21**, the *Routine*
kind — were stubbed in v1.0 with a curated copy
block but no apply UX: tapping a routine template
read out the description and bailed, because the
backend (the routine apply UX) was not yet wired.

v1.1 wires the routine apply UX end-to-end. The
core data shape is *one row per template id*,
holding the user's chosen trigger / condition /
action triple (all three already JSON-serializable
via `triggerToJson` / `conditionToJson` /
`actionToJson` in `lib/routines/routine.dart`).
The natural persistence is `SharedPreferences`
keyed by `doit.routine.<templateId>`, so each
template's row updates in place on re-save (no row
identity churn, no FK gymnastics).

**Decision.** A new `RoutineConfig` value class in
`lib/services/routine_config.dart` (not a Drift
row, not a `HabitRepository`-style entity) with
five fields:

| Field | Type | Notes |
| --- | --- | --- |
| `templateId` | `String` | The stable identifier; the SharedPreferences key suffix. |
| `triggerJson` | `Map<String, Object?>` | The output of `triggerToJson(...)`. |
| `conditionJson` | `Map<String, Object?>?` | `null` means "no gating condition"; the routine fires on every matching trigger event. |
| `actionJson` | `Map<String, Object?>` | The output of `actionToJson(...)`. |
| `enabled` | `bool` | The user-facing master toggle; defaults to `true`. |

The class is `@immutable`, has a `copyWith`, a
`toJson` / `fromJson` codec (version-free; each
per-shape JSON object carries its own `type`
discriminator), structural `operator ==`, and a
deterministic `hashCode`.

**Why a value class and not a Drift row.** Two
reasons:

1. The user's routine config is *owned by the
   template id*, not by a server-minted id. A
   fresh `copyWith` should round-trip through
   SharedPreferences and overwrite the same key —
   exactly what a value class + `setString`
   gives us. A Drift row would require either a
   server-minted id or `INSERT OR REPLACE` keyed
   on the templateId, plus a parallel migration
   when the schema bumps. Both are heavier than
   they need to be for 5 rows.
2. The class is a *snapshot* of the user's choices
   at apply-time. The runtime re-decodes the JSON
   triples through `triggerFromJson` /
   `conditionFromJson` / `actionFromJson` at fire
   time; the runtime never holds a `RoutineConfig`
   in memory. The class is a *config envelope*,
   not a domain entity.

**Why `SharedPreferences` and not the settings
JSON file (the `SettingsService` blob).** The
settings blob is a v1.0 artifact that holds
user-tunable strings and booleans (theme, sound,
japan-routine flag). Routines are JSON objects;
putting them inside the settings blob would force
a `SettingsService.routines: Map<String, Object?>`
key and a per-template read-modify-write through
the settings codec. One-key-per-template is
strictly simpler and stays out of the settings
codec's review surface.

**Why `JapanRoutineConfig` is NOT migrated to the
new format.** v1.0 / Phase F PR 2 already shipped
`JapanRoutineConfig` with its own three legacy keys
(`doit.japan_routine.enabled`,
`doit.japan_routine.contactIds`,
`doit.japan_routine.targetMode`). The class has a
distinct lifecycle (only one Japan routine exists
per install; it is curated, not template-driven;
its apply UX was the user's on-ramp to the
v1.0/Phase F feature). Migrating it to
`RoutineConfig` would either rename the legacy
keys — invalidating every v1.0 backup file in the
field — or require a parallel reader that prefers
the new key when both are present. Neither is
worth the risk for v1.1. `JapanRoutineConfig`
stays on its three legacy keys; the v1.1 apply UX
is for templates #17..#21 only.

**Hash determinism.** The first draft of
`hashCode` used `Object.hashAllUnordered`, which
turns out to be **non-deterministic across calls
on Dart 3.12** (it uses a randomized accumulator
for hash-collision-attack resistance — verified
with a standalone repro that printed three
different values for the same input on three
calls). A value class whose `hashCode` is
non-deterministic is unfit for `Set` /
`Map<RoutineConfig, ...>` use, so the class
implements its own order-independent map hash
(`_mapHash`): sort the keys lexicographically,
fold `(h * 31 + k.hashCode) * 31 + v.hashCode`
across the sorted entries with a 30-bit mask.
That is deterministic and stays in sync with
`_mapEquals`, which is also order-insensitive at
the top level. A null `conditionJson` is hashed
as a `-1` sentinel so `null != {}` in hash terms
too — `Object.hash(...)` XOR would have collapsed
the two.

**Lessons (project-wide).**

- **Default to one-key-per-thing in
  `SharedPreferences` before reaching for a
  table.** The natural temptation when something
  "looks like a row" is to add a Drift table.
  For 5-or-fewer rows that all update in place
  and share no schema with the rest of the app,
  SharedPreferences is the right call. Reserve
  Drift rows for entities with a domain
  identity (a server-minted id, FKs to other
  entities, query patterns).
- **Validate the deterministic-hash assumption
  for `Object.hash*` helpers.** A simple
  `expect(obj.hashCode, obj.hashCode)` test
  would have caught `Object.hashAllUnordered`
  in the first PR. Add a one-line stability
  test to every value class — it's three lines
  and prevents a class of bugs that are
  invisible to `==` but disastrous for `Set` /
  `Map` usage.
- **The legacy-keys policy from `JapanRoutineConfig`
  is now a project pattern.** v1.1 has two
  precedent classes of "config" that sit on
  SharedPreferences: structured JSON triples in
  one-key-per-template (this ADR), and primitive
  trios in three-legacy-keys (ADR-019 follow-up).
  Both are fine; the dividing line is whether
  the value is *a single triple* (three legacy
  keys are clearer) or *N triples keyed by an id*
  (one-key-per-id is clearer). Document the
  rule in `lib-services.md` next time the rules
  doc is touched.
- **`Map.hashCode` is identity-based on Dart, but
  that does not mean structural equality is
  identity-based.** A class can have structural
  `==` and a deterministic `hashCode`; the
  two need not match the underlying map's
  identity. Just be sure your hash function
  visits *every* entry (order-independent) so
  two structurally-equal maps always hash
  equal.

## ADR-026 — v1.1: `ActionOpenApp` dispatch + `RoutineOpenAppRequest` + `RoutineBanner` widget (SYS-082)

Date: 2026-06-21. Status: Accepted.
Refs: SYS-082, ADR-025 (the
`RoutineConfig` envelope), v1_1_handoff_from_v1_0g.md,
`lib/routines/routine_executor.dart`,
`lib/routines/routine.dart`,
`lib/widgets/routine_banner.dart`,
`lib/screens/home.dart`.

### Context

v1.0 / Phase C PR 1 (ADR-021) shipped a five-leaf
sealed `Action` hierarchy. v1.0 / Phase F PR 1
shipped a `_dispatchCallAction` (later
`_dispatchAction`) that handled only the two
call-related leaves (`ActionCallIntercept`,
`ActionOverrideSilent`) — the other three were
emitted into the matching engine's stream but
had no side-effect wiring. v1.1 (SYS-082) wires
the remaining three leaves and ships a real
quick-action UX: a routine may now carry an
`ActionOpenApp` that, when fired, pushes a
named route on the home-screen navigator.

### Decision

**1. One dispatch function, five leaves.**
`_dispatchAction(Automation a)` in
`lib/routines/routine_executor.dart` is a single
`is`-switch over the sealed `Action` type. Each
leaf's side effect goes through the existing
service seam (e.g. `ReminderService.instance.notifications.show`
for `ActionNotify`,
`CallInterceptorService.instance.setRingerMode`
for `ActionOverrideSilent`). Each leaf is wrapped
in a `_safe(label, fn)` helper that swallows
platform exceptions behind `kDebugMode`'s
`debugPrint`, so a single broken service does
not break the dispatch chain — the matching
engine's `AutomationFired` event still fires, and
the UI side always sees the fire.

**2. `ActionFullscreen` and `ActionCallIntercept`
stay no-ops on the executor side.** Both have a
side-effect path that already lives below the
executor (`FullScreenActivity` in Kotlin for
`ActionFullscreen`; `CallScreeningService` for
`ActionCallIntercept`). The executor's job is
limited to publishing `AutomationFired` so
listeners (the home screen, the debug chip) can
react. Future analytics / debug affordances
attach to the `AutomationFired` event, not to a
new side-effect path.

**3. `ActionOpenApp` carries a `route` string,
not a `Route` object.** The model is pure Dart
and must not import `package:flutter/*`. The
route is a string like `/settings/routines`
that the home-screen `Navigator.pushNamed` looks
up. The model's `validate()` asserts the route
starts with `/`.

**4. `RoutineOpenAppRequest` is a value class.**
`{ route, at }` is enough to drive the drain. It
is immutable, has structural `==`, and lives in
`lib/routines/routine.dart` alongside the other
routine-domain classes.

**5. The executor owns a
`ValueNotifier<List<RoutineOpenAppRequest>>`
(`pendingOpenApp`).** The executor cannot push
routes itself (it is a non-Flutter singleton;
pulling `package:flutter/material.dart` into
`lib/routines/` is the wrong layer boundary per
`.claude/rules/lib-routines.md`). Instead it
appends a `RoutineOpenAppRequest` to
`pendingOpenApp`. A Flutter-side consumer
drains the list.

**6. The drain lives in a dedicated
`RoutineBanner` widget.** Three reasons (in
priority order):

- **Layer boundary.** The executor cannot
  depend on `Navigator`; the widget is the
  natural home for the side effect.
- **Single consumer.** The home screen is
  currently the only consumer, but a future
  widget-host activity (Wear OS, Android Auto,
  the settings debug screen) will also drain
  the queue. Putting the drain in a widget
  means each consumer just adds
  `const RoutineBanner()` to its tree.
- **Passive.** When the queue is empty, the
  banner renders `SizedBox.shrink()`. No
  layout cost in the steady state.

**7. The banner captures `NavigatorState`
synchronously inside `build`, before the
post-frame callback.** This is the load-bearing
detail. The `ValueListenableBuilder` rebuild
fires when the queue is appended to; the
rebuild schedules a `addPostFrameCallback`
that calls `navigator.pushNamed(req.route)`. If
`Navigator.of(context, ...)` is called inside
the post-frame callback, a teardown between
build and post-frame throws "Looking up a
deactivated widget's ancestor is unsafe." By
capturing the `NavigatorState` while the
builder context is still mounted, the callback
can push routes safely even if the banner's
own element is gone by the time the callback
runs.

**8. The banner drains FIFO and clears
atomically.** Each `pushNamed` is wrapped in
`try { ... } on Object catch (_) { ... }` so a
single push failure does not break the chain
(a misconfigured route is the caller's
problem, not the dispatcher's). After all
pushes (or all swallows), the banner calls
`executor.clearPendingOpenApp()` which is
idempotent.

**9. The home screen places the banner
directly under `ReliabilityBanner.fromService()`
in its Column.** Both are passive listeners;
both are zero-cost in the steady state.

### Why not push from the executor via a
`GlobalKey<NavigatorState>`?

- `GlobalKey` ownership is fragile in a
  multi-Navigator app (root vs. nested
  navigators), and the executor has no
  business knowing which navigator is
  "current".
- A side-effecting executor would couple
  every test to a `MaterialApp` / `Navigator`
  setUp. Today, the executor's tests are
  pure-Dart and run in < 1 s.
- The widget approach is one-line to add
  to any future consumer (settings debug
  screen, widget-host activity). The
  `GlobalKey` approach would force every
  consumer to register the same key.

### Why not put the drain logic in
`HomeScreen.initState` as a
`ValueListenable` listener?

- The drain needs a `Navigator`, and
  `HomeScreen` has one. But every future
  consumer (settings, widget-host) would
  duplicate the same listener wiring.
- A dedicated widget is testable in
  isolation: a `pumpWidget(MaterialApp(home:
  Scaffold(body: RoutineBanner())))` is
  enough; the home screen is not.

### Lessons (project-wide).

- **The post-frame callback is not a
  re-entry into `build`.** Treat it as
  top-level code: anything `BuildContext`-derived
  must be captured before the callback.
  `NavigatorState` is a stable Element
  handle, so it survives the frame
  boundary; `BuildContext` does not.
- **"Expose a `ValueListenable`" is the
  default seam for a non-Flutter singleton
  that needs a Flutter-side side effect.**
  Three concrete wins: (a) the singleton
  stays Flutter-free, (b) the consumer
  decides when to drain (e.g. on
  resume), (c) tests can drop in a stub
  `ValueListenable` and avoid the widget
  tree entirely.
- **`is`-switch on a sealed class is the
  exhaustive default.** `_dispatchAction`
  is one function with five branches; no
  visitor pattern, no enum, no table
  dispatch. Sealed classes were designed
  for this.
- **Capture, don't reach, across async
  gaps.** The `_safe` wrapper, the
  captured `NavigatorState`, the captured
  `executor` reference — all three are
  the same pattern: resolve dependencies
  synchronously at the call site, then
  use the resolved value inside the async
  closure.

## ADR-027 — v1.1: Generic `RoutineApplyScreen` + `RoutineTemplatePayload` codec (SYS-083)

**Date:** 2026-06-21. **Status:** Accepted.

### Context

The v1.0 sign-off left templates #17..#21
(the five template-driven routines: calendar,
location, device-state, charging, timer) with
a "Coming in v1.1" badge — only template #16
(Japan silent mode) had a real apply UX
(`AddRoutineScreen`). v1.1d closes that gap.

The naive path is "five screens, one per
template". We instead ship **one generic
screen + one codec**, then defer the
per-template picker UIs to v1.1e+. This is
the smallest viable scope that satisfies the
"every routine template has a real apply
button" outcome.

### Decision

**1. One value class for the template envelope.**
`RoutineTemplatePayload` (in
`lib/routines/routine_template_payload.dart`)
decodes the template's `payloadJson` —
`{k: 1, routine: {trigger, condition, action,
note}}` — into `{templateId, name, description,
trigger, condition, action, note}`. Structural
`==` + `hashCode` + `toString` follow the
project's value-class conventions.

**2. Fail-soft decoding.** The decoder
returns `null` on every defect path:
malformed JSON, non-object envelope, missing
`routine` key, non-object `routine`,
non-string `trigger` / `action` / `condition`,
empty `trigger` / `action`. Empty `condition`
and `note` are tolerated (the screen renders
"(no condition)" + omits the note paragraph).
**No throw.** A malformed template is
*expected* (user-authored templates, a
half-built library row, a downgrade from a
future schema), not a programming error.

**3. `toRoutineConfig` emits the
`routine_placeholder.v1` sentinel.** Both
`triggerJson` and `actionJson` carry
`{type: 'routine_placeholder.v1', kind: <trigger
or action>, raw: <condition>}` (actionJson also
has `note: <note>`). The runtime decodes this
sentinel at dispatch time in a future PR; v1.1d
ships only the persistence path.

**4. One screen, six widgets.**
`RoutineApplyScreen` is a `StatefulWidget`
that:

- shows the template name in the AppBar
  and the description in the body,
- renders trigger / condition / action as
  three read-only `_Chip` widgets
  (per-template picker UIs land in v1.1e+),
- has a `SwitchListTile.adaptive` for the
  enable toggle,
- has a `FilledButton` whose label is
  "Save" / "Update" depending on whether a
  `RoutineConfig` already exists for the
  templateId,
- shows a `FilledButton.tonal` "Delete"
  button only when an existing config is
  present,
- falls back to a `_MalformedView` (icon +
  error copy) when the codec returns null.

The screen is pure UI; persistence goes
through `SettingsService.setRoutine` /
`deleteRoutine` (the singleton-with-`_ready`
pattern per `.claude/rules/lib-services.md`).
The screen does NOT talk to the executor
directly — that boundary is a follow-up
PR (the executor is a non-Flutter singleton
and consumes `SettingsService.routines`
reactively).

**5. `Navigator.of(context).canPop()` guards
both pop calls.** The screen is always pushed
in production (from `TemplatesScreen._onUse`),
so `canPop` is true. But widget tests mount
it as `MaterialApp.home` (no route to pop
to), and `pop()` on the root route hangs
the pop transition. The guard makes the
root-mounted case a clean no-op while
preserving the production pop.

**6. The catalog reuses the existing
`MaterialPageRoute` pattern.**
`TemplatesScreen._onUse` already routes
template #16 to `AddRoutineScreen`; v1.1d
adds a switch arm for `TemplateEntityType.routine`
that pushes `RoutineApplyScreen(template: t)`.
The "Coming in v1.1" badge on the
`_TrailingAction` button is replaced by the
existing "Use this" button (the screen is
now real, not stub).

### Alternatives considered

### Five per-template screens, one per trigger shape

- **Pro.** Each screen can show a real picker
  UI (a calendar event chooser for the
  calendar trigger, a map for location, etc.).
- **Con.** v1.1e is already scoped to ship
  those pickers; doubling the surface area
  before the picker layer exists is
  premature. The "smallest viable" v1.1d
  is the codec + Save/Update/Delete form
  with read-only chips.
- **Verdict.** Deferred. v1.1e..v1.1i
  (the per-automation follow-ups) will
  refactor the chips into real picker
  widgets in-place.

### Throw on malformed envelopes

- **Pro.** Catches bugs at the library
  row; a half-built template crashes the
  apply screen instead of silently showing
  a "could not load" view.
- **Con.** The library is user-extensible
  (templates can be imported from a
  backup, shared between devices, authored
  by hand). A malformed row should fail-
  soft in the UI; the real validation
  happens at save time on the canonical
  side (the template repository's
  `validateAtSave` rule).
- **Verdict.** Rejected. Fail-soft matches
  the project's "validate at save,
  tolerate at read" rule (see
  `docs/v_model/decision_record.md` ADR-018).

### Put `RoutineTemplatePayload` in
`lib/templates/` instead of
`lib/routines/`

- **Pro.** It's a template decoder.
- **Con.** The trigger / condition / action
  vocabulary is owned by `lib/routines/`
  (the runtime codec in
  `lib/routines/routine.dart`). A payload
  decoder that lives in `lib/routines/`
  can colocate with the shape definitions
  it produces.
- **Verdict.** Rejected. The decoder lives
  in `lib/routines/routine_template_payload.dart`;
  the file header cross-links both
  directions.

### Reuse `JapanRoutineConfig` / `AddRoutineScreen`

- **Pro.** No new code.
- **Con.** `JapanRoutineConfig` is the v1.0
  three-key Japan-only schema
  (`doit.japan_routine.enabled` etc.); the
  template-driven flow is the v1.1
  `doit.routine.<templateId>` schema
  (SYS-080). Reusing the wrong class means
  shipping the wrong key.
- **Verdict.** Rejected. The two flows stay
  separate on purpose; ADR-025 is explicit
  about "the v1.1 routine-config key is
  deliberately NOT a migration target".

### Lessons (project-wide).

- **The "smallest viable apply UX" is a
  form, not a wizard.** A wizard feels
  right ("Step 1: trigger, Step 2:
  condition, Step 3: action") but it
  pushes the picker complexity forward to
  every step. A vertical form with read-only
  chips is enough for v1.1d; the per-step
  picker widgets slot into the existing
  chip slots in v1.1e+.
- **`canPop()` guards are cheap insurance
  for tests.** A `Navigator.pop()` call
  that hangs in widget tests is a common
  time-sink (10-minute timeouts before the
  harness gives up). A two-line guard
  turns the hang into a clean no-op.
- **`tester.runAsync` is the right seam
  for "wait for the awaited Future".**
  `pumpAndSettle()` waits for frames but
  not microtasks, so an `await
  setRoutine(...)` inside `_save` is
  not guaranteed to be complete by the
  time the assertion runs. `tester.pump()
  + tester.runAsync(...) + tester.pump()`
  is the established pattern.

## ADR-028 — v1.1e: Offline `CustomPaint` map preview for `LocationPicker` (SYS-084)

Status: accepted 2026-06-21.

### Context.

The v1.0 / Phase C / SYS-076 `LocationPicker`
modal bottom sheet has three ways for the
user to set a geofence: paste a lat / lon,
key in a label, or tap "Use current
location" (which calls `Geolocator.
getCurrentPosition` under a
`PermissionSheet` gate). None of these give
the user visual feedback for the chosen
point — a 37.7749 / -122.4194 is just two
numbers, and the user has no way to know if
they typed "the office" or "the office
across the street" without leaving the app
and opening a real map.

The v1.0 sign-off explicitly listed
`LocationPicker` map widget as a v1.1
candidate
(`docs/v_model/v1_0_release_baseline.md`),
naming `google_maps_flutter` and
`flutter_map` as the two implementation
options. `google_maps_flutter` would add a
Google Play Services dependency + API key +
~5 MB of native code. `flutter_map` is
pure Dart on top of OSM tiles.

Either choice triggers a v0.1 permission
baseline cross-check per `AGENTS.md` /
`CLAUDE.md`: OSM tile fetches require
`INTERNET`, which is **deliberately
omitted** from the v0.1 baseline
(no analytics, no remote logs, no tile
fetches — see the constraints section of
`v1_0_release_baseline.md`). Adding
`INTERNET` is a privacy-blast-radius
change for the whole app: any code path
could in principle make a network call,
which contradicts the "no remote logs"
user contract.

### Decision.

Ship an **offline `CustomPaint`-based map
preview** — `LocationMapPreview` in
`lib/widgets/location_map_preview.dart`.

- Pure `dart:ui` painting. No
  `flutter_map`, no `latlong2`, no
  `package:http`, no `INTERNET`
  permission.
- Equirectangular projection of a fixed
  world window (lat ∈ [-85°, 85°],
  lon ∈ [-180°, 180°]) onto a 360×100
  canvas (default height; configurable).
- 5×5 stylised grid on the background;
  a filled pin (radius 6 px) at the
  projected (lat, lon); a translucent
  ring (radius scaled by 1° lat ≈
  111 320 m) for the geofence.
- One callback: `onLatLonChanged(lat,
  lon)` invoked on `onTapDown` and
  `onPanUpdate`. Coordinates clamped to
  ±90 / ±180 before being reported.
- Three pure helpers
  (`projectLatLonForTest`,
  `unprojectLatLonForTest`,
  `radiusMetresToPxForTest`) exposed for
  unit tests; the widget itself uses
  the same logic internally.

The picker mounts the preview between
the lat/lon `TextFormField` row and the
"Use current location" button. The
`TextFormField`s gain an `onChanged: (_)
=> setState(() {})` so the pin follows
typed coordinates in real time, and the
slider's existing `setState` already
re-renders the ring. Tapping the preview
writes back to `_latCtrl` / `_lonCtrl`
via `toStringAsFixed(6)` and triggers
`setState` so the form's `form.validate`
runs.

The widget's public API
(`onLatLonChanged`) is shaped so a v1.2
candidate can swap the `CustomPaint`
body for `flutter_map`'s `FlutterMap`
without changing the call site.

### Alternatives considered.

- **`flutter_map` + OpenStreetMap
  + `INTERNET` permission.** Matches the
  v1.0 sign-off wording, gives a real
  world map. Rejected because it requires
  the `INTERNET` permission baseline
  cross-check per `CLAUDE.md`; the
  blast radius is the whole app, not just
  the picker. `INTERNET` is a v0.1
  baseline change; we don't make it
  incidentally.
- **`google_maps_flutter`.** Adds
  ~5 MB of native code + a Play Services
  key + a billing account. Also requires
  `INTERNET`. Rejected for the same reason
  as `flutter_map`, plus the APK bloat.
- **Hide the "Use current location"
  button behind a "Show on map" toggle
  that opens the system Maps app.**
  Rejected because it pushes the user out
  of the app for what should be a 2-second
  visual confirmation. The picker is
  modal; routing the user out is jarring.
- **Do nothing (keep v1.0's behaviour).**
  Rejected because the v0.6 reliability
  feedback explicitly flagged "no visual
  feedback for the chosen location" as a
  high-frequency complaint.

### Lessons.

- **The no-network baseline is a
  *feature*, not a *constraint* to
  work around.** Forcing an offline
  implementation pushed the design toward
  a pure-paint widget that is faster,
  lighter (no network on the cold path),
  and easier to test. A v1.2 swap to
  `flutter_map` is still on the table —
  but the offline preview is the right
  default for v1.1.
- **`HitTestBehavior.opaque` is the
  default for `GestureDetector`-wrapped
  `CustomPaint`.** Without it, taps fall
  through the (otherwise empty)
  `SizedBox.expand` child to whatever is
  behind the preview.
- **Pre-seed `SharedPreferences` via
  `setMockInitialValues` + `resetForTesting`
  + `init()`** is the established pattern
  for widget tests that read service state
  on mount; the picker's preview follows
  the same shape as the routine apply
  screen's edit-mode read.
- **`tester.ensureVisible` lands the
  target at the bottom edge of the
  bottom sheet** where the scroll-gesture
  detector overlaps it; an extra `drag(
  find.byType(SingleChildScrollView),
  Offset(0, -80))` after a radio-tap
  re-render clears the overlap so the
  Save button is fully tappable.

## ADR-029: Per-automation reliability badge (v1.1f)

**Status:** Accepted (2026-06-21). Lands in v1.1f.

### Context

v1.0 ships an app-wide `Reliability` enum
(`lib/reminders/alarm_scheduler.dart`) that answers the
question "can the system wake us up at the right time?".
The answer is driven by exact-alarm grant + Doze + battery
optimisation. It is rendered by `ReliabilityBanner`
(`lib/widgets/reliability_banner.dart`) on the home screen
and in Settings.

That enum is per-device, not per-automation. A user can
have an `optimal` global state and still have one routine
that will never fire because `ACCESS_COARSE_LOCATION` was
revoked (the geofence trigger), or `READ_CALENDAR` was
revoked (the calendar trigger), or `ACTION_IGNORE_BATTERY_OPTIMIZATION`
was unset for a device-state trigger that needs a
foreground service.

In v1.0 the user has no in-app way to see "this specific
routine has a permission problem". The settings page has
the global permission tile, but it does not link from a
routine row. The routine list rows render only an icon and
a summary; a routine that will never fire is visually
indistinguishable from one that will.

v1.0 sign-off (`docs/v_model/v1_0_release_baseline.md`)
explicitly listed "per-automation reliability badges" as
a v1.1 follow-up.

### Decision

Add a new `AutomationReliability` enum
(`lib/routines/automation_reliability.dart`) with three
states — `optimal` / `degraded` / `unknown` — that mirrors
the v1.0 `Reliability` semantics on purpose so the
existing banner and the new badge share visual language.

The enum is populated by a pure function
`automationReliability(Automation automation, {required
Map<PermissionKind, PermissionResult?> statuses})`. The
function is exhaustive over the sealed `Trigger`
hierarchy via `_requiredPermissionForTrigger` —
`TriggerLocation*` maps to `PermissionKind.location`,
`TriggerCalendarEvent*` to `PermissionKind.calendar`,
`TriggerDeviceState*` / `TriggerCallIncoming*` /
`TriggerTimeOfDay` return `null` (no runtime gate). The
switch is the canonical reference for "which triggers gate
a permission"; adding a new leaf without updating it is a
compile-time error.

The new badge widget
(`lib/widgets/automation_reliability_badge.dart`) lives in
`lib/widgets/`, not in `lib/routines/`. Rationale:
`lib/routines/` is the executor / model layer
(`.claude/rules/lib-routines.md`: Flutter-free). The badge
is a UI surface; it imports `package:flutter/material.dart`
and reads `Theme.of(context).colorScheme.*`. Putting it in
`lib/widgets/` mirrors the `ReliabilityBanner` convention.

The badge wraps its body in a `ValueListenableBuilder`
over `PermissionService.instance.statuses`. The map is
already a `ValueNotifier<Map<PermissionKind, PermissionResult?>>`
that fires on every permission probe, so the badge
reactively re-renders after the user grants or revokes a
permission without the parent screen having to call
`setState`.

For `optimal` the badge renders `SizedBox.shrink` —
matching the `ReliabilityBanner` convention of hiding
itself when the system is in a good state. The common case
(most routines are `optimal`) must not clutter the
trailing slot.

For `degraded` / `unknown` the badge renders a 40×40 dp
`IconButton` (touch target). The icon + colour tokens
match `ReliabilityBanner`: `Icons.warning_amber_rounded`
in `colorScheme.onErrorContainer` for `degraded`, a fresh
`Icons.info_outline` in `colorScheme.onSecondaryContainer`
for `unknown` (the existing banner does not render
`unknown` — the enum defines it but the widget never
visits that case, so a new colour token is needed here).

The badge accepts an optional `onTap` callback. The three
add screens (`add_habit` / `add_person` / `add_event`)
do not pass one at v1.1f; a follow-up PR will pass one
that opens an `AlertDialog` with the rationale + a deep
link to Settings → Permissions for that specific kind.
The badge is non-interactive when `onTap` is null (the
`IconButton.onPressed` is null).

The trailing slot of the three `_RoutineRow` widgets is
restructured from a single `IconButton` into a `Row(
mainAxisSize: MainAxisSize.min, children: [badge,
remove])`. The `ValueKey` of the remove button is
preserved across all three screens so existing widget tests
that target `find.byKey('add_habit.remove_routine')`
continue to find it.

### Alternatives considered

- **Reuse the existing `Reliability` enum directly.**
  Rejected: `lib/routines/` → `lib/reminders/` would be a
  new cross-cutting dependency for a 3-line enum, and the
  semantics are genuinely different (per-automation vs.
  per-device). Two parallel enums are clearer.
- **Per-trigger enum values (LocationReliability,
  CalendarReliability, ...).** Rejected: most triggers
  share the same three states; collapsing them into one
  enum keeps the badge's switch exhaustive and tiny.
- **Skip the badge; rely on the global
  `ReliabilityBanner` + the existing settings tile.**
  Rejected: the user cannot tell from a routine row which
  permission is missing. The settings tile is global; the
  badge is per-row. Both are needed.
- **Build the badge as a coloured `Container` instead of
  an `IconButton`.** Rejected: the 40×40 dp touch target
  requirement (`.claude/rules/lib-screens.md`: ≥ 48dp
  recommended, 40dp minimum for trailing slots) is easier
  to hit with an `IconButton`'s built-in
  `BoxConstraints(minWidth: 40, minHeight: 40)`. A
  `Container` would need a manual `InkWell` wrapper.
- **Render the badge as a `Tooltip` instead of a
  Semantics label + `IconButton.tooltip`.** Rejected: the
  badge already renders an icon, the tooltip is the
  established pattern in the codebase (mirrors
  `ReliabilityBanner`).

### Lessons

- **A `ValueListenableBuilder` over the singleton's
  `ValueNotifier` is enough for reactivity** — no need
  for a `ChangeNotifier`, `Provider`, or a `Stream`.
  `PermissionService.statuses` already fires on every
  probe; the badge just subscribes.
- **The exhaustive sealed-hierarchy switch is the
  contract.** Both the impl and the test pin "which
  triggers gate a permission" via a single switch
  statement. If a future contributor adds a new
  `TriggerCallIncoming` leaf without updating
  `_requiredPermissionForTrigger`, the build breaks — a
  feature, not a bug.
- **`IconButton(onPressed: null)` renders the icon as
  disabled-but-visible.** This is the right behaviour for
  the v1.1f "non-interactive badge" mode (the parent
  screen hasn't decided whether to wire the dialog yet).
  A `Container` or a `GestureDetector(onTap: null)` would
  hide the icon entirely.
- **Parallel enums that share semantics are OK.** The
  `Reliability` (v1.0) and `AutomationReliability` (v1.1f)
  enums both have `optimal` / `degraded` / `unknown`. They
  live in different files, have different constructors,
  and answer different questions, but the visual surface
  (`ReliabilityBanner` + `AutomationReliabilityBadge`)
  treats them the same. This is a deliberate naming choice
  to make a future merge (if the global enum ever
  disappears) cheap.

## ADR-030 — v1.1g: PACKAGE_USAGE_STATS — special-access probe, not a runtime-prompt permission

### Context

v1.2 will add a `TriggerForegroundApp` ("do X when I open app Y")
routine. The signal source is the foreground-app state from
Android's `UsageStatsManager` API, which is gated behind the
`PACKAGE_USAGE_STATS` permission — a **special-access**
permission that:

1. Is NOT in the runtime-prompt flow. Android shows no popup;
   the user MUST navigate to Settings → Special access →
   Usage access and toggle do it on manually.
2. Has no API in `permission_handler` (the Dart plugin does
   not expose it because it cannot request it programmatically).
3. Is queried at the OS level via `AppOpsManager.unsafeCheckOpNoThrow`
   (`OPSTR_GET_USAGE_STATS`) rather than the runtime
   `checkSelfPermission` path.
4. Is toggled by the user, not by the app — the app can only
   deep-link to the Settings page and re-probe on resume.

v1.1g ships the **plumbing** for this permission now so v1.2
only has to add the `TriggerForegroundApp` leaf (no permission
work, no manifest change, no `PermissionSheet` extension).
The `PermissionKind.usageStats` enum entry, the
`UsageStatsService` singleton, the Kotlin method-channel
handlers, the manifest declaration, the Settings tile, and
the rationale copy all ship together.

The PermissionSheet must handle this kind even though there is
no system dialog to show. The sheet's "Allow" CTA becomes a
deep-link to `Settings.ACTION_USAGE_ACCESS_SETTINGS`; the
result depends on whether the user came back having toggled
the permission.

### Decision

1. **New sealed-entry: `PermissionKind.usageStats`.** Added
   to `lib/services/permission_service.dart`'s `PermissionKind`
   enum (alongside the existing `notifications`, `contacts`,
   `exactAlarm`, `batteryOptimization`, `location`, `calendar`,
   `backupFolder`).

2. **New singleton: `UsageStatsService`
   (`lib/services/usage_stats_service.dart`).** Standard
   `_ready` Completer gate; production source is
   `_MethodChannelUsageStatsSource` (talks to `doit/device_state`);
   test source is `ScriptedUsageStatsSource` (hand-driven
   `setGranted()` / `setOpenSettingsResult()`). Two public
   methods: `isGranted()` (one-shot probe) and `openSettings()`
   (deep-link to Settings → Special access → Usage access).
   A `@visibleForTesting` factory `debugInstance({required
   UsageStatsSource source})` lets the test file construct
   isolated instances.

3. **`_ready` starts completed.** Unlike the other services in
   `lib/services/`, `UsageStatsService.init()` has no async
   init work — the platform side is a stateless probe + a
   deep-link. The `_ready` Completer is therefore constructed
   with `..complete()` so production callers (e.g.,
   `PermissionService._refreshUsageStatsAfterInit`) do not
   need to await `init()` first. `resetForTesting` is the
   only path that re-creates the gate.

4. **Probe is fire-and-forget from `PermissionService.init()`.**
   `init()` calls `unawaited(_refreshUsageStatsAfterInit())`
   instead of `await UsageStatsService.instance.isGranted()`.
   This is mandatory because the platform-channel call uses
   a real Future that does NOT advance in a widget-test's
   fake-async zone — a test like
   `calendar_picker_test.dart` calls `await PermissionService.instance.init()`
   at the top of a `testWidgets` block, and an `await
   _channel.invokeMethod(...)` inside `init()` hangs the test
   (the fake-async clock does not process real Futures).
   `init()` MUST complete in fake-async without touching the
   real-async platform channel. The post-init probe runs on
   the real-async microtask queue and merges into `statuses`
   when it resolves. `refreshUsageStats()` (the public
   API used by `Settings._PermissionTile._reProbe` and the
   future `AppLifecycleState.resumed` handler) is the same
   probe but synchronous-style awaited.

5. **Manifest entry: `PACKAGE_USAGE_STATS` with
   `tools:ignore="ProtectedPermissions"`.** The permission is
   opt-in only — the user is never blocked from using do it
   for declining. The `tools:ignore` suppresses the
   manifest-merger lint that flags "signature|privileged"
   permissions. Cross-checked against the v0.1 permission
   baseline in `docs/v_model/architecture_options.md`
   `Permission Baseline`.

6. **Rationale copy in `PermissionSheet._meta`:** "Allows
   do it to fire 'do X when I open app Y' routines (coming
   in v1.2). Android does not show a popup for this — you
   will need to toggle do it on in the next screen." Icon
   `Icons.query_stats_outlined`, title "Usage access".

7. **PermissionSheet switches extended.** The `_onAllow`
   switch routes `usageStats` to `PermissionService.requestUsageStats()`
   (which deep-links to Settings → Usage access via
   `UsageStatsService.openSettings()`). The `_onOpenSettings`
   switch routes `usageStats` to `requestUsageStats()` +
   `refreshUsageStats()` (the deep-link + the re-probe).

8. **Settings → Permissions tile re-probes differently.**
   `Settings._PermissionTile._reProbe` for `usageStats` calls
   `PermissionService.refreshUsageStats()` (the probe) instead
   of `requestUsageStats()` (the deep-link), because the
   "Allow" CTA was a deep-link and the user has already
   returned from Settings; we want to reflect the new
   toggle state, not re-prompt.

9. **Kotlin side (`DeviceStateChannel.kt`):** two new method
   handlers — `isUsageStatsGranted` (calls
   `AppOpsManager.unsafeCheckOpNoThrow(OPSTR_GET_USAGE_STATS,
   Process.myUid(), packageName)`) and
   `openUsageAccessSettings` (launches an intent with
   `Settings.ACTION_USAGE_ACCESS_SETTINGS` and
   `FLAG_ACTIVITY_NEW_TASK`).

### Alternatives considered

- **Use `permission_handler` for usage stats.** Rejected —
  the plugin does not expose this permission because Android
  does not show a runtime prompt for it. The plugin would
  always report "denied" without a way to request.
- **Skip the deep-link and just tell the user where to
  toggle.** Rejected — the Settings → Permissions tile would
  show "denied" with no actionable affordance, leaving the
  user to discover Settings → Special access → Usage access
  on their own. The deep-link + re-probe is the standard
  pattern for special-access permissions (mirrors the
  battery-optimization flow in v0.6).
- **Make `UsageStatsService` a probe-only service (drop
  `openSettings`).** Rejected — the deep-link is part of the
  service's contract because the rationale UX must not
  import the platform-channel seam directly (separation of
  concerns: the widget layer imports only `permission_sheet.dart`
  which imports `permission_service.dart` which imports
  `usage_stats_service.dart` which talks to the platform).
- **Synchronously await the probe in `init()`.** Rejected —
  the v1.1g diagnostic revealed that `MethodChannel.invokeMethod`
  in a widget test's fake-async zone hangs because real
  Futures do not advance without `tester.runAsync`. The
  fire-and-forget probe resolves this without sacrificing
  the eventual consistency of the badge tile.
- **Move the probe to `app.dart`'s `initState` instead of
  `PermissionService.init()`.** Rejected — the probe belongs
  in `PermissionService` because the badge widget reads
  from `PermissionService.statuses`. Splitting the probe
  path would require a second `ValueNotifier` and two
  listeners in the badge.
- **Defer the permission work to v1.2 alongside the
  `TriggerForegroundApp` leaf.** Rejected — the manifest
  entry, the `PermissionKind` enum, and the `PermissionSheet`
  extension are all API-surface changes. Shipping them in
  v1.2 means a separate PR with a "permission baseline
  bump" footnote in `architecture_options.md`. Shipping
  them in v1.1g keeps the v1.2 PR focused on the trigger
  leaf + the foreground-app probe in `DeviceStateService`.

### Lessons

- **Permission probes that touch the platform channel must
  not block `PermissionService.init()`.** The fire-and-forget
  pattern via `unawaited(_refreshUsageStatsAfterInit())` is
  the right shape. Any future permission kind that requires
  a platform-channel probe (e.g., the planned
  `PermissionKind.callScreening` for `RoleManager`) must
  follow the same pattern.
- **`_ready` start state is a per-service decision.** Some
  services genuinely have async init (e.g., `CalendarService`
  registers a `ContentObserver` on init) and need an
  uncompleted `_ready` gate. Others (like `UsageStatsService`)
  have no init work and should start completed to avoid
  "await init() that nobody calls" bugs in production.
- **The first widget-test hang in a new permission's probe
  is always the fake-async / real-async divide.** The
  `permission_handler` calls in `PermissionService.init()`
  work in `testWidgets` because `permission_handler` uses
  Pigeon which has both sync and async paths; a raw
  `MethodChannel.invokeMethod` does not. Document this in
  the inline comment at the probe site so the next person
  does not undo the `unawaited` workaround.

## ADR-031 — v1.1h: i18n scaffolding — ARB catalogs + `flutter_localizations` + `localizedApp` test helper (SYS-087)

### Context

Every user-facing string in `lib/main.dart`, `lib/screens/home.dart`,
`lib/screens/settings.dart`, and `lib/screens/onboarding.dart` is a
hard-coded English literal (`'Notifications'`, `'Skip'`,
`'Optimal — exact alarm granted.'`, `'Send a test reminder'`, etc.).
A future translator has no clean extraction surface — they would
have to grep for `Text('...')` and `SnackBar(content: Text(...))`
across the screens and assemble the catalog by hand, then patch
every literal in parallel.

The v1.0 sign-off explicitly deferred i18n ("no localized strings,
English-only copy"). v1.1h ships the scaffolding so v1.2+ can land
a translation PR without touching any `lib/screens/` file: the
translator edits `app_es.arb`, runs `flutter gen-l10n`, and the
visible copy flips at runtime via `MaterialApp.locale`.

The constraint set:

1. **No code changes outside the i18n surface.** A new locale
   must be addable by editing one ARB file and re-running
   `flutter gen-l10n` — no Dart edits, no test edits.
2. **Existing widget tests must not crash.** Production code calls
   `AppLocalizations.of(context)!` (with bang); a test that mounts
   `HomeScreen` in a plain `MaterialApp` without the localizations
   delegate crashes on the bang. The fix is a shared
   `localizedApp(...)` helper that all screen tests use instead of
   hand-rolling `MaterialApp`.
3. **No new dependencies that pull transitive native code.** The
   localization stack must be pure-Flutter — no `flutter_localizations`
   generator switches, no third-party ARB tools.
4. **`flutter analyze` and `flutter test` stay clean** without
   relaxing any threshold.

### Decision

1. **ARB catalogs in `lib/l10n/`.** Two files:
   `app_en.arb` is the source-of-truth (`@@locale: en` +
   ~60 keys) and `app_es.arb` is the Spanish translation
   (`@@locale: es`). Keys are grouped by surface:
   `appTitle`, `homeAppBarTitle`, `homeSelectionAppBarTitle`
   (ICU plural: `{count, plural, =0{Select dos} =1{1 do selected}
   other{{count} dos selected}}`), `homeSnackbarMarkedDone`,
   `homeSnackbarMarkedCount` (placeholder), `homeEmptyTitle`,
   `homeRetryButton`, `homeAddSheetNewDo/Person/FromTemplate`;
   `settingsAppBarTitle`, `settingsSectionAppearance/Anchor/
   Permissions/Reliability/DeviceState/Backup/About`,
   `settingsThemeDark/Light/System`, `settingsAnchorManual/
   FirstUnlock/Either`, `settingsReminderReliabilityTitle/Optimal/
   Degraded/Unknown`, `settingsTestReminderTitle/Subtitle/
   Snackbar`, `settingsRestoreTitle/Subtitle`,
   `settingsAboutAppVersion` (placeholder),
   `settingsLicensesTitle/Subtitle`;
   `permissionNotificationsTitle/ContactsTitle/ExactAlarmTitle/
   LocationTitle/CalendarTitle/UsageStatsTitle`,
   `permissionStatusGranted/Denied/Blocked/NotAsked`,
   `permissionSettingsButton`,
   `permissionBackupFolderTitle/NotPicked/RePick/Set/Error`
   (placeholders),
   `permissionCallScreeningTitle/Checking/Held/NotHeld/Change/Grant`;
   `onboardingAppBarTitle/LastStepAppBarTitle`,
   `onboardingStep{N}Title/Body/Cta` for N ∈ {0..4},
   `onboardingSkipCta`,
   `onboardingOpenAndroidSettingsCta`.

2. **`l10n.yaml` at the repo root.** Six keys:
   `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`,
   `output-localization-file: app_localizations.dart`,
   `output-class: AppLocalizations`,
   `output-dir: lib/l10n/gen`, `nullable-getter: false`. The
   `synthetic-package: false` key was removed (Flutter 3.44
   deprecated the option; leaving it in produces a warning).
   `nullable-getter: false` means `AppLocalizations.of(context)`
   throws on a missing delegate — production code can therefore
   use `!` without runtime surprises; the test helper installs
   the delegate so tests never hit the throw.

3. **`pubspec.yaml` adds `flutter_localizations` + `intl: any`.**
   `flutter_localizations: { sdk: flutter }` brings in the
   standard `GlobalMaterialLocalizations` /
   `GlobalWidgetsLocalizations` / `GlobalCupertinoLocalizations`
   delegates the `MaterialApp` needs to render a non-English
   locale (date / time / directionality). `intl: any` pins to
   whatever the Flutter SDK ships so we do not pull a major
   `intl` upgrade by accident. `flutter: { generate: true }`
   opts the project into the codegen pipeline that
   `flutter pub get` / `flutter gen-l10n` drives.

4. **Generated code in `lib/l10n/gen/`.** Three files produced
   by `flutter gen-l10n`: `app_localizations.dart` (the
   `AppLocalizations` class with `supportedLocales`,
   `localizationsDelegates`, and one getter per ARB key),
   `app_localizations_en.dart`, `app_localizations_es.dart`.
   Generated files are NOT hand-edited — they are a build
   artifact. The directory is `.gitignore`-clean by Flutter's
   convention; the `.gitignore` already excludes
   `**/gen/**/app_localizations*.dart`.

5. **Three screens read every user-facing string from
   `AppLocalizations.of(context)`.** `home.dart`,
   `settings.dart`, `onboarding.dart` no longer contain a
   hard-coded English literal that the user sees. Pattern:

   ```dart
   final l = AppLocalizations.of(context);
   // ...
   appBar: AppBar(title: Text(l.homeAppBarTitle)),
   ```

   The onboarding step list (formerly `static const
   _steps = <_OnboardingStep>[...]`) becomes
   `static List<_OnboardingStep> _buildSteps(AppLocalizations l)
   => [...]` because each entry now reads its title/body/cta from
   the ARB catalog. `_kStepCount = 5` stays `const` so the
   `_handleSkip` "Skip to last step" logic stays compile-time.

6. **`MaterialApp` wires delegates + supportedLocales.**
   `lib/main.dart`'s `MaterialApp` now passes
   `localizationsDelegates: AppLocalizations.localizationsDelegates`
   and `supportedLocales: AppLocalizations.supportedLocales`. The
   locale is NOT hard-coded — Flutter picks the best match from
   `supportedLocales`, falling back to the first entry (English)
   for an unsupported locale like `fr-FR`.

7. **Test helper: `test/support/localized_app.dart`.** A 30-line
   `localizedApp({required Widget home, ThemeData? theme, ...})`
   function that builds a `MaterialApp` with the generated
   delegates pre-installed. All 10 screen-test files
   (`test/screens/home_test.dart`, `settings_test.dart`,
   `settings_permissions_test.dart`, `settings_licenses_test.dart`,
   `settings_test_reminder_test.dart`,
   `settings_call_screening_tile_test.dart`,
   `onboarding_test.dart`, `onboarding_permission_wiring_test.dart`,
   `onboarding_call_screening_step_test.dart`,
   `test/integration/fresh_install_test.dart`) route through it.

8. **Test coverage in `test/l10n/app_localizations_test.dart`.**
   11 tests across two groups:
   - **Structural (5 tests):** ARB file presence, `@@locale`
     header on each, key-set parity between `app_en.arb` and
     `app_es.arb` (asserts the translator did not add or drop a
     key), ICU plural placeholder type metadata on
     `homeSelectionAppBarTitle` / `homeSnackbarMarkedCount` (the
     plural-type metadata is the field the codegen reads).
   - **Widget (4 tests):** Spanish resolution (mounts a tiny
     widget with `locale: const Locale('es')` and asserts the
     translated AppBar title), English resolution, unsupported-
     locale fallback (`const Locale('fr')` lands on English —
     the first entry in `supportedLocales`), ICU plural branches
     in Spanish (`count: 0`, `count: 1`, `count: 2`).
   - **Class API (2 tests):**
     `AppLocalizations.supportedLocales` contains exactly `en`
     and `es`; the delegate list contains
     `DefaultMaterialLocalizations.delegate` and
     `DefaultWidgetsLocalizations.delegate` (the runtime types,
     not the static `.delegate` instances — the latter would
     crash on a missing-delegate test path).

### Consequences

- **Adding a new locale is one file edit.** Drop
  `app_<lang>.arb` in `lib/l10n/`, run `flutter gen-l10n`,
  the generated `AppLocalizations` picks it up, and
  `supportedLocales` grows. No `lib/screens/` change.
- **New screen tests MUST route through `localizedApp`.** The
  production code's `!` bang will crash any test that mounts
  a screen directly. The helper is the single source of truth
  for test-side delegate wiring; an `appBar: AppBar(title:
  Text(l.foo))` regression in production code is caught the
  first time a screen test mounts without `localizedApp`.
- **`flutter pub get` is now a code step.** Removing
  `flutter: { generate: true }` from `pubspec.yaml` would break
  the build — the import in `main.dart`
  (`import 'package:doit/l10n/gen/app_localizations.dart';`)
  resolves only when codegen has produced the file. A fresh
  clone needs `flutter pub get` before `flutter analyze`
  returns clean.
- **No permission baseline change.** No new permission,
  no manifest entry, no `INTERNET` requirement.
  `AppLocalizations` is generated from in-tree ARB files; the
  Flutter SDK does not fetch anything.
- **English copy is unchanged for v1.1h.** The new
  `app_en.arb` keys match the prior hard-coded literals
  verbatim (character-for-character, including em-dashes in
  "Optimal — exact alarm granted."). Users on English locales
  see no copy change. A user-facing copy audit is a separate
  concern.
- **Spanish coverage is partial.** `app_es.arb` translates the
  ~60 extracted keys as a smoke test of the codegen + delegate
  pipeline; it is NOT a professional translation. The keys
  exist so a translator can iterate on them — they are not the
  final v1.1 release copy. A real translation pass (with a
  native Spanish speaker) is a v1.2 follow-up.

### Alternatives considered

- **`easy_localization` package.** Lower ceremony (one import,
  a `tr(context, ...)` call), but adds a transitive dependency,
  its own runtime JSON loading, and a non-standard test seam.
  The Flutter-team-blessed `flutter_localizations` + ARB pipeline
  has no third-party surface area, so the trade is
  "more boilerplate" vs "less indirection". The boilerplate is
  one `l10n.yaml` file and one `flutter gen-l10n` run — not
  enough to justify a third-party dep.
- **Code-gen keys (one Dart constant per key) instead of ARB.**
  Faster compile, but the translator has to read Dart instead
  of JSON. The ARB format is the Flutter convention; a future
  contributor will recognise it immediately.
- **Ship English-only and translate later.** The argument is
  that v1.0 was English-only and v1.1 is too. But the
  scaffold is the highest-cost part of any future translation
  PR (the call-site edits); the ARB extraction is cheap now
  and prevents `Text('Notifications')` from accumulating in
  new screens between now and v1.2.
- **Translate to all 24 supported locales.** Way out of scope
  for one PR; the spec is one source-of-truth locale (English)
  + one smoke-test locale (Spanish) to prove the pipeline. A
  real translator picks the locales.

## ADR-032 — v1.1i: Custom launcher icon + splash — hand-authored adaptive-icon vectors over `flutter_launcher_icons` (SYS-088)

### Context

`do it` ships at v1.0 with the default Flutter launcher icon
(blue "F" on white) and a flat-color splash (white on light,
`?android:colorBackground` on dark). The default icon does
not match the brand seed (`#FF6750A4`, "muted purple —
calm, slightly stubborn"; see `lib/theme/app_theme.dart:15`)
and gives users no visual anchor in the launcher grid. The
default splash flashes white for ~100ms before Flutter
draws, which is jarring on the brand-purple theme.

Three V-Model docs explicitly defer this work to v1.1:

- `docs/v_model/plan.md:277-279` (Milestone 8 / v1.1 scope)
- `docs/v_model/v1_0_release_baseline.md:227-228`
  (out-of-scope-for-v1.0)
- `docs/v_model/v0_5_release_baseline.md:231-234` (origin
  of the deferral)

Additionally `docs/v_model/architecture_options.md:191-192`
calls out a notification-icon gap
(`drawable/ic_streak_notification.xml`, "Custom monochrome
white-on-transparent for the status bar; full-color for the
app icon") that has never landed on disk. v1.1i closes that
gap in the same PR.

The user picked the visual direction in plan mode: lowercase
'd' + small filled circle (the check dot), white foreground
on the brand purple background. The 'd' fills ~66% of the
108dp adaptive-icon safe zone; the dot sits at the
bottom-right outside the 'd' bowl.

### Decision

Hand-author three vector drawables for the launcher icon
(in `android/app/src/main/res/drawable/`):

1. **`ic_launcher_background.xml`** — solid brand purple
   `#FF6750A4`. A single `<path>` rectangle, 108dp × 108dp
   viewport.
2. **`ic_launcher_foreground.xml`** — the white 'd' + dot
   glyph. A single `<path>` with four subpaths (the stem
   rectangle, the outer bowl circle, the inner bowl circle,
   the dot circle) using `fillType="evenOdd"`. Coordinates:
   stem x ∈ [23, 29], y ∈ [24, 84]; bowl center (54, 54),
   outer R = 25, inner R = 16; dot center (80, 80), R = 4.
   All content fits within the 66dp safe zone.
3. **`ic_launcher_monochrome.xml`** — same glyph as the
   foreground, painted pure white. Android 13+ themed icons
   recolor this layer against the user's wallpaper-derived
   tint and drop the background layer; the foreground glyph
   stays visible.

Then the adaptive-icon entry point at
`mipmap-anydpi-v26/ic_launcher.xml`:

```xml
<adaptive-icon xmlns:android="...">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
```

`AndroidManifest.xml:66`'s
`android:icon="@mipmap/ic_launcher"` reference is unchanged;
Android resolves that to the adaptive-icon XML on API 26+
and to the legacy `mipmap-*/ic_launcher.png` files on API
21..25. The five legacy PNGs (the Flutter default 48..192px
fallbacks) are NOT deleted; they continue to ship as the
pre-26 fallback.

Both `drawable/launch_background.xml` and
`drawable-v21/launch_background.xml` are rewritten as a
`<layer-list>`:

```xml
<layer-list xmlns:android="...">
    <item android:drawable="@color/launch_background" />
    <item
        android:drawable="@drawable/ic_launcher_foreground"
        android:gravity="center"
        android:width="96dp"
        android:height="96dp" />
</layer-list>
```

The brand purple `#FF6750A4` is extracted into a named
color resource `@color/launch_background` in
`values/colors.xml` because AAPT2 rejects inline color
values in `<item android:drawable>` inside `drawable-v21/`
resources (only `@drawable/...`, `@color/...`, and `@android:color/...`
are accepted as drawable references); a named resource
works on every API level. The `?android:colorBackground`
reference in the API 21+ variant is dropped — keeping the
splash on-brand beats flipping it to the theme's dark
background.

The pre-existing
`android/app/src/main/res/drawable/ic_streak_notification.xml`
resource gap (referenced by `architecture_options.md:191-192`
and by the Kotlin-side notification-channel init for the
`streak.reminders` channel) is closed: a monochrome
white-on-transparent copy of the foreground glyph with the
check dot dropped (the dot is unreadable at 24dp).

`pubspec.yaml` and `lib/build_info.dart` move from
`1.0.0+7` to `1.1.0+8`. The mirror-pin tests in
`test/release_signing_test.dart` (`pubspec.yaml` +
`lib/build_info.dart` agreement) update in lockstep.

### Consequences

- **One vector per layer.** Android's adaptive-icon
  infrastructure scales vectors natively; the launcher
  renders crisply at every density.
- **Per-density regeneration deferred to v1.2.** The five
  legacy `mipmap-*/ic_launcher.png` files stay as the
  Flutter default; a v1.2 follow-up can regenerate them
  from the master vector if a pre-26 device needs on-brand
  visuals.
- **AOSP launcher mask applied at draw time.** Circle
  (Pixel launcher), squircle (Samsung), teardrop (Xiaomi)
  — the brand purple + 'd' + dot composition clips
  uniformly against each launcher shape.
- **Themed icons (Android 13+) use the monochrome layer.**
  Users with themed icons enabled see the 'd' + dot
  silhouette tinted against their wallpaper palette; the
  brand purple is dropped.
- **The brand seed lives in three places.** `lib/theme/app_theme.dart:15`
  defines `0xFF6750A4` as the `ColorScheme.fromSeed` seed,
  `values/colors.xml` defines `<color name="launch_background">#FF6750A4</color>`,
  and `drawable/ic_launcher_background.xml` + the
  `launch_background` color resource hardcode `#FF6750A4`
  (vector drawables do not consume color resources at draw
  time — the fillColor is a literal). A v1.2 follow-up could
  promote the seed into a build-config constant so the
  launcher + theme + colors.xml stay in sync. Not blocking
  for v1.1i.
- **No new permissions.** The icon + splash changes are
  pure Android resource edits; no manifest change beyond
  the existing `@mipmap/ic_launcher` reference.
- **No `flutter_launcher_icons` package.** Direct
  hand-authored vector XMLs are simpler and produce
  crisper output at every density (the package would
  regenerate the vectors into PNGs anyway).
- **No `flutter_native_splash` package.** The Android-side
  `LaunchTheme` + `<layer-list>` is the lower-ceremony path
  (one layer-list change vs a `flutter_native_splash:` block
  in pubspec + a build_runner pass + a generated
  `splash.dart`). The trade is a 5-minute Flutter-vs-Android
  divergence on splash timing (the Android splash is
  ~100ms faster than the Flutter-managed one).

### Alternatives considered

- **`flutter_launcher_icons` package.** Auto-generates the
  per-density PNGs from a master asset. The package adds
  build-step ceremony (a `flutter_launcher_icons:` block in
  `pubspec.yaml`, a `pubspec.lock` entry, a `dart run
  flutter_launcher_icons` step on every asset change). For
  a developer/designer hybrid where the developer is also
  the designer, hand-authored XMLs are faster and produce
  sharper output (Android scales vectors natively; the
  package regenerates the vectors into PNGs anyway, with a
  quality loss at the edges).
- **`flutter_native_splash` package.** Generates the
  per-platform splash drawables from a single
  `flutter_native_splash:` block in `pubspec.yaml`. Same
  build-step ceremony argument applies; plus the Android
  side already has the `LaunchTheme` + `<layer-list>`
  mechanism for this, so adding a package is
  duplicative-of-infrastructure.
- **Hand-rasterized per-density PNGs.** Five PNGs at
  mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi (48/72/96/144/192px) plus
  the adaptive-icon XML. Strict superset of the v1.1i
  approach (we keep the PNGs as the API 21..25 fallback
  anyway, but we don't regenerate them). The downside is
  the PNGs go out of sync with the master vector on every
  redesign; the upside is a pre-26 device gets on-brand
  visuals today. Deferred to v1.2.
- **The 'two-petal' / 'number 1' design alternatives
  weighed in plan mode.** A "two-petal" mark and a
  "stylized 1" were both rejected as harder to read at
  24dp than the 'd' + dot. The 'd' is the lowercase
  initial of the 'do' brand entity; the dot is the
  completion signal.

