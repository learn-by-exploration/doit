# Stabilization Roadmap — 3-month campaign

Status: active. The single source of truth for "what's left to stabilize"
after the v1.4a..v1.4m feature cycles. Each subsequent stabilization cycle
updates this doc (mark done, add findings, re-prioritize).

**Cycle A kicked off:** 2026-06-28. **Window:** ~3 months (≈13 weeks).
**Owner:** Claude (autonomous mode) per the user directive "we have 3 month
to stabilise the app and have exhaustive test".

---

## 1. Current coverage state

Source: `flutter test --coverage` (1334/1334 pass, 2026-06-28).

**Overall `lib/` coverage: 8812/13638 lines (64.61%) across 123 files.**
Branches are not reported by Dart's coverage tooling (Dart's coverage
tooling does not emit `BRF` / `BRH` markers by default — only line hits).

| Bucket | Threshold | File count | Action |
|---|---|---|---|
| Priority 1 | < 80% line coverage | **33 files** | These need new tests in the appropriate stabilization cycle |
| Priority 2 | 80-90% line coverage | 31 files | Opportunistic improvement; not blocking |
| Priority 3 | ≥ 90% line coverage | 59 files | Tracked; not action-required |

### Priority 1 files (< 80% line coverage)

These are the worst offenders — every file in this table should be the
target of a dedicated test-writing cycle, OR have its low coverage
explained by an ADR ("why this file has no unit tests"). The cycle
sequencing in §3 references these explicitly.

| File | Lines | Coverage | Note |
|---|---|---|---|
| `lib/services/db/migrations/v1_to_v2.dart` | 0/12 | 0.0% | Migration file — exercised by integration test, not unit test (Drift codegen) |
| `lib/services/db/tables.dart` | 0/119 | 0.0% | Drift table definitions — exercised by every test that reads/writes the DB; "tested transitively" but not directly |
| `lib/services/db/schema.g.dart` | 1301/3909 | 33.3% | Generated Drift code — generated, not hand-written |
| `lib/main.dart` | 17/53 | 32.1% | App entry point — integration-tested via `integration_test/`, not unit-tested |
| `lib/widget/widget_config_screen.dart` | 1/44 | 2.3% | Per-instance widget configuration screen (v1.4k / SYS-125) — minimal test coverage; Cycle G + Cycle H will exercise the screen |
| `lib/l10n/gen/app_localizations_es.dart` | 10/143 | 7.0% | Generated localization code (Spanish ARB); Cycle I will exercise both locales |
| `lib/screens/settings_restore.dart` | 16/86 | 18.6% | Backup restore UI — has integration coverage; needs unit tests |
| `lib/services/permission_result.dart` | 7/37 | 18.9% | Permission result sealed class — covered transitively via permission_service_test.dart; should add direct tests |
| `lib/services/pause_service.dart` | 7/31 | 22.6% | Pause service — covered transitively; needs direct coverage for `pausedUntil` edge cases |
| `lib/reminders/full_screen_intent.dart` | 6/24 | 25.0% | Full-screen intent — Cycle C will add `USE_FULL_SCREEN_INTENT` probe + tests |
| `lib/widget/widget_service_proxy.dart` | 1/3 | 33.3% | Trivial proxy — single forward call; test value is low |
| `lib/missions/chain.dart` | 6/14 | 42.9% | Chain model — covered transitively via `chain_executor.dart`; needs edge-case tests |
| `lib/screens/add_person.dart` | 113/258 | 43.8% | Add-person screen — widget tests partial; needs more coverage |
| `lib/screens/add_habit.dart` | 283/633 | 44.7% | Add-habit screen (the most complex form) — widget tests partial; needs more coverage |
| `lib/services/calendar_service.dart` | 53/101 | 52.5% | Calendar service — needs direct coverage |
| `lib/services/person_repository.dart` | 82/154 | 53.2% | Person repository — has direct tests but coverage gap |
| `lib/people/person.dart` | 24/44 | 54.5% | Person model — pure-Dart, MUST hit 100% per the success criteria |
| `lib/screens/person_groups.dart` | 150/275 | 54.5% | Person groups screen — needs more widget tests |
| `lib/screens/add_event.dart` | 149/269 | 55.4% | Add-event screen — needs more widget tests |
| `lib/services/db.dart` | 16/27 | 59.3% | Drift singleton — tested transitively |
| `lib/widgets/permission_sheet.dart` | 80/130 | 61.5% | Permission rationale sheet — needs more widget tests |
| `lib/missions/mission_input.dart` | 33/51 | 64.7% | Mission input — pure-Dart, MUST hit 100% per the success criteria |
| `lib/widget/widget_bridge.dart` | 24/36 | 66.7% | Widget bridge — needs direct tests |
| `lib/do/do.dart` | 210/301 | 69.8% | Base `Do` domain model — pure-Dart, MUST hit 100% per the success criteria |
| `lib/triggers/action.dart` | 26/36 | 72.2% | Trigger action — needs more tests |
| `lib/do/proof_mode.dart` | 16/22 | 72.7% | Proof mode sealed — pure-Dart, needs 100% |
| `lib/do/consecutive_counter.dart` | 47/62 | 75.8% | Streak calculator — pure-Dart, MUST hit 100% per the success criteria |
| `lib/triggers/condition.dart` | 66/87 | 75.9% | Trigger condition — needs more tests |
| `lib/widget/widget_action_invoker.dart` | 31/40 | 77.5% | Widget action invoker — needs more tests |
| `lib/missions/mission_result.dart` | 7/9 | 77.8% | Mission result sealed — pure-Dart, needs 100% |
| `lib/events/event.dart` | 32/41 | 78.0% | Event model — pure-Dart, needs 100% |
| `lib/screens/home_tile_sparkline.dart` | 33/42 | 78.6% | Home tile sparkline — has tests but coverage gap |
| `lib/services/permission_lifecycle_observer.dart` | 11/14 | 78.6% | Lifecycle observer — needs more tests |

**Notes on the table:**
- The pure-Dart model layer (`lib/do/`, `lib/people/`, `lib/habits/`,
  `lib/missions/`, `lib/events/`) MUST hit 100% coverage per the
  success criteria (§4). Current state shows several gaps — these are
  the foundation of the stabilization campaign.
- Drift generated files (`schema.g.dart`) and migration files
  (`migrations/v*.dart`) are tested transitively — every DB test
  exercises the schema. Adding direct unit tests to generated code is
  low value.
- Widget config screen coverage will improve when Cycle G (badge) +
  Cycle H (recently-deleted UI) ship — both new screens consume
  `WidgetService.setSelectedHabitId` and benefit from the same test
  patterns.

### The full per-file table (all 123 `lib/` files)

| Coverage | Lines | Branches | File |
|----------|-------|----------|------|
| 0.0% | 0/12 | — | `lib/services/db/migrations/v1_to_v2.dart` |
| 0.0% | 0/119 | — | `lib/services/db/tables.dart` |
| 2.3% | 1/44 | — | `lib/widget/widget_config_screen.dart` |
| 7.0% | 10/143 | — | `lib/l10n/gen/app_localizations_es.dart` |
| 18.6% | 16/86 | — | `lib/screens/settings_restore.dart` |
| 18.9% | 7/37 | — | `lib/services/permission_result.dart` |
| 22.6% | 7/31 | — | `lib/services/pause_service.dart` |
| 25.0% | 6/24 | — | `lib/reminders/full_screen_intent.dart` |
| 32.1% | 17/53 | — | `lib/main.dart` |
| 33.3% | 1301/3909 | — | `lib/services/db/schema.g.dart` |
| 33.3% | 1/3 | — | `lib/widget/widget_service_proxy.dart` |
| 42.9% | 6/14 | — | `lib/missions/chain.dart` |
| 43.8% | 113/258 | — | `lib/screens/add_person.dart` |
| 44.7% | 283/633 | — | `lib/screens/add_habit.dart` |
| 52.5% | 53/101 | — | `lib/services/calendar_service.dart` |
| 53.2% | 82/154 | — | `lib/services/person_repository.dart` |
| 54.5% | 24/44 | — | `lib/people/person.dart` |
| 54.5% | 150/275 | — | `lib/screens/person_groups.dart` |
| 55.4% | 149/269 | — | `lib/screens/add_event.dart` |
| 59.3% | 16/27 | — | `lib/services/db.dart` |
| 61.5% | 80/130 | — | `lib/widgets/permission_sheet.dart` |
| 64.7% | 33/51 | — | `lib/missions/mission_input.dart` |
| 66.7% | 24/36 | — | `lib/widget/widget_bridge.dart` |
| 69.8% | 210/301 | — | `lib/do/do.dart` |
| 72.2% | 26/36 | — | `lib/triggers/action.dart` |
| 72.7% | 16/22 | — | `lib/do/proof_mode.dart` |
| 75.8% | 47/62 | — | `lib/do/consecutive_counter.dart` |
| 75.9% | 66/87 | — | `lib/triggers/condition.dart` |
| 77.5% | 31/40 | — | `lib/widget/widget_action_invoker.dart` |
| 77.8% | 7/9 | — | `lib/missions/mission_result.dart` |
| 78.0% | 32/41 | — | `lib/events/event.dart` |
| 78.6% | 33/42 | — | `lib/screens/home_tile_sparkline.dart` |
| 78.6% | 11/14 | — | `lib/services/permission_lifecycle_observer.dart` |
| 80.0% | 4/5 | — | `lib/do/proof_mode_tag.dart` |
| 80.1% | 113/141 | — | `lib/screens/templates.dart` |
| 80.4% | 86/107 | — | `lib/widgets/calendar_picker.dart` |
| 80.5% | 33/41 | — | `lib/services/full_screen_intent_service.dart` |
| 80.5% | 33/41 | — | `lib/services/usage_stats_service.dart` |
| 81.1% | 77/95 | — | `lib/services/device_state_probe.dart` |
| 82.1% | 138/168 | — | `lib/services/call_interceptor.dart` |
| 82.6% | 19/23 | — | `lib/screens/home_tile_budget.dart` |
| 82.6% | 19/23 | — | `lib/screens/home_tile_skip.dart` |
| 83.0% | 39/47 | — | `lib/widgets/streak_recovery_card.dart` |
| 83.2% | 119/143 | — | `lib/l10n/gen/app_localizations_en.dart` |
| 83.6% | 92/110 | — | `lib/screens/add_routine.dart` |
| 83.8% | 88/105 | — | `lib/screens/routine_apply.dart` |
| 83.8% | 83/99 | — | `lib/widgets/automation_reliability_dialog.dart` |
| 84.8% | 56/66 | — | `lib/screens/mission_launcher.dart` |
| 85.2% | 69/81 | — | `lib/services/reminder_service.dart` |
| 85.3% | 29/34 | — | `lib/services/backup_scheduler.dart` |
| 85.7% | 545/636 | — | `lib/screens/home.dart` |
| 85.7% | 30/35 | — | `lib/app_router.dart` |
| 86.3% | 44/51 | — | `lib/widgets/dst_transition_banner.dart` |
| 87.0% | 20/23 | — | `lib/screens/home_tile_undo.dart` |
| 87.3% | 55/63 | — | `lib/reminders/reminder_bridge.dart` |
| 87.5% | 223/255 | — | `lib/services/do_repository.dart` |
| 87.5% | 7/8 | — | `lib/widget/widget_state_locator.dart` |
| 87.8% | 86/98 | — | `lib/triggers/trigger.dart` |
| 88.9% | 40/45 | — | `lib/screens/mission_math.dart` |
| 88.9% | 16/18 | — | `lib/services/db/schema.dart` |
| 89.3% | 25/28 | — | `lib/do/category.dart` |
| 89.4% | 42/47 | — | `lib/people/person_group.dart` |
| 89.5% | 34/38 | — | `lib/do/skip_budget.dart` |
| 89.8% | 115/128 | — | `lib/widgets/location_picker.dart` |
| 90.6% | 48/53 | — | `lib/screens/mission_shake.dart` |
| 90.6% | 29/32 | — | `lib/widgets/reliability_banner.dart` |
| 90.7% | 68/75 | — | `lib/services/reliability_service.dart` |
| 90.9% | 20/22 | — | `lib/widget/widget_state_cache.dart` |
| 91.5% | 226/247 | — | `lib/screens/settings.dart` |
| 91.6% | 87/95 | — | `lib/widgets/completion_log_section.dart` |
| 91.7% | 22/24 | — | `lib/widgets/automation_reliability_badge.dart` |
| 92.4% | 61/66 | — | `lib/screens/mission_hold.dart` |
| 92.5% | 173/187 | — | `lib/screens/stats.dart` |
| 92.6% | 25/27 | — | `lib/missions/shake_detector.dart` |
| 92.9% | 91/98 | — | `lib/services/person_group_repository.dart` |
| 93.4% | 71/76 | — | `lib/screens/mission_memory.dart` |
| 93.4% | 142/152 | — | `lib/services/permission_service.dart` |
| 93.8% | 15/16 | — | `lib/missions/chain_executor.dart` |
| 94.1% | 16/17 | — | `lib/l10n/gen/app_localizations.dart` |
| 94.4% | 135/143 | — | `lib/screens/onboarding.dart` |
| 94.8% | 55/58 | — | `lib/reminders/alarm_scheduler.dart` |
| 95.8% | 228/238 | — | `lib/routines/routine.dart` |
| 96.3% | 182/189 | — | `lib/routines/routine_executor.dart` |
| 96.3% | 104/108 | — | `lib/services/widget_service.dart` |
| 96.5% | 333/345 | — | `lib/services/backup_service.dart` |
| 96.6% | 86/89 | — | `lib/services/geofence_service.dart` |
| 97.1% | 67/69 | — | `lib/services/settings_service.dart` |
| 97.1% | 34/35 | — | `lib/screens/mission_type.dart` |
| 97.6% | 122/125 | — | `lib/widgets/location_map_preview.dart` |
| 97.8% | 44/45 | — | `lib/people/cadence.dart` |
| 98.3% | 115/117 | — | `lib/widgets/category_chip.dart` |
| 98.3% | 58/59 | — | `lib/templates/template_library.dart` |
| 98.4% | 61/62 | — | `lib/missions/mission.dart` |
| 98.5% | 66/67 | — | `lib/services/event_repository.dart` |
| 98.6% | 68/69 | — | `lib/widget/doit_widget_state.dart` |
| 98.6% | 71/72 | — | `lib/services/completion_log_service.dart` |
| 100.0% | 25/25 | — | `lib/do/do_description.dart` |
| 100.0% | 13/13 | — | `lib/missions/mission_attempts.dart` |
| 100.0% | 18/18 | — | `lib/reminders/anchor_detector.dart` |
| 100.0% | 5/5 | — | `lib/reminders/notification_service.dart` |
| 100.0% | 24/24 | — | `lib/routines/automation_reliability.dart` |
| 100.0% | 52/52 | — | `lib/routines/routine_template_payload.dart` |
| 100.0% | 2/2 | — | `lib/screens/home_tile_completion.dart` |
| 100.0% | 4/4 | — | `lib/screens/home_tile_delete.dart` |
| 100.0% | 15/15 | — | `lib/screens/home_tile_streak.dart` |
| 100.0% | 33/33 | — | `lib/screens/rest_day_picker_dialog.dart` |
| 100.0% | 19/19 | — | `lib/screens/routine_overlay_screen.dart` |
| 100.0% | 2/2 | — | `lib/services/db/migrations/v2_to_v3.dart` |
| 100.0% | 4/4 | — | `lib/services/db/migrations/v3_to_v4.dart` |
| 100.0% | 2/2 | — | `lib/services/db/migrations/v4_to_v5.dart` |
| 100.0% | 22/22 | — | `lib/services/japan_routine_config.dart` |
| 100.0% | 1/1 | — | `lib/services/permission_kind_meta.dart` |
| 100.0% | 64/64 | — | `lib/services/platform_alarm_scheduler.dart` |
| 100.0% | 20/20 | — | `lib/services/platform_full_screen_intent.dart` |
| 100.0% | 11/11 | — | `lib/services/platform_notification_service.dart` |
| 100.0% | 63/63 | — | `lib/services/routine_config.dart` |
| 100.0% | 69/69 | — | `lib/services/template_repository.dart` |
| 100.0% | 45/45 | — | `lib/templates/template.dart` |
| 100.0% | 11/11 | — | `lib/theme/app_theme.dart` |
| 100.0% | 19/19 | — | `lib/widget/widget_state_builder.dart` |
| 100.0% | 31/31 | — | `lib/widgets/device_state_row.dart` |
| 100.0% | 48/48 | — | `lib/widgets/icon_picker.dart` |
| 100.0% | 27/27 | — | `lib/widgets/routine_banner.dart` |

---

## 2. Latent bugs inventory

The known bugs that the stabilization campaign will close. Each bug has
a target cycle; cycles that close multiple bugs do so in one PR (e.g.,
Cycle B closes both BUG-001 and BUG-002 because they share the same
`_toRow` save-path).

| Bug ID | Description | Source | Priority | Target cycle |
|---|---|---|---|---|
| BUG-001 | `_toRow` does NOT write `automations_json` to `HabitsCompanion`. User's automations are silently lost on Save click. | `feature.md` §4 + `lib/services/do_repository.dart:106-134` | P0 (data loss) | Cycle B |
| BUG-002 | `_toRow` does NOT write `paused_until_millis`. User's pause state is silently lost on Save click. | `feature.md` §4 + `lib/services/do_repository.dart:106-134` | P0 (data loss) | Cycle B |
| BUG-003 | Full-screen launch on Android 14+ requires `USE_FULL_SCREEN_INTENT` permission. Without it, lockscreen-bypass fails silently. | `docs/v_model/notification_reliability.md §5` | P1 (reliability) | Cycle C |
| BUG-004 | "Target paused" badge on home tile for DoAnchor dos whose target is tombstoned — data layer ships in v1.4l; UI deferred. | `v1.4l ADR-056 §6` | P2 (UX) | Cycle G |
| BUG-005 | `callScreening` permission probe was deferred in v1.1f; rationale copy exists but the runtime probe is incomplete. | `v1.1f ADR-031` | P2 (reliability) | Cycle D |
| BUG-006 | Spanish (`es`) ARB has stale copy in some keys (the v1.0 native-speaker review was deferred). | `feature.md` §4 | P3 (UX) | Post-stab (needs native speaker) |
| BUG-007 | `pause_service.dart` coverage is 22.6% — `pausedUntil` edge cases are not exhaustively tested. The fix is a Cycle B side-effect (the `pausedUntilMillis` field gets a save-invariant pin). | §1 audit findings | P2 | Cycle B |
| BUG-008 | `add_habit.dart` coverage is 44.7% — the most complex form in the app has partial widget test coverage. | §1 audit findings | P2 | Cycle K (E2E) — partial coverage via E2E flows |
| BUG-009 | `add_person.dart` coverage is 43.8% — person form has partial widget test coverage. | §1 audit findings | P3 | Cycle K (E2E) |
| BUG-010 | `add_event.dart` coverage is 55.4% — event form has partial widget test coverage. | §1 audit findings | P3 | Cycle K (E2E) |
| BUG-011 | `permission_result.dart` coverage is 18.9% — sealed class used transitively; needs direct unit tests on every sealed subclass. | §1 audit findings | P2 | Cycle D |
| BUG-012 | `person.dart` model coverage is 54.5% — pure-Dart, MUST hit 100% per success criteria. | §1 audit findings | P2 | Cycle D + Cycle K |
| BUG-013 | `do.dart` base model coverage is 69.8% — pure-Dart, MUST hit 100% per success criteria. | §1 audit findings | P0 | Cycle B (pin) + Cycle K |
| BUG-014 | `proof_mode.dart` coverage is 72.7% — pure-Dart sealed class, needs 100%. | §1 audit findings | P2 | Cycle B |
| BUG-015 | `event.dart` model coverage is 78.0% — pure-Dart, needs 100%. | §1 audit findings | P2 | Cycle K |
| BUG-016 | `consecutive_counter.dart` coverage is 75.8% — streak calculator, pure-Dart, MUST hit 100% per success criteria. | §1 audit findings | P0 | Cycle K |
| BUG-017 | `mission_input.dart` coverage is 64.7% — pure-Dart sealed class, needs 100%. | §1 audit findings | P2 | Cycle K |
| BUG-018 | `mission_result.dart` coverage is 77.8% — pure-Dart sealed class, needs 100%. | §1 audit findings | P2 | Cycle K |
| BUG-019 | `home_tile_sparkline.dart` coverage is 78.6% — has v1.4i tests but coverage gap; should add edge cases. | §1 audit findings | P3 | Opportunistic (any cycle that touches home tile) |
| BUG-020 | `permission_lifecycle_observer.dart` coverage is 78.6% — needs lifecycle-edge-case tests. | §1 audit findings | P3 | Cycle D |

**Bug-tracking rule.** When a stabilization cycle closes a bug, this
table is updated (status `closed (Cycle N)`, link to the PR). New bugs
found during the audit append to this table.

---

## 3. Cycle-by-cycle roadmap (Cycles B..L)

The sequencing below is a draft. Cycle A's findings (above) may shift
priorities (e.g., if a permission flow is more critical than expected,
it may move earlier). Each cycle's own plan-mode session will re-confirm
the priority ordering.

### Month 1 — Audit + critical fixes

#### **Cycle B** — Fix `_toRow` automations + pausedUntil latent bugs (Phase 42)

- **Closes:** BUG-001, BUG-002, BUG-007, BUG-013, BUG-014
- **Scope:** 2-line fix in `_toRow` (`lib/services/do_repository.dart`) + 2 new save-invariant tests (parallel to v1.4m's `deletedAtMillis` pin). The tests prove the user's automations + pause state survive a Save round-trip.
- **Files:** `lib/services/do_repository.dart`, `test/services/do_repository_test.dart`.
- **Tests:** +6 (2 save-invariant pins + 2 round-trip + 2 edge cases — `pausedUntil` expiry, `automationsJson` re-derivation).
- **Success criteria:** user's automations + pause state survive a Save round-trip; coverage on `do_repository.dart` ≥ 95%; coverage on `do.dart` ≥ 85% (improvement from 69.8% baseline).
- **Risk:** if a future change accidentally adds `automationsJson: d.automationsJson` to `_toRow` without the explicit "do not specify for empty automations" comment, the invariant breaks. Mitigation: the new test pins the invariant from the round-trip side.

#### **Cycle C** — Full-screen launch hardening (API 34+) (Phase 43)

- **Closes:** BUG-003
- **Scope:** Add `<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />` to `AndroidManifest.xml`. Verify the permission is requested at runtime on API 34+. Probe-and-report reliability so the home banner correctly shows "degraded" when the permission is denied. Update `notification_reliability.md`.
- **Files:** `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/.../FullScreenActivity.kt`, `lib/reminders/full_screen_intent.dart`, `lib/services/full_screen_intent_service.dart`, `docs/v_model/notification_reliability.md`, `docs/v_model/architecture_options.md` §"Permission baseline".
- **Tests:** +4 (permission probe on API 34+, permission probe on API < 34, reliability banner state when denied, full-screen launch retries on permission grant).
- **Success criteria:** full-screen launch works on Android 14+ with `USE_FULL_SCREEN_INTENT`; reliability banner correctly reports "degraded" when permission denied. Cross-check against `docs/v_model/architecture_options.md` §"Permission baseline".
- **Risk:** the `USE_FULL_SCREEN_INTENT` permission is sensitive on Android 14+ (Play Store policy). Mitigation: cross-check the permission rationale + the Play Store declaration copy in the same PR.

#### **Cycle D** — Permission flow audit (Phase 44)

- **Closes:** BUG-005, BUG-011, BUG-012, BUG-020
- **Scope:** Per-`PermissionKind` tests covering grant / deny / rationale / settings-deeplink. Complete the `callScreening` probe that v1.1f deferred. Add direct unit tests for every `PermissionResult` sealed subclass. Audit `permission_lifecycle_observer.dart` edge cases.
- **Files:** `lib/services/permission_service.dart`, `lib/services/permission_result.dart`, `lib/services/permission_lifecycle_observer.dart`, `lib/people/permission_rationale.dart`, `test/services/permission_service_test.dart`, `test/services/permission_result_test.dart` (NEW), `test/services/permission_lifecycle_observer_test.dart` (NEW).
- **Tests:** +12 (4 per `PermissionKind` × 3 most-used kinds = 12; covers grant + deny + rationale + settings-deeplink).
- **Success criteria:** every `PermissionKind` has a happy-path + a denial-path test. `callScreening` probe is complete. Coverage on `permission_service.dart` ≥ 95%, `permission_result.dart` = 100%.

### Month 2 — Reliability + integrity

#### **Cycle E** — Reliability detection coverage (Phase 45)

- **Scope:** Every path in `ReliabilityService` exercised in tests. Verify exact-alarm denied → WorkManager fallback path. Add doze-simulation tests. Probe battery-optimization denied → degrade.
- **Files:** `lib/services/reliability_service.dart`, `lib/reminders/alarm_scheduler.dart`, `test/services/reliability_service_test.dart`, `test/reminders/alarm_scheduler_test.dart`, `test/reminders/doze_simulation_test.dart`.
- **Tests:** +8 (every `Reliability` enum path × 2 trigger conditions = 8).
- **Success criteria:** every `Reliability.optimal / .degraded / .unknown` path exercised in tests. AlarmScheduler verified to fall back to WorkManager when exact-alarm is denied. Doze-simulation tests cover idle + maintenance windows.

#### **Cycle F** — Backup round-trip exhaustive (Phase 46)

- **Scope:** Every backup payload version × every table × every field. The current backup tests cover the v0.2 / v1.0 schema fields + envelope shape; they don't exhaustively cover every optional field (`do/automations`, `do/pausedUntil`, `event/archivedAt`, `person/resolutionStatus`, `do/deletedAtMillis`).
- **Files:** `lib/services/backup_service.dart`, `test/services/backup_encryption_test.dart`.
- **Tests:** +10 (every optional field × 1 round-trip = 10).
- **Success criteria:** every backup envelope field round-trips losslessly. Coverage on `backup_service.dart` = 100%.

#### **Cycle G** — DoAnchor "Target paused" badge (Phase 47)

- **Closes:** BUG-004, BUG-019
- **Scope:** The v1.4l data layer ships the "pause, don't break" semantics for `DoAnchor.targetDoId` referencing a tombstoned habit. The badge rendering on the home tile is deferred. Cycle G ships the UI.
- **Files:** `lib/screens/home.dart`, `lib/widgets/do_anchor_paused_badge.dart` (NEW), `test/screens/home_test.dart`, `test/widgets/do_anchor_paused_badge_test.dart` (NEW).
- **Tests:** +6 (badge renders when target is tombstoned, badge hides when target is active, badge accessibility label, badge semantics, badge color, badge position).
- **Success criteria:** the "Target paused" badge renders on anchor dos whose target is tombstoned. Coverage on `home.dart` ≥ 90% (improvement from 85.7% baseline).

#### **Cycle H** — Restore / delete-forever UI (Phase 48)

- **Scope:** The deferred v1.4n "Recently deleted" UI. Pure UI; data layer + tests are already shipped in v1.4m. This is the LAST UI surface in the v1.4 series — it completes the v1.4l feature.
- **Files:** `lib/screens/recently_deleted_screen.dart` (NEW), `lib/app_router.dart`, `lib/screens/settings.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`, `test/screens/recently_deleted_screen_test.dart` (NEW).
- **Tests:** +12 (every screen state × 3-4 affordances = 12: list loaded, list empty, restore happy path, restore failed, delete-forever happy path, delete-forever confirm, delete-forever cancel, navigation, error retry, SnackBar success, SnackBar failed, ARB parity).
- **Success criteria:** the "Recently deleted" UI surface ships. Users can restore or delete-forever tombstoned habits. Coverage on `recently_deleted_screen.dart` = 100%.

### Month 3 — Polish + exhaustive

#### **Cycle I** — i18n test exhaustive (Phase 49)

- **Partially closes:** BUG-006 (test coverage only; copy review needs native speaker)
- **Scope:** Every ARB key tested in both `en` and `es` locales. Every screen renders both locales.
- **Files:** `test/l10n/app_localizations_test.dart`, `test/l10n/locale_render_test.dart` (NEW).
- **Tests:** +20 (every ARB key × 2 locales + every screen × 2 locales = ~100+, conservatively 20 distinct tests).
- **Success criteria:** every ARB key has a test in both locales. Every screen renders both locales. ARB parity test catches missing Spanish entries automatically.

#### **Cycle J** — Accessibility audit (Phase 50)

- **Scope:** Every screen has TalkBack labels. Color contrast ≥ 4.5:1 for body text, ≥ 3:1 for large text and icons. Font-scale tested at 1.0x / 1.3x / 1.6x.
- **Files:** `test/a11y/every_screen_test.dart` (NEW).
- **Tests:** +15 (every screen × 3 checks = 15).
- **Success criteria:** every screen has TalkBack labels, contrast ≥ 4.5:1, font-scale tested at 1.0x / 1.3x / 1.6x.

#### **Cycle K** — E2E integration tests (Phase 51)

- **Partially closes:** BUG-008, BUG-009, BUG-010, BUG-012, BUG-013, BUG-015, BUG-016, BUG-017, BUG-018
- **Scope:** 10 critical user flows: add do → mark done → streak → delete → undo → soft-delete → restore → backup → restore-from-backup → update-via-appcast.
- **Files:** `integration_test/critical_flows_test.dart` (NEW).
- **Tests:** +10 (one per flow).
- **Success criteria:** every critical user flow runs end-to-end in `integration_test/`. The pure-Dart model layer coverage hits 100% per the success criteria.

#### **Cycle L** — Performance audit + fuzz + benchmark (Phase 52)

- **Scope:** Widget rebuild benchmark. SQL query benchmark (N+1 detection). APK size documented. Fuzz / property tests for the model layer (`lib/do/`, `lib/people/`, `lib/habits/`, `lib/missions/`).
- **Files:** `test/perf/widget_rebuild_test.dart` (NEW), `test/perf/sql_benchmark_test.dart` (NEW), `test/fuzz/do_model_fuzz_test.dart` (NEW), `docs/v_model/performance_baseline.md` (NEW).
- **Tests:** +10 (benchmarks + fuzz tests).
- **Success criteria:** widget rebuild benchmark ≤ 1 ms per tile. SQL query benchmark ≤ 5 ms per query. APK size documented and ≤ 80 MB. Fuzz tests run 1000 iterations with no crashes.

---

## 4. Success criteria for the 3-month campaign

After Cycle L, the project should have:

1. **≥90% line coverage** on every file in `lib/` (up from the current "≥80% on changed files" rule)
2. **100% coverage** on the pure-Dart model layer (`lib/do/`, `lib/people/`, `lib/habits/`, `lib/missions/`, `lib/events/`) — no Flutter, no excuses
3. **E2E tests** for the 10 critical user flows (Cycle K)
4. **0 known latent bugs** in §2 above (every BUG-NNN closed)
5. **Accessibility**: every screen has TalkBack labels, contrast ≥ 4.5:1, font-scale tested at 1.0x / 1.3x / 1.6x (Cycle J)
6. **i18n**: every ARB key tested in both locales; every screen renders both locales (Cycle I)
7. **Reliability**: every `Reliability` enum path exercised in tests (Cycle E)
8. **Backup**: every backup version × every table × every field round-trip clean (Cycle F)
9. **Performance**: widget rebuild benchmark, SQL query benchmark, APK size documented (Cycle L)
10. **0 skipped tests** (current rule preserved)

---

## 5. Open questions

These need user input before subsequent cycles can plan. Cycle A
catalogs them so the user can address them in batches.

1. **Cycle C's permission scope.** Does the user want `USE_FULL_SCREEN_INTENT` added to the Play Store declaration? The permission is sensitive on Android 14+ and may affect Play Store review. (Affects Cycle C.)
2. **Cycle F's backup scope.** Does the user want backup round-trip tests for every historical backup envelope version (v1, v2, v3) or only the current v3? Historical round-trip is more thorough but adds ~10 tests. (Affects Cycle F.)
3. **Cycle H's restore UI scope.** Is the "Recently deleted" UI a top-level screen (full-screen list) or a section within the existing Settings screen? Affects the layout of `lib/screens/recently_deleted_screen.dart`. (Affects Cycle H.)
4. **Cycle K's E2E scope.** Should the 10 critical flows include `update-via-appcast` (which requires a mock appcast server) or drop it? Affects the test harness complexity. (Affects Cycle K.)
5. **BUG-006 (Spanish translation).** Does the user have a native Spanish speaker who can review the ARB copy, or should we defer to a future v2.0 milestone? (Affects all subsequent i18n work.)

---

## 6. Cycle A retrospective

**Cycle A status:** kicked off 2026-06-28. Coverage report produced.
Roadmap drafted. Sequencing provisional; will be re-confirmed by
Cycle B's plan-mode session.

**Cycle A artifacts:**
- `docs/v_model/stabilization_roadmap.md` (this file) — main deliverable
- `coverage/lcov.info` — coverage report (1334/1334 tests pass; 8812/13638 lines covered = 64.61%)
- V-Model artifacts: SYS-128, ADR-059, WF-056
- `feature.md` §4 / §5 / §6 updated
- `docs/v_model/plan.md` Milestone 12 entry added
- `CHANGELOG.md` v1.4-stab-A block added
- `implementation_status.md` v1.4-stab-A row added
- `traceability_matrix.md` WF-056 row added