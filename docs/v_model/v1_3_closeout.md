# v1.3 close-out — closed (shipped)

Status: **shipped**, 2026-06-25. The v1.3 reliability + lifecycle hardening milestone closed with the v1.3d release APK + the v1.3 sign-off. This document is the post-mortem / retrospective for the v1.3 cycle, mirroring the v1.1 pattern at [`v1_1_handoff_from_v1_0g.md`](v1_1_handoff_from_v1_0g.md).

## TL;DR

The v1.3 milestone is closed:

- **4 feature commits** (`v1.3a` … `v1.3d`) shipped between 2026-06-24 and 2026-06-25.
- **3 V-Model doc commits** appended the matching commit SHAs into [`implementation_status.md`](implementation_status.md) (the v1.3a / v1.3b / v1.3c rows in their respective PRs; the v1.3d + sign-off rows landed in the sign-off commit `f51602c`).
- **1 sign-off commit** (`f51602c`, PR #22) carries the `## [1.3.0]` CHANGELOG block + the new `v1_3_release_baseline.md` + `v1_3_release_checklist.md` + the 1.3.0+10 version bump.
- **1 follow-up commit** (`df8237d`, also on the sign-off branch) closes `feature.md §2.1` "Still deferred" (the v1.3d launch-path closure).
- **1 v1.3d release PR** (`5eca37b`, PR #21) carries the `FullScreenActivity` Kotlin class + launch handlers + chain-level orchestrator widget.
- **3-gate at v1.3 tip**: 1064 / 1064 tests pass, `dart format` clean, `flutter analyze --fatal-infos` clean. Coverage stays at the 80% floor on changed files per `AGENTS.md`.

The original "what might slip" risks from the v1.2 close-out's carry-over section (the feature.md §2.1 "Still deferred" + §2.2 action-side permission disambiguation + §2.3 `TriggerCallIncoming*` reliability arm) are now tracked: §2.1 closed in v1.3c + v1.3d, §2.2 still deferred to v1.x, §2.3 still deferred to v1.x.

## What shipped

The full per-commit trail is in [`implementation_status.md`](implementation_status.md). Summary by sub-milestone:

- **v1.3a — Monthly stats + per-do grace factory (Phase 12).**
  The stats screen shows a 30-day completion rate, a month-over-month delta, and a 7-day bar chart. The per-do `graceWindowOverride` field (Phase 11f) is now wired end-to-end through a new `Do.effectiveStreakConfig(...)` factory method. The Settings → Stats tile makes the screen discoverable from the Settings page. Closes the Phase 11f doc/impl gap: the field was inert until the factory met its first real consumer.
  Source: `lib/do/do.dart` (sealed base) + `lib/do/consecutive_counter.dart` (top-level `kDefaultGraceWindow` constant) + `lib/screens/stats.dart` + `lib/screens/settings.dart`. SYS-111 appended. Tests in `test/screens/stats_test.dart` + `test/widgets/routine_banner_clear_test.dart` (+20 tests, 999 → 1019).

- **v1.3b — Unified reliability source-of-truth (Phase 13).**
  `lib/services/reliability_service.dart` (NEW) is a singleton with a `Stream<Reliability>` getter, a `ValueListenable<Reliability>` mirror, and a synchronous `value` getter. The service merges the alarm-system bridge probe (re-run on `init`, on `refresh`, and on a 30 s fallback `Timer.periodic`) with the `PermissionService.statuses` listener (re-derives the value on every change). Initial value is `Reliability.optimal` — closes the v1.3a first-read race where the very first read of `PlatformAlarmScheduler.reliability` returned `Reliability.unknown` for a fully optimal device. `PlatformAlarmScheduler.reliability` becomes a thin pass-through (removes the 30 s fire-and-forget cache + the local `_refreshReliability` helper).
  Source: `lib/services/reliability_service.dart` + `lib/services/platform_alarm_scheduler.dart` (pass-through) + `lib/widgets/reliability_banner.dart` (new `ReliabilityBanner.fromStream` factory) + `lib/screens/settings.dart` (`_ReliabilityRow` binds to the service) + `lib/app/app_lifecycle_observer.dart` (resume hook extends to the new service) + `lib/main.dart` (await `ReliabilityService.init(...)`). SYS-112 / ADR-042 appended. Tests: 10 reliability-service + 3 scheduler-rel rewritten (1019 → 1032).

- **v1.3c — `USE_FULL_SCREEN_INTENT` probe + reliability wiring (Phase 14).**
  `PermissionKind.fullScreenIntent` joins the enum (opt-in, ADR-030 precedent). New `FullScreenIntentService` singleton mirrors `UsageStatsService` over the `doit/full_screen` MethodChannel; the Kotlin side resolves the API 32 / 33 / 34 asymmetry on the platform side (implicit-granted on API < 32; `NotificationManager.canUseFullScreenIntent()` on API 32/33/34; deep-link uses `Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT` on API 34+). `fullScreenIntent` joins `_kReliabilityGatedKinds` (now 5 elements: `location`, `calendar`, `callScreening`, `usageStats`, `fullScreenIntent`). The Settings → Permissions screen gains a 5th `_PermissionTile`. The home-screen `ReliabilityBanner` gains an `onTap` callback that deep-links the user to the tile. AndroidManifest declares `<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" tools:ignore="ProtectedPermissions" />`.
  Source: `lib/services/permission_service.dart` + `lib/services/full_screen_intent_service.dart` + `lib/services/permission_kind_meta.dart` + `lib/screens/settings_permissions.dart` + `lib/widgets/reliability_banner.dart` + `android/app/src/main/AndroidManifest.xml` + `android/app/src/main/kotlin/com/doit/FullScreenIntentChannel.kt` (NEW). SYS-113 / ADR-043 appended. Tests: 8 FSI-service + 3 permission-service + 1 reliability-service + 2 settings-permissions + 1 reliability-banner (1032 → 1047).

- **v1.3d — Full-screen activity launch path (Phase 15 / Phase 6a proper).**
  A real `FullScreenActivity` Kotlin class sets lockscreen-bypass window flags (`FLAG_SHOW_WHEN_LOCKED | FLAG_TURN_SCREEN_ON | FLAG_DISMISS_KEYGUARD | FLAG_KEEP_SCREEN_ON`) in `onCreate` and encodes intent extras into a query string via `getInitialRoute()`. `FullScreenIntentChannel.kt` grows two new `when` arms (`showHabitMission`, `showRoutineOverlay`). `MainActivity.buildReminderNotification` splits the strong-mode branch: targets `FullScreenActivity` + `setFullScreenIntent(openPi, true)`. The new `MissionLauncherScreen` chain-level orchestrator widget loads the habit by id from `DoRepository.instance.getById`, iterates the `MissionChain`, runs the executor, and appends the completion on `ChainPassed`. The new `RoutineOverlayScreen` banner widget renders routine-fired overlays. `lib/main.dart` gains `MaterialApp.onGenerateRoute` mapping `/mission` to the right screen. Closes `feature.md §2.1` "Still deferred" (the Phase 6a proper gap).
  Source: `android/app/src/main/kotlin/com/doit/FullScreenActivity.kt` (NEW) + `android/app/src/main/kotlin/com/doit/FullScreenIntentChannel.kt` + `android/app/src/main/kotlin/com/doit/MainActivity.kt` + `android/app/src/main/AndroidManifest.xml` + `lib/screens/mission_launcher.dart` (NEW) + `lib/screens/routine_overlay_screen.dart` (NEW) + `lib/main.dart` + `lib/services/platform_full_screen_intent.dart` + `lib/reminders/full_screen_intent.dart`. SYS-114 / ADR-044 appended. Tests: 6 FSI-service + 6 launcher + 4 overlay (1048 → 1064). Kotlin compile: BUILD SUCCESSFUL.

- **v1.3 — sign-off + CHANGELOG `[1.3.0]`.** Doc-only close-out: new `## [1.3.0] — 2026-06-25 — Reliability + lifecycle hardening` summary block at the top of `CHANGELOG.md` + new `docs/v_model/v1_3_release_baseline.md` + `docs/v_model/v1_3_release_checklist.md` + version bump `1.2.0+9` → `1.3.0+10` + mirror-pin test updates + `plan.md` Milestone 10 (v1.3) flipped from stub to shipped. No code, no new tests. PR #22.

## Lessons learned (v1.3 cycle)

Four lessons that future milestones should preserve:

- **L5** (v1.3b): the unified service's initial value should be the optimistic one. Before v1.3b, the very first read of `PlatformAlarmScheduler.reliability` returned `Reliability.unknown` for a fully optimal device — a race condition caused by the cold-start probe being a fire-and-forget on a 30 s TTL cache. The fix was to make `ReliabilityService.instance.value` synchronously return `Reliability.optimal` from the constructor and let the cold-start probe upgrade it to `optimal` / `degraded` later (a no-op upgrade). The lesson: when a service exposes both a synchronous `value` getter and an async probe, the synchronous getter should return the optimistic default; the async probe upgrades on success or downgrades on failure. Future services with this shape should follow.

- **L6** (v1.3c): the Kotlin-side MethodChannel extension pattern. The `FullScreenIntentChannel.kt` shape (`object` with `CHANNEL` const + `attach(engine)` / `detach()` / `setAppContext(ctx)` lifecycle + `when (call.method)` dispatch + `result.error("NO_CONTEXT", ...)` fallback) is now the canonical pattern for any Kotlin-side channel that needs to dispatch multiple method names from one MethodChannel. v1.3c shipped the probe + deep-link handlers (`canUseFullScreenIntent`, `openFullScreenIntentSettings`); v1.3d extended the same `when` with `showHabitMission` + `showRoutineOverlay`. The future `WidgetChannel.kt` (Phase 28 / v1.4a) and any other channel added in v1.x should mirror this pattern.

- **L7** (v1.3d): the Dart `_safe` wrapper as defense-in-depth (ADR-013) preserved across extensions. When v1.3c added the `FullScreenIntentChannel` probe handlers, the Dart `_safe` wrapper was added to swallow `MissingPluginException` for the probe call. When v1.3d added the launch handlers, the `MissingPluginException` raised by the new `showHabitMission` / `showRoutineOverlay` channel reads was swallowed by the same wrapper. The lesson: the `_safe` wrapper is a contract that outlives the methods it guards; future channel additions should preserve the wrapper, not replace it.

- **L8** (v1.3d): the `setFullScreenIntent` notification flag must come with a separate `PendingIntent`. When v1.3d split the strong-mode branch of `buildReminderNotification`, the existing `openIntent` (a `PendingIntent.getActivity` to `MainActivity`) was reused for the "Open" action button. The new `setFullScreenIntent(openPi, true)` required a separate `PendingIntent.getActivity` to `FullScreenActivity` (with `habitId` extra + `FLAG_ACTIVITY_NEW_TASK`). The fix was to build the FSI PendingIntent once (`fsiPi`), set `setContentIntent(fsiPi)` and `setFullScreenIntent(fsiPi, true)` and `addAction(0, "Open", fsiPi)` on the strong-mode builder. The lesson: any notification that needs a FSI flag + an Open action must build a separate PendingIntent for each (the FSI one fires when the alarm fires; the Open one fires when the user taps the heads-up notification).

## Canonical v1.3 sources

- **Requirements + design rationale + test inventory:** [`requirements.md`](requirements.md) (SYS-111..SYS-114 rows) + [`decision_record.md`](decision_record.md) (ADR-042..ADR-044 entries).
- **Traceability:** [`traceability_matrix.md`](traceability_matrix.md) top table (v1.3a..v1.3d rows; v1.3c + v1.3d map to SYS-113 + SYS-114) + workflow table (WF-041 Strong-mode habit fires full-screen mission chain end-to-end).
- **Workflow:** [`workflows.md`](workflows.md) — the v1.3 cycle did not add a new WF- ID; the strong-mode interruption flow is captured under WF-001 (alarm → notification path) which WF-041 extends.
- **Status:** [`implementation_status.md`](implementation_status.md) (v1.3a..v1.3d rows + v1.3 sign-off row; 5 rows total).
- **Milestone summary:** [`plan.md`](plan.md) Milestone 10 (v1.3, shipped).
- **User-facing change log:** [`CHANGELOG.md`](../CHANGELOG.md) `[1.3.0]` block (the sign-off summary block at the top of the file).
- **Operational concept:** [`notification_reliability.md`](notification_reliability.md) § Layer 1 (full-screen interruption) extended with the v1.3c FSI probe + v1.3d launch handlers + `setFullScreenIntent` strong-mode notification flag + `MissionLauncherScreen` orchestrator.

## Carry-over to v1.x

Items from `feature.md §2-4` that remain deferred past v1.3:

- **§2.2 Action-side permission disambiguation** in `AutomationReliabilityDialog` (today the dialog covers trigger-side only). v1.5b candidate per the 30-phase roadmap.
- **§2.3 `TriggerCallIncoming*` reliability arm** once `PermissionService.callScreening` is fully probed. v1.5c candidate.
- **§2.4 Native-Spanish-speaker translation** of `lib/l10n/app_es.arb` (v1.1h's smoke-test locale is the only translation). v1.6a candidate.
- **§2.5 `google_maps_flutter` for `LocationMapPreview`** (would add `INTERNET`). Deferred indefinitely; the v1.1e `CustomPaint` location map preview is the standing replacement.
- **§2.6 Legacy `mipmap-*/ic_launcher.png` regeneration** from the master vector. v1.5 follow-up candidate.
- **§2.7 Light-theme icon variant**. v1.5 follow-up candidate.
- **§2.8 B9 — Android home-widget re-arm indicator.** v1.4a candidate (the Phase 28 home-screen widget plan is approved; implementation unblocks after PR #21 + #22 merge).
- **Phases 16-30** of the 30-phase roadmap (consolidated at [`v1_2_30_phase_roadmap.md`](v1_2_30_phase_roadmap.md) per PR #23). v1.x parking lot.

## Out of v1.3 scope (and stay deferred)

- **Kotlin-side unit tests** for `FullScreenIntentChannel.showHabitMission` / `showRoutineOverlay` and the new `FullScreenActivity`. The Dart-side tests cover the channel-call contract; the Kotlin compile gate catches syntax / null-safety / deprecation issues. A v1.4+ follow-up can add Robolectric / `androidx.test.core` tests.
- **`wakelock_plus` swap.** The activity-level `FLAG_KEEP_SCREEN_ON` is sufficient for v1.3; a future v1.4+ could swap to `wakelock_plus` for per-mission wake-lock control.
- **Per-mission retry UX.** A `ChainFailedAt` currently pops with `null`; v1.1f grace-window semantics handle the wrong-attempt case for Math / Type; Shake / Hold / Memory do not retry. v1.4+ polish candidate.

— handoff from v1.3 cycle, closed 2026-06-25.