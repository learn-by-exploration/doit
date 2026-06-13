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
third Flutter app to `common_games` or building Streak in native
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
- Auto to a fixed path (e.g., Documents/Streak/) — fragile across
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

**Decision.** Streak model is configurable per habit. Defaults:
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
