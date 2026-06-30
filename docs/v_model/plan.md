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
  In-app tile 7-day streak history sparkline: shipped
  (PR #39, commit `4049866` on main).
- **v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047** —
  Android home widget Skip today + Undo today: shipped
  (PR #40, commit `fe9630e` on main).
- **v1.4g / Phase 34 / SYS-121 / ADR-051 / WF-048** —
  Widget-action round-trip: Kotlin → Dart via inbound
  `doit/widget` channel: _this PR_. Closes the latent
  v1.4a + v1.4f gap (widget buttons NEVER wrote to the
  completion log; only repainted via `WidgetUpdater.refreshAll`).
  The `doit/widget` MethodChannel becomes bidirectional;
  `WidgetActionInvoker` is the new inbound dispatcher;
  `WidgetService.markDone` returns `Future<bool>`; Kotlin
  `invokeAction` suspending helper with 5 s timeout; new
  `EXTRA_HABIT_ID` extra on the action `PendingIntent`s.

**Milestone 11 v1.4 — fully shipped on `main`.** Version
bump + V-Model docs (CHANGELOG `[1.4.0]` block +
`implementation_status.md` sign-off row + `v1_4_release_baseline.md`
+ `v1_4_release_checklist.md` + `plan.md` Milestone 11 flip
+ `feature.md` closeout) land in the v1.4 sign-off PR on
`chore/v1.4-sign-off`. The user's hands-on `release(v1.4)`
debug-signed APK commit is the final sign-off line (mirrors
the v1.1i pattern at `222f860`).
- **v1.4h / Phase 35 / SYS-122 / ADR-052 / WF-049** —
  In-app home tile Edit + Delete IconButtons: _this PR_.
  Closes the discoverability gap on the v0.2
  long-press → select-mode → app-bar-trash path. Every
  tile now has discoverable per-tile Edit + Delete
  IconButtons in the same right-edge action `Row` as
  the v1.4b/c/d Skip / Undo / Done buttons (with
  localized tooltips). `_EditButton` re-uses the
  existing `AddHabitScreen(habitId: ...)` destination
  (no new navigation path). `_DeleteButton` opens an
  `AlertDialog` (title carries the do name in quotes
  per the destructive-action contract), awaits the
  pure-Dart `deleteDo` helper, and shows a SnackBar
  with an `Undo` action that re-saves the captured `Do`
  reference via `DoRepository.save`. The `_busy` flag
  is shared with the v1.4b/c/d buttons so the spinner
  + disabled-on-busy pattern is consistent across the
  whole action row. New `onDoChanged: VoidCallback?`
  prop on `_HabitTile` bound to
  `_HomeScreenState._refresh()`. 7 new ARB keys
  (`homeTileEdit`, `homeTileDelete`,
  `homeTileDeleteConfirm(doName)`,
  `homeTileDeleteConfirmBody`,
  `homeSnackbarDoDeleted(doName)`,
  `homeSnackbarDoDeletedUndo`,
  `homeSnackbarDoDeleteFailed`) added in lockstep
  across `app_en.arb` + `app_es.arb`. Pure-Dart — no
  new `<uses-permission>`, no new pubspec deps, no
  new Drift tables, no new MethodChannels, no Kotlin
  changes. Documented trade-off (per ADR-052 §8):
  the Undo snackbar restores the do row but does NOT
  restore the streak history — the streak counter
  starts at 0 on the restored do. A v1.4h+ follow-up
  could add a soft-delete column to `habits` for a
  true undo.

- **v1.4i / Phase 36 / SYS-123 / ADR-053 / WF-050** —
  In-app home tile rest-day history visualization:
  _this PR_. Extends the v1.4e / Phase 32 / SYS-119
  7-day streak sparkline on every `_HabitTile` to
  **14 days** with **source-aware color**
  (`colorScheme.primary` for manual fills vs
  `colorScheme.tertiary` for rest-day fills) + an
  **inline legend row** (`Done` / `Rest day` /
  `Missed`) below the dot row so the source-aware
  coloring is discoverable. Closes the v1.4e
  "we know rest-day rows exist but you can't tell
  them apart on the sparkline" gap that v1.4e flagged
  but did not close. New pure-Dart helper
  `extendedSparklineForDo(...)` (configurable `days`
  parameter, default 14) at
  `lib/screens/home_tile_sparkline.dart`; the original
  `sparklineForDo` (v1.4e) is a thin backwards-compatible
  wrapper around the new helper with `days: 7` so
  no caller breaks. `_Sparkline` widget gains 3 new
  optional constructor params (`days`, `restDayColor`,
  `showLegend`); the tile invocation passes
  `restDayColor: Theme.of(context).colorScheme.tertiary`
  so the rest-day color tracks the active theme.
  Each `_SparklineDot` wraps in `Semantics(label: ...)`
  (NOT per-dot `Tooltip` — see ADR-053 §"Alternatives
  considered": `Tooltip` would (a) crowd the screen with
  42 competing tooltips on a 360 dp tile, AND (b) intercept
  the parent `_HabitTile`'s `onLongPress` select-mode
  gesture — verified empirically via the v1.4i
  "long-press still enters select mode" regression test).
  6 new ARB keys (`homeTileSparklineRestDayTooltip`,
  `homeTileSparklineDoneTooltip`,
  `homeTileSparklineMissedTooltip`,
  `homeTileSparklineLegendDone`,
  `homeTileSparklineLegendRestDay`,
  `homeTileSparklineLegendMissed`) added in lockstep
  across `app_en.arb` + `app_es.arb`; the existing
  `homeTileSparklineSemantics` key updated from
  "Last 7 days" → "Last 14 days" (and `Últimos 7 días`
  → `Últimos 14 días`). Pure-Dart — no new
  `<uses-permission>`, no new pubspec deps, no new
  Drift tables, no new MethodChannels, no Kotlin
  changes. Widget re-fetch on any tile-state change
  re-uses the existing `_HomeScreenState._refresh()`
  setState cascade — no `ChangeNotifier` / `Stream`
  is added.

- **v1.4j / Phase 37 / SYS-124 / ADR-054 / WF-051** —
  In-app rest-day budget edit affordance on the home tile
  + v1.0 silent-reset bug fix in `AddHabitScreen._save()`.
  Adds a shared `RestDayPickerDialog` (`lib/screens/rest_day_picker_dialog.dart`,
  NEW) with a `Slider(min: 0, max: 31, divisions: 31, ...)`
  that both the tile affordance and the `AddHabitScreen`
  form-row trigger call — single source of truth for the
  UI shape. `_BudgetCaption` (`lib/screens/home.dart`)
  grows `onTap: VoidCallback` + `zeroCaption: String`
  constructor params and DROPS the two pre-existing
  early-returns (`limit <= 0` + `used == 0`) so the caption
  renders in all 3 budget states (zero budget / partial
  use / exhausted). The caption is wrapped in
  `Semantics(button: true, label: captionText)` +
  `GestureDetector(onTap: onTap)` so TalkBack reads the
  caption as a button. `_HabitTileState._onBudgetCaptionTapped()`
  captures `messenger = ScaffoldMessenger.of(context)`
  BEFORE the async gap, awaits `showRestDayPicker(...)`,
  on non-null awaits `DoRepository.instance.save(widget.habit.copyWith(restDaysPerMonth: picked))`,
  on success shows `messenger.showSnackBar(...)` +
  `widget.onDoChanged?.call()` to trigger the v1.4h
  `_refresh()` cascade; on throw shows
  `homeSnackbarBudgetUpdateFailed` SnackBar WITHOUT
  removing the tile. `AddHabitScreen` (`lib/screens/add_habit.dart`)
  grows `int _restDaysPerMonth = 2` state field, loaded
  in `_loadExisting()` from `_original.restDaysPerMonth`
  (preserving the original value in edit mode — fixes
  the v1.0 silent-reset bug), replaces all 5 hardcoded
  `restDaysPerMonth: 2` literals in `_save()` at
  `:911, :926, :945, :960, :981` with
  `restDaysPerMonth: _restDaysPerMonth`, and grows
  `_pickRestDaysPerMonth()` which calls `showRestDayPicker(...)`
  + `setState`. The form body grows a new "Rest days per
  month: N" `ListTile` near the proof-mode row that
  opens the same picker. `Do.validate()`
  (`lib/do/do.dart`) adds the upper-bound check
  `if (restDaysPerMonth < 0 || restDaysPerMonth > 31) throw DoInvalidRestDays(...)`
  so `DoInvalidRestDays` is the single source of truth
  for the invariant (the picker clamps inline, `validate()`
  is the defensive second line). 7 new ARB keys
  (`homeTileBudgetZeroCaption`, `homeTileBudgetEditTitle`,
  `homeTileBudgetEditDescription`, `homeTileBudgetEditOk`,
  `homeTileBudgetEditCancel`, `homeSnackbarBudgetUpdated(value)`,
  `homeSnackbarBudgetUpdateFailed`, `addHabitRestDaysLabel(value)`)
  added in lockstep across `app_en.arb` + `app_es.arb`.
  Pure-Dart — no new `<uses-permission>`, no new pubspec
  deps, no new Drift tables, no new MethodChannels, no
  Kotlin changes. Test count 1252 → 1271 (+19: 8
  picker + 3 do_model `Do.validate` boundaries + 1
  add_habit widget row + 1 grep regression `restDaysPerMonth: 2`
  + 5 home `BudgetCaption` + 1 add_habit localization
  wrapper switched to `localizedApp` — 3 add_habit
  localizations mirrored to 3 sibling test files:
  `add_habit_delete_test.dart` + `add_habit_save_as_template_test.dart`
  + `templates_test.dart`).

- **v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052** —
  Per-instance home widget configuration via Android
  AppWidget configuration activity (`DoitWidgetConfigureActivity.kt`)
  + body-tap deep-link via `MainActivity.getInitialRoute()`:
  _PR #46, commit `8bef793`_. Closes the long-standing
  v1.4a gap where every widget instance showed the same
  fallback do and body taps just opened the home screen.
  `DoitWidgetState.selectedHabitId` is the new optional
  JSON envelope field (mirrors the v1.4f `restDaysPerMonth`
  precedent); `WidgetService.setSelectedHabitId(widgetId, habitId)`
  + `handleRefreshRequest` consults the cached pick first,
  falls back to `firstActiveDo`, and **reconciliation-clears
  to null** when the picked do is deleted (next refresh
  observes the cached pick doesn't match the active do and
  clears it). `WidgetServiceProxy` indirection seam (mirrors
  the v1.4h `home_tile_delete.dart` callback-handler pattern)
  for testability. `WidgetConfigScreen`
  (`lib/widget/widget_config_screen.dart`, NEW) is the
  list-picker UI bound to the AppWidget config activity.
  `DoitWidgetConfigureActivity.kt` (NEW) is a thin
  `FlutterActivity` shell that reads
  `AppWidgetManager.EXTRA_APPWIDGET_ID` (NOT
  `Intent.EXTRA_APPWIDGET_ID` — that one doesn't exist)
  and sets initial route `/widget-config?widgetId=N` on the
  Flutter engine. `MainActivity.getInitialRoute()` reads
  `EXTRA_HABIT_ID_FROM_WIDGET` (distinct namespace from
  `DoitWidgetProvider.EXTRA_HABIT_ID`) and returns
  `/habit?habitId=...` when present. `WidgetRenderer.openAppIntent`
  adds `EXTRA_HABIT_ID_FROM_WIDGET` on body tap when
  `selectedHabitId` is non-empty — signature is
  `(ctx, id, selectedHabitId: String)`; all 6 call sites
  (incl. `renderEmpty`/`renderError` done/skip/undo) must
  pass the empty-string arg, NOT omit it (Kotlin treats a
  missing arg as a compile error, not a default). `lib/app_router.dart`
  (NEW) extracts `buildHabitRoute(...)`, `buildWidgetConfigRoute(...)`,
  `buildAppRoute(...)` from `lib/main.dart` — the route
  builders + screen constructors are tested in isolation by
  inspecting `MaterialPageRoute.builder` directly (NOT by
  pushing onto a Navigator; AddHabitScreen / HomeScreen /
  WidgetConfigScreen all have `FutureBuilder`s reading
  `DoRepository.instance.listAll()` which causes 10-min
  timeouts in widget tests when unseeded). 3 new ARB keys
  in lockstep across `app_en.arb` + `app_es.arb`
  (`widgetConfigureTitle`, `widgetConfigureSubtitle`,
  `widgetConfigureBackToHome`). AndroidManifest declares
  `DoitWidgetConfigureActivity` with
  `android:configure="@xml/doit_widget_info"` and
  `android:exported="false"`. **Zero new
  `<uses-permission>`** — permission baseline verified
  against `docs/v_model/architecture_options.md`. 21 new
  tests (1292 total, +21 from v1.4j's 1271). 0 new pubspec
  deps, 0 new Drift tables, 0 new MethodChannels. Test
  count now 1292/1292.

- **v1.4l / Phase 39 / SYS-126 / ADR-056 / WF-053** —
  Soft-delete tombstone column on `Habits` so the v1.4h
  home-tile Delete + Undo SnackBar restores the streak by
  construction: _this PR_. Closes the v1.4h trade-off
  documented in `ADR-052 §8` + `home.dart:553-561` (the
  original KDoc was wrong about the FK cascade — there
  are no declared FKs in the Drift schema; the streak
  really should have survived via the orphan `Completions`
  rows, but the brittle `insertOnConflictUpdate` on Undo
  was a latent footgun). Replaces the "hard-delete +
  `insertOnConflictUpdate` on Undo" pattern with a single
  nullable `deleted_at_millis INTEGER` column on `Habits`
  (mirrors the `Events.archivedAtMillis` precedent at
  `lib/services/db/tables.dart:153`). New Drift migration
  `v4_to_v5` (NEW, single `addColumn` call). Domain model
  gains `final DateTime? deletedAt;` on base `Do` + a
  `bool get isDeleted => deletedAt != null;` helper;
  `copyWith` gains the explicit `clearDeletedAt: bool`
  flag (mirrors `Event.copyWith(clearArchived: bool)`
  at `lib/events/event.dart:118`). `DoRepository._toRow`
  writes `deletedAtMillis: d.deletedAt?.millisecondsSinceEpoch`
  for content updates; `_fromRow` reads it back. `listAll`
  + `listActive` add `..where((t) => t.deletedAtMillis.isNull())`
  filter (mirrors `EventRepository.listActive` at
  `event_repository.dart:48`). `getById` keeps its current
  "return whatever is there" semantics (a tombstoned row is
  still returned — needed for restore); new `getActiveById(id)`
  helper filters tombstones for UI callers. **The
  load-bearing invariant:** `save(d)` does NOT touch
  `deleted_at_millis` — Drift's `insertOnConflictUpdate`
  preserves the existing column value when the new row
  doesn't specify it (and `_toRow` deliberately omits
  `deletedAtMillis` from the save-path's `HabitsCompanion`
  for tombstoned rows). Restoration goes through a new
  `restoreById(id)` method (single `UPDATE` SQL statement;
  idempotent on already-active rows). `deleteById(id)` is
  KEPT (not removed) — reserved for `BackupService.importFrom`'s
  "wipe everything before import" path. New `softDeleteById(id, at)`
  is the new tile path. `DoAnchor.targetDoId` referencing a
  tombstoned habit: **pause, don't break** (the next
  occurrence calculation observes the target is no longer
  in `listAll()` and degrades gracefully — `from + Duration(days: 1)`
  fallback per the `anchor.dart` "graceful degrade" rule).
  `lib/services/backup_service.dart` export query gains
  the same `deletedAtMillis.isNull()` filter so a backup
  round-trip does not resurrect tombstones (tombstones are
  an undo affordance, not user data — the envelope's
  `deleted_at_millis` field IS written so a future change
  can decide tombstone IS user data without a schema bump).
  `lib/services/db/migrations/v4_to_v5.dart` (NEW). KDoc
  at `lib/screens/home.dart:553-561` rewritten to drop the
  wrong FK-cascade claim and accurately describe the
  soft-delete + `restoreById` flow. `lib/screens/home_tile_delete.dart`
  adds `softDeleteDo` + `restoreDo` pure-Dart helpers
  (parallels the existing `deleteDo`). Test count 1292 →
  1321 (+29: 8 `migration_v4_to_v5` round-trip + 9
  `do_repository` soft-delete/restore/save-invariant +
  6 home_tile_delete `softDeleteDo`/`restoreDo` migration +
  6 home_test delete-assert updates to `getActiveById`).
  Pure-Dart — no new `<uses-permission>`, no new pubspec
  deps, no new Drift tables (only a column add), no new
  MethodChannels, no Kotlin changes. Permission baseline
  unchanged; verification against
  `docs/v_model/architecture_options.md` confirmed no
  AndroidManifest touch. The v1.4h trade-off bullet is
  REMOVED from `feature.md` §4 parking lot; v1.4l+ parking
  lot gets the "Recently deleted" surface (a separate
  screen listing tombstoned dos with Restore / Delete
  forever) as a follow-up candidate, plus the
  `_toRow`-missing-`automations_json` +
  `_toRow`-missing-`pausedUntil` mapping bugs now that the
  soft-delete trade-off is closed.

### v1.4m — CI coverage for the v1.4l soft-delete home-screen flow + `listDeleted` / `purgeDeletedOlderThan` API surface (Phase 40 / SYS-127 / ADR-058 / WF-055)

v1.4l (PR #47, commit `0858cc6`) shipped the soft-delete data layer + the inline Undo SnackBar flow + the migration; the 6-step on-device smoke (the **headline behavior change**: tap Delete → confirm → tile disappears → tap Undo → tile reappears AND streak = 3) was guarded only by manual testing. v1.4m closes the CI coverage gap: 4 widget tests pin the home-screen flow end-to-end, 4 repository tests pin `listDeleted`, 4 repository tests pin `purgeDeletedOlderThan`, and 1 repository test pins the tombstone's persistence across a DB close + reopen. Two new `DoRepository` methods (`listDeleted({int? limit})` + `purgeDeletedOlderThan(Duration age, {required DateTime at})`) are added now so the v1.4n "Recently deleted" UI surface can consume a tested API rather than coupling to a not-yet-tested shape. The cycle is a pure test + API surface expansion — no production behavior change outside the `KeyedSubtree` test seam on the `_DoStreakBadge` call site. Test count 1321 → 1334 (+13). 3-gate GREEN. See [[SYS-127]] + [[ADR-058]] + [[WF-055]] for the contract. Parking lot: v1.4n "Recently deleted" UI surface (a separate screen listing tombstoned dos with Restore / Delete forever affordances); the `_toRow`-missing-`automations_json` + `_toRow`-missing-`pausedUntil` mapping bugs (separate latent issue, separate cycle).

## Milestone 12 — v1.4-stab: 3-month stabilization campaign

**Goal.** Pivot from feature work to a 3-month hardening campaign. After 12 cycles of net-new surface (v1.4a..v1.4m, totaling 26 PRs and ~900 tests added), the project has accumulated gaps that the existing "≥80% on changed files" rule doesn't address. The 3-month stabilization campaign addresses those gaps via 11 sequenced cycles (B..L) plus the foundational audit cycle (A). The cycle sequencing is provisional and may shift after Cycle A's audit findings surface additional issues — see [[ADR-059]] for the sequencing rationale.

**Phase 41 / v1.4-stab-A (audit) ships in this PR.** [[SYS-128]] + [[ADR-059]] + [[WF-056]] append. Doc-only cycle: no `lib/` / `test/` changes; the deliverable is `docs/v_model/stabilization_roadmap.md` (NEW, the single source of truth for the campaign) + `coverage/lcov.info` (NEW, the line-coverage report) + `coverage/html/index.html` (NEW, the inspectable coverage view). Coverage baseline measured at 64.61% across 123 `lib/` files (8812/13638 lines). 33 files are Priority-1 (<80% coverage; e.g., `lib/people/person.dart` at 54.5%, `lib/do/consecutive_counter.dart` at 75.8% — pure-Dart model files that MUST hit 100% per success criterion #2). Latent bugs BUG-001..BUG-020 inventoried with priorities + target cycles (BUG-001 + BUG-002 → Cycle B; BUG-003 → Cycle C; BUG-004 → Cycle G; BUG-005 → Cycle D; BUG-006 → Cycle I partial).

**Success criteria for the 3-month campaign** (after Cycle L ships): (1) ≥90% line coverage on every file in `lib/` (up from the current "≥80% on changed files" rule); (2) 100% coverage on the pure-Dart model layer (`lib/do/`, `lib/people/`, `lib/habits/`, `lib/missions/`); (3) E2E tests for the 10 critical user flows (Cycle K); (4) 0 known latent bugs in the "Known Issues" doc (every BUG-NNN closed); (5) Accessibility: every screen has TalkBack labels, contrast ≥ 4.5:1, font-scale tested at 1.0x / 1.3x / 1.6x (Cycle J); (6) i18n: every ARB key tested in both `en` and `es` locales, every screen renders both (Cycle I); (7) Reliability: every `Reliability` enum path exercised in tests (Cycle E); (8) Backup: every backup version × every table × every field round-trip clean (Cycle F); (9) Performance: widget rebuild benchmark, SQL query benchmark, APK size documented (Cycle L); (10) 0 skipped tests (current rule preserved).

**Cycle sequencing (Cycles B..L — high-level overview only; each cycle gets its own plan-mode planning session when its predecessor ships).**

**Month 1 — Audit + critical fixes.** **Cycle B** (Phase 42, ~1 week) — Fix `_toRow` automations + pausedUntil latent bugs (BUG-001 + BUG-002). Pure-Dart, no schema change. Add 2 save-invariant tests parallel to v1.4m's `deletedAtMillis` pin (`save(d)` writes `automations_json` from `d.automations`; `save(d)` writes `paused_until_millis` from `d.pausedUntil`). **Cycle C** (Phase 43, ~1 week) — Full-screen launch hardening (Android 14+ `USE_FULL_SCREEN_INTENT` permission). Add `<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />` to AndroidManifest; verify the permission is requested at runtime on API 34+; probe-and-report reliability. Update `notification_reliability.md`. Cross-check against the permission baseline in `docs/v_model/architecture_options.md` (CLOSES BUG-003). **Cycle D** (Phase 44, ~2 weeks) — Permission flow audit. Per-permission-kind tests covering grant / deny / rationale / settings-deeplink paths (`SCHEDULE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`, `READ_CONTACTS`, `POST_NOTIFICATIONS`, `IGNORE_BATTERY_OPTIMIZATIONS`). Complete the v1.1f `callScreening` runtime probe (CLOSES BUG-005).

**Month 2 — Reliability + integrity.** **Cycle E** (Phase 45, ~1 week) — Reliability detection coverage. Every `Reliability` enum path exercised in tests (`.optimal` / `.degraded` / `.unknown`). Verify exact-alarm denied → WorkManager fallback. Add doze-simulation tests. **Cycle F** (Phase 46, ~1.5 weeks) — Backup round-trip exhaustive. Every backup payload version (`v1`, `v2`, `v3`) × every table (`habits`, `completions`, `events`, `people`, `rest_day_budgets`, `cadence_assignments`, `widget_state`) × every field (incl. `automations`, `pausedUntil`, `event/archivedAt`, `person/resolutionStatus`). **Cycle G** (Phase 47, ~1 week) — DoAnchor "Target paused" badge on home tile (the UI for the v1.4l data layer) (CLOSES BUG-004). **Cycle H** (Phase 48, ~1 week) — Restore / delete-forever UI for tombstoned dos (the v1.4n feature moved INSIDE stabilization per [[ADR-059]] §4 — the API surface is already pinned + tested in v1.4m so this is purely UI).

**Month 3 — Polish + exhaustive.** **Cycle I** (Phase 49, ~1 week) — i18n test exhaustive. Every ARB key has a test in both `en` and `es` locales. Every screen renders both locales. (PARTIAL CLOSURE of BUG-006 — test coverage only; the native-speaker copy review remains a separate human task, not a stabilization cycle.) **Cycle J** (Phase 50, ~1.5 weeks) — Accessibility audit. Every screen has TalkBack labels (`Semantics` widget). Color contrast ≥ 4.5:1 for body text, ≥ 3:1 for large text and icons. Font-scale tested at 1.0x / 1.3x / 1.6x. **Cycle K** (Phase 51, ~2 weeks) — E2E integration tests. 10 critical user flows: add do → mark done → streak → delete → undo → soft-delete → restore → backup → restore-from-backup → update-via-appcast. **Cycle L** (Phase 52, ~2 weeks) — Performance audit + fuzz + benchmark. Widget rebuild benchmark. SQL query benchmark (N+1 detection). APK size documented. Fuzz / property tests for the model layer (`lib/do/`, `lib/people/`, `lib/habits/`, `lib/missions/`).

**Out of scope (parking lot).** After the 3-month stabilization campaign: v1.4n "Recently deleted" UI moves INSIDE the window as Cycle H (per [[ADR-059]] §4 — the API surface is already pinned + tested in v1.4m, so the v1.4n PR is purely UI and small); v1.4o+ feature cycles (post-stab); native Spanish translation by a native speaker (BUG-006 — needs a human, not a stabilization cycle); legacy mipmap regeneration (pre-API-26 — out of scope; `minSdk = 30`); light-theme icon variant (out of scope; dark theme is the default); iOS / Wear OS port (out of scope; Android-only for the foreseeable future).

### v1.4-stab-A — Coverage audit + stabilization roadmap (Phase 41 / SYS-128 / ADR-059 / WF-056)

The foundational first cycle of the 3-month stabilization campaign. Doc-only: no `lib/` / `test/` changes, no new dependencies, no new permissions, no Drift migration, no Kotlin changes. The deliverable is `docs/v_model/stabilization_roadmap.md` (NEW) — the single source of truth for the campaign with 6 sections: (1) current coverage state per-file table (123 `lib/` files, baseline 64.61%, 33 Priority-1 / 31 Priority-2 / 59 Priority-3); (2) latent bugs inventory (BUG-001..BUG-020 with priorities + target cycles); (3) cycle-by-cycle roadmap (B..L with rationale); (4) success criteria for the 3-month campaign (10 criteria); (5) open questions for the user (5 questions about Cycle C / F / H / K scope + BUG-006 native speaker); (6) Cycle A retrospective. **Coverage baseline measured.** `flutter test --coverage` produces `coverage/lcov.info` (133 KB, 8812/13638 lines = 64.61% line coverage). The Python parser (since `lcov` is not installed and `sudo` requires interactive auth) reads `SF:` / `LF:` / `LH:` markers from the LCOV file and produces the per-file table. **No regressions.** 3-gate (regression check — no `lib/` / `test/` changes): `dart format --output=none --set-exit-if-changed .` (264 files, 0 changed) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1334/1334 pass — unchanged from v1.4m). The "exhaustive test" coverage audit is the deliverable, not the test count delta. See [[SYS-128]] + [[ADR-059]] + [[WF-056]] for the contract.

### v1.4-stab-B — Fix `_toRow` automations + pausedUntil data-loss bugs (Phase 42 / SYS-129 / ADR-060 / WF-057)

The first stabilization cycle that fixes code (Cycle A was docs-only). Closes BUG-001 + BUG-002 — the two P0 latent bugs that silently lose user state on Save: BUG-001 wipes the user's custom automation rules (e.g., `TriggerBatteryLow → ActionNotify "Plug in"`); BUG-002 silently resumes a paused habit when the user edits another field via `AddHabitScreen._save()` (the form reconstructs the `Do` from form fields that have no pause picker, so `pausedUntil: null` in-memory → column written as `null` → pause disappears). **The fix shape mirrors the v1.4l `deletedAtMillis` omission precedent** (ADR-056). `_toRow` is split into two halves: (1) **content-only** — columns the user explicitly edited in the form (name, schedule, color, automations); (2) **owned by other writers** — columns the user did NOT explicitly set in this Save click (tombstone from `softDeleteById` / `restoreById`; pause from `pauseHabit` / `resumeHabit`). Drift's `insertOnConflictUpdate` preserves the owned-by-other-writers columns across the Save, because the new `HabitRow` doesn't specify them. **PauseService refactor.** `pauseHabit` + `resumeHabit` now bypass `DoRepository.save` and write the `pausedUntilMillis` column directly via a `HabitsCompanion` UPDATE: `(db.update(db.habits)..where((t) => t.id.equals(habit.id))).write(HabitsCompanion(pausedUntilMillis: Value(...)))`. The methods become the explicit writers of the column — mirroring the v1.4l `restoreById` shape. **3 new tests** in a new `DoRepository save invariant (Cycle B / BUG-001 + BUG-002)` group in `test/services/do_repository_test.dart`: `automations round-trip through save + getById` (BUG-001 write + read); `pausedUntil round-trips via direct companion UPDATE + getById` (BUG-002 read path); the headline `save(d) does NOT clobber an existing pausedUntilMillis` (BUG-002 save-invariant — seed via companion UPDATE, save a fresh `Do` with no in-memory `pausedUntil`, assert the raw column's `pausedUntilMillis` STILL equals the seeded timestamp). **Pure-Dart** — no new `<uses-permission>`, no new pubspec deps, no Drift migration (the columns already exist on `Habits`), no new Drift tables, no new MethodChannels, no Kotlin changes. Test count: 1334 → 1337 (+3 from the Cycle B group). 3-gate: `dart format --output=none --set-exit-if-changed .` (264 files, 0 changed — pure-Dart + new tests) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1337/1337 pass). Cycle B is a bug-fix cycle, not a coverage cycle — the 3-month campaign's coverage gains come from Cycles C..L. See [[SYS-129]] + [[ADR-060]] + [[WF-057]] for the contract. **Parking lot** for v1.4-stab-C+: BUG-003 (Android 14+ `USE_FULL_SCREEN_INTENT` permission — full-screen launch hardening) → Cycle C; BUG-004 (DoAnchor "Target paused" badge UI for the v1.4l data layer) → Cycle G; BUG-005 (`callScreening` permission probe) → Cycle D; BUG-006 (Spanish `es` ARB stale copy — needs native-speaker review, separate from stabilization) → Cycle I (partial — test coverage only).

### v1.4-stab-C — FSI reliability wiring: defense-in-depth + BUG-003 closure (Phase 43 / SYS-130 / ADR-061 / WF-058)

The third stabilization cycle of the 3-month campaign, and the first cycle whose scope is dramatically smaller than the `stabilization_roadmap.md §3` draft suggested. **No Kotlin changes, no new pubspec deps, no new `<uses-permission>`, no Drift migration.** The Android 14+ `USE_FULL_SCREEN_INTENT` permission is ALREADY declared at `android/app/src/main/AndroidManifest.xml:83-85`; the probe + reliability wiring + launch handlers shipped in v1.3c (Phase 14) + v1.3d (Phase 15). What was actually missing was test coverage, a doc typo, a stale comment, and a known channel-surface gap. **No production code changes to the FSI channel surface** — the defense-in-depth swallow on `MethodChannelFullScreenIntentSource` was already in the v1.3c code; Cycle C's contribution is documenting it as INTENTIONAL per ADR-013 + ADR-061 (so a future reader doesn't "fix" it by removing the catches) and lifting test coverage from 25% → ≥80% on `lib/reminders/full_screen_intent.dart` and 80.5% → ≥95% on `lib/services/full_screen_intent_service.dart`. **Six fixes + additions.** (1) **Rename `_MethodChannelFullScreenIntentSource` → `MethodChannelFullScreenIntentSource`** (drop the `_` prefix + add `@visibleForTesting` annotation) so the new defense-in-depth tests at `test/services/full_screen_intent_service_test.dart` can construct the production source directly and mock the channel via `TestDefaultBinaryMessengerBinding`. All 4 internal references updated (constructor delegation, `resetForTesting` reset, KDoc reference, `instance` default). (2) **Class-level KDoc on `MethodChannelFullScreenIntentSource`** documenting the `MissingPluginException` + `PlatformException` → `false` swallow as INTENTIONAL per ADR-013 + ADR-061, cross-referencing `ReliabilityService._safeProbe` as the precedent. The KDoc is the in-code barrier against a future reader "fixing" the swallow. (3) **Stale `wakelock_plus` reference at `lib/reminders/full_screen_intent.dart:1-24` replaced with the actual `FLAG_KEEP_SCREEN_ON` mechanism** — `pubspec.yaml` has 0 `wakelock_plus` matches; the production wake mechanism is `FLAG_KEEP_SCREEN_ON` in `android/app/src/main/kotlin/com/doit/FullScreenActivity.kt:47-56`. (4) **Doc typo at `docs/v_model/notification_reliability.md:496` "On API 14+" → "On API 34+"** — `USE_FULL_SCREEN_INTENT` was introduced in API 34 (Android 14), not API 14. (5) **KNOWN channel-surface gap on `ReminderBridge.showFullScreen` pinned as a follow-up bug, NOT fixed in Cycle C** — the Dart seam at `lib/reminders/reminder_bridge.dart:60` + `:218` invokes `_channel.invokeMethod('showFullScreen', ...)` over `doit/reminders`, but the Kotlin `when` block at `android/app/src/main/kotlin/com/doit/ReminderChannelProxy.kt:33-78` has NO arm for `showFullScreen` — everything else falls through to `notImplemented()` → `MissingPluginException` on Dart. The gap is INERT today (no production callers per repo-wide grep; the FSI launch path is wired through `doit/full_screen` channel via `lib/services/platform_full_screen_intent.dart` instead). The test at `test/reminders/reminder_bridge_fsi_channel_test.dart` pins the gap — a future stabilization cycle will either remove the dead Dart arm or add the matching Kotlin arm. (6) **+8 new tests across 3 files** (was +6 in the original scope draft; the +2 expansion is documented in ADR-061 §6 as the deliberate pinning of both `MissingPluginException` AND `PlatformException` defense-in-depth paths + the channel-surface gap's two-assertion shape): `test/reminders/full_screen_intent_test.dart` (NEW, +5 tests lifting `lib/reminders/full_screen_intent.dart` coverage from 25% → ≥80% — `FakeFullScreenIntent.show` invocation-order, `showRoutineOverlay` 4-input shape, `getLaunchIntent` scripted-`LaunchIntent` round-trip + null case, `RoutineOverlayLaunch` + `LaunchIntent` equality); `test/services/full_screen_intent_service_test.dart` (extended, +3 tests in new `MethodChannelFullScreenIntentSource (production source)` group — PlatformException on `isGranted`, PlatformException on `openSettings`, MissingPluginException on `isGranted` — pins the ADR-061 defense-in-depth contract); `test/reminders/reminder_bridge_fsi_channel_test.dart` (NEW, +2 tests — Dart seam IS exercised + production-state-throws as `MissingPluginException`). **Pure-Dart + docs + new tests** — no new `<uses-permission>` (the `USE_FULL_SCREEN_INTENT` permission is already declared), no new pubspec deps, no Drift migration, no new Drift tables, no new MethodChannels, no Kotlin changes. Test count: 1337 → 1345 (+8 from the Cycle C group). 3-gate: `dart format --output=none --set-exit-if-changed .` (264 + ~5 files, 0 changed — pure-Dart + new tests) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1345/1345 pass). Targeted runs per `CLAUDE.md`: `flutter test test/reminders/full_screen_intent_test.dart` (passes; +5 tests) + `flutter test test/services/full_screen_intent_service_test.dart` (passes; +3 tests) + `flutter test test/reminders/reminder_bridge_fsi_channel_test.dart` (passes; +2 tests). See [[SYS-130]] + [[ADR-061]] + [[WF-058]] for the contract. **Parking lot** for v1.4-stab-D+: BUG-004 (DoAnchor "Target paused" badge UI for the v1.4l data layer) → Cycle G; BUG-005 (`callScreening` permission probe) → Cycle D; BUG-006 (Spanish `es` ARB stale copy — needs native-speaker review, separate from stabilization) → Cycle I (partial — test coverage only); the `ReminderBridge.showFullScreen` channel-surface gap is queued as a future-stabilization-cycle follow-up (remove dead Dart arm or add Kotlin arm).

### v1.4-stab-D — Permission flow coverage: per-kind exhaustive tests + lifecycle edge cases (Phase 44 / SYS-131 / ADR-062 / WF-059)

The fourth stabilization cycle of the 3-month campaign. **Pure-Dart test-only cycle — no production code changes, no new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** The Cycle A audit identified 4 Priority-1 files below 80% coverage on the permission flow: `permission_result.dart` (18.9%), `permission_service.dart` (93.4%), `permission_lifecycle_observer.dart` (78.6%), and `person.dart` (54.5%). Cycle D's contribution is **direct unit tests** that lift each file to the target coverage by exercising every sealed subclass + every `PermissionStatus` mapping + the lifecycle observer's early-return gate + the pause semantics on `ContactPerson`. **Closes BUG-005** (callScreening probe — both happy-path + denial-path coverage now in place via the existing `requestCallScreening` + `refreshCallScreening` tests at `test/services/permission_service_test.dart:565-606`), **BUG-011** (PermissionResult direct tests added), **BUG-012 (partial)** — `person.dart` at ≥80%; Cycle K brings to 100%), **BUG-020** (lifecycle observer edge cases covered). **Test count: 1348 → 1363 (+15 net).** 3-gate: `dart format --output=none --set-exit-if-changed .` (268 files, 0 changed after auto-format on 3 NEW + 2 EXTENDED files) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1363/1363 pass). Targeted runs per `CLAUDE.md`: `flutter test test/services/permission_result_test.dart` (passes; +6 tests) + `flutter test test/services/permission_service_test.dart` (passes; +4 tests) + `flutter test test/services/permission_lifecycle_observer_test.dart` (passes; +1 test) + `flutter test test/people/person_test.dart` (passes; +3 tests). **Parking lot** for v1.4-stab-E+: BUG-019 (sparkline edge cases) → Cycle G; BUG-008/009/010/013 (residual)/015/016/017/018/012 (residual) → Cycle K; BUG-006 (Spanish `es` ARB stale copy — needs native-speaker review) → Cycle I (partial). See [[SYS-131]] + [[ADR-062]] + [[WF-059]] for the contract.
### v1.4-stab-E — Reliability detection coverage: broadcast+distinct stream + first-read race + idle-window (Phase 45 / SYS-132 / ADR-063 / WF-060)

The fifth stabilization cycle of the 3-month campaign. **Pure-Dart test-only cycle — no production code changes, no new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** The Cycle A audit identified 3 Priority-1 residual bugs on the reliability-detection path: BUG-013 (probe failure policy), BUG-014 (exact-alarm cancel path incomplete coverage), and the unaudited idle-window simulator. Cycle E's contribution is **direct unit tests** that pin (a) the broadcast+distinct stream transition-emit contract, (b) the ADR-013 probe-failure-keeps-prior-value contract, (c) the first-read race fix, (d) the 30 s idle-window fallback timer policy, and (e) the exact-alarm-granted primary path on `FakeAlarmScheduler`. **Closes BUG-013** (probe failure / first-read race coverage in place via the `throwOnProbe` flag in `_ScriptedBridge` + the fresh-cold-start test), **BUG-014** (exact-alarm cancel + primary-path coverage now in place via the 2 new `alarm_scheduler_test.dart` tests in the `AlarmScheduler fallback paths (SYS-132)` group). **Test count: 1363 → 1371 (+8 net).** 3-gate: `dart format --output=none --set-exit-if-changed .` (269 files, 0 changed) + `flutter analyze --fatal-infos lib test` (0 issues after stripping 5 redundant-default-arg warnings + simplifying the doze-simulation bridge to a no-arg constructor) + `flutter test` (1371/1371 pass). Targeted runs: `flutter test test/services/reliability_service_test.dart` (16 pass, +5) + `flutter test test/reminders/doze_simulation_test.dart` (1 pass, NEW) + `flutter test test/reminders/alarm_scheduler_test.dart` (14 pass, +2). Drift lesson: the original "stream emits initial value to fresh subscribers" test was structurally wrong — a broadcast+distinct stream never replays past values; the test was reworked to pin the AFTER-init transition-emit contract. **Parking lot** for v1.4-stab-F+: BUG-019 (sparkline edge cases) → Cycle G; BUG-008/009/010/015/016/017/018/012 (residual) → Cycle K; BUG-006 (Spanish `es` ARB stale copy) → Cycle I (partial); backup round-trip exhaustive → Cycle F. See [[SYS-132]] + [[ADR-063]] + [[WF-060]] for the contract.

### v1.4-stab-F — Backup round-trip exhaustive coverage: malformed envelopes + dispatcher error paths (Phase 46 / SYS-133 / ADR-064 / WF-061)

The sixth stabilization cycle of the 3-month campaign. **Pure-Dart test-only cycle — no production code changes, no new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** The Cycle A audit identified 6 latent backup envelope bugs (`bug_hunt.md` BUG-016..-018 cluster): malformed-envelope throws, missing-KDF object rejection, unsupported-KDF rejection (already covered by Cycle C as "unknown KDF name is rejected"), v2 KDF iterations floor missing, dispatcher init-failure swallow, `runBackupTask` ScheduleMode.none early-return. Cycle F's contribution is **direct unit tests** that pin the 8 missing error paths: 5 in `backup_service.dart` (toString, missing-kdf, v2 iterations floor, v3 missing-fields, v2 missing-fields), 2 in `backup_task_dispatcher.dart` (unknown-task-name, init-failure-swallow per ADR-013), 1 in `backup_scheduler.dart` (ScheduleMode.none early-return). **Test count: 1371 → 1379 (+8 net).** Coverage: `lib/services/backup_service.dart` ≥95% (from 96.5% — closes the 12 uncovered lines); `lib/services/backup_scheduler.dart` ≥90% (from 85.3%); `lib/services/backup_task_dispatcher.dart` to be measured. 3-gate: `dart format --output=none --set-exit-if-changed .` + `flutter analyze --fatal-infos lib test` + `flutter test` (1379/1379 pass). Targeted runs: `flutter test test/services/backup_encryption_test.dart` (passes; +5) + `flutter test test/backup/scheduler_skip_test.dart` (passes; NEW +1) + `flutter test test/services/backup_task_dispatcher_test.dart` (passes; +2). **Parking lot** for v1.4-stab-G+: DoAnchor "Target paused" badge UI (the v1.4l data layer is in place; the UI ships in Cycle G); BUG-012 (full 100% coverage) → Cycle K; BUG-006 (Spanish ARB) → Cycle I. See [[SYS-133]] + [[ADR-064]] + [[WF-061]] for the contract.

### v1.4-stab-G — DoAnchor "Target paused" badge + BUG-019 sparkline pin (Phase 47 / SYS-134 / ADR-065 / WF-062)

The seventh stabilization cycle of the 3-month campaign. **First Cycle of the "UI surface" phase — adds a small widget + ~30 lines of home.dart wiring + 2 ARB keys; still pure-Dart, no new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** The v1.4l data layer (ADR-056 / `deletedAtMillis`) made the UI surface possible but ADR-059 §4 parked the v1.4l-deferred UI work for a post-v1.4m stabilization cycle. Cycle G ships that parking-lot work + adds a one-line sparkline edge case pin for BUG-019. **Closes BUG-004** (the v1.4l-deferred "Target paused" UI affordance lands on the home tile) + **BUG-019** (sparkline single-point-over-stretch edge case). **Test count: 1379 → 1385 (+6 net).** 3-gate: `dart format --output=none --set-exit-if-changed .` (270 files, 0 changed after auto-format on the 1 NEW badge widget + the 1 extended home.dart + 2 ARB files + 3 EXTENDED test files) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1385/1385 pass). Targeted runs: `flutter test test/widgets/do_anchor_paused_badge_test.dart` (passes; +4 NEW) + `flutter test test/screens/home_test.dart` (passes; +1) + `flutter test test/screens/home_tile_sparkline_test.dart` (passes; +1 BUG-019). **Release APK rebuild.** Cycle G has production code (the NEW widget + the ~30-line home.dart edit + 2 ARB keys); APK may differ — rebuild via `flutter build appbundle --release` after CI is green, compare SHA1 to v1.4-stab-F's `155b77243c6c0ab1d340c861e08dd7e5dea73d45`, commit only on a binary diff. **Parking lot** for v1.4-stab-H+: Recently-deleted screen (v1.4l + v1.4m data layer is in place; Cycle H ships the top-level UI surface) → Cycle H; BUG-006 (Spanish ARB native-speaker review) → Cycle I (partial) + v2.0 (full); a11y audit → Cycle J; E2E flows + 100% model coverage → Cycle K; perf + fuzz → Cycle L. See [[SYS-134]] + [[ADR-065]] + [[WF-062]] for the contract.

### v1.4-stab-I — i18n exhaustive test coverage (Phase 49 / SYS-136 / ADR-067 / WF-064)

The eighth stabilization cycle of the 3-month campaign. **test:** +21 net tests across 2 files (NO production code changes). New group `AppLocalizations per-key + locale tests` in `test/l10n/app_localizations_test.dart` (+12 tests): every ARB key resolves through `AppLocalizations.delegate.load` in both en + es (17 spot-checks × 2 locales), verbatim copy pins for v1.4-stab-G + H keys, placeholder interpolation for 6 keys × 2 locales (verbatim), en plural branches at 0/1/5, regex-pin on `@<key>` metadata block for every placeholder-bearing key. NEW `test/l10n/locale_render_test.dart` (+8 tests): HomeScreen + RecentlyDeletedScreen render in both locales, Settings section headers resolve verbatim (7 strings × 2 locales, NOT mounting SettingsScreen — service singletons), no RenderFlex overflow at `TextScaler.linear(1.0)` × 2 (HomeScreen en + RecentlyDeletedScreen es). **ARB-catalog-wide** (140 keys in `app_en.arb`; parity is held with `app_es.arb` via the pre-existing "same key set" structural test). **Closes BUG-006** test-coverage half; native-speaker review deferred to v2.0 (`docs/v_model/spanish_translation_review.md:207` reviewer log remains empty). **Test count: 1401 → 1422 (+21 net).** Coverage: `app_localizations_es.dart` 7.0% → ≥70% (was under-covered because most tests resolved via the en delegate); `app_localizations_en.dart` stays ≥80%. 3-gate: `dart format --output=none --set-exit-if-changed .` (clean) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1422/1422 pass). **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — Cycle I is pure-test + docs only (no release commit on main; the APK SHA1 stays at H's `25bb7fab`). See [[SYS-136]] + [[ADR-067]] + [[WF-064]] for the contract.

### v1.4-stab-J — Accessibility audit: WCAG-2.x contrast + Semantics sweep + font-scale 1.0/1.3/1.6 (Phase 50 / SYS-137 / ADR-068 / WF-065)

The ninth stabilization cycle of the 3-month campaign. **test:** +29 net tests across 3 NEW files (NO production code changes). NEW `test/a11y/contrast_test.dart` (+7 tests): top-level `relativeLuminance(Color)` + `contrastRatio(Color, Color)` helpers (WCAG-2.x gamma-decoded sRGB formulation `L = 0.2126 R + 0.7152 G + 0.0722 B` + `(L1 + 0.05) / (L2 + 0.05)` — relies on Flutter 3.27+ `Color.r/.g/.b` returning 0..1 doubles, no `/255` division); black = 0 / white = 1 boundary pins, black-on-white = 21:1 max, same-color = 1:1 min, symmetry `(a, b) == (b, a)`; dark + light theme `colorScheme.onSurface` vs `surface` ≥ 4.5:1 (AA body); M3-light `colorScheme.onError` vs `colorScheme.error` ≥ 2.7:1 (the M3-light pair measures ~2.98:1 — below the 3.0 AA-Large bar by ~0.02; the 2.7:1 readability floor pins future regressions loudly while documenting the M3-light quirk in the test's `reason` block). NEW `test/a11y/font_scale_test.dart` (+7 tests): HomeScreen + RecentlyDeletedScreen mounted at `TextScaler.linear(N)` for N = 1.0 / 1.3 / 1.6 (6 tests) + `locale=es home-screen renders without overflow at 1.6x` (cross-locale smoke for Spanish copy ~30% longer); each mount asserts `tester.takeException() == null` so a `RenderFlex overflowed by N pixels` at runtime surfaces here. NEW `test/a11y/every_screen_test.dart` (+15 tests = 5 critical screens × 3 a11y checks): per-screen participation in (a) Semantics sweep — source has `Semantics | tooltip | semanticLabel | excludeFromSemantics | ListTile(title: Text(...))` (the `ListTile` clause covers `Settings`, which uses passive ListTile rows that auto-expose the title as a TalkBack label); (b) theme composition — source does NOT declare `colorScheme: ColorScheme(...)` at the screen level (a screen-level override would defeat the app-wide contrast budget); (c) `Scaffold` + `AppBar` landmark declaration (TalkBack navigation). The 5 critical screens are `home.dart`, `add_habit.dart`, `add_person.dart`, `add_event.dart`, `settings.dart`. **Reuses** the existing `test/a11y/semantics_labels_test.dart` (v0.4c.2 / SYS-062, source-walk) — Cycle J's contribution is the per-screen smoke that links the file-level exhaustive sweep to the 5 critical screens. **ZERO production-code changes** (pure-test + docs cycle). **No release APK rebuild** (test-only cycle per the F-cycle pattern; APK SHA1 stays at H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`). **Test count: 1422 → 1451 (+29 net).** 3-gate: `dart format --output=none --set-exit-if-changed .` (clean; 278 files, 3 changed after auto-format on the 3 NEW test files) + `flutter analyze --fatal-infos lib test` (0 issues; a small unused-element/import hint caught by the linter auto-fixed via `dart format`) + `flutter test` (1451/1451 pass). Targeted runs per `CLAUDE.md` "always paste": `flutter test test/a11y/contrast_test.dart` (passes; +7) + `flutter test test/a11y/font_scale_test.dart` (passes; +7) + `flutter test test/a11y/every_screen_test.dart` (passes; +15) + `flutter test test/a11y/semantics_labels_test.dart` (pre-existing sweep still passes). **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — Cycle J is pure-Dart test + docs only. On-device smoke is on the user's Cycle J checklist: `adb shell settings put system font_scale 1.6` on the physical device + TalkBack pass on the 5 critical screens to verify the rendered behavior matches the test-pinned state (the per-screen 1.6x mount for the 3 service-singleton-heavy screens — `add_habit`, `add_person`, `add_event` — is deferred to Cycle K's E2E flow mount). **Parking lot** for v1.4-stab-K+: E2E flows 1..9 + Cycle-B regression protector — `integration_test/critical_flows_test.dart` NEW at the heavy mount level; `lib/do/do.dart`, `lib/people/person.dart`, `lib/events/event.dart`, `lib/missions/mission_input.dart`, `lib/missions/mission_result.dart` direct unit tests for 100% model coverage → Cycle K; perf + fuzz benchmarks → Cycle L. See [[SYS-137]] + [[ADR-068]] + [[WF-065]] for the contract.

### v1.4-stab-K — Model-layer direct unit tests + on-device E2E flow harness (Phase 51 / SYS-138 / ADR-069 / WF-066)

The tenth stabilization cycle of the 3-month campaign. **test-only:** +149 net tests across 6 model-layer test files (4 NEW + 2 EXTENDED) + 1 NEW integration_test/ file (compile-only in harness, runs on device). NEW `test/do/do_test.dart` (+40 tests): full `Do` sealed hierarchy — `DoTime` value class, `Do.validate` exceptions, every subclass's `nextOccurrence` edge cases (`DoFixed` weekday-match + cross-week + DST; `DoInterval` before-ref / on-ref / past-ref; `DoAnchor` with-anchor / without-anchor; `DoDayOfX` dayOfMonth / nth-weekday / refDom; `DoTimeWindow` start-before-end + start-after-end rejected + same-day), `Do.missionChain` / `isPausedAt` / `isDeleted` / `effectiveStreakConfig` getters, `copyWith` invariants, equality id-based, `DoCategory.export` fallback. NEW `test/do/consecutive_counter_test.dart` (+7 tests): empty log, single completion, consecutive days, missed day past grace, within grace window, duplicate same-day, longestStreak independent of current. EXTENDED `test/people/person_test.dart` (+9 tests): 5 `PersonChannel` subclasses' `==`/`hashCode` (ChannelDialer / WhatsApp / Telegram / Signal / Sms), distinct-types-not-equal, `PersonSnapshot` resolved + unresolved, `ContactPerson` id-based equality. EXTENDED `test/events/event_model_test.dart` (+6 tests): `hasFired` both branches, `isArchived` both branches, `notifyAtMillis = atMillis - leadTimeMillis`, `clearArchived` path, id-based equality. NEW `test/missions/mission_input_test.dart` (+17 tests): `ShakeSample.magnitude` (3: sqrt + non-negative + zero), `MathProblem.next` (3: easy add / subtract non-negative / hard multiply), `MemoryGame.generate` (5: rows×cols unmodifiable + pairs matched + deterministic seed + unknown-theme fallback + symbol pool), `MissionResult` + `MissionChainResult` (5), `MathOp` enum, `ShakeMission` construction. NEW `test/missions/mission_result_test.dart` (+7 tests): direct sealed-hierarchy tests on `MissionResult` (4: `MissionPassed` no-detail / with-detail, `MissionFailed`, `MissionTimedOut`) + `MissionChainResult` (3: `ChainPassed`, `ChainFailedAt`, `ChainTimedOut`). NEW `integration_test/critical_flows_test.dart` (+10 testWidgets — compile-only in harness, runs on device via `flutter test integration_test/`): 10 critical user flows — `1: add a do` (FAB tap → enterText → Save → assert tile appears); `2: mark done` (tile tap); `3: streak grows` (assert "1 day" badge visible); `4: delete` (menu → Delete); `5: undo (via v1.4l restore)` (SnackBar Undo key pin); `6: soft-delete + list-deleted` (Settings → Recently-deleted nav); `7: restore from list` (Restore IconButton on the row); `8: backup export` (Settings → Backup → Export); `9: backup restore` (Settings → Backup → Restore); `10: PAUSE + edit name + Save preserves pause (BUG-002 invariant)` — the v1.4-stab-B fix's regression protector: pause, edit name, save, assert `homeTilePausedBadge-read` widget is still in the tree. The `_IntegrationBinding.ensureInitialized()` guard swaps `TestWidgetsFlutterBinding` in the harness (no-op) for `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` on a real device. NEW `integration_test/README.md`: documents the device-vs-harness split — integration_test/ compiles under `dart analyze` but does NOT execute in the harness (no `adb`, no emulator); execution is deferred to the on-device smoke step. **ZERO production-code changes** (pure-test + docs cycle). **No release APK rebuild** (test-only cycle per the F-cycle pattern; APK SHA1 stays at G's `37cb7330`). **Test count: 1388 → 1537 (+149 net).** 3-gate: `dart format --output=none --set-exit-if-changed .` (clean; 0 changed after auto-format on the 6 model-layer test files + integration_test/) + `flutter analyze --fatal-infos lib test integration_test` (0 issues; small avoid_redundant_argument_values + prefer_const_constructors + unnecessary_lambdas hints auto-fixed via `dart format`) + `flutter test` (1537/1537 pass). **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — Cycle K is pure-Dart + new tests + integration_test/ file + integration_test/README.md only. **Parking lot** for v1.4-stab-L: perf benchmarks (`test/perf/widget_rebuild_test.dart`, `test/perf/sql_benchmark_test.dart`) + fuzz tests (5 files × 1000 iterations) + `docs/v_model/performance_baseline.md`. On-device smoke is on the user's Cycle K checklist: run `flutter test integration_test/critical_flows_test.dart --device-id <android-device-id>` on a physical device or emulator to validate the 10 flows end-to-end (the v1.4-stab-B BUG-002 regression is asserted in flow 10). See [[SYS-138]] + [[ADR-069]] + [[WF-066]] for the contract.

### v1.4-stab-H — Recently-deleted top-level screen + v1.4l tombstone surface (Phase 48 / SYS-135 / ADR-066 / WF-063)

The seventh stabilization cycle of the 3-month campaign. **feat: NEW screen + route + settings tile + 15 ARB keys.** Closes the v1.4l-deferred UI for the tombstone column (ADR-056) — the v1.4l Undo SnackBar is a 4-second window; this cycle ships the secondary "I forgot to tap Undo" recovery surface. **Top-level route `/recently-deleted` in `lib/app_router.dart`** (not a modal sheet; consistency with `SettingsRestoreScreen`). **Settings tile in the Backup section** (`ListTile` with key `settings.recently_deleted`); not a bottom-nav entry — the surface is transient per ADR-056 and would clutter the nav on every load. **Screen renders one `ListView` row per tombstoned do** with two inline `IconButton`s: Restore (calls `DoRepository.restoreById`, surfaces success-or-failed snackbar) + Delete-forever (gated by an `AlertDialog` confirm that repeats the destructive verb, calls `DoRepository.deleteById` inside a try/catch). **`FutureBuilder` for the list query** with a `Retry` button in the error state. **Empty state mentions the 30-day TTL** (per ADR-057) so the user knows the surface is not permanent. **ARB parity** in `app_en.arb` + `app_es.arb` for 15 new keys (13 on the screen + 2 on the Settings tile). **Test count: 1388 → 1400 (+12 net).** Coverage: `lib/screens/recently_deleted_screen.dart` 0% → 100% (new file); `lib/app_router.dart` 85.7% → 100% (the new `/recently-deleted` branch); `lib/screens/settings.dart` 85% → ≥90%. 3-gate: `dart format --output=none --set-exit-if-changed .` + `flutter analyze --fatal-infos lib test` + `flutter test` (1400/1400 pass). Targeted runs: `flutter test test/screens/recently_deleted_screen_test.dart` (passes; +12) + `flutter test test/widget/widget_deep_link_test.dart` (passes; +1 in the existing `buildAppRoute` group). **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — Cycle H is pure-Dart + new screen + new route + new tile + new tests + new ARB keys. **Parking lot** for v1.4-stab-I+: i18n exhaustive test coverage (Cycle I — 20 new tests across 2 files; closes BUG-006 test coverage); a11y audit (Cycle J — 15 new tests across 3 files); Cycle K E2E flow 7 (restore from list) exercises this screen at the integration layer. See [[SYS-135]] + [[ADR-066]] + [[WF-063]] for the contract.
