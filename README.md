# Streak

A personal, local-first Android habit and relationship app. Reminds you to do
the small things — drink water, call Mom, run the morning routine — with the
same level of stubbornness as Alarmy, and tracks your streaks honestly.

This workspace follows the same V-model development path used by
[`../board_box`](../board_box) and [`../card_box`](../card_box). Requirements
map to architecture, implementation, and verification, with explicit
artifacts on each side of the V.

## Why this app

Existing habit apps let you tap "done" without doing the thing. Existing
contact apps remind you to call people but never insist. Streak fuses the
two:

- **Habits** with three proof modes: soft (one-tap), strong (mission
  required), auto (interval window).
- **People** with per-person call/message cadence.
- **Anchored routines** (after wake-up, after workout) so the morning
  unfolds in order.
- **Local-first.** Your data never leaves the phone.
- **Strong reminders** via full-screen intents, exact alarms, and a chain of
  missions when you try to dismiss.

## Current direction

- Tech stack: Flutter (matching `board_box` / `card_box`).
- Target: Android only for v0.1. iOS is a v0.2+ candidate.
- User model: single user, single device, personal use.
- No cloud. No telemetry. No account.
- Auto local backup to a user-chosen folder.

## Documents

The V-model artifacts live in [`docs/v_model/`](docs/v_model/):

- [V-model plan](docs/v_model/plan.md)
- [Concept of operations](docs/v_model/conops.md)
- [Operational workflows](docs/v_model/workflows.md)
- [System requirements](docs/v_model/requirements.md)
- [v0.1 requirements baseline](docs/v_model/v0_1_baseline.md)
- [Architecture options](docs/v_model/architecture_options.md)
- [Decision record](docs/v_model/decision_record.md)
- [Traceability matrix](docs/v_model/traceability_matrix.md)
- [Open questions](docs/v_model/open_questions.md)
- [Implementation status](docs/v_model/implementation_status.md)
- [Mission catalog](docs/v_model/mission_catalog.md)
- [Notification reliability](docs/v_model/notification_reliability.md)
- [Changelog](CHANGELOG.md) — user-facing summary of every release; lives next to the README by convention.

## Status

Implementation in flight. v0.1 is feature-complete and the 14-day real-device
run is running on the user's primary phone; v0.2 (events, groups, time
windows, edit, pause, test reminder, bulk complete) is also in flight on the
same phone. See [`docs/v_model/implementation_status.md`](docs/v_model/implementation_status.md)
for the current slice. The v0.3 sideload-to-friends release plan is at
[`docs/v_model/v0_3_release_baseline.md`](docs/v_model/v0_3_release_baseline.md).
