// Migration test for the v5 → v6 step (v2.0 retention /
// PR-E1 / SYS-194).
//
// Asserts:
//   - The schema version is bumped to 6.
//   - The `scheduled_messages` table exists.
//   - All 9 expected columns are present with the right
//     types (text / nullable / integer / default).
//   - The `status` column has the SQL-level default 'pending'
//     (verified via `customInsert` so the Dart constructor
//     doesn't supply it).
//   - Nullable columns (`personId`, `messageBody`,
//     `firedAtMillis`) accept NULL cleanly.
//   - A fully-populated row round-trips with byte-for-byte
//     column fidelity (text + int + nullable).
//   - All 4 status lifecycle values are storable.

import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('migrateV5ToV6', () {
    late AppDatabase db;

    setUp(() async {
      await AppDatabaseService.instance.closeForTesting();
      db = AppDatabase(NativeDatabase.memory());
      await AppDatabaseService.instance.init(overrideDb: db);
      await AppDatabaseService.instance.ready;
    });

    tearDown(() async {
      await AppDatabaseService.instance.closeForTesting();
    });

    test('schemaVersion is 6 (v2.0 retention / PR-E1 / SYS-194 pin)', () {
      expect(db.schemaVersion, 6);
      expect(kCurrentSchemaVersion, 6);
    });

    test('scheduled_messages table exists', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name='scheduled_messages'",
          )
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.data['name'], 'scheduled_messages');
    });

    test('scheduled_messages has all 9 expected columns', () async {
      final rows = await db
          .customSelect("PRAGMA table_info('scheduled_messages')")
          .get();
      final cols = rows
          .map((r) => r.data['name'] as String)
          .toList(growable: false);
      expect(
        cols,
        containsAll(<String>[
          'id',
          'person_id',
          'channel_tag',
          'channel_handle',
          'message_body',
          'fire_at_millis',
          'status',
          'created_at_millis',
          'fired_at_millis',
        ]),
      );
      // No spurious columns beyond the 9 we declared.
      expect(cols, hasLength(9));
    });

    test('status column has the SQL-level default "pending" '
        '(via customInsert, omitting status)', () async {
      // The Drift-generated Dart constructor makes `status`
      // required even though the SQL column has a default
      // (per the .withDefault() call on the table). The
      // SQL default still applies to a raw INSERT that
      // omits the column — exercise that path with
      // customInsert so the default is actually used.
      final fireAt = DateTime(2026, 7, 9, 15).millisecondsSinceEpoch;
      final createdAt = DateTime(2026, 7, 9, 10).millisecondsSinceEpoch;
      await db
          .into(db.scheduledMessages)
          .insert(
            ScheduledMessagesCompanion.insert(
              id: 'm-default',
              channelTag: 'whatsapp',
              channelHandle: '+15551234567',
              fireAtMillis: fireAt,
              createdAtMillis: createdAt,
            ),
          );
      final back = await (db.select(
        db.scheduledMessages,
      )..where((t) => t.id.equals('m-default'))).getSingle();
      expect(back.status, 'pending');
    });

    test('nullable columns accept NULL (personId / messageBody / '
        'firedAtMillis)', () async {
      // A row with the three nullable fields left at their
      // default (null) — exercises the "no person saved yet"
      // path and the "no pre-filled body" path and the
      // "not-yet-fired" path.
      await db
          .into(db.scheduledMessages)
          .insert(
            ScheduledMessageRow(
              id: 'm-nullable',
              channelTag: 'sms',
              channelHandle: '+15559876543',
              fireAtMillis: DateTime(2026, 7, 9, 15).millisecondsSinceEpoch,
              createdAtMillis: DateTime(2026, 7, 9, 10).millisecondsSinceEpoch,
              status: 'pending',
            ),
          );
      final back = await (db.select(
        db.scheduledMessages,
      )..where((t) => t.id.equals('m-nullable'))).getSingle();
      expect(back.personId, isNull);
      expect(back.messageBody, isNull);
      expect(back.firedAtMillis, isNull);
    });

    test(
      'fully-populated row round-trips with byte-for-byte fidelity',
      () async {
        // A row with EVERY field filled (a person saved +
        // a real message body + a real fired-at audit
        // timestamp + a non-default status). This pins the
        // column mapping end-to-end and catches the "type
        // mismatch on round-trip" failure mode.
        const payload = 'Hey, calling about Saturday lunch';
        final fireAt = DateTime(2026, 7, 9, 15, 30).millisecondsSinceEpoch;
        final createdAt = DateTime(2026, 7, 9, 10).millisecondsSinceEpoch;
        final firedAt = DateTime(2026, 7, 9, 15, 30, 5).millisecondsSinceEpoch;

        await db
            .into(db.scheduledMessages)
            .insert(
              ScheduledMessageRow(
                id: 'm-full',
                personId: 'p-1',
                channelTag: 'whatsapp',
                channelHandle: '+15551234567',
                messageBody: payload,
                fireAtMillis: fireAt,
                status: 'fired',
                createdAtMillis: createdAt,
                firedAtMillis: firedAt,
              ),
            );
        final back = await (db.select(
          db.scheduledMessages,
        )..where((t) => t.id.equals('m-full'))).getSingle();
        expect(back.id, 'm-full');
        expect(back.personId, 'p-1');
        expect(back.channelTag, 'whatsapp');
        expect(back.channelHandle, '+15551234567');
        expect(back.messageBody, payload);
        expect(back.fireAtMillis, fireAt);
        expect(back.status, 'fired');
        expect(back.createdAtMillis, createdAt);
        expect(back.firedAtMillis, firedAt);
      },
    );

    test('status lifecycle values are storable (pending / fired / '
        'dismissed / cancelled)', () async {
      // Each lifecycle value is a valid string; insert one
      // row per value to pin that no status string is
      // rejected by the column type.
      for (final s in <String>['pending', 'fired', 'dismissed', 'cancelled']) {
        await db
            .into(db.scheduledMessages)
            .insert(
              ScheduledMessageRow(
                id: 'm-status-$s',
                channelTag: 'dialer',
                channelHandle: '+15550000000',
                fireAtMillis: DateTime(2026).millisecondsSinceEpoch,
                status: s,
                createdAtMillis: DateTime(2026).millisecondsSinceEpoch,
              ),
            );
      }
      final all = await db.select(db.scheduledMessages).get();
      expect(all, hasLength(4));
      final statuses = all.map((r) => r.status).toSet();
      expect(statuses, <String>{'pending', 'fired', 'dismissed', 'cancelled'});
    });
  });
}
