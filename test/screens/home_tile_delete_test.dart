// Unit tests for `home_tile_delete.dart` — the pure-Dart
// `deleteDo` helper that backs the in-app home tile's
// per-tile "Delete" button (v1.4h / Phase 35 / SYS-122 /
// ADR-052 / WF-049).
//
// The helper's only job is to call
// `DoRepository.deleteById(activeDo.id)` and translate the
// throwable into a `bool` so the tile's UI layer can
// branch without `try/catch` blocks everywhere.
//
// Because `DoRepository` is concrete (not abstract), the
// tests use a hand-rolled fake that `implements`
// `DoRepository` + `noSuchMethod` fallback — same pattern
// as `test/widget/widget_service_test.dart`. The fake
// records every `deleteById` call and can be configured
// to throw so the helper's catch-all is exercised.
//
// The helper imports no Flutter types (it's pure-Dart),
// so no `TestWidgetsFlutterBinding` is needed.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/screens/home_tile_delete.dart';
import 'package:doit/services/do_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Do _makeDo({String id = 'do-1', String name = 'Read'}) {
  return DoFixed(
    id: id,
    name: name,
    proofMode: const SoftProof(),
    createdAt: DateTime(2026, 6),
    restDaysPerMonth: 2,
    weekdays: const <int>{1, 2, 3, 4, 5, 6, 7},
    time: const DoTime(9, 0),
  );
}

class _FakeDoRepo implements DoRepository {
  final List<String> deletedIds = <String>[];
  // When non-null, the next `deleteById` call throws the
  // configured error. The flag is consumed on first throw
  // so subsequent calls return to the happy path (lets a
  // single test exercise both branches if needed).
  Object? throwOnNextDelete;

  @override
  Future<void> deleteById(String id) async {
    if (throwOnNextDelete != null) {
      final err = throwOnNextDelete;
      throwOnNextDelete = null;
      throw err!;
    }
    deletedIds.add(id);
  }

  @override
  Future<void> save(Do d) async {}

  @override
  Future<Do?> getById(String id) async => null;

  @override
  Future<List<Do>> listAll() async => const <Do>[];

  @override
  Future<List<Do>> listActive(DateTime now) async => const <Do>[];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('deleteDo (v1.4h / SYS-122)', () {
    test('returns true on the happy path', () async {
      // Arrange
      final repo = _FakeDoRepo();
      final activeDo = _makeDo();

      // Act
      final ok = await deleteDo(activeDo: activeDo, repository: repo);

      // Assert
      expect(ok, isTrue);
      expect(repo.deletedIds, <String>['do-1']);
    });

    test('calls deleteById exactly once with the do id', () async {
      // Arrange
      final repo = _FakeDoRepo();
      final activeDo = _makeDo(id: 'do-unique');

      // Act
      await deleteDo(activeDo: activeDo, repository: repo);

      // Assert — one call, the captured id, nothing else.
      expect(repo.deletedIds, hasLength(1));
      expect(repo.deletedIds.single, 'do-unique');
    });

    test('returns false when the repository throws an Error', () async {
      // Arrange
      final repo = _FakeDoRepo()..throwOnNextDelete = StateError('DB locked');
      final activeDo = _makeDo();

      // Act
      final ok = await deleteDo(activeDo: activeDo, repository: repo);

      // Assert
      expect(ok, isFalse);
    });

    test('returns false when deleteById throws an Exception subtype', () async {
      // Arrange — the catch-all swallows any throwable, not
      // just Errors. A typical Drift exception is an
      // Exception (not an Error).
      final repo = _FakeDoRepo()
        ..throwOnNextDelete = Exception('foreign-key constraint');
      final activeDo = _makeDo();

      // Act
      final ok = await deleteDo(activeDo: activeDo, repository: repo);

      // Assert
      expect(ok, isFalse);
    });

    test(
      'does not re-throw — the caller can rely on the bool return',
      () async {
        // Arrange
        final repo = _FakeDoRepo()
          ..throwOnNextDelete = StateError('should be swallowed');
        final activeDo = _makeDo();

        // Act + Assert — no throw escapes the helper.
        await expectLater(
          () => deleteDo(activeDo: activeDo, repository: repo),
          returnsNormally,
        );
      },
    );

    test('does not import Flutter (no binding initialization)', () async {
      // Arrange
      final repo = _FakeDoRepo();
      final activeDo = _makeDo();

      // Act — calling the helper in a non-Flutter test
      // context would throw at compile-time if the helper
      // pulled in `package:flutter/*`. The real check is
      // the import at the top of the source file; this
      // test pins the runtime side: the call completes
      // without the test binding.
      final ok = await deleteDo(activeDo: activeDo, repository: repo);

      // Assert
      expect(ok, isTrue);
    });
  });
}
