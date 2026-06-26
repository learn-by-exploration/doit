# v1.4 release checklist (right-side gate)

> **Purpose.** This document is the right-side gate of the
> V-Model for the v1.4 milestone. It is the on-device
> verification steps that close out the v1.4 cycle. The
> left-side baseline is
> [`v1_4_release_baseline.md`](v1_4_release_baseline.md); that
> doc is where the scope, the 30-phase roadmap status, the
> SYS- IDs, the ADRs, and the deferred items live.

The sign-off line at the bottom of this doc is the moment
the user accepts the build as the v1.4 release. v1.4x is the
user's hands-on on-device verification on the Android
emulator (or a real SM-S918B device), the same shape as
v0.5e / v1.0h / v1.1h / v1.1k / v1.2x / v1.3x.

## Pre-flight (mechanical, before the user's hands-on step)

These run as CI / commit-time checks, not on the device:

- [x] `dart format --output=none --set-exit-if-changed .` —
      clean.
- [x] `flutter analyze --fatal-infos` — No issues found!
- [x] `flutter test` — 1197 / 1197 tests passing.
- [x] `pubspec.yaml` → `version: 1.4.0+11`.
- [x] `lib/build_info.dart` → `kAppVersion = '1.4.0'`,
      `kAppVersionCode = 11`.
- [x] `test/release_signing_test.dart` mirror-pin assertions
      updated in lockstep.
- [x] `CHANGELOG.md` `## [1.4.0]` block exists with four
      sub-entries (v1.4a..v1.4d).
- [x] `docs/v_model/plan.md` Milestone 11 (v1.4) flipped to
      `shipped`.
- [x] `docs/v_model/implementation_status.md` has 4 new
      rows (v1.4a..v1.4d) + the sign-off row.
- [x] `docs/v_model/decision_record.md` ADR-045..ADR-048
      appended.
- [x] `docs/v_model/requirements.md` SYS-115..SYS-118
      appended.
- [x] `docs/v_model/v1_4_release_baseline.md` +
      `v1_4_release_checklist.md` exist.

## Build + install (the user runs)

- [ ] `flutter build apk --debug` — no signing-config touch.
      Record the SHA1 + size in the `release(v1.4)` commit
      (mirrors the v1.1i pattern at `222f860`).
- [ ] `adb install -r build/app/outputs/apk/debug/app-debug.apk`
      on the Android emulator (or a real SM-S918B device).
- [ ] Optional (asks first per CLAUDE.md):
      `flutter build appbundle --release` +
      `adb install -r build/app/outputs/bundle/release/app-release.aab`.

## On-device verification (one per sub-entry)

The v1.4 cycle shipped 4 sub-entries. The on-device checks
are organized by sub-entry; the user runs each in turn.

### v1.4a (Android home-screen widget)

- [ ] Long-press the home screen → Widgets → "do it". Add the
      widget. The widget should render the first-active do's
      name + streak + reliability badge (NOT empty / NOT a
      placeholder).
- [ ] Cold-launch the app for the first time (fresh install).
      The widget should still render the streak (read from the
      `SharedPreferences` cache before the Dart side has a chance
      to populate it).
- [ ] Tap the widget's "Done" button. The widget should refresh
      to show the streak advanced by 1 within ~500 ms (the
      Dart round-trip via `doit/widget` MethodChannel).
- [ ] Toggle a permission off in OS settings
      (`USE_FULL_SCREEN_INTENT` for example). Return to do it.
      The widget's reliability badge should flip to the
      `ic_widget_degraded` icon (the
      `ReliabilityService.reliability` subscription drives the
      re-derive → the `WidgetUpdater.refreshIds` is fired).
- [ ] Remove the widget from the home screen. Re-add it. The
      widget should re-render correctly (the
      `DoitWidgetProvider.onEnabled` lifecycle hook is wired).

### v1.4b (in-app tile streak + Done button)

- [ ] Open the home screen. The first tile should now show a
      streak number next to the do name with a "day streak"
      subtitle (matches the widget).
- [ ] The streak number should be computed from the local
      completion log via `ConsecutiveCounter.compute(...)`. Add
      3 consecutive completions (use the `markDoDone` flow or
      the widget's Done button); the streak should show "3".
- [ ] Tap the tile's "Mark done" button (the new `IconButton`
      on the right edge). The completion should append via
      `CompletionLogService.append(...)` and the tile should
      flip to "Already done for today" tooltip + a "Marked done."
      snackbar.
- [ ] Tap "Mark done" again on the already-done tile. The
      `CompletionLogService.append` should NOT fire a second
      time (the `_isCompletedToday` gate prevents the second
      tap).
- [ ] Edit a do to strong-mode (`StrongProof`). Schedule a
      reminder 1 minute from now. Tap the tile's "Mark done".
      The `MissionLauncherScreen` should push; the chain should
      walk end-to-end; on `ChainPassed` the tile should append
      the completion + flip to done. On `ChainFailedAt` the
      tile should NOT flip (v1.1f grace-window contract).

### v1.4c (in-app tile Skip today + rest-day budget indicator)

- [ ] Edit a do with `restDaysPerMonth > 0`. Return to the home
      screen. The tile should now show a "Skip today" button
      next to "Mark done".
- [ ] The tile should show "X / Y rest days left" below the
      streak badge (where X is the remaining budget for the
      current month, Y is the per-do limit).
- [ ] Tap "Skip today". The completion should append via
      `CompletionLogService.append(...)` with
      `source: CompletionSource.restDay`; the streak should
      HOLD (the streak calculator credits `rest_day`
      identically to `manual`); the "Skip today" button should
      flip to the "Rest day taken" tooltip; the budget caption
      should decrement by 1.
- [ ] Repeat until the budget is exhausted. The button should
      stay tappable (not greyed out — the tap triggers the
      SnackBar). The tap should show the
      "No rest days left this month." snackbar and should NOT
      append a row.
- [ ] Edit a do with `restDaysPerMonth == 0`. Return to the home
      screen. The "Skip today" button should be HIDDEN (NOT
      visible — the "opted out" state, not the "exhausted"
      state). The budget caption should NOT render.

### v1.4d (in-app tile Undo today's completion)

- [ ] Tap "Mark done" on a fresh tile (today not yet resolved).
      The tile should flip to done. The new "Undo today"
      `IconButton` should appear (the visibility gate is
      `_isResolvedToday == true`).
- [ ] Tap "Undo today". An `AlertDialog` should appear with the
      title "Undo today's completion?" and the body "This will
      remove today's check-in. The streak will update.".
- [ ] Tap "Cancel". The dialog should dismiss without state
      change. The completion row should still be there (query
      the local DB via `flutter run --debug` → `sqflite` log,
      or check the streak counter still reflects the manual
      completion).
- [ ] Tap "Undo today" again. Tap "Undo today" (the FilledButton
      in the dialog). The dialog should dismiss; the completion
      row should be deleted; a "Completion removed." snackbar
      should appear; the tile should flip back to "fresh" state
      (the streak should reflect the row's removal).
- [ ] Tap "Skip today" on a fresh tile. The tile should flip to
      skipped. The "Undo today" button should appear (the
      `_isResolvedToday` gate is shared between Done + Skip).
- [ ] Tap "Undo today" → "Undo today" (confirm). The rest-day
      row should be deleted; a "Completion removed." snackbar
      should appear; the tile should flip back to "fresh"
      state.
- [ ] Verify the "nothing to undo" defensive branch: open the
      app's local DB (via `flutter run --debug` →
      `sqflite` log) and manually delete today's row. Tap
      "Undo today" → "Undo today". The snackbar should read
      "Nothing to undo for today." (NOT crash, NOT flip the
      state flag).

## Regression checks (re-run the v1.3x checks)

The v1.4 cycle should not have regressed any v1.3
functionality. Re-run:

- [ ] Per-automation reliability badges (the icon-only state,
      before tapping). (v1.1f.)
- [ ] `PACKAGE_USAGE_STATS` permission rationale + deep-link.
      (v1.1g.)
- [ ] Brand-purple launcher icon + 'd' glyph + check dot.
      On-brand splash. Status-bar notification icon.
      (v1.1i.)
- [ ] Spanish locale. (v1.1h.)
- [ ] DST transition banner + streak-recovery card +
      pre-notification 5-min / 1-min heads-up. (v1.2j.)
- [ ] `CompletionLogSection` for review + undo. (v1.2m.)
- [ ] Uniform 3-wrong take-a-break across Math + Type.
      (v1.2l.)
- [ ] Hard-delete affordance on edit screen. (v1.2k.)
- [ ] Monthly stats + 7-day bar chart + per-do grace factory.
      (v1.3a.)
- [ ] Unified `ReliabilityService` source-of-truth (banner +
      settings row read from `ReliabilityService.instance.notifier`).
      (v1.3b.)
- [ ] `USE_FULL_SCREEN_INTENT` 5th permission tile + deep-link.
      (v1.3c.)
- [ ] `FullScreenActivity` launch path on locked device for
      strong-mode habits. (v1.3d.)

## SYS- exit criteria (left-side ↔ right-side traceability)

Every SYS- ID added in v1.4 maps to a verifiable test or
on-device check. The `requirements.md` row carries the
canonical mapping; this table mirrors it for quick sign-off:

| SYS- ID | v1.4 sub-entry | Verification (test or on-device check) |
| --- | --- | --- |
| SYS-115 | v1.4a | `test/widget/widget_state_builder_test.dart` (8 tests — streak from `ConsecutiveCounter.compute`; per-do `graceWindowOverride` honored; defensive `null activeDo` → empty snapshot; reliability→badge 1:1; `asOf` honored; fromJson defensive; equality + hashCode; copyWith) + `test/widget/widget_bridge_test.dart` (11 tests — `snapshot` happy path; `cacheSnapshot` happy path; `markDone` happy path; `_safe` swallows production `MissingPluginException`; `_safe` swallows `PlatformException`; per-method `MissingPluginException` swallow; `setAppContext` is a no-op for the fakes; `resetForTesting`; channel name is `doit/widget`; recording fakes capture args in order) + `test/widget/widget_state_cache_test.dart` (5 tests — save→load round-trip; empty cache returns null; corrupted cache returns null + clears; `cached` is in-memory after `save`; `resetForTesting` clears in-memory + prefs) + `test/widget/widget_state_locator_test.dart` (4 tests — first-active by `createdAt`; paused entry skipped; empty list returns null; `now` argument is honored for the paused check) + `test/widget/widget_service_test.dart` (6 tests — `init` is idempotent; `handleRefreshRequest` triggers a `bridge.snapshot` call; reliability change triggers re-derive; `markDone` on missing habit is a no-op; `markDone` on present habit appends + re-derives; `bridge` failure is swallowed per ADR-013) + on-device cold-start fallback + widget "Done" tap + reliability badge flip |
| SYS-116 | v1.4b | `test/screens/home_tile_streak_test.dart` (8 tests — empty log → 0; consecutive days → N; per-do `graceWindowOverride`; DST boundary; rest-day budget consumed; `asOf` parameter honored; helper is pure (no `DateTime.now()`); helper raises on null do) + `test/screens/home_tile_completion_test.dart` (4 tests — `markDoDone` calls `completionLog.append` with `source: CompletionSource.manual`; day argument is local-midnight at `asOf`; `proofModeAtTime` tag matches the do's `proofMode` (soft/strong/auto); no-op on null do) + `test/screens/home_test.dart` (+7 widget tests — tile renders streak number; tile renders "day streak" subtitle; soft-mode "Mark done" tap appends; already-done "Mark done" tap is a no-op; `_busy` indicator during in-flight append; SnackBar reads "Marked done."; strong-mode "Mark done" tap pushes `MissionLauncherScreen`) + on-device tile streak + Done check |
| SYS-117 | v1.4c | `test/screens/home_tile_skip_test.dart` (8 tests — happy-path append with `source: CompletionSource.restDay`; throws `NoRestDaysRemaining` when `restDaysPerMonth == 0`; throws on exhausted month; `SkipBudgetExhausted` is converted to `NoRestDaysRemaining`; day argument is local-midnight at `asOf`; `proofModeAtTime` tag matches the do's `proofMode`; idempotent (no append on second call within same month); no-op on null do) + `test/screens/home_tile_budget_test.dart` (11 tests — initial-state 0 used; after-append decrements; mid-month partial; month-roll-over reset; `restDaysPerMonth == 0` is opted-out (NOT exhausted); negative `remaining` is clamped to 0; `canSkip` / `isExhausted` derived flags; pure (no `DateTime.now()`); no-op on null do; `asOf` honored) + `test/screens/home_test.dart` (+7 widget tests — Skip button renders when `restDaysPerMonth > 0`; hidden when `restDaysPerMonth == 0`; soft-mode Skip tap appends rest-day; success snackbar reads "Rest day taken"; budget caption "X / Y" renders after a skip; snackbar reads "no rest days left" on exhausted budget; tooltip switches to "Rest day taken" after a skip) + on-device tile Skip + budget check |
| SYS-118 | v1.4d | `test/screens/home_tile_undo_test.dart` (8 tests — manual hit returns `UndoResult.removed(rowId, source)`; rest-day hit returns `UndoResult.removed`; no row returns `UndoResult.nothingToUndo()`; first-match by `dayMillis` regardless of source; no future-leak (yesterday's row doesn't match today's midnight); `deleteById` called exactly once on happy path; `deleteById` NOT called on nothingToUndo; `UndoResult` value-equality for both factories) + `test/screens/home_test.dart` (+5 widget tests — Undo button renders only when day is resolved; hidden when day not resolved; undo-tap on completed-today opens confirm dialog with body copy; undo-tap → confirm deletes the row + shows success snackbar; undo-tap on skipped-today deletes the rest-day row) + on-device tile Undo check (Done → Undo → Cancel + Done → Undo → Confirm; Skip → Undo → Confirm) |

## Sign-off

When every check above is green, the user accepts the build
as the v1.4 release:

```
v1.4 sign-off: 2026-06-27

Build SHA1: <from release(v1.4) commit>
Build size: <from release(v1.4) commit>
Test count: 1197 / 1197
```

The sign-off line lives in the `release(v1.4)` commit
message; the build SHA1 + size are recorded there.
