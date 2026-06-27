// Tests for the v1.4l soft-delete + restore surface on
// [DoRepository] (v1.4l / Phase 39 / SYS-126 / ADR-056 /
// WF-053).
//
// Coverage:
//   - softDeleteById writes a non-null `deletedAtMillis`.
//   - The tombstoned do disappears from `listAll` after
//     a soft-delete.
//   - The tombstoned do disappears from `listActive` after
//     a soft-delete.
//   - `getById` still returns the tombstoned do (used by
//     the restore path).
//   - `getActiveById` returns null for the tombstoned do.
//   - `restoreById` clears the tombstone and the do
//     reappears in `listAll`.
//   - `save` does NOT touch a tombstoned row's tombstone
//     (the v1.4l invariant — pin so a future change to
//     `_toRow` cannot silently resurrect / tombstone via
//     a Save click).
//   - `softDeleteById` is idempotent on an already-
//     tombstoned row (returns false).
//   - `restoreById` is idempotent on an already-active row
//     (returns false).
//
// The general CRUD tests live in
// `test/services/habit_repository_test.dart`; this file is
// dedicated to the soft-delete surface so the v1.4l
// invariant pins are obvious.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/do_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _init() async {
  await AppDatabaseService.instance.closeForTesting();
  await AppDatabaseService.instance.init(
    overrideDb: AppDatabase(NativeDatabase.memory()),
  );
  await AppDatabaseService.instance.ready;
}

Future<void> _tearDown() => AppDatabaseService.instance.closeForTesting();

Do _do({required String id, String name = 'Drink water', DateTime? createdAt}) {
  return DoFixed(
    id: id,
    name: name,
    proofMode: const SoftProof(),
    createdAt: createdAt ?? DateTime(2026, 6, 27),
    restDaysPerMonth: 2,
    weekdays: const <int>{1, 2, 3, 4, 5, 6, 7},
    time: const DoTime(9, 0),
  );
}

void main() {
  setUp(_init);
  tearDown(_tearDown);

  group('DoRepository soft-delete (v1.4l / SYS-126)', () {
    test('softDeleteById writes a non-null deletedAtMillis', () async {
      // Arrange
      await DoRepository.instance.save(_do(id: 'h1'));
      final at = DateTime(2026, 6, 27, 10);

      // Act
      final ok = await DoRepository.instance.softDeleteById('h1', at: at);

      // Assert
      expect(ok, isTrue);
      // The row is still present (with the tombstone).
      final db = AppDatabaseService.instance.db;
      final row = await (db.select(
        db.habits,
      )..where((t) => t.id.equals('h1'))).getSingle();
      expect(row.deletedAtMillis, at.millisecondsSinceEpoch);
    });

    test('listAll excludes tombstoned habits', () async {
      // Arrange
      await DoRepository.instance.save(_do(id: 'h-active', name: 'Active'));
      await DoRepository.instance.save(_do(id: 'h-deleted', name: 'Deleted'));
      await DoRepository.instance.softDeleteById(
        'h-deleted',
        at: DateTime(2026, 6, 27),
      );

      // Act
      final list = await DoRepository.instance.listAll();

      // Assert
      expect(list.map((d) => d.id), <String>['h-active']);
    });

    test('listActive excludes tombstoned habits', () async {
      // Arrange
      await DoRepository.instance.save(_do(id: 'h-active', name: 'Active'));
      await DoRepository.instance.save(_do(id: 'h-deleted', name: 'Deleted'));
      await DoRepository.instance.softDeleteById(
        'h-deleted',
        at: DateTime(2026, 6, 27),
      );

      // Act
      final now = DateTime(2026, 6, 27, 12);
      final list = await DoRepository.instance.listActive(now);

      // Assert
      expect(list.map((d) => d.id), <String>['h-active']);
    });

    test('getById still returns a tombstoned do (used by restore)', () async {
      // Arrange
      await DoRepository.instance.save(_do(id: 'h-deleted'));
      await DoRepository.instance.softDeleteById(
        'h-deleted',
        at: DateTime(2026, 6, 27),
      );

      // Act
      final d = await DoRepository.instance.getById('h-deleted');

      // Assert
      expect(d, isNotNull);
      expect(d!.isDeleted, isTrue);
      expect(d.deletedAt, DateTime(2026, 6, 27));
    });

    test('getActiveById returns null for a tombstoned do', () async {
      // Arrange
      await DoRepository.instance.save(_do(id: 'h-deleted'));
      await DoRepository.instance.softDeleteById(
        'h-deleted',
        at: DateTime(2026, 6, 27),
      );

      // Act
      final d = await DoRepository.instance.getActiveById('h-deleted');

      // Assert
      expect(d, isNull);
    });

    test('getActiveById returns the do when active', () async {
      // Arrange
      await DoRepository.instance.save(_do(id: 'h-active'));

      // Act
      final d = await DoRepository.instance.getActiveById('h-active');

      // Assert
      expect(d, isNotNull);
      expect(d!.isDeleted, isFalse);
    });

    test('softDeleteById is idempotent on an already-tombstoned row', () async {
      // Arrange
      await DoRepository.instance.save(_do(id: 'h1'));
      final first = await DoRepository.instance.softDeleteById(
        'h1',
        at: DateTime(2026, 6, 27),
      );

      // Act — second soft-delete returns false (the
      // SQL UPDATE filters `deletedAtMillis IS NULL`,
      // so the row is no longer "deletable").
      final second = await DoRepository.instance.softDeleteById(
        'h1',
        at: DateTime(2026, 6, 28),
      );

      // Assert
      expect(first, isTrue);
      expect(second, isFalse);
      // The first timestamp is preserved (no overwrite).
      final db = AppDatabaseService.instance.db;
      final row = await (db.select(
        db.habits,
      )..where((t) => t.id.equals('h1'))).getSingle();
      expect(row.deletedAtMillis, DateTime(2026, 6, 27).millisecondsSinceEpoch);
    });

    test('softDeleteById on a missing row returns false', () async {
      // Arrange — no save.

      // Act
      final ok = await DoRepository.instance.softDeleteById(
        'does-not-exist',
        at: DateTime(2026, 6, 27),
      );

      // Assert
      expect(ok, isFalse);
    });
  });

  group('DoRepository restore (v1.4l / SYS-126)', () {
    test('restoreById clears the tombstone', () async {
      // Arrange
      await DoRepository.instance.save(_do(id: 'h1'));
      await DoRepository.instance.softDeleteById(
        'h1',
        at: DateTime(2026, 6, 27),
      );

      // Act
      final ok = await DoRepository.instance.restoreById('h1');

      // Assert
      expect(ok, isTrue);
      final db = AppDatabaseService.instance.db;
      final row = await (db.select(
        db.habits,
      )..where((t) => t.id.equals('h1'))).getSingle();
      expect(row.deletedAtMillis, isNull);
    });

    test('restored do reappears in listAll with isDeleted == false', () async {
      // Arrange
      await DoRepository.instance.save(_do(id: 'h1'));
      await DoRepository.instance.softDeleteById(
        'h1',
        at: DateTime(2026, 6, 27),
      );

      // Act
      await DoRepository.instance.restoreById('h1');
      final list = await DoRepository.instance.listAll();

      // Assert
      expect(list.map((d) => d.id), <String>['h1']);
      expect(list.single.isDeleted, isFalse);
    });

    test('restoreById is idempotent on an already-active row', () async {
      // Arrange — save without soft-delete.
      await DoRepository.instance.save(_do(id: 'h1'));

      // Act
      final ok = await DoRepository.instance.restoreById('h1');

      // Assert — the SQL UPDATE filters
      // `deletedAtMillis IS NOT NULL`, so an active row
      // is a no-op and returns false.
      expect(ok, isFalse);
    });

    test('restoreById on a missing row returns false', () async {
      // Arrange — no save.

      // Act
      final ok = await DoRepository.instance.restoreById('does-not-exist');

      // Assert
      expect(ok, isFalse);
    });
  });

  group('DoRepository save invariant (v1.4l / SYS-126)', () {
    test(
      'save(d) does NOT touch a tombstoned row\'s deletedAtMillis',
      () async {
        // Arrange — soft-delete then save a modified copy
        // with `deletedAt: null`. The tombstone must survive
        // the save (Drift's `insertOnConflictUpdate`
        // semantics on a row whose `_toRow` omits the
        // column). This is the v1.4l invariant — a Save
        // click must not silently resurrect a tombstoned
        // do.
        await DoRepository.instance.save(_do(id: 'h1', name: 'Old name'));
        await DoRepository.instance.softDeleteById(
          'h1',
          at: DateTime(2026, 6, 27),
        );

        // Act — caller's in-memory copy has deletedAt: null
        // (they don't see the tombstone via getActiveById,
        // and they don't think to query getById for the
        // tombstone). `save` must NOT clear the tombstone.
        final updated = _do(id: 'h1', name: 'New name');
        await DoRepository.instance.save(updated);

        // Assert — the row is STILL tombstoned.
        final db = AppDatabaseService.instance.db;
        final row = await (db.select(
          db.habits,
        )..where((t) => t.id.equals('h1'))).getSingle();
        expect(row.name, 'New name'); // the content update landed
        expect(row.deletedAtMillis, isNotNull);
        // And the do is still hidden from listAll.
        final list = await DoRepository.instance.listAll();
        expect(list, isEmpty);
      },
    );

    test('restoreById after a save on a tombstoned row still works', () async {
      // Arrange — the user might edit the do's name
      // after a soft-delete (e.g., from the Edit IconButton
      // path). The tombstone survives the save (see the
      // previous test). restoreById must still clear the
      // tombstone and bring the do back into the active
      // listing.
      await DoRepository.instance.save(_do(id: 'h1', name: 'Old name'));
      await DoRepository.instance.softDeleteById(
        'h1',
        at: DateTime(2026, 6, 27),
      );
      await DoRepository.instance.save(_do(id: 'h1', name: 'New name'));

      // Act
      final ok = await DoRepository.instance.restoreById('h1');
      final list = await DoRepository.instance.listAll();

      // Assert
      expect(ok, isTrue);
      expect(list.map((d) => d.id), <String>['h1']);
      expect(list.single.name, 'New name');
    });
  });

  group('DoRepository hard-delete (v1.4l / SYS-126 — preserved path)', () {
    test(
      'deleteById still removes the row (backup-restore wipe path)',
      () async {
        // Arrange — `deleteById` is the force-delete path
        // reserved for `BackupService.importFrom`. It must
        // still work post-v1.4l. The home tile does NOT
        // call this — it goes through softDeleteById.
        await DoRepository.instance.save(_do(id: 'h1'));

        // Act
        await DoRepository.instance.deleteById('h1');

        // Assert
        final d = await DoRepository.instance.getById('h1');
        expect(d, isNull);
      },
    );

    test(
      'force-deleting then saving the same id re-inserts as active',
      () async {
        // Arrange — the v1.4h Undo path used
        // `insertOnConflictUpdate` after a hard-delete.
        // Today, hard-delete is reserved for the backup
        // wipe, but the same id + a fresh save should
        // still work (the row is gone, so the
        // `insertOnConflictUpdate` is just an insert).
        await DoRepository.instance.save(_do(id: 'h1'));
        await DoRepository.instance.deleteById('h1');

        // Act
        final reInserted = _do(id: 'h1', name: 'Re-saved');
        await DoRepository.instance.save(reInserted);
        final list = await DoRepository.instance.listAll();

        // Assert
        expect(list.map((d) => d.id), <String>['h1']);
        expect(list.single.name, 'Re-saved');
        expect(list.single.isDeleted, isFalse);
      },
    );
  });
}
