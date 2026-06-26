# V-Model Development Plan

## Purpose

Use the V-model to keep the app honest: user needs and system requirements on
the left side, implementation at the bottom, and explicit verification on
the right side. do it is opinionated — strong reminders, no cloud, single
user — so the V must make those opinions visible at every stage. If a
document stops describing those opinions, it has drifted.

## V-Model Stages

| Left side artifact | Development activity | Right side verification |
| --- | --- | --- |
| User needs | Interviews with self, app-store research (Alarmy, Habit Now, StickK), review of why prior apps failed | User acceptance test (real-day run) |
| Concept of operations | Define actors, modes, scenarios, constraints | Operational scenario validation |
| Operational workflows | Define end-to-end user flows and edge cases | Workflow acceptance tests |
| System requirements | Functional, reliability (Doze/exact-alarm), privacy, platform constraints | System tests |
| Architecture | Flutter app, scheduling layer, mission engine, local DB, backup | Integration tests |
| Module design | Habit / person / mission / reminder models, service singletons | Unit / widget tests |
| Implementation | Flutter code and Android configuration | Static analysis, tests, builds |

The right side is **not optional**. Every requirement has a verification
target. If a requirement cannot be verified, it is not a requirement — it
is a wish. See [`traceability_matrix.md`](traceability_matrix.md).

## Initial Milestones

1. **V0.1 requirements baseline** ✅
   - Lock target user (single user, single device, personal use).
   - Lock target platform (Android only).
   - Lock proof model (3-mode hybrid: Soft / Strong / Auto).
   - Lock mission set (Shake-N, Type, Hold-tap, Math, Memory).
   - Lock schedule set (Fixed, Interval, Anchor, Day-of-week/month/annual).
   - Decide calling flow (notification → dialer pre-filled, no CALL_PHONE).
   - Decide backup (auto local, user-chosen folder).
   - Acceptance: every SYS- ID maps to a test or manual check.

2. **Feasibility prototype** (next)
   - Flutter app shell with theme, navigation, and onboarding.
   - Local DB (sqflite or drift) for habits, people, completions.
   - Reminder scheduling layer (AlarmManager + WorkManager fallback).
   - One mission end-to-end (Shake-N) to prove the engine.
   - One habit preset end-to-end (drink water) to prove the loop.
   - Acceptance: scheduled reminder fires, mission can be completed, log
     written, app survives reboot.

3. **Lean MVP (v0.1)**
   - All 4 habit presets (drink water, call person, morning routine, daily
     todo).
   - All 5 mission types.
   - Full-screen intent + home widget.
   - Wake-up anchor (manual + first-unlock).
   - Auto local backup.
   - do it model with rest days and per-habit + overall.
   - Acceptance: the user runs the app for 14 consecutive days with at
     least 3 of the 4 presets active and >70% completion rate.

4. **Validation**
   - Real-device 30-day run on the user's primary phone.
   - Verify Doze behavior with battery-saver + restricted background.
   - Verify reboot survival, timezone change, DST.
   - Verify backup restore round-trip.
   - Verify streak break rules across a missed rest-day window.
   - Decision gate: ship as personal-use build, or extend scope.

5. **Life-coach richness (v0.2) — committed 2026-06-14**
   - The 8 recommended workflows from
     [`v0_2_proposal.md`](v0_2_proposal.md): events, contact groups,
     time-window habits, edit / pause / test / bulk-complete,
     category + color + icon.
   - 16 new SYS-IDs (SYS-032..SYS-047). The contract is at
     [`v0_2_baseline.md`](v0_2_baseline.md).
   - Phased: v0.2a (foundation) → v0.2b (events) → v0.2c (groups) →
     v0.2d (UX delight) → v0.2e (14-day run #2).
   - Acceptance: 9 criteria in `v0_2_baseline.md`.

## Working Assumptions

- **Tech stack:** Flutter 3.44 / Dart 3.12, matching `board_box` and
  `card_box`. Reuse the 3-gate, lint rules, and CI scaffolding.
- **First release target:** Android only, Android 9+ (API 28+).
- **No cloud, no analytics, no account.** Local-first by mandate.
- **Reliability > features.** A scheduled reminder that fires 15 minutes
  late is a defect, not a quirk. See
  [`notification_reliability.md`](notification_reliability.md).
- **Honesty over gamification.** Streaks are earned, not inflated. The
  completion log is the source of truth; the streak number is derived
  from it.
- **No CALL_PHONE permission.** Calling reminders are user-confirmed by
  tapping a notification that opens the dialer pre-filled.
- **Permission-first UX.** Every platform interface is requested with a
  rationale screen, never on first launch silently.
- **Backup is the user's, not ours.** The export file lives in a folder
  the user picks. We never write to cloud storage automatically.

## V-Model discipline

When a doc changes, the doc on the opposite side of the V is suspect:

| If you change… | Also re-check… |
|---|---|
| `conops.md` (new actor, mode, or scenario) | `workflows.md`, `requirements.md`, `traceability_matrix.md` |
| `workflows.md` (new flow) | `requirements.md` (new SYS- ID), `traceability_matrix.md` |
| `requirements.md` (new or removed SYS- ID) | `traceability_matrix.md`, the matching test |
| `architecture_options.md` (new package or module) | `decision_record.md` (new ADR), `conops.md` (if user-visible) |
| `decision_record.md` (new ADR) | `conops.md`, `architecture_options.md` |
| `mission_catalog.md` (new or changed mission) | `requirements.md`, `mission_catalog.md` invariants, `test/missions/` |
| `notification_reliability.md` (new policy) | `requirements.md` (reliability SYS- IDs), `test/reminders/` |

If you ship a PR that changes a left-side doc but not its right-side
verification (or vice versa), say so in the commit message — the V is
intentionally incomplete for that slice.

## Milestone 6 — v0.5e-fix (ADR-017): the v0.5 release namespace defect

- **Date:** 2026-06-16.
- **Status:** accepted; commit `ce6dd83` is local; push
  to `main` is pending user approval.
- **The defect.** The v0.5a rename commit picked
  `applicationId = "com.doit.package"` and
  `namespace = "com.doit.package"` for the v0.5 release
  (mirroring the Dart package name `doit` with `package`
  as a namespace segment). The 3-gate was green (407/407)
  and the v0.5a pin tests asserted the value *exactly*. At
  v0.5e, `flutter build appbundle --release` failed:
  `Namespace 'com.doit.package' is not a valid Java
  package name as 'package' is a Java reserved keyword`
  (JLS §3.9).
- **The fix (commit `ce6dd83`, ADR-017).** Five surgical
  changes — `android/app/build.gradle.kts` (`com.doit` /
  `com.doit`), `AndroidManifest.xml`
  (`com.doit.FIRE_ALARM`),
  `android/app/src/main/kotlin/com/doit/package/` →
  `android/app/src/main/kotlin/com/doit/` via `git mv`
  with intermediate name `doit_tmp` (the target parent
  already exists), `test/release_signing_test.dart`
  rewrite + new regression-guard
  `isNot(contains('com.doit.package'))`, four doc files
  updated. The release AAB (61.0 MB) and APK (69.8 MB)
  rebuild successfully.
- **Lessons (project-wide).**
  - A green 3-gate does not mean a green build. The 3-gate
    is `dart format` + `flutter analyze --fatal-infos` +
    `flutter test`; the release AOT build is the user's
    hands-on step (ADR-013's lesson, restated). The
    v0.5e-fix is the third post-`flutter build appbundle`
    defect in this project (after v0.4b-release-fix and
    v0.4b-release-fix-2).
  - Pin tests for *invalid* values matter as much as pin
    tests for *exact* values. The v0.5a pin tests asserted
    `applicationId == "com.doit.package"` *exactly*; a
    future re-pick of the bad value would have passed the
    test. The v0.5e-fix regression guard
    (`isNot(contains('com.doit.package'))`) is the
    negative-space pin the project needed.
  - "Stylistic redundancy" in identifiers is a smell, not
    a virtue. The v0.5a rationale for `com.doit.package`
    was "the applicationId matches the Dart package name".
    The cost of the redundancy is a longer string to type
    and review, and the redundancy can hide a defect: a
    reviewer is more likely to approve a string that
    *looks intentional*. The shorter `com.doit` is harder
    to misread.
  - The Java reserved-keyword list (JLS §3.9) is a small,
    fixed list. `package` is the only one likely to
    appear in an Android `applicationId` or `namespace`
    segment. See ADR-017 for the full list.
- **Right-side gate.** `docs/v_model/v0_5_release_checklist.md`
  is updated; the v0.5e on-device verification is still
  pending the user attaching the SM-S918B.

## Milestone 7 — v1.0: Routines + Japan silent-mode + Do rename

- **Date:** 2026-06-21.
- **Status:** **in flight**. All six v1.0 work items
  (Phases A–F) are closed at the `ff56021` tip + the
  `7157707` status-doc commit. The release-prep PR
  (v1.0g, this milestone's sign-off commit) ships the
  version bump, CHANGELOG fill-in, and the left-side
  baseline + right-side gate docs.
- **What v1.0 ships.** Four user-facing themes on top of
  the v0.5 + v0.4 contract-closure foundation:
  - **Routines are first-class.** Every do / event /
    person gets a `Trigger` / `Condition` / `Action`
    automation list. Five trigger kinds (time of day,
    location enter / exit, device-state, calendar
    event, call incoming) are wired to a single
    `RoutineExecutor` (Phases C, D, E, F).
  - **Japan silent-mode is a real routine.** Template
    #16 routes to a working `AddRoutineScreen` that
    configures `CallInterceptor` via
    `ROLE_CALL_SCREENING` (Phase F).
  - **The Habit → Do rename finishes.** Class names,
    user-facing copy, and V-Model docs all move from
    "Habit / Streak" to "Do / Consecutive run". DB
    column names are unchanged to avoid a needless
    v2→v3 migration (Phase A; ADR-024).
  - **Templates carry the curated library.** 25
    templates seeded on first run, save-as-template
    UX, catalog UI (Phase B).
- **The 14 v1.0 commits.** `373913c` v1.0a.3 →
  `ff56021` v1.0f.2 + `7157707` status-doc log. The
  full list lives in
  [`implementation_status.md`](implementation_status.md)
  Phase log table.
- **The 7 v1.0 ADRs.** ADR-019 (CallScreeningService),
  ADR-019 follow-up (Japan routine UX + role opt-in),
  ADR-020 (template JSON envelope, `kTemplateFormatVersion = 1`),
  ADR-021 (geolocator for coarse-only geofence),
  ADR-022 (reactive device-state broadcasts, no
  polling), ADR-023 (reactive `ContentObserver` for
  calendar, no 5-min poll), ADR-024 (Habit → Do rename).
- **The 11 v1.0 SYS- IDs.** SYS-067 (25 templates
  seeded) → SYS-076 (PermissionKind.location coarse)
  + SYS-079 (call-screening role opt-in).
- **v1.0 release APK + on-device verification
  (v1.0h).** The user's hands-on step. Lighter than
  v0.5e because the `applicationId` did not change —
  the install is an upgrade, not a fresh install; no
  uninstall is needed. The five-step smoke:
  1. Launch the app; observe `1.0.0 (7)` in About.
  2. Tap a Phase B template; verify the catalog UI +
     save-as-template.
  3. Add a Phase C location routine; verify geofence
     fires.
  4. Add a Phase D device-state routine; verify the
     trigger fires.
  5. Tap a Phase F Japan template; verify the
     silent-mode routine runs during a real call.
- **Left-side doc.**
  [`v1_0_release_baseline.md`](v1_0_release_baseline.md).
- **Right-side gate.**
  [`v1_0_release_checklist.md`](v1_0_release_checklist.md).
- **Sign-off.** Pending the user's hands-on `v1.0h`
  pass. The checklist `§ Sign-off` line is the gate.

## Milestone 8 — v1.1: Polish + expansion (shipped)

- **Date:** 2026-06-21.
- **Status:** shipped. Nine sub-entries (v1.1a
  through v1.1i) landed across the v1.1 cycle; v1.1j
  is the doc-only sign-off that flips this milestone
  to `shipped` and finalises the CHANGELOG `[1.1.0]`
  block. The implementation rows are in
  `implementation_status.md` (rows v1.1a..v1.1j) and
  the CHANGELOG entries are in `CHANGELOG.md`
  `[1.1.0]` (`### v1.1a` through `### v1.1i`). SHA
  range: `<v1.1a SHA>` → `78b1267`; sign-off commit
  is the v1.1j SHA.
- **What shipped (v1.1a..v1.1i — 9 sub-entries, 152
  new tests, 741 → 893):**
  - **Routines — first-class value class + executor
    wiring.** v1.1a (SYS-080 / ADR-025) lands
    `RoutineConfig` (immutable value class with
    structural `==`, deterministic `hashCode`,
    `copyWith`, and a version-free `toJson` /
    `fromJson` codec) + per-template persistence
    under `doit.routine.<templateId>`. v1.1b wires
    `RoutineExecutor` to consume `SettingsService.routines`
    reactively via a `ValueNotifier` listener with
    a single exhaustive `is`-switch over all five
    `Action` leaves. v1.1c (SYS-082 / ADR-026) adds
    the `ActionOpenApp` leaf + `RoutineOpenAppRequest`
    value class + a passive `RoutineBanner` widget
    that drains FIFO. v1.1d (SYS-083 / ADR-027)
    routes templates #17..#21 through a generic
    `RoutineApplyScreen` (the "Coming in v1.1"
    badge on the Templates screen is removed).
  - **Location — offline map preview.** v1.1e
    (SYS-084 / ADR-028) adds a pure-`CustomPaint`
    `LocationMapPreview` widget — stylised grid +
    pin + geofence ring. No `flutter_map`, no
    `INTERNET` permission. The pin follows typed
    lat/lon coordinates in real time.
  - **Reliability — per-automation badges +
    `PACKAGE_USAGE_STATS` permission.** v1.1f
    (SYS-085 / ADR-029) adds an `AutomationReliability`
    enum + a pure `automationReliability(Automation, statuses)`
    function (exhaustive over the sealed `Trigger`
    hierarchy via `_requiredPermissionForTrigger`)
    + a 40×40 dp `IconButton` badge that hides
    itself for optimal automations, paints
    warning-amber for degraded, info-outline for
    unknown. v1.1g (SYS-086 / ADR-030) ships
    `UsageStatsService` (a `isGranted()` probe +
    `openSettings()` deep-link), extends
    `PermissionService` with `PermissionKind.usageStats`,
    adds the `<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"/>`
    manifest entry (cross-checked against the v0.1
    permission baseline), and routes the
    `PermissionSheet` "Allow" CTA to the Settings →
    Special access → Usage access deep-link (no
    system dialog — special-access permissions have
    no on-demand grant).
  - **i18n — ARB scaffolding + Spanish smoke-test
    locale.** v1.1h (SYS-087 / ADR-031) extracts
    ~60 user-facing strings to `lib/l10n/app_en.arb`
    (English is the source of truth) +
    `lib/l10n/app_es.arb` (Spanish smoke-test
    translation; NOT a professional translation).
    `flutter_localizations` + `intl` are added to
    `pubspec.yaml`. `flutter gen-l10n` (driven by
    a new top-level `l10n.yaml`) produces
    `AppLocalizations`, which is wired through
    `lib/main.dart` so every screen reads its copy
    from `AppLocalizations.of(context)` at runtime.
    10 existing screen-test files route through a
    new `test/support/localized_app.dart` helper
    that pre-installs the generated delegates on
    the test `MaterialApp`.
  - **Branding — custom launcher icon + splash +
    notification icon.** v1.1i (SYS-088 / ADR-032)
    ships three hand-authored vector adaptive-icon
    layers (background = solid brand purple
    `#FF6750A4`, foreground = white sans-serif
    lowercase 'd' + small filled check dot,
    monochrome = pure white for Android 13+
    themed icons). Splash drawables are rewritten
    as `<layer-list>` that paints the brand purple
    first (via a new `@color/launch_background`
    named color resource — AAPT2 rejects inline
    color values inside `drawable-v21/`) then
    layers the foreground vector centered on a
    96dp × 96dp box. The pre-existing
    `drawable/ic_streak_notification.xml`
    resource gap (called out at
    `architecture_options.md:191-192`) is closed
    in the same PR. Version bumped `1.0.0+7` →
    `1.1.0+8`. Bundled platform maintenance:
    `android/app/build.gradle.kts` compileSdk 34 →
    36 + minSdk 28 → 30; `CallInterceptor.kt`
    migrates from the removed `Call.Response.Builder`
    to `CallScreeningService.CallResponse.Builder`;
    `MainActivity.kt` passes the Activity
    explicitly via `setActivity(this / null)`
    because `FlutterEngine.activity` was removed in
    the modern embedding.
- **Why v1.1 is its own milestone, not bundled into
  v1.0.** v1.0 closed the four-theme foundation
  (Routines, Japan silent-mode, Do rename,
  Templates). Each v1.1 follow-up is a meaningful
  feature on its own; bundling them into v1.0 would
  have doubled the commit count and required two
  on-device verification cycles on the user's primary
  phone. v1.1 kept each follow-up PR-sized and got
  one APK install per feature.
- **Deferred to v1.2+ (open at v1.1 sign-off):**
  - **Per-density PNG regeneration from the master
    vector** (v1.1i leaves the legacy PNGs as the
    API 21..25 fallback; a v1.2 follow-up can
    regenerate them from the master vector if a
    pre-26 device needs on-brand visuals).
  - **`flutter_map` + cached tiles for
    `LocationMapPreview`** (v1.1e ships a pure
    `CustomPaint` body; the `flutter_map` swap
    needs the `INTERNET` permission, which is out
    of v1.1 scope).
  - **`TriggerForegroundApp` leaf** consuming
    `PermissionKind.usageStats` (v1.1g ships the
    permission flow; the actual consumer routine
    leaf is v1.2).
  - **`TriggerCallIncoming*` fold into
    `automation_reliability_badge`** once
    `RoleManager` is wired through
    `PermissionService` (v1.1f ships the per-
    automation badge minus the
    `TriggerCallIncoming*` arm; v1.2 candidate).
  - **Wearable / auto surface — Wear OS / Android
    Auto.** v1.1 stays phone-only. Wear OS target
    (companion tile vs standalone wear-app) is a
    product decision deferred to v1.2.
  - **iOS port.** v1.1 stays Android-only. iOS
    App Store icon assets + iOS-specific call-
    screening flow are v2.0+ candidates.
  - **Multi-user / multi-device sync.** Out of
    project scope; deferred to v2.0+.
  - **Professional Spanish translation.** v1.1h's
    `app_es.arb` is a smoke-test translation, not
    a professional one. A native-Spanish-speaker
    pass is a v1.2 follow-up.
- **Open questions (resolved during v1.1):**
  - Map provider choice → `flutter_map` with
    OpenStreetMap is **deferred to v1.2+** (the v1.1
    ship uses a pure-`CustomPaint` preview; see
    ADR-028). Picking `flutter_map` vs
    `google_maps_flutter` is now a v1.2 question.
  - i18n scope → **English + Spanish smoke-test
    only** (per the v1.1h author choice in
    ADR-031). A full Latin + CJK baseline is a
    v1.2+ question.
  - Wear OS target → **deferred to v1.2** (Wear OS
    / Android Auto was not picked for v1.1; the
    phone-only experience ships first).

## Milestone 9 — v1.2: Code-TODO closure (shipped)

- **Date:** 2026-06-23.
- **Status:** shipped. Thirteen sub-entries
  (v1.2a..v1.2m) landed across the v1.2 cycle; this
  milestone is the doc-only sign-off that flips the
  milestone to `shipped` and finalises the CHANGELOG
  `[1.2.0]` block. The implementation rows are in
  `implementation_status.md` (rows v1.2a..v1.2m) and
  the CHANGELOG entries are in `CHANGELOG.md` under
  `## [Unreleased]`.
- **Scope:** the code-TODO closure pass over the v1.1
  foundation. Every `TODO` (and the Phase A wiring gap
  it represented) is now either shipped, explicitly
  deferred to a v1.x follow-up with a SYS- ID, or
  tracked in [`feature.md`](../feature.md) §2-4.
- **Headline themes:**
  - **Wire-up** — the `NotificationService.show` /
    `dismiss` path (v1.2e), the routine `Action` leaves
    (`ActionFullscreen`, `ActionCallIntercept`, v1.2f),
    BOOT_COMPLETED coverage confirmation (v1.2g).
  - **UX completeness** — Person pauseUntil UI (v1.2f),
    DoFixed weekday display (v1.2f), DST transition
    banner (v1.2j), streak-recovery card (v1.2j),
    pre-notification 5-min / 1-min heads-up (v1.2j).
  - **Reliability disambiguation** — per-automation
    `AlertDialog` on tap (v1.2h),
    `AppLifecycleState.resumed` re-probe hook (v1.2i).
  - **Edit affordances** — hard delete with confirm
    (v1.2k), completion-log review + undo (v1.2m),
    uniform 3-wrong take-a-break across Math + Type
    (v1.2l).
- **V-Model artifacts (this milestone):**
  - `v1_2_release_baseline.md` (left-side) +
    `v1_2_release_checklist.md` (right-side gate).
  - `requirements.md` rows SYS-098..SYS-110 (appended
    in v1.2e..v1.2m).
  - `decision_record.md` rows ADR-033..ADR-041
    (appended in this sign-off commit; see the
    baseline for the per-ADR topics).
  - `implementation_status.md` rows v1.2a..v1.2m.
  - `CHANGELOG.md` `## [1.2.0]` block + a clean merge
    of the v1.2l / v1.2m entry pair (the pre-sign-off
    conflict at lines 1206-1303 is resolved).
  - `pubspec.yaml` → `1.2.0+9`; `lib/build_info.dart`
    mirrors; `test/release_signing_test.dart` mirror-
    pin assertions updated in lockstep.
- **Deferred (v1.x candidates, tracked in `feature.md`):**
  - Strong-mode full-screen hardening (the
    `USE_FULL_SCREEN_INTENT` permission on API 34+).
  - Action-side permission disambiguation in the
    `AutomationReliabilityDialog` (today the dialog
    covers trigger-side only).
  - `TriggerCallIncoming*` reliability arm once
    `RoleManager` is wired through `PermissionService`.
  - Native-Spanish-speaker translation of
    `lib/l10n/app_es.arb` (v1.1h's smoke-test locale
    is the only translation).
  - `google_maps_flutter` map tiles for
    `LocationMapPreview` (needs `INTERNET`).
  - Legacy `mipmap-*/ic_launcher.png` regeneration
    from the master vector.
  - Light-theme icon variant.
  - B9 — widget re-arm indicator (the project does
    not yet ship a home widget).
  - Home screen widget, iOS port, Wear OS, Argon2id
    backup upgrade, backup format v2 → v3 — all
    v1.x point-release candidates, NOT v2.0.
- **No new permissions, no `INTERNET`.** The v1.2
  cycle did not add any new `AndroidManifest.xml`
  permission entries; the closest call was the
  pre-existing `PACKAGE_USAGE_STATS` (v1.1g) which
  is the only "special-access" permission do it
  ships.
- **Right-side gate (this milestone):**
  [`v1_2_release_checklist.md`](v1_2_release_checklist.md).
  The sign-off line at the bottom of that doc is the
  moment the user accepts the build as the v1.2
  release. v1.2x is the user's hands-on on-device
  verification on the Android emulator (or a real
  SM-S918B device), the same shape as v0.5e / v1.0h
  / v1.1k.

## Milestone 10 — v1.3: Reliability + lifecycle hardening (shipped)

- **Date:** 2026-06-25.
- **Status:** shipped. Four sub-entries (v1.3a..v1.3d)
  landed across the v1.3 cycle; this milestone is the
  doc-only sign-off that flips the milestone to `shipped`
  and finalises the CHANGELOG `[1.3.0]` block. The
  implementation rows are in `implementation_status.md`
  (rows v1.3a..v1.3d) and the CHANGELOG entries are in
  `CHANGELOG.md` under `## [Unreleased]`.
- **Scope:** the reliability + lifecycle hardening pass
  over the v1.2 foundation. The three headline themes:
  - **Stats-side groundwork** (v1.3a / Phase 12) — the
    30-day completion-rate + 7-day bar chart on the Stats
    screen + the per-do `graceWindowOverride` factory.
  - **Reliability unification** (v1.3b / Phase 13) —
    `ReliabilityService.instance` is the unified
    `Stream<Reliability>` source-of-truth; the home-screen
    `ReliabilityBanner` and the settings page
    `_ReliabilityRow` both bind to
    `ReliabilityService.instance.notifier`; the
    `_kReliabilityGatedKinds` set is the policy gate.
  - **Special-access gating** (v1.3c / Phase 14) —
    `PermissionKind.fullScreenIntent` joins the gated set
    (now 5 elements); the Settings → Permissions screen
    gains a 5th `_PermissionTile`; the home banner's
    `onTap` deep-links the user to the tile; the manifest
    declares `<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"
    tools:ignore="ProtectedPermissions" />`.
  - **Strong-mode interruption end-to-end** (v1.3d /
    Phase 15 / Phase 6a proper) — `FullScreenActivity`
    Kotlin class lands; `showHabitMission` +
    `showRoutineOverlay` launch handlers on
    `doit/full_screen`; the strong-mode notification uses
    `setFullScreenIntent(openPi, true)`; the chain-level
    orchestrator (`MissionLauncherScreen`) walks the
    `MissionChain` end-to-end and appends the completion
    on `ChainPassed`. Closes `feature.md` §2.1 "Still
    deferred".
- **V-Model artifacts (this milestone):**
  - `v1_3_release_baseline.md` (left-side) +
    `v1_3_release_checklist.md` (right-side gate).
  - `requirements.md` rows SYS-112..SYS-114 (appended
    in v1.3b..v1.3d).
  - `decision_record.md` rows ADR-042..ADR-044
    (appended in v1.3b..v1.3d; see the baseline for
    the per-ADR topics).
  - `implementation_status.md` rows v1.3a..v1.3d.
  - `CHANGELOG.md` `## [1.3.0]` block + a clean
    alphabetised merge of the v1.3a..v1.3d sub-entries.
  - `pubspec.yaml` → `1.3.0+10`; `lib/build_info.dart`
    mirrors; `test/release_signing_test.dart` mirror-
    pin assertions updated in lockstep.
- **Deferred (v1.x candidates, tracked in `feature.md`):**
  - Action-side permission disambiguation in the
    `AutomationReliabilityDialog` (today the dialog
    covers trigger-side only).
  - `TriggerCallIncoming*` reliability arm once
    `PermissionService.callScreening` is fully probed.
  - Native-Spanish-speaker translation of
    `lib/l10n/app_es.arb` (v1.1h's smoke-test locale is
    the only translation).
  - `google_maps_flutter` for `LocationMapPreview`
    (would add `INTERNET`).
  - Legacy `mipmap-*/ic_launcher.png` regeneration from
    the master vector.
  - Light-theme icon variant.
  - B9 — widget re-arm indicator (the project does not
    yet ship a home widget).
  - Home screen widget, iOS port, Wear OS, Argon2id
    backup upgrade, backup format v2 → v3 — all v1.x
    point-release candidates, NOT v2.0.
  - Kotlin-side unit tests for `FullScreenIntentChannel.showHabitMission`
    / `showRoutineOverlay` + the new `FullScreenActivity`
    (the Dart-side tests cover the channel-call contract;
    the `compileDebugKotlin` gate catches syntax /
    null-safety / deprecation issues).
- **One new permission, no `INTERNET`.** The v1.3 cycle
  added one `AndroidManifest.xml` permission entry:
  `<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"
  tools:ignore="ProtectedPermissions" />` (v1.3c). The
  permission is **opt-in** — declining does NOT block any
  feature (the user keeps getting the notification
  fallback). The `tools:ignore` marker mirrors the v1.1g
  `PACKAGE_USAGE_STATS` precedent (ADR-030). The v1.3
  cycle did not add `INTERNET`; the `LocationMapPreview`
  remains a pure `CustomPaint` widget, and no new
  network call paths were added. The `ci grep rejects
  any import 'package:http'` rule is unchanged.
- **No DB migrations.** The `MissionChainExecutor.run`
  signature is unchanged (pure function); the
  `ReliabilityService` is a new singleton that sits next
  to the existing `PlatformAlarmScheduler.reliability`
  getter (now a thin pass-through); the new
  `FullScreenActivity` is a separate Android `Activity`
  (NOT a new `launchMode` on `MainActivity`) and
  therefore does not affect the existing channel
  registration in `MainActivity.configureFlutterEngine`.
- **Right-side gate (this milestone):**
  [`v1_3_release_checklist.md`](v1_3_release_checklist.md).
  The sign-off line at the bottom of that doc is the
  moment the user accepts the build as the v1.3
  release. v1.3x is the user's hands-on on-device
  verification on the Android emulator (or a real
  SM-S918B device), the same shape as v0.5e / v1.0h /
  v1.1k / v1.2x.

## Milestone 11 — v1.4: Home-screen widget + remaining parking-lot items

- **Date:** _TBD_ (sign-off pending v1.4a device
  verification).
- **Status:** stub (Milestone 11 placeholder; v1.4a
  lands as the first sub-entry, with v1.4b / v1.4c
  parking-lot candidates to follow).
- **Scope:** ship the first v1.x parking-lot items. The
  headline feature for v1.4a is the Android home-screen
  widget — the missing primary surface that closes
  `feature.md` §2.8 B9.
- **v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042** (the
  first sub-entry): a native `AppWidgetProvider` +
  `RemoteViews` over the `doit/widget` MethodChannel
  renders the user's first-active do, current streak,
  "Done" button, and unified `Reliability` badge. No
  `home_widget` pubspec dep (per ADR-018); no new
  `<uses-permission>`; no `wakelock_plus`. The
  cold-start fallback uses a `SharedPreferences` cache so
  the widget is never blank between OS process-kill and
  first Dart frame. See `CHANGELOG.md` v1.4a block for
  the long-form summary; `implementation_status.md` row
  v1.4a for the file-by-file breakdown; `feature.md` §2.8
  B9 for the deferral that v1.4a closes.
## Milestone 11 — v1.4: Home-screen widget + tile parity (shipped)

**Goal.** Two-phase cycle. Phase 28 ships the Android
home-screen widget (the missing primary surface). Phase 29
ships feature-parity on the in-app home tile so the user gets
the same affordance whether they look at the launcher or
open the app.

**Sub-entries:**

- **v1.4a — Android home-screen widget (Phase 28 / SYS-115 /
  ADR-045 / WF-042).** First time the app surfaces a habit
  on the home screen without opening the app. New: native
  `AppWidgetProvider` + `RemoteViews` (ADR-045 explicitly
  rejects `home_widget` pubspec dep); `lib/widget/`
  sub-folder (`widget_state_locator`, `widget_state_builder`,
  `widget_service`); `AndroidManifest.xml` receiver
  registration. Strong-mode "Done" deep-links to the
  existing `MissionLauncherScreen` (SYS-114). No new
  `<uses-permission>`, no new pubspec dep. **Status: shipped**
  (PR #33, awaiting merge to `main`).
- **v1.4b — In-app tile streak + Done button (Phase 29 /
  SYS-116 / ADR-046 / WF-043).** Mirror the v1.4a widget's
  surface on the home tile. `_HabitTile` becomes a
  `StatefulWidget` (`_HabitTileState`); a new `_DoStreakBadge`
  sub-widget renders the streak + "day streak" subtitle; a
  new `_DoneButton` sub-widget rewires the existing
  `IconButton` to call `markDoDone(...)` (soft/auto) or push
  `MissionLauncherScreen` (strong). New pure-Dart helpers
  `lib/screens/home_tile_streak.dart` + `lib/screens/home_tile_completion.dart`.
  4 new ARB keys. **Status: shipping in this PR.**
- **v1.4c candidates (parking lot).** Tile "Skip today"
  button (consumes a rest-day budget); tile streak history
  visualization (7-day sparkline); tile edit / delete
  affordance (currently long-press select-mode only);
  widget small / large variants, widget config activity,
  widget list (scrolling), widget deep-link to a specific
  do. See `feature.md` §4.
- **v1.4c candidates** (parking lot, TBD): iOS / Wear OS
  widget surfaces (each needs a separate platform port
  + a shared widget spec); native Spanish translator
  (smoke-test translation only today — see `feature.md`
  §2.4).
- **Right-side gate:** the user runs `flutter build
  appbundle --release` + installs on an Android 13+ device
  + drags the widget from the launcher's widget picker +
  verifies streak number renders + taps Done + verifies
  completion appends + revokes a gated permission +
  verifies badge flips to degraded. Mirrors the v0.5e /
  v1.0h / v1.1k / v1.2x / v1.3x user-side on-device
  checks. Kotlin side is untested at the unit level per
  the established 5-native-channel precedent.
v1.4c — In-app tile Skip today button + rest-day
  budget indicator (Phase 30 / SYS-117 / ADR-047 / WF-044).**
  Extend `_HabitTile` with a `_SkipButton` sub-widget
  (Icons.bedtime / bedtime_outlined; tap calls `markDoSkipped(...)`
  in `try/catch on NoRestDaysRemaining` → `homeTileSkipSuccess`
  / `homeTileSkipBudgetExhausted` SnackBar); a new `_BudgetCaption`
  sub-widget renders inside `_DoStreakBadge` (FutureBuilder
  over `budgetRemainingForDo(...)`; "X / Y rest days left" /
  "No rest days left" / `SizedBox.shrink()` mid-fetch). The
  `_DoneButton`'s post-tap SnackBar now branches on
  `_isSkippedToday` for `homeTileSkipAlready` vs
  `homeTileAlreadyDoneTooltip`. New pure-Dart helpers
  `lib/screens/home_tile_skip.dart` +
  `lib/screens/home_tile_budget.dart`. Shared
  `proofModeTag(DoProofMode)` helper extracted to
  `lib/do/proof_mode_tag.dart` (consolidates the v1.4b
  inline copies in `do_repository.dart` +
  `home_tile_completion.dart`; `mission_launcher.dart` left
  untouched due to its different defensive `'unknown'`
  contract). 6 new ARB keys. **Status: shipping in this PR.**

**Constraints.**

- **No new pubspec deps.** v1.4a rejects `home_widget` per
  ADR-045. v1.4b + v1.4c are pure-Dart + a single ARB
  addition.
- **No new `<uses-permission>`.** The widget runs without a
  foreground service. The tile is a stateless surface.
- **No DB migrations.** The widget reads via the existing
  `doit/widget` MethodChannel + the existing
  `DoRepository.listAll()`. The tile reads via the existing
  `CompletionLogService.instance.listForHabit` +
  `CompletionLogService.instance.listRestDaysInMonth`. The
  rest-day budget was already a `RestDayBudgets` Drift
  snapshot table in v0.5, and the `CompletionSource.restDay`
  enum value already existed; v1.4c is pure-Dart + a
  stateful tile extension + ARB additions.
- **Strong-mode completion write ownership.** Both surfaces
  (widget strong-mode "Done" + tile strong-mode "Done")
  delegate to `MissionLauncherScreen` (SYS-114), which owns
  the `CompletionLogService.append` call for strong-mode
  completions. The tile's `markDoDone` helper writes only
  for soft/auto do.
- **Single source of truth for the completion write.** Both
  surfaces call the same `CompletionLogService.append(
  habitId, day, source: CompletionSource.manual,
  proofModeAtTime: <soft|strong|auto>)` shape. The append
  already dedupes on `(habitId, day, source)` — a
  double-tap inserts one row, not two. The rest-day write
  is `completionLog.append(habitId, day, source:
  CompletionSource.restDay, proofModeAtTime: ...)` and
  shares the same dedupe key — a Skip-tap and a Done-tap
  on the same day resolves to a single row (the rest-day
  row wins, since it is written first).
- **Rest-day budget exhaustion is a soft signal.** A user
  who hits `restDaysPerMonth == 0` mid-month sees a SnackBar
  ("No rest days left this month.") and the tile continues
  to render the streak + Done button normally. The user's
  existing streak is NOT broken — `ConsecutiveCounter.compute`
  only checks the budget at *write* time, not at *compute*
  time.
- **Right-side gate (this milestone):** user's hands-on
  `flutter build appbundle --release` + on-device install +
  add a do with 3+ consecutive completions + verify the
  streak renders on the home tile + tap the tile's Done
  button + verify the completion appends + verify the
  SnackBar + tap the tile's Skip button + verify the
  rest-day row appends + verify the budget caption
  decrements. The widget's verification path is the same
  shape (add the widget, verify the streak renders, tap
  "Mark done", verify the streak advances after re-render).

**v1.4d — In-app tile Undo today's completion (Phase 31 /
SYS-118 / ADR-048 / WF-045).** Close the per-tile-undo
parking-lot entry from v1.4c by giving the user a single
tap to revert an accidental Done or Skip tap on today's
tile. Mirrors the `CompletionLogSection` (SYS-108 /
WF-025) review-and-undo flow but with one fewer tap
(no scroll, no list, no per-row delete icon — just a
confirm dialog on the tile itself). The existing
`CompletionLogService.deleteById(rowId)` (v1.2m) is
re-used verbatim; no new Drift methods, no new
`lib/services/`. A single pure-Dart helper lands in
`lib/screens/home_tile_undo.dart`:

- `undoToday({required Do activeDo, required DateTime
  asOf, required CompletionLogService completionLog})`
  fetches `completionLog.listForHabit(activeDo.id)`,
  filters rows whose `day == DateTime(asOf.year,
  asOf.month, asOf.day)` (local-midnight comparison —
  same convention as `markDoDone` + `markDoSkipped`), and
  on the happy path calls `completionLog.deleteById(row.id)`
  exactly once. The helper returns an `UndoResult` sealed
  value class with two factories:
  `UndoResult.removed(rowId, source)` carries the deleted
  row's id + source; `UndoResult.nothingToUndo()` for the
  no-row path (defensive — the dialog is gated on
  `_isResolvedToday == true`, but the DB is the source of
  truth and a concurrent app-tile rebuild could leave a
  dangling flag).
- `_HabitTileState` grows a `_UndoButton` sub-widget
  (`Icons.undo`, tooltip `homeTileUndoToday`, sits
  between `_SkipButton` and `_DoneButton`). Visibility
  is gated on `_isResolvedToday == true` — the tile is
  "resolved" for the day via either Done (`_isCompletedToday`)
  or Skip (`_isSkippedToday`). The undo affordance
  disappears for fresh tiles, eliminating the temptation
  to undo a row that does not exist.
- Tap opens an `AlertDialog` titled `homeTileUndoConfirm`
  with body `homeTileUndoConfirmBody`. The confirm
  callback calls `undoToday(...)`. On the `removed` branch
  the tile flips `_isCompletedToday`/`_isSkippedToday`
  (whichever was true) back to `false` and shows the
  `homeTileUndoSuccess` SnackBar. On the `nothingToUndo`
  branch shows the `homeTileUndoNotToday` SnackBar
  (defensive copy — the dialog is gated, but the DB is
  the source of truth).
- No new pubspec dep; no new `<uses-permission>`; no
  Android-side changes. Pure-Dart + a stateful tile
  extension + 5 new ARB keys (`homeTileUndoToday`,
  `homeTileUndoConfirm`, `homeTileUndoConfirmBody`,
  `homeTileUndoSuccess`, `homeTileUndoNotToday`). The
  ARB parity test catches Spanish drift automatically.
- **Right-side gate (v1.4d):** user's hands-on `flutter
  build appbundle --release` + on-device install + add a
  do + tap Done → tap Undo → confirm → verify the
  completion row disappears from the edit screen's
  `CompletionLogSection` + the streak decrements by 1 +
  the tile re-renders with the Undo button hidden +
  tap Skip → tap Undo → confirm → verify the rest-day
  row disappears + the budget caption re-increments by
  1. The widget side already has a "Done" affordance
  that writes via the same `CompletionLogService.append`
  shape — the widget's per-cell undo is a v1.4e
  candidate (parked).

### Sub-entry status (Milestone 11)

- **v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042** —
  Android home-screen widget: shipped (PR #33, commit
  `18452af` on main).
- **v1.4b / Phase 29 / SYS-116 / ADR-046 / WF-043** —
  In-app tile streak + Done button: shipped (PR #34,
  commit `8b9e2c2` on main).
- **v1.4c / Phase 30 / SYS-117 / ADR-047 / WF-044** —
  In-app tile Skip today + rest-day budget: shipped
  (PR #35, commit `252191c` on main).
- **v1.4d / Phase 31 / SYS-118 / ADR-048 / WF-045** —
  In-app tile Undo today's completion: shipped (PR #37,
  commit `34b6940` on main).
- **v1.4e / Phase 32 / SYS-119 / ADR-049 / WF-046** —
  In-app tile 7-day streak history sparkline: _this PR_.

**Milestone 11 v1.4 — fully shipped on `main`.** Version
bump + V-Model docs (CHANGELOG `[1.4.0]` block +
`implementation_status.md` sign-off row + `v1_4_release_baseline.md`
+ `v1_4_release_checklist.md` + `plan.md` Milestone 11 flip
+ `feature.md` closeout) land in the v1.4 sign-off PR on
`chore/v1.4-sign-off`. The user's hands-on `release(v1.4)`
debug-signed APK commit is the final sign-off line (mirrors
the v1.1i pattern at `222f860`).
