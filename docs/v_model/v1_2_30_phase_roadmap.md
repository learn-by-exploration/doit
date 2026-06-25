# 30-phase roadmap (source of truth)

> **Purpose.** This document is the single source-of-truth for
> the 30-phase roadmap that drives `do it`'s milestone scoping
> from v0.1 → v1.x. It replaces the scattered references in
> every CHANGELOG sub-entry and every `feature.md` §3.1 / §3.2
> follow-up. Every other V-Model doc references back to this
> file via `docs/v_model/v1_2_30_phase_roadmap.md`.

The 30 phases span v0.5 (Phases 1-2), v1.2 (Phases 3-11c), v1.3
(Phases 12-15 — the reliability + lifecycle hardening milestone
that shipped at v1.3.0+10), and v1.x (Phases 16-30 — the parking
lot from `feature.md` §4). The roadmap was assembled in three
slices (the v1.2 baseline `v1_2_release_baseline.md` §2 table,
the v1.3 baseline `v1_3_release_baseline.md` §2 table, and the
v1.x parking-lot bullets in `feature.md` §4); this doc merges
the three into one authoritative table.

## Master table (all 30 phases)

| Phase | Topic | Status | Sub-entry / PR | SYS- / ADR- |
|---|---|---|---|---|
| 1 | trigger-set baseline (`Set<Trigger>` value class + set-of-set union / intersection helpers) | shipped | v1.2a (doc-only stub, `lib/routines/trigger_set.dart`) | (consumed by Phase 6b) |
| 2 | condition-predicate baseline (`_PredicateCondition` leaf that defers the predicate to the widget layer) | shipped | v1.2b (doc-only stub, `lib/routines/condition_predicate.dart`) | (consumed by Phase 6b) |
| 3 | `TriggerForegroundApp` leaf + `PermissionKind.callScreening` enum value | shipped | v1.2c (`e60597c`) | SYS-099 (folded in v1.2c) |
| 4 | `PauseService._ready` eager-complete + `PositionSource.dispose` contract | shipped | v1.2d (`2a0a5a7`) | (covered by `test/services/pause_service_test.dart`) |
| 5 | alarm fire → notification render path wire-up (`NotificationService.show` / `dismiss`) | shipped | v1.2e (`33b08f3`) | SYS-098 / ADR-033 |
| 6a | `USE_FULL_SCREEN_INTENT` permission + full-screen-intent reliability policy | shipped (split into 6a.i + 6a.ii) | v1.3c (probe / wiring, `81962a1`) + v1.3d (launch path, `5eca37b`) | SYS-113 / ADR-043 + SYS-114 / ADR-044 |
| 6a.i | `PermissionKind.fullScreenIntent` enum + `FullScreenIntentChannel` probe + reliability wiring + manifest entry | shipped | v1.3c (`81962a1`) | SYS-113 / ADR-043 |
| 6a.ii | `FullScreenActivity` Kotlin class + launch handlers on `doit/full_screen` + chain-level orchestrator widget | shipped | v1.3d (`5eca37b`) | SYS-114 / ADR-044 |
| 6b | `ActionFullscreen` + `ActionCallIntercept` leaves in `RoutineExecutor._dispatchAction` | shipped | v1.2f (`b4089b4`) | SYS-099 + SYS-100 / ADR-034 |
| 6c | `Person.pauseUntil` field + drift v5_to_v6 + AddPersonScreen Pause section | shipped | v1.2f (`b4089b4`) | SYS-101 |
| 6d | `DoFixed` weekday display via `lib/do/do_description.dart`'s `describeDo(Do h)` | shipped | v1.2f (`b4089b4`) | SYS-102 |
| 6e | exhaustive `_dispatchAction` switch grows `ActionFullscreen` + `ActionCallIntercept` arms | shipped | v1.2f (`b4089b4`) | (covered by `test/routines/action_dispatch_test.dart`) |
| 7 | BOOT_COMPLETED coverage confirmation — `BootReceiver` exhaustive over `BOOT_COMPLETED` / `LOCKED_BOOT_COMPLETED` / `MY_PACKAGE_REPLACED` | shipped | v1.2g (`a31331c`) | (covered by `test/reminders/reboot_survival_test.dart`) |
| 8 | per-automation `AutomationReliabilityDialog` on tap (trigger-side only) | shipped (trigger-side only; action-side deferred to Phase 25) | v1.2h (`6e47be7`) | SYS-103 / ADR-035 |
| 9 | `AppLifecycleState.resumed` re-probe hook (`PermissionLifecycleReProbe`) | shipped | v1.2i (`f0990fe`) | SYS-104 / ADR-036 |
| 10 | DST transition banner + streak-recovery card + pre-notification 5-min / 1-min heads-up | shipped | v1.2j (`d80b9f1`) | SYS-105 + SYS-106 + SYS-107 / ADR-037 + ADR-038 + ADR-039 |
| 11a | hard-delete affordance on edit screen (`AddHabitScreen` `Delete…` popup-menu) | shipped | v1.2k (`7bb126e`) | SYS-108 |
| 11b | shared `MissionWrongAttempts` module (uniform 3-wrong take-a-break across Math + Type) | shipped | v1.2l (`6f83d47`) | SYS-109 / ADR-040 |
| 11c | `CompletionLogSection` for review + undo | shipped | v1.2m (`8b3f83e`) | SYS-110 / ADR-041 |
| 12 | monthly stats + per-do grace factory (`Do.effectiveStreakConfig(...)` + `kDefaultGraceWindow` + 30-day completion-rate + MoM delta + 7-day bar chart + Settings → Stats tile) | shipped | v1.3a (`a4a5393`, PR #18) | SYS-111 |
| 13 | unified reliability source-of-truth (`ReliabilityService.instance` + `ReliabilityBanner.fromStream` factory + `_ReliabilityRow` binding + `AppLifecycleState.resumed` re-probe extension) | shipped | v1.3b (`e9fc922`, PR #19) | SYS-112 / ADR-042 |
| 14 | `USE_FULL_SCREEN_INTENT` probe + reliability wiring (`PermissionKind.fullScreenIntent` + `FullScreenIntentService` singleton + 5th `_PermissionTile` + manifest entry + reliability gate fold-in) | shipped (= Phase 6a.i) | v1.3c (`81962a1`, PR #20) | SYS-113 / ADR-043 |
| 15 | full-screen activity launch path (`FullScreenActivity` Kotlin class + launch handlers + `setFullScreenIntent` + `MissionLauncherScreen` orchestrator + `RoutineOverlayScreen`) | shipped (= Phase 6a.ii) | v1.3d (`5eca37b`, PR #21) | SYS-114 / ADR-044 |
| 16 | in-app tile streak number (the home screen `_HabitTile` shows `currentStreak`) | v1.x parking lot (v1.4b candidate) | — | — |
| 17 | in-app tile "Done" button (wire the `_HabitTile`'s `IconButton` to actually call `CompletionLogService.append`) | v1.x parking lot (v1.4b candidate) | — | — |
| 18 | widget resize variants (small + large layouts in addition to medium) | v1.x parking lot (v1.4b candidate) | — | — |
| 19 | widget config activity (user picks which Do the widget tracks) | v1.x parking lot (v1.4b candidate) | — | — |
| 20 | widget list (scrolling RemoteViews list of multiple dos) | v1.x parking lot (v1.4b candidate) | — | — |
| 21 | deep-link from widget body to a specific Do (`/do/<id>` route in `MaterialApp.routes`) | v1.x parking lot (v1.4b candidate) | — | — |
| 22 | iOS port (Swift equivalents for `lib/reminders/` + `lib/services/platform_*`; model layer is already pure Dart) | v1.x parking lot (v2.x candidate due to scope) | — | — |
| 23 | Wear OS target (companion surface mirroring the home tile) | v1.x parking lot (v2.x candidate due to scope) | — | — |
| 24 | backup encryption upgrade (PBKDF2-HMAC-SHA256 100k → Argon2id per current OWASP guidance; backwards-compat reads-from-v1 per the v0.4c.1 precedent) | v1.x parking lot (v1.5a candidate) | — | — |
| 25 | action-side permission disambiguation in `AutomationReliabilityDialog` (extends Phase 8 from trigger-side to action-side: `ActionOverrideSilent` → `ACCESS_NOTIFICATION_POLICY`, contact-requiring actions → `READ_CONTACTS`) | v1.x parking lot (v1.5b candidate) | — | — |
| 26 | `TriggerCallIncoming*` reliability arm fold-in (extending the `RoleManager` check from `PermissionKind.callScreening` into `_requiredPermissionForTrigger`; closes `feature.md` §2.3) | v1.x parking lot (v1.5c candidate) | — | — |
| 27 | backup format v2 → v3 (adds `RoutineConfig`, `Person.pausedUntil`, the v1.1f / v1.2h reliability badge states, the v1.3x `ReliabilityService` snapshot; backwards-compat reads-from-v1) | v1.x parking lot (v1.5d candidate) | — | — |
| 28 | **Android home screen widget (the Phase 28 milestone — greenfield AppWidgetProvider + `RemoteViews` + `doit/widget` MethodChannel + `WidgetService` Dart-side singleton; shows first-active Do + streak + reliability badge + Done affordance; closes B9 re-arm indicator requirement)** | in-progress (Phase 20 plan approved; implementation unblocks after PR #21 + #22 merge) | v1.4a (planned, blocking on PR #21 merge) | SYS-115 / ADR-045 / WF-042 (planned) |
| 29 | native-Spanish-speaker translation of `lib/l10n/app_es.arb` (v1.1h's smoke-test locale is the only translation; closes `feature.md` §2.4) | v1.x parking lot (v1.6a candidate) | — | — |
| 30 | retrospective + roadmap retrospective doc (mirror of `docs/v_model/v1_1_handoff_from_v1_0g.md`) + the home-screen-widget retrospective + the `home_widget` package re-evaluation (in case the native-AppWidgetProvider approach turns out to be too much for the team) | v1.x parking lot (v1.6b candidate) | — | — |

## Why this doc exists

The roadmap was originally scattered across three places:

1. **The v1.2 baseline** (`docs/v_model/v1_2_release_baseline.md` §2) — a 18-row table covering Phases 1-11c.
2. **The v1.3 baseline** (`docs/v_model/v1_3_release_baseline.md` §2) — a 5-row table covering Phases 12-15 + Phases 16-30 deferred.
3. **The v1.x parking lot** (`feature.md` §4) — 5 bullets covering home widget, iOS port, Wear OS, backup encryption upgrade, backup format v2 → v3.

Every CHANGELOG sub-entry references "Phase N of the 30-phase roadmap" inline. Every `feature.md` §3.1 / §3.2 follow-up says "the roadmap is scattered across CHANGELOG entries — needs `v1_2_30_phase_roadmap.md`". This file is the consolidation — the 30 rows above are the single source-of-truth.

## How to update this file

When a phase lands:

1. Update the **Status** column to `shipped` + the **Sub-entry / PR** column to the CHANGELOG sub-entry + PR number + commit SHA.
2. Update the **SYS- / ADR-** column to the canonical IDs (mirror `requirements.md` + `decision_record.md`).
3. Update the **Phase 6a row** to reflect that v1.3c + v1.3d together close the 6a entry — the split into 6a.i + 6a.ii rows is for traceability.

When a phase is **promoted from parking lot to in-progress**:

1. Bump the row's **Status** column to `in-progress (v1.Xa candidate)` and reference the PR.
2. The CHANGELOG sub-entry for the new milestone gets a row referencing back to this file.

When a phase is **demoted from parking lot to v2.x**:

1. Update the **Status** column to `v2.x candidate (deferred from v1.x)`.
2. The rationale lives in `feature.md` §4 — add a footnote here citing the `feature.md` line.

## Cross-references

- **The v1.2 baseline** still owns Phases 1-11c; the v1.3 baseline still owns Phases 12-15. This file is the union — neither baseline needs to be re-edited to point at this file (the inline references are useful in their own right as the per-milestone scope summary).
- **`feature.md` §3.1 / §3.2 / §3.3** still lists the 30-phase-roadmap follow-ups as a bullet — that bullet becomes "done" once this file lands. `feature.md` §4 still lists the parking-lot candidates — those bullets can be shortened once this file is the canonical list.
- **`implementation_status.md`** rows reference CHANGELOG sub-entries which reference this file. The chain is: `implementation_status.md` → `CHANGELOG.md` → `v1_2_30_phase_roadmap.md` (this file) → `requirements.md` / `decision_record.md` for SYS- / ADR- IDs.

## Out of scope

- The roadmap does **not** cover v0.1-v1.0 phases — those predate the 30-phase framing. `implementation_status.md` rows v0.5a..v0.5e-fix + v1.0h..v1.0j + v1.1a..v1.1k are the source-of-truth for those cycles.
- The roadmap does **not** assign PR numbers to parked phases — those PR numbers are TBD when the phase ships.
- The roadmap does **not** include size estimates — those live in the per-phase plan files (see `docs/v_model/plan.md` Milestone 11 draft for v1.4).