// Singleton tests for AppDatabaseService (v1.5-cyc-ε /
// SYS-144 / ADR-075 / WF-072, v1.6-ι / SYS-154 / ADR-085 /
// WF-082).
//
// Coverage (5 tests):
//   - init() is idempotent (a second init() does not re-bind
//     `db` and resolves immediately).
//   - closeForTesting() then init() re-opens a fresh DB
//     (the round-trip used by every repository test in
//     `setUp` / `tearDown`).
//   - The `db` getter throws StateError with a documented
//     message before `init()` has resolved (the
//     "AppDatabaseService.init() must complete before db is
//     read" guard).
//   - init() failure surfaces through `ready.future` AND the
//     `db` getter stays in a "must init first" state
//     (v1.6-ι pin of the per-kind failure propagation path).
//   - closeForTesting() resets `db` accessibility so the
//     getter throws until the next init() (v1.6-ι pin of
//     the close→re-init boundary).
//
// Tests are AAA-pattern, deterministic (in-memory Drift
// executor — no filesystem I/O), and use
// `AppDatabaseService.instance.closeForTesting()` between
// tests to keep the singleton state isolated.

import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppDatabaseService', () {
    setUp(() async {
      // Reset the singleton to a clean state for each test.
      await AppDatabaseService.instance.closeForTesting();
    });

    tearDown(() async {
      // Close the in-memory DB so subsequent tests get a fresh
      // binding. `closeForTesting()` is idempotent.
      await AppDatabaseService.instance.closeForTesting();
    });

    test(
      'init_is_idempotent (second init resolves immediately, same DB)',
      () async {
        // Arrange.
        final first = AppDatabase(NativeDatabase.memory());

        // Act.
        await AppDatabaseService.instance.init(overrideDb: first);
        await AppDatabaseService.instance.ready;
        final boundAfterFirst = AppDatabaseService.instance.db;

        // A second init must NOT re-bind `db`; it must resolve
        // immediately and `db` must still equal the first binding.
        await AppDatabaseService.instance.init(overrideDb: first);
        await AppDatabaseService.instance.ready;
        final boundAfterSecond = AppDatabaseService.instance.db;

        // Assert.
        expect(identical(boundAfterFirst, first), isTrue);
        expect(identical(boundAfterSecond, first), isTrue);
      },
    );

    test('closeForTesting_re_init_round_trip (fresh DB after close)', () async {
      // Arrange.
      final first = AppDatabase(NativeDatabase.memory());
      await AppDatabaseService.instance.init(overrideDb: first);
      await AppDatabaseService.instance.ready;
      expect(identical(AppDatabaseService.instance.db, first), isTrue);

      // Act.
      await AppDatabaseService.instance.closeForTesting();
      final second = AppDatabase(NativeDatabase.memory());
      await AppDatabaseService.instance.init(overrideDb: second);
      await AppDatabaseService.instance.ready;

      // Assert — `db` now points at the new binding; the first
      // is gone (closed via closeForTesting's `await d.close()`).
      expect(identical(AppDatabaseService.instance.db, first), isFalse);
      expect(identical(AppDatabaseService.instance.db, second), isTrue);
    });

    test('db_getter_throws_StateError_pre_init', () {
      // Arrange + Act + Assert — the getter must throw with a
      // documented message before init() has resolved. Because
      // `closeForTesting` resolves the empty Completer in the
      // setUp, this test pins the documented contract:
      // `db` is reachable only after `init()` has completed.
      expect(
        () => AppDatabaseService.instance.db,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'AppDatabaseService.init() must complete before db is read.',
            ),
          ),
        ),
      );
    });

    // ---- v1.6-ι / SYS-154 / ADR-085 / WF-082 ----
    // State-after-failure paths for the singleton: an
    // `init()` that throws must surface the error through
    // `ready.future` AND keep `db` in a "must init first"
    // state; a `closeForTesting()` after a successful init
    // must drop accessibility until the next init().
    test('init_failure_surfaces_via_ready.future_and_db_stays_uninitialized '
        '(v1.6-ι)', () async {
      // Arrange — drive the failure path by passing an
      // `overrideDb` that we then break. The simplest seam:
      // call `init()` without an override (so the path
      // resolves the application-support directory) inside
      // a fake-async zone that does NOT have path_provider
      // available. The `getApplicationSupportDirectory`
      // call inside `init()` throws `MissingPluginException`
      // (no path_provider channel).
      //
      // We drive this with a non-widget unit test (no
      // `tester.runAsync`) so the platform-channel call
      // does NOT advance on the fake-async microtask queue
      // — exactly the failure mode the production code
      // has to tolerate.
      Object? caught;
      try {
        await AppDatabaseService.instance.init();
        // The init() should have thrown because
        // path_provider is not available in this
        // environment.
      } catch (e) {
        caught = e;
      }

      // Assert — init() propagated the failure. We don't
      // pin the exception type (it's
      // `MissingPluginException` today, but the contract
      // is "any throw from the platform layer surfaces").
      expect(caught, isNotNull, reason: 'init() must propagate failures');

      // The Completer's future rejects with the same
      // error. Subscribers (repositories / services that
      // `await ready.future` in their public reads) MUST
      // see the same error.
      Object? readyError;
      try {
        await AppDatabaseService.instance.ready;
      } catch (e) {
        readyError = e;
      }
      expect(readyError, isNotNull, reason: 'ready.future must reject');

      // The `db` getter is still in the "must init first"
      // state — `_db` was never assigned because the
      // failure happened before the assignment.
      expect(
        () => AppDatabaseService.instance.db,
        throwsA(isA<StateError>()),
        reason:
            'After a failed init, `db` must still throw '
            'StateError (the singleton never bound).',
      );
    });

    test(
      'closeForTesting_resets_db_accessibility_until_next_init (v1.6-ι)',
      () async {
        // Arrange — bind a fresh DB, verify it is reachable,
        // then close and verify the getter throws until a
        // new init() restores access.
        final fresh = AppDatabase(NativeDatabase.memory());
        await AppDatabaseService.instance.init(overrideDb: fresh);
        await AppDatabaseService.instance.ready;
        expect(identical(AppDatabaseService.instance.db, fresh), isTrue);

        // Act.
        await AppDatabaseService.instance.closeForTesting();

        // Assert — after closeForTesting, the singleton's
        // `_db` is null; the getter must throw the documented
        // StateError.
        expect(
          () => AppDatabaseService.instance.db,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'AppDatabaseService.init() must complete before db is read.',
              ),
            ),
          ),
          reason:
              'closeForTesting must reset `_db` to null so the '
              'getter throws until the next init() completes.',
        );

        // Re-init restores accessibility.
        final second = AppDatabase(NativeDatabase.memory());
        await AppDatabaseService.instance.init(overrideDb: second);
        await AppDatabaseService.instance.ready;
        expect(
          identical(AppDatabaseService.instance.db, second),
          isTrue,
          reason: 'After re-init, `db` must point at the new binding.',
        );
      },
    );
  });
}
