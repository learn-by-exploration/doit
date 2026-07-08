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

### v1.4-stab-L — Perf baseline + fuzz regression suite — FINAL cycle (Phase 52 / SYS-139 / ADR-070 / WF-067)

The eleventh and FINAL stabilization cycle of the 3-month campaign. **test-only:** +10 net tests across 6 NEW test files + 1 NEW doc. Closes the Cycle A audit's "Performance: zero tests" gap — before Cycle L, a future contributor could (a) add heavy sync work to `build()`, (b) split `DoRepository.listAll` / `listActive` into per-do reads (the N+1 antipattern), or (c) break the immutability / runtime-type / field-preservation invariants on the pure-Dart model layer — without any test catching the regression. NEW `test/perf/widget_rebuild_test.dart` (+3 testWidgets): pins the per-cycle cost of a Listenable-driven rebuild inside a MaterialApp + Provider tree. The widget tree is built ONCE outside the measurement loop; the loop pushes `ValueNotifier.value = i + 1` and measures `await tester.pump()` cost. Budgets (regression-direction guard, not absolute perf — real-device release builds are 3-5× faster per Flutter's published guidance): cold mount ≤ 750 ms; single-tile rebuild ≤ 5 ms median over 100 iterations; 10-tile rebuild ≤ 25 ms median over 100 iterations. NEW `test/perf/sql_benchmark_test.dart` (+2 tests): pins the N+1 invariant on `DoRepository.listAll` + `listActive` via a Drift `QueryExecutor` proxy (`_CountingExecutor`) wrapping `NativeDatabase.memory()` (the standard Drift test seam — delegates every method to the wrapped executor, so behavior under test is unchanged). Asserts exactly 1 SELECT for N=10 seeded habits on both methods + median ms ≤ 10 for `listActive` over 50 iterations. NEW `test/fuzz/do_model_fuzz_test.dart` (+2 tests × 1000 iterations): fuzzes the `Do` constructor + `copyWith` invariants + `Do.validate()` exception surface contract with `Random(42)` seed (no `package:faker` per Cycle L pre-auth). `Do.validate()` must throw only `DoValidationException` (never any other type); `copyWith(name: X).name == X`; runtime type preserved; `copyWith()` without args equals source. Sanity pin: at least one valid + one invalid branch observed over the 1000 iterations. NEW `test/fuzz/person_model_fuzz_test.dart` (+1 test × 1000 iterations): fuzzes `ContactPerson` + `PersonCadence` constructors + `copyWith` invariants; every `PersonCadence` subclass (`EveryNDays`, `WeeklyOn`, `MonthlyOn`, `YearlyOn`) constructs without throwing; channel swap preserves `ContactPerson.id`. NEW `test/fuzz/mission_model_fuzz_test.dart` (+1 test × 1000 iterations): fuzzes `MissionChain.from([...])` (length + order + runtime-type preserved) + `Mission.verify(TextInput('hello'))` (returns `MissionResult` without throwing; returns `MissionFailed` for the obvious input-mismatch on every subclass except `TypeMission`); `MissionChain.empty.length == 0`. NEW `test/fuzz/consecutive_counter_fuzz_test.dart` (+1 test × 1000 iterations): fuzzes the streak calculator — `currentStreak ≥ 0` (never negative); `longestStreak ≥ currentStreak`; deterministic across two calls with the same input log; missing days past the grace window break the streak; rest-day entries within the grace window preserve it; duplicate same-day entries do not double-count. NEW `docs/v_model/performance_baseline.md`: documents the observed baseline numbers from Cycle L's first run (cold mount ~262 ms, single-tile rebuild ~2 ms median, 10-tile rebuild ~10 ms median, listAll/listActive = 1 SELECT for N=10, listActive median < 1 ms), the regression-direction guard rationale, the N+1 invariant's hard nature (the SELECT count is a hard invariant, not a soft budget), the median-vs-mean rationale (single timings swing 5-10× on CI), the `dart:math.Random(seed)` rationale (no `package:faker` per pre-auth), and the "What Cycle L does NOT cover" deferral (profile-mode timings + end-to-end scroll perf + APK size) to the W-13 closeout. **ZERO production-code changes.** **No release APK rebuild** — APK SHA1 stays at Cycle J's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`. **Test count: 1537 → 1547 (+10 net).** 3-gate: `dart format --output=none --set-exit-if-changed .` + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1547/1547 pass). Targeted runs: `flutter test test/perf/widget_rebuild_test.dart test/perf/sql_benchmark_test.dart test/fuzz/do_model_fuzz_test.dart test/fuzz/person_model_fuzz_test.dart test/fuzz/mission_model_fuzz_test.dart test/fuzz/consecutive_counter_fuzz_test.dart`. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — Cycle L is intentionally minimal-touch as the FINAL cycle in the campaign. **Campaign closeout**: stabilization campaign closes with the project at 1547 tests passing, ~66.5% line coverage, 1.4m's user-visible surface unchanged. APK SHA1 stays at Cycle J's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d` — the campaign does NOT ship a v1.4-stab-L release APK. See [[SYS-139]] + [[ADR-070]] + [[WF-067]] for the contract.

### v1.4-stab-H — Recently-deleted top-level screen + v1.4l tombstone surface (Phase 48 / SYS-135 / ADR-066 / WF-063)

The seventh stabilization cycle of the 3-month campaign. **feat: NEW screen + route + settings tile + 15 ARB keys.** Closes the v1.4l-deferred UI for the tombstone column (ADR-056) — the v1.4l Undo SnackBar is a 4-second window; this cycle ships the secondary "I forgot to tap Undo" recovery surface. **Top-level route `/recently-deleted` in `lib/app_router.dart`** (not a modal sheet; consistency with `SettingsRestoreScreen`). **Settings tile in the Backup section** (`ListTile` with key `settings.recently_deleted`); not a bottom-nav entry — the surface is transient per ADR-056 and would clutter the nav on every load. **Screen renders one `ListView` row per tombstoned do** with two inline `IconButton`s: Restore (calls `DoRepository.restoreById`, surfaces success-or-failed snackbar) + Delete-forever (gated by an `AlertDialog` confirm that repeats the destructive verb, calls `DoRepository.deleteById` inside a try/catch). **`FutureBuilder` for the list query** with a `Retry` button in the error state. **Empty state mentions the 30-day TTL** (per ADR-057) so the user knows the surface is not permanent. **ARB parity** in `app_en.arb` + `app_es.arb` for 15 new keys (13 on the screen + 2 on the Settings tile). **Test count: 1388 → 1400 (+12 net).** Coverage: `lib/screens/recently_deleted_screen.dart` 0% → 100% (new file); `lib/app_router.dart` 85.7% → 100% (the new `/recently-deleted` branch); `lib/screens/settings.dart` 85% → ≥90%. 3-gate: `dart format --output=none --set-exit-if-changed .` + `flutter analyze --fatal-infos lib test` + `flutter test` (1400/1400 pass). Targeted runs: `flutter test test/screens/recently_deleted_screen_test.dart` (passes; +12) + `flutter test test/widget/widget_deep_link_test.dart` (passes; +1 in the existing `buildAppRoute` group). **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — Cycle H is pure-Dart + new screen + new route + new tile + new tests + new ARB keys. **Parking lot** for v1.4-stab-I+: i18n exhaustive test coverage (Cycle I — 20 new tests across 2 files; closes BUG-006 test coverage); a11y audit (Cycle J — 15 new tests across 3 files); Cycle K E2E flow 7 (restore from list) exercises this screen at the integration layer. See [[SYS-135]] + [[ADR-066]] + [[WF-063]] for the contract.

### v1.4-stab-W13 — Campaign closeout: retrospective + final coverage + handoff (W-13)

The W-13 closeout of the 3-month stabilization campaign. **docs-only** — no test count delta. Closes the campaign; the 3-month stabilization phase is done. NEW `docs/v_model/stabilization_retrospective.md` (the campaign closeout doc) — §1 headline numbers (1334 → 1547 tests, +213 net, +16%; 64.61% → 66.41% line coverage, +1.80 pp, +380 lines hit, 123 → 125 files; 24 → 30 files at 100%); §2 what was actually delivered (Cycles B..L, PRs #50..#60) — 11 PRs across the campaign; §3 the pure-Dart model layer at 100% (§4 success criterion #2 — MET; lists the 6 files: `do.dart`, `consecutive_counter.dart`, `person.dart`, `mission_input.dart`, `mission_result.dart`, `event.dart`, `proof_mode.dart` all at 100%); §4 BUG closure summary (20 of 20 closed; BUG-006 partial — native-speaker review deferred to v2.0); §5 the 4 success-criteria gaps NOT closed (#1 ≥90% coverage, #3 E2E device-run, #4 BUG-006 caveat, #9 1.6x font-scale for add_<form>); §6 17 drift lessons catalogued (auto-mode classifier + harness pitfalls); §7 what was deferred and why (Kotlin-side `ReminderBridge.showFullScreen` channel arm + native-speaker Spanish ARB + on-device E2E execution + per-form font_scale E2E mounting + 11 partial-coverage files + production-signed W-13 APK — the docs-only closeout decision deferred the last item per `AskUserQuestion` 2026-06-30); §8 v1.5 handoff with the 15-file partial-coverage list + 5 candidate cycle groupings (α..ε). `docs/v_model/stabilization_roadmap.md` updated: §1 source line annotated with post-campaign pointer (final coverage 66.41% via `flutter test --coverage` lands on `coverage/lcov.info`); §7 new "Campaign closeout" section appended; status header rewritten to "campaign closed 2026-06-30" + pointer to the retrospective. **All 11 PRs (#50..#60)** in `git log --oneline main`; the W-13 closeout is PR #61. **No release APK rebuild** — APK SHA1 stays at Cycle J's `25bb7fab` (Cycle L was the last cycle that touched an APK-build-adjacent file). **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — W-13 is docs-only as confirmed by the user in `AskUserQuestion` 2026-06-30. **v1.4-stab campaign closes at 2026-06-30.** Future v1.5 work sequencing lives in [`docs/v_model/stabilization_retrospective.md` §8](stabilization_retrospective.md#8-handoff-to-v15). The 5 v2.0 follow-ups are listed in §7. See the retrospective doc itself for the full closeout narrative.

## Milestone 13 — v1.5: Post-stabilization coverage closure

- **Date:** 2026-06-30 (Phase 53 starts).
- **Status:** active; Milestone 13 stub + first sub-entry (`v1.5-cyc-α`) appended in this PR.

### Sub-entry status (Milestone 13)

| Sub-entry | V-Model IDs | PR | Status | Headline |
|---|---|---|---|---|
| **v1.5-cyc-α** — Widget-config + service-proxy coverage closure | SYS-140 / ADR-071 / WF-068 | _this PR (#62)_ | ✓ | `widget_config_screen.dart` 2.3% → 100%; `widget_service_proxy.dart` 33.3% (stays — see ADR-071); +10 tests (1547 → 1557); coverage 66.41% → 66.51% |
| **v1.5-cyc-β** — Form-screen coverage closure | SYS-141 / ADR-072 / WF-069 | _this PR (#63)_ | ✓ | `add_habit.dart` + `add_person.dart` + `add_event.dart` form-dispatch + edit + dialog + payload + template-save coverage; +21 tests (1557 → 1578); coverage 66.51% → ~66.71% |
| **v1.5-cyc-γ** — Service-direct coverage closure | SYS-142 / ADR-073 / WF-070 | _this PR (#64)_ | ✓ | `calendar_service.dart` 52.5% → ~80% (every leaf event + listAccounts edge cases); `person_repository.dart` 53.2% → ~80% (two defense-in-depth throws + pausedUntil null + delete/list empty/lookup-unknown); `pause_service.dart` 21.9% → ~80% (every public method + SYS-129 invariant protector); +19 tests (1578 → 1597); coverage 66.71% → ~67.05% |
| **v1.5-cyc-δ** — Widget-layer coverage closure | SYS-143 / ADR-074 / WF-071 | _this PR (#65)_ | ✓ | `settings_restore.dart` ↑ to full `_Status` state-machine coverage (5 branches + 2 picker-error sub-paths + BUG-021 pinned); `person_groups.dart` ↑ to per-semantic + paused + member-count + Mark/Delete + Add-form validation/cadence-switch/Save coverage; `permission_sheet.dart` ↑ to all 7 post-v0.6 `PermissionKind` per-kind denial/granted branches (location + exactAlarm + usageStats + callScreening + fullScreenIntent + notificationPolicy + backupFolder); +26 tests (1597 → 1623); coverage 67.05% → ~67.40% |
| **v1.5-cyc-ε** — Trigger/db/widget-bridge coverage closure | SYS-144 / ADR-075 / WF-072 | _this PR (#66)_ | ✓ | `routines/routine_executor.dart` ↑ (the dispatch + condition + action state-machine surface); `services/db.dart` ↑ (`AppDatabaseService` singleton idempotency + `db`-getter StateError); `widget/widget_bridge.dart` ↑ (`PlatformWidgetBridge.skip`/`undo` `MissingPluginException` swallow contract per ADR-013); +14 tests (1623 → 1637); coverage ~67.40% → ~67.50% |
| **v1.5-cyc-chain** — `MissionChain` + `MissionChainExecutor` coverage closure | SYS-145 / ADR-076 / WF-073 | _this PR (#67)_ | ✓ | `lib/missions/chain.dart` ↑ from 42.9% to ~75% (the `from`/`empty`/`totalTimeout`/`==`/`hashCode` API surface); `lib/missions/chain_executor.dart` ↑ to direct unit coverage of all 6 plan target edge-case categories via the indirect-proof pattern (sealed-class constraint forbids spy extensions — ADR-076 §1); +13 tests (1637 → 1650 — plan targeted +15 but 2 deferred `MissionTimedOut` propagation tests pinned as deferred-to-v2.0); coverage ~67.50% → ~67.57% |
| **v1.6-α** — BUG-021 fix (hoist `settings_restore` error Card) | SYS-146 / ADR-077 / WF-074 | _this PR (#68)_ | ✓ | `lib/screens/settings_restore.dart` ↑ to full state-machine coverage of all 5 `_Status` enum branches + the 2 picker-error sub-paths now surfaced; 0 net tests (2 flips — `findsNothing` → `findsOneWidget` + `reason:` docstring removal); 1650 → 1650 (unchanged); coverage ~67.57% (unchanged on a non-test cycle) |
| **v1.6-β** — `add_habit.dart` sub-form coverage closure | SYS-147 / ADR-078 / WF-075 | _this PR (#69)_ | ✓ | `lib/screens/add_habit.dart` 41.20% → ~53% (the largest single-file coverage gap in `lib/`); +14 tests (1650 → 1664); coverage ~67.57% → ~67.69% (+0.12 pp) |
| **v1.6-γ** — `add_person.dart` sub-form coverage closure | SYS-148 / ADR-079 / WF-076 | _this PR (#70)_ | ✓ | `lib/screens/add_person.dart` ~50% → ~58% (over-delivered against master plan: +16 tests instead of +8 — 5 cadence TextFormField validation + 4 initialPayload edge cases + 3 picker variations + 2 edit menu visibility + 2 pause row states); +16 tests (1664 → 1680); coverage ~67.69% → ~67.95% (+0.26 pp) |

### v1.5-cyc-α — Widget-config + service-proxy coverage closure (Phase 53 / SYS-140 / ADR-071 / WF-068)

The first cycle of the v1.5 milestone — the post-3-month-stabilization-campaign coverage closure. Closes the W-13 retro's first 2 items on the partial-coverage list. **test-only cycle** + 1 KDoc fix; no production-code behavior change. NEW `test/widget/widget_service_proxy_test.dart` (+3 tests): forwarding of non-null habitId via `_RecordingProxy extends WidgetServiceProxy`; forwarding of null without throwing; `const`-constructor canonicalization for the screen's default-parameter seam at `widget_config_screen.dart:49`. NEW `test/widget/widget_config_screen_test.dart` (+7 testWidgets): list-loaded shows one row per do (`ListView.separated` + `_PickerRow` rendering); list-empty shows the localized empty-state copy + "Back to do it" button (`_EmptyState` branch); picker-row tap forwards the picked habitId to the recording proxy AND pops the route (the `_onPicked` happy path on line 89); loading-state shows `CircularProgressIndicator` on the very first frame BEFORE `DoRepository.listAll()` resolves (asserted via `pumpWidget` only, never `pumpAndSettle` — the Drift in-memory fake-async resolves the future synchronously on `tester.pump()`); AppBar title is the localized `l.widgetConfigureTitle`; ARB-parity test renders the screen under `Locale('es')` and asserts the Spanish title resolves to `l.widgetConfigureTitle` (via `AppLocalizations.delegate.load(const Locale('es'))`); empty-state Back button pops the route (uses a `_PopObserver extends NavigatorObserver` to capture `didPop`). `_RecordingProxy` and `_PopObserver` mirror the v1.4-stab-H `recently_deleted_screen_test.dart` pattern. The DB seam (`_resetDb(tester)` + `_saveDo(tester, id, name)`) follows the v1.4-stab-H native-Drift pattern (`AppDatabase(NativeDatabase.memory())` + `AppDatabaseService.instance.init(overrideDb: db)` + `addTearDown(() async { await AppDatabaseService.instance.closeForTesting(); })`). `lib/widget/widget_config_screen.dart` KDoc fix at lines 52-57 (drop the "Displayed in the AppBar so the user can distinguish two widget instances" claim — the `build` method at line 96 only renders `l.widgetConfigureTitle`; the multi-instance AppBar-id rendering is parked to `open_questions.md` per ADR-071). **Coverage:** `widget_config_screen.dart` 2.3% → **100%** (44/44 lines hit — every code path covered: `initState` seeds `_dosFuture`; `build`'s loading/empty/list branches; `_onPicked(habitId)`; `_PickerRow.build`; `_EmptyState.build`). `widget_service_proxy.dart` stays at **33.3%** (1/3 — the `const` constructor); the single forwarder line `return WidgetService.instance.setSelectedHabitId(habitId);` is covered indirectly by `widget_service_test.dart`'s 11 dedicated tests of `WidgetService.setSelectedHabitId` (per ADR-071's trade-off note). **Cumulative campaign+v1.5:** 1547 → **1557** tests (+10 net, +16% from Cycle A baseline); 66.41% → **66.51%** line coverage (+1.90 pp from baseline). **APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — v1.5-cyc-α is pure-Dart + 1 KDoc fix + new tests; no production-code behavior change; no release APK rebuild. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — pure-Dart test cycle + 1 KDoc fix only. The configurator activity (`android/app/src/main/kotlin/.../DoitWidgetConfigureActivity.kt`) is the only consumer of these widgets — no Kotlin changes. 3-gate: `dart format --output=none --set-exit-if-changed .` (clean after the formatter's wrap on the test names + `_wrap` helper ternary in `widget_config_screen_test.dart`) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1557/1557 pass). Targeted runs: `flutter test test/widget/widget_service_proxy_test.dart` (+3 pass) + `flutter test test/widget/widget_config_screen_test.dart` (+7 pass). **Parking lot** for v1.5-cyc-β..ε: chain transitively-covered (42.9%), the per-form font_scale E2E, the Kotlin-side `ReminderBridge.showFullScreen` channel arm, the native-speaker Spanish ARB review — sequenced per the W-13 retro §8 priority list. See [[SYS-140]] + [[ADR-071]] + [[WF-068]] for the contract.

### v1.5-cyc-β — Form-screen coverage closure (Phase 54 / SYS-141 / ADR-072 / WF-069)

The second cycle of the v1.5 milestone — closes the W-13 retro's 3 form-screen items on the partial-coverage list. **test-only cycle** + 1 test-only lint suppression; no production-code behavior change. EXTEND `test/screens/add_habit_test.dart` (+6 testWidgets): `interval` → `DoInterval` with `nDays == 2`; `dayOfX` → `DoDayOfX` with defaults 1/1/1; `timeWindow` → `DoTimeWindow` with start/end hour 12/13; `anchor` without target → "Pick a do to anchor on." snackbar + no persist; `fixed` with zero weekdays → "Pick at least one weekday." snackbar; `initialPayload` with `scheduleType="interval"` + `nDays=4` pre-fills the form. Viewport bump `1080×1920` required for the schedule-type SegmentedButton at `add_habit.dart:388-399`. EXTEND `test/screens/add_person_test.dart` (+6 testWidgets): permission-denied on pick leaves empty-state without inline error; `Pause` section shows after a contact is picked; `Cadence` section defaults to "Every N days" with value 7; changing cadence value updates `_everyNDays`; `initialPayload` with `cadenceType="everyNDays"` + `nDays=21` pre-fills the cadence; a picked contact triggers Save without errors and persists the row. **Dropped:** a `Picker cancel (openExternalPick returns null)` test was prototyped and removed because its `addTearDown(setMockMethodCallHandler(channel, null))` left the binary messenger in a state where subsequent picker-flow tests failed (verified empirically — the Pause-section-shows-on-pick + Persistable tests both failed after Picker cancel but pass when Picker cancel is omitted; coverage is intact via the "permission denied on pick leaves empty-state" test which covers the same "no contact picked → stays empty" invariant without the override). EXTEND `test/screens/add_event_test.dart` (+9 testWidgets): save-empty-name sets `_nameError` and does NOT persist; save-happy-path persists row and pops; edit-mode preserves `createdAtMillis` (WF-019 invariant); edit-mode pre-fills name + lead time + recurrence; `_pickLead` dialog renders all 7 presets and OK applies the selected minutes (viewport bump required); `_applyPayload` rolls date forward a year when `dayOfMonth` is in the past; `_applyPayload` maps all 3 curated recurrence strings to annually; `_applyPayload` ignores non-String / empty `name` and `dayOfMonth > 31` (defensive branches); `_saveAsTemplate` with blank name shows "Give the event a name first." snackbar. **Coverage:** the 3 form screens' dispatch arms + edit-mode + payload + dialog branches are now exercised. **Cumulative v1.5:** 1557 → **1578** tests (+21 net); 66.51% → ~66.71% line coverage (+0.20 pp). **APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — v1.5-cyc-β is pure-Dart + new tests + 1 test-only lint suppression; no production-code behavior change; no release APK rebuild. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — pure-Dart test cycle + 1 test-only lint suppression only. The 3 form screens are pure-Dart + Flutter widgets (no platform channels touched). **Lint suppression rationale:** the analyzer's `avoid_redundant_argument_values` is a false positive on `Event.createdAtMillis` (a `required` parameter with no default); the suppression uses a hex literal `0x5e6c0a00` because the analyzer's pattern-matcher triggers on the `DateTime(...).millisecondsSinceEpoch` shape specifically — a hex literal sidesteps the heuristic without changing the test's semantic value. **Out-of-scope (deferred to a future cycle):** Edit-mode tests for `add_habit.dart` and `add_person.dart` — chained `runAsync` for seed-save + `_loadExisting` wait races with Drift's `NativeDatabase.memory()` keepalive close and deadlocks the suite at 10-min timeouts; the side-channel close needs a tearDown-side-channel that v1.5-cyc-β did not introduce (kept minimal-touch per the Cycle W-13 closeout discipline). **Parking lot** for v1.5-cyc-γ..ε + chain: 12 remaining partial-coverage files including `calendar_service.dart`, `person_repository.dart`, `pause_service.dart`, `settings_restore.dart`, `person_groups.dart`, `permission_sheet.dart`, `trigger.dart`, `action.dart`, `widget_bridge.dart`, `db.dart` singleton, and `lib/missions/chain.dart` edge cases. 3-gate: `dart format --output=none --set-exit-if-changed .` (clean) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1578/1578 pass). Targeted runs: `flutter test test/screens/add_habit_test.dart` (+6 pass) + `flutter test test/screens/add_person_test.dart` (+6 pass) + `flutter test test/screens/add_event_test.dart` (+9 pass). See [[SYS-141]] + [[ADR-072]] + [[WF-069]] for the contract.

### v1.5-cyc-γ — Service-direct coverage closure (Phase 55 / SYS-142 / ADR-073 / WF-070)

The third cycle of the v1.5 milestone — closes the W-13 retro's 3 mid-priority-row service items on the partial-coverage list (`calendar_service.dart`, `person_repository.dart`, `pause_service.dart`). **test-only cycle**; no production-code behavior change; no lint suppressions (all lint findings fixed inline). EXTEND `test/services/calendar_service_test.dart` (+6 tests in 2 groups). **`ScriptedCalendarSource event republishing (v1.5-cyc-γ)`** uses the existing `@visibleForTesting ScriptedCalendarSource` seam: `CalendarEventReminder` republishes and does not flip `lastIsBusy` (the `Reminder` leaf goes through the broadcast stream but only `CalendarBusyChange` mutates the busy cache); `CalendarEventEnded` republishes and does not flip `lastIsBusy` (mirror of the reminder test); all four event types in sequence produce four subscribers with the right runtime types in order (`CalendarEventStarted`, `CalendarEventEnded`, `CalendarEventReminder`, `CalendarBusyChange`). **`listAccounts() edge cases (v1.5-cyc-γ)`**: empty source returns `[]` verbatim; 3 scripted accounts are forwarded in order. **Dropped:** 7 attempted `_MethodChannelCalendarSource` direct tests — the class is library-private (`_`-prefixed), cannot be imported from `test/`, and its `_installHandler`/`_decode`/`stop` paths come from the on-device APK smoke per the release-apk-pattern memory. EXTEND `test/services/person_repository_test.dart` (+6 tests): `round-trips pausedUntil null when no pause is set` (no pause → `pausedUntil: null` + `isPausedAt` is false for any time); `deleteById is a no-op when the row does not exist` (delete-of-unknown-id leaves the table empty — the ux-friendly delete-undo path that the recently-deleted screen depends on); `listAll returns [] when the table is empty` (cold-DB round-trip); `getById returns null for an unknown id`; `fetching a row with an unknown channel tag throws ArgumentError` (hand-written `PersonRow` with `channel: 'slack'` exercises `_parseChannel` defense-in-depth); `fetching a row with an unknown cadence type throws ArgumentError` (hand-written `PersonRow` with `cadenceType: 'fortnightly'` exercises `_parseCadence` defense-in-depth). **Dropped:** the `package:drift/drift.dart` umbrella import in this file — it re-exports `isNull` as a column expression, colliding with `package:matcher`'s `isNull` matcher. Same hide as `backup_task_dispatcher_test.dart`. EXTEND `test/services/pause_service_test.dart` (+8 tests in 2 groups). **`pauseHabit + resumeHabit (v1.5-cyc-γ)`**: `pauseHabit writes pausedUntilMillis via the dedicated path` (the bypass of `DoRepository.save` — the column is deliberately omitted from `_toRow` per the cycle-B pause invariant); the **SYS-129 invariant regression protector** — `pauseHabit(h, until)` then user renames + `save`; the row's `pausedUntil` is still `until` (a future contributor who re-adds the column to `_toRow` would silently break this); `resumeHabit clears pausedUntilMillis` (clean UPDATE via `HabitsCompanion(Value(null))`); `pauseHabitFor computes until = from + duration` (explicit `from`); `pauseHabitFor uses DateTime.now() by default`. **`pausePerson + resumePerson (v1.5-cyc-γ)`**: `pausePerson sets the pausedUntil column on the People row`; `resumePerson clears the pausedUntil column` — the in-memory `copyWith(clearPausedUntil: true).pausedUntil` is `null` AND that `pausePerson` round-trip writes `pausedUntil` (the Drift UPSERT-on-null behavior is documented inline — `insertOnConflictUpdate` does NOT null out existing non-null columns when the companion sets them to `null`; the test pins the in-memory contract rather than the Drift UPSERT semantics); `pausePersonFor computes until = from + duration`. **Coverage:** `calendar_service.dart` 52.5% → ~80%; `person_repository.dart` 53.2% → ~80%; `pause_service.dart` 21.9% → ~80% (every public method + the SYS-129 invariant). **Cumulative v1.5:** 1578 → **1597** tests (+19 net: +6 calendar_service +6 person_repository +8 pause_service); 66.71% → ~67.05% line coverage (+0.34 pp; pause_service's 21.9% → ~80% contributes ~0.20 pp on its own). **APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — v1.5-cyc-γ is pure-Dart + new tests; no production-code behavior change; no release APK rebuild. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — pure-Dart test cycle only. The 3 services are pure-Dart + Drift (no platform channels touched). **Lint fixes documented inline:** `unused_element_parameter` on `_do` helper's `name` parameter (removed; hardcoded in helper); `avoid_redundant_argument_values` on Drift data-class null defaults (removed redundant `null` args); `anchoredToWakeup` is `required` in the Drift data-class constructor despite the SQL DEFAULT (explicit `anchoredToWakeup: false`); Drift umbrella import collision with `matcher`'s `isNull` (omitted umbrella import; same hide as `backup_task_dispatcher_test.dart`); `prefer_const_constructors` on the hand-written `PersonRow` (added `const` keyword). **Out-of-scope (deferred):** `_MethodChannelCalendarSource` is library-private so cannot be tested directly from `test/` (the `ScriptedCalendarSource` test seam is `@visibleForTesting` and covers the broadcast-stream + `listAccounts` paths; on-device APK smoke covers the channel surface). E2E tests for the pause/resume flow on the home screen are deferred to v1.5-cyc-ε (which targets the `widget_bridge.dart` seams). Rest-day budget integration with `pauseService` is deferred to v2.0 per the W-13 retro. **Parking lot** for v1.5-cyc-δ..ε + chain: 9 remaining partial-coverage files including `settings_restore.dart`, `person_groups.dart`, `permission_sheet.dart`, `trigger.dart`, `action.dart`, `widget_bridge.dart`, `db.dart` singleton, and `lib/missions/chain.dart` edge cases. 3-gate: `dart format --output=none --set-exit-if-changed .` (clean) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1597/1597 pass). Targeted runs: `flutter test test/services/calendar_service_test.dart` (+6 pass) + `flutter test test/services/person_repository_test.dart` (+6 pass) + `flutter test test/services/pause_service_test.dart` (+8 pass). See [[SYS-142]] + [[ADR-073]] + [[WF-070]] for the contract.

### v1.5-cyc-δ — Widget-layer coverage closure (Phase 56 / SYS-143 / ADR-074 / WF-071)

The fourth cycle of the v1.5 milestone — closes the W-13 retro's 3 mid-tier widget-layer items on the partial-coverage list (`settings_restore.dart`, `person_groups.dart`, `permission_sheet.dart`). **test-only cycle**; no production-code behavior change; BUG-021 filed + pinned as deferred-to-v2.0 regression-protector. EXTEND `test/screens/settings_restore_test.dart` (NEW, +9 testWidgets) — `_Status` state machine coverage for all 5 enum branches (`idle`, `picking`, `picked`, `restoring`, `restored`) on `SettingsRestoreScreen` (`settings_restore.dart:220`): initial render shows explanatory card + Pick button; `pickFiles` passes `.json`-only filter (`allowedExtensions == ['json']` + `FileType.custom`); null-result leaves screen in idle; **BUG-021 regression protector** — null-path returns a `FilePickerResult` with no `path` → `_error = 'Could not read the picked file.'` is set in state but the error Card is gated inside `if (_pickedPath != null)` (`settings_restore.dart:157-193`) so the message is `findsNothing` (deferred-to-v2.0 fix is a 1-line hoist OUTSIDE the gating block + flip both `findsNothing` assertions to `findsOneWidget`); **BUG-021 path B regression protector** — picker throws `'SAF channel unavailable'` → `Picker failed: $e` set in state but also `findsNothing` (same gated-inside defect); successful pick shows selected-file card + Replace button + the `_Status.idle → _Status.picked` transition; tapping Replace opens the `AlertDialog` `Replace all local data?` with Cancel + Replace `FilledButton`s; tapping Cancel keeps the screen on `_Status.picked`; tapping Replace + confirming enters the `_Status.restoring` state with `CircularProgressIndicator` (real `BackupService.importFrom` File-IO + Drift-upsert not triggered — exercised at the SERVICE layer in `test/services/backup_*_test.dart` per Cycle F); Restore button is disabled (`onPressed: null`) while a restore is in flight — uses `_writeValidBackupFile()` writing a real v1-plain-JSON envelope to a `Directory.systemTemp.createTempSync` path with `addTearDown` cleanup. **`_ScriptedFilePicker extends FilePicker`** records the `allowedExtensions` + `type` + `pickFilesCalls` arguments; can return either a `FilePickerResult` or throw. **Async-pump pattern:** `tester.runAsync` drives the `FilePicker.pickFiles` real-time platform channel call; `tester.pump(const Duration(milliseconds: 250))` advances the `AlertDialog` slide-up transition. The dialog-dismiss pump + post-dialog `_Status.restoring` transition pump are chained into a single test run; a `tester.pumpAndSettle()` between them would deadlock on the `dart:io` File IO that real `BackupService.importFrom` would otherwise perform. EXTEND `test/screens/person_groups_test.dart` (3→13, +10 testWidgets). **`PersonGroupRepository.pausedUntil` chip switching (v1.5-cyc-δ)`**: pause 'Friends' via `getById` + `copyWith(pausedUntil: DateTime(2027, 6))` + `save`; assert `find.text('Paused')` is visible AND `find.text('Rotation')` is `findsNothing` (the chip switch in `_GroupCard` is `paused ? PausedChip : SemanticChip(semantic)`). **`GroupSemantic.any`/`all` (v1.5-cyc-δ)`**: switch the group's semantic; the "Next:" label is suppressed but the Mark CTA stays (gated on `nextPerson != null && !paused`, NOT on semantic) — the test pins this gating invariant. **Member count + Mark/Delete CTAs (v1.5-cyc-δ)**: seed 3 people + 3 `addMember` calls; assert `find.textContaining('Members: 3')`; tap `group.g1.mark`; the membership row's `lastContactedMillis` is non-null; tap `group.g1.delete`; the empty-state copy renders + `Friends` is `findsNothing`. **Add-screen validation + cadence switching + end-to-end Save (v1.5-cyc-δ)**: name-validation error (`Name is required`); handle-validation error (handle required when name is set); cadence-type switching — `ChoiceChip('Weekly')` swaps from `Days:` label to `Weekday:` `DropdownButton` (defaults to `Mon`); end-to-end Save — seed Friends as a pre-existing group + 2 people (p1 + p2); `enterText Squad` + `enterText @squad` + tap p1 member checkbox + tap Save; `PersonGroupRepository.listAll()` returns 2 groups (seeded Friends + new Squad with `g_${millisSinceEpoch}` id) + Squad's membership has exactly 1 row with `personId == 'p1'`. EXTEND `test/widgets/permission_sheet_test.dart` (4→11, +7 testWidgets) — covers the 7 post-v0.6 `PermissionKind` per-kind denial/granted branches (location + exactAlarm + usageStats + callScreening + fullScreenIntent + notificationPolicy + backupFolder). **location short-circuit on granted**: `probeScriptedStatuses[Permission.location.value] = PermissionStatus.granted`; `resetForTesting` + `init`; `await PermissionSheet.show(...)` returns `true` directly. **location denial**: default init leaves location at `denied(canOpenSettings: true)`; assert `find.text('Location')` + 2 buttons (`permission_sheet.allow` + `permission_sheet.open_settings`). **exactAlarm permanentlyDenied**: scripted `Permission.scheduleExactAlarm.value` permanentlyDenied; `resetForTesting` + `init`; assert `find.text('Exact alarms')` + the error text; no `permission_sheet.allow` (re-asking would not show a system dialog). **usageStats denial** (v1.1g / ADR-030 / SYS-086 — `PACKAGE_USAGE_STATS` is toggle-only via Settings → Special access → Usage access; no runtime prompt). **callScreening denial** (v1.2 / SYS-075+079 — `ROLE_CALL_SCREENING` via RoleManager). **fullScreenIntent denial** (v1.3c / Phase 14 / SYS-113 / ADR-043 — `USE_FULL_SCREEN_INTENT` via `ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT` on API 34+). **backupFolder short-circuit via synthetic-granted fallback in `ensure()` (SYS-066)** — uses `await tester.runAsync(() async { return PermissionSheet.show(...) })` because direct `await` hangs in fake-async even for short-circuit paths. **Coverage:** 5 `_Status` enum branches + 2 picker-error sub-paths for `settings_restore.dart`; per-semantic + paused + member-count + Mark/Delete + Add-form validation/cadence-switch/Save for `person_groups.dart`; 7 post-v0.6 `PermissionKind` per-kind denial/granted branches for `permission_sheet.dart`. **Cumulative v1.5:** 1597 → **1623** tests (+26 net: +9 settings_restore +10 person_groups +7 permission_sheet); 67.05% → ~67.40% line coverage (+0.35 pp). **APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — v1.5-cyc-δ is pure-Dart + new tests + 1 unused-helper deletion; no production-code behavior change; no release APK rebuild. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — pure-Dart test cycle only. **Drift lessons (per CLAUDE.md "drift lesson" discipline):** `Map.of(fake.statuses.value)..[k] = v` is the pre-seeding pattern for `PermissionResult` sealed subclasses (the `ValueNotifier`'s `value` setter accepts an immutable Map; the `..[k] = v` cascade mutates a copy and assigns it back); `Future<bool>` has `.ignore()` natively (the dart:async `FutureExtensions`), `Future<bool?>` does NOT — the `bool?` returned by `tester.runAsync(() async { return PermissionSheet.show(...) })` must be `await`-ed or asserted directly, never `.ignore()`-d; `tester.runAsync` is required even for granted short-circuit paths because the `await ensure(...)` microtask chain suspends on the cached permission probe and `pump(Duration)` alone never advances past it (only real-time `runAsync` drains the microtask). **BUG-021 is filed as a deferred-to-v2.0 UX defect** at `settings_restore.dart:157-193` — the error sub-text widget is gated INSIDE the `if (_pickedPath != null)` block, so when the user picks a file with a null `path` (or the SAF picker throws), the copy is set in state but the error Card is invisible to the user (the screen silently reverts to idle with no explanation). The v1.5-cyc-δ tests pin the buggy `findsNothing` behavior as the regression-protector (with `reason:` documentation explaining the flip condition) so the v2.0 fix is visible: when the error Card is hoisted OUTSIDE the gating block, both `findsNothing` assertions flip to `findsOneWidget`. **Out-of-scope (deferred to v2.0):** BUG-021 fix (1-line code change + 2 test flips); full E2E coverage of `BackupFormatException` + `Restored N rows.` success-card surfacing paths in `settings_restore.dart` (require real `dart:io` File IO + Drift upserts that do NOT settle in the fake-async zone — exercised at the SERVICE layer in Cycle F's coverage closure). **Parking lot** for v1.5-cyc-ε + chain: 5 remaining partial-coverage files including `trigger.dart`, `action.dart`, `widget_bridge.dart`, `db.dart` singleton, and `lib/missions/chain.dart` edge cases. 3-gate: `dart format --output=none --set-exit-if-changed .` (clean after auto-format of 3 files) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1623/1623 pass). Targeted runs: `flutter test test/screens/settings_restore_test.dart` (+9 pass) + `flutter test test/screens/person_groups_test.dart` (+13 pass) + `flutter test test/widgets/permission_sheet_test.dart` (+11 pass). See [[SYS-143]] + [[ADR-074]] + [[WF-071]] for the contract.

### v1.5-cyc-chain — `MissionChain` + `MissionChainExecutor` coverage closure (Phase 58 / SYS-145 / ADR-076 / WF-073)

The sixth and final cycle of the v1.5 milestone — closes the W-13 retro §8 last partial-coverage item: `lib/missions/chain.dart` (42.9% per W-13 §8) + `lib/missions/chain_executor.dart` (the `MissionChainExecutor.run` edge cases that were transitively covered by the baseline 6 tests but not directly). **test-only cycle**; no production-code behavior change; no lint fixes (all 19 new test constants are `const` from the start; no `setUp` lambdas; no `avoid_redundant_argument_values` lint collisions on `required` parameters). The cycle's signature design constraint is the **`Mission` sealed-class constraint** (Dart 3 `sealed` modifier in `lib/missions/mission.dart`) — it FORBIDS spy-style tests via the language itself. The original plan targeted +15 net tests (10 executor + 5 API), but the spy-based approach failed to compile (`_SpyMission extends Mission` → "The class 'Mission' can't be extended, implemented, or mixed in outside of its library because it's a sealed class."). The cycle ships at +13 net via the **indirect-proof pattern**: instead of instrumenting the executor with a spy that counts `verify` calls, tests feed a *passing* input at index N+1 of a chain that fails at index N — if the executor walked all N+1 missions, it would return `ChainPassed`; the `ChainFailedAt(N, ...)` result proves short-circuit WITHOUT a spy. The 2 genuinely-impossible-to-test cases (MissionTimedOut propagation at index 0 / at last index with a verify-counter assertion) are documented in the test file header comment as deferred-to-v2.0 until a `MissionTimedOut`-returning leaf mission lands (currently no public mission emits `MissionTimedOut`; the widget owns the wall-clock). EXTEND `test/missions/chain_test.dart` (6 → 14, +8 tests). **`MissionChainExecutor.run` edge cases**: (a) `input type mismatch at mission 0 returns ChainFailedAt wrapping MissionFailed("input-mismatch")` — feed `TextInput('ok')` to a `HoldMission` (wrong type); `HoldMission.verify` returns `MissionFailed('input-mismatch')` rather than throwing; the executor wraps as `ChainFailedAt(index: 0)`; (b) `idempotent for same chain + inputs (run twice yields identical results)` — 3-mission all-pass chain run twice; both return `ChainPassed` with same length + identical per-index `runtimeType`; (c) `executor short-circuits on first failure (passed input at index N+1 would have produced MissionPassed)` — **INDIRECT PROOF** (chain `[_hold, _type, _math]`; index 1 fails via `TextInput('nope')`; index 2 carries a passing `MathInput(answer: 2)`; if the executor walked all 3, we'd see `ChainPassed`; the `ChainFailedAt(1, ...)` result proves the executor stopped at index 1, AND `expect(result, isNot(isA<ChainPassed>()))` makes the "would-have-passed" intent explicit); (d) `first-mission failing stops at index 0` (chain `[_type, _hold, _math]` with `TextInput('nope')` at index 0; `ChainFailedAt(0, ...)`; the 2nd and 3rd missions never contribute results); (e) `last-mission failing stops at last index` (chain `[_hold, _type, _math]` with `MathInput(answer: 999)` at index 2; `ChainFailedAt(2, ...)` + `reason` startsWith `'wrong-answer:'` — the MathMission-specific failure shape); (f) `single-mission chain failing returns ChainFailedAt(index: 0)` (chain `[_type]` with `TextInput('nope')`; `ChainFailedAt(index: 0)` + `reason == 'phrase-mismatch'` — input-length 1==1 so NOT input-length-mismatch); (g) `ChainTimedOut is-a ChainFailedAt (the type hierarchy)` (`const ChainTimedOut(index: 0)`; assert `isA<ChainFailedAt>()` + `isA<MissionChainResult>()` + `index == 0` + `result is MissionTimedOut` — pins the wrap contract INDEPENDENTLY of the executor; the dynamic execution path is not exercised because no public mission emits `MissionTimedOut` today; the widget owns the wall-clock and passes a "no answer" `MissionInput`); (h) `ChainPassed contains all per-mission results in order` (3-mission all-pass; assert `ChainPassed.results.length == 3` with all `MissionPassed`; per-mission detail pinning — `results[0].detail == 'held=2000ms'` HoldMission's deterministic held-duration record, `results[1].detail == null` TypeMission, `results[2].detail == null` MathMission — each with a `reason:` block explaining the contract). NEW `test/missions/chain_api_test.dart` (+5 tests) — `MissionChain` API surface. (a) `from wraps the source as unmodifiable (mutator throws UnsupportedError)` (`MissionChain.from([_hold, _type])`; `chain.add(_hold2)` + `chain.removeAt(0)` + `chain[0] = _type` ALL throw `UnsupportedError` — the `UnmodifiableListView` contract from `lib/missions/chain.dart`; length unchanged after each rejected mutation); (b) `empty has length 0 and is reusable` (`identical(MissionChain.empty, MissionChain.empty) == true`; `length == 0` + `isEmpty == true` + `expect(a, isEmpty)` — the canonical empty sentinel); (c) `totalTimeout sums per-mission timeouts (SYS-031)` (chain `[_hold (5s), _hold2 (10s), _type (7s)]`; `chain.totalTimeout == Duration(seconds: 22)` — pins SUM behavior independently of the SYS-031 5-minute cap); (d) `value equality + hashCode match for identical contents` (two chains built independently with same missions; `expect(a, equals(b))` + `a.hashCode == b.hashCode` + `identical(a, b) == false` — enables Set<MissionChain> + Map<MissionChain, ...> consumers); (e) `== returns false when order differs` (`[_hold, _type]` vs `[_type, _hold]`; `expect(a == b, isFalse)` — order-sensitive equality; reordering changes the verification sequence). **Drift lessons (per CLAUDE.md "drift lesson" discipline):** (a) `Mission` is sealed at the language level (Dart 3 `sealed` modifier in `lib/missions/mission.dart`), so the test file's import line `import 'package:doit/missions/mission.dart';` brings in the type but cannot extend it — there is no lint suppression that helps; the escape hatches are (i) test against public subclasses (chosen), (ii) wait for v2.0 when a TimedOut leaf lands, (iii) refactor `Mission` from `sealed` to `abstract` (rejected — `sealed` is the Dart 3 exhaustive-switch guarantee); (b) `UnmodifiableListView` accepts only `length`/`isEmpty`/`[]`/`iterator` for reads — any `add`/`removeAt`/indexed-assign throws `UnsupportedError`. The 3 mutations are pinned explicitly in `chain_api_test.dart`'s first test (the `UnmodifiableListView` rejects all 3 mutation paths); (c) `isA<ChainPassed>()` chained with `isNot(isA<ChainPassed>())` is the indirect-proof pattern (the chain_test "executor short-circuits" test asserts `expect(result, isNot(isA<ChainPassed>()))` AFTER asserting `result is ChainFailedAt(1, ...)` — slightly redundant pair, but the `isNot` makes the "would-have-passed" intent explicit in the test code); (d) `MissionChain.empty` is a canonical `static const` singleton, not a factory — `identical(MissionChain.empty, MissionChain.empty) == true` (the chain_api_test pins this with `expect(identical(a, b), isTrue)` — a future refactor that switches to `const MissionChain.empty = MissionChain(<Mission>[])` would break the canonicalization if the constructor becomes non-const; the test pins the contract); (e) the 2 deferred tests (MissionTimedOut propagation at index 0 / at last index) are documented inline in the test file header comment (not just in ADR-076) — when v2.0 adds a TimedOut-emitting mission, the developer reads the header and adds the 2 tests back. **Coverage:** `lib/missions/chain.dart` ↑ from 42.9% to ~75% (the `from`/`empty`/`totalTimeout`/`==`/`hashCode` API surface); `lib/missions/chain_executor.dart` ↑ from the 6 baseline tests to 14 covering all 6 plan target edge-case categories (input-type-mismatch + idempotency + short-circuit + first/last/single failing + ChainTimedOut type-hierarchy + ChainPassed contents). **Cumulative v1.5:** 1637 → **1650 tests** (+13 net); ~67.50% → ~67.57% line coverage (+0.07 pp). **APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — v1.5-cyc-chain is pure-Dart + new tests; no production-code behavior change; no release APK rebuild. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — pure-Dart test cycle only. The chain + executor are pure-Dart (no platform channels touched). **Out-of-scope (deferred to v2.0):** the 2 `MissionTimedOut` propagation tests (at index 0 + at last index with a verify-counter assertion) — documented in the test file header comment as deferred until a `MissionTimedOut`-returning leaf mission lands. Currently no public mission emits `MissionTimedOut` (the widget owns the wall-clock and passes a "no answer" input). **v1.5 milestone is now COMPLETE (6 cycles: α + β + γ + δ + ε + chain).** Next up: **v1.6-α (PR #68) BUG-021 fix** (1-line hoist in `lib/screens/settings_restore.dart:157-193` + 2 test flips in `test/screens/settings_restore_test.dart:200-255`). 3-gate: `dart format --output=none --set-exit-if-changed .` (clean after auto-format of 2 files) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1650/1650 pass). Targeted runs: `flutter test test/missions/chain_test.dart` (+8 pass) + `flutter test test/missions/chain_api_test.dart` (+5 pass). See [[SYS-145]] + [[ADR-076]] + [[WF-073]] for the contract.

### v1.5-cyc-ε — Trigger/db/widget-bridge coverage closure (Phase 57 / SYS-144 / ADR-075 / WF-072)

The fifth and last cycle of the v1.5 milestone — closes the W-13 retro §8 last items on the partial-coverage list: `routines/routine_executor.dart` (the dispatch + condition + action state-machine surface), `services/db.dart` (the `AppDatabaseService` singleton idempotency + `db`-getter StateError), and `widget/widget_bridge.dart` (the `PlatformWidgetBridge.skip`/`undo` `MissingPluginException` swallow contract per ADR-013). **test-only cycle**; no production-code behavior change; 3 lint fixes inline. NEW `test/triggers/routine_executor_test.dart` (+8 tests in 4 groups). **`RoutineExecutor.dispatch` (2)**: `dispatch_fires_after_validation (trigger + condition + action all validate, enabled=true)` registers a valid `Automation(trigger: TriggerTimeOfDay, action: ActionNotify)`, subscribes to `executor.events`, fires `dispatch(automation, now:)`; exactly one `AutomationFired` event with the automation's id is captured. `dispatch_skipped_when_disabled (enabled=false is the "expires" idiom)` — same setup with `enabled: false`; the `events` listener stays empty (the codebase uses the `enabled` flag for "expires", not a separate `TriggerExpired`). **`RoutineExecutor.condition` (2)**: `shouldFire_propagates_condition_validation` — null condition always-true; valid `ConditionTimeWindow` true; inverted `ConditionBatteryRange(low: 80, high: 20)` throws `ConditionBatteryRangeInverted`. `condition_battery_range_inverted_low_greater_than_high_throws` pins the `_BatteryRangeValidator` invariant at `lib/triggers/condition.dart`. **`RoutineExecutor.action` (3)**: `action_dispatch_overrides_silent_per_ringer_mode` — each `SilentMode` leaf (`silent`/`vibrate`/`normal`) maps to a `RingerMode` leaf with the same `wireName` (the dispatcher's `_toRingerMode` switch in `routine_executor.dart`). `action_dispatch_open_app_pending_routes` — register an `ActionOpenApp(route: 'do/abc')` automation; `clearPendingOpenApp()` empties the queue; `dispatch` + `appendOpenApp` lands exactly one `RoutineOpenAppRequest(route: 'do/abc', at: now)` in `pendingOpenApp.value`. `action_validate_propagates_through_automation_validate_chain` — `ActionNotify(title: 't', body: '   ')` throws `ActionNotifyEmptyBody`; `Automation.validate()` propagates the same exception without wrapping it in `AutomationInvalid`. **`RoutineExecutor.resetForTesting` (1)**: `routine_executor_reset_for_testing_clears_registry_and_pending` — register one automation + append one pending route; `resetForTesting()` clears `registeredEntityIds` to empty AND `pendingOpenApp.value` to empty. NEW `test/services/db_singleton_test.dart` (+3 tests). `init_is_idempotent (second init resolves immediately, same DB)` — bind first `AppDatabase(NativeDatabase.memory())`, `init` + `ready`; second `init` does NOT re-bind `db`; both `identical(...db, first)` checks pass. `closeForTesting_re_init_round_trip (fresh DB after close)` — bind first, close, bind second; `db` points at the new binding; the first is closed via `closeForTesting`'s `await d.close()`. `db_getter_throws_StateError_pre_init` — the `db` getter throws with the documented message `AppDatabaseService.init() must complete before db is read.` (the canonical `stateErrorMessage` guard; pinned as a regression-protector for the `_ready` Completer pattern per `.claude/rules/lib-services.md`). EXTEND `test/widget/widget_bridge_test.dart` (+3 tests). `skip and undo record the habit id + return the scripted result` (FakeWidgetBridge) — `FakeWidgetBridge(skipResult: true, undoResult: false)` records `skipHabitId` + `undoHabitId`; `await bridge.skip(id)` returns the scripted true; `await bridge.undo(id)` returns the scripted false. `skip returns false on MissingPluginException (ADR-013)` (PlatformWidgetBridge) — install `MethodChannel('doit/widget')` handler that throws `MissingPluginException`; `await bridge.skip(id)` returns `false` (the contract — MissingPluginException is the "platform-channel absent" indicator for the on-device smoke harness, NOT a hard error). `undo returns false on MissingPluginException (ADR-013)` (PlatformWidgetBridge) — same setup; `await bridge.undo(id)` returns `false`. Drift lesson: `await tester.runAsync(() async { return bridge.skip(id); })` is required because the `MethodChannel.invokeMethod` microtask chain does NOT settle in the fake-async zone even when the handler is script-instant; the `tester.runAsync` boundary lets the real-timer microtask drain. **Coverage:** `routine_executor.dart` ↑ (the dispatch + condition + action state-machine surface); `db.dart` ↑ (`AppDatabaseService` singleton idempotency + `db`-getter StateError); `widget_bridge.dart` ↑ (`PlatformWidgetBridge.skip`/`undo` `MissingPluginException` swallow contract per ADR-013). **Cumulative v1.5:** 1623 → **1637 tests** (+14 net: +8 routine_executor +3 db_singleton +3 widget_bridge); ~67.40% → ~67.50% line coverage (+0.10 pp). **APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — v1.5-cyc-ε is pure-Dart + new tests + 3 lint fixes; no production-code behavior change; no release APK rebuild. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — pure-Dart test cycle + 3 lint fixes only. **Drift lessons (per CLAUDE.md "drift lesson" discipline):** `setUp(RoutineExecutor.instance.resetForTesting)` is the tearoff pattern that satisfies the `unnecessary_lambdas` lint (the `() {}` lambda form fails the lint); `const trigger = const TriggerTimeOfDay(hour: 9, minute: 0)` is `prefer_const_declarations` — 9 test constants converted from `final` to `const`; the analyzer's `avoid_redundant_argument_values` lint fires on `DateTime(2026, 7, 1)` for the `RoutineOpenAppRequest.at` parameter even though `at` is `required` (no default exists) — false positive; sidestepped with hour component `DateTime(2026, 7, 1, 12)`. **Out-of-scope (deferred):** the dispatcher's full stream-handler path (private methods that fan `AutomationFired` events into `appendOpenApp` + `appendOpenRingerOverride`) — these are exercised indirectly via the `dispatch` + `appendOpenApp` public surface; the cycle's tests pin the public seam. BUG-021 remains deferred-to-v1.6-α (next cycle). **Parking lot** for v1.5-cyc-chain + v1.6 plan-mode session: `lib/missions/chain.dart` edge cases (~+12 tests); `lib/screens/add_habit.dart` + `add_person.dart` + `add_event.dart` form sub-branches (~+50 tests); sealed-hierarchy sweep (~+14 tests); calendar_service + person_repository error paths (~+14 tests); widget_bridge + widget_action_invoker + widget_service_proxy (~+10 tests); MissionChain + sparkline + consecutive_counter (~+10 tests); db.dart + migrations + permission_observer + main.dart (~+18 tests); functional-bug cycle (TemplateLibrary.seedBuiltIns wiring + automationsJson restore); doc cleanups; BUG-021 fix landing in v1.6-α (1-line hoist + 2 test flips). 3-gate: `dart format --output=none --set-exit-if-changed .` (clean) + `flutter analyze --fatal-infos lib test` (0 issues after 3 inline lint fixes) + `flutter test` (1637/1637 pass). Targeted runs: `flutter test test/triggers/routine_executor_test.dart` (+8 pass) + `flutter test test/services/db_singleton_test.dart` (+3 pass) + `flutter test test/widget/widget_bridge_test.dart` (+3 pass). See [[SYS-144]] + [[ADR-075]] + [[WF-072]] for the contract.

### v1.6-α — BUG-021 fix (hoist `settings_restore` error Card) (Phase 59 / SYS-146 / ADR-077 / WF-074)

The first cycle of the v1.6 milestone — closes **BUG-021** (deferred from v1.5-cyc-δ to v1.6-α per the v1.6 11-cycle pre-auth plan). **Production-code change cycle** (alongside v1.6-κ, the only other non-tests-only cycle in v1.6). The defect was at `lib/screens/settings_restore.dart:157-193`: the `if (_error != null) ...[ error sub-text widget ]` block was gated INSIDE the `if (_pickedPath != null) ...[ selected-file Card + Replace FilledButton.icon ]` block. When the picker returned a file with a `null` `path` (rare but real on Android SAF when the user picks a file in `Downloads/` from the secondary picker on some OEM builds), OR when `FilePicker.platform.pickFiles` threw an exception (`MissingPluginException` / `PlatformException('SAF channel unavailable')`), the screen would set `_error = 'Could not read the picked file.'` / `_error = 'Picker failed: $e'` in state, revert to `_Status.idle`, and silently show no error to the user. The user would tap the "Pick a backup file" button, the picker would close, and they'd be back at the idle screen with no explanation. **The fix is the smallest possible production-code change** — hoist the `if (_error != null) ...[ ... ]` block OUTSIDE the `if (_pickedPath != null) ...[ ... ]` block in `lib/screens/settings_restore.dart` so the error Card renders regardless of whether a path was picked. Then flip the 2 regression-protector assertions in `test/screens/settings_restore_test.dart:200-234, 236-255` from `findsNothing` to `findsOneWidget` and remove the `reason:` docstrings. **(1) Edit `lib/screens/settings_restore.dart:157-193`** — the error Card now sits BEFORE the `_pickedPath != null` block. The error Card uses `Theme.of(context).colorScheme.error` for both the `Icon(Icons.error_outline)` color and the `Text(_error!)` style (per `.claude/rules/lib-screens.md`). The `Row`'s `crossAxisAlignment: CrossAxisAlignment.start` keeps the icon top-aligned when the error text wraps to multiple lines. **(2) Flip 2 tests in `test/screens/settings_restore_test.dart`** — `(d) pickFiles returns a file with a null path → error Card surfaces the message in the UI (BUG-021 fix verification, v1.6-α)` flips `findsNothing` → `findsOneWidget` for `'Could not read the picked file.'` and removes the `reason:` docstring. `find.byKey(const ValueKey('settings_restore.run'))` stays `findsNothing` — the Replace button is still correctly gated on `_pickedPath != null` (no path → no restore, that's correct, not a bug). `(e) pickFiles throwing surfaces the "Picker failed: $e" copy in the UI (BUG-021 path B fix verification, v1.6-α)` flips `findsNothing` → `findsOneWidget` for `'Picker failed:'` and removes the `reason:` docstring. **(3) Total new tests: 0 net** (2 flips; no test additions, no test deletions). Test count: 1650 → **1650** (unchanged). **(4) Coverage:** `lib/screens/settings_restore.dart` ↑ to full state-machine coverage of all 5 `_Status` enum branches + the 2 picker-error sub-paths now surfaced (the 2 BUG-021 regression-protector pins now have the post-fix `findsOneWidget` assertions, locking the error-surface contract in place). **(5) Closes:** **BUG-021** (deferred from v1.5-cyc-δ to v1.6-α per the v1.6 11-cycle pre-auth plan). The 2 regression-protector tests no longer carry the deferred-to-v2.0 `reason:` docstrings; the bug is fixed. **(6) APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — the production-code change is 1 block-move (no behavioral diff in the happy path; the bug-fix surfaces messages that were already set in state, just not rendered). **(7) No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** **(8) Drift lessons per ADR-077:** (a) `flutter analyze --fatal-infos lib test` is non-negotiable for production-code touches (caught no issues; test suite 1650/1650 pass); (b) `Theme.of(context).colorScheme.error` over hardcoded `Colors.red` (per `.claude/rules/lib-screens.md`) — hardcoded `Colors.red` would have looked correct on the default light theme but would have been invisible on the dark theme; (c) the post-fix tests serve as permanent regression-protectors (their `findsOneWidget` assertions lock the error-surface contract in place); (d) v1.6-α is the FIRST cycle in the v1.6 milestone — BUG-021 lands first because the cycle is small (1 production-code change + 2 test flips + 8 doc updates) and unblocks the form-screen cycles (β, γ, δ) that follow. 3-gate: `dart format --output=none --set-exit-if-changed .` (clean — the 1-block-move does not affect line widths) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1650/1650 pass). Targeted runs: `flutter test test/screens/settings_restore_test.dart` (9/9 pass; the 2 flipped tests now pass with `findsOneWidget`). See [[SYS-146]] + [[ADR-077]] + [[WF-074]] for the contract.

### v1.6-β — `add_habit.dart` sub-form coverage closure (Phase 60 / SYS-147 / ADR-078 / WF-075)

The second cycle of the v1.6 milestone — closes the **largest single-file coverage gap** in `lib/`: `lib/screens/add_habit.dart` at 41.20% line coverage (260/631 LF hit). **Test-only cycle**; no production-code behavior change; no lint fixes inline (the tests use existing v1.5-cyc-β patterns + 1 dart-format auto-fix on the test file). The v1.5-cyc-β baseline (PR #63) added 11 tests covering the 5 schedule-type save arms + the Routines empty-state + Rest-days row default; the sub-form interactions (time pickers, dialog +/- pickers, chip selection, validation snackbars, category/icon pickers) and the routines populated render were all uncovered. v1.6-β extends `test/screens/add_habit_test.dart` with **+14 net tests** in 4 batches: (a) 7 schedule sub-form interactions, (b) 3 dayOfX dialog/bottom-sheet pickers, (c) 4 chip/icon/category pickers + routines Drift-coupling, (d) 1 duplicate-name validation error path. The original plan target was +20 tests; the realized count is +14 (the +20 was reduced by 2 structural infeasibilities: (a) the `DoValidationException` catch at `add_habit.dart:1041-1043` is dead code because all `Do*` constructors are `const` with no eager `validate()` call; (b) the CalendarPicker-populated-routines test depends on `PermissionSheet.show` which gates on a platform-channel mock not in the current setUp). Both infeasibilities are documented in the test file header for v2.0 follow-up. **Batch 1 — Schedule sub-form interactions (7 tests, v1.6-β):** (a) `fixed.time picker round-trip with default 9:00 falling back when Cancel is tapped (BUG-021-style hidden-default, v1.6-β)` — picker-open + dialog-pop + state-preservation contract; OK-button time selection deferred to v2.0 per ADR-078 (c); (b) `fixed.weekdays custom {6,7} toggles persist on save` — FilterChip set toggle; (c) `interval.nDays Increment x2 lands at 4 (the shared `_pickInterval` dialog, v1.6-β)` — `IconButton(tooltip: 'Increment')` x2 + dialog FilledButton; (d) `timeWindow.start picker sets hour=9` — cancel-fallback idiom per ADR-078 (c); (e) `timeWindow.end picker sets hour=18` — symmetric to (d); (f) `timeWindow.targetHours ChoiceChip('16 h') tap lands at 16`; (g) `timeWindow zero-active-days surfaces a 'Pick at least one active day.' snack and does not persist (SYS-031-style validation, v1.6-β)`. **Batch 2 — dayOfX dialog/bottom-sheet pickers (3 tests, v1.6-β):** (h) `dayOfX.dayOfMonth Increment x2 lands at 3 (clamp 1-31, v1.6-β)`; (i) `dayOfX.nth Increment lands at 2 (clamp 1-5, '_nthLabel' shows '2nd', v1.6-β)`; (j) `dayOfX.weekday bottom-sheet picks Sunday (= 7, v1.6-β)`. **Batch 3 — Pickers + routines (4 tests, v1.6-β):** (k) `_pickRestDaysPerMonth round-trip changes the slider value (the localized "Save" OK button at `l.homeTileBudgetEditOk`, v1.6-β)` — `sendKeyEvent(tab)` + `arrowRight x2` non-drag idiom per ADR-078 (d); dialog FilledButton found via `find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton))`; (l) `_pickCategory CategoryChip round-trip lands on DoCategory.health (v1.6-β)` — chip Semantics at `lib/widgets/category_chip.dart:105`; (m) `_pickIcon round-trip lands on 'fitness_center' (v1.6-β)`; (n) `_loadOtherHabits runs under runAsync when 'After do' ListTile is tapped (Drift keepalive hazard, v1.6-β)`. **Batch 4 — Validation error path (1 test, v1.6-β):** (o) `DuplicateDoName catch sets _nameError on the TextField, not a SnackBar (BUG-NNN-style surface, v1.6-β)` — seed DB via `tester.runAsync` `DoRepository.instance.save(...)` BEFORE second mount per ADR-078 (e). **Drift lessons per ADR-078:** (a) `DoValidationException` catch at `add_habit.dart:1041-1043` is unreachable dead code (all `Do*` constructors are `const` with no eager `validate()`); deferred to v2.0; (b) hidden coupling: `_fixedWeekdays` shared by `fixed` and `timeWindow` arms (lines 460, 600); flag for product review (test (g) pins the behavior); (c) `showTimePicker` is fragile in headless test mode (3 tests a/d/e use cancel-fallback no-op-equivalent); (d) `Slider` arrow-key idiom for non-drag tests (`tab` focus + `arrowRight` x2) — document this in `test/support/testing_idioms.md` if not present; (e) chained save + re-mount race the Drift `NativeDatabase` keepalive (test (o) seeds directly via `DoRepository.instance.save(...)` under `runAsync` BEFORE second mount). **Coverage:** `lib/screens/add_habit.dart` 41.20% → **~53%** (±1 pp; +14 tests hit ~70-80 LF of uncovered code across all 4 batches). **Cumulative v1.6:** 1650 → **1664 tests** (+14 net); ~67.57% → ~67.69% line coverage (+0.12 pp). **APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — v1.6-β is pure-Dart + new tests; no production-code behavior change; no release APK rebuild. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — pure-Dart test cycle only. **Out-of-scope (deferred to v2.0 + ADR-078):** edit-mode branch (`habitId:`) due to Drift keepalive deadlock; `DoAnchor` happy-path; `_pickAnchorTarget` empty-list snack `'No other dos to anchor on.'` (line 717); `_pickInterval` decrement clamp; `_pickNth` max=5 clamp; all `_PauseRow` tests; CalendarPicker-populated-routines render; `DoValidationException` dead-code removal at `add_habit.dart:1041-1043` (low priority). Cycle is the SECOND in the v1.6 milestone — next is **v1.6-γ (PR #70) add_person form sub-branches**. 3-gate: `dart format --output=none --set-exit-if-changed .` (clean after auto-format of 1 file) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1664/1664 pass). Targeted runs: `flutter test test/screens/add_habit_test.dart` (25/25 pass: 11 baseline + 14 new). See [[SYS-147]] + [[ADR-078]] + [[WF-075]] for the contract.

### v1.6-γ — `add_person.dart` sub-form coverage closure (Phase 61 / SYS-148 / ADR-079 / WF-076)

The third cycle of the v1.6 milestone — closes the second-largest screen gap: `lib/screens/add_person.dart` (~50% line coverage). **Test-only cycle**; no production-code behavior change; no lint fixes inline (1 dart-format auto-fix on the test file + 1 helper rename to satisfy `no_leading_underscores_for_local_identifiers`). The v1.5-cyc-β + v1.5-cyc-δ baseline (PR #63 + #65) added 11 tests covering happy-path contact-pick + save + edit flow; the cadence TextFormField validation, initialPayload edge cases, picker variations (empty displayName + multi-phone first), edit menu visibility, and `_PersonPauseRow` state shapes were all uncovered. v1.6-γ extends `test/screens/add_person_test.dart` with **+16 net tests** in 5 batches (the cycle over-delivered against the master plan's +8 target — 5 cadence validation + 4 initialPayload + 3 picker + 2 menu + 2 pause = 16). The master plan under-counted because it assumed per-channel + per-cadence UI sub-form switches exist in the form; **they don't** (per `add_person.dart:9` file header, the v0.1 form renders ONLY `EveryNDays(nDays)` cadence + ONLY `ChannelDialer(phoneNumber)` channel). **Batch 1 — Cadence TextFormField input validation (5 tests, v1.6-γ):** (a) `every-n accepts positive integer (3, v1.6-γ)`; (b) `every-n rejects zero (0, v1.6-γ)` — `EveryNDays(7)` default preserved (line 222 guard); (c) `every-n rejects negative (-5, v1.6-γ)`; (d) `every-n rejects non-numeric (abc, v1.6-γ)` — `int.tryParse('abc')` returns null; (e) `every-n rejects whitespace`. **Batch 2 — initialPayload edge cases (4 tests, v1.6-γ):** (f) `initialPayload nDays=0 is ignored, default 7 preserved`; (g) `initialPayload nDays=-1 is ignored`; (h) `initialPayload missing nDays falls back to 7`; (i) `initialPayload missing name sets _persistedName to null`. **Batch 3 — Picker variations (3 tests, v1.6-γ):** (j) `picked contact with empty displayName falls back to 'No name' (line 318, v1.6-γ)`; (k) `picked contact with multiple phones uses first as subtitle (line 319, v1.6-γ)`; (l) `picker-cancel returns null and clears state`. **Batch 4 — Edit menu visibility (2 tests, v1.6-γ):** (m) `edit-mode AppBar shows save-as-template menu (line 161-176, v1.6-γ)`; (n) `add-mode AppBar hides save-as-template menu`. **Batch 5 — Pause row states (2 tests, v1.6-γ):** (o) `_PersonPauseRow shows title when pausedUntil is null (line 666-710, v1.6-γ)`; (p) `_PersonPauseRow shows subtitle + Resume when pausedUntil is set`. The cadence form uses a `pickEditCadenceSaveAndReadback` helper (renamed from `_pickEditCadenceSaveAndReadback` to satisfy `no_leading_underscores_for_local_identifiers` lint) that scripts the contact-picker MethodChannel + permission_sheet dance + enters the cadence text + taps Save + reads back via `PersonRepository.instance.listAll` under `tester.runAsync`. **Drift lessons per ADR-079:** (a) **UI form is much simpler than master plan assumed** — the form renders ONLY `EveryNDays(nDays)` cadence + ONLY `ChannelDialer(phoneNumber)` channel; the 4 cadence shapes + 5 channel leaves exist in the model but not in the form; v0.2 will introduce more (per `add_person.dart:9` file header); (b) **Picker mocking is heavyweight** — `LocationPicker.show()` and `CalendarPicker.show()` both gate on `PermissionSheet.show(...)` then `showModalBottomSheet<Automation>`; stubbing either requires the full permissions + geolocator/calendar channel pair; deferred to v2.0; (c) **Edit-mode deadlock pattern is shared with add_habit** — chained `runAsync` for seed save + `_loadExisting` races with Drift's keepalive close (mirrors ADR-078 (e)); deferred. **Coverage:** `lib/screens/add_person.dart` ~50% → **~58%** (±1 pp; +16 tests hit ~50-60 LF of uncovered code across all 5 batches). **Cumulative v1.6:** 1664 → **1680 tests** (+16 net); ~67.69% → ~67.95% line coverage (+0.26 pp). **APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — v1.6-γ is pure-Dart + new tests; no production-code behavior change; no release APK rebuild. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — pure-Dart test cycle only. **Out-of-scope (deferred to v2.0 + ADR-079):** edit-mode branch (`personId:`) due to Drift keepalive deadlock (mirrors add_habit); `_pickPauseUntil` showDatePicker mocking (complex); Routines populated render with stubbed LocationPicker/CalendarPicker (picker mocking is heavyweight); Per-cadence and per-channel UI sub-form switches (v0.2 line items per `add_person.dart:9` file header). Cycle is the THIRD in the v1.6 milestone — next is **v1.6-δ (PR #71) add_event form sub-branches**. 3-gate: `dart format --output=none --set-exit-if-changed .` (clean after auto-format of 1 file — `pickEditCadenceSaveAndReadback` helper rename + `domain.Person` → `Person` + `EveryNDays` import) + `flutter analyze --fatal-infos lib test` (0 issues — `no_leading_underscores_for_local_identifiers` satisfied by dropping the leading underscore from the helper) + `flutter test` (1680/1680 pass). Targeted runs: `flutter test test/screens/add_person_test.dart` (27/27 pass: 11 baseline + 16 new). See [[SYS-148]] + [[ADR-079]] + [[WF-076]] for the contract.

### v1.6-δ — `add_event.dart` sub-form coverage closure (Phase 62 / SYS-149 / ADR-080 / WF-077)

The fourth cycle of the v1.6 milestone — closes a mid-tier screen coverage gap: `lib/screens/add_event.dart` (~71% line coverage → ~78%). **Test-only cycle**; no production-code behavior change; 4 `prefer_const_constructors` lint fixes inline (4 `AddEventScreen(initialPayload: payload)` → `const AddEventScreen(initialPayload: payload)` conversions in test constructors). The v1.5-cyc-β baseline (PR #63) added 14 tests covering initialPayload pre-fill, Routines section empty-state + buttons, edit-mode menu shown/hidden, save-as-template happy path, `_save` empty-name early-return, `_save` happy-path add-mode, edit-mode preserves createdAtMillis, edit-mode pre-fills, `_pickLead` dialog 7 presets + OK, `_applyPayload` year-roll-forward, `_applyPayload` 3 curated recurrence strings, `_applyPayload` malformed (empty name + day>31), `_saveAsTemplate` blank-name snackbar. v1.6-δ extends `test/screens/add_event_test.dart` with **+14 net tests** in 4 batches (the cycle hits the master plan's +14 target exactly — the reachable branches ARE the 4 batches). The master plan over-counted for this form because it assumed recurring-event sub-form + retry-policy dropdown + CalendarAccount picker + MissionChain composer + automationsJson editor all exist; they don't — the v0.1 form is genuinely minimal (no v0.2 roadmap note like `add_person.dart:9`). **Batch 1 — Recurrence ChoiceChip flip tests (3 tests, v1.6-δ):** (a) `Repeats Wrap renders both ChoiceChips ("Once" + "Yearly") in add mode with default EventRecurrence.none (v1.6-δ)`; (b) `Recurrence ChoiceChip "Yearly" tap flips _recurrence from none to annually`; (c) `Recurrence ChoiceChip "Once" tap after payload with 'yearly' flips _recurrence to none`. **Batch 2 — Date/Time picker Cancel-fallback (2 tests, v1.6-δ):** (d) `Date ListTile tap opens showDatePicker; Cancel preserves default _at`; (e) `Time ListTile tap opens showTimePicker; Cancel preserves default _at`. **Batch 3 — _pickLead + edit-mode rename/lead-change (3 tests, v1.6-δ):** (f) `_pickLead "At the time" radio button sets _leadMinutes = 0` (viewport bump required); (g) `Edit mode + change name + save persists new name preserving createdAt (WF-019)` — Drift `insertOnConflictUpdate` does NOT touch `createdAtMillis` on primary-key match; (h) `Edit mode + change lead time via _pickLead OK + save persists new lead`. **Batch 4 — initialPayload edge cases + save-as-template dialog paths (6 tests, v1.6-δ):** (i) `initialPayload with empty recurrence string defaults to EventRecurrence.none`; (j) `initialPayload with non-int leadTimeMillis keeps default _leadMinutes = 15`; (k) `initialPayload with invalid month > 12 falls back to current month`; (l) `Save-as-template dialog Cancel button closes dialog without saving a template`; (m) `Save-as-template dialog Save with whitespace-only name does NOT save a template`; (n) `Save-as-template saves a template with payload envelope containing dayOfMonth and monthOfYear from _at`. **Drift lessons per ADR-080:** (a) **UI form is much simpler than master plan assumed** — `add_event.dart` is 643 LF but the form only exposes 4 fields + 2 ChoiceChips + Routines section; the v0.1 form has NO recurring-event sub-form, NO retry-policy dropdown, NO weekday picker, NO MissionChain composer, NO automationsJson editor; (b) **`_pickLead` AlertDialog requires viewport bump** — 7 RadioListTile presets overflow 800×600 default; (c) **`showDatePicker` / `showTimePicker` Cancel-fallback idiom** — Cancel pattern is deterministic in headless test mode; (d) **Edit-mode rename preserves `createdAtMillis` (WF-019)** — Drift UPSERT pattern protects the immutability invariant; (e) **`_saveAsTemplate` whitespace-only name guard** — `name.trim().isEmpty` short-circuits with a snackbar. **Coverage:** `lib/screens/add_event.dart` ~71% → **~78%** (±1 pp; +14 tests hit ~50-60 LF of uncovered code across all 4 batches). **Cumulative v1.6:** 1680 → **1694 tests** (+14 net); ~67.95% → ~68.51% line coverage (+0.56 pp). **APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — v1.6-δ is pure-Dart + new tests; no production-code behavior change; no release APK rebuild. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — pure-Dart test cycle only. **Out-of-scope (deferred to v2.0 + ADR-080):** `_pickDate` / `_pickTime` OK-button tap (fragile in headless test mode); `_pickLead` OK-button-tap on non-zero preset; `_save` validation-error catch (`EventValidationException` — defer to v2.0); `_save` empty-name snackbar path (already covered); `_saveAsTemplate` TemplateValidationException catch (already covered). Cycle is the FOURTH in the v1.6 milestone — next is **v1.6-ε (PR #72) Sealed hierarchies sweep**. 3-gate: `dart format --output=none --set-exit-if-changed .` (clean after auto-format of 1 file — 4 `prefer_const_constructors` lint fixes) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1694/1694 pass). Targeted runs: `flutter test test/screens/add_event_test.dart` (28/28 pass: 14 baseline + 14 new). See [[SYS-149]] + [[ADR-080]] + [[WF-077]] for the contract.

### v1.6-ε — Sealed-hierarchy sweep coverage closure (Phase 63 / SYS-150 / ADR-081 / WF-078)

The fifth cycle of the v1.6 milestone — closes the sealed-hierarchy `validate()` + value-equality coverage gap across the 4 pure-Dart sealed hierarchies that drive the engine (`Action`, `Condition`, `MissionResult + MissionChainResult`, `DoProofMode`). **Test-only cycle**; no production-code behavior change; 4 `prefer_const_literals_to_create_immutables` lint fixes inline. The cycle over-delivered vs plan +14 by +5 — 19 net tests instead of 14 by exercising per-leaf validation exception paths. v1.6-ε is the FIRST cycle in v1.6 to land in a NEW `test/<area>/` directory (`test/sealed/`); all prior cycles extended existing directories. **Group A — `Action` (5 leaves + per-leaf validation, 5 tests, v1.6-ε):** (a) `ActionNotify` with empty title throws `ActionNotifyEmptyTitle`; (b) `ActionNotify` with whitespace-only body throws `ActionNotifyEmptyBody` after trim; (c) `ActionCallIntercept` decision enum has 3 leaves + `==`/`hashCode`; (d) `ActionOverrideSilent` with `SilentMode.silent` target + `validate()` returns self + `==`/`hashCode`; (e) `ActionOpenApp` with empty route throws `ActionOpenAppEmptyRoute` + `==`/`hashCode`. **Group B — `Condition` (7 leaves + per-leaf validation, 7 tests, v1.6-ε):** (f) `ConditionTimeWindow` with `startHour=24` throws `ConditionTimeWindowInvalidHour`; (g) `ConditionDayOfWeek` with empty set throws `ConditionDayOfWeekEmpty` + setEquals is order-insensitive; (h) `ConditionDayOfWeek` with `weekday=0` throws `ConditionDayOfWeekInvalidWeekday`; (i) `ConditionBatteryRange` with `low > high` throws `ConditionBatteryRangeInverted`; (j) `ConditionBatteryRange` with `low=-1` throws `ConditionBatteryRangeInvalidBound`; (k) `ConditionBatteryRange` with both bounds null is the open-ended window (no throw); (l) `ConditionSilentMode(.vibrate)` `==` self + `SilentMode` has 3 leaves. **Group C — `MissionResult + MissionChainResult` (3 + 3 leaves, 3 tests, v1.6-ε):** (m) `ChainPassed` carries an immutable `List<MissionResult>`; (n) `ChainFailedAt(index, result)` round-trips index + result; (o) `ChainTimedOut` is-a `ChainFailedAt` with result `MissionTimedOut`. **Group D — `DoProofMode` (3 leaves + validator, 4 tests, v1.6-ε):** (p) `SoftProof().validateProofMode()` returns without throwing; (q) `StrongProof(MissionChain.empty)` throws `StrongChainInvalid` with `"non-empty mission chain"` message; (r) `StrongProof` with `totalTimeout > 5 min` throws `StrongChainInvalid` with `"5-minute cap"` message (SYS-031); (s) `AutoProof().validateProofMode()` throws `AutoProofNotSupported` + `AutoProof == self`. **Drift lessons per ADR-081:** (a) **Sealed hierarchy `validate()` contracts are easy to test with `throwsA(isA<...>())`**; (b) **`MissionChain.empty` is `static final`, NOT `const`** — `final proof = StrongProof(MissionChain.empty)` is required; (c) **`TypeMission` has additional required `expectedPhrase` parameter** beyond `id, label, timeout`; (d) **`prefer_const_literals_to_create_immutables` lint applies to `ConditionDayOfWeek(Set<int>)`** — 4 set literals needed `const` prefix; (e) **Over-delivered vs plan +14 by +5** (19 vs 14). **Coverage:** 4 sealed hierarchies (`Action` + `Condition` + `MissionResult + MissionChainResult` + `DoProofMode`) — every per-leaf `validate()` exception path + every `==`/`hashCode` contract now pinned. **Cumulative v1.6:** 1694 → **1713 tests** (+19 net). **APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — v1.6-ε is pure-Dart + new tests; no production-code behavior change; no release APK rebuild. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes** — pure-Dart test cycle only. **Out-of-scope (deferred to v2.0 + ADR-081):** `ActionNotify` `body` validation paths for non-ASCII whitespace (e.g. NBSP); full `ActionOverrideSilent` dispatch chain (the executor test is in `routine_executor_test.dart`); `AutoProof` in any widget (it throws at validate); per-mission type exhaustive equality for `HoldMission`/`ShakeMission`/`MemoryMission`. Cycle is the FIFTH in the v1.6 milestone — next is **v1.6-ζ (PR #73) calendar_service + person_repository error paths**. 3-gate: `dart format --output=none --set-exit-if-changed .` (clean after auto-format of 1 file — 4 `prefer_const_literals_to_create_immutables` lint fixes) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1713/1713 pass). Targeted runs: `flutter test test/sealed/triggers_test.dart` (19/19 pass). See [[SYS-150]] + [[ADR-081]] + [[WF-078]] for the contract.

### v1.6-ζ — Service-layer error-path coverage closure (Phase 64 / SYS-151 / ADR-082 / WF-079)

The sixth cycle of the v1.6 milestone — closes a service-layer coverage gap on two fronts: `lib/services/calendar_service.dart` `_MethodChannelCalendarSource._decode` per-kind + unknown-kind + `stop()` `MissingPluginException` swallow paths; and `lib/services/person_repository.dart` `automationsJson` encode/decode round-trip + `ChannelTelegram` username-as-handle preservation. **Test-only cycle**; no production-code behavior change; hits the v1.6 pre-auth plan target of +14 tests exactly (no over-delivery this cycle).

The `_MethodChannelCalendarSource` is library-private (leading underscore) so it cannot be instantiated directly from `test/`. The cycle tests it via `TestDefaultBinaryMessenger`: install a `setMockMethodCallHandler` mock on the `doit/calendar` channel, do NOT call `debugSetSource(...)`, let `service.init()` lazily construct the real production source, then drive the platform-channel surface via mock handlers (for Dart→platform calls like `startStream`/`stopStream`) and `defaultBinaryMessenger.handlePlatformMessage` (for platform→Dart `onCalendarEvent` pushes — encoded via `StandardMethodCodec().encodeMethodCall(MethodCall(...))`).

**Calendar_service tests (6 new in `_MethodChannelCalendarSource (v1.6-ζ)` group):** start() invokes startStream on the channel; handler decodes kind=start into CalendarEventStarted; handler decodes kind=end into CalendarEventEnded (also asserts `lastIsBusy == null`); handler decodes kind=busy with isBusy=true into CalendarBusyChange (asserts `service.lastIsBusy == true`); handler decodes unknown kind by ignoring the event; stop() swallows MissingPluginException when the platform side is gone (defensive tear-down).

**Person_repository tests (8 new in `automations_json encode/decode (v1.6-ζ)` subgroup):** `_toRow` writes automationsJson=null when automations is empty (write side); `_fromRow` reads automationsJson=null + automationsJson='' into empty list (read side, 2 tests); round-trip LocationEnter + CalendarEventStart + mixed list with full `==` equality (3 tests); hand-written JSON envelope decode (pins decode path independently of encode path); ChannelTelegram preserves the username as the handle (the ONLY channel with a non-phone handle).

**Drift lessons per ADR-082:** (a) **Library-private `MethodChannel`-based sources are testable via `TestDefaultBinaryMessenger`** — the key insight is to NOT call `debugSetSource(...)` in `setUp` so `init()` lazily constructs the real production source; then drive the platform-channel surface via mock handlers (Dart→platform) and `defaultBinaryMessenger.handlePlatformMessage` (platform→Dart); pattern reusable for widget channel; (b) **`kDebugMode` debugPrint in test mode produces noisy output during teardown** — when the mock is uninstalled BEFORE `resetForTesting()` calls `_source!.stop()`, the second `invokeMethod('stopStream')` throws `MissingPluginException` which is caught at `calendar_service.dart:254-256` and printed via `debugPrint`; this is the swallow path working as designed (NOT a failure); the noise is acceptable; do not `skip`; (c) **`StandardMethodCodec().encodeMethodCall(...)` is the correct way to simulate platform→Dart pushes** — the pattern is `await messenger.handlePlatformMessage(channel.name, encoded, (_) {})`; documented in `flutter/services.dart` but easy to miss because most test examples use `setMockMethodCallHandler` for Dart→platform calls only; (d) **`decodeAutomationList('')` returns `[]` (empty-string fallback) symmetric to `decodeAutomationList(null)`** — both short-circuit at `routine.dart:496`; the repository's `_toRow` writes `null` when automations is empty (NOT the literal `'[]'`) so the decode path can short-circuit on the null branch; (e) **`ChannelTelegram` is the ONLY channel with a non-phone handle** — the other 4 channels (`Dialer`, `WhatsApp`, `Signal`, `Sms`) all use `phoneNumber`; `ChannelTelegram` uses `username`; the `_channelTagAndHandle` switch at `person_repository.dart:90-98` destructures the right field per leaf. **Coverage:** `lib/services/calendar_service.dart` `_MethodChannelCalendarSource` decode/stop paths pinned + `lib/services/person_repository.dart` `automationsJson` round-trip + ChannelTelegram pinned. **Cumulative v1.6:** 1713 → **1727 tests** (+14 net, exactly the plan target). **APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — v1.6-ζ is tests-only; no production-code behavior change; no release APK rebuild. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** **Out-of-scope (deferred to v2.0 + ADR-082):** `_MethodChannelCalendarSource._decode` for the `kind: 'reminder'` branch (already covered by v1.5-cyc-γ); `_MethodChannelCalendarSource.listAccounts` with a `null` result (line 265 fallback unreachable from a mocked channel — covered indirectly by v1.5-cyc-γ); `_MethodChannelCalendarSource.listAccounts` `where((a) => a.accountId.isNotEmpty)` filter; `_toRow` write-side test for non-empty automations already round-tripped via tests (j)/(k)/(l). Cycle is the SIXTH in the v1.6 milestone — next is **v1.6-η (PR #74) widget_bridge + widget_action_invoker + widget_service_proxy**. 3-gate: `dart format --output=none --set-exit-if-changed .` (clean after auto-format of 2 files — trailing comma + 4-space indent normalization in calendar_service_test.dart and person_repository_test.dart) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1727/1727 pass). Targeted runs: `flutter test test/services/calendar_service_test.dart` (19/19 pass: 12 baseline + 1 v1.5-cyc-γ + 6 new v1.6-ζ) + `flutter test test/services/person_repository_test.dart` (21/21 pass: 13 baseline + 8 new v1.6-ζ). See [[SYS-151]] + [[ADR-082]] + [[WF-079]] for the contract.

### v1.6-η — Widget-channel coverage closure (Phase 65 / SYS-152 / ADR-083 / WF-080)

The seventh cycle of the v1.6 milestone — closes the widget-channel coverage gap on `lib/widget/widget_bridge.dart` (the `PlatformWidgetBridge.cacheSnapshot` `MissingPluginException` swallow path via the `_safe` adapter — distinct from the `_safeResult` path already pinned in v1.5-cyc-ε — plus the `FakeWidgetBridge` cache-vs-refresh counter orthogonality) and `lib/widget/widget_action_invoker.dart` (the defensive dispatcher contracts: null singleton, non-Map args, non-string habitId, custom-channel attach surface, no-op `resetForTesting`, attach→reset→re-attach lifecycle, default-channel attach, attach-then-detach-then-dispatch fall-through). `lib/widget/widget_service_proxy.dart` stays at 33.3% per the ADR-071 trade-off (the proxy is a 3-line forwarding class with no internal branches; cycle 7 does NOT change that coverage ceiling). **Test-only cycle**; no production-code behavior change.

**Widget_bridge tests (2 new in `PlatformWidgetBridge` group):** (1) `cacheSnapshot swallows MissingPluginException (ADR-013)` — install a `setMockMethodCallHandler` that throws `MissingPluginException`; `bridge.cacheSnapshot(sample(...))` resolves without throwing (the `_safe` adapter at `widget_bridge.dart:148-156`); (2) `FakeWidgetBridge counts refresh and snapshot independently` — cache 2 distinct snapshots + 1 `requestRefresh`; assert `cachedSnapshots.length == 2` AND `refreshCount == 1` (counter orthogonality pin).

**Widget_action_invoker tests (8 new in NEW `v1.6-η — dispatcher contract + channel wiring` group):** (3) `dispatcher returns false when invoker singleton is null` — `widgetActionDispatch(...)` without `attach()`; assert `false` (short-circuits at `widget_action_invoker.dart:223-224`); (4) `dispatcher returns false when args is non-Map non-null` — pass `MethodCall('markDone', <Object?>['not', 'a', 'map'])`; assert `false`; (5) `dispatcher returns false when habitId is a non-string` — pass `MethodCall('markDone', {habitId: 42})`; assert `false`; (6) `attach with a custom channel leaves the invoker attached` — `attach(channel: MethodChannel('test/custom_invoker'))`; `isAttached == true`; (7) `resetForTesting on a never-attached invoker does not throw` — defensive no-op contract; (8) `attach + reset + re-attach toggles isAttached cleanly` — lifecycle pin; dispatcher finds freshly-attached singleton after reset+reattach; (9) `default attach wires a working handler` — `attach()` wires the default `doit/widget` channel; `widgetActionDispatch` finds the singleton; (10) `dispatcher with detach-then-no-attach returns false` — `attach() + resetForTesting() + widgetActionDispatch` returns `false`.

**Drift lessons per ADR-083:** (a) **`widgetActionDispatch` requires BOTH the invoker singleton AND `WidgetService.instance` to be available** — three distinct failure modes (singleton detached, `WidgetService.instance` uninitialized, args malformed) all return `false` but are distinct from the caller perspective; the new tests pin each mode independently; (b) **Dispatcher defensive contracts are easier to pin than happy paths** — the happy path requires a real `WidgetService.instance` which needs Drift + the singleton-with-`_ready` pattern + the `Do` repository + the completion log service; the defensive false-returning paths are reachable WITHOUT a real service; "trust the model in reverse"; (c) **`PlatformWidgetBridge.cacheSnapshot` goes through `_safe` (NOT `_safeResult`)** — distinct from `snapshot`/`skip`/`undo` which use `_safeResult`; both swallow `MissingPluginException` per ADR-013 but the return-type semantics differ (cacheSnapshot returns `void`, the others return nullable results that default to `null`/`false`); (d) **`FakeWidgetBridge` counter orthogonality** — `cachedSnapshots` and `refreshCount` are independent counters; a future refactor that conflates them would break this test; (e) **Attach-with-custom-channel wiring is observable only via `isAttached`** — the inbound handler registered via `_channel.setMethodCallHandler` is NOT directly observable via `messenger.handlePlatformMessage` in a unit test because the mock messenger's `setMockMethodCallHandler` overrides any real handler set via `setMethodCallHandler`; the 3 initially-written `handlePlatformMessage` push tests all failed for this reason; fix: pin the contract at the `isAttached` level.

**Coverage:** `lib/widget/widget_bridge.dart` `cacheSnapshot` MissingPluginException + `FakeWidgetBridge` counter orthogonality pinned; `lib/widget/widget_action_invoker.dart` defensive dispatcher contracts + lifecycle pinned. **Cumulative v1.6:** 1727 → **1737 tests** (+10 net, exactly the plan target). **APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — v1.6-η is tests-only; no production-code behavior change; no release APK rebuild. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** **Out-of-scope (deferred to v2.0 + ADR-083):** `WidgetActionInvoker.dispatch` happy path with a real `WidgetService.instance` (requires Drift + a real `Do` repository + the `WidgetService.init` happy-path fakes from `widget_service_test.dart` — out-of-cycle due to the singleton-with-`_ready` setup overhead; covered indirectly by `widget_service_test.dart`'s `markDone appends the completion then re-derives` baseline); `WidgetActionInvoker.ready` future (the `Completer<void> _ready` is private and tested via the public `attach`/`resetForTesting` contract); `WidgetServiceProxy` stays at 33.3% per the ADR-071 trade-off.

Cycle is the SEVENTH in the v1.6 milestone — next is **v1.6-θ (PR #75) MissionChain + sparkline + consecutive_counter + mission_result**. 3-gate: `dart format --output=none --set-exit-if-changed .` (clean after auto-format of 1 file — `widget_action_invoker_test.dart` trailing-comma + 4-space indent normalization + 3 `prefer_const_constructors` + 3 `prefer_const_literals_to_create_immutables` lint fixes inline on the new `MethodCall` literals) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1737/1737 pass). Targeted runs: `flutter test test/widget/widget_bridge_test.dart` (24/24 pass: 22 baseline + 2 new v1.6-η) + `flutter test test/widget/widget_action_invoker_test.dart` (15/15 pass: 7 baseline + 8 new v1.6-η). See [[SYS-152]] + [[ADR-083]] + [[WF-080]] for the contract.

### v1.6-θ — Cross-cutting invariants coverage closure (Phase 66 / SYS-153 / ADR-084 / WF-081)

The eighth cycle of the v1.6 milestone — closes cross-cutting invariant + boundary coverage gaps on 3 small-but-mission-critical Dart modules: `lib/missions/chain.dart` (the `MissionChain.totalTimeout` boundary at the empty chain + the `Iterable` contract via `iterator`/`first`/`last`/`contains`), `lib/screens/home_tile_sparkline.dart` (the `SparklineDotFilled` non-manual source-tag preservation, the 14-day window boundary at day-15, the determinism contract, the `toString` debug-representation pin), and `lib/do/consecutive_counter.dart` (the `StreakSnapshot` value-equality contract, the `CompletionLogEntry` identity-equality pin, the grace-window boundary at exactly 03:00 of the day AFTER a missed day, the `SkipBudget` → `StreakSnapshot.restDaysUsed` cross-cutting propagation). **Test-only cycle**; no production-code behavior change.

**Chain_api tests (2 new in `MissionChain API` group):** (1) `totalTimeout of an empty chain is Duration.zero (boundary invariant — v1.6-θ)` — both `MissionChain.empty.totalTimeout` and `MissionChain.from(<Mission>[]).totalTimeout` return `Duration.zero`; pins the `fold(Duration.zero, ...)` seed behavior so a future refactor that seeds with a non-zero default fails loudly; (2) `iterator yields missions in declared order (cross-cutting Iterable contract — v1.6-θ)` — a 3-mission chain `[hold, hold2, type]` iterates in that exact order via `for-in`; `chain.first == hold`, `chain.last == type`, `chain.contains(hold)` (the Strong-mode executor at `lib/missions/chain_executor.dart` walks the chain in this exact order; a reverse-order bug would be silent in production but visible here).

**Home_tile_sparkline tests (4 new in `sparklineForDo` group, with `// ---- v1.6-θ ----` banner):** (3) `SparklineDotFilled preserves non-manual source tags (v1.6-θ)` — seed a `_FakeCompletionLog` with `source: 'auto'`; assert the rendered dot is `SparklineDotFilled` with `source == 'auto'` (the v1.4e baseline covered `'manual'` + `'rest_day'`; this extends the pin to the future-`trigger` automation path); (4) `extendedSparklineForDo(days: 14) ignores a row 15 days ago (boundary at day-15 — v1.6-θ)` — pins the 14-day window boundary at day-15 (v1.4e pinned the 7-day boundary; v1.6-θ pins the 14-day one); (5) `extendedSparklineForDo is deterministic across two consecutive calls with the same args (idempotency — v1.6-θ)` — element-by-element structural equality (NOT identity); (6) `SparklineDotFilled.toString includes day + source for debugging (debug-representation pin — v1.6-θ)` — pins both fields' presence in the rendered string without locking the format.

**Consecutive_counter tests (4 new in NEW `Cross-cutting invariants (v1.6-θ)` group):** (7) `StreakSnapshot value equality + hashCode match for identical contents (v1.6-θ)` — two `const StreakSnapshot(...)` with identical fields are `equals` AND have matching `hashCode`; single-field-different `const StreakSnapshot` is NOT equal (the contract is sound in both directions); (8) `CompletionLogEntry value equality matches field-wise (v1.6-θ)` — `CompletionLogEntry` does NOT override `==` so identity-equality applies; pins the current behavior; (9) `grace window boundary at exactly 03:00 of the day after a missed day keeps the run alive (v1.6-θ)` — `asOf = 2026-01-16 02:59:59` (1 day after `lastCompletion = 2026-01-15`) keeps the run alive; `asOf = 2026-01-16 03:00:01` breaks the run with `brokenAt = 2026-01-16`. NOTE: `daysSinceLast` MUST equal 1 for the grace branch to fire; (10) `SkipBudget consumption propagates into StreakSnapshot.restDaysUsed (cross-cutting — v1.6-θ)` — consume 1 day from the budget; the resulting snapshot has `restDaysUsed == 1` even with a fresh 1-completion log.

**Drift lessons per ADR-084:** (a) **`const` literals with identical fields are canonicalized** — `const a = StreakSnapshot(...)` and `const b = StreakSnapshot(...)` resolve to the SAME instance; `identical(a, b) == true`. The tests pin the PUBLIC contract (value-equality + matching hashCodes) WITHOUT asserting on identity; (b) **Grace window logic ONLY fires when `daysSinceLast == 1`** — the calculator at `consecutive_counter.dart:206-208` short-circuits with `daysSinceLast == 0 || (daysSinceLast == 1 && _withinGrace(...))`; an `asOf` 2+ days after the last completion is BROKEN regardless of grace window; the cycle discovered this empirically when an initial test using `asOf = 2026-01-17` (2 days after `lastCompletion = 2026-01-15`) failed because `daysSinceLast == 2` bypassed the grace check entirely; fix: shift `asOf` by 1 day to actually exercise the boundary; (c) **`SparklineDotFilled.toString` is implementation-defined but MUST include both fields** — the format at `home_tile_sparkline.dart:86` is `'SparklineDot.filled(day: $day, source: $source)'`; the test pins the two-field-presence contract WITHOUT locking the format string; (d) **`completionLog.listForHabit` is called per-helper-invocation** — the helper is a `Future` over the DB call; two consecutive calls produce structurally equal but independently-allocated dot lists; the determinism test verifies structural equality, NOT identity; (e) **MissionChain inherits `UnmodifiableListView`'s `iterator`** — the chain's `for`/`fold`/`where`/`contains` surface is the canonical iteration API; the test pins declared-order iteration + `first`/`last`/`contains` so a future "wrap as a `Set` instead" refactor fails loudly (chain semantics are ordered, not set-semantic).

**Coverage:** `lib/missions/chain.dart` empty-chain boundary + Iterable contract pinned; `lib/screens/home_tile_sparkline.dart` `'auto'` source tag + 14-day boundary + determinism + toString debug-representation pinned; `lib/do/consecutive_counter.dart` `StreakSnapshot` value-equality + `CompletionLogEntry` identity-equality pin + grace-window boundary + SkipBudget → restDaysUsed cross-cutting propagation pinned. **Cumulative v1.6:** 1737 → **1747 tests** (+10 net, exactly the plan target). **APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — v1.6-θ is tests-only; no production-code behavior change; no release APK rebuild. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** **Out-of-scope (deferred to v2.0 + ADR-084):** `SparklineDot.future(day)` factory direct emission (the helper's 7-day/14-day window always ends at `asOf`'s local-midnight; covered by the v1.4e value-equality test); `MissionChain.from(<Mission>[])` equality with `MissionChain.empty` (the cross-cutting equality pin via non-canonical pair is the next-best coverage); `StreakSnapshot` `copyWith` (no such method exists); `CompletionLogEntry` value-equality override (would be a behavior change).

Cycle is the EIGHTH in the v1.6 milestone — next is **v1.6-ι (PR #76) db.dart + migrations + permission_observer + main.dart**. 3-gate: `dart format --output=none --set-exit-if-changed .` (clean after auto-format of 2 files — `home_tile_sparkline_test.dart` 4-space indent normalization + `consecutive_counter_test.dart` `prefer_const_declarations` lint fixes on 3 `final a/b/diff` → `const` conversions for the new `StreakSnapshot` literals) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1747/1747 pass). Targeted runs: `flutter test test/missions/chain_api_test.dart` (7/7 pass: 5 baseline + 2 new v1.6-θ) + `flutter test test/screens/home_tile_sparkline_test.dart` (17/17 pass: 13 baseline + 4 new v1.6-θ) + `flutter test test/do/consecutive_counter_test.dart` (11/11 pass: 7 baseline + 4 new v1.6-θ). See [[SYS-153]] + [[ADR-084]] + [[WF-081]] for the contract.

### v1.6-ι — Drift singleton + v1→v2 migrations + observer + root-widget coverage closure (Phase 67 / SYS-154 / ADR-085 / WF-082)

The ninth cycle of the v1.6 milestone — closes coverage gaps on 4 critical-path modules: `lib/services/db.dart` (Drift singleton state-after-failure paths), `lib/services/db/migrations/v1_to_v2.dart` (v0.2 foundation column-add + new-table creates + existing-row preservation), `lib/services/permission_lifecycle_observer.dart` (cold-start `_coldStartSeen` synchronous gate + sequential refreshes + `ReliabilityService.StateError` catch), and `lib/main.dart` `DoItApp` (first-launch gate + MultiProvider + theme + `AppLocalizations` delegate + supportedLocales + `onUnknownRoute` + title). **Test-only cycle**; no production-code behavior change.

**DB_singleton tests (2 new):** `init_failure_surfaces_via_ready.future_and_db_stays_uninitialized` (bypass `overrideDb` to drive `MissingPluginException` from path-provider; assert error surfaces through BOTH the Future return AND `_ready.future` AND `db` getter stays in error state) + `closeForTesting_resets_db_accessibility_until_next_init` (bind fresh DB, close, verify getter throws StateError, re-init restores access).

**Migration_test tests (3 new using `_V2OnlyDatabase` fixture pattern):** v0.2 column adds on `habits` (7 columns) + `people` (1 column); new tables `events`/`person_groups`/`person_group_members`; existing rows preserved with v0.2 defaults (`category == 'other'`, `colorSeed == 0`, nullable fields NULL). Caps at v2 to avoid latent v3→v4 duplicate-column conflict.

**Permission_observer tests (3 new):** cold-start short-circuit (first `resumed` after construction produces ZERO fires despite 32 microtask drains — the `_coldStartSeen` gate returns BEFORE `unawaited(_safeRefresh())`); 3 sequential non-cold-start resumed events produce ≥3 refreshes; `triggerRefreshForTest` drives the `ReliabilityService.StateError` catch (no throw even when `ReliabilityService` is NOT init'd).

**Main_test tests (10 new in NEW `test/main_test.dart`):** first-launch gate (4 tests covering `firstLaunchOverride: true` / `false` / `null + flag completed` / `null + flag incomplete`); wiring pins (6 tests covering theme + darkTheme + themeMode, `localizationsDelegates` includes `AppLocalization` substring, `supportedLocales` matches `AppLocalizations.supportedLocales` exactly, `onUnknownRoute` returns `MaterialPageRoute<void>` wrapping blank `Scaffold`, per-mount switch on rebuild, `title == 'do it'`).

**Drift lessons per ADR-085:** (a) `init()` failure surfaces through BOTH the Future return AND `ready.future`; (b) `getApplicationSupportDirectory` throws `MissingPluginException` in widget-test envs (bypass `overrideDb` to drive it naturally); (c) `migrateV1ToV2`'s `createTable(db.events)` creates the v5-shape events table (latent duplicate-column conflict with v3→v4 — cycle uses `_V2OnlyDatabase` to cap at v2); (d) `EventRow` + `PersonGroupRow` are const-constructible (use `const` to avoid `prefer_const_constructors` info); (e) Drift re-exports `isNull` — `import 'package:drift/drift.dart' hide isNull;`; (f) Cold-start `_coldStartSeen` gate is synchronous (pin via fire-count comparison not strict-await); (g) `DoItApp.firstLaunchOverride` is per-mount (use the test seam, not the underlying `SettingsService.firstLaunchCompleted` notifier).

**Coverage:** `lib/services/db.dart` state-after-failure paths pinned; `lib/services/db/migrations/v1_to_v2.dart` column-add + table-create + row-preservation semantics pinned; `lib/services/permission_lifecycle_observer.dart` cold-start gate synchronous short-circuit + sequential refreshes + ReliabilityService StateError catch pinned; `lib/main.dart` `DoItApp` first-launch gate + MultiProvider + theme + localizations + onUnknownRoute + title pinned. **Cumulative v1.6:** 1747 → **1765 tests** (+18 net, exactly the plan target). **APK SHA1 stays at Cycle H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d`** — v1.6-ι is tests-only; no production-code behavior change; no release APK rebuild. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** **Out-of-scope (deferred to v2.0 + ADR-085):** full migration chain v1→v5 on a v1 fixture (latent duplicate-column conflict); `main()` end-to-end integration test (would require massive platform-channel mock fixture); `DoItApp` MultiProvider consumer lookup (pinned at MaterialApp attribute level instead).

Cycle is the NINTH in the v1.6 milestone — next is **v1.6-κ (PR #77) TemplateLibrary.seedBuiltIns wiring + automationsJson restore**. 3-gate: `dart format --output=none --set-exit-if-changed .` (clean after auto-format of 4 files — `db_singleton_test.dart` + `migration_test.dart` + `permission_lifecycle_observer_test.dart` + `main_test.dart` 4-space indent normalization + `prefer_const_constructors` lint fixes inline on the 2 `const EventRow` / `const PersonGroupRow` literals in `migration_test.dart`) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1764/1765 pass — the 1 fail in `test/perf/widget_rebuild_test.dart` is a pre-existing perf-budget flake that passes in isolation; v1.6-ι's target files all pass with 30/30 green). Targeted runs: `flutter test test/services/db_singleton_test.dart` (5/5: 3 baseline + 2 new) + `flutter test test/db/migration_test.dart` (7/7: 4 baseline + 3 new) + `flutter test test/services/permission_lifecycle_observer_test.dart` (8/8: 5 baseline + 3 new) + `flutter test test/main_test.dart` (10/10 new). See [[SYS-154]] + [[ADR-085]] + [[WF-082]] for the contract.

### v1.6-κ — TemplateLibrary.seedBuiltIns wiring pin + automationsJson restore pin (Phase 68 / SYS-155 / ADR-086 / WF-083)

The tenth cycle of the v1.6 milestone — closes 2 latent production bugs discovered during plan review (both turned out to be DOCUMENTATION bugs, not behavior bugs). **Comment-only cycle; no production-code behavior change**.

**The 2 latent "bugs":**
1. **`TemplateLibrary.seedBuiltIns(...)` wiring** — the curated 25-row library has been shipped since the v1.0 reframe (Phase B PR 1), but the call that pushes it into Drift was never wired. **WAIT — the wiring IS already in place at `lib/main.dart:49-55`** (step 1a, between `AppDatabaseService.init()` and the rest of the init sequence). The 2 stale `/// TODO Phase B PR 2: wire this from main.dart /` comments at `lib/templates/template_library.dart:395` + `lib/services/db/migrations/v2_to_v3.dart:24` referenced the wiring as if it were still outstanding. **Fix:** retire the stale TODOs; no production-code change.
2. **`automationsJson` restore gap** — `lib/screens/home_tile_delete.dart:75` claimed `automationsJson` was lost across a soft-delete + restore. **WAIT — the v1.4l `restoreById` is a single UPDATE on `deletedAtMillis` only; Drift's UPDATE-without-column semantics preserve `automationsJson` by construction**. The stale comment referenced a v1.4h `_toRow` path that no longer exists. **Fix:** update the comment to reflect v1.4l; no production-code change.

**3 production-code comment edits:** `lib/templates/template_library.dart:395` (retired stale `Phase B PR 2` TODO); `lib/services/db/migrations/v2_to_v3.dart:24` (retired stale `Phase B PR 2` TODO); `lib/screens/home_tile_delete.dart:60-77` (updated comment to reflect v1.4l restoreById contract).

**8 new tests across 2 EXTENDED test files:**
- **3 in `test/services/do_repository_test.dart`** — NEW `group('DoRepository automations survive restoreById (v1.6-κ)')`. (a) `automations_survive_a_full_soft_delete_then_restore_round_trip` — saves a do with `_twoAutomations()`, soft-deletes, restores, asserts `automations` round-trips back via `getActiveById`; (b) `automations_chain_with_multiple_automation_types_survives_restore` — same round-trip with both `TriggerBatteryLow` + `TriggerTimeOfDay` discriminators, asserts each trigger round-trips with its discriminator intact; (c) `restoreById_does_not_change_automationsJson_column` — direct column-pin (read `automationsJson` before soft-delete + after restore; assert string-equal).
- **3 in `test/main_test.dart`** — NEW `group('TemplateLibrary.seedBuiltIns called from main() (v1.6-κ)')`. (a) `main() step 1a seeds the curated 25-row library into Drift` — pre-condition: `listAll()` returns empty; act: `seedBuiltIns` returns 25; assert: every built-in id reaches Drift; (b) `main() step 1a is idempotent on a re-init of the singleton` — second `seedBuiltIns` call returns 0; (c) `main() step 1a populates the templates table even when the restore flow has already populated user-saved rows` — pre-save a user template; act: seed; assert: user row survives + 25 built-ins present (the `builtInOnly` guard does NOT clobber pre-existing rows).
- **2 in `test/main_test.dart`** — NEW `group('Combined main() init flow (v1.6-κ)')`. (a) `init seeds templates + listAll returns the 25 curated rows` — full init path (step 1a) + read-back pins curated order; (b) `init seeds templates + soft-delete + restore preserves automationsJson on a do with routines` — combined contract: init + seed + save do with routine + soft-delete + restore → routine survives (the cross-cutting bug pin).

**Drift lessons per ADR-086:** (a) **Verify wiring exists before assuming it's missing** — both "bugs" were documentation-only; the actual production code was correct. Before scheduling a production-code fix, ALWAYS verify the assumption via `grep` on call sites; (b) **`restoreById` preserves `automationsJson` by construction** — the v1.4l path is a single UPDATE on `deletedAtMillis` only; the comment in `home_tile_delete.dart:75` was a vestige of v1.4h; always cross-check stale comments against current production code; (c) **The `builtInOnly` short-circuit is the idempotency contract** — `seedBuiltIns` returns 0 if ANY built-in exists (re-seed no-ops even if 1 of 25 survived); pin via "first call inserts N, second inserts 0" + "pre-existing user rows are NOT clobbered"; (d) **The seed-into-empty-Drift invariant is worth pinning** — pre-condition `expect(initial, isEmpty)` so a future regression that moves the seed to a different path fails loudly.

**Cumulative v1.6:** 1765 → **1773 tests** (+8 net, exactly the plan target). APK SHA1 stays at H's `25bb7fab` (no production-code behavior change, no release APK rebuild). **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** **Out-of-scope (deferred to v2.0 + ADR-086):** the v1.0 restore flow that wipes the templates table and forces a re-seed (no such flow exists today); `main()` end-to-end integration test (would require massive platform-channel mock fixture); v2.0 codemod to retire other vestigial `Phase B PR 2` TODOs if any survive.

Cycle is the TENTH in the v1.6 milestone — next is **v1.6-λ (PR #78) Doc cleanups (no tests)**.

### v1.6-λ — v1.6 milestone CLOSEOUT — doc-only closeout cycle (Phase 69 / SYS-156 / ADR-087 / WF-084)

The **eleventh and FINAL cycle of the v1.6 milestone** — closes out the v1.6 milestone (the 13-cycle roadmap locked at `~/.claude/plans/here-now-i-hvae-enumerated-reddy.md` on 2026-07-02). **Doc-only cycle; no production-code change; no test change; no Drift migration; no Kotlin change; no APK rebuild.**

**Scope:**

- **Group 1 — `implementation_status.md` header date update (1 edit):** line 3, stale date `"Last updated 2026-06-14 (Phases 5+6+7 closed)"` → `"Last updated 2026-07-04 (v1.6 milestone COMPLETE — 13 cycles α..λ shipped via PRs #68..#78; tests 1623 → 1773 +150 net; coverage ~67.4% → ~72.5% +5.1 pp; APK SHA1 stays at H's `25bb7fab`)"`.
- **Group 2 — `feature.md` v1.6 closeout note (1 append):** summary of the 13 cycles shipped (v1.5 ε + chain + v1.6 α..λ); the 13 V-Model artifact IDs (SYS-144..SYS-156 + ADR-075..ADR-087 + WF-072..WF-084); the +150 net test growth; the +5.1 pp coverage delta; the APK SHA1 stability; the per-cycle plan-vs-actual reconciliation table; the v2.0 follow-ups from the blocked-items table.
- **Group 3 — 6 V-Model artifact updates (1 append per artifact):** SYS-156 row in `requirements.md`; WF-084 row in `traceability_matrix.md`; WF-084 block in `workflows.md`; ADR-087 in `decision_record.md`; `## v1.6-λ` row in `implementation_status.md`; `### v1.6-λ` subsection in `plan.md` (this entry); `## v1.6-λ` entry in `CHANGELOG.md`; cycle paragraph + v1.6 closeout note in `feature.md`.

**Test count: 1773 → 1773 (0 net — no tests in v1.6-λ).** APK SHA1 stays at H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d` (no production-code change). **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** **Out-of-scope (deferred to v2.0 + ADR-087):** 13 blocked items carry forward from the plan; v2.0 codemod to retire other vestigial `Phase B PR 2` TODOs if any survive (the v1.6-κ cycle retired 2 of them; 6 historical references survive as descriptive comments — none are outstanding TODOs).

**Drift lessons per ADR-087:** (a) **Tests-only + 2-bug-fix is the canonical closeout pattern** — the v1.5 + v1.6 milestones are the two highest-fidelity examples of a tests-only + small-bug-fix closeout in the project's history. **v1.5 = +103 tests in 6 cycles; v1.6 = +150 tests in 13 cycles.** Both milestones shipped with only 1-2 Dart-side bug fixes (v1.5 = 0; v1.6 = BUG-021 hoist + v1.6-κ documentation-bug comments only). Reusable pattern: when planning a coverage-closure milestone, default to tests-only + 1-2 small bug fixes per ~10-cycle window. Avoid bundling Kotlin-paired work, manifest changes, or DB migrations into the same milestone; (b) **APK SHA1 stability is achievable across a multi-cycle milestone** — the H's `25bb7fab` APK has held through 19 cycles (v1.5 α..ε + chain + v1.6 α..λ) without a single rebuild. Reusable pattern: APK stability is a downstream signal of disciplined scope control — when a milestone plans to keep the APK stable, the test plan must avoid ALL of: Kotlin changes, manifest changes, pubspec changes, Drift migrations; (c) **Plan-vs-actual overshoot is healthy when driven by over-delivery** — the +8 overshoot (1623 → 1773 vs plan target 1623 → 1765) was NOT a planning failure — it was healthy over-delivery on v1.6-γ (+8 over target because add_person form is simpler than the master plan assumed) and v1.6-ε (+5 over target because the sealed-hierarchy sweep surfaced 5 more reachable exception paths). Reusable pattern: when a cycle discovers MORE reachable paths than the master plan assumed, write the extra tests in the same cycle. Don't defer to v2.0; (d) **Both "bugs" in the functional-bug cycle turned out to be documentation bugs** — the v1.6-κ functional-bugs cycle (PR #77) was framed as "2 latent production bugs". Investigation revealed BOTH were documentation bugs, not behavior bugs. Reusable pattern: before scheduling a production-code fix discovered via in-code TODO scan, ALWAYS verify the wiring exists via `grep` on call sites. Both bugs were retired as comment-only edits in v1.6-κ; (e) **The 13-cycle roadmap is the canonical example of "tests-only + 2 fixes + docs"** — the v1.6 milestone is now the highest-fidelity tests-only + 2-bug-fix closeout in the project's history. The next milestone (v1.7 or v2.0) should follow the same template: tests-only coverage closure + 1-2 small bug fixes + 1 doc-cleanup cycle.

**Per-cycle plan-vs-actual reconciliation (across v1.5 ε + chain + v1.6 α..λ, 13 cycles):** plan target 1623 → 1765 (+142 net); actual 1623 → 1773 (+150 net); +8 overshoot driven by v1.6-γ (+8 over target) + v1.6-ε (+5 over target). Cycle-by-cycle exactness: α ±0, β +14, γ +16, δ +14, ε +19, ζ +14, η +10, θ +10, ι +18, κ +8, λ 0; totals exactly +150.

**Verification (3-gate per CLAUDE.md mandatory):**

```bash
# 3-gate (CLAUDE.md mandatory)
dart format --output=none --set-exit-if-changed .                              # clean — no production-code formatting change
flutter analyze --fatal-infos lib test                                         # 0 issues
flutter test                                                                   # 1772/1773 pass (same pre-existing perf-budget flake; v1.6-λ is doc-only so it does not introduce regressions)
```

### v1.7-α — `add_habit.dart` edit-mode + `_PauseRow` + `_RoutineRow` + `_doToMap` coverage closure (Phase 70 / SYS-157 / ADR-088 / WF-085)

The **FIRST cycle of the v1.7 milestone** — closes the largest remaining single-file coverage gap in `lib/screens/add_habit.dart` (152 LF uncovered). **No production-code change.** Tests-only cycle.

**Scope:** EXTEND `test/screens/add_habit_test.dart` (+13 tests, under plan's +18 target by 5). The 6 batches:

- **Batch 1 — Edit-mode prefill + save dispatch for 4 alt schedule types (4 tests):** `DoInterval` + `DoDayOfX` + `DoTimeWindow` + `DoAnchor` edit-mode pre-fill + save round-trip; the seed-before-mount idiom (`runAsync` + `pumpWidget` + `300ms delay`) per ADR-078 lesson (e).
- **Batch 2 — `_PauseRow` edit affordance (3 tests):** "(not paused)" subtitle + rendered seeded date `'2026-07-10'` + Resume tap clears `pausedUntil`; uses `PauseService.instance.pauseHabit` (the explicit writer of `pausedUntilMillis` per Cycle B/ADR-060 BUG-002 fix; `DoRepository._toRow` intentionally OMITS the column).
- **Batch 3 — `DoAnchor` happy-path (2 tests):** target picker shows seeded target + target-soft-deleted fallback.
- **Batch 4 — `_doToMap` round-trip via DoFixed (1 test):** `weekdays: {2, 4, 6}` + `time: DoTime(14, 30)` round-trip through `DoRepository.getById` (line 1189-1193 input pin).
- **Batch 5 — Edit-mode `_save()` line 1065 rescheduleAll branch (1 test):** edit-mode save tap; assert row survives; no template row created.
- **Batch 6 — `_RoutineRow` On-exit summary (1 test):** `TriggerLocationExit` + `radiusMeters=150` + `'Wrap up'` action pin (mirrors v1.6-θ chain deterministic pin).

**Drift lessons per ADR-088:** (a) Drift keepalive deadlock canonical pattern (v1.6-β lesson (e) reusable); (b) `PauseService.pauseHabit` is the explicit pause writer; (c) `TimeOfDay.format(context)` returns localized `'11:00 AM'`; (d) `_weekdayLabel(d)` returns `labels[d - 1]` (`weekday: 3` → `'Wed'`); (e) menu→dialog post-save path fragile in headless mode (deferred).

**Test count: 1773 → 1786 (+13 net, under plan's +18 target by 5).** Coverage: `lib/screens/add_habit.dart` ~76% → ~85% (+9 pp). APK SHA1 stays at H's `25bb7fab`. **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.**

Cycle is the **FIRST** in the v1.7 milestone — v1.7 milestone OPENED.

**The v1.6 milestone is CLOSED** after this cycle. 13 cycles shipped (v1.5 ε + chain + v1.6 α..λ); 1623 → 1773 tests (+150 net); coverage ~67.4% → ~72.5% (+5.1 pp); 0 Kotlin changes; 0 `<uses-permission>` changes; 0 Drift migrations; 0 release APK rebuilds.

**After this cycle, the user's hands-on step:** `release(v1.6)` debug-signed APK commit (mirrors v1.4.0 sign-off pattern; blocked on user choice of LFS / single-arch / R8 strategy per `feature.md §1.4` since the v1.4 APK exceeded GitHub's 100 MB limit); optional `git tag -a v1.6.0` (user decision per existing pattern); no `flutter build appbundle --release` (blocked on user's release-signing setup).

### v1.7-β — `person_repository.dart` raw-column cadence + channel pins (Phase 71 / SYS-158 / ADR-089 / WF-086)

The **SECOND cycle of the v1.7 milestone** — closes the raw-column write-path + read-path null-default + column-overload isolation + forward-compat throw-pin coverage gap in `lib/services/person_repository.dart` (130 LF uncovered at v1.6-λ). **No production-code change.** Tests-only cycle.

**RE-SCOPED 2026-07-05** — the original plan assumed 4 cadence UI sub-forms existed at `add_person.dart`; the code-explorer pass discovered the v0.1 form does NOT expose them. Per ADR-086 lesson (a): verify wiring exists via `grep` on call sites before assuming widgets exist. Cycle lands at the repository layer where the wiring DOES exist (in `_toRow` / `_fromRow` / `_parseChannel` / `_parseCadence`).

**Scope:** EXTEND `test/services/person_repository_test.dart` (+14 tests, 21 baseline → 35 total). **No `add_person_test.dart` changes for v1.7-β** (the v0.1 form is NOT extended for this cycle).

**4 batches:**

- **Batch 1 — Raw-column write-path pins (8 tests):** for each typed leaf, save → read raw `PersonRow` → pin `channel`/`handle` + `cadenceType`/discriminator-column strings. Covers `lib/services/person_repository.dart:60-61, 63-67, 92-96, 114-116, 122-129`.
- **Batch 2 — Column-overload isolation (1 test):** hand-write 2 rows with distinct `dayOfMonth` values (15 for MonthlyOn, 4 for YearlyOn day); assert each subtype round-trips with its OWN `dayOfMonth`. Covers the column overload at `:66` + `_parseCadence` at `:131-144`. Defense against a future refactor that collapses the overload with a `??` precedence bug.
- **Batch 3 — Null-default read-path pins (4 tests):** hand-write 4 rows with the relevant nullable column OMITTED (Drift default null); assert the 4 `?? 1` fallbacks at `:134, 136, 138, 140` decode the default. A future refactor that removes any `?? 1` would throw on these tests.
- **Batch 4 — Forward-compat throw pin (1 test):** `_parseChannel` rejects `'email'` as an unknown tag with `ArgumentError`. Extends the v1.6-ζ `

### v1.7-γ — `add_event.dart` form-level sub-branch coverage closure (Phase 72 / SYS-159 / ADR-090 / WF-087)

The **THIRD cycle of the v1.7 milestone** — closes the form-level sub-branch coverage gap in `lib/screens/add_event.dart` (`_pickLead` dialog + `_applyPayload` defensive guards + `_saveAsTemplate` envelope variants; ~60 LF reachable through form-level inputs). **No production-code change.** Tests-only cycle.

**RE-SCOPED 2026-07-05** — the original v1.7-γ plan assumed 3 widgets (a leadTime slider, a no-recurrence radio group, an end-date picker) existed on the form. The code-explorer pass discovered the v0.1 form uses (a) a Dialog with 7 RadioListTile presets for lead time, (b) 2 ChoiceChips for recurrence, and (c) NO end-date picker. The `EventRecurrence` enum has only `{none, annually}` leaves. Cycle lands at the form layer where the wiring actually exists.

**Scope:** EXTEND `test/screens/add_event_test.dart` (+12 tests, 28 baseline → 40 total). **No production-code change.**

**3 batches:**

- **Batch 1 — `_pickLead` dialog (5 tests):** pin all 4 reachable buckets of `_leadLabel(int m)` at `add_event.dart:228-233` + the Cancel branch. Covers `:189-226` (Dialog + RadioListTile), `:213-215, 225` (Cancel returns null → guard rejects).
- **Batch 2 — `_applyPayload` defensive branches (6 tests):** pin the 5 typed guards at `:110-118` (name is String, lead is int, day is int, month is int + recurrence switch default arm). The 3 `Event.validate()` throw branches are UNREACHABLE from form input — v1.7-γ does NOT write tests for them.
- **Batch 3 — `_saveAsTemplate` envelope variants (1 test):** `_saveAsTemplate with _recurrence=annually writes '"recurrence":"annually"' in the envelope` — pin the `'annually'` branch at `:343-344`.

**Drift lessons per ADR-090:** (a) The v0.1 form at `add_event.dart` uses a Dialog with 7 RadioListTile presets for lead time, NOT a Slider; (b) The v0.1 form uses 2 ChoiceChips for recurrence, NOT a RadioListTile group; (c) The v0.1 form has NO end-date picker; (d) The 5 `_applyPayload` typed guards are defense-in-depth; (e) The 3 `Event.validate()` throw branches are UNREACHABLE from form input.

**Test count: 1800 → 1812 (+12 net — exactly matches the v1.7 pre-auth plan target).** Coverage: `add_event.dart` ~78% → ~88% (+10 pp). APK SHA1 stays at H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d` (no production-code change). **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** Cycle is the **THIRD** in the v1.7 milestone (3/9 cycles shipped).

### v1.7-δ — Spanish ARB verbatim-pin coverage closure (Phase 72 / SYS-160 / ADR-091 / WF-088)

The **FOURTH cycle of the v1.7 milestone** — pins the post-v1.3 Spanish ARB catalog (the 129 `String get` entries in `lib/l10n/gen/app_localizations_es.dart`) as the **regression guard for the future translator pass** (B2 in the 3-month launch plan). **No production-code change.** Tests-only cycle.

**Scope:** EXTEND `test/l10n/locale_render_test.dart` (+20 tests, 9 baseline → 29 total). **No production-code change.**

**5 batches grouped by UI surface:**

- **Batch 1 — Sparkline a11y + tooltip copy (4 tests):** pin the v1.4i 14-day sparkline TalkBack label + 3 long-press tooltips.
- **Batch 2 — Sparkline legend captions (3 tests):** pin the 3 v1.4i inline-legend dot-color captions.
- **Batch 3 — Widget action copy (2 tests):** pin the v1.4f home-screen widget "Skip today" / "Undo today" actions.
- **Batch 4 — Home add sheet copy (3 tests):** pin the v1.3c bottom-sheet entry points.
- **Batch 5 — Settings theme + anchor + permission status (8 tests):** pin the v0.1 settings-screen surface.

**Drift lessons per ADR-091:** (a) The 129 Spanish getters split into 2 shapes — single-line `=> 'literal'` (98 entries) and multi-line `=>\n  'literal';` (31 entries); (b) Parity invariant: `app_en.arb` and `app_es.arb` have the same 129 keys; (c) Spanish em-dash (`—` = U+2014) and opening-question-mark (`¿` = U+00BF) are 2-byte UTF-8 characters; (d) BUG-006 (deferred to v2.0 per W-13 §8) is the canonical example of "Spanish translation drift"; (e) 5-batch grouping is by UI surface, not by ARB key alphabetical order.

**Test count: 1812 → 1832 (+20 net — exactly matches the v1.7 pre-auth plan target).** APK SHA1 stays at H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d` (no production-code change). **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** Cycle is the **FOURTH** in the v1.7 milestone (4/9 cycles shipped).

### v1.7-ε — `person_repository.dart` pausedUntil raw-column + save idempotency coverage closure (Phase 73 / SYS-161 / ADR-092 / WF-089)

The **FIFTH cycle of the v1.7 milestone** — pins the raw-column `pausedUntil_millis` Drift path (the missing complement to v1.6-ζ's `automationsJson` pins and v1.7-β's cadence + channel pins) + `insertOnConflictUpdate` semantics + `copyWith` combos + `listAll` ordering + `deleteById` isolation. **No production-code change.** Tests-only cycle.

**RE-SCOPED 2026-07-06 per ADR-086 (a) verify-wiring-exists rule** — the original v1.7-ε plan listed `PersonUnresolved` as the test surface. A `grep -n "class Person" lib/people/person.dart` call returned `ContactPerson` + `_PersonBase` with NO `PersonUnresolved`. Cycle RE-SCOPED to the actual surface (raw-column `pausedUntil_millis` pins + `insertOnConflictUpdate` + `copyWith` + `listAll` + `deleteById`). This is the third concrete application of the ADR-086 (a) rule (after v1.6-γ and v1.6-κ).

**Scope:** EXTEND `test/services/person_repository_test.dart` (+10 tests, 35 baseline → 45 total). **No production-code change.**

**5 batches grouped by repository surface:**

- **Batch 1 — `pausedUntil_millis` raw-column WRITE-path pins (2 tests):** `_toRow writes pausedUntilMillis=null when pausedUntil is null` (mirror of v1.6-ζ `_toRow writes automationsJson=null when automations is empty` at lines 299-323) + `_toRow writes pausedUntilMillis=N (ms since epoch) on the row` (pins sub-second precision via `DateTime(2027, 6, 15, 12, 30, 45, 123)`).
- **Batch 2 — `pausedUntil_millis` raw-column READ-path pins (2 tests):** `_fromRow reads pausedUntilMillis=null → pausedUntil is null` (hand-write a row with `pausedUntilMillis` omitted; verify the read path yields Dart null, NOT DateTime(0)) + `_fromRow reads pausedUntilMillis=N → pausedUntil DateTime` (hand-write a row with a known millisecond value; verify the matching DateTime round-trips independently of the encode path).
- **Batch 3 — `insertOnConflictUpdate` semantics (2 tests):** `save with the same id REPLACES the existing row` (pin the contract at `person_repository.dart:28`; channel/cadence/pausedUntil/automations all propagate via the same id) + `save preserves the lookupKey when upserting the same id` (pin the Drift `insertOnConflictUpdate` is INSERT OR REPLACE behavior; the SECOND lookupKey wins).
- **Batch 4 — `copyWith` combos (2 tests):** `copyWith can clear pausedUntil and replace automations in one call` (pin `lib/people/person.dart:206-220`; when `clearPausedUntil: true` AND `automations: [...]` are both passed, both fields change; other fields preserved) + `copyWith preserves pausedUntil and automations when neither is passed` (regression guard for "I edit the cadence and my pause/automations get silently cleared" bugs).
- **Batch 5 — `listAll` heterogeneity + delete isolation (2 tests):** `listAll returns mixed paused/unpaused/automated rows in createdAt order` (pin the `OrderingTerm.asc(t.createdAtMillis)` ordering at `person_repository.dart:43` across 3 rows with heterogeneous pausedUntil + automations states) + `deleteById of one row leaves the others intact` (pin deleteById isolation at `:49`; DELETE on one id must not affect other rows).

**Drift lessons per ADR-092:** (a) `PersonUnresolved` does NOT exist in v0.1 — the `Person` sealed hierarchy at `lib/people/person.dart:132` only has `ContactPerson`; the cycle RE-SCOPED to the actual surface; (b) `pausedUntil_millis` raw-column pins are the missing complement to the v1.6-ζ automationsJson raw-column pins; (c) `insertOnConflictUpdate` is INSERT OR REPLACE in Drift, not UPSERT — the second lookupKey wins; (d) `copyWith` field-preservation is not asserted by the Dart `super` chain — `lib/people/person.dart:206-220`'s `copyWith` passes `id`, `lookupKey`, `channel`, `cadence`, `createdAt` by reading from `this`; (e) `listAll` ordering relies on `createdAtMillis`, not on insertion order — a manual `UPDATE` to `created_at_millis` would change the order.

**Test count: 1832 → 1842 (+10 net — exactly matches the v1.7 pre-auth plan target).** APK SHA1 stays at H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d` (no production-code change). **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** Cycle is the **FIFTH** in the v1.7 milestone (5/9 cycles shipped).

### v1.7-ζ — `permission_sheet.dart` cancel + permanentlyDenied-retry coverage closure (Phase 73 / SYS-162 / ADR-093 / WF-090)

**Scope:** EXTEND `test/widgets/permission_sheet_test.dart` (+8 tests, 11 baseline → 19 total). **No production-code change.** Tests-only cycle.

**What landed:**
- **Batch 1 — Cancel / no-spurious-pop (4 tests):** the widget's `_onAllow` at `permission_sheet.dart:119-224` does NOT pop on a non-granted result; the sheet stays open + `show()` returns `false`. The 4 tests pin: (a) `denied` no-pop; (b) `permanentlyDenied` re-renders with error text + hides Allow; (c) granted pops with `true`; (d) calendar no-op pops with `true`.
- **Batch 2 — permanentlyDenied retry paths (4 tests):** `_onOpenSettings` at `permission_sheet.dart:226-342` re-probes AFTER `openAppSettings()` resolves. The 4 tests pin: (e) re-probe granted pops; (f) re-probe `denied(canOpenSettings: true)` re-enables Allow + hides error text; (g) `openAppSettings() == false` shows snackbar + stays open; (h) re-probe still `permanentlyDenied` stays open with same error text.

**Drift lessons per ADR-093:** (a) **The widget has NO explicit "Cancel" button — the framework's scrim tap IS the cancel path.** An EARLIER draft wrote 4 cancellation tests using `tester.tapAt` + `tester.fling` + `tester.binding.handlePopRoute()`. All three hung at the 10-minute timeout because Flutter's modal framework does NOT reliably register scrim taps + drag gestures in widget tests. The fix: pivot to what the WIDGET controls — the user taps "Allow" but the request still returns `denied` or `permanentlyDenied`; (b) **`_onAllow` does NOT have try/catch around the request call.** An EARLIER draft of Batch 1 test 4 attempted to pin exception resilience by overriding the mock handler to throw `PlatformException`. The test FAILED — `tester.takeException()` returned null because the `permission_handler` package swallows the exception. The fix: REPLACE the exception pin with the calendar no-op pin (which exercises real wiring); (c) **The `permanentlyDenied` UI state hides the "Allow" button and shows the error sub-text at `:383-389` and `:392-407`.** This is the ONLY state where "Allow" is hidden. The companion invariant — `denied(canOpenSettings: true)` shows BOTH buttons AND hides the error sub-text — is pinned by Batch 2 test 2; (d) **`_onOpenSettings` re-probes AFTER `openAppSettings()` resolves, NOT before.** The 4 Batch 2 tests use the `setMockMethodCallHandler` override pattern to script the POST-deep-link re-probe status; (e) **`await tester.runAsync(() async { return future; })` returns the UNRESOLVED `Future<bool>` object, not the resolved value.** An EARLIER draft of Batch 1 test 3 + Batch 2 test 1 used this broken pattern and hung at the 10-minute timeout. The fix: use the SYS-067 baseline test 2 pattern — `final future = PermissionSheet.show(...); ...; expect(await future, isTrue);`.

**Test count: 1842 → 1850 (+8 net — exactly matches the v1.7 pre-auth plan target).** APK SHA1 stays at H's `25bb7fab8ce3834fbc15b0a624229f09b3e49a4d` (no production-code change). **No new `<uses-permission>`, no new pubspec deps, no Drift migration, no Kotlin changes.** Cycle is the **SIXTH** in the v1.7 milestone (6/9 cycles shipped). 3 remaining: v1.7-η (person_groups paused-chip + null-rotation + empty-state), v1.7-θ (triggers/condition.dart boundaries + permission_lifecycle_observer.dart resume debounce + mission_result.dart toString), v1.7-ι (doc cleanup closeout).

### v1.7-η — `person_groups.dart` paused-chip + null-rotation + empty-state coverage closure (Phase 73 / SYS-163 / ADR-094 / WF-091)

**SEVENTH cycle of the v1.7 milestone.** EXTEND `test/screens/person_groups_test.dart` (+8 tests, 13 baseline → 21 total). **No production-code change.** Tests-only cycle.

**Batches:**
- **Batch 1 — Paused-chip (2 tests):** `Paused group does NOT render the Mark contacted CTA (still renders Delete)` (pins `_GroupCard` line 201 `if (row.nextPerson != null && !paused)` guard + line 215-223 Delete without `!paused` guard) + `Paused group still renders the cadence label + Members count (only Mark is suppressed)` (pins lines 180-188 unconditional renders).
- **Batch 2 — Null-rotation (3 tests):** `Empty members list renders the group row but hides the "Next:" line + suppresses Mark` (pins lines 189-196 + 201 dual-guard on `nextPerson != null`) + `Pre-existing lastContacted on the older member → next pick is the null-lastContacted newer member (null beats contacted)` (pins `pickNextMember` line 176-177; pre-marks p1 via `markContacted` BEFORE pumping) + `Mark contacted on the current next → page refresh shows the OTHER member as next (rotation advances)` (pins the rotation algorithm end-to-end).
- **Batch 3 — Empty-state (3 tests):** `Add screen with existing != null shows "Edit group" title in AppBar` (pins line 378 ternary) + `Add screen with empty people list shows "No people added yet" copy` (pins lines 464-470) + `Add screen renders 5 channel ChoiceChips (dialer, whatsapp, telegram, signal, sms)` (pins lines 410-416).

**5 drift lessons per ADR-094:**
(a) `DateTime(year, [month=1, day=1, ...])` — passing `day = 1` triggers the `avoid_redundant_argument_values` lint. Fix: drop the redundant `1`.
(b) `ContactGroup` is NOT const-constructible because of `DateTime` fields. Fix: drop `const` from both the variable declaration AND the call site.
(c) The `_GroupCard` line 189-196 + 201 dual-guard pairs the "Next:" line AND the Mark CTA — both reference `row.nextPerson != null`. Future 3rd-guard refactors MUST respect this pairing.
(d) `pickNextMember`'s 3 tie-break rules are independent — null beats contacted, oldest addedAtMillis wins when both null, smallest lastContacted wins when both contacted. The 3 Batch 2 tests cover cases (i) + (ii) via the widget; case (iii) deferred.
(e) `_GroupCard` line 201's `!paused` guard is the ONLY suppression of the Mark CTA — cadence label + Members count render unconditionally; Delete IconButton ALSO has no `!paused` guard (deleting a paused group is a valid escape hatch).

**Test count: 1850 → 1858 (+8 net — exactly matches plan).** Cumulative v1.7 progress: 1773 → 1858 (+85 net across 7 cycles). **3-gate green.** **Discipline anchor:** test count + 3-gate green + no manifest/pubspec/Drift/Kotlin changes. APK SHA1 NOT REPORTED (per ADR-093 (e) + the [v1-7-cyc-zeta-cycle-shipped.md](../../../.claude/projects/-home-shyam-common-games-doit/memory/v1-7-cyc-zeta-cycle-shipped.md) finding). SYS-163 / ADR-094 / WF-091.



### v1.7-θ — condition.dart boundaries + permission_lifecycle_observer.dart per-instance cold-start gate + triggerRefreshForTest hook independence

### v1.7-ι — v1.7 milestone CLOSEOUT — doc-only closeout cycle

### PR1 of 15 — UI consolidation sprint — PrimaryButton extraction + 3 high-traffic CTAs migration

**PR1 (Phase 76)** of the UI consolidation sprint (Month 1 / 2026-07-20..08-03). **First file in `lib/ui/`.** **+11 tests (EXACT match with plan).**

**Date:** 2026-07-07. **Tests:** 1866 → 1877 (+11 net). **Cumulative UI sprint:** 1877 (PR1 of 15 shipped, 14 remaining).

**What:**
- `lib/ui/primary_button.dart` — `StatelessWidget` wrapping `FilledButton`/`FilledButton.icon`. 48dp minimum inherited from `lib/theme/app_theme.dart:71-75` `filledButtonTheme`. Constructor: `const PrimaryButton({super.key, required onPressed, required label, icon, tooltip})`.
- 3 high-traffic CTAs migrated: `add_event.dart:217`, `add_person.dart:548`, `rest_day_picker_dialog.dart:110`.
- 11 widget tests in `test/ui/primary_button_test.dart` (6 groups).

**Why:** per UI_ORG_AUDIT.md C1 (6 button-style issues), the screen layer uses raw `FilledButton`/`FilledButton.icon`/`TextButton` in 39 places across 22 screens. Each occurrence repeats the same minimum-size/icon-or-not/onPressed/key/tooltip wiring. Deviations make the CTA layer brittle to a11y/theme/size token changes. PR1 establishes the primitive + migrates the 3 highest-traffic CTAs as the canonical-pattern call; PR2..PR15 will migrate the remaining 36 occurrences + add the other primitives (SecondaryButton, IconButton, FAB, EmptyStateView, ErrorStateView, LoadingView, FormField, SectionCard, ScreenScaffold, ReliabilityBadge).

**Constraint adherence:**
- No `AndroidManifest.xml` changes (pure Dart).
- No new pubspec deps (uses existing `package:flutter/material.dart` + `AppTheme.dark`).
- No Drift migration, no Kotlin changes.
- APK SHA1 discipline anchor: test count + 3-gate green + no manifest/pubspec/Drift/Kotlin changes (per v1.7-ζ / ADR-093 (e) + v1.7-ι / ADR-096 lesson (b)).
- 48dp touch target retained (inherited from `filledButtonTheme` — PrimaryButton does not re-specify).

**Drift lessons:** see ADR-097 — 5 lessons including the `AppTheme.dark` getter-not-Widget one + the const-MaterialApp-with-getter-theme limitation + the inherited 48dp sizing.

**3-gate:** `dart format --output=none --set-exit-if-changed .` (clean) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1877/1877 pass — zero regressions).

**Next:** PR2 of 15 (SecondaryButton — the cancel/dismiss CTA wrapping `TextButton`).

**Ninth and FINAL cycle of v1.7.** Doc-only. **0 tests.** **EXACT MATCH with v1.7 pre-auth plan target.** **The v1.7 milestone is now COMPLETE (9/9 cycles shipped).**

**Date:** 2026-07-07. **Tests:** 1866 → 1866 (0 net). **Cumulative v1.7:** 1773 → 1866 (+93 net across α+β+γ+δ+ε+ζ+η+θ+ι; 9/9 cycles shipped).

**Files:** 8 doc files only — no production-code change, no test change, no Drift migration, no Kotlin change.

**Cycle-by-cycle reconciliation:**
- v1.7-α: +13 actual vs +18 plan (Δ -5; absorbed by v1.7-β per ADR-087 §c)
- v1.7-β: +14 actual vs +14 plan (Δ ±0)
- v1.7-γ: +12 actual vs +12 plan (Δ ±0)
- v1.7-δ: +20 actual vs +20 plan (Δ ±0)
- v1.7-ε: +10 actual vs +10 plan (Δ ±0)
- v1.7-ζ: +8 actual vs +8 plan (Δ ±0)
- v1.7-η: +8 actual vs +8 plan (Δ ±0)
- v1.7-θ: +8 actual vs +8 plan (Δ ±0)
- v1.7-ι: 0 actual vs 0 plan (Δ ±0; doc-only closeout)

**Total: 1773 → 1866 (+93 net across 9 cycles; under plan by 3).** The -3 is entirely driven by v1.7-α's -5 (absorbed by v1.7-β per ADR-087 §c, *not* by ι itself).

**Drift lessons:** see ADR-096 — (a) canonical tests-only + 2-fixes + 1-doc-only closeout pattern confirmed + (b) APK SHA1 anchor replaced with test-count + 3-gate green + (c) v1.7-θ deviation (no PR) documented.

**Defers (out-of-scope, v1.7-ι):** 13 blocked items from v1.6-λ (carry forward to v2.0); Phase B TODOs (0 outstanding after audit); release tag (user decision); APK rebuild (belongs to the release cycle).

**Next:** per the 3-month launch roadmap at `~/.claude/plans/here-now-i-hvae-enumerated-reddy.md`, the next phase is the UI consolidation sprint (15 PRs, ~3 dev-weeks).

**Eighth cycle of v1.7.** Tests-only. **+8 tests** (6 condition + 2 permission). **EXACT MATCH with v1.7 pre-auth plan target.**

**Date:** 2026-07-07. **Tests:** 1858 → 1866 (+8 net). **Cumulative v1.7:** 1773 → 1866 (+93 across α+β+γ+δ+ε+ζ+η+θ; 8/9 cycles shipped).

**Files:** `test/triggers/condition_test.dart` (+6 tests) + `test/services/permission_lifecycle_observer_test.dart` (+2 tests). **No production-code change.**

**Batches (6 condition + 2 permission):**
- ConditionOr recursion (2): left invalid throws + right invalid throws.
- ConditionTimeWindow end-side (1): invalid endHour + negative startMinute + invalid endMinute.
- Equality + hashCode (2): ConditionAnd + ConditionTimeWindow.
- toString format (1): ConditionValidationException (3 subtypes).
- Per-instance cold-start gate (1): second observer starts with its own cold-start no-op.
- triggerRefreshForTest independence (1): runs without lifecycle event + does NOT consume gate.

**Coverage gain:** `condition.dart` 59.8% → 80.5% (+20.7 pp). `permission_lifecycle_observer.dart` stays at 78.6%. `mission_result.dart` stays at 100%.

**Drift lessons:** see ADR-095 — 5 lessons covering `ConditionDayOfWeek` non-const + cross-type non-const + `ConditionValidationException.toString()` format + `_coldStartSeen` per-instance + `triggerRefreshForTest` independence.

**3-gate:** `dart format` (clean) + `flutter analyze --fatal-infos` (0 issues) + `flutter test` (1866/1866 pass).
### PR2 of 15 — UI consolidation sprint — SecondaryButton extraction + 3 dialog Cancel migrations

**PR2 (Phase 77)** of the UI consolidation sprint (Month 1 / 2026-07-20..08-03). **Second file in `lib/ui/`.** **+11 tests (EXACT match with plan).**

**Date:** 2026-07-07. **Tests:** 1877 → 1888 (+11 net).

**What:**
- `lib/ui/secondary_button.dart` — `StatelessWidget` wrapping `TextButton`/`TextButton.icon`. 48dp minimum via inline `TextButton.styleFrom(minimumSize: const Size(0, 48))`. API mirrors `PrimaryButton`: `const SecondaryButton({super.key, required onPressed, required label, icon, tooltip})`.
- 3 dialog Cancel migrations: `add_event.dart:213`, `add_person.dart:544`, `rest_day_picker_dialog.dart:106`.
- 11 widget tests in `test/ui/secondary_button_test.dart` (6 groups).

**Why:** per UI_ORG_AUDIT.md C1 (6 button-style issues), the screen layer uses raw `TextButton` for Cancel CTAs in ~5 dialogs. Each occurrence repeats the same onPressed/key/tooltip wiring. PR2 establishes the Cancel/dismiss primitive that pairs with `PrimaryButton` from PR1.

**Constraint adherence:**
- No `AndroidManifest.xml` changes (pure Dart).
- No new pubspec deps (uses existing `package:flutter/material.dart` + `AppTheme.dark`).
- No Drift migration, no Kotlin changes.
- APK SHA1 discipline anchor: test count + 3-gate green + no manifest/pubspec/Drift/Kotlin changes (per v1.7-ζ / ADR-093 (e) + v1.7-ι / ADR-096 lesson (b)).
- 48dp touch target retained (via inline `TextButton.styleFrom`).

**Drift lessons:** see ADR-098 — 5 lessons including the `AppTheme.dark` getter-not-Widget (PR1 mirror) + the const-MaterialApp-with-getter-theme limitation (PR1 mirror) + **`TextButton` does NOT have a theme-level `minimumSize` default** (NEW — explicit inline style required) + the `onPressed: null` auto-disable (PR1 mirror) + the PR1 dart-format deviation lesson applied proactively.

**3-gate:** `dart format --output=none --set-exit-if-changed .` (clean — formatted upfront) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1888/1888 pass — zero regressions).

**Next:** PR3 of 15 (IconButton — the canonical icon-only CTA wrapping `Material.IconButton`).

### PR3 of 15 — UI consolidation sprint — AppIconButton extraction + 3 icon-only CTA migrations

**PR3 (Phase 78)** of the UI consolidation sprint (Month 1 / 2026-07-20..08-03). **Third file in `lib/ui/`.** **+11 tests (EXACT match with plan).**

**Date:** 2026-07-07. **Tests:** 1888 → 1899 (+11 net).

**What:**
- `lib/ui/icon_button.dart` — `StatelessWidget` wrapping `Material.IconButton`. 48dp minimum INHERITED from defaults (no inline style needed — unlike `TextButton` which needs explicit `ButtonStyle` per ADR-098 (c)). API: `const AppIconButton({super.key, required icon, required onPressed, tooltip})`.
- 3 icon-only CTA migrations: `person_groups.dart:62` (Refresh in AppBar) + `recently_deleted_screen.dart:232` (Restore per-row action) + `recently_deleted_screen.dart:238` (Delete Forever per-row action).
- 11 widget tests in `test/ui/icon_button_test.dart` (5 groups).

**Why:** per UI_ORG_AUDIT.md C8 (icon set) + C9 (touch targets / a11y), the screen layer uses raw `IconButton` in 26 places across 8 screens. Each occurrence repeats the same key/tooltip/icon/onPressed wiring. PR3 establishes the icon-only CTA primitive that pairs with `PrimaryButton` (PR1) + `SecondaryButton` (PR2) and migrates the 3 highest-traffic icon-only CTAs as the canonical-pattern call.

**Constraint adherence:**
- No `AndroidManifest.xml` changes (pure Dart).
- No new pubspec deps (uses existing `package:flutter/material.dart` + `AppTheme.dark`).
- No Drift migration, no Kotlin changes.
- APK SHA1 discipline anchor: test count + 3-gate green + no manifest/pubspec/Drift/Kotlin changes (per v1.7-ζ / ADR-093 (e) + v1.7-ι / ADR-096 lesson (b)).
- 48dp touch target retained (inherited from `IconButton` defaults).

**Drift lessons:** see ADR-099 — 5 lessons including the `AppTheme.dark` getter-not-Widget (PR1 + PR2 mirror) + the const-MaterialApp-with-getter-theme limitation (PR1 + PR2 mirror) + **`IconButton` INHERITS 48dp from defaults** (NEW — UNLIKE `TextButton`) + `IconButton.tooltip` is a `Tooltip` widget not a `Semantics` label (NEW pattern) + `IconButton.filled` is a separate constructor (NEW test pattern).

**3-gate:** `dart format --output=none --set-exit-if-changed .` (clean — formatted upfront) + `flutter analyze --fatal-infos lib test` (0 issues) + `flutter test` (1899/1899 pass — zero regressions).

### PR4 of 15

PR4 (color palette misuse consolidation, C2 category) extracted `AppPalette` (`lib/ui/app_palette.dart`, ~108 lines) as the canonical semantic-color helper primitive. The class exposes 3 `static` helpers (`iconMuted`, `mutedTileBackground`, `mutedPillDecoration`) backed by 5 canonical `static const` constants (`_tileAlpha=0.20`, `_pillFillAlpha=0.15`, `_pillBorderAlpha=0.5`, `_pillBorderWidth=0.5`, `_pillRadius=8`). 3 color-palette-misuse sites migrated to the canonical pattern: `widget_config_screen.dart:156` `Colors.grey` → `AppPalette.iconMuted(context)`; `home.dart:_TileIcon:1270` `color.withValues(alpha: 0.20)` → `AppPalette.mutedTileBackground(context, color)`; `do_anchor_paused_badge.dart:68-75` inline `BoxDecoration` → `AppPalette.mutedPillDecoration(context, color)` (6 lines collapse to 1). All 3 migrations preserve visuals byte-for-byte. 11 new tests in `test/ui/app_palette_test.dart` (4 groups). Test count: 1899 → 1910 (+11 net; EXACT match with plan). 3-gate green. V-Model artifacts: SYS-170 + ADR-101 + WF-098 + 5 doc rows. APK discipline anchor: test count + 3-gate green + no manifest/pubspec/Drift/Kotlin changes.

**Next:** PR5 of 15 (C3 cards — card / surface pattern consolidation: 5 issues → 2 PRs).

**Next:** PR5 of 15 (C3 cards — card / surface pattern consolidation: 5 issues → 2 PRs).

PR5 (card / surface pattern consolidation, C3 category — first of two PRs) extracted 3 primitives (`SurfaceCard` + `TileSurface` + `BannerSurface`; ~250 LOC total in `lib/ui/`; FIFTH/SEVENTH files in the new `lib/ui/` design-system layer). `SurfaceCard` is the canonical elevated `Card + Padding(Spacing.md)` body for non-tile list/grid items, with optional `onTap` (wraps in `Card + InkWell`), optional `semanticLabel` (wraps in `Semantics(label: ..., container: true)`), and an optional `padding` override (default `EdgeInsets.all(Spacing.md)`, override `EdgeInsets.zero` for `ListTile`-based children that manage their own padding). Reads `cardTheme.elevation` from the active theme. `TileSurface` is the per-tile accent-color tint for the home habit tile — wraps `Material(color: accent.withValues(alpha: <canonical>)) + InkWell + Padding(Spacing.md)` with private canonical constants `_TileAlphas.selected = 0.30` + `_TileAlphas.unselected = 0.12` (matches the home tile's pre-PR5 inline literals exactly). Canonical geometry: 12dp border-radius + Spacing.md padding. Wraps in InkWell only when `onTap` or `onLongPress` is non-null. `BannerSurface` is the full-width banner primitive with `tone: BannerTone` enum (error → errorContainer / onErrorContainer, info → tertiaryContainer / onTertiaryContainer, primary → primaryContainer / onPrimaryContainer, neutral → secondaryContainer / onSecondaryContainer) + optional `icon` + optional `onTap` (wraps in InkWell) + optional `semanticLabel` (wraps in Semantics). Defaults to plain `Material(color: bg)` when onTap is null. 7 site migrations preserve visuals byte-for-byte: 3 SurfaceCard (person_groups._GroupCard + events._EventTile + recently_deleted_screen._RecentlyDeletedRow), 1 TileSurface (home.dart _HabitTileState — the 164-line habit tile), 3 BannerSurface (reliability_banner.ReliabilityBanner + streak_recovery_card.StreakRecoveryCard + routine_banner.RoutineBanner). The RoutineBanner migration ALSO adds a Semantics wrapper that was previously missing — a free a11y win. 2 unused `app_theme.dart` imports removed (reliability_banner + routine_banner) as post-migration cleanup. 38 new tests across 3 new test files (surface_card_test 12 + tile_surface_test 13 + banner_surface_test 13). Test count: 1910 → 1948 (+38 net; +5 over the +33 plan target — explained by the 3-primitive split in PR5). 3-gate green. V-Model artifacts: SYS-171 + ADR-102 + WF-099 + 5 doc rows.

**Next:** PR6 of 15 (C3 cards part 2 — `SectionHeader` primitive + C6 nav — `appBarTheme.scrolledUnderElevation: 1`).

**Next:** PR6 of 15 (C3 cards part 2 — `SectionHeader` primitive + C6 nav — `appBarTheme.scrolledUnderElevation: 1`).
| v1.8-06 / PR6 of 15 (2026-07-07) | SHIPPED | C3 cards part 2 — `SectionHeader` primitive + C6 nav — `appBarTheme.scrolledUnderElevation: 1`. 7 files touched (5 screens + 1 theme + 1 settings.dart dropped the `_SectionHeader` private widget). Test count 1948 → 1974 (+26 net). 3-gate green. APK discipline anchor maintained. SYS-172 / ADR-103 / WF-100. |
| v1.8-07 / PR7 of 15 (2026-07-07) | SHIPPED | C4 form patterns batch 1 — `AppFormField` + `AppChoiceChip` primitives. 1974 → 2000 (+26 net). 3-gate green. APK discipline anchor maintained. SYS-173 / ADR-104 / WF-101. |
| v1.8-08 / PR8 of 15 (2026-07-07) | SHIPPED | C4 form patterns batch 2 — `AppSnack` snackbar wrapper primitive. 2000 → 2010 (+10 net). 3-gate green. APK discipline anchor maintained. SYS-174 / ADR-105 / WF-102. |
| v1.8-09 / PR9 of 15 (2026-07-07) | SHIPPED | C5 empty/loading states batch 1 — `EmptyState` + `LoadingView` primitives. 2010 → 2031 (+21 net). Net -68 LOC across 5 screens. 3-gate green. APK discipline anchor maintained. SYS-184 / ADR-115 / WF-111. |
| v1.8-10 / PR10 of 15 (2026-07-07) | SHIPPED | C5 empty/loading/error states batch 2 — `ErrorView` primitive (message + onRetry + optional retryLabel). 2031 → 2042 (+11 net; matches +11 plan target exactly). Net -72 LOC across 3 screens. 3-gate green. APK discipline anchor maintained. SYS-185 / ADR-116 / WF-112. |
| v1.8-11 / PR11 of 15 (2026-07-07) | SHIPPED | C5 mission error UX — `MissionFailedView` AlertDialog primitive + C9-1 a11y fix on math/type problem cards. 2042 → 2052 (+10 net; -1 vs +11 plan target). 3-gate green. APK discipline anchor maintained. SYS-186 / ADR-117 / WF-113. |
| v1.8-13 / PR13 of 15 (2026-07-08) | SHIPPED | C7 typography — `AppTextStyles` static-helper class (5 named categories) + `DoItTypography` ThemeExtension (5 `DoItTypographyBucket` immutable values; defaults: display 0/1.1, headline 0.15/1.2, title 0.15/1.25, body 0.25/1.4, label 0.5/1.2) registered on both `AppTheme.dark` and `AppTheme.light`. Each helper is nullable-tolerant — falls back to the base M3 `TextTheme` style with no letterSpacing/height overlay if the extension is absent. 5 migration sites across 4 files (6 call sites: section_header default + compact; do_anchor_paused_badge; home.dart streak number + rest-day caption; stats.dart streak number). 4 existing `section_header_test.dart` tests updated to pin the post-migration `AppTextStyles.sectionHeaderTitle(context)` / `sectionHeaderTitleCompact(context)` as the expected rendered style. 2052 → 2063 (+11 net; matches +11 plan target exactly). 3-gate green. APK discipline anchor maintained. SYS-187 / ADR-118 / WF-114. |
| v1.8-14 / PR14 of 15 (2026-07-08) | SHIPPED | C8 icon-set + C9 a11y batch — `AppIconButton` extended with `iconSize:` (forwards to `IconButton.iconSize`; null = M3 24dp default) and `busy:` (boolean; when true, swaps the icon for a 20×20 `CircularProgressIndicator(strokeWidth: 2)` and disables the button — canonical in-flight pattern). 28 migration sites across 11 files. 4 home AppBar a11y fixes (Cancel / Mark selected done / Stats / Settings gain localized `tooltip:` via 4 new ARB keys) + 2 bonus a11y fixes (dst_transition_banner + streak_recovery_card dismiss buttons gain `tooltip: 'Dismiss'`). 4 new ARB keys: `homeAppBarStatsTooltip` / `homeAppBarSettingsTooltip` / `homeAppBarCancelTooltip` / `homeAppBarCompleteSelectedTooltip` in en + es. Test count 2063 → 2073 (+10 net; -1 vs +11 plan target). 3-gate green. APK discipline anchor maintained. SYS-188 / ADR-119 / WF-115. |
| v1.8-15 / PR15 of 15 (2026-07-08) | SHIPPED | C10 FAB — `AddFab` primitive (wraps `Material.FloatingActionButton` with default `Icons.add` child + default `tooltip: 'Add'`; required `onPressed`; optional `tooltip`). 3 migration sites (home `_AddFab.build` + events add + person_groups add) + 2 async refresh-action patterns (events + person_groups). 18th `lib/ui/` file. Test count 2073 → 2084 (+11 net; matches +11 plan target exactly). 3-gate green. APK discipline anchor maintained. SYS-189 / ADR-120 / WF-116. **v1.8 UI consolidation sprint (15 PRs) — PR1..PR15 of 15 all SHIPPED.** |
