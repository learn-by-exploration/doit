# `do it` — feature.md (remaining work)

> Last updated: 2026-06-23.
> Branch: `main` @ `3197b56` (clean working tree, up to date with `origin/main`).
> Test state: 1001/1001 passing. `dart format` clean. `flutter analyze --fatal-infos` clean.
> Version in `pubspec.yaml` / `lib/build_info.dart`: `1.1.0+8`.

This file tracks everything that is **not yet shipped** and is not
already covered by the V-Model docs (`docs/v_model/plan.md`,
`implementation_status.md`, `decision_record.md`, `open_questions.md`,
`CHANGELOG.md`). It is the single place to look when picking the next
piece of work.

---

## 1. Ship blockers (must finish before closing the v1.2 cycle)

### 1.1 Resolve the v1.2l / v1.2m CHANGELOG merge conflict

`CHANGELOG.md` lines 1206-1303 contain an unresolved
`<<<<<<< HEAD` / `=======` / `>>>>>>> origin/main` conflict that was
introduced when v1.2l and v1.2m landed in the same merge. Both PRs
closed cleanly on `main` (their commits `6f83d47` and `8b3f83e` are
present, and 1001/1001 tests pass), but the CHANGELOG section that
*describes* them was committed in conflict. The conflict must be
resolved in a follow-up commit (or the entries merged into one
coherent block). The right resolution is:

- Keep both `### v1.2m` (Phase 11c) and `### v1.2l` (Phase 11b)
  sections with their full bodies.
- Replace the `<<<<<<<< / ======== / >>>>>>>>` markers with a clean
  sequence of `### v1.2l` then `### v1.2m` (the existing
  alphabetic order in the file is `m` before `l` because the
  v1.2l entry sits at the end of `[Unreleased]` chronologically —
  the order matters for keep-a-changelog: newest first).
- Drop both `Formatted X files (0 changed)` and `flutter test`
  3-gate blocks; keep one consolidated block at the end of the
  v1.2 cycle (after Phase 11c).

This is a **doc-only** change; no tests, no analyzer risk.

### 1.2 Bump version to v1.2.0

The v1.2 cycle has shipped 9 sub-entries (v1.2e..v1.2m) but the
project is still on `1.1.0+8`. Two things must move together:

- `pubspec.yaml` line: `version: 1.1.0+8` → `version: 1.2.0+9`.
- `lib/build_info.dart`: `kAppVersion = '1.1.0'` → `'1.2.0'`,
  `kAppVersionCode = 8` → `9`.
- `test/release_signing_test.dart` mirror-pin assertions (the
  four pubspec / build_info agreement tests at lines 223-260) need
  the new values in lockstep.
- CHANGELOG: a new `## [1.2.0] — 2026-06-23 — Code-TODO closure`
  block summarizing the v1.2 cycle (routines: Phase 5, 6, 7, 8,
  9, 10, 11a, 11b, 11c).

SYS- IDs added: SYS-098 (alarm fire → notification render path,
v1.2e), SYS-099 (ActionFullscreen wiring, v1.2f), SYS-100
(ActionCallIntercept wiring, v1.2f), SYS-101 (Person pauseUntil,
v1.2f), SYS-102 (DoFixed weekday display, v1.2f), SYS-103
(AutomationReliabilityDialog on tap, v1.2h), SYS-104
(PermissionLifecycleReProbe + `PermissionService.refresh()`,
v1.2i). The implementation_status.md table needs a v1.2 row per
PR, mirroring the v1.0 / v1.1 shape.

### 1.3 Add `docs/v_model/v1_2_release_baseline.md` and `v1_2_release_checklist.md`

Every previous milestone has both a left-side baseline and a
right-side checklist (v0_1..v0_5, v1_0, v1_1). v1.2 has neither.
The 30-phase roadmap referenced in the CHANGELOG entries is not
on disk. The minimum viable pair:

- `v1_2_release_baseline.md` — left-side: scope, the 30 phases
  with their status (Phases 5, 6b-6e, 7, 8, 9, 10, 11a, 11b, 11c
  closed; Phases 1-4, 6a, 12-30 explicitly out-of-scope or
  deferred), the deferred items table (Spanish translation by
  native speaker; `google_maps_flutter` decision; legacy PNG
  regeneration; light-theme icon variant; `USE_FULL_SCREEN_INTENT`
  on API 34+).
- `v1_2_release_checklist.md` — right-side gate: the on-device
  checks listed in the v1.2 sub-entries (delete-confirm flow,
  pause UI cycle, automation reliability dialog, 3-wrong
  take-a-break, DST banner, completion-log undo, pre-notification
  heads-up).

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

`v1.2g` explicitly deferred B9 ("Android home-widget re-arm
indicator") because the project does not yet ship an Android
home-screen widget. Tracking this in the v1.x batch
(see §4 — the home widget is Phase 28 in the 30-phase roadmap).
No work in v1.2.

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

- **v1.x** — Home screen widget (Phase 28 of the 30-phase
  roadmap). The widget is the missing primary surface; the
  reliability design (WF-038) was scoped for it but the widget
  itself is not yet built.
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
| v1.0 / v1.1 / v1.2a..m implementation | `docs/v_model/implementation_status.md` | v1.0..v1.1 fully logged; v1.2 sub-entries need rows appended (mirrors the v1.0/v1.1 backfill pattern) |
| v1.0 / v1.1 / v1.2 deferred items | `docs/v_model/plan.md` (Milestone 7-9 sections) | Milestone 7 (v1.0) shipped; 8 (v1.1) shipped; 9 (v1.2) needs the milestone block flipped to "shipped" once §1.2 + §1.4 land |
| 30-phase roadmap | scattered across `CHANGELOG.md` v1.2 sub-entries | needs `v1_2_30_phase_roadmap.md` (see §3.2) |
| ADRs | `docs/v_model/decision_record.md` | up to ADR-032; v1.2 sub-entries need ADRs-033..041 appended for SYS-098..104 |
| SYS- IDs | `docs/v_model/requirements.md` | v1.2 sub-entries appended SYS-098..104; v1.2a..v1.2d SYS- IDs need to be traced and appended (Phase 1-4 items) |
| WF- IDs | `docs/v_model/workflows.md` | v1.2 sub-entries added WF-022, WF-025, WF-030; cross-check the rest are in `traceability_matrix.md` |
| Open questions | `docs/v_model/open_questions.md` | all 21 closed (last closure: v0.5e-fix ADR-017) |
| Spanish translation | `lib/l10n/app_es.arb` + `CHANGELOG.md` v1.1h block | smoke-test only; see §2.4 |
| On-device hands-on | none on disk | v0.5e / v1.0h / v1.1k / v1.1h all reference a "user runs ..." step but there is no checklist doc — see §1.6 |

---

## 6. Recommended next step (single recommendation)

Resolve the CHANGELOG conflict (§1.1), then bump the version +
add v1.2a..v1.2d CHANGELOG backfill rows + add the v1.2 rows to
`implementation_status.md` + add the v1.2 baseline + checklist
docs (§1.3) in a single doc-only PR. The format commit
(`3197b56`) is already on main. After the doc PR lands, the
release build (§1.4) and tag (§1.5) are mechanical. The
on-device install (§1.6) is a user step.

This sequence keeps the v1.2 cycle audit-clean: every code PR
landed with its CHANGELOG entry, every v1.2 sub-entry has an
implementation_status.md row, the milestone block in plan.md is
flipped to "shipped", and the release artefact is the single
sign-off line.
