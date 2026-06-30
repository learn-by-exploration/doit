// Tests for [PersonRepository] — round-trips for all 4 cadence
// types and 5 channels.

import 'package:doit/people/cadence.dart';
import 'package:doit/people/person.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/person_repository.dart';
// Hand-writing `PersonRow`s for the unknown-channel / unknown-cadence
// throw tests does not require any `package:drift/drift.dart`
// symbols (we use concrete `PersonRow` instances). Note: importing
// the Drift umbrella in this file would collide with
// `package:matcher`'s `isNull` matcher; see the existing
// `backup_task_dispatcher_test.dart` for the same hide.
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

void main() {
  setUp(_init);
  tearDown(_tearDown);

  group('PersonRepository', () {
    test('round-trips a ContactPerson with EveryNDays cadence', () async {
      final p = ContactPerson(
        id: 'p1',
        lookupKey: 'lookup-1',
        channel: const ChannelDialer('+15555550100'),
        cadence: const EveryNDays(3),
        createdAt: DateTime(2026),
      );
      await PersonRepository.instance.save(p);
      final back = await PersonRepository.instance.getById('p1');
      expect(back, isA<ContactPerson>());
      expect((back as ContactPerson).cadence, isA<EveryNDays>());
      expect((back.cadence as EveryNDays).nDays, 3);
      expect(back.channel, isA<ChannelDialer>());
      expect((back.channel as ChannelDialer).phoneNumber, '+15555550100');
    });

    test('round-trips WeeklyOn / MonthlyOn / YearlyOn cadences', () async {
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p2',
          lookupKey: 'lookup-2',
          channel: const ChannelWhatsApp('+15555550101'),
          cadence: const WeeklyOn(3),
          createdAt: DateTime(2026),
        ),
      );
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p3',
          lookupKey: 'lookup-3',
          channel: const ChannelTelegram('alice'),
          cadence: const MonthlyOn(15),
          createdAt: DateTime(2026),
        ),
      );
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p4',
          lookupKey: 'lookup-4',
          channel: const ChannelSignal('+15555550102'),
          cadence: const YearlyOn(7, 4),
          createdAt: DateTime(2026),
        ),
      );

      final w = await PersonRepository.instance.getById('p2') as ContactPerson;
      expect(w.cadence, isA<WeeklyOn>());
      expect((w.cadence as WeeklyOn).weekday, 3);
      expect(w.channel, isA<ChannelWhatsApp>());

      final m = await PersonRepository.instance.getById('p3') as ContactPerson;
      expect(m.cadence, isA<MonthlyOn>());
      expect((m.cadence as MonthlyOn).dayOfMonth, 15);
      expect(m.channel, isA<ChannelTelegram>());

      final y = await PersonRepository.instance.getById('p4') as ContactPerson;
      expect(y.cadence, isA<YearlyOn>());
      final yc = y.cadence as YearlyOn;
      expect(yc.month, 7);
      expect(yc.day, 4);
      expect(y.channel, isA<ChannelSignal>());
    });

    test('ChannelSms round-trips with phone number', () async {
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p5',
          lookupKey: 'lookup-5',
          channel: const ChannelSms('+15555550199'),
          cadence: const EveryNDays(7),
          createdAt: DateTime(2026),
        ),
      );
      final back =
          await PersonRepository.instance.getById('p5') as ContactPerson;
      expect(back.channel, isA<ChannelSms>());
      expect((back.channel as ChannelSms).phoneNumber, '+15555550199');
    });

    test('listAll returns people in createdAt order', () async {
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p1',
          lookupKey: 'k1',
          channel: const ChannelDialer('+1'),
          cadence: const EveryNDays(1),
          createdAt: DateTime(2026),
        ),
      );
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p2',
          lookupKey: 'k2',
          channel: const ChannelDialer('+2'),
          cadence: const EveryNDays(1),
          createdAt: DateTime(2026, 2),
        ),
      );
      final list = await PersonRepository.instance.listAll();
      expect(list.map((p) => p.id), ['p1', 'p2']);
    });

    test('deleteById removes the row', () async {
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p1',
          lookupKey: 'k1',
          channel: const ChannelDialer('+1'),
          cadence: const EveryNDays(1),
          createdAt: DateTime(2026),
        ),
      );
      await PersonRepository.instance.deleteById('p1');
      final back = await PersonRepository.instance.getById('p1');
      expect(back, isNull);
    });

    // v1.2f / Phase 6: round-trip the optional pause
    // (`pausedUntil_millis` column). The read path now
    // round-trips a DateTime through the repository; the
    // UI surfaces it via `_PersonPauseRow` in
    // `add_person.dart` and a per-person "Paused" chip in
    // `person_groups.dart`.
    test('round-trips pausedUntil as millisecondsSinceEpoch', () async {
      final pausedUntil = DateTime(2027, 1, 1, 23, 59);
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p-paused',
          lookupKey: 'k-paused',
          channel: const ChannelDialer('+15555550199'),
          cadence: const EveryNDays(7),
          createdAt: DateTime(2026),
          pausedUntil: pausedUntil,
        ),
      );
      final back =
          await PersonRepository.instance.getById('p-paused') as ContactPerson;
      expect(back.pausedUntil, pausedUntil);
      expect(back.isPausedAt(DateTime(2026, 6)), isTrue);
      expect(back.isPausedAt(DateTime(2028)), isFalse);
    });

    test('clearPausedUntil removes the pause via copyWith', () async {
      final pausedUntil = DateTime(2027, 1, 1, 23, 59);
      final p = ContactPerson(
        id: 'p-cleared',
        lookupKey: 'k-cleared',
        channel: const ChannelDialer('+15555550199'),
        cadence: const EveryNDays(7),
        createdAt: DateTime(2026),
        pausedUntil: pausedUntil,
      );
      final cleared = p.copyWith(clearPausedUntil: true);
      expect(cleared.pausedUntil, isNull);
      // The other fields are preserved.
      expect(cleared.id, 'p-cleared');
      expect(cleared.cadence, const EveryNDays(7));
      expect(cleared.channel, const ChannelDialer('+15555550199'));
    });

    // ---- v1.5-cyc-γ additions (coverage closure) ----

    test('round-trips pausedUntil null when no pause is set', () async {
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p-no-pause',
          lookupKey: 'k-no-pause',
          channel: const ChannelDialer('+1'),
          cadence: const EveryNDays(1),
          createdAt: DateTime(2026),
        ),
      );
      final back =
          await PersonRepository.instance.getById('p-no-pause')
              as ContactPerson;
      expect(back.pausedUntil, isNull);
      expect(back.isPausedAt(DateTime(2026, 6)), isFalse);
      expect(back.isPausedAt(DateTime(2028)), isFalse);
    });

    test('deleteById is a no-op when the row does not exist', () async {
      // Saving nothing + deleting must not throw and must leave
      // the table empty.
      await PersonRepository.instance.deleteById('does-not-exist');
      expect(await PersonRepository.instance.listAll(), isEmpty);
    });

    test('listAll returns [] when the table is empty', () async {
      expect(await PersonRepository.instance.listAll(), isEmpty);
    });

    test('getById returns null for an unknown id', () async {
      expect(await PersonRepository.instance.getById('nope'), isNull);
    });

    test(
      'fetching a row with an unknown channel tag throws ArgumentError',
      () async {
        // Hand-write a row with an unrecognised channel tag to
        // exercise the `_parseChannel` defense-in-depth throw
        // (forward-compat guard for new channel kinds). Only
        // the columns whose values matter for this test are
        // named; the rest fall back to the Drift-generated
        // data-class defaults.
        final db = AppDatabaseService.instance.db;
        await db
            .into(db.people)
            .insert(
              const PersonRow(
                id: 'p-bad-channel',
                lookupKey: 'k-bad',
                displayName: '',
                channel: 'slack', // not in the v0.1 set
                handle: 'u/handle',
                createdAtMillis: 0,
                cadenceType: 'every_n_days',
                nDays: 1,
                anchoredToWakeup: false,
              ),
            );
        await expectLater(
          PersonRepository.instance.getById('p-bad-channel'),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message?.toString() ?? '',
              'message',
              contains('channel'),
            ),
          ),
        );
      },
    );

    test(
      'fetching a row with an unknown cadence type throws ArgumentError',
      () async {
        // Hand-write a row with an unrecognised cadence_type.
        final db = AppDatabaseService.instance.db;
        await db
            .into(db.people)
            .insert(
              const PersonRow(
                id: 'p-bad-cadence',
                lookupKey: 'k-bad-cadence',
                displayName: '',
                channel: 'dialer',
                handle: '+1',
                createdAtMillis: 0,
                cadenceType: 'fortnightly',
                anchoredToWakeup: false,
              ),
            );
        await expectLater(
          PersonRepository.instance.getById('p-bad-cadence'),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });
}
