// v1.4-stab-L / Phase 52 / SYS-139 / ADR-070 / WF-067:
// SQL query-count benchmark for [DoRepository].
//
// Pins the N+1 invariant on the read paths the home
// screen consumes:
//   - `listAll` — single SELECT for N habits
//   - `listActive` — single SELECT for N habits (pause + tombstone
//     filters are at the SQL level, not in Dart)
//
// The benchmark uses Drift's [QueryExecutor] seam: a thin
// counting proxy wraps the in-memory NativeDatabase and
// increments `selectCount` / `executeCount` on every read /
// write. The proxy is the standard Drift test seam — it
// delegates every method to the wrapped executor, so the
// behavior under test is unchanged; only the side-channel
// counter is added.
//
// The test asserts exactly 1 SELECT for the N=10 case and
// reports the median ms per call over 50 iterations. The
// SELECT count is the regression guard — a future
// contributor who splits `listAll` into a per-do query
// (e.g. to JOIN related rows) would silently bump the
// counter to N=10 and the test would fail.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/do_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drift [QueryExecutor] proxy that counts SELECT / write
/// calls. Delegates every call to the wrapped executor so
/// behavior under test is unchanged. Implements the
/// Drift 2.20 surface area — see
/// https://pub.dev/documentation/drift/2.20.3/drift/QueryExecutor-class.html.
class _CountingExecutor extends QueryExecutor {
  _CountingExecutor(this._inner);

  final QueryExecutor _inner;
  int selectCount = 0;
  int executeCount = 0;

  @override
  SqlDialect get dialect => _inner.dialect;

  @override
  QueryExecutor beginExclusive() => _inner.beginExclusive();

  @override
  TransactionExecutor beginTransaction() => _inner.beginTransaction();

  @override
  Future<void> close() => _inner.close();

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _inner.ensureOpen(user);

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      _inner.runBatched(statements);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    executeCount++;
    return _inner.runCustom(statement, args);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) {
    executeCount++;
    return _inner.runDelete(statement, args);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    executeCount++;
    return _inner.runInsert(statement, args);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) async {
    selectCount++;
    return _inner.runSelect(statement, args);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    executeCount++;
    return _inner.runUpdate(statement, args);
  }
}

/// per-cycle drift lesson: median over many runs, not a
/// single timing. CI noise can swing single timings by
/// 5x.
int _medianMs(List<int> xs) {
  final sorted = List<int>.from(xs)..sort();
  return sorted[sorted.length ~/ 2];
}

Future<void> _resetDbWithCounting(_CountingExecutor counter) async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(counter);
  await AppDatabaseService.instance.init(overrideDb: db);
  await AppDatabaseService.instance.ready;
}

Future<void> _seedHabits(int n) async {
  final now = DateTime(2026, 6, 15, 9);
  for (var i = 0; i < n; i++) {
    await DoRepository.instance.save(
      DoFixed(
        id: 'h$i',
        name: 'Habit $i',
        proofMode: const SoftProof(),
        createdAt: now,
        restDaysPerMonth: 2,
        weekdays: const <int>{1, 3, 5},
        time: const DoTime(8, 0),
      ),
    );
  }
}

void main() {
  late _CountingExecutor counter;

  setUp(() async {
    counter = _CountingExecutor(NativeDatabase.memory());
    await _resetDbWithCounting(counter);
  });

  tearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });

  test('DoRepository.listAll issues exactly 1 SELECT for N=10 habits', () async {
    // Arrange
    await _seedHabits(10);
    counter.selectCount = 0;

    // Act
    final dos = await DoRepository.instance.listAll();

    // Assert
    expect(dos, hasLength(10));
    expect(
      counter.selectCount,
      equals(1),
      reason:
          'listAll should issue exactly 1 SELECT. Got ${counter.selectCount}. '
          'A future contributor who splits the query per-do would '
          'regress N+1 here — fix at the SQL level.',
    );
  });

  test(
    'DoRepository.listActive stays at 1 SELECT and median ms budget',
    () async {
      // Arrange
      await _seedHabits(10);
      counter.selectCount = 0;

      // Act — measure median over 50 iterations.
      const iterations = 50;
      final samples = <int>[];
      int lastCount = 0;
      final now = DateTime(2026, 6, 15, 9);
      for (var i = 0; i < iterations; i++) {
        counter.selectCount = 0;
        final sw = Stopwatch()..start();
        final dos = await DoRepository.instance.listActive(now);
        sw.stop();
        samples.add(sw.elapsedMicroseconds);
        lastCount = counter.selectCount;
        expect(dos, hasLength(10));
      }

      // Assert — query count guard first.
      expect(
        lastCount,
        equals(1),
        reason:
            'listActive should issue exactly 1 SELECT. Got $lastCount. '
            'The pause + tombstone filters MUST be at the SQL level.',
      );

      // Median ms budget — listActive is the home-screen hot
      // path; 10 ms median is generous for an in-memory DB
      // and an aggressive regression guard against drift.
      final med = _medianMs(samples) ~/ 1000;
      expect(
        med,
        lessThanOrEqualTo(10),
        reason:
            'listActive median $med ms over $iterations iterations '
            'exceeded 10 ms budget',
      );
    },
  );
}
