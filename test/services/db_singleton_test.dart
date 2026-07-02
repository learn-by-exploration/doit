// Singleton tests for AppDatabaseService (v1.5-cyc-ε /
// SYS-144 / ADR-075 / WF-072).
//
// Coverage (3 tests):
//   - init() is idempotent (a second init() does not re-bind
//     `db` and resolves immediately).
//   - closeForTesting() then init() re-opens a fresh DB
//     (the round-trip used by every repository test in
//     `setUp` / `tearDown`).
//   - The `db` getter throws StateError with a documented
//     message before `init()` has resolved (the
//     "AppDatabaseService.init() must complete before db is
//     read" guard).
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
  });
}
