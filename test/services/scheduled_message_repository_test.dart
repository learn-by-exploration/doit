// Tests for [ScheduledMessageRepository] — CRUD round-trips
// + the 3 query paths (listAll / listPending / pendingFor) +
// the 3 state transitions (save / markFired / cancel).
//
// v1.8-pr-e2 / SYS-196 / ADR-126. The Drift table
// migration shipped in PR-E1 (#104); this is the
// service-layer half.

import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/scheduled_message_repository.dart';
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

ScheduledMessage _row({
  String id = 'sm-1',
  String? personId = 'p1',
  String channelTag = 'whatsapp',
  String channelHandle = '+15555550100',
  String? messageBody = 'hi there',
  DateTime? fireAt,
  DateTime? createdAt,
  ScheduledMessageStatus status = ScheduledMessageStatus.pending,
  DateTime? firedAt,
}) {
  return ScheduledMessage(
    id: id,
    personId: personId,
    channelTag: channelTag,
    channelHandle: channelHandle,
    messageBody: messageBody,
    fireAt: fireAt ?? DateTime.fromMillisecondsSinceEpoch(1735689600000),
    status: status,
    createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(1735603200000),
    firedAt: firedAt,
  );
}

void main() {
  setUp(_init);
  tearDown(_tearDown);

  group('ScheduledMessageRepository.save', () {
    test('round-trips a pending row', () async {
      final original = _row();
      await ScheduledMessageRepository.instance.save(original);
      final back = await ScheduledMessageRepository.instance.getById('sm-1');
      expect(back, isNotNull);
      expect(back!.id, 'sm-1');
      expect(back.personId, 'p1');
      expect(back.channelTag, 'whatsapp');
      expect(back.channelHandle, '+15555550100');
      expect(back.messageBody, 'hi there');
      expect(back.status, ScheduledMessageStatus.pending);
      expect(back.firedAt, isNull);
    });

    test(
      'preserves null personId (one-off schedule without a Person row)',
      () async {
        await ScheduledMessageRepository.instance.save(
          _row(personId: null, messageBody: null),
        );
        final back = await ScheduledMessageRepository.instance.getById('sm-1');
        expect(back, isNotNull);
        expect(back!.personId, isNull);
        expect(back.messageBody, isNull);
      },
    );

    test('save is upsert — second save with same id replaces', () async {
      await ScheduledMessageRepository.instance.save(_row(messageBody: 'a'));
      await ScheduledMessageRepository.instance.save(_row(messageBody: 'b'));
      final back = await ScheduledMessageRepository.instance.getById('sm-1');
      expect(back!.messageBody, 'b');
    });
  });

  group('ScheduledMessageRepository.insert', () {
    test('insert returns the saved row', () async {
      final saved = await ScheduledMessageRepository.instance.insert(
        id: 'sm-insert',
        personId: 'p1',
        channelTag: 'sms',
        channelHandle: '+15555550199',
        messageBody: 'test',
        fireAt: DateTime.fromMillisecondsSinceEpoch(1735689600000),
        createdAt: DateTime.fromMillisecondsSinceEpoch(1735603200000),
      );
      expect(saved.id, 'sm-insert');
      expect(saved.channelTag, 'sms');
      expect(saved.status, ScheduledMessageStatus.pending);
      expect(saved.firedAt, isNull);
    });

    test(
      'omitting status exercises the SQL DEFAULT \'pending\' clause',
      () async {
        // Hand-rolled raw INSERT via customInsert bypasses the
        // Companion.insert() helper, so the SQL DEFAULT fires.
        // The repository's `insert(...)` method always writes
        // `status: pending` explicitly, so this is the only
        // way to exercise the default from a Dart unit test
        // (PR-E1 ADR-125 lesson: `withDefault` does NOT make
        // the generated Dart constructor parameter optional).
        await AppDatabaseService.instance.db
            .into(AppDatabaseService.instance.db.scheduledMessages)
            .insert(
              ScheduledMessagesCompanion.insert(
                id: 'sm-default',
                channelTag: 'whatsapp',
                channelHandle: '+15555550100',
                fireAtMillis: 1735689600000,
                createdAtMillis: 1735603200000,
              ),
            );
        final back = await ScheduledMessageRepository.instance.getById(
          'sm-default',
        );
        expect(back, isNotNull);
        expect(back!.status, ScheduledMessageStatus.pending);
      },
    );
  });

  group('ScheduledMessageRepository queries', () {
    setUp(() async {
      // Insert 4 rows in mixed states for query coverage.
      await ScheduledMessageRepository.instance.save(
        _row(id: 'sm-a', fireAt: DateTime.fromMillisecondsSinceEpoch(1000)),
      );
      await ScheduledMessageRepository.instance.save(
        _row(id: 'sm-b', fireAt: DateTime.fromMillisecondsSinceEpoch(2000)),
      );
      await ScheduledMessageRepository.instance.save(
        _row(
          id: 'sm-c',
          fireAt: DateTime.fromMillisecondsSinceEpoch(3000),
          status: ScheduledMessageStatus.fired,
          firedAt: DateTime.fromMillisecondsSinceEpoch(3001),
        ),
      );
      await ScheduledMessageRepository.instance.save(
        _row(
          id: 'sm-d',
          fireAt: DateTime.fromMillisecondsSinceEpoch(4000),
          status: ScheduledMessageStatus.cancelled,
        ),
      );
    });

    test('listAll returns every row in fireAtMillis ASC order', () async {
      final all = await ScheduledMessageRepository.instance.listAll();
      expect(
        all.map((r) => r.id).toList(),
        equals(['sm-a', 'sm-b', 'sm-c', 'sm-d']),
      );
    });

    test('listPending filters out fired + cancelled rows', () async {
      final pending = await ScheduledMessageRepository.instance.listPending();
      expect(pending.map((r) => r.id).toList(), equals(['sm-a', 'sm-b']));
      expect(pending.every((r) => r.isPending), isTrue);
    });

    test('pendingFor filters by personId AND pending status', () async {
      // Add a 5th row for a different person, pending.
      await ScheduledMessageRepository.instance.save(
        _row(id: 'sm-e', personId: 'p2'),
      );
      final forP1 = await ScheduledMessageRepository.instance.pendingFor('p1');
      expect(forP1.map((r) => r.id).toList(), equals(['sm-a', 'sm-b']));
      final forP2 = await ScheduledMessageRepository.instance.pendingFor('p2');
      expect(forP2.map((r) => r.id).toList(), equals(['sm-e']));
      final forNone = await ScheduledMessageRepository.instance.pendingFor(
        'p-none',
      );
      expect(forNone, isEmpty);
    });
  });

  group('ScheduledMessageRepository transitions', () {
    test('markFired flips status + sets firedAt', () async {
      await ScheduledMessageRepository.instance.save(_row());
      final at = DateTime.fromMillisecondsSinceEpoch(1735776000000);
      await ScheduledMessageRepository.instance.markFired('sm-1', at);
      final back = await ScheduledMessageRepository.instance.getById('sm-1');
      expect(back!.status, ScheduledMessageStatus.fired);
      expect(back.firedAt, at);
    });

    test('cancel flips status to cancelled without setting firedAt', () async {
      await ScheduledMessageRepository.instance.save(_row());
      await ScheduledMessageRepository.instance.cancel('sm-1');
      final back = await ScheduledMessageRepository.instance.getById('sm-1');
      expect(back!.status, ScheduledMessageStatus.cancelled);
      expect(back.firedAt, isNull);
    });

    test('cancel on a missing id is a no-op', () async {
      await ScheduledMessageRepository.instance.cancel('does-not-exist');
      final back = await ScheduledMessageRepository.instance.getById(
        'does-not-exist',
      );
      expect(back, isNull);
    });

    test('deleteById hard-deletes the row', () async {
      await ScheduledMessageRepository.instance.save(_row());
      await ScheduledMessageRepository.instance.deleteById('sm-1');
      final back = await ScheduledMessageRepository.instance.getById('sm-1');
      expect(back, isNull);
    });

    test('deleteForPerson removes every row for that person', () async {
      await ScheduledMessageRepository.instance.save(_row());
      await ScheduledMessageRepository.instance.save(_row(id: 'sm-2'));
      await ScheduledMessageRepository.instance.save(
        _row(id: 'sm-3', personId: 'p2'),
      );
      await ScheduledMessageRepository.instance.deleteForPerson('p1');
      final remaining = await ScheduledMessageRepository.instance.listAll();
      expect(remaining.map((r) => r.id).toList(), equals(['sm-3']));
    });
  });

  group('ScheduledMessageStatus', () {
    test('round-trips every enum value through the wire format', () {
      for (final s in ScheduledMessageStatus.values) {
        expect(ScheduledMessageStatus.fromWire(s.wire), s);
      }
    });

    test('unknown wire value falls back to pending (forward-compat)', () {
      expect(
        ScheduledMessageStatus.fromWire('mystery_status'),
        ScheduledMessageStatus.pending,
      );
    });

    test('isPending and isTerminal getters agree with the enum', () {
      final pending = _row();
      expect(pending.isPending, isTrue);
      expect(pending.isTerminal, isFalse);
      final fired = _row(status: ScheduledMessageStatus.fired);
      expect(fired.isPending, isFalse);
      expect(fired.isTerminal, isTrue);
      final cancelled = _row(status: ScheduledMessageStatus.cancelled);
      expect(cancelled.isPending, isFalse);
      expect(cancelled.isTerminal, isTrue);
    });
  });
}
