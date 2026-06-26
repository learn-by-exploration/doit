# `do it` — feature.md (remaining work)

> Last updated: 2026-06-23.
> Branch: `main` @ `acf9c32` (clean working tree, up to date with `origin/main`).
> Test state: 1001/1001 passing. `dart format` clean. `flutter analyze --fatal-infos` clean.
> Version in `pubspec.yaml` / `lib/build_info.dart`: `1.2.0+9`.

This file tracks everything that is **not yet shipped** and is not
already covered by the V-Model docs (`docs/v_model/plan.md`,
`implementation_status.md`, `decision_record.md`, `open_questions.md`,
`CHANGELOG.md`). It is the single place to look when picking the next
piece of work.

---

## 1. Ship blockers (must finish before closing the v1.2 cycle)

### 1.1 ✅ DONE — Resolved the v1.2l / v1.2m CHANGELOG ordering + merge conflict

`CHANGELOG.md` `[Unreleased]` block now has the 9 v1.2
sub-entries (v1.2e..v1.2m) in clean alphabetic order
(e, f, g, h, i, j, k, l, m). The pre-existing `<<<<<<<< /
======== / >>>>>>>>` markers at the v1.2l/v1.2m junction are
gone (the duplicate 3-gate blocks are collapsed into a single
consolidated block). The `## [1.2.0]` summary block points
to the 9 entries. v1.2c + v1.2d remain tracked only in
`implementation_status.md` (they shipped via PRs #5 / #6
without `CHANGELOG.md` updates — a known gap, retro-fix
deferred per the v1.1h backfill precedent). Closed in the
v1.2 closeout PR (`acf9c32`).

### 1.2 ✅ DONE — Bumped version to v1.2.0

`pubspec.yaml` is at `1.2.0+9`. `lib/build_info.dart` mirrors
(`kAppVersion = '1.2.0'`, `kAppVersionCode = 9`).
`test/release_signing_test.dart` mirror-pin assertions updated
in lockstep (commit `8684a6e`). `CHANGELOG.md` has the new
`## [1.2.0] — 2026-06-23 — Code-TODO closure` summary block.
`implementation_status.md` has 13 v1.2 rows + the sign-off row
(mirrors the v1.0 / v1.1 shape). `requirements.md` has
SYS-098..SYS-110 appended. `decision_record.md` has
ADR-033..ADR-041 appended. Closed in the v1.2 closeout PR
(`acf9c32`).

### 1.3 ✅ DONE — Added `v1_2_release_baseline.md` + `v1_2_release_checklist.md`

Both docs are on disk and current:

- `docs/v_model/v1_2_release_baseline.md` (181 lines) —
  left-side baseline: scope, the 30-phase roadmap status
  table, the SYS-098..SYS-110 requirements table (matches
  `requirements.md`), the ADR-033..ADR-041 decisions table,
  the deferred-items table (Phase 6a / action-side permission
  disambiguation / `TriggerCallIncoming*` arm / native Spanish
  translator / `google_maps_flutter` / legacy PNG
  regeneration / light-theme icon / B9 widget re-arm / Phases
  12-30), the no-new-permissions / no-`INTERNET` confirmation,
  and the version-bump section.
- `docs/v_model/v1_2_release_checklist.md` — right-side gate:
  pre-flight mechanical checks, build + install steps (user's
  hands-on), per-sub-entry on-device verification, regression
  checks (re-runs the v1.1k checks), and the new SYS- exit
  criteria table that maps every SYS-098..SYS-110 to its
  test files + on-device check.

Closed in the v1.2 closeout PR (`acf9c32`).

### 1.4 Commit a `release(v1.2)` debug-signed APK

`v1.1i` shipped as `222f860` (debug-signed APK, 75.1 MB, SHA1
`c3e0f6c6`). v1.2 needs the same pattern: `flutter build apk
--debug` (no signing-config touch), record the SHA1 + size in a
`release(v1.2)` commit that mirrors the v1.1i sign-off shape. This
is a build artefact, not a code change.

### 1.5 Optional: v1.2.0 git tag

A `git tag -a v1.2.0 -m "<message>"` at the release commit,
mirroring the `[1.0.0]` / `[1.1.0]` CHANGELOG anchors. Optional
because the project has not used git tags before v1.1i; CLAUDE.md
treats `git push --force` / branch deletes on shared branches as
ask-first, but a tag push to `origin/main` is a non-destructive
new ref. **User decision** required.

### 1.6 Optional: `flutter build appbundle --release` + on-device install

CLAUDE.md gates this with "ask first (touches signing)". The
v1.1i sign-off cited this as the user's hands-on step but the
user has not exercised it. If the user wants a Play-Store-ready
AAB for v1.2, this is the missing piece.

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

These items are deferred beyond v1.2 but are explicitly **v1
work** (no v2.0 jump). They are tracked here so they don't get
lost between the v1.2 closeout and the next milestone kickoff.

_(Home-screen widget item removed in v1.4a — shipped as
SYS-115 / ADR-045 / WF-042. See §2.8 above.)_
- **v1.x** — iOS port. v0.1 + v1.0 are Android-only; the
  `lib/habits/` + `lib/people/` + `lib/missions/` model layer
  is already pure Dart and would port cleanly. The Kotlin side
  (`lib/reminders/`, `lib/services/platform_*`) is the bulk of
  the port work. A v1.x port keeps the project on a single
  version track and lets iOS users land on the same
  `RoutineConfig` / `Person.pausedUntil` / reliability-badge
  work that v1.2 has shipped on Android.
- **v1.x** — Wear OS target. Same v1-versioning reasoning —
  ships as a v1.x point release, not a v2.0 milestone.
- **v1.x** — Backup encryption upgrade from PBKDF2-HMAC-SHA256
  (100k iterations) to Argon2id or a higher PBKDF2 round count,
  in line with current OWASP guidance. The change is
  backwards-compatible reads-from-v1 (per the v0.4c.1
  precedent) so it can land as a v1.x point release without
  forcing a v2.0.
- **v1.x** — Backup format v2 → v3 to support new fields added
  across v1.x (RoutineConfig, Person.pausedUntil, the
  v1.1f/v1.2h reliability badge states, etc.). Same
  backwards-compat-reads-from-v1 pattern; v1.x point release.

---

## 5. Quick index: where each piece is documented

| Item | Doc | Status |
|---|---|---|
| v1.0 / v1.1 / v1.2a..m implementation | `docs/v_model/implementation_status.md` | v1.0..v1.2 fully logged; 13 v1.2 rows + sign-off row appended (v1.2a + v1.2b are doc-only stubs, v1.2c..v1.2m are code commits) |
| v1.0 / v1.1 / v1.2 deferred items | `docs/v_model/plan.md` (Milestone 7-9 sections) | Milestones 7 (v1.0), 8 (v1.1), and 9 (v1.2) all shipped; the v1.2 closeout PR flipped Milestone 9 to "shipped" with closing date 2026-06-23 |
| 30-phase roadmap | scattered across `CHANGELOG.md` v1.2 sub-entries | needs `v1_2_30_phase_roadmap.md` (see §3.2) |
| ADRs | `docs/v_model/decision_record.md` | up to ADR-045 (9 v1.2 ADRs appended in the closeout PR — ADR-033..ADR-041 covering SYS-098..SYS-110; v1.3 sub-entries appended ADR-042..ADR-044 covering SYS-112..SYS-114; v1.4a appended ADR-045 covering SYS-115); v1.2c/d/e/f/h/i/j/l/m earned ADRs; v1.2g/k did not (doc-only closeout / routine UI affordance respectively) |
| SYS- IDs | `docs/v_model/requirements.md` | v1.2 sub-entries appended SYS-098..SYS-110 (13 IDs); v1.3 sub-entries appended SYS-111..SYS-114 (4 IDs); v1.4a appended SYS-115 (1 ID — the home widget). v1.2a + v1.2b are doc-only baseline stubs with no SYS- ID (the value classes are consumed by the v1.2f leaves, not asserted as requirements themselves) |
| WF- IDs | `docs/v_model/workflows.md` | v1.2 sub-entries added WF-022, WF-025, WF-030; v1.3 sub-entries added WF-040, WF-041; v1.4a appended WF-042 (home widget). Cross-check the rest are in `traceability_matrix.md` |
| Open questions | `docs/v_model/open_questions.md` | all 21 closed (last closure: v0.5e-fix ADR-017) |
| Spanish translation | `lib/l10n/app_es.arb` + `CHANGELOG.md` v1.1h block | smoke-test only; see §2.4 |
| On-device hands-on | none on disk | v0.5e / v1.0h / v1.1k / v1.1h all reference a "user runs ..." step but there is no checklist doc — see §1.6 |

---

## 6. Recommended next step (single recommendation)

The v1.2 closeout doc-only PR (`acf9c32`) has landed. The
remaining v1.2 work is the user's hands-on step: §1.4
(commit a `release(v1.2)` debug-signed APK mirroring the
v1.1i pattern at `222f860`), then §1.5 (optionally tag
`v1.2.0`), then §1.6 (optionally build + install the
`app-release.aab` on the emulator). After those, the v1.2
cycle is fully closed and the next milestone kickoff can pick
from §2-4.

This sequence keeps the v1.2 cycle audit-clean: every code PR
landed with its CHANGELOG entry (with the documented v1.2c/d
gap), every v1.2 sub-entry has an `implementation_status.md`
row, the milestone block in `plan.md` is flipped to "shipped",
the new baseline + checklist docs are on disk, and the
release artefact is the single sign-off line.
