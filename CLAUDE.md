# CLAUDE.md — Streak (Claude Code layer)

**Read [`AGENTS.md`](AGENTS.md) first.** It has the project overview, the
3-gate, app invariants, commit conventions, and the secret-management
rules. This file is the Claude-Code-specific layer: command allowlists,
workflow expectations, subagent hints, and the verification loop. Keep it
short — bloated CLAUDE.md files cause Claude to ignore the real rules.

For deep-dives, see [`docs/v_model/`](docs/v_model/).

---

## Order of operations

1. Read this file (you're doing it).
2. Read [`AGENTS.md`](AGENTS.md) — portable project rules.
3. Read `.claude/rules/<path>.md` for the area you're touching (auto-loaded
   by Claude Code; covers `lib/habits/`, `lib/people/`, `lib/missions/`,
   `lib/reminders/`, `lib/services/`, `lib/screens/`, `test/`).
4. Read the relevant `docs/v_model/` file (see "Pointer to docs/" below).
5. Then plan, then code, then verify (the 3-gate), then commit.

---

## Pre-approved commands (no prompt needed)

- `flutter pub get`
- `dart format .` (auto-fix, then re-verify)
- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze --fatal-infos`
- `flutter test` (single file or whole suite)
- `flutter test --coverage`
- `flutter build apk --debug`
- `flutter build appbundle --release` — **ask first** (touches signing)
- `flutter build web --release --base-href /Streak/`
- `git status`, `git diff`, `git log`, `git add`, `git commit`, `git push`
- `gh pr create`, `gh pr view`, `gh pr list`, `gh run list`, `gh run view`
- Read-only shell: `cat`, `ls`, `find`, `grep`, `rg`

## Ask before running

- `flutter build appbundle --release` (touches signing config)
- `flutter build ios` (not in v0.1 scope; do not run without re-approval)
- Anything that modifies `android/key.properties`, `*.jks`, `*.der`, or
  `ANDROID_*` GitHub Secrets
- `flutter pub upgrade --major-versions` (review changelogs first)
- `git push --force`, `git reset --hard`, branch deletes on shared branches
- `rm -rf` outside of `build/` and `.dart_tool/`
- `adb install` / `adb uninstall` on a physical device
- Any change to `AndroidManifest.xml` permissions (always cross-check
  against the permission baseline in
  [docs/v_model/architecture_options.md](docs/v_model/architecture_options.md))

---

## Plan before code

For any non-trivial change (new habit type, new mission, new screen,
multi-file feature, dependency change), enter plan mode first. Plans
should name the files to touch, the test files to add/update, and the
verification step (the three quality-gate commands). Trivial fixes
(typos, single-line lints, format-only) can skip plan mode.

When the plan involves a **reminder, mission, or schedule** change, the
plan must explicitly call out the affected invariant from
[`AGENTS.md`](AGENTS.md) and the test that guards it.

---

## Three-gate verification loop (mandatory)

Before saying a task is done, run the three-gate sequence from `AGENTS.md`
and paste the output. "Looks done" is not done. If a gate cannot run
(e.g. no Flutter SDK in this environment), say so explicitly and explain
why.

```
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

For changes that affect reminder timing, also paste the output of:

```
flutter test test/reminders/alarm_scheduler_test.dart
flutter test test/reminders/doze_simulation_test.dart
```

For changes that affect missions, also paste:

```
flutter test test/missions/
```

---

## Subagent guidance

Use subagents to keep the main context lean. Order of dispatch by task
shape:

- **Investigate (read-only):** `code-explorer` (or `Explore` for broad
  fan-out). Good for "find every place that schedules an alarm" or "map
  the current proof-mode flow."
- **Plan:** `planner` (or `Plan`). For multi-file features and refactors.
- **Implement:** `flutter-expert` (Flutter-specific patterns) or
  `code-architect` (cross-language design).
- **Test (TDD):** `tdd-guide` for write-tests-first, `flutter-test`
  skill for running.
- **Review:** `code-reviewer` (general), `flutter-reviewer` (Flutter),
  `security-reviewer` (auth / PII / input validation — especially for
  READ_CONTACTS and any backup encryption).
- **Debug:** `debugger` for test failures, `build-error-resolver` for
  `dart analyze` / `flutter build` failures.

For multi-perspective review of a V-Model artifact (e.g. "is the
conops complete?"), use the panel approach from the global
`agents-and-skills` doc: spawn a planner, a security-reviewer, and a
fresh-eyes reviewer in parallel.

**Compact carefully.** When context compacts, preserve: the list of
files modified in the current task; the exact quality-gate command
outputs; any TODO items the user added inline during the session. If
compaction keeps losing important state, add a one-line rule to
`.claude/settings.json` — not to this file.

---

## V-Model-aware workflow

Streak follows the V-Model from
[`docs/v_model/plan.md`](docs/v_model/plan.md). When working on this
repo, the right-side verification is just as important as the
left-side requirement:

- A change to a habit model → update
  [`requirements.md`](docs/v_model/requirements.md) `SYS-` IDs and
  the test that guards them.
- A change to a mission → update
  [`mission_catalog.md`](docs/v_model/mission_catalog.md) and add
  a model test.
- A change to scheduling → update
  [`notification_reliability.md`](docs/v_model/notification_reliability.md)
  and the alarm-scheduler test.
- A new architecture decision → append an ADR to
  [`decision_record.md`](docs/v_model/decision_record.md).

If you change a doc but not the code (or vice-versa), the V is
incomplete. Say so in the commit message.

---

## Pointer to docs/

| For… | Read… |
|---|---|
| Day-to-day Dart/Flutter style (naming, file org, imports, comments, constants) | [`docs/engineering/coding-guidelines.md`](docs/engineering/coding-guidelines.md) |
| Style for models, services, widgets, errors, tests, Dart 3 (companion to coding-guidelines) | [`docs/engineering/coding-guidelines-types.md`](docs/engineering/coding-guidelines-types.md) |
| V-Model lifecycle, phase gates, traceability (lifecycle framing that wraps everything below) | [`docs/engineering/v-model.md`](docs/engineering/v-model.md) |
| V-Model stages, milestones, working assumptions | [`docs/v_model/plan.md`](docs/v_model/plan.md) |
| Mission, actors, modes, constraints, success | [`docs/v_model/conops.md`](docs/v_model/conops.md) |
| End-to-end user flows (WF-001..N) | [`docs/v_model/workflows.md`](docs/v_model/workflows.md) |
| System requirements (SYS-001..N) | [`docs/v_model/requirements.md`](docs/v_model/requirements.md) |
| v0.1 scope, decisions, acceptance criteria | [`docs/v_model/v0_1_baseline.md`](docs/v_model/v0_1_baseline.md) |
| Tech stack, packages, modules | [`docs/v_model/architecture_options.md`](docs/v_model/architecture_options.md) |
| Why each decision was made (ADRs) | [`docs/v_model/decision_record.md`](docs/v_model/decision_record.md) |
| Need → Requirement → Design → Verification | [`docs/v_model/traceability_matrix.md`](docs/v_model/traceability_matrix.md) |
| What is still open | [`docs/v_model/open_questions.md`](docs/v_model/open_questions.md) |
| What is done / what is next | [`docs/v_model/implementation_status.md`](docs/v_model/implementation_status.md) |
| Spec for each mission type | [`docs/v_model/mission_catalog.md`](docs/v_model/mission_catalog.md) |
| Doze, exact-alarm, boot survival | [`docs/v_model/notification_reliability.md`](docs/v_model/notification_reliability.md) |

---

*Last updated: 2026-06-13. Keep this file ≤120 lines — bloat kills the rules.*
