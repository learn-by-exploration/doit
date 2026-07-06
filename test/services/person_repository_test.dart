// Tests for [PersonRepository] — round-trips for all 4 cadence
// types and 5 channels.

import 'package:doit/people/cadence.dart';
import 'package:doit/people/person.dart';
import 'package:doit/routines/routine.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/person_repository.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
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

    // ---- v1.6-ζ additions (automations_json encode/decode round-trip
    // + ChannelTelegram username-as-handle preservation) ----

    test(
      '_toRow writes automationsJson=null when automations is empty',
      () async {
        final p = ContactPerson(
          id: 'p-empty-auto',
          lookupKey: 'k-empty-auto',
          channel: const ChannelDialer('+1'),
          cadence: const EveryNDays(1),
          createdAt: DateTime(2026),
          // automations omitted -> default const [].
        );
        await PersonRepository.instance.save(p);
        final db = AppDatabaseService.instance.db;
        final row = await (db.select(
          db.people,
        )..where((t) => t.id.equals('p-empty-auto'))).getSingle();
        expect(
          row.automationsJson,
          isNull,
          reason:
              'An empty automations list must persist as NULL — not as the '
              'literal string "[]" — so the decode path can short-circuit.',
        );
      },
    );

    test('_fromRow reads automationsJson=null into an empty list', () async {
      final db = AppDatabaseService.instance.db;
      await db
          .into(db.people)
          .insert(
            const PersonRow(
              id: 'p-null-auto',
              lookupKey: 'k-null-auto',
              displayName: '',
              channel: 'dialer',
              handle: '+1',
              createdAtMillis: 0,
              cadenceType: 'every_n_days',
              nDays: 1,
              anchoredToWakeup: false,
              // automationsJson intentionally omitted -> default null.
            ),
          );
      final back =
          await PersonRepository.instance.getById('p-null-auto')
              as ContactPerson;
      expect(back.automations, isEmpty);
    });

    test('_fromRow reads automationsJson="" into an empty list', () async {
      final db = AppDatabaseService.instance.db;
      await db
          .into(db.people)
          .insert(
            const PersonRow(
              id: 'p-empty-string-auto',
              lookupKey: 'k-empty-string-auto',
              displayName: '',
              channel: 'dialer',
              handle: '+1',
              createdAtMillis: 0,
              cadenceType: 'every_n_days',
              nDays: 1,
              anchoredToWakeup: false,
              automationsJson: '',
            ),
          );
      final back =
          await PersonRepository.instance.getById('p-empty-string-auto')
              as ContactPerson;
      expect(
        back.automations,
        isEmpty,
        reason:
            'The empty-string fallback in decodeAutomationList must yield '
            'an empty list (symmetric to the null-input path).',
      );
    });

    test('round-trips a single LocationEnter automation', () async {
      final automation = Automation(
        trigger: const TriggerLocationEnter(
          geofenceId: 'gf1',
          label: 'Home',
          latitude: 47.6,
          longitude: -122.3,
          radiusMeters: 100,
        ),
        action: const ActionNotify(title: 'Arrived', body: 'Welcome home'),
      );
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p-loc',
          lookupKey: 'k-loc',
          channel: const ChannelDialer('+15555550111'),
          cadence: const EveryNDays(7),
          createdAt: DateTime(2026),
          automations: [automation],
        ),
      );
      final back =
          await PersonRepository.instance.getById('p-loc') as ContactPerson;
      expect(back.automations, hasLength(1));
      final got = back.automations.single;
      expect(got.trigger, isA<TriggerLocationEnter>());
      final t = got.trigger as TriggerLocationEnter;
      expect(t.geofenceId, 'gf1');
      expect(t.label, 'Home');
      expect(t.radiusMeters, 100);
      expect(got.action, isA<ActionNotify>());
      expect((got.action as ActionNotify).title, 'Arrived');
    });

    test('round-trips a single CalendarEventStart automation', () async {
      final automation = Automation(
        trigger: const TriggerCalendarEventStart(
          calendarId: 'cal1',
          eventTitle: 'Standup',
        ),
        action: const ActionNotify(title: 'Meeting', body: 'Starting now'),
      );
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p-cal',
          lookupKey: 'k-cal',
          channel: const ChannelDialer('+15555550112'),
          cadence: const EveryNDays(7),
          createdAt: DateTime(2026),
          automations: [automation],
        ),
      );
      final back =
          await PersonRepository.instance.getById('p-cal') as ContactPerson;
      expect(back.automations, hasLength(1));
      final got = back.automations.single;
      expect(got.trigger, isA<TriggerCalendarEventStart>());
      final t = got.trigger as TriggerCalendarEventStart;
      expect(t.calendarId, 'cal1');
      expect(t.eventTitle, 'Standup');
    });

    test('round-trips a mixed list of automations in declared order', () async {
      final first = Automation(
        trigger: const TriggerLocationEnter(
          geofenceId: 'gf1',
          label: 'Gym',
          latitude: 47.6,
          longitude: -122.3,
          radiusMeters: 50,
        ),
        action: const ActionNotify(title: 'At the gym', body: 'Workout'),
      );
      final second = Automation(
        trigger: const TriggerCalendarEventStart(
          calendarId: 'cal2',
          eventTitle: 'Lunch',
        ),
        action: const ActionNotify(title: 'Lunch', body: 'Eat well'),
      );
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p-mixed',
          lookupKey: 'k-mixed',
          channel: const ChannelDialer('+15555550113'),
          cadence: const EveryNDays(7),
          createdAt: DateTime(2026),
          automations: [first, second],
        ),
      );
      final back =
          await PersonRepository.instance.getById('p-mixed') as ContactPerson;
      expect(back.automations, hasLength(2));
      expect(back.automations[0].trigger, isA<TriggerLocationEnter>());
      expect(back.automations[1].trigger, isA<TriggerCalendarEventStart>());
      // Equality is on the full (id, trigger, condition, action,
      // enabled) tuple per Automation's == implementation, so we
      // round-trip cleanly only if encodeAutomationList preserves
      // the order.
      expect(back.automations[0], first);
      expect(back.automations[1], second);
    });

    test(
      'decodes a hand-written automationsJson array into Automations',
      () async {
        // Hand-write the JSON envelope so this test pins the decode
        // path independently of the encode path (no round-trip
        // symmetry assumption).
        const raw =
            '['
            '{'
            '"id":"a1",'
            '"trigger":{"type":"timeOfDay","hour":9,"minute":0},'
            '"condition":null,'
            '"action":{"type":"notify","title":"Wake","body":"Up"},'
            '"enabled":true'
            '}'
            ']';
        final db = AppDatabaseService.instance.db;
        await db
            .into(db.people)
            .insert(
              const PersonRow(
                id: 'p-hand-json',
                lookupKey: 'k-hand-json',
                displayName: '',
                channel: 'dialer',
                handle: '+1',
                createdAtMillis: 0,
                cadenceType: 'every_n_days',
                nDays: 1,
                anchoredToWakeup: false,
                automationsJson: raw,
              ),
            );
        final back =
            await PersonRepository.instance.getById('p-hand-json')
                as ContactPerson;
        expect(back.automations, hasLength(1));
        final got = back.automations.single;
        expect(got.id, 'a1');
        expect(got.trigger, isA<TriggerTimeOfDay>());
        final t = got.trigger as TriggerTimeOfDay;
        expect(t.hour, 9);
        expect(t.minute, 0);
        expect(got.action, isA<ActionNotify>());
        expect((got.action as ActionNotify).title, 'Wake');
      },
    );

    test('ChannelTelegram preserves the username as the handle', () async {
      const username = 'alice_t';
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p-tg',
          lookupKey: 'k-tg',
          channel: const ChannelTelegram(username),
          cadence: const EveryNDays(7),
          createdAt: DateTime(2026),
        ),
      );
      final back =
          await PersonRepository.instance.getById('p-tg') as ContactPerson;
      expect(back.channel, isA<ChannelTelegram>());
      final c = back.channel as ChannelTelegram;
      expect(
        c.username,
        username,
        reason:
            'ChannelTelegram is the only channel with a non-phone handle '
            '(it is keyed on username, not phoneNumber); the (tag, handle) '
            'mapping must funnel it through correctly.',
      );
    });

    // ---- v1.7-β additions (SYS-158 / ADR-089 / WF-086):
    // Raw-column write-path + read-path default pins +
    // column-overload isolation + forward-compat throw pin.
    //
    // Per ADR-089 lesson (a): the v0.1 form at
    // lib/screens/add_person.dart:7-10 only renders EveryNDays +
    // ChannelDialer, so we cannot exercise the alternate cadences /
    // channels via UI tests. The raw-column tests below pin the
    // (tag, handle) and (cadenceType, nDays/weekday/dayOfMonth/
    // monthOfYear) mappings at the Drift layer where the wiring
    // DOES exist. NO production-code change.

    test(
      '_toRow writes channel="dialer" and handle=phoneNumber on the row',
      () async {
        // v1.7-β (SYS-158): raw-column pin for ChannelDialer. The
        // existing typed round-trip test exercises the model layer;
        // this test pins the raw-column string form so a future
        // refactor that swaps the discriminator string (e.g.,
        // 'dialer' → 'phone') fails loudly.
        await PersonRepository.instance.save(
          ContactPerson(
            id: 'p-rc-dialer',
            lookupKey: 'k-rc-dialer',
            channel: const ChannelDialer('+15555550100'),
            cadence: const EveryNDays(1),
            createdAt: DateTime(2026),
          ),
        );
        final db = AppDatabaseService.instance.db;
        final row = await (db.select(
          db.people,
        )..where((t) => t.id.equals('p-rc-dialer'))).getSingle();
        expect(row.channel, 'dialer');
        expect(row.handle, '+15555550100');
      },
    );

    test(
      '_toRow writes channel="whatsapp" and handle=phoneNumber on the row',
      () async {
        await PersonRepository.instance.save(
          ContactPerson(
            id: 'p-rc-whatsapp',
            lookupKey: 'k-rc-whatsapp',
            channel: const ChannelWhatsApp('+15555550101'),
            cadence: const EveryNDays(1),
            createdAt: DateTime(2026),
          ),
        );
        final db = AppDatabaseService.instance.db;
        final row = await (db.select(
          db.people,
        )..where((t) => t.id.equals('p-rc-whatsapp'))).getSingle();
        expect(row.channel, 'whatsapp');
        expect(row.handle, '+15555550101');
      },
    );

    test(
      '_toRow writes channel="telegram" and handle=username on the row',
      () async {
        // ChannelTelegram is the only channel with a non-phone
        // handle. The v1.6-ζ cycle pinned the typed round-trip;
        // this test pins the raw-column form separately so the
        // (tag, handle) mapping at person_repository.dart:94 is
        // also covered.
        await PersonRepository.instance.save(
          ContactPerson(
            id: 'p-rc-telegram',
            lookupKey: 'k-rc-telegram',
            channel: const ChannelTelegram('alice'),
            cadence: const EveryNDays(1),
            createdAt: DateTime(2026),
          ),
        );
        final db = AppDatabaseService.instance.db;
        final row = await (db.select(
          db.people,
        )..where((t) => t.id.equals('p-rc-telegram'))).getSingle();
        expect(row.channel, 'telegram');
        expect(row.handle, 'alice');
      },
    );

    test(
      '_toRow writes channel="signal" and handle=phoneNumber on the row',
      () async {
        await PersonRepository.instance.save(
          ContactPerson(
            id: 'p-rc-signal',
            lookupKey: 'k-rc-signal',
            channel: const ChannelSignal('+15555550102'),
            cadence: const EveryNDays(1),
            createdAt: DateTime(2026),
          ),
        );
        final db = AppDatabaseService.instance.db;
        final row = await (db.select(
          db.people,
        )..where((t) => t.id.equals('p-rc-signal'))).getSingle();
        expect(row.channel, 'signal');
        expect(row.handle, '+15555550102');
      },
    );

    test(
      '_toRow writes channel="sms" and handle=phoneNumber on the row',
      () async {
        await PersonRepository.instance.save(
          ContactPerson(
            id: 'p-rc-sms',
            lookupKey: 'k-rc-sms',
            channel: const ChannelSms('+15555550103'),
            cadence: const EveryNDays(1),
            createdAt: DateTime(2026),
          ),
        );
        final db = AppDatabaseService.instance.db;
        final row = await (db.select(
          db.people,
        )..where((t) => t.id.equals('p-rc-sms'))).getSingle();
        expect(row.channel, 'sms');
        expect(row.handle, '+15555550103');
      },
    );

    test(
      '_toRow writes cadenceType="weekly_on" and weekday=N on the row',
      () async {
        await PersonRepository.instance.save(
          ContactPerson(
            id: 'p-rc-weekly',
            lookupKey: 'k-rc-weekly',
            channel: const ChannelDialer('+1'),
            cadence: const WeeklyOn(3),
            createdAt: DateTime(2026),
          ),
        );
        final db = AppDatabaseService.instance.db;
        final row = await (db.select(
          db.people,
        )..where((t) => t.id.equals('p-rc-weekly'))).getSingle();
        expect(row.cadenceType, 'weekly_on');
        expect(row.weekday, 3);
      },
    );

    test(
      '_toRow writes cadenceType="monthly_on" and dayOfMonth=N on the row',
      () async {
        await PersonRepository.instance.save(
          ContactPerson(
            id: 'p-rc-monthly',
            lookupKey: 'k-rc-monthly',
            channel: const ChannelDialer('+1'),
            cadence: const MonthlyOn(15),
            createdAt: DateTime(2026),
          ),
        );
        final db = AppDatabaseService.instance.db;
        final row = await (db.select(
          db.people,
        )..where((t) => t.id.equals('p-rc-monthly'))).getSingle();
        expect(row.cadenceType, 'monthly_on');
        expect(row.dayOfMonth, 15);
      },
    );

    test('_toRow writes cadenceType="yearly_on" and both monthOfYear=M '
        'and dayOfMonth=D on the row', () async {
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p-rc-yearly',
          lookupKey: 'k-rc-yearly',
          channel: const ChannelDialer('+1'),
          cadence: const YearlyOn(7, 4),
          createdAt: DateTime(2026),
        ),
      );
      final db = AppDatabaseService.instance.db;
      final row = await (db.select(
        db.people,
      )..where((t) => t.id.equals('p-rc-yearly'))).getSingle();
      expect(row.cadenceType, 'yearly_on');
      expect(row.monthOfYear, 7);
      expect(row.dayOfMonth, 4);
    });

    test('_monthlyDay and _yearlyDay share the dayOfMonth column — '
        'each subtype reads back its own value', () async {
      // v1.7-β (SYS-158): pin the column overload at
      // person_repository.dart:66 where `_monthlyDay(p.cadence) ??
      // _yearlyDay(p.cadence)` decides which subtype's value lands
      // in the shared `dayOfMonth` column. Insert two rows with
      // distinct `dayOfMonth` values (15 for MonthlyOn, 4 for
      // YearlyOn day) and verify each subtype round-trips with
      // its OWN value, not the other subtype's.
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p-col-monthly',
          lookupKey: 'k-col-monthly',
          channel: const ChannelDialer('+1'),
          cadence: const MonthlyOn(15),
          createdAt: DateTime(2026),
        ),
      );
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p-col-yearly',
          lookupKey: 'k-col-yearly',
          channel: const ChannelDialer('+2'),
          cadence: const YearlyOn(7, 4),
          createdAt: DateTime(2026),
        ),
      );
      final monthly =
          await PersonRepository.instance.getById('p-col-monthly')
              as ContactPerson;
      final yearly =
          await PersonRepository.instance.getById('p-col-yearly')
              as ContactPerson;
      expect(monthly.cadence, isA<MonthlyOn>());
      expect((monthly.cadence as MonthlyOn).dayOfMonth, 15);
      expect(yearly.cadence, isA<YearlyOn>());
      final y = yearly.cadence as YearlyOn;
      expect(y.month, 7);
      expect(y.day, 4);
      // Sanity: the two values must NOT have been swapped
      // (defense against a future refactor that collapses the
      // overload with a `??` precedence bug).
      expect(y.day, isNot(15));
      expect((monthly.cadence as MonthlyOn).dayOfMonth, isNot(4));
    });

    test('_fromRow defaults nDays=1 when cadenceType="every_n_days" '
        'but nDays is null', () async {
      // v1.7-β (SYS-158): pin the `?? 1` fallback at
      // person_repository.dart:134. Hand-write a row whose
      // `cadenceType` is `every_n_days` but whose `nDays`
      // column is null (defense-in-depth for partial writes
      // from older app versions or hand-imported rows).
      final db = AppDatabaseService.instance.db;
      await db
          .into(db.people)
          .insert(
            const PersonRow(
              id: 'p-null-ndays',
              lookupKey: 'k-null-ndays',
              displayName: '',
              channel: 'dialer',
              handle: '+1',
              createdAtMillis: 0,
              cadenceType: 'every_n_days',
              // nDays omitted → null → exercises the `?? 1` fallback at
              // person_repository.dart:134.
              anchoredToWakeup: false,
            ),
          );
      final back =
          await PersonRepository.instance.getById('p-null-ndays')
              as ContactPerson;
      expect(back.cadence, isA<EveryNDays>());
      expect((back.cadence as EveryNDays).nDays, 1);
    });

    test('_fromRow defaults weekday=1 when cadenceType="weekly_on" '
        'but weekday is null', () async {
      final db = AppDatabaseService.instance.db;
      await db
          .into(db.people)
          .insert(
            const PersonRow(
              id: 'p-null-weekday',
              lookupKey: 'k-null-weekday',
              displayName: '',
              channel: 'dialer',
              handle: '+1',
              createdAtMillis: 0,
              cadenceType: 'weekly_on',
              // weekday omitted → null → exercises the `?? 1` fallback at
              // person_repository.dart:136.
              anchoredToWakeup: false,
            ),
          );
      final back =
          await PersonRepository.instance.getById('p-null-weekday')
              as ContactPerson;
      expect(back.cadence, isA<WeeklyOn>());
      expect((back.cadence as WeeklyOn).weekday, 1);
    });

    test('_fromRow defaults dayOfMonth=1 when cadenceType="monthly_on" '
        'but dayOfMonth is null', () async {
      final db = AppDatabaseService.instance.db;
      await db
          .into(db.people)
          .insert(
            const PersonRow(
              id: 'p-null-monthly',
              lookupKey: 'k-null-monthly',
              displayName: '',
              channel: 'dialer',
              handle: '+1',
              createdAtMillis: 0,
              cadenceType: 'monthly_on',
              // dayOfMonth omitted → null → exercises the `?? 1`
              // fallback at person_repository.dart:138.
              anchoredToWakeup: false,
            ),
          );
      final back =
          await PersonRepository.instance.getById('p-null-monthly')
              as ContactPerson;
      expect(back.cadence, isA<MonthlyOn>());
      expect((back.cadence as MonthlyOn).dayOfMonth, 1);
    });

    test('_fromRow defaults monthOfYear=1 and dayOfMonth=1 when '
        'cadenceType="yearly_on" but both columns are null', () async {
      // v1.7-β (SYS-158): the yearly case has TWO null-defaults
      // (monthOfYear and dayOfMonth). Pin both at
      // person_repository.dart:140 in a single test.
      final db = AppDatabaseService.instance.db;
      await db
          .into(db.people)
          .insert(
            const PersonRow(
              id: 'p-null-yearly',
              lookupKey: 'k-null-yearly',
              displayName: '',
              channel: 'dialer',
              handle: '+1',
              createdAtMillis: 0,
              cadenceType: 'yearly_on',
              // monthOfYear + dayOfMonth omitted → both null →
              // exercises the two `?? 1` fallbacks at
              // person_repository.dart:140.
              anchoredToWakeup: false,
            ),
          );
      final back =
          await PersonRepository.instance.getById('p-null-yearly')
              as ContactPerson;
      expect(back.cadence, isA<YearlyOn>());
      final y = back.cadence as YearlyOn;
      expect(y.month, 1);
      expect(y.day, 1);
    });

    test('_parseChannel rejects "email" as an unknown tag with '
        'ArgumentError', () async {
      // v1.7-β (SYS-158): the v1.6-ζ 'slack'-tag throw test pinned
      // the `_` default arm at person_repository.dart:107 for one
      // specific unknown tag. Pin a SECOND unknown tag here so the
      // default arm isn't accidentally weakened to a no-op (e.g.,
      // a future refactor that adds `if (tag == 'email') return
      // ChannelEmail(...)`).
      final db = AppDatabaseService.instance.db;
      await db
          .into(db.people)
          .insert(
            const PersonRow(
              id: 'p-unknown-email',
              lookupKey: 'k-unknown-email',
              displayName: '',
              channel: 'email', // not in the v0.1 set
              handle: 'alice@example.com',
              createdAtMillis: 0,
              cadenceType: 'every_n_days',
              nDays: 1,
              anchoredToWakeup: false,
            ),
          );
      await expectLater(
        PersonRepository.instance.getById('p-unknown-email'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message?.toString() ?? '',
            'message',
            contains('channel'),
          ),
        ),
      );
    });
  });
}
