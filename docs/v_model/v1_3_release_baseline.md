# v1.3 release baseline

> **Scope.** This document is the left-side baseline of the V-Model
> for the v1.3 milestone. It is the contract the implementation
> rows in `implementation_status.md` (v1.3a..v1.3d) and the
> requirements rows in `requirements.md` (SYS-112..SYS-114) satisfy.
> The right-side gate is
> [`v1_3_release_checklist.md`](v1_3_release_checklist.md); that doc
> is where the on-device verification steps live.

## 1. Headline theme

**Reliability + lifecycle hardening.** Four v1.3 sub-entries
(v1.3a..v1.3d) landed across the v1.3 cycle to harden the unified
`Reliability` signal and close the strong-mode interruption
contract end-to-end on Android 14+. The three headline themes:

- **Reliability unification** (v1.3b) — a single
  `ReliabilityService.instance` is the unified source-of-truth
  for the app-wide `Reliability` enum; the home-screen banner
  and the settings reliability row both bind to it; the
  `_kReliabilityGatedKinds` set is the policy gate.
- **Special-access gating** (v1.3c) — the Android 14+
  `USE_FULL_SCREEN_INTENT` special-access permission joins the
  gated set; the Settings → Permissions screen gains a 5th
  `_PermissionTile`; the home banner's `onTap` deep-links the
  user to the tile.
- **Strong-mode interruption end-to-end** (v1.3d) — the
  `FullScreenActivity` Kotlin class lands; the launch handlers
  on `doit/full_screen` (`showHabitMission`, `showRoutineOverlay`)
  fire the activity; the strong-mode notification uses
  `setFullScreenIntent(openPi, true)` so the OS launches the
  activity directly on a locked device; the chain-level
  orchestrator (`MissionLauncherScreen`) walks the `MissionChain`
  end-to-end and appends the completion on `ChainPassed`. This
  closes `feature.md` §2.1 "Still deferred" — Phase 6a proper.

The stats-side groundwork (v1.3a — monthly stats + per-do
grace factory) is the prerequisite for the reliability work:
the 30-day completion-rate + 7-day bar chart are the user-
visible signal that the gated reliability affects outcomes.

## 2. The 30-phase roadmap (status)

The 30-phase roadmap is scattered across the `CHANGELOG.md`
v1.3 sub-entries. The phase status at v1.3 sign-off:

| Phase | Topic | Status | v1.3 sub-entry |
|---|---|---|---|
| 12 | Monthly stats + per-do grace factory | shipped | v1.3a |
| 13 | Unified `ReliabilityService` source-of-truth | shipped | v1.3b |
| 14 | `USE_FULL_SCREEN_INTENT` probe + reliability wiring | shipped | v1.3c |
| 15 | `FullScreenActivity` launch path (Phase 6a proper) | shipped | v1.3d |
| 6a | `USE_FULL_SCREEN_INTENT` permission + reliability policy | shipped | v1.3c + v1.3d (combined) |
| 16-30 | v1.x candidates (home widget, iOS port, Wear OS, backup encryption upgrade, backup format v2 → v3, Argon2id backup, etc.) | v1.x parking lot | — (see `feature.md` §4) |

The Phase 6a "still deferred" item from the v1.2 sign-off is
closed by the combination of v1.3c (probe + reliability
wiring) + v1.3d (activity launch path). The remaining
deferred items are tracked in `feature.md` §2.2..§2.8 and
§4 — none of them block the v1.3 release.

## 3. Requirements (SYS- IDs)

v1.3 added 3 requirements rows to `requirements.md` (the
`requirements.md` mapping is the source of truth — every
other doc in this folder is required to match):

- **SYS-112** (v1.3b / Phase 13) — `ReliabilityService.instance`
  is the unified `Stream<Reliability>` source-of-truth; the
  home-screen `ReliabilityBanner` and the settings page
  `_ReliabilityRow` both bind to `ReliabilityService.instance.notifier`;
  the `PlatformAlarmScheduler.reliability` getter is a thin
  pass-through. The combine rule: bridge probe `degraded` →
  `degraded`; any gated kind `Denied` / `PermanentlyDenied` →
  `degraded`; else `optimal`. Initial value `optimal` (NOT
  `unknown`) — closes the v1.3a first-read race.
- **SYS-113** (v1.3c / Phase 14) — `PermissionKind.fullScreenIntent`
  is a new enum entry on `lib/services/permission_service.dart`
  (opt-in, ADR-030 precedent); the manifest declares
  `<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"
  tools:ignore="ProtectedPermissions" />`; a new
  `FullScreenIntentService` singleton mirrors `UsageStatsService`
  over the `doit/full_screen` MethodChannel; the Kotlin side
  resolves the API 32 / 33 / 34 asymmetry on the platform side;
  `fullScreenIntent` joins `_kReliabilityGatedKinds` (now 5
  elements: `location`, `calendar`, `callScreening`,
  `usageStats`, `fullScreenIntent`); the Settings → Permissions
  screen gains a 5th `_PermissionTile`; the home-screen
  `ReliabilityBanner` gains an `onTap` callback.
- **SYS-114** (v1.3d / Phase 15) — the v1.3c-deferred activity
  launch path is wired end-to-end. A real `FullScreenActivity`
  Kotlin class sets the lockscreen-bypass window flags in
  `onCreate` (`FLAG_SHOW_WHEN_LOCKED | FLAG_TURN_SCREEN_ON |
  FLAG_DISMISS_KEYGUARD | FLAG_KEEP_SCREEN_ON`) and encodes
  intent extras into the initial route query string via
  `getInitialRoute()`; `FullScreenIntentChannel.kt` grows two
  new `when` arms (`showHabitMission`, `showRoutineOverlay`);
  `MainActivity.buildReminderNotification` splits the strong-
  mode branch with `setFullScreenIntent(openPi, true)`; a
  new `lib/screens/mission_launcher.dart` chain-level
  orchestrator widget loads the habit by id via
  `DoRepository.instance.getById`, iterates the `MissionChain`,
  runs `MissionChainExecutor.run`, and appends the completion
  on `ChainPassed`; a new `lib/screens/routine_overlay_screen.dart`
  banner widget renders the routine-fired overlay; the
  `MaterialApp.onGenerateRoute` in `lib/main.dart` maps
  `/mission` to the right screen; `Future<LaunchIntent?> getLaunchIntent()`
  + `_safeResult<T>` defense-in-depth wrapper added to
  `PlatformFullScreenIntent`.

## 4. Decisions (ADRs)

v1.3 added 3 ADRs to `decision_record.md` (042..044):

- **ADR-042** — `ReliabilityService` unified `Stream<Reliability>`
  source-of-truth (the 4 → 5 gated kinds and the
  `ReliabilityBanner.fromStream` factory).
- **ADR-043** — `FullScreenIntentChannel` probe + reliability
  wiring for `USE_FULL_SCREEN_INTENT` on Android 14+ (the
  API 32 / 33 / 34 asymmetry; the opt-in UX pattern; the
  `tools:ignore="ProtectedPermissions"` marker).
- **ADR-044** — `FullScreenActivity` launch path: separate
  activity (NOT a new `launchMode` on `MainActivity`);
  channel reuse (extend `doit/full_screen`, NOT a new
  MethodChannel); `setFullScreenIntent(openPi, true)` on the
  strong-mode notification; chain-level orchestrator widget
  lives in `lib/screens/` (NOT `lib/missions/`); no
  `wakelock_plus` package (activity-level `FLAG_KEEP_SCREEN_ON`
  is sufficient); no new `<uses-permission>` (v1.3c baseline
  covers the launch path); `_safe` wrapper defense-in-depth
  preserved (ADR-013).

## 5. Out-of-scope (deferred to v1.x)

These items are explicitly **not** in v1.3 scope but are
v1.x candidates (still v1 track, not v2.0 jump):

- Action-side permission disambiguation in the
  `AutomationReliabilityDialog` (today the dialog covers
  trigger-side only). See `feature.md` §2.2.
- `TriggerCallIncoming*` reliability arm once
  `PermissionService.callScreening` is fully probed. See
  `feature.md` §2.3.
- Native-Spanish-speaker translation of
  `lib/l10n/app_es.arb` (v1.1h's smoke-test locale is the
  only translation). See `feature.md` §2.4.
- `google_maps_flutter` for `LocationMapPreview` (would
  add `INTERNET`). See `feature.md` §2.5.
- Legacy `mipmap-*/ic_launcher.png` regeneration from the
  master vector. See `feature.md` §2.6.
- Light-theme icon variant. See `feature.md` §2.7.
- B9 — Android home-widget re-arm indicator (the project
  does not yet ship a home widget). See `feature.md` §2.8.
- Phases 16-30 of the 30-phase roadmap (home widget, iOS
  port, Wear OS, backup encryption upgrade, backup format
  v2 → v3, Argon2id backup, v1.3 retrospective, etc.).
  See `feature.md` §4.
- Kotlin-side unit tests for `FullScreenIntentChannel.showHabitMission`
  / `showRoutineOverlay` + the new `FullScreenActivity` (the
  Dart-side tests cover the channel-call contract; the
  `compileDebugKotlin` gate catches syntax / null-safety /
  deprecation issues). A v1.4+ follow-up can add
  Robolectric / `androidx.test.core` tests.
- `wakelock_plus` swap (the v1.4+ follow-up may swap the
  activity-level `FLAG_KEEP_SCREEN_ON` for per-mission wake-lock
  control if the team wants finer-grained control).
- Per-mission retry UX (a `ChainFailedAt` currently pops with
  `null`; v1.1f grace-window semantics handle the wrong-attempt
  case for Math / Type; Shake / Hold / Memory do not retry).

## 6. One new permission, no `INTERNET`

The v1.3 cycle added one `AndroidManifest.xml` permission
entry:

- `<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"
  tools:ignore="ProtectedPermissions" />` (v1.3c) — the
  Android 14+ full-screen-intent special-access permission.
  The `tools:ignore` marker mirrors the v1.1g
  `PACKAGE_USAGE_STATS` precedent (ADR-030). The permission is
  **opt-in** — declining does NOT block any feature (the user
  keeps getting the notification fallback). v1.3d's launch
  path depends on this permission being granted on API 34+.

The v1.3 cycle did **not** add `INTERNET`; the
`LocationMapPreview` remains a pure `CustomPaint` widget, and
no new network call paths were added. The
`ci grep rejects any import 'package:http'` rule is unchanged.

## 7. Test surface

- v1.3 starts at the v1.2 sign-off end state: 1001 / 1001
  tests passing.
- v1.3 adds 63 new tests across the 4 sub-entries
  (v1.3a..v1.3d) for a final v1.3 end state of 1064 / 1064
  tests passing.
- v1.3 has no `skip:` markers; the CI rejects skipped tests
  (see `.claude/rules/test.md`).
- v1.3's test coverage on changed files is ≥ 80% per
  `.claude/rules/test.md`'s coverage policy.

## 8. Version bump

- `pubspec.yaml` — `version: 1.2.0+9` → `version: 1.3.0+10`.
- `lib/build_info.dart` — `kAppVersion = '1.2.0'` →
  `kAppVersion = '1.3.0'`; `kAppVersionCode = 9` → `10`.
- `test/release_signing_test.dart` mirror-pin assertions
  updated in lockstep.

The version code increments by one (no skipped codes),
mirroring the v1.0 → v1.0.0+7 and v1.1.0+8 → v1.2.0+9 → v1.3.0+10
bumps.

## 9. Migration shape

The v1.3 cycle has **no DB migrations**. The
`MissionChainExecutor.run` signature is unchanged (pure
function); the `ReliabilityService` is a new singleton that
sits next to the existing `PlatformAlarmScheduler.reliability`
getter (now a thin pass-through); the new
`FullScreenActivity` is a separate Android `Activity` (NOT a
new `launchMode` on `MainActivity`) and therefore does not
affect the existing channel registration in
`MainActivity.configureFlutterEngine`. The release-shape rule
"a migration is its own PR" is honored — v1.3 has no migrations.