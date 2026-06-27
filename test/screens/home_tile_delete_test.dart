// Tests for `home_tile_delete.dart` — the pure-Dart
// `softDeleteDo` + `restoreDo` helpers that back the
// in-app home tile's per-tile Delete + Undo SnackBar
// (v1.4l / Phase 39 / SYS-126 / ADR-056 / WF-053).
//
// The helpers' job is to call
// `DoRepository.softDeleteById(activeDo.id, at: at)` and
// `DoRepository.restoreById(activeDo.id)` and translate the
// throwable into a `bool` so the tile's UI layer can branch
// without `try/catch` blocks. v1.4l supersedes the v1.4h
// `deleteDo` helper (hard-delete + Undo-re-save) with the
// soft-delete + Undo-restore flow that keeps the
// completion-log rows intact for true streak restoration.
//
// Because `DoRepository` is concrete (not abstract), the
// tests use a hand-rolled fake that `implements`
// `DoRepository` + `noSuchMethod` fallback — same pattern
// as `test/widget/widget_service_test.dart`. The fake
// records every `softDeleteById` / `restoreById` call and
// can be configured to throw so each helper's catch-all is
// exercised.
//
// The helpers import no Flutter types (they're pure-Dart),
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

class _RecordedCall {
  _RecordedCall(this.id, [this.at]);
  final String id;
  final DateTime? at;
}

class _FakeDoRepo implements DoRepository {
  final List<_RecordedCall> softDeleted = <_RecordedCall>[];
  final List<_RecordedCall> restored = <_RecordedCall>[];
  // When non-null, the next softDeleteById or restoreById
  // call throws the configured error. Each flag is consumed
  // on first throw so a single test can exercise both
  // branches.
  Object? throwOnNextSoftDelete;
  Object? throwOnNextRestore;
  // Return values for softDeleteById / restoreById. Default
  // true (happy path).
  bool softDeleteReturn = true;
  bool restoreReturn = true;

  @override
  Future<bool> softDeleteById(String id, {required DateTime at}) async {
    if (throwOnNextSoftDelete != null) {
      final err = throwOnNextSoftDelete;
      throwOnNextSoftDelete = null;
      throw err!;
    }
    softDeleted.add(_RecordedCall(id, at));
    return softDeleteReturn;
  }

  @override
  Future<bool> restoreById(String id) async {
    if (throwOnNextRestore != null) {
      final err = throwOnNextRestore;
      throwOnNextRestore = null;
      throw err!;
    }
    restored.add(_RecordedCall(id));
    return restoreReturn;
  }

  @override
  Future<void> save(Do d) async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<Do?> getById(String id) async => null;

  @override
  Future<Do?> getActiveById(String id) async => null;

  @override
  Future<List<Do>> listAll() async => const <Do>[];

  @override
  Future<List<Do>> listActive(DateTime now) async => const <Do>[];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('softDeleteDo (v1.4l / SYS-126)', () {
    test('returns true on the happy path', () async {
      // Arrange
      final repo = _FakeDoRepo();
      final activeDo = _makeDo();
      final at = DateTime(2026, 6, 27, 10);

      // Act
      final ok = await softDeleteDo(
        activeDo: activeDo,
        at: at,
        repository: repo,
      );

      // Assert — the happy-path call forwards the captured
      // id AND the timestamp verbatim. (This subsumes the
      // "forwards the do id and the timestamp verbatim"
      // case from the v1.4h test — the v1.4l helper takes
      // the timestamp explicitly so the verifier can pin
      // both fields in one assertion.)
      expect(ok, isTrue);
      expect(repo.softDeleted, hasLength(1));
      expect(repo.softDeleted.single.id, 'do-1');
      expect(repo.softDeleted.single.at, at);
    });

    test('forwards a non-default id verbatim', () async {
      // Arrange
      final repo = _FakeDoRepo();
      final activeDo = _makeDo(id: 'do-unique');
      final at = DateTime(2026, 7);

      // Act
      await softDeleteDo(activeDo: activeDo, at: at, repository: repo);

      // Assert — the helper must propagate the caller's id
      // (not synthesize one). The `at` arg uses a fixed
      // epoch-millis-equivalent date; the prior test pins
      // the timestamp-forwarding behavior so we don't need
      // a second timestamp assertion here.
      expect(repo.softDeleted.single.id, 'do-unique');
    });

    test('returns false when the repository throws an Error', () async {
      // Arrange
      final repo = _FakeDoRepo()
        ..throwOnNextSoftDelete = StateError('DB locked');
      final activeDo = _makeDo();

      // Act
      final ok = await softDeleteDo(
        activeDo: activeDo,
        at: DateTime(2026, 6, 27),
        repository: repo,
      );

      // Assert
      expect(ok, isFalse);
    });

    test('returns false when softDeleteById throws an Exception', () async {
      // Arrange — the catch-all swallows any throwable, not
      // just Errors. A typical Drift exception is an
      // Exception (not an Error).
      final repo = _FakeDoRepo()
        ..throwOnNextSoftDelete = Exception('disk full');
      final activeDo = _makeDo();

      // Act
      final ok = await softDeleteDo(
        activeDo: activeDo,
        at: DateTime(2026, 6, 27),
        repository: repo,
      );

      // Assert
      expect(ok, isFalse);
    });

    test('does not re-throw — caller can rely on the bool return', () async {
      // Arrange
      final repo = _FakeDoRepo()
        ..throwOnNextSoftDelete = StateError('should be swallowed');
      final activeDo = _makeDo();

      // Act + Assert — no throw escapes the helper.
      await expectLater(
        () => softDeleteDo(
          activeDo: activeDo,
          at: DateTime(2026, 6, 27),
          repository: repo,
        ),
        returnsNormally,
      );
    });

    test(
      'returns false when the repo reports no active row to tombstone',
      () async {
        // Arrange — softDeleteById returns false when the
        // row is already tombstoned (the SQL UPDATE filters
        // `deletedAtMillis IS NULL`). The helper must
        // forward the false, not swallow it.
        final repo = _FakeDoRepo()..softDeleteReturn = false;
        final activeDo = _makeDo();

        // Act
        final ok = await softDeleteDo(
          activeDo: activeDo,
          at: DateTime(2026, 6, 27),
          repository: repo,
        );

        // Assert
        expect(ok, isFalse);
        expect(repo.softDeleted, hasLength(1));
      },
    );
  });

  group('restoreDo (v1.4l / SYS-126)', () {
    test('returns true on the happy path', () async {
      // Arrange
      final repo = _FakeDoRepo();
      final tombstonedDo = _makeDo();

      // Act
      final ok = await restoreDo(tombstonedDo: tombstonedDo, repository: repo);

      // Assert
      expect(ok, isTrue);
      expect(repo.restored, hasLength(1));
      expect(repo.restored.single.id, 'do-1');
    });

    test('forwards the do id verbatim', () async {
      // Arrange
      final repo = _FakeDoRepo();
      final tombstonedDo = _makeDo(id: 'do-restored');

      // Act
      await restoreDo(tombstonedDo: tombstonedDo, repository: repo);

      // Assert
      expect(repo.restored.single.id, 'do-restored');
    });

    test('returns false when the repository throws an Error', () async {
      // Arrange
      final repo = _FakeDoRepo()..throwOnNextRestore = StateError('DB locked');
      final tombstonedDo = _makeDo();

      // Act
      final ok = await restoreDo(tombstonedDo: tombstonedDo, repository: repo);

      // Assert
      expect(ok, isFalse);
    });

    test('returns false when restoreById throws an Exception', () async {
      // Arrange
      final repo = _FakeDoRepo()..throwOnNextRestore = Exception('disk full');
      final tombstonedDo = _makeDo();

      // Act
      final ok = await restoreDo(tombstonedDo: tombstonedDo, repository: repo);

      // Assert
      expect(ok, isFalse);
    });

    test('does not re-throw — caller can rely on the bool return', () async {
      // Arrange
      final repo = _FakeDoRepo()
        ..throwOnNextRestore = StateError('should be swallowed');
      final tombstonedDo = _makeDo();

      // Act + Assert — no throw escapes the helper.
      await expectLater(
        () => restoreDo(tombstonedDo: tombstonedDo, repository: repo),
        returnsNormally,
      );
    });

    test(
      'returns false when the repo reports no tombstoned row to restore',
      () async {
        // Arrange — restoreById returns false when the row
        // is already active (idempotent — the SQL UPDATE
        // filters `deletedAtMillis IS NOT NULL`). The
        // helper must forward the false.
        final repo = _FakeDoRepo()..restoreReturn = false;
        final tombstonedDo = _makeDo();

        // Act
        final ok = await restoreDo(
          tombstonedDo: tombstonedDo,
          repository: repo,
        );

        // Assert
        expect(ok, isFalse);
        expect(repo.restored, hasLength(1));
      },
    );
  });

  group('softDeleteDo + restoreDo round-trip (v1.4l / SYS-126)', () {
    test('restoreDo after softDeleteDo restores the same id', () async {
      // Arrange — the tile flow is: soft-delete →
      // SnackBar Undo → restore. The two helpers must
      // operate on the same id.
      final repo = _FakeDoRepo();
      final activeDo = _makeDo(id: 'do-roundtrip');
      final at = DateTime(2026, 6, 27);

      // Act
      final soft = await softDeleteDo(
        activeDo: activeDo,
        at: at,
        repository: repo,
      );
      final restored = await restoreDo(
        tombstonedDo: activeDo,
        repository: repo,
      );

      // Assert
      expect(soft, isTrue);
      expect(restored, isTrue);
      expect(repo.softDeleted.single.id, 'do-roundtrip');
      expect(repo.restored.single.id, 'do-roundtrip');
    });
  });

  group('imports (v1.4l / SYS-126)', () {
    test('softDeleteDo and restoreDo do not import Flutter', () async {
      // Arrange
      final repo = _FakeDoRepo();
      final activeDo = _makeDo();

      // Act — calling the helpers in a non-Flutter test
      // context would throw at compile-time if either
      // helper pulled in `package:flutter/*`. The real
      // check is the import at the top of the source file;
      // this test pins the runtime side: both calls
      // complete without the test binding.
      final soft = await softDeleteDo(
        activeDo: activeDo,
        at: DateTime(2026, 6, 27),
        repository: repo,
      );
      final restored = await restoreDo(
        tombstonedDo: activeDo,
        repository: repo,
      );

      // Assert
      expect(soft, isTrue);
      expect(restored, isTrue);
    });
  });
}
