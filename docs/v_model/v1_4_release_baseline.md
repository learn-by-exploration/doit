# v1.4 release baseline

> **Scope.** This document is the left-side baseline of the V-Model
> for the v1.4 milestone. It is the contract the implementation
> rows in `implementation_status.md` (v1.4a..v1.4d) and the
> requirements rows in `requirements.md` (SYS-115..SYS-118)
> satisfy. The right-side gate is
> [`v1_4_release_checklist.md`](v1_4_release_checklist.md); that doc
> is where the on-device verification steps live.

## 1. Headline theme

**Home widget + in-app tile completion lifecycle.** Four v1.4
sub-entries (v1.4a..v1.4d) landed across the v1.4 cycle to land
the first launcher surface AND bring the in-app tile to feature
parity with it (Done / Skip / Undo / streak). The four headline
themes:

- **Android home-screen widget** (v1.4a / Phase 28) — the first
  launcher surface; a native `AppWidgetProvider` + `RemoteViews`
  over the `doit/widget` MethodChannel; renders the first-active
  do's streak + a unified `Reliability` badge; cold-start
  fallback uses `SharedPreferences` so the widget is never blank
  between OS process-kill and first Dart frame. Closes `feature.md`
  §2.8 (B9 — widget re-arm indicator) + the home-widget gap from
  the 30-phase roadmap.
- **In-app tile streak + Done button** (v1.4b / Phase 29) — the
  home tile grows the same streak number + "Mark done" affordance
  as the widget, mirroring `WidgetService.markDone` via
  `CompletionLogService.append`; strong-mode habits push
  `MissionLauncherScreen` end-to-end. Mirrors the widget's
  strong-mode path (which fires the FSI mission UI).
- **In-app tile Skip today + rest-day budget indicator** (v1.4c /
  Phase 30) — per-tile "Skip today" `IconButton` consumes a
  rest-day slot from the per-do `restDaysPerMonth` budget; the
  success snackbar reads "Rest day taken"; the budget caption
  updates from "X / Y rest days left" → "No rest days left" on
  exhaustion. `CompletionLogService.append` with
  `source: CompletionSource.restDay` — the streak calculator
  credits `CompletionSource.restDay` identically to manual rows.
- **In-app tile Undo today's completion** (v1.4d / Phase 31) —
  per-tile `IconButton` visible only when today is resolved (Done
  or Skip); opens a confirm dialog; calls the new pure-Dart
  `undoToday` helper which deletes the matching `CompletionRow`
  via the existing `CompletionLogService.deleteById` from v1.2m /
  SYS-108. Mirrors `CompletionLogSection._confirmAndDelete` with
  one fewer tap (no scroll, no list, no per-row delete icon).

The v1.4 cycle brings the in-app tile to full lifecycle
completeness — every action the user can take from the widget is
now also one tap away on the home tile.

## 2. The 30-phase roadmap (status)

The 30-phase roadmap is scattered across the `CHANGELOG.md`
v1.4 sub-entries. The phase status at v1.4 sign-off:

| Phase | Topic | Status | v1.4 sub-entry |
|---|---|---|---|
| 28 | Android home-screen widget (cold-start fallback + reliability badge) | shipped | v1.4a |
| 29 | In-app tile streak number + per-tile Done button | shipped | v1.4b |
| 30 | In-app tile Skip today + rest-day budget indicator | shipped | v1.4c |
| 31 | In-app tile Undo today's completion | shipped | v1.4d |
| 16-27 | v1.x candidates (Phases 16-27) | v1.x parking lot | — (see `feature.md` §4) |
| 32-36 | v1.x candidates (iOS port, Wear OS, 7-day sparkline, widget variants, etc.) | v1.x parking lot | — (see `feature.md` §4) |

Phase 28 (the home widget) was the highest-priority deferred
item from the v1.3 sign-off. Phases 29-31 close the in-app tile's
completion-lifecycle gap with the widget. The remaining deferred
items (Phases 16-27 + 32-36) are tracked in `feature.md` §2 + §4
— none of them block the v1.4 release.

## 3. Requirements (SYS- IDs)

v1.4 added 4 requirements rows to `requirements.md` (the
`requirements.md` mapping is the source of truth — every other
doc in this folder is required to match):

- **SYS-115** (v1.4a / Phase 28) — `DoitWidgetProvider` (native
  `AppWidgetProvider` + `RemoteViews` over the `doit/widget`
  MethodChannel) renders the first-active do's streak + a unified
  `Reliability` badge; cold-start fallback reads from a
  `SharedPreferences` cache so the widget is never blank between
  OS process-kill and first Dart frame; `WidgetService` is a
  singleton-with-`_ready` that subscribes to
  `ReliabilityService.reliability` so every value change triggers
  a re-derive; `WidgetBridge` MethodChannel has `_safe` wrapper
  per ADR-013 (defense-in-depth); `WidgetStateCache` mirrors the
  Dart-side cache; `WidgetStateLocator.firstActiveDo(...)` is
  deterministic (caller passes a frozen `now`); no `home_widget`
  pubspec dep; no `<uses-permission>` for widget rendering.
- **SYS-116** (v1.4b / Phase 29) — the in-app tile grows a streak
  number + "Mark done" affordance mirroring the widget. Pure-Dart
  `streakForDo(...)` calls `ConsecutiveCounter.compute(...)` (the
  same source-of-truth the widget reads); the "Mark done" tap
  calls `CompletionLogService.append(...)` with
  `source: CompletionSource.manual` (single source-of-truth for
  the completion write); strong-mode tiles push
  `MissionLauncherScreen` (which already handles the completion
  write on `ChainPassed` per SYS-114); the per-tile state
  (`_isCompletedToday`, `_busy`) is local to the tile; `asOf` is
  frozen at `_loadDos` time (NOT `DateTime.now()` in `build()`).
- **SYS-117** (v1.4c / Phase 30) — the in-app tile grows a "Skip
  today" `IconButton` + a per-do budget caption. Pure-Dart
  `markDoSkipped(...)` + `NoRestDaysRemaining` exception + pure
  `budgetRemainingForDo(...)` + `BudgetRemaining` immutable value
  class; the `SkipBudget(doId, monthlyLimit).consume(asOf)` call
  throws `SkipBudgetExhausted` which the helper converts to
  `NoRestDaysRemaining` so the contract stays single-message;
  `CompletionLogService.append(...)` with
  `source: CompletionSource.restDay` (the streak calculator
  credits `rest_day` identically to `manual`); the per-do
  `restDaysPerMonth == 0` case is "opted out" (not exhausted);
  shared `proofModeTag(DoProofMode)` helper consolidates 2 of 3
  inline copies; the budget caption reads "X / Y rest days left"
  → "No rest days left" on exhaustion.
- **SYS-118** (v1.4d / Phase 31) — the in-app tile grows an
  "Undo today" `IconButton` visible only when today is resolved.
  Pure-Dart `undoToday({required Do activeDo, required DateTime
  asOf, required CompletionLogService completionLog})` +
  `UndoResult` sealed value class with two factories
  (`UndoResult.removed(rowId, source)` for the happy path;
  `UndoResult.nothingToUndo()` for the no-row path); day filter is
  `DateTime(asOf.year, asOf.month, asOf.day)` (local-midnight
  comparison — same convention as `markDoDone` + `markDoSkipped`);
  the helper calls `completionLog.deleteById(row.id)` exactly once
  on the happy path; the widget branches on the result to flip
  `_isCompletedToday` / `_isSkippedToday` back to `false` and show
  `homeTileUndoSuccess` (happy path) or `homeTileUndoNotToday`
  (defensive — the dialog shouldn't be reachable when
  `_isResolvedToday` is false, but the DB is the source of truth);
  no `DateTime.now()` inside; no Flutter import.

## 4. Decisions (ADRs)

v1.4 added 4 ADRs to `decision_record.md` (045..048):

- **ADR-045** — `DoitWidgetProvider` (native `AppWidgetProvider` +
  `RemoteViews` over the `doit/widget` MethodChannel) is the
  Android home widget surface. NO `home_widget` pubspec dep; NO
  `wakelock_plus` (the widget renders from `RemoteViews`, not a
  `FlutterActivity`); cold-start fallback via
  `SharedPreferences`; reliability-string-to-icon 1:1 mapping
  (`optimal` → `ic_widget_optimal`, `degraded` →
  `ic_widget_degraded`, `unknown` → `ic_widget_unknown`); no new
  `<uses-permission>`.
- **ADR-046** — In-app tile streak + Done button. Same shape as
  the widget's; pure-Dart `streakForDo(...)` calls
  `ConsecutiveCounter.compute(...)` (no new helper class —
  re-uses the streak calculator that the widget already reads);
  `markDoDone(...)` calls `CompletionLogService.append(...)` (no
  new DB method); strong-mode path pushes `MissionLauncherScreen`
  (no new mission logic — the launcher already handles the
  completion write per SYS-114); `asOf` is frozen at `_loadDos`
  time (NOT `DateTime.now()` in `build()`).
- **ADR-047** — In-app tile Skip today + rest-day budget
  indicator. The "X / Y rest days left" caption is a
  `FutureBuilder` over `budgetRemainingForDo(...)` (re-uses the
  `SkipBudget` from v1.1f + the same `CompletionLogService.append`
  call shape as `markDoDone`); `restDaysPerMonth == 0` is "opted
  out" (not exhausted — closes the "user disabled rest days but
  the budget caption reads 'no rest days left'?" ambiguity);
  shared `proofModeTag(DoProofMode)` helper consolidates 2 of 3
  inline copies (DRY — the same helper already exists in
  `WidgetService._proofModeTag`); the per-tile `_isResolvedToday`
  getter is `(_isCompletedToday || _isSkippedToday)` (the gate
  for the Undo button in v1.4d).
- **ADR-048** — In-app tile Undo today's completion. Mirrors
  `CompletionLogSection._confirmAndDelete` (v1.2m / SYS-108) but
  with one fewer tap (no scroll, no list, no per-row delete
  icon); pure-Dart `undoToday(...)` + `UndoResult` sealed value
  class (no enum — sealed for exhaustiveness in the widget's
  switch); day filter is local-midnight (same convention as
  `markDoDone` + `markDoSkipped`); the widget branches on the
  result to flip the right state flag + show the right snackbar;
  the helper calls `completionLog.deleteById(...)` exactly once
  on the happy path; no new Drift methods; no new
  `<uses-permission>`.

## 5. Out-of-scope (deferred to v1.x)

These items are explicitly **not** in v1.4 scope but are v1.x
candidates (still v1 track, not v2.0 jump):

- Widget-side "Skip today" button (mirrors the v1.4c in-app tile
  affordance). See `feature.md` §4.
- Widget-side Undo (mirrors the v1.4d in-app tile affordance).
  See `feature.md` §4.
- In-app tile streak history visualization (7-day sparkline). See
  `feature.md` §4.
- In-app tile edit / delete affordance (currently in long-press
  select-mode only). See `feature.md` §4.
- Widget small / large variants, widget config activity, widget
  list (scrolling), widget deep-link to a specific do. See
  `feature.md` §4.
- Rest-day history visualization. See `feature.md` §4.
- Rest-day budget edit affordance (currently per-do
  `restDaysPerMonth` is fixed at habit creation). See `feature.md`
  §4.
- Phases 16-27 of the 30-phase roadmap (iOS port, Wear OS, etc.).
  See `feature.md` §4.
- Phases 32-36 of the 30-phase roadmap (the v1.4 cycle landed
  Phases 28-31). See `feature.md` §4.
- Kotlin-side unit tests for `DoitWidgetProvider` /
  `WidgetChannel` / `WidgetUpdater` / `WidgetRenderer` /
  `WidgetStateCache` (the Dart-side tests cover the bridge +
  service contract; the `compileDebugKotlin` gate catches
  syntax / null-safety / deprecation issues). A v1.5+ follow-up
  can add Robolectric / `androidx.test.core` tests.
- Widget click handler for "open app" deep-link (today the
  widget's "Done" tap fires `ACTION_MARK_DONE`; an
  "open app to this do" deep-link is a v1.5+ candidate).
- Per-mission retry UX (a `ChainFailedAt` currently pops with
  `null`; v1.1f grace-window semantics handle the wrong-attempt
  case for Math / Type; Shake / Hold / Memory do not retry).
- Native-Spanish-speaker translation of `lib/l10n/app_es.arb`
  (v1.1h's smoke-test locale is the only translation). See
  `feature.md` §2.4.
- `google_maps_flutter` for `LocationMapPreview` (would add
  `INTERNET`). See `feature.md` §2.5.
- Legacy `mipmap-*/ic_launcher.png` regeneration from the master
  vector. See `feature.md` §2.6.
- Light-theme icon variant. See `feature.md` §2.7.

## 6. No new permissions, no `INTERNET`

The v1.4 cycle did **not** add any new `<uses-permission>`. The
home widget needs no permissions to render (the `RemoteViews`
are visible only when the launcher shows them). The in-app tile
gains only existing-permission functionality (notification
permission for the v1.4b/c Done/Skip snackbars; none for the
v1.4d Undo which is purely local to the Drift DB).

The v1.4 cycle did **not** add `INTERNET`. The `doit/widget`
MethodChannel is local to the device (the widget process talks
to the host process over `FlutterEngineCache` + `MethodChannel`;
no network). The `LocationMapPreview` remains a pure
`CustomPaint` widget. The CI grep rejecting
`import 'package:http'` and `Uri.http(s)` in production code is
unchanged.

## 7. Test surface

- v1.4 starts at the v1.3 sign-off end state: 1064 / 1064 tests
  passing.
- v1.4 adds 133 new tests across the 4 sub-entries (v1.4a..v1.4d)
  for a final v1.4 end state of 1197 / 1197 tests passing.
- v1.4 has no `skip:` markers; the CI rejects skipped tests (see
  `.claude/rules/test.md`).
- v1.4's test coverage on changed files is ≥ 80% per
  `.claude/rules/test.md`'s coverage policy.

The 133 new tests break down as:

| Sub-entry | New tests | Where |
|---|---|---|
| v1.4a | 66 | `test/widget/widget_state_builder_test.dart` (8) + `widget_bridge_test.dart` (11) + `widget_state_cache_test.dart` (5) + `widget_state_locator_test.dart` (4) + `widget_service_test.dart` (6) + per-test re-organizations across the 4 `widget_state_locator_test.dart` / `widget_bridge_test.dart` linter-driven tweaks |
| v1.4b | 19 | `test/screens/home_tile_streak_test.dart` (8) + `home_tile_completion_test.dart` (4) + `home_test.dart` (+7 widget extensions) |
| v1.4c | 19 | `test/screens/home_tile_skip_test.dart` (8) + `home_tile_budget_test.dart` (11) + `home_test.dart` (+7 widget extensions, overlapping the v1.4b widget extensions) |
| v1.4d | 13 | `test/screens/home_tile_undo_test.dart` (8) + `home_test.dart` (+5 widget extensions) |

(The v1.4b + v1.4c + v1.4d widget extension numbers are
slightly-overlapping because each cycle re-tested the existing
widget extensions in lockstep with the new ones.)

## 8. Version bump

- `pubspec.yaml` — `version: 1.3.0+10` → `version: 1.4.0+11`.
- `lib/build_info.dart` — `kAppVersion = '1.3.0'` →
  `kAppVersion = '1.4.0'`; `kAppVersionCode = 10` → `11`.
- `test/release_signing_test.dart` mirror-pin assertions updated
  in lockstep.

The version code increments by one (no skipped codes), mirroring
the v1.0 → v1.0.0+7 and v1.1.0+8 → v1.2.0+9 → v1.3.0+10 →
v1.4.0+11 bumps.

## 9. Migration shape

The v1.4 cycle has **no DB migrations**. The `WidgetStateCache`
is a new `SharedPreferences` key (`doit.widget.cached_v1`); it
is NOT a Drift migration. The `_HabitTile` widget's state grew
3 new fields (`_isCompletedToday`, `_isSkippedToday`, `_busy`)
in v1.4b..v1.4d but those are in-memory only — they reset on
cold launch. The new `UndoResult` sealed value class is a pure
Dart value type with no persistence concerns. The release-shape
rule "a migration is its own PR" is honored — v1.4 has no
migrations.
