// Tests for [PersonRepository] — round-trips for all 4 cadence
// types and 5 channels.

import 'package:doit/people/cadence.dart';
import 'package:doit/people/person.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/person_repository.dart';
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
  });
}
