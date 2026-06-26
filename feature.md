# `do it` — feature.md (remaining work)

> Last updated: 2026-06-27.
> Branch: `main` @ `34b6940` (v1.4d PR #37 squash-merged).
> Test state: 1197/1197 passing. `dart format` clean. `flutter analyze --fatal-infos` clean.
> Version in `pubspec.yaml` / `lib/build_info.dart`: `1.4.0+11` (sign-off in flight on `chore/v1.4-sign-off`).

This file tracks everything that is **not yet shipped** and is not
already covered by the V-Model docs (`docs/v_model/plan.md`,
`implementation_status.md`, `decision_record.md`, `open_questions.md`,
`CHANGELOG.md`). It is the single place to look when picking the next
piece of work.

---

## 1. Ship blockers (must finish before closing the v1.4 cycle)

### 1.1 ✅ DONE — Shipped v1.4a/b/c/d/e on `main`

v1.4a (PR #33) shipped the Android home-screen widget
(SYS-115 / ADR-045 / WF-042 / Phase 28). v1.4b (PR #35)
shipped the in-app tile streak + Done button (SYS-116 /
ADR-046 / WF-043 / Phase 29). v1.4c shipped the in-app tile
Skip today + rest-day budget indicator (SYS-117 / ADR-047 /
WF-044 / Phase 30). v1.4d (PR #37) shipped the in-app tile
Undo today's completion (SYS-118 / ADR-048 / WF-045 / Phase
31). v1.4e ships the in-app tile 7-day streak history
sparkline (SYS-119 / ADR-049 / WF-046 / Phase 32).
`main` is at `34b6940` (post v1.4d) with 1208 / 1208 tests
passing post-v1.4e.

### 1.2 ✅ DONE — Bumped version to v1.4.0

`pubspec.yaml` → `version: 1.4.0+11`. `lib/build_info.dart` →
`kAppVersion = '1.4.0'`, `kAppVersionCode = 11`.
`test/release_signing_test.dart` mirror-pin assertions updated
in lockstep on `chore/v1.4-sign-off`. `CHANGELOG.md` has the
new `## [1.4.0] — 2026-06-27 — Home widget + in-app tile
completion lifecycle` summary block (mirrors `## [1.3.0]`
shape) + the `### v1.4e` sub-entry block. `implementation_status.md`
has 5 v1.4 rows + the sign-off row (mirrors the v1.0 / v1.1 /
v1.2 / v1.3 shape). `requirements.md` has SYS-115..SYS-119
appended. `decision_record.md` has ADR-045..ADR-049 appended.
`workflows.md` has WF-042..WF-046 appended.
`traceability_matrix.md` has the 5 new rows appended.

### 1.3 ✅ DONE — Added `v1_4_release_baseline.md` + `v1_4_release_checklist.md`

Both docs are on disk and current:

- `docs/v_model/v1_4_release_baseline.md` — left-side baseline:
  scope (home widget + in-app tile completion lifecycle), the
  30-phase roadmap status table (Phases 28-31 shipped; 16-27 +
  32-36 in v1.x parking lot), the SYS-115..SYS-118
  requirements table (matches `requirements.md`), the
  ADR-045..ADR-048 decisions table, the deferred-items table
  (widget-side Skip today / Undo / 7-day sparkline / tile
  edit-delete / widget variants / widget config activity /
  widget list / widget deep-link / rest-day history /
  rest-day budget edit / Phases 16-27 + 32-36 / Kotlin-side
  widget unit tests / widget "open app" deep-link / per-mission
  retry UX / native Spanish / google_maps_flutter / legacy
  mipmap regen / light-theme icon), the no-new-permissions /
  no-`INTERNET` confirmation, and the version-bump section.
- `docs/v_model/v1_4_release_checklist.md` — right-side gate:
  pre-flight mechanical checks, build + install steps (user's
  hands-on), per-sub-entry on-device verification (v1.4a/b/c/d
  checks), regression checks (re-runs the v1.3x checks), and
  the new SYS- exit criteria table that maps every
  SYS-115..SYS-118 to its test files + on-device check.

Landing in the v1.4 sign-off PR.

### 1.4 Commit a `release(v1.4)` debug-signed APK

`v1.1i` shipped as `222f860` (debug-signed APK, 75.1 MB, SHA1
`c3e0f6c6`). `v1.2` shipped as `5ed9fcf` (75.3 MB, SHA1
`85ffabbdd29e6c908c2d786d77618730b18514aa`). `v1.3` did NOT ship
a debug-signed APK commit (the project shifted to "code PR +
sign-off PR" shape in v1.3). v1.4 attempts to re-introduce the
APK commit but **the v1.4 APK exceeds GitHub's 100 MB file size
limit**: the v1.4a widget (DoitWidgetProvider + WidgetChannel
+ WidgetUpdater + WidgetRenderer + WidgetStateCache + the
`lib/widget/` Dart code + the new drawables + layouts) pushes
the debug APK from ~75 MB (v1.2) to ~175 MB. The SHA1 +
size were recorded locally:
- SHA1: `dcaf115a5991151d574ceef25a6cab2d7ab81531`
- Size: 174,842,017 bytes (166.7 MiB / 174.8 MB)

User options to land the release artefact:
- **Set up Git LFS on the repo** (recommended for future
  releases). One-time setup; the repo's `.gitattributes` would
  mark `*.apk` for LFS tracking; subsequent APK commits land
  in LFS storage (separate from the 100 MB GitHub file size
  limit). Requires repo-owner authorization.
- **Build a single-arch APK** with
  `flutter build apk --debug --target-platform android-arm64`
  (drops the universal APK's armv7 + x86_64 + x86 fat-binary
  overhead — the debug APK is normally built for all ABIs).
- **Build with R8/proguard** via
  `flutter build apk --release` (the v0.3 release signing
  shape; user must drop a keystore into
  `android/key.properties` first per CLAUDE.md). This requires
  the v0.3 signing setup.

For now, the v1.4 release artefact is the user-runs step on
the user's machine; the SHA1 + size are recorded in this
section for traceability. The release(v1.4) commit lands when
one of the three options above is chosen.

### 1.5 Optional: v1.4.0 git tag

A `git tag -a v1.4.0 -m "<message>"` at the release commit,
mirroring the `[1.0.0]` / `[1.1.0]` CHANGELOG anchors. Optional
because the project has not used git tags before v1.1i; CLAUDE.md
treats `git push --force` / branch deletes on shared branches as
ask-first, but a tag push to `origin/main` is a non-destructive
new ref. **User decision** required.

### 1.6 Optional: `flutter build appbundle --release` + on-device install

CLAUDE.md gates this with "ask first (touches signing)". The
v1.1i sign-off cited this as the user's hands-on step but the
user has not exercised it. If the user wants a Play-Store-ready
AAB for v1.4, this is the missing piece.

---

## 2. v1.2 deferred / gap-filler items (carried forward from the
##    sub-entries)

These are the items the v1.2 sub-entries explicitly deferred. They
are not blocking v1.2 sign-off, but tracking them here is the
single-source-of-truth.

### 2.1 Strong-mode full-screen launch hardening (v1.2e)

**DONE in v1.3c / Phase 14 / SYS-113 / ADR-043 (probe +
deep-link + reliability wiring).** See
[CHANGELOG.md](CHANGELOG.md) `### v1.3c` block.

**DONE in v1.3d / Phase 15 / SYS-114 / ADR-044 (activity
launch path — Phase 6a proper).** See
[CHANGELOG.md](CHANGELOG.md) `### v1.3d` block. The
deferred "launch path itself" gap is closed: a real
`FullScreenActivity` Kotlin class exists (lockscreen-bypass
flags, `getInitialRoute()` query-string encoding, manifest
declaration with `singleTask` / `taskAffinity=""` /
`excludeFromRecents`), `FullScreenIntentChannel.kt` has
the two launch handlers (`showHabitMission`,
`showRoutineOverlay`), `MainActivity.buildReminderNotification`
splits the strong-mode branch with
`setFullScreenIntent(openPi, true)`, and a chain-level
orchestrator widget (`lib/screens/mission_launcher.dart`)
loads the habit by id from `DoRepository.instance.getById`
and walks the `MissionChain` end-to-end. The routine-fired
overlay path is wired to a new
`lib/screens/routine_overlay_screen.dart` banner widget.
`_safe` wrapper defense-in-depth preserved (ADR-013).

`MainActivity.kt`'s `FullScreenActivity` is described as
"v1.2e-minimal" and needs hardening in a follow-up that adds
`USE_FULL_SCREEN_INTENT` on API 34+ (Phase 6 in the 30-phase
roadmap). The current behavior is best-effort; on Android 14+ the
system can suppress full-screen intents from background-launching
apps without this permission. SYS- ID not yet assigned; ADR
needed.

### 2.2 Action-side permission disambiguation (v1.2h)

The `AutomationReliabilityDialog` (v1.2h) handles **trigger-side**
permissions cleanly. It does not yet handle **action-side**
permissions:

- `ActionOverrideSilent` needs `ACCESS_NOTIFICATION_POLICY` to
  actually change the ringer mode.
- Contact-requiring actions (`ActionNotify` to a person,
  `ActionCallIntercept` on a person, the Japan silent-mode
  routine) need `READ_CONTACTS` to resolve the contact URI.

The dialog should grow a "Action permission" section that shows
the action's required permission (if any) with the same status +
rationale + Open settings CTA treatment. Phase 8+ in the roadmap.

### 2.3 `TriggerCallIncoming*` reliability arm (v1.1f carry-over)

`automation_reliability.dart`'s `_requiredPermissionForTrigger`
maps `TriggerCallIncoming*` → `null` (the badge reads "no gate
required"). v1.1f deferred folding in the `RoleManager` check for
the `ROLE_CALL_SCREENING` role until `PermissionService` exposes
`callScreening` as a first-class `PermissionKind`. The
`PermissionKind.callScreening` enum value is present (v1.2c /
Phase 3) but the `PermissionService` probe for it is still
partially wired. When the probe + dialog arm are complete, the
badge should switch from "no gate" to "optimal / degraded" based
on `RoleManager.isRoleHeld(ROLE_CALL_SCREENING)`.

### 2.4 Spanish translation by a native speaker (v1.1h carry-over)

`lib/l10n/app_es.arb` is a smoke-test locale; the README and the
v1.1h CHANGELOG entry explicitly say "NOT a professional
translation". A v1.2+ follow-up with a native Spanish speaker is
the right path. The ARB catalog is in place; the work is a single
PR that re-translates the ~60 keys and adds 1-2 structural tests
that pin the key-set parity between `app_en.arb` and the
replacement `app_es.arb`.

### 2.5 `google_maps_flutter` for `LocationMapPreview` (v1.1e carry-over)

The current `LocationMapPreview` is a pure `CustomPaint` (no
`INTERNET` permission). The v1.1e CHANGELOG entry says
"v1.2 candidate: swap the `CustomPaint` body for `flutter_map` +
cached tiles + the `INTERNET` permission." This is a product
decision deferred to v1.2+. The current preview is functional
and the app ships without `INTERNET`; the upgrade is opt-in.

### 2.6 Legacy `mipmap-*/ic_launcher.png` regeneration (v1.1i carry-over)

The five legacy density buckets (mdpi, hdpi, xhdpi, xxhdpi,
xxxhdpi) are still the Flutter-default PNGs because the v1.1i
adaptive-icon vectors are only on the API 26+ path. A v1.2
follow-up can regenerate the legacy PNGs from the master
vector (using a build-time `flutter_launcher_icons` invocation or
a one-off `aapt2`-driven rasterization). Optional; the legacy
fallback is the "second-best" path on pre-26 devices, which are
out of v0.1+ scope anyway (`minSdk = 30` as of v1.1i).

### 2.7 Light-theme icon variant (v1.1i carry-over)

The adaptive icon is brand purple + white glyph. AOSP mask is
applied at draw time, so the icon looks correct in both light
and dark themes, but a future product pass might want a
light-mode variant where the background is white and the glyph
is brand purple. Deferred to v1.2+ per the v1.1i CHANGELOG.

### 2.8 B9 — Widget re-arm indicator (v1.2g explicit deferral)

**Shipped in v1.4a (SYS-115 / ADR-045 / WF-042 / Phase 28).**
The project now ships an Android home-screen widget
(`com.doit.DoitWidgetProvider`) that renders the
first-active do's streak + the unified `Reliability`
badge (`ic_widget_optimal` / `ic_widget_degraded` /
`ic_widget_unknown`). The v1.2g deferral is closed — the
"widget re-arm indicator" requirement now has a surface.
The widget is a native `AppWidgetProvider` + `RemoteViews`
over the `doit/widget` MethodChannel (no `home_widget`
pubspec dep); the cold-start fallback uses a
`SharedPreferences` cache so the widget is never blank
between OS process-kill and first Dart frame. See
`docs/v_model/decision_record.md` ADR-045 + `workflows.md`
WF-042 for the long-form rationale and end-to-end flow.
`v1.2g` explicitly deferred B9 ("Android home-widget re-arm
indicator") because the project did not yet ship an Android
home-screen widget. **Closed by v1.4a** (Phase 28 / SYS-115 /
ADR-045 / WF-042 — the widget surface landed with the streak +
"Mark done" affordance, including a re-arm indicator driven by
the reliability badge caption).

---

## 3. v1.2 / v1.3 follow-ups not yet started

### 3.1 Phases 1-4, 6a, 12-30 of the 30-phase roadmap

The 30-phase roadmap is referenced in every v1.2 sub-entry but
not on disk. From the partial references, the unstarted phases
include:

- **Phase 1-4** (v1.2a..v1.2d) — these are the *foundation* phases
  that v1.2e..v1.2m built on top of. The CHANGELOG does not have
  v1.2a..v1.2d entries; they are the `TriggerForegroundApp` leaf
  (v1.2c) and the DST transition banner / streak-recovery card /
  pre-notification heads-up cluster (v1.2d, which is in the
  CHANGELOG as a section but is not the same scope as v1.2j).
  **Verify**: was v1.2c the `TriggerForegroundApp` + `PermissionKind.callScreening`
  commit (`e60597c` in git log)? And v1.2d the `PauseService._ready` +
  `PositionSource.dispose` contract commit (`2a0a5a7`)? If yes, the
  CHANGELOG needs v1.2a..v1.2d entries backfilled (mirrors the v1.0
  / v1.1 backfill pattern from `297f06a`).
- **Phase 6a** — `USE_FULL_SCREEN_INTENT` permission + the
  full-screen-intent reliability policy (related to §2.1 above).
- **Phase 12-30** — out of v1.2 scope. Includes the home widget
  (Phase 28), the iOS port, the Wear OS target, and other
  platform-expansion items.

### 3.2 `30-phase-roadmap.md` source of truth

The roadmap is currently scattered across the CHANGELOG sub-entries.
A single `docs/v_model/v1_2_30_phase_roadmap.md` would close the
doc-side gap and make future milestone scoping faster. This is a
doc-only PR; no code, no tests.

### 3.3 `v1.2_closeout.md` retrospective

The v1.1k retrospective (`docs/v_model/v1_1_handoff_from_v1_0g.md`)
established the pattern. v1.2 deserves the same: a post-mortem on
the 30-phase cycle, what shipped, what slipped, what was learned.
The 4 lessons worth capturing from the v1.2 sub-entries:

- **L1** (v1.2c): service `_ready` eager-complete pattern — the
  `..complete()` constructor in `UsageStatsService` avoids the
  `await init()` call sites that hung in widget-test fake-async.
- **L2** (v1.2g): the V-Model's "right-side gate" is sometimes a
  doc, not a test (B9 was closed by a doc-only CHANGELOG entry
  that explicitly deferred the work).
- **L3** (v1.2i): app-lifecycle re-probe is a *separate* path
  from cold-start probe. `WidgetsBindingObserver` is the
  right shape; the first `resumed` after cold launch is a no-op.
- **L4** (v1.2l): shared `MissionWrongAttempts` module eliminates
  the Math/Type behavior gap. The opt-in pattern (Shake / Hold /
  Memory have no "wrong attempt" notion) is the future-proof
  shape for similar shared modules.

---

## 4. v1 candidate batch (parking lot — still v1 scope)

These items are deferred beyond v1.4 but are explicitly **v1
work** (no v2.0 jump). They are tracked here so they don't get
lost between the v1.4 closeout and the next milestone kickoff.

| ADRs | `docs/v_model/decision_record.md` | up to ADR-052 (9 v1.2 ADRs appended in the closeout PR — ADR-033..ADR-041 covering SYS-098..SYS-110; v1.3 sub-entries appended ADR-042..ADR-044 covering SYS-112..SYS-114; v1.4 sub-entries appended ADR-045..ADR-048 covering SYS-115..SYS-118; v1.4f sub-entry appended ADR-050 covering SYS-120 — widget-side Skip + Undo; v1.4g sub-entry appended ADR-051 covering SYS-121 — widget-action round-trip Kotlin → Dart via the inbound `doit/widget` MethodChannel; v1.4h sub-entry appended ADR-052 covering SYS-122 — per-tile Edit + Delete IconButtons on the in-app home tile); v1.2c/d/e/f/h/i/j/l/m earned ADRs; v1.2g/k did not (doc-only closeout / routine UI affordance respectively) |
| SYS- IDs | `docs/v_model/requirements.md` | v1.2 sub-entries appended SYS-098..SYS-110 (13 IDs); v1.3 sub-entries appended SYS-111..SYS-114 (4 IDs); v1.4 sub-entries appended SYS-115..SYS-118 (4 IDs — home widget, tile streak+Done, tile Skip+budget, tile Undo); v1.4e appended SYS-119 (tile 7-day sparkline); v1.4f appended SYS-120 (widget-side Skip + Undo); v1.4g appended SYS-121 (widget-action round-trip — bidirectional `doit/widget` MethodChannel); v1.4h appended SYS-122 (per-tile Edit + Delete IconButtons on the in-app home tile). v1.2a + v1.2b are doc-only baseline stubs with no SYS- ID (the value classes are consumed by the v1.2f leaves, not asserted as requirements themselves) |
| WF- IDs | `docs/v_model/workflows.md` | v1.2 sub-entries added WF-022, WF-025, WF-030; v1.3 sub-entries added WF-040, WF-041; v1.4 sub-entries added WF-042..WF-046; v1.4f added WF-047 (widget-side Skip + Undo from the home widget); v1.4g added WF-048 (widget action button taps round-trip to Dart's `WidgetService`); v1.4h added WF-049 (Edit or delete a do from the in-app home tile). Cross-check the rest are in `traceability_matrix.md` |

**v1.4i+ follow-up** — Tile + widget surface gaps after
  the v1.4a widget + v1.4b tile streak + v1.4c tile skip
  + v1.4d tile undo + v1.4e tile sparkline + v1.4f widget-side
  Skip + Undo + v1.4g widget-action round-trip + v1.4h per-tile
  Edit + Delete ship: widget
  small / large variants, widget config
  activity, widget list (scrolling), widget deep-link to a
  specific do; rest-day history visualization;
  rest-day budget edit affordance; soft-delete column on
  `habits` so the v1.4h Delete-Undo path can restore streak
  history (v1.4h documented trade-off, per ADR-052 §8).
  See `docs/v_model/plan.md`
  Milestone 12+ for the candidate list (Milestone 11 v1.4
  is shipping in this cycle).

---

## 5. Quick index: where each piece is documented

| Item | Doc | Status |
|---|---|---|
| v1.0 / v1.1 / v1.2a..m + v1.3 + v1.4a..e implementation | `docs/v_model/implementation_status.md` | v1.0..v1.4 fully logged (v1.4a..v1.4e shipped on `main`; v1.4e sub-entry in flight on `feat/v1.4e-tile-sparkline`) |
| v1.0 / v1.1 / v1.2 deferred items | `docs/v_model/plan.md` (Milestone 7-11 sections) | Milestones 7 (v1.0), 8 (v1.1), 9 (v1.2), 10 (v1.3), 11 (v1.4) flipped to `shipped` in the v1.4 sign-off PR |
| 30-phase roadmap | scattered across `CHANGELOG.md` v1.2 sub-entries | needs `v1_2_30_phase_roadmap.md` (see §3.2) |
| ADRs | `docs/v_model/decision_record.md` | up to ADR-049 (4 v1.3 ADRs appended — ADR-042..ADR-044 covering SYS-112..SYS-114 + 5 v1.4 ADRs appended — ADR-045 covering SYS-115 + ADR-046 covering SYS-116 + ADR-047 covering SYS-117 + ADR-048 covering SYS-118 + ADR-049 covering SYS-119) |
| SYS- IDs | `docs/v_model/requirements.md` | v1.2 sub-entries appended SYS-098..SYS-110 (13 IDs); v1.3 appended SYS-111..SYS-114 (4 IDs); v1.4 appended SYS-115..SYS-119 (5 IDs — home widget, tile streak+Done, tile Skip+budget, tile Undo, tile sparkline). v1.2a + v1.2b are doc-only baseline stubs with no SYS- ID (the value classes are consumed by the v1.2f leaves, not asserted as requirements themselves) |
| WF- IDs | `docs/v_model/workflows.md` | v1.2 sub-entries added WF-022, WF-025, WF-030; v1.3 added WF-040, WF-041; v1.4 added WF-042, WF-043, WF-044, WF-045, WF-046. Cross-check the rest are in `traceability_matrix.md` |
| Open questions | `docs/v_model/open_questions.md` | all 21 closed (last closure: v0.5e-fix ADR-017) |
| Spanish translation | `lib/l10n/app_es.arb` + `CHANGELOG.md` v1.1h block | smoke-test only; see §2.4 |
| On-device hands-on | `docs/v_model/v1_4_release_checklist.md` + v0/v1.0/v1.1/v1.2/v1.3 equivalents | `v1_4_release_checklist.md` mirrors the v1.2 / v1.3 shape; user-runs step is §1.4 (release(v1.4) APK commit) |

---

## 6. Recommended next step (single recommendation)

The v1.4 cycle is in closeout. The four v1.4 sub-entries
(v1.4a/b/c/d) are shipped on `main`. The sign-off commit
`chore/v1.4-sign-off` lands the version bump + V-Model docs
(`pubspec.yaml` → `1.4.0+11`, `lib/build_info.dart` mirror,
`test/release_signing_test.dart` pin updates, `CHANGELOG.md`
`## [1.4.0]` block, `implementation_status.md` sign-off row,
`v1_4_release_baseline.md` + `v1_4_release_checklist.md` new
docs, `plan.md` Milestone 11 flipped to `shipped`).

After the sign-off PR lands, the user's hands-on step is the
`release(v1.4)` debug-signed APK commit: `flutter build apk
--debug` (no signing-config touch), record the SHA1 + size in
the commit message (mirrors the v1.1i pattern at `222f860`).
Then optionally tag `v1.4.0`, then optionally
`flutter build appbundle --release` + on-device install.

The v1.4i+ parking lot at `feature.md` §4 has fresh candidates
ready for the next cycle: widget small / large variants, widget
config activity, widget list (scrolling), widget deep-link to a
specific do; rest-day history visualization; rest-day budget edit
affordance; soft-delete column on `habits` so the v1.4h
Delete-Undo path can restore streak history (v1.4h documented
trade-off, per ADR-052 §8). (The v1.4h per-tile Edit + Delete
closure closed the v1.4h+ "in-app tile edit/delete affordance"
item.)
See `docs/v_model/plan.md` Milestone 12+ for the candidate
list.
