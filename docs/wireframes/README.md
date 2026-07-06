# do it — Wireframe Slideshow

A single-page slideshow player that renders every wireframe in
`docs/wireframes/` inside an `<iframe>` at the canonical
**412 × 892** Android viewport. Built for design reviews,
walkthroughs, and cross-team sharing — no build step, no
CDN, no dependencies. Just open `index.html` in a browser.

The full inventory lives in
[`INVENTORY.md`](./INVENTORY.md); captions in the player are
paraphrased from that document.

---

## How to open

### macOS / Linux

```bash
xdg-open docs/wireframes/index.html        # Linux
open docs/wireframes/index.html            # macOS
```

### Windows

```cmd
start docs\wireframes\index.html
```

### Any platform (drag-and-drop)

Drag `docs/wireframes/index.html` onto any modern browser
window (Chrome, Firefox, Safari, Edge).

> **Note:** No web server is required. The player loads every
> wireframe via relative `iframe src=` (e.g.
> `W01-home-populated.html`). As long as `index.html` sits
> next to the `W*.html` files in the same folder, the
> references resolve.
>
> If your browser blocks local file access in iframes
> (some Chrome configurations), either:
> - serve the folder with a one-liner static server:
>   ```bash
>   python3 -m http.server 8000 --directory docs/wireframes
>   # then visit http://localhost:8000/
>   ```
> - or launch Chrome with `--allow-file-access-from-files`.

---

## Auto-advance timing

| Setting | Value |
|---|---|
| Base interval | **8 seconds** per wireframe |
| Loop | Wraps from W38 back to W01 |
| Pause | Any user navigation pauses autoplay; press **Space** to resume |
| Restart | The **Restart** button (or **R** key) jumps to W01 |

The active countdown is visible on both sides of the
progress bar:

```
[time remaining] ······ [time elapsed]
       6.4s                  1.6s
```

---

## Keyboard shortcuts

| Key | Action |
|---|---|
| `Space` | Play / Pause |
| `←` | Previous wireframe |
| `→` | Next wireframe |
| `R` | Restart (jump to W01) |
| `F` | Toggle fullscreen |

Shortcuts are suppressed while focus is in a text input (so
typing in a future caption-edit field doesn't trigger nav).

---

## Speed control

Three speeds, top-right of the bottom controls:

- **0.5x** — 16 s/wireframe (slower, for design critique)
- **1x** — 8 s/wireframe (default)
- **2x** — 4 s/wireframe (faster skim)

The active speed is highlighted. Speed changes apply on the
next tick (no jump-cut mid-slide).

---

## What it looks like

```
┌──────────────────────────────────────────────────────────────┐
│  do it — Wireframes · v1.4-stab · 38 surfaces                │
│                                                              │
│   [◄ Prev]  [▶ Play]  [► Next]   03 / 38                    │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌──────────────────────┐                                   │
│   │                      │                                   │
│   │   412 × 892 iframe   │                                   │
│   │     (the phone)      │                                   │
│   │                      │                                   │
│   └──────────────────────┘                                   │
│                                                              │
│   W03 — Per-tile Skip / Undo / Done actions                  │
│   Three trailing-row actions that mutate the completion      │
│   log and the rest-day budget on a single tile.              │
│   [A · Habit lifecycle]  [W03-per-tile-skip-undo-done.html]  │
│                                                              │
│   ━━━━━━━━━━━░░░░░░░░░░░░░░░░  32%                           │
│   5.4s                                          2.6s         │
│                                                              │
│   [↻ Restart]    [0.5x | 1x | 2x]    [⛶ Full]                │
└──────────────────────────────────────────────────────────────┘
```

---

## Full list of wireframes (with captions)

The captions are paraphrased from
[`INVENTORY.md`](./INVENTORY.md); see that file for the full
source-of-truth visual elements, states, SYS / WF / ADR
cross-references.

### Group A — Habit lifecycle (W01–W10)

| ID | Title | Caption |
|---|---|---|
| **W01** | Home (populated) | One screen per active habit; the home tile is the canonical unit of habit interaction. Shows reliability banner, routine drainer, DST banner, streak-recovery card, and per-tile Skip / Undo / Done / Edit / Delete actions. |
| **W02** | Add / Edit habit | The single source of truth for the habit schedule engine + automation wiring. Form sections cover name, category, icon, schedule (Fixed / Interval / Anchor / Day-of-X / Time-Window), routines, rest-day budget, pause, and the edit-only completion-log section. |
| **W03** | Per-tile Skip / Undo / Done actions | Three trailing-row actions that mutate the completion log and the rest-day budget on a single tile. Done is idempotent; Skip consumes from the rest-day budget and shows a SnackBar on exhaustion; Undo reverses today's completion within a 4-second window. |
| **W04** | Per-tile Edit / Delete actions | Per-tile discoverability gap closure. Edit opens the habit form pre-populated; Delete soft-deletes to a tombstone with an Undo SnackBar so completion history survives a Restore. |
| **W05** | 14-day Sparkline visualization | At-a-glance completion rhythm per habit. 14 color-coded dots (emerald done, grey empty, amber skipped, primary today) rendered inline on every home tile. |
| **W06** | Rest-day budget picker dialog | Shared slider dialog (0..31) used by both the home tile budget caption and the add-habit form row. Per-habit, default 2 per calendar month. |
| **W07** | Icon picker (8×8 grid) | Draggable bottom sheet with 64 Material icons across 8 thematic rows (physical, mind, relational, productivity, home, discipline-recovery, food, exercise). Single source of truth for which icon represents a habit. |
| **W08** | Category chip + swatch picker | Rounded category chip with color swatch override. The only file in the app that bridges the pure-Dart `DoCategory` enum to a Flutter `Color`. |
| **W09** | Completion-log edit section | Edit-screen recovery path — undo an accidental completion without leaving the form. Up to 30 rows of date / time / source with per-row delete and an overflow message for hidden entries. |
| **W10** | Streak recovery card | One-shot home surface for 3+ missed days. Tertiary-container banner with a "I'm back" CTA that fast-paths the user back into the habit on the next slot. |

### Group B — People + Cadence (W11–W14)

| ID | Title | Caption |
|---|---|---|
| **W11** | Add / Edit person | A person is the cadence habit anchor for relational triggers. Form covers name, channel (Phone / WhatsApp / Telegram / Signal / SMS), handle, cadence shape, routines, pause, and a contact picker gated by the on-demand permission sheet. |
| **W12** | Person groups (rotation) | Multi-person cadence (e.g. "call one of these 4 every Sunday"). Each group has a semantic (rotation / any / all) and a per-group cadence chip; tap to drill into members. |
| **W13** | Per-person routines section | Same routine wiring as habit routines, scoped to person triggers (e.g. inbound call → silent). Per-automation row shows an AutomationReliabilityBadge trailing. |
| **W14** | Contact picker bottom sheet | Bridge from the Add-person form to the OS-level contact list. Single-select result returns a PersonResolver snapshot (display name, lookup key, channel handle). |

### Group C — Events (W15–W17)

| ID | Title | Caption |
|---|---|---|
| **W15** | Add / Edit event | An event is a date-anchored cadence habit with optional calendar triggers. Form: title, date, time, lead-time slider (0..14 days), repeat (None / Annually), routines summary. |
| **W16** | Events list (upcoming + past) | Surface for date-anchored reminders. Two sections (Upcoming / Past) plus an archived tier. Per-row archive and delete IconButtons. |
| **W17** | Calendar-event routine | Routine trigger that fires on inbound Android calendar events (READ_CALENDAR permission gate). Bottom sheet with multi-select of upcoming events. |

### Group D — Missions (W18–W23)

| ID | Title | Caption |
|---|---|---|
| **W18** | Shake-N mission | Strong-mode proof that requires physical motion. Consumes the sensors_plus accelerometer stream; debounced shake detector advances a live counter toward N. |
| **W19** | Type-phrase mission | Strong-mode proof that requires cognitive engagement. User must type a target phrase exactly; 3 wrong attempts lock out the mission. |
| **W20** | Hold-tap mission | Strong-mode proof that requires sustained attention. Circular timer fills over N seconds; releasing early resets the progress. |
| **W21** | Math mission | Strong-mode proof that requires arithmetic. Numeric answer field against a seeded problem; 3 wrong attempts lock out the mission. |
| **W22** | Memory mission | Strong-mode proof that requires working memory. Tap-to-flip grid of cards; matched pairs stay face-up; win when all pairs are matched. |
| **W23** | Mission chain launcher | Routes to the 5 mission UIs via the sealed `Mission` switch and runs the chain executor. Stepper ("Step 2 of 3"), per-mission timeout honored by the chain, failed-at aborts the rest. |

### Group E — Routines (W24–W25)

| ID | Title | Caption |
|---|---|---|
| **W24** | Routine apply (templates #17–#21) | Generic apply UX for the 5 routine templates (location / calendar / device-state / time-of-day / usage-stats). Form sections scoped to the trigger kind with Enable toggle and Save / Update / Delete action row. |
| **W25** | Japan silent-mode call-screening routine (#16) | Specialised template #16 — the canonical Phase F reference template. When a selected contact calls, switch to Normal / Vibrate / Silent. |

### Group F — Reliability + Permissions (W26–W28)

| ID | Title | Caption |
|---|---|---|
| **W26** | Reliability banner (home + settings) | App-wide alarm-system reliability banner. errorContainer strip with "Reminders may be late. Tap to fix." Hidden when reliability is optimal. |
| **W27** | On-demand permission sheet | Single on-demand permission gate. Every feature that requires a runtime permission calls `PermissionSheet.show(context, kind)` first. Handles 9 PermissionKind cases with rationale + Allow + Open-settings. |
| **W28** | Per-automation reliability badge + dialog | Per-routine reliability diagnostic. Visual sibling of the ReliabilityBanner but scoped to one automation; dialog surfaces Trigger-side and Action-side permission sections. |

### Group G — Settings + Backup (W29–W31)

| ID | Title | Caption |
|---|---|---|
| **W29** | Settings | The catch-all system-preferences surface. Sections: Appearance, Anchor, Permissions, Reliability, DeviceState, Stats, Backup (restore + recently-deleted entries), About. |
| **W30** | Restore from backup | SAF-backed destructive restore. 5-state machine: idle / picking / picked / restoring / restored. Confirms with a replace-all dialog before clobbering local data. |
| **W31** | Recently deleted (tombstones) | v1.4-stab-H deferred UI surface for the v1.4l tombstone column. List of soft-deleted habits with title + deletion date + restore + delete-forever trailing. |

### Group H — Widget + Stats + Templates (W32–W36)

| ID | Title | Caption |
|---|---|---|
| **W32** | Android home-screen widget | Widget-side Kotlin ↔ Dart round-trip plus per-instance widget config and body-tap deep-link. RemoteViews tile shows name, streak, and Done / Skip actions. |
| **W33** | Stats screen | Materialised stats queries cached for 5 seconds. Per-category bucket with 30-day completion rate, 7-day bars chart, and per-habit streak badge. |
| **W34** | Templates gallery (25 templates) | Curated templates the user can clone: 12 do + 3 person + 4 event + 6 routine. 5 filter chips (All / Do / Event / Person / Routine) over a 2-column GridView of Cards. |
| **W35** | Device-state live row | Diagnostic ListTile that reflects the current `DeviceStateSnapshot` published by `DeviceStateService`. Battery / headphones / screen state with HH:MM:SS trailing timestamp. |
| **W36** | DST transition banner | One-shot surface for clock-change drops. Lists each habit whose `nextOccurrence` silently rescheduled (e.g. "Meditate → 07:00") with a "Reschedule now" CTA. |

### Group I — Onboarding (W37–W38)

| ID | Title | Caption |
|---|---|---|
| **W37** | Onboarding (5 permission steps) | First-launch 5-step permission walk: Notifications, Contacts, ExactAlarms, BackupFolder, CallScreening. Step indicator dots; Skip link top-right; Allow FilledButton per step. |
| **W38** | Anchor mode + theme (final onboarding) | The two preference picks that close onboarding. Anchor mode (Manual / First unlock / Either) and theme (Dark / Light / System) via SegmentedButtons with a Get-started FilledButton CTA. |

---

## Behavior summary

| Spec | Implementation |
|---|---|
| List ALL wireframes (every `W*.html`) | 38 entries registered in `WIREFRAMES` (W01–W38); missing files surface as iframe errors. |
| Render in `<iframe>` at **412 × 892** | `.phone-frame` is a fixed 412 × 892 box with a 6px device bezel. |
| Top nav: prev / play-pause / next / counter | `.controls-top` with `Prev`, `Play/Pause`, `Next`, and `NN / Total` counter. |
| Caption strip: title + 1-2 sentence explanation | `.caption` block, title from `<title>` of each `W*.html`, body paraphrased from `INVENTORY.md`. |
| Auto-advance every **8s** | `BASE_INTERVAL_MS = 8000`; `requestAnimationFrame` loop gated on `state.playing`. |
| Pauses on user navigation | `prev()` / `next()` / progress-bar seek call `pause()` and show a "Auto-advance paused" toast. |
| Loops at end | `tick()` checks `idx === length - 1` and wraps to 0. |
| Keyboard: Space, ←, → | `keydown` listener with a guard for text inputs. |
| Progress bar at bottom | Full-width track with `progressBar` fill + click-to-seek. |
| Speed: 0.5x / 1x / 2x | `.speed-group` buttons; sets `state.speed`, resets tick anchor. |
| Dark theme matching wireframes | Same Material 3 dark surface palette as the wireframes themselves. |
| Centered on desktop | `body` is a flex column with `align-items: center`; max-width 980px on the header. |

---

## Implementation notes

- **No CDN, no external assets.** All CSS and JS is inline.
  The page works fully offline.
- **No build step.** Save and refresh. Reorder wireframes by
  editing the `WIREFRAMES` array near the top of the inline
  `<script>`.
- **Title source.** Each wireframe's display title comes from
  the `<title>` element inside the `W*.html` file. The
  player's title-prefix (`W03 — …`) is derived from the
  registry key, not the iframe document.
- **Caption source.** Captions are paraphrased from
  [`INVENTORY.md`](./INVENTORY.md) and embedded as a JS
  object literal. To re-sync with a new INVENTORY, edit the
  `WIREFRAMES` array (each entry has `id`, `file`, `title`,
  `group`, `caption`).
- **Sandboxing.** The `<iframe>` runs with
  `sandbox="allow-same-origin allow-scripts"` so wireframe
  JS (slider handlers, etc.) still works while keeping the
  parent page safe.
- **Accessibility.** All buttons have `aria-label`s; the
  progress bar exposes `role="progressbar"` with live
  `aria-valuenow`; `prefers-reduced-motion` disables
  transitions.

---

*Last updated: 2026-07-06.*