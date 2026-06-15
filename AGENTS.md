# AGENTS.md — do it

**Package:** `doit` · **App:** do it · **Android:** `com.doit.package`
**Flutter:** 3.44.0 stable (CI-pinned) · **Dart:** `^3.12.0` · **JVM:** 17

A Flutter app for Android: habits, call/message reminders, anchored
routines, and strong (Alarmy-style) mission enforcement. Personal use,
single user, single device, local-first.

This file is the **portable baseline** for any coding agent. Tool-specific
extensions belong in `CLAUDE.md` (Claude Code) or similar — not here.
Everything below points to a deep-dive in `docs/`.

---

## Setup

```bash
flutter pub get
flutter --disable-analytics && flutter precache --force
flutter doctor -v
cp android/key.properties.example android/key.properties  # gitignored
```

Pin Flutter to the CI version (3.44.0) — mismatches are the #1 source of
"passes locally, fails in CI" bugs. Use FVM or `flutter upgrade`.

## Architecture pointers

Full rules: [docs/v_model/architecture_options.md](docs/v_model/architecture_options.md).
TL;DR:

- **Feature-folder layout.** `lib/habits/`, `lib/people/`, `lib/missions/`,
  `lib/reminders/`, `lib/services/`, `lib/models/`, `lib/screens/`.
- **Model purity.** Files in `lib/models/` and the per-feature model files
  have zero `package:flutter/*` imports. Sibling `*_assets.dart` (where
  present) is the only Flutter-importing exception (it reads `rootBundle`).
- **Service pattern.** Singletons with `Completer<void> _ready`. All public
  reads/writes `await _ready.future` first. `init()` is idempotent.
- **State pattern.** Sealed `*State` classes (`*Scheduled` / `*Firing` /
  `*InMission` / `*Completed` / `*Missed`). No bare enum state.
- **Layer boundaries.** One-directional imports: presentation → application
  → domain → data. No back-edges.

## Documentation discipline

The artifacts in [`docs/v_model/`](docs/v_model/) are the **contract**.
Read them before writing code; treat them as the source of truth; and
update them **in the same PR** whenever a requirement, design, or
verification step changes.

- **Code contradicts a doc → the doc wins.** Fix the code first; if the
  doc is wrong, fix the doc in the same PR. Never ship code that
  contradicts an unrevised doc.
- **A new behavior with no doc change is incomplete.** If you add a
  feature, you must add or update the matching SYS- ID in
  [`requirements.md`](docs/v_model/requirements.md), the row in
  [`traceability_matrix.md`](docs/v_model/traceability_matrix.md), the
  workflow step in [`workflows.md`](docs/v_model/workflows.md), and a
  test in `test/`. The V is incomplete otherwise.
- **An ADR is required for any of:** a new package, a new permission
  in `AndroidManifest.xml`, a new module, a new reliability policy, a
  new state shape, or any reversal of a previous decision. Append to
  [`decision_record.md`](docs/v_model/decision_record.md); do not
  edit history.
- **The package id is `com.doit.package` and the launcher name
  is "do it".** This is committed (v0.5a). Any further rename is
  a v0.6+ decision and requires an ADR.

## The 3-gate

Run, in order, with zero failures. **All three must pass before a task is
done.** Paste the output in the PR / completion message.

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

Do not relax lints, suppress warnings, or skip tests. `--fatal-infos` is
non-negotiable — info-level lints block the build. See
[docs/v_model/notification_reliability.md](docs/v_model/notification_reliability.md)
for CI wiring.

## App invariants — never break these

If a change to habit / mission / reminder logic risks breaking one of these
invariants, the corresponding test must be updated to cover the new
behavior. Failing these silently ships a broken habit app.

| Area | Critical rules |
|------|---------------|
| **Reminder firing** | A scheduled reminder must fire within ±60 seconds of its scheduled time on a non-Doze device, and within ±5 minutes on a Doze device unless the user has whitelisted the app. Cancelling the OS alarm must not silently drop the reminder — the WorkManager fallback must take over. |
| **Schedule survival** | Reminders, anchors, and intervals must survive device reboot, time-zone change, and clock adjustment. Boot receiver + rescheduler is mandatory. |
| **Mission chain** | Strong-mode missions must execute in declared order. Skipping or reordering silently invalidates the proof. |
| **Shake-N mission** | Shake count must be derived from the accelerometer, not from a timer. A user holding the phone still must not advance the counter. |
| **Soft vs. Strong vs. Auto** | A habit's proof mode is immutable per-instance. The model must not let a habit silently flip between modes. |
| **Calling reminder** | Tapping a call reminder MUST open the system dialer with the contact's number pre-filled. The app MUST NOT call `ACTION_CALL` (no `CALL_PHONE` permission). |
| **Backup integrity** | A backup file is the source of truth for restore. Restoring MUST be idempotent — re-importing the same file twice must not create duplicates. |
| **do it break** | A streak breaks only on a missed day past the grace window. A `rest_day` token (capped per period) prevents the break. Stats must reflect the actual completion log, not the streak number. |
| **Local-only data** | The app must never make a network call with user data. No analytics, no telemetry, no cloud sync. Any `http(s)://` usage is a security defect and must be removed. |

## Testing

- `flutter test` (all) or `flutter test test/<area>_test.dart` (one).
- **Minimum 80% coverage** on changed files. `flutter test --coverage`
  → `genhtml coverage/lcov.info -o coverage/html`.
- New model logic MUST have a corresponding
  `test/<area>_model_test.dart` covering: initial state, valid transitions,
  edge cases (Doze, reboot, tz change, missed day), and round-trip where
  applicable.
- Widget (screen) files need at minimum a pump-and-tap golden path test.
- New model fields that change save/load round-trip behavior must extend
  the existing round-trip test in that area's `_model_test.dart` (do not
  create a new test file just for the round-trip).
- Async widgets: `tester.runAsync` to step out of the fake-async zone for
  real `Future`s (`SharedPreferences`, `Future.delayed` on real time). Use
  `tester.pump()`, **never** `pumpAndSettle()` after a drag (scroll physics
  loops forever). Full pattern: see `board_box` testing-strategy.

## Commit & branch

- **Conventional Commits:** `feat:`, `fix:`, `refactor:`, `docs:`,
  `test:`, `chore:`, `perf:`, `ci:`.
- **One logical change per commit.** When a feature is large, split it
  into multiple commits and ship them in order.
- PR description: what changed, why, how it was verified (paste the
  three-gate output).
- **Banned in commits:** AI co-author footers (`Co-Authored-By: Claude …`),
  "Generated with Claude Code" trailers, `key.properties`, `*.jks`, `*.der`,
  any `ANDROID_*` env value, `google-services.json`, or any keystore.
- Push only when the user asks. Do not push directly to `main` without an
  approved PR (unless explicitly told to).

## Style highlights (lint-enforced — see [`analysis_options.yaml`](analysis_options.yaml))

Inherit from `board_box` (the 18 enabled lints). The three most relevant to
do it:

- **`avoid_print`** — `print()` is banned. Use `debugPrint` behind a
  `kDebugMode` guard, or surface the message to the UI.
- **`unawaited_futures`** — every `Future` must be `await`ed or wrapped in
  `unawaited(...)` from `dart:async`. Reminder scheduling is the
  asynchronous critical path; missing an `await` is the easiest way to
  ship a dropped alarm.
- **`always_use_package_imports`** — `package:doit/...` imports
  only. No relative `../` imports.

Full rationale: see `board_box/docs/engineering/flutter-dart-style.md`.

## Path-scoped rules (auto-loaded by Claude Code)

If your task touches a path, the matching `.claude/rules/<path>.md` will
load automatically:

- `lib/habits/**` → [`.claude/rules/lib-habits.md`](.claude/rules/lib-habits.md) — model purity, schedule types, proof modes.
- `lib/people/**` → [`.claude/rules/lib-people.md`](.claude/rules/lib-people.md) — contact resolution, cadence, privacy.
- `lib/missions/**` → [`.claude/rules/lib-missions.md`](.claude/rules/lib-missions.md) — chain order, sensor use, fail-safe.
- `lib/reminders/**` → [`.claude/rules/lib-reminders.md`](.claude/rules/lib-reminders.md) — exact-alarm, Doze, boot survival.
- `lib/services/**` → [`.claude/rules/lib-services.md`](.claude/rules/lib-services.md) — singleton + `_ready` gate, no Flutter imports.
- `lib/screens/**` → [`.claude/rules/lib-screens.md`](.claude/rules/lib-screens.md) — `StatefulWidget` for async, dimmed placeholders, 48dp targets.
- `test/**` → [`.claude/rules/test.md`](.claude/rules/test.md) — coverage, `runAsync`, no skipped tests.

## Out of scope

Do not modify these — report issues instead:

- `android/key.properties`
- `android/*.jks`, `android/*.der`, any keystore
- Any `ANDROID_*` GitHub Secret
- `google-services.json` or other platform credentials
- Anything in `.claude/` other than `AGENTS.md` / `CLAUDE.md` / `rules/`

## Common pitfalls

- **`key.properties` is gitignored.** Debug builds work without it; release
  fails with a Gradle signing error. On a new machine:
  `cp android/key.properties.example android/key.properties`.
- **Gradle OOM on low-RAM machines.** Set
  `org.gradle.jvmargs=-Xmx4g` in `android/gradle.properties` (default 8g).
- **Flutter SDK version mismatch.** CI pins 3.44.0. Use the same locally
  via FVM.
- **Exact-alarm permission on Android 14+.** `SCHEDULE_EXACT_ALARM` is now
  a user-granted permission. The app must detect denial and gracefully
  fall back to inexact WorkManager scheduling. See
  [docs/v_model/notification_reliability.md](docs/v_model/notification_reliability.md).
- **Doze + OEM battery savers.** Xiaomi / Oppo / Vivo / Honor aggressively
  kill background work. The app must prompt the user to disable battery
  optimization and the OEM's "auto-start" toggle, with a one-tap deep link.
- **Shake mission uses sensors, not timers.** Holding the phone still
  must not advance the shake count. The detector thresholds magnitude
  AND inter-shake spacing.
- **do it grace vs. rest day.** A grace window is automatic (e.g., "miss
  until 3 AM next day still counts"). A rest day is a user-granted
  manual pass. The model must distinguish them.
- **Backup file path is user-chosen.** The app must not assume a fixed
  Documents/ path. It uses `file_picker` to let the user pick a folder
  the first time and remembers the SAF URI in `shared_preferences`.

*Everything else — V-Model process, mission catalog, decision record,
traceability matrix, open questions — is in [`docs/v_model/`](docs/v_model/).*
