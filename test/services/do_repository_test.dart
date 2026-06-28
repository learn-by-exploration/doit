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
import 'package:doit/routines/routine.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:drift/drift.dart' show Value;
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

Do _do({
  required String id,
  String name = 'Drink water',
  DateTime? createdAt,
  List<Automation>? automations,
  DateTime? pausedUntil,
}) {
  return DoFixed(
    id: id,
    name: name,
    proofMode: const SoftProof(),
    createdAt: createdAt ?? DateTime(2026, 6, 27),
    restDaysPerMonth: 2,
    weekdays: const <int>{1, 2, 3, 4, 5, 6, 7},
    time: const DoTime(9, 0),
    automations: automations ?? const <Automation>[],
    pausedUntil: pausedUntil,
  );
}

/// Two Automation fixtures for the Cycle B round-trip test.
/// They use different trigger shapes (batteryLow + timeOfDay)
/// so the round-trip exercise the codec's discriminator
/// handling for at least two Trigger leaves. Each gets a
/// unique stable id so the [Automation.==] comparison across
/// the round-trip is unambiguous.
List<Automation> _twoAutomations() => <Automation>[
  Automation(
    id: 'auto-battery',
    trigger: const TriggerBatteryLow(20),
    action: const ActionNotify(title: 'Battery low', body: 'Plug in'),
  ),
  Automation(
    id: 'auto-tod',
    trigger: const TriggerTimeOfDay(hour: 7, minute: 30),
    action: const ActionNotify(title: 'Morning', body: 'Drink water'),
  ),
];

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

  group('DoRepository save invariant (Cycle B / BUG-001 + BUG-002)', () {
    test('automations round-trip through save + getById', () async {
      // Arrange — two automations on the in-memory do.
      // BUG-001 (SYS-129 / ADR-060): the column was missing
      // from `_toRow` AND `_fromRow`, so the user-saved
      // automations were silently lost on every Save and
      // even if the column had been written, the read path
      // would have returned an empty list. This test pins
      // BOTH directions: the round-trip yields the same
      // list back.
      final seed = _twoAutomations();

      // Act
      await DoRepository.instance.save(_do(id: 'h1', automations: seed));
      final loaded = await DoRepository.instance.getById('h1');

      // Assert — full round-trip equality (Automation's
      // own `==` covers id + trigger + condition + action +
      // enabled).
      expect(loaded, isNotNull);
      expect(loaded!.automations, equals(seed));
    });

    test(
      'pausedUntil round-trips via direct companion UPDATE + getById',
      () async {
        // Arrange — seed the `pausedUntilMillis` column via
        // a direct `HabitsCompanion` UPDATE. This mirrors the
        // shape `PauseService.pauseHabit` uses (Cycle B
        // refactor: pause/resume bypass `save()`).
        final pauseAt = DateTime(2026, 7, 2);
        await DoRepository.instance.save(_do(id: 'h1'));
        final db = AppDatabaseService.instance.db;
        await (db.update(db.habits)..where((t) => t.id.equals('h1'))).write(
          HabitsCompanion(
            pausedUntilMillis: Value(pauseAt.millisecondsSinceEpoch),
          ),
        );

        // Act
        final loaded = await DoRepository.instance.getById('h1');

        // Assert — `_fromRow` decodes the column back into
        // `Do.pausedUntil`.
        expect(loaded, isNotNull);
        expect(loaded!.pausedUntil, equals(pauseAt));
      },
    );

    test('save(d) does NOT clobber an existing pausedUntilMillis', () async {
      // Arrange — seed via direct `HabitsCompanion` UPDATE
      // (simulates a `PauseService.pauseHabit` call). Then
      // save a fresh in-memory `Do` with no pausedUntil
      // (simulates the AddHabitScreen Save path, which
      // reconstructs the `Do` from form fields that have
      // no pause picker). BUG-002 (SYS-129 / ADR-060): the
      // column was always being written as `null` whenever
      // the in-memory copy had `pausedUntil: null`, which
      // silently resumed a paused habit on every Save.
      // After the Cycle B fix, `_toRow` omits the column,
      // so the existing timestamp survives.
      final pauseAt = DateTime(2026, 7, 2);
      await DoRepository.instance.save(_do(id: 'h1', name: 'Old name'));
      final db = AppDatabaseService.instance.db;
      await (db.update(db.habits)..where((t) => t.id.equals('h1'))).write(
        HabitsCompanion(
          pausedUntilMillis: Value(pauseAt.millisecondsSinceEpoch),
        ),
      );

      // Act — save a fresh Do with a NEW name and no
      // pausedUntil in the in-memory copy (this is what
      // AddHabitScreen does after a form edit).
      await DoRepository.instance.save(_do(id: 'h1', name: 'New name'));

      // Assert — content update landed AND pause preserved.
      final row = await (db.select(
        db.habits,
      )..where((t) => t.id.equals('h1'))).getSingle();
      expect(row.name, 'New name');
      expect(row.pausedUntilMillis, equals(pauseAt.millisecondsSinceEpoch));

      // And the in-memory copy sees the same value.
      final loaded = await DoRepository.instance.getById('h1');
      expect(loaded, isNotNull);
      expect(loaded!.pausedUntil, equals(pauseAt));
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

  group('DoRepository persistence-across-restart (v1.4m / SYS-127)', () {
    test('soft-delete survives close + reopen of the in-memory DB', () async {
      // The "tombstone persists across app restart"
      // property is the v1.4l invariant. The Drift SQL
      // `UPDATE` that sets `deleted_at_millis` commits
      // before the DB is closed; a fresh DB that is
      // hand-seeded with the same row bytes (raw SQL)
      // observes the same tombstone.
      //
      // The test mirrors the v1.4l `migration_v3_to_v4`
      // fixture pattern (`test/db/migration_v3_to_v4_test.dart`)
      // but in miniature: open → softDelete → close →
      // reopen → seed row with the same tombstone →
      // assert.
      await DoRepository.instance.save(_do(id: 'h1', name: 'Stretch'));
      final at = DateTime(2026, 6, 27);
      await DoRepository.instance.softDeleteById('h1', at: at);

      // Close the in-memory DB.
      await AppDatabaseService.instance.closeForTesting();

      // Re-open with a fresh in-memory DB + hand-seed
      // the tombstoned row.
      final freshDb = AppDatabase(NativeDatabase.memory());
      await AppDatabaseService.instance.init(overrideDb: freshDb);
      await AppDatabaseService.instance.ready;

      final deletedAtMillis = at.millisecondsSinceEpoch;
      await freshDb.customStatement(
        'INSERT INTO habits (id, name, proof_mode, '
        'created_at_millis, rest_days_per_month, '
        'schedule_type, weekdays, deleted_at_millis) '
        "VALUES ('h1', 'Stretch', 'soft', 1747526400000, "
        "2, 'fixed', '1,2,3,4,5,6,7', $deletedAtMillis)",
      );

      // The "restarted" app must observe the tombstone.
      final stillTombstoned = await DoRepository.instance.getById('h1');
      expect(stillTombstoned, isNotNull);
      expect(stillTombstoned!.isDeleted, isTrue);
      expect(stillTombstoned.deletedAt, at);

      // The UI perspective filters it out.
      final uiPerspective = await DoRepository.instance.getActiveById('h1');
      expect(uiPerspective, isNull);

      // And `listAll` excludes it.
      final allActive = await DoRepository.instance.listAll();
      expect(allActive, isEmpty);

      // The restore path still works.
      final restored = await DoRepository.instance.restoreById('h1');
      expect(restored, isTrue);
      final afterRestore = await DoRepository.instance.getActiveById('h1');
      expect(afterRestore, isNotNull);
      expect(afterRestore!.isDeleted, isFalse);
    });
  });

  group('DoRepository listDeleted (v1.4m / SYS-127)', () {
    test('listDeleted excludes active habits', () async {
      // Arrange — one active + one tombstoned do.
      await DoRepository.instance.save(_do(id: 'h-active', name: 'Active'));
      await DoRepository.instance.save(_do(id: 'h-deleted', name: 'Deleted'));
      await DoRepository.instance.softDeleteById(
        'h-deleted',
        at: DateTime(2026, 6, 27),
      );

      // Act
      final deleted = await DoRepository.instance.listDeleted();

      // Assert
      expect(deleted.map((d) => d.id), <String>['h-deleted']);
      expect(deleted.single.isDeleted, isTrue);
      expect(deleted.single.deletedAt, DateTime(2026, 6, 27));
    });

    test(
      'listDeleted returns tombstoned habits with descending deletedAt',
      () async {
        // Arrange — 3 tombstones with different deletedAt
        // timestamps. The order MUST be newest-first.
        await DoRepository.instance.save(_do(id: 'h-old', name: 'Old'));
        await DoRepository.instance.save(_do(id: 'h-mid', name: 'Mid'));
        await DoRepository.instance.save(_do(id: 'h-new', name: 'New'));
        await DoRepository.instance.softDeleteById(
          'h-old',
          at: DateTime(2026, 6, 20),
        );
        await DoRepository.instance.softDeleteById(
          'h-mid',
          at: DateTime(2026, 6, 25),
        );
        await DoRepository.instance.softDeleteById(
          'h-new',
          at: DateTime(2026, 6, 27),
        );

        // Act
        final deleted = await DoRepository.instance.listDeleted();

        // Assert — descending by deletedAt.
        expect(deleted.map((d) => d.id), <String>['h-new', 'h-mid', 'h-old']);
      },
    );

    test('listDeleted respects the limit parameter', () async {
      // Arrange — 3 tombstones; ask for the 2 newest.
      await DoRepository.instance.save(_do(id: 'h1', name: 'One'));
      await DoRepository.instance.save(_do(id: 'h2', name: 'Two'));
      await DoRepository.instance.save(_do(id: 'h3', name: 'Three'));
      await DoRepository.instance.softDeleteById(
        'h1',
        at: DateTime(2026, 6, 20),
      );
      await DoRepository.instance.softDeleteById(
        'h2',
        at: DateTime(2026, 6, 25),
      );
      await DoRepository.instance.softDeleteById(
        'h3',
        at: DateTime(2026, 6, 27),
      );

      // Act
      final top2 = await DoRepository.instance.listDeleted(limit: 2);

      // Assert — only the 2 newest are returned.
      expect(top2.map((d) => d.id), <String>['h3', 'h2']);
    });

    test('listDeleted is empty when no tombstones exist', () async {
      // Arrange — only active habits.
      await DoRepository.instance.save(_do(id: 'h-active'));

      // Act
      final deleted = await DoRepository.instance.listDeleted();

      // Assert
      expect(deleted, isEmpty);
    });
  });

  group('DoRepository purgeDeletedOlderThan (v1.4m / SYS-127)', () {
    test('hard-deletes tombstones older than the cutoff', () async {
      // Arrange — 2 tombstones: one old, one recent.
      await DoRepository.instance.save(_do(id: 'h-old', name: 'Old'));
      await DoRepository.instance.save(_do(id: 'h-recent', name: 'Recent'));
      await DoRepository.instance.softDeleteById(
        'h-old',
        at: DateTime(2026, 5, 15),
      );
      await DoRepository.instance.softDeleteById(
        'h-recent',
        at: DateTime(2026, 6, 20),
      );

      // Act — purge with a 30-day cutoff relative to 2026-06-27.
      final purgeAt = DateTime(2026, 6, 27);
      final purged = await DoRepository.instance.purgeDeletedOlderThan(
        const Duration(days: 30),
        at: purgeAt,
      );

      // Assert — h-old is gone (purged), h-recent stays.
      expect(purged, 1);
      final after = await DoRepository.instance.listDeleted();
      expect(after.map((d) => d.id), <String>['h-recent']);
      // And the old one is hard-deleted (no row at all).
      final oldRow = await DoRepository.instance.getById('h-old');
      expect(oldRow, isNull);
    });

    test('leaves younger tombstones alone', () async {
      // Arrange — 2 tombstones, both within the 30-day
      // window.
      await DoRepository.instance.save(_do(id: 'h1', name: 'One'));
      await DoRepository.instance.save(_do(id: 'h2', name: 'Two'));
      await DoRepository.instance.softDeleteById(
        'h1',
        at: DateTime(2026, 6, 25),
      );
      await DoRepository.instance.softDeleteById(
        'h2',
        at: DateTime(2026, 6, 26),
      );

      // Act
      final purged = await DoRepository.instance.purgeDeletedOlderThan(
        const Duration(days: 30),
        at: DateTime(2026, 6, 27),
      );

      // Assert — nothing was purged.
      expect(purged, 0);
      final after = await DoRepository.instance.listDeleted();
      expect(after.map((d) => d.id), containsAll(<String>['h1', 'h2']));
    });

    test('does NOT touch active habits', () async {
      // Arrange — 1 active + 1 tombstoned, both within the
      // cutoff.
      await DoRepository.instance.save(_do(id: 'h-active', name: 'Active'));
      await DoRepository.instance.save(_do(id: 'h-deleted', name: 'Deleted'));
      await DoRepository.instance.softDeleteById(
        'h-deleted',
        at: DateTime(2026, 6, 26),
      );

      // Act
      final purged = await DoRepository.instance.purgeDeletedOlderThan(
        const Duration(days: 30),
        at: DateTime(2026, 6, 27),
      );

      // Assert — active habit is preserved.
      expect(purged, 0);
      final active = await DoRepository.instance.getActiveById('h-active');
      expect(active, isNotNull);
      expect(active!.isDeleted, isFalse);
    });

    test('purge is idempotent when nothing matches', () async {
      // Arrange — no tombstones at all.
      await DoRepository.instance.save(_do(id: 'h-active'));

      // Act
      final purged = await DoRepository.instance.purgeDeletedOlderThan(
        const Duration(days: 30),
        at: DateTime(2026, 6, 27),
      );

      // Assert — purge returns 0, active habit is intact.
      expect(purged, 0);
      final active = await DoRepository.instance.listAll();
      expect(active.map((d) => d.id), <String>['h-active']);
    });
  });
}
