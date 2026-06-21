# v1.1 hand-off from v1.0g release prep

Status: **in flight**, 2026-06-21. This document is the
hand-off from the v1.0g release-prep agent to whoever
finishes the v1.1 work. Read it before resuming.

## TL;DR

The v1.0g release-prep PR is **complete and preserved in
stash@{0}** of the `main` branch:

```
git stash list
# stash@{0}: On main: v1.0g release prep (commit after v1.1 lands)
# stash@{1}: On main: v1.1 parallel work (out of v1.0 release-prep scope)
```

It contains 12 files:

- `pubspec.yaml` (1.0.0+7)
- `lib/build_info.dart` (kAppVersion='1.0.0',
  kAppVersionCode=7)
- `test/release_signing_test.dart` (v0.5a pin tests
  rewritten in place to assert v1.0g values; new test
  names end in `(v1.0g)`)
- `CHANGELOG.md` (Phase A + D + F subsections added)
- `docs/v_model/v1_0_release_baseline.md` (new, 259
  lines — left-side V-Model doc)
- `docs/v_model/v1_0_release_checklist.md` (new, 336
  lines — right-side gate)
- `docs/v_model/implementation_status.md` (v1.0g row
  appended)
- `docs/v_model/notification_reliability.md` (Device-
  state + Calendar + Call-screening sections updated
  from `(planned)` to shipped state)
- `docs/v_model/plan.md` (Milestone 7 + Milestone 8
  stub appended)
- `docs/v_model/workflows.md` (WF-036 appended)
- `docs/v_model/architecture_options.md` (3 rows
  appended: Calendar service + CallInterceptor service
  + Device-state PR 2)

To commit the v1.0g release-prep once v1.1 is green:

```
git stash pop stash@{0}     # restore the v1.0g work
git status --short          # verify only the 12 v1.0g files are listed
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test                # should be 741+ (no new tests in v1.0g)
git add <the 12 v1.0g files explicitly>
git commit                   # conventional commit: docs(v1.0): release prep + sign-off
git push                     # user step per CLAUDE.md (default-branch push)
```

## Why this handoff

During v1.0g release prep, the agent discovered that the
working tree also contains **uncommitted v1.1 parallel
work** (started by a separate agent or session):

- `lib/services/routine_config.dart` (new, untracked) —
  template-driven routine config class for templates
  #17–#21, refs `SYS-080 / ADR-025`.
- `lib/routines/routine.dart` (modified) — adds
  `RoutineOpenAppRequest` value class, refs `SYS-082`.
- `lib/routines/routine_executor.dart` (modified) —
  adds `_pendingOpenApp` `ValueNotifier<List<RoutineOpenAppRequest>>`,
  `appendOpenApp`, `pendingOpenApp` getter, dispatch path
  for `ActionOpenApp`, refs `SYS-082`.
- `lib/reminders/notification_service.dart` (modified) —
  adds `body` field on `ReminderEvent` for routine-fired
  notifications.
- `lib/services/settings_service.dart` (modified) — adds
  `setRoutine` / `getRoutine` / `japanRoutine` accessors
  for the v1.1 routine config persistence.
- `test/screens/settings_test.dart` (modified) — header
  test updated to assert the v1.1 settings API.

The v1.1 changes break compilation of **5 dispatch
tests** (`test/routines/executor_test.dart`,
`calendar_dispatch_test.dart`, `call_dispatch_test.dart`,
`device_state_dispatch_test.dart`,
`location_dispatch_test.dart`) because the executor API
changed (new `appendOpenApp` + `_pendingOpenApp`
`ValueNotifier`). The `routine_config.dart` file has a
**type error at line 169** (a `MapEntry` is not an
`Iterable<Object?>` — see fix below). The
`test/screens/settings_call_screening_tile_test.dart`
file (committed in `ff56021`) has a **pre-existing info
lint** at line 47 (`_setPhoneSize` underscore-prefix).

These are **out of scope** for v1.0g (which is doc-only
+ version bump per the user's pick via AskUserQuestion).
The v1.1 work needs its own plan + completion cycle.

## v1.1 known issues (must-fix list)

1. **`lib/services/routine_config.dart:169` — compile
   error.**
   ```dart
   Object.hashAllUnordered(
     conditionJson?.entries ??            // ← line 169
         const MapEntry<String, Object?>('__null__', null),
   ),
   ```
   `Object.hashAllUnordered` expects an
   `Iterable<Object?>`. The `??` fallback is a single
   `MapEntry`, not an iterable. Fix:
   ```dart
   conditionJson == null
       ? 0
       : Object.hashAllUnordered(conditionJson.entries),
   ```
   Or keep the sentinel-hash approach by wrapping:
   ```dart
   Object.hashAllUnordered(
     conditionJson?.entries ?? const [],
   ),
   ```
   (Both are minimal; the first is more idiomatic.)

2. **`test/routines/executor_test.dart` + 4 sibling
   dispatch tests — compilation failures.**
   The new `appendOpenApp` + `_pendingOpenApp` +
   `pendingOpenApp` API on `RoutineExecutor` is
   referenced from the dispatch tests but the existing
   tests still use the v1.0 API. Each dispatch test
   needs the `ActionOpenApp` arm added (or stubbed). See
   `lib/routines/routine_executor.dart` lines
   ~95–110 for the new state and lines ~550–580 for
   the new dispatch arm.

3. **`test/screens/settings_call_screening_tile_test.dart:47` —
   pre-existing info lint.**
   `local variable '_setPhoneSize' starts with an
   underscore`. Rename to `setPhoneSize`. The lint
   appears at the v1.0f.2 tip (`ff56021`) independent of
   the v1.1 work; the v1.1 hand-off is the natural
   moment to fix it.

4. **Missing ADR-025** — `RoutineConfig`'s design
   rationale (kTemplateFormatVersion for routine
   payloads, the SharedPreferences key shape
   `doit.routine.<templateId>`, the deliberate non-
   migration of `JapanRoutineConfig`'s legacy keys) is
   referenced in `routine_config.dart`'s file header
   but the ADR is not in `decision_record.md`.

5. **Missing test for `RoutineConfig`** — `lib/services/
   routine_config.dart` is a pure value class with a
   `toJson` / `fromJson` codec, structural equality,
   and `copyWith`. A `test/services/routine_config_test.dart`
   covering equality, hash, toString, and the codec
   round-trip is needed before v1.1 can land.

6. **Missing v1.1 SYS- / ADR- rows** —
   `docs/v_model/requirements.md` needs SYS-080
   (RoutineConfig template-driven routines), SYS-081
   (?), SYS-082 (ActionOpenApp / RoutineOpenAppRequest),
   and probably SYS-083–085 for the v1.1 routine
   wiring. `decision_record.md` needs ADR-025. These
   updates are best done in the same PR that fixes
   issues 1–2 + 5 above.

## v1.1 completion plan (suggested — to be planned and
executed by the v1.1 hand)

1. **PR v1.1a — `RoutineConfig` (SYS-080 / ADR-025).**
   Fix the type error at `routine_config.dart:169`,
   write `test/services/routine_config_test.dart`,
   append ADR-025 to `decision_record.md`, append
   SYS-080 to `requirements.md`. 3-gate green in
   isolation.
2. **PR v1.1b — `ReminderEvent.body` + SettingsService
   routine API.** Already in the working tree. Need to
   confirm the dispatcher tests pass and pin the new
   `body` field in a small test.
3. **PR v1.1c — `ActionOpenApp` + `RoutineOpenAppRequest`
   + dispatch (SYS-082).** Fix the dispatch tests
   (5 files). Add a `RoutineBanner` widget that drains
   `pendingOpenApp` on home-screen resume. Add
   `requirements.md` SYS-082.
4. **PR v1.1d — sign-off + version bump.** (Per
   [`v1_0_release_baseline.md`](v1_0_release_baseline.md)
   Milestone 8 plan.)
5. **After v1.1d lands:** `git stash pop stash@{0}` to
   restore the v1.0g release-prep, then `git commit`
   the v1.0g release-prep on top of the v1.1 tip.

The v1.0g commit lands on the v1.1 tip because the v1.0g
files do not overlap with any v1.1 files except via
cross-references in the V-Model docs (the docs reference
v1.1 features by name; v1.1 needs to land first so the
doc cross-references resolve). This sequencing is the
correct one per the user's pick ("Commit v1.1 first
(Recommended)").

## Cross-references the v1.0g docs already include

The v1.0g release-prep docs (in stash@{0}) reference v1.1
features that do not yet exist in the codebase:

- `v1_0_release_baseline.md` mentions "templates #17–#21
  in v1.1" (this is what `routine_config.dart` covers —
  see ADR-025 to be written).
- `v1_0_release_baseline.md` "What is explicitly out of
  scope for v1.0" lists v1.1 follow-ups including the
  generic routine apply UX for templates #17–#21.
- `v1_0_release_checklist.md` "v1.1 working set" mirrors
  the same list.
- `plan.md` Milestone 8 lists the v1.1 candidates.

These cross-references are **forward-pointing** and
intentional: when v1.1 lands, the cross-references
resolve. No v1.0g doc edit is needed when v1.1 lands;
the v1.1 PRs update their own docs (ADR-025, SYS-080,
SYS-082, etc.) and the v1.0g cross-references already
point at them.

## Recovery steps if the stash is lost

`git stash list` will show both stashes. To verify
their contents before any pop:

```
git stash show stash@{0} --stat     # v1.0g release prep
git stash show stash@{1} --stat     # v1.1 closed-off (notification_service.dart + routine.dart + settings_service.dart + settings_test.dart)
```

If both stashes are present, the work is preserved. If
either is missing, recover from
`/home/shyam/.claude/projects/-home-shyam-common-games-doit/`
(they are referenced in this session's transcript).

## Status snapshot

- **v1.0 release-prep**: complete in `stash@{0}` (12
  files). Ready to pop and commit after v1.1 lands.
- **v1.1 parallel work**: in working tree (5 modified +
  1 untracked). Blocked on 6 known issues (see above).
- **v1.0 tip**: `7157707` (status-doc log).
- **Stash list**:
  - `stash@{0}` — v1.0g release prep (12 files).
  - `stash@{1}` — v1.1 closed-off work (4 files; the
    v1.1 source code that's *not* the broken
    `routine_executor.dart`).
- **3-gate at the v1.0 tip alone**: 741 / 741 tests
  pass (verified by the v1.0g agent before the v1.1
  stash-pop made the tree inconsistent).

The user (or v1.1 agent) resumes here. The v1.0g
release-prep is **safe to commit** as soon as the v1.1
tip is green.

— handoff from v1.0g release-prep agent, 2026-06-21.