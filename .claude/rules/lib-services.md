# `lib/services/**` — Service singletons

## Pattern

All services in `lib/services/` follow the same pattern as
`board_box/lib/services/`:

- One file per service.
- A `Completer<void> _ready` is held by the singleton.
- `init()` is idempotent. Multiple calls after the first
  resolve immediately.
- All public reads/writes `await _ready.future` first.
- Public methods are async; they return `Future<T>` even for
  synchronous results, so the caller can `await` them.

Worked examples to follow:

- `lib/services/habit_repository.dart` (CRUD for habits).
- `lib/services/completion_log_service.dart` (append + query).
- `lib/services/db.dart` (Drift singleton).

## Layer boundary

- Services depend on `lib/models/`, `lib/habits/`, `lib/people/`,
  `lib/missions/`, `lib/reminders/` (for the schedule layer
  only).
- Services MUST NOT depend on `lib/screens/` (no UI).
- Services MUST NOT depend on `package:flutter/*` (no widgets).
  An exception: services that need `WidgetsBinding` (e.g., for
  `AppLifecycleState`) may import `package:flutter/widgets.dart`
  for that type only.

## No network calls

This is a hard rule. The CI grep rejects any
`import 'package:http'` or `Uri.http(s)` outside the dev-only
test harness. If a service needs to make a network call, it is
the wrong service — talk to the user.

## Singleton lifecycle

- A service is constructed once at app start in `main.dart`.
- `init()` is called from `main()` after `runApp` is NOT
  called (services are initialized before `runApp` so the
  first frame can read state).
- A service that needs a platform channel (e.g.,
  `NotificationService`) is initialized in `main()` and the
  platform side is set up in `MainActivity.configureFlutterEngine`.

## Database

- `lib/services/db.dart` is the Drift singleton.
- The Drift schema lives in `lib/services/db/schema.dart`.
- Migrations live in `lib/services/db/migrations/` (one file
  per version bump, named `vN_to_vM.dart`).
- Migrations are tested in `test/db/migration_test.dart` with
  a downgraded-schema fixture.

## Backup service

- `lib/services/backup_service.dart` is the singleton for
  nightly auto-backup and restore.
- The service owns the SAF URI and the staging file path.
- The service runs on a `WorkManager` periodic task at
  02:00-04:00 local.
- The service is the only writer of backup files. Restore is
  also its responsibility.

## Streak service

- `lib/services/streak_service.dart` is a thin wrapper over
  `lib/habits/streak_calculator.dart` that also subscribes
  to the completion log and re-computes streaks when the log
  changes.
- The service exposes `Stream<StreakSnapshot>` for the home
  screen and the widget.

## Stats service

- `lib/services/stats_service.dart` is a thin wrapper that
  materializes the stats queries for the stats screen.
- The service caches results for 5 seconds; re-renders within
  that window are free.

## Forbidden patterns

- No `print()`. Use `debugPrint` behind `kDebugMode`.
- No `await` of side-effect methods that are not declared
  `async`. (Lint: `unawaited_futures`.)
- No global state outside this pattern.
- No mutating a service's public state. The service's state
  is private; mutations go through methods.

## Tests

- One test file per service, e.g.,
  `test/services/backup_service_test.dart`.
- Use `tester.runAsync` for tests that touch the real
  filesystem or the platform channel.
- 80%+ coverage on changed files.

## When changing this folder

- If a new service is added, update
  [`docs/v_model/architecture_options.md`](../../docs/v_model/architecture_options.md)
  (module list).
- If a service changes its public API, the change is a
  breaking change for the rest of the app. Coordinate.
- A DB migration is its own PR. Do not bundle a migration
  with a feature.
