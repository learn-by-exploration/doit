# v1.1 hand-off — closed (shipped)

Status: **shipped**, 2026-06-22. The v1.1 polish / expansion
milestone closed with the v1.1i release APK. This document
was originally a live hand-off from the v1.0g release-prep
agent; it now serves as a closing retrospective and a pointer
to the canonical v1.1 sources.

## TL;DR

The v1.1 milestone is closed:

- **9 feature commits** (`v1.1a` … `v1.1i`) shipped between
  2026-06-21 and 2026-06-22.
- **9 doc-only backfill commits** appended the matching
  commit SHA into
  [`implementation_status.md`](implementation_status.md).
- **1 retroactive test commit** (`v1.1c`, `3b42260`) closed
  the SYS-082 dispatch coverage gap.
- **1 release commit** (`v1.1i`, `222f860`) carries the
  debug-signed APK (`build/app/outputs/flutter-apk/app-release.apk`,
  75.1 MB, SHA1 `c3e0f6c6`) on `main`.
- **3-gate at v1.1 tip**: `893 / 893` tests pass,
  `dart format` clean, `flutter analyze --fatal-infos`
  clean. Coverage stays at the 80% floor on changed files
  per `AGENTS.md`.

The original "v1.1 known issues (must-fix list)" and
"v1.1 completion plan (suggested)" sections are gone —
every item is closed or superseded. See "What shipped" and
"Carry-over to v1.2" below.

## What shipped

The full per-commit trail is in
[`implementation_status.md`](implementation_status.md).
Summary by sub-milestone:

- **v1.1a — `RoutineConfig` value class (SYS-080 / ADR-025).**
  Templates #17..#21 (Focus block, Working from home, At
  the gym, Leaving work, Meeting prep) get a typed
  envelope with structural equality, deterministic
  hashCode, and a `toJson` / `fromJson` codec. Settings
  persistence under `doit.routine.<templateId>`.
  `JapanRoutineConfig` deliberately stays on its three v1.0
  legacy keys (ADR-025 explicit non-migration).
  Source: `lib/services/routine_config.dart`, tests in
  `test/services/routine_config_test.dart` +
  `test/services/settings_service_routine_test.dart`.

- **v1.1b — `ReminderEvent.body` + `SettingsService` routine
  registry.** Routine-fired notifications (Phase C/D/E
  routines whose action is `ActionNotify`) now carry their
  own body text instead of deriving it on the Kotlin side.
  The SettingsService gains a reactive
  `routines: ValueListenable<Map<String, RoutineConfig>>`
  that the routine executor subscribes to.
  Source: `lib/reminders/notification_service.dart`,
  `lib/services/settings_service.dart`.

- **v1.1c — `ActionOpenApp` dispatch + `RoutineBanner`
  drain (SYS-082 / ADR-026).** The fifth leaf of the
  sealed `Action` hierarchy is wired end-to-end. The
  executor's `_dispatchAction` is a single exhaustive
  `is`-switch; `ActionOpenApp` appends a
  `RoutineOpenAppRequest` to a `ValueNotifier` on the
  executor, and a passive `RoutineBanner` widget drains
  the queue via `Navigator.pushNamed` from the home
  screen. Zero layout cost in the steady state.
  Source: `lib/routines/routine_executor.dart`,
  `lib/widgets/routine_banner.dart`, tests in
  `test/widgets/routine_banner_test.dart` +
  `test/routines/action_dispatch_test.dart`.

- **v1.1d — generic `RoutineApplyScreen` for templates
  #17..#21 (SYS-083 / ADR-027).** A shared apply UX
  replaces the "Coming in v1.1" badge on the five
  template-driven routine cards. Fail-soft codec handles
  malformed envelopes; the screen exposes Save / Update
  / Delete with `SettingsService.deleteRoutine`.
  `TemplatesScreen._onUse` now routes templates #17..#21
  through `RoutineApplyScreen` (template #16 keeps its
  dedicated `AddRoutineScreen`).
  Source: `lib/screens/routine_apply.dart`,
  `lib/routines/routine_template_payload.dart`, tests in
  `test/routines/routine_template_payload_test.dart` +
  `test/screens/routine_apply_screen_test.dart`.

- **v1.1e — offline `LocationMapPreview` for the location
  picker (SYS-084 / ADR-028).** A pure `CustomPaint`
  widget (5×5 grid + pin + geofence ring) replaces the
  planned `flutter_map` integration. No `INTERNET`
  permission; no `flutter_map`; no `latlong2`. The pin
  follows typed lat/lon in real time.
  Source: `lib/widgets/location_map_preview.dart`,
  tests in `test/widgets/location_map_preview_test.dart`
  (11 tests).

- **v1.1f — per-automation reliability badges (SYS-085).**
  A new `AutomationReliabilityBadge` widget surfaces the
  permission health of each routine row in the templates
  screen and the routines UI. Optimal → hide, degraded →
  warning-amber, unknown → info-outline. Location-triggered
  routines get the badge in v1.1f; calendar-triggered
  badges are deferred to v1.2 (see "Carry-over").
  Source: `lib/widgets/automation_reliability_badge.dart`,
  tests in `test/widgets/automation_reliability_badge_test.dart`
  (11 tests).

- **v1.1g — `PACKAGE_USAGE_STATS` permission + rationale UX
  (SYS-086 / ADR-030).** Probes Android's special-access
  permission via `AppOpsManager.unsafeCheckOpNoThrow` and
  deep-links to `Settings.ACTION_USAGE_ACCESS_SETTINGS`.
  Fire-and-forget from `PermissionService.init()` so the
  real-async method-channel call does not block the
  fake-async test zone. The Settings → Triggers tile
  re-probes on return (the only `PermissionKind` that
  re-probes rather than re-requests).
  Source: `lib/services/usage_stats_service.dart`, tests
  in `test/services/usage_stats_service_test.dart`
  (8 tests).

- **v1.1h — i18n scaffolding (ARB + `es` locale +
  `localizedApp` test helper) (SYS-087 / ADR-031).**
  `lib/l10n/app_en.arb` (~60 keys) is the source of truth;
  `app_es.arb` is the first translation (Spanish — smoke
  test locale, not a professional translation). Every
  user-facing string in `home.dart`, `settings.dart`, and
  `onboarding.dart` reads from `AppLocalizations.of(context)`.
  A new `test/support/localized_app.dart` helper wires the
  generated delegates so existing widget tests do not crash
  on the production `!` bang.
  Source: `lib/l10n/`, `test/support/localized_app.dart`,
  tests in `test/l10n/app_localizations_test.dart`
  (11 tests) + 9 screen-test files migrated through
  `localizedApp` + 1 integration test
  (`test/integration/app_localizations_wiring_test.dart`)
  asserting the production `DoItApp` root wires the delegate.

- **v1.1i — custom launcher icon + branded splash + bundled
  platform maintenance (SYS-088 / ADR-032).** Three
  hand-authored vector drawables replace the default
  Flutter launcher icon: background in brand purple
  `#FF6750A4`, foreground as a white sans-serif lowercase
  'd' glyph with a check dot, monochrome in pure white
  for Android 13+ themed icons. Both `drawable/` and
  `drawable-v21/` `launch_background.xml` files are
  rewritten as `<layer-list>` referencing a new named
  `@color/launch_background` (AAPT2 rejects inline colors
  in `drawable-v21/` `<item android:drawable>`). The
  pre-existing `drawable/ic_streak_notification.xml` gap
  (called out in `architecture_options.md:191-192`) is
  closed in the same PR. Version bumps `1.0.0+7` →
  `1.1.0+8`.
  Bundled platform maintenance: `compileSdk` 34 → 36,
  `minSdk` 28 → 30, `CallInterceptor.kt` migrates to
  `CallScreeningService.CallResponse.Builder`,
  `MainActivity.kt` passes the Activity explicitly via
  `setActivity(this / null)`.
  Source: `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
  + `drawable/ic_launcher_{background,foreground,monochrome}.xml`
  + `drawable/ic_streak_notification.xml` +
  `drawable[-v21]/launch_background.xml` +
  `values/colors.xml`. Tests in `test/app_icon_test.dart`
  (9 filesystem tests) + 2 new pin tests in
  `test/release_signing_test.dart`.
  Release artifact: `build/app/outputs/flutter-apk/app-release.apk`,
  75.1 MB, SHA1 `c3e0f6c6`, debug-signed (force-added past
  the `.gitignore` per the user's release-flow request).

## Canonical v1.1 sources

The matrix and the requirements are the right-side
verification of the v-Model. Per-sub-milestone:

- **Requirements + design rationale + test inventory:**
  [`requirements.md`](requirements.md) (SYS-080..SYS-088
  rows) + [`decision_record.md`](decision_record.md)
  (ADR-025..ADR-032 entries).
- **Traceability:**
  [`traceability_matrix.md`](traceability_matrix.md) top
  table (v1.1a..v1.1i rows) + workflow table
  (WF-039 Apply a template-based routine — generic flow).
- **Workflow:**
  [`workflows.md`](workflows.md) WF-039 (templates #17..#21
  apply flow), plus the WF-033..WF-038 v1.0 PR 2 rows that
  v1.1 supersedes.
- **Status:**
  [`implementation_status.md`](implementation_status.md)
  (v1.1a..v1.1i rows; 9 doc-only backfill commits appended
  the SHA of each feat commit).
- **Milestone summary:**
  [`plan.md`](plan.md) Milestone 8 (v1.1, shipped).
- **User-facing change log:**
  [`CHANGELOG.md`](../CHANGELOG.md) `[1.1.0]` block.
- **Operational concept:**
  [`conops.md`](conops.md) § Templates (the "Coming in
  v1.1" badge is gone; templates #17..#21 route through
  `RoutineApplyScreen`).

## Carry-over to v1.2

One v1.0-scope item was deferred past v1.1 and is
explicitly a v1.2+ candidate:

- **Per-automation reliability badge for calendar
  triggers.** v1.1f landed the badge for
  location-triggered routines only. Calendar-triggered
  routines still rely on a silent miss on revoked
  `READ_CALENDAR` (the row in `conops.md` was updated
  to reflect this). The `AutomationReliabilityBadge` is
  architected to extend to `TriggerCalendarEvent*` leaves
  with no new design work — a v1.2 follow-up PR can wire
  it through `_requiredPermissionForTrigger` once the
  team has bandwidth. Tracked in `open_questions.md` for
  the v1.2 cycle.

Two other items from the original v1.1 candidate list
are deliberately **out of v1.2** until further notice
(see [`plan.md`](plan.md) "Deferred to v1.2+"):

- **Wear OS / Android Auto target.** v1.1 stays phone-only.
- **iOS port.** v1.1 stays Android-only.

## Original hand-off context (historical)

The rest of this section is the original v1.0g-era
hand-off text, preserved for historical context. The
"in flight" / "must-fix" / "completion plan" language was
about the **pre-v1.1a working tree** at the v1.0g sign-off
moment. Every numbered item is closed.

The original document described:

- two git stashes (`stash@{0}` v1.0g release prep +
  `stash@{1}` v1.1 parallel work);
- 6 known issues blocking v1.1 (a compile error in
  `routine_config.dart:169`, 5 dispatch test failures,
  1 pre-existing info lint, a missing ADR-025, a missing
  `test/services/routine_config_test.dart`, missing
  v1.1 SYS-/ADR- rows);
- a 4-PR v1.1a..v1.1d completion plan + a v1.1d sign-off
  + version bump step.

Every one of those 6 known issues is closed by v1.1a..v1.1c.
The two stashes were settled: the v1.0g release-prep was
popped and committed as the v1.0g sign-off (`b938276`);
the v1.1 parallel work was re-committed across v1.1a +
v1.1b + v1.1h. The current `stash@{0}` is now a
duplicate of committed work (its 4 files match HEAD with
strict-superset diffs: `settings_service.dart` has 14
extra lines for v1.1d's `deleteRoutine` + locale
updates; `settings_test.dart` has 2 extra imports for
v1.1h's `localizedApp` wrap) and is safe to drop with
`git stash drop stash@{0}` if the user wants a clean
stash list. The drop is non-destructive because the
work is already in git history (commits `a33bf4c`,
`548e2b1`, `43c1b0c`).

— handoff from v1.1 cycle, closed 2026-06-22.
