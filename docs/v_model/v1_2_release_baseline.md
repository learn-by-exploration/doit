# v1.2 release baseline

> **Scope.** This document is the left-side baseline of the V-Model
> for the v1.2 milestone. It is the contract the implementation
> rows in `implementation_status.md` (v1.2a..v1.2m) and the
> requirements rows in `requirements.md` (SYS-098..SYS-110)
> satisfy. The right-side gate is
> [`v1_2_release_checklist.md`](v1_2_release_checklist.md); that
> doc is where the on-device verification steps live.

## 1. Headline theme

**Code-TODO closure.** Thirteen v1.2 sub-entries (v1.2a..v1.2m)
landed across the v1.2 cycle to close the 30-phase roadmap's
code-TODO pass over the v1.1 foundation. The four headline
themes:

- **Wire-up.** The `NotificationService.show` / `dismiss`
  path (v1.2e), the routine `Action` leaves
  (`ActionFullscreen`, `ActionCallIntercept`, v1.2f), and the
  `BOOT_COMPLETED` coverage confirmation (v1.2g).
- **UX completeness.** `Person.pauseUntil` UI (v1.2f),
  `DoFixed` weekday display (v1.2f), `DstTransitionBanner`
  (v1.2j), `StreakRecoveryCard` (v1.2j), and the
  pre-notification 5-min / 1-min heads-up (v1.2j).
- **Reliability disambiguation.** Per-automation
  `AlertDialog` on tap (v1.2h) and the
  `AppLifecycleState.resumed` re-probe hook (v1.2i).
- **Edit affordances.** Hard delete with confirm (v1.2k),
  `CompletionLogSection` for review + undo (v1.2m), and the
  uniform 3-wrong take-a-break across Math + Type (v1.2l).

## 2. The 30-phase roadmap (status)

The 30-phase roadmap is scattered across the `CHANGELOG.md`
v1.2 sub-entries and the `feature.md` §3.1 / §3.2 follow-ups;
a single `v1_2_30_phase_roadmap.md` doc is a v1.2+ follow-up
(see `feature.md` §3.2). The phase status at v1.2 sign-off:

| Phase | Topic | Status | v1.2 sub-entry |
|---|---|---|---|
| 1 | trigger-set baseline | shipped | v1.2a (doc-only) |
| 2 | condition-predicate baseline | shipped | v1.2b (doc-only) |
| 3 | `TriggerForegroundApp` + `PermissionKind.callScreening` | shipped | v1.2c |
| 4 | `PauseService._ready` eager-complete + `PositionSource.dispose` contract | shipped | v1.2d |
| 5 | alarm fire → notification render path wire-up | shipped | v1.2e |
| 6a | `USE_FULL_SCREEN_INTENT` permission + reliability policy | deferred (v1.x) | — (see `feature.md` §2.1) |
| 6b | `ActionFullscreen` + `ActionCallIntercept` leaves | shipped | v1.2f |
| 6c | `Person.pauseUntil` UI | shipped | v1.2f |
| 6d | `DoFixed` weekday display | shipped | v1.2f |
| 6e | exhaustive `_dispatchAction` switch grows 2 arms | shipped | v1.2f |
| 7 | BOOT_COMPLETED coverage confirmation | shipped | v1.2g |
| 8 | per-automation `AutomationReliabilityDialog` on tap | shipped | v1.2h (trigger-side only) |
| 9 | `AppLifecycleState.resumed` re-probe hook | shipped | v1.2i |
| 10 | DST banner + streak-recovery card + pre-notification heads-up | shipped | v1.2j |
| 11a | hard-delete affordance on edit screen | shipped | v1.2k |
| 11b | shared `MissionWrongAttempts` module | shipped | v1.2l |
| 11c | `CompletionLogSection` for review + undo | shipped | v1.2m |
| 12-30 | home widget, iOS port, Wear OS, backup encryption upgrade, backup format v2 → v3, Argon2id backup, etc. | v1.x parking lot | — (see `feature.md` §4) |

## 3. Requirements (SYS- IDs)

v1.2 added 13 requirements rows to `requirements.md` (the
`requirements.md` mapping is the source of truth — every
other doc in this folder is required to match):

- **SYS-098** (v1.2e / Phase 5) — alarm fire → notification
  render path wire-up.
- **SYS-099** (v1.2f / Phase 6b) — `ActionFullscreen` leaf
  wired through `ReminderService.fullScreen.showRoutineOverlay()`.
- **SYS-100** (v1.2f / Phase 6c) — `ActionCallIntercept`
  leaf wired through
  `CallInterceptorService.recordRoutineDecision(decision)`.
- **SYS-101** (v1.2f / Phase 6d) — `Person.pausedUntil` UI
  on the Add Person screen + `ContactPerson.copyWith` round-trip.
- **SYS-102** (v1.2f / Phase 6e) — `DoFixed` weekday display
  via the new pure `describeDo(Do h)` helper.
- **SYS-103** (v1.2h / Phase 8) — per-automation
  `AutomationReliabilityDialog` on tap.
- **SYS-104** (v1.2i / Phase 9) — `PermissionService.refresh()`
  + `WidgetsBindingObserver` re-probe hook.
- **SYS-105** (v1.2j / Phase 10) — `DstTransitionBanner` on
  the home screen (24-hour-ahead DST warning).
- **SYS-106** (v1.2j / Phase 10) — `StreakRecoveryCard` on
  the home screen (back-fillable missed day, 3+ missed days).
- **SYS-107** (v1.2j / Phase 10) — pre-notification 5-min /
  1-min heads-up channel.
- **SYS-108** (v1.2k / Phase 11a) — hard-delete affordance
  on edit screen with confirm dialog.
- **SYS-109** (v1.2l / Phase 11b) — shared
  `MissionWrongAttempts` module (uniform 3-wrong take-a-break
  across Math + Type).
- **SYS-110** (v1.2m / Phase 11c) — `CompletionLogSection`
  for review + undo.

## 4. Decisions (ADRs)

v1.2 added 9 ADRs to `decision_record.md` (033..041):

- **ADR-033** — wire `AlarmScheduler` through
  `NotificationService.show` / `dismiss`.
- **ADR-034** — extend `Action` sealed hierarchy with
  `ActionFullscreen` + `ActionCallIntercept`.
- **ADR-035** — `AutomationReliabilityDialog` on tap
  (per-automation reliability details, trigger-side only).
- **ADR-036** — `PermissionLifecycleReProbe` +
  `PermissionService.refresh()` for
  `AppLifecycleState.resumed`.
- **ADR-037** — `DstTransitionBanner` on home screen
  (24-hour-ahead DST warning).
- **ADR-038** — `StreakRecoveryCard` on home screen
  (back-fillable missed day).
- **ADR-039** — `PreNotificationHeadsUp` (5-min / 1-min
  heads-up channel).
- **ADR-040** — shared `MissionWrongAttempts` module
  (uniform 3-wrong take-a-break across Math + Type).
- **ADR-041** — `CompletionLogSection` for review + undo
  (last-7-days, best-effort routine reversal).

## 5. Out-of-scope (deferred to v1.x)

These items are explicitly **not** in v1.2 scope but are
v1.x candidates (still v1 track, not v2.0 jump):

- Strong-mode full-screen launch hardening (Phase 6a —
  `USE_FULL_SCREEN_INTENT` on API 34+). See `feature.md`
  §2.1.
- Action-side permission disambiguation in the
  `AutomationReliabilityDialog`. See `feature.md` §2.2.
- `TriggerCallIncoming*` reliability arm once
  `PermissionService.callScreening` is fully probed. See
  `feature.md` §2.3.
- Spanish translation by a native speaker (the v1.1h
  smoke-test locale is the only translation). See
  `feature.md` §2.4.
- `google_maps_flutter` for `LocationMapPreview` (would
  add `INTERNET`). See `feature.md` §2.5.
- Legacy `mipmap-*/ic_launcher.png` regeneration from the
  master vector. See `feature.md` §2.6.
- Light-theme icon variant. See `feature.md` §2.7.
  **Shipped in PR #30** (v1.3d — `Settings._PermissionsRow`
  branches the FSI tile icon on `Theme.of(context).brightness`
  so light mode renders `Icons.open_in_full_outlined` and
  dark mode keeps the filled `Icons.open_in_full`; 2 widget
  tests pin both branches).
- B9 — Android home-widget re-arm indicator (the project
  does not yet ship a home widget). See `feature.md` §2.8.
- Phases 12-30 of the 30-phase roadmap (home widget, iOS
  port, Wear OS, backup encryption upgrade, backup format
  v2 → v3, Argon2id backup). See `feature.md` §4.

## 6. No new permissions, no `INTERNET`

The v1.2 cycle did not add any new `AndroidManifest.xml`
permission entries. The pre-existing permission set
(`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`,
`USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`,
`FOREGROUND_SERVICE`, `VIBRATE`, `WAKE_LOCK`,
`PACKAGE_USAGE_STATS`, `READ_CONTACTS`) is unchanged. The
v1.2 cycle also did not add `INTERNET`; the
`LocationMapPreview` remains a pure `CustomPaint` widget.

The only "special-access" permission do it ships is
`PACKAGE_USAGE_STATS` (v1.1g). The closest call in v1.2
was the `USE_FULL_SCREEN_INTENT` permission on API 34+,
which is explicitly deferred (Phase 6a).

## 7. Test surface

- v1.2 starts at the v1.1i / v1.1j end state: 893 / 893
  tests passing.
- v1.2 adds 108 new tests across the 13 sub-entries
  (v1.2a..v1.2m) for a final v1.2 end state of 1001 / 1001
  tests passing.
- v1.2 has no `skip:` markers; the CI rejects skipped tests
  (see `.claude/rules/test.md`).
- v1.2's test coverage on changed files is ≥ 80% per
  `.claude/rules/test.md`'s coverage policy.

## 8. Version bump

- `pubspec.yaml` — `version: 1.1.0+8` → `version: 1.2.0+9`.
- `lib/build_info.dart` — `kAppVersion = '1.1.0'` →
  `kAppVersion = '1.2.0'`; `kAppVersionCode = 8` → `9`.
- `test/release_signing_test.dart` mirror-pin assertions
  updated in lockstep.

The version code increments by one (no skipped codes),
mirroring the v1.0 → v1.0.0+7 and v1.1.0+8 → v1.2.0+9 bumps
(the v1.1 line is what we increment from).
