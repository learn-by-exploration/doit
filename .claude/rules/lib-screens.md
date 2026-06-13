# `lib/screens/**` — UI layer

## Pattern

- All screens are `StatefulWidget`. A screen that reads from
  a service and rebuilds on changes is a `StatefulWidget` that
  listens to a `ChangeNotifier` or a `ValueNotifier`.
- A screen that does not read from a service and does not
  change is a `StatelessWidget` (rare in this app).
- A `StatefulWidget`'s `initState` registers listeners; its
  `dispose` unregisters them. A lint check catches
  listener-leaks.

## Async initialization

- A screen that needs to load data uses `FutureBuilder` or
  subscribes to a service stream.
- The screen shows a `CircularProgressIndicator` (or a
  skeleton placeholder) while loading, never an empty
  container.
- A failed load shows a `Retry` button with a clear error
  message.

## Touch targets

- Every interactive element is ≥ 48dp × 48dp.
- The mission UI's primary action button is ≥ 64dp to
  encourage confident tapping.
- The "Done" button on the home widget is ≥ 56dp.

## Accessibility

- Every interactive element has a `Semantics` label.
- The mission UI has full TalkBack labels:
  - Shake-N: "Shake detected: <N> of <target>".
  - Type phrase: "Type the phrase to confirm".
  - Hold-tap: "Hold to confirm, <N> of <target> seconds".
  - Math: "Math problem, <problem>. Type the answer."
  - Memory: "Memory game, <N> of <pairs> pairs matched".
- Every screen has a `Scaffold` with a `Material` ancestor
  so the TalkBack focus tree is correct.
- Color contrast: ≥ 4.5:1 for body text, ≥ 3:1 for large
  text and icons.

## State management

- Use `Provider` (or `ChangeNotifier` directly) for screens
  that need to read from a service. Decision: stick with
  `provider` (de-facto Flutter standard, matches
  `board_box`).
- The home screen subscribes to `HabitRepository` and
  `StreakService` via `Consumer` or `context.watch`.
- The mission screen is local state only; it does not need
  a provider.

## Theming

- Use the app's `ThemeData`, not ad-hoc styles.
- The dark theme is the default. The light theme is opt-in
  in settings.
- Colors and text styles come from `Theme.of(context)`, not
  hardcoded.

## Forbidden patterns

- No `print()`. Use `debugPrint` behind `kDebugMode`.
- No `setState` outside the widget's `State`. (Lint:
  `invalid_use_of_protected_member`.)
- No platform calls in widgets. Go through services.
- No raw `AlarmManager`, `ContactsContract`, or sensor API
  in widgets. Go through `lib/reminders/`, `lib/people/`,
  `lib/missions/`.
- No `Future` ignored without an explicit `unawaited(...)`
  reason. (Lint: `unawaited_futures`.)
- No deep widget trees (> 6 levels of `Widget` nesting).
  Extract a sub-widget.

## Tests

- One widget test per screen, minimum.
- The widget test covers: pump-and-tap the happy path, the
  error path, and the loading path.
- Use `tester.runAsync` for any screen that uses a real
  `Future` (e.g., `shared_preferences`).
- Use `tester.pump()`, **never** `pumpAndSettle()` after a
  drag (scroll physics loops forever).
- 80%+ coverage on changed files.

## When changing this folder

- Update the matching SYS- IDs in
  [`docs/v_model/requirements.md`](../../docs/v_model/requirements.md).
- If a screen changes the user-facing copy for a permission
  or a reliability banner, update
  [`docs/v_model/conops.md`](../../docs/v_model/conops.md)
  (Normal Operational Scenario).
- A new screen is its own PR. Do not bundle a screen with a
  model change.
