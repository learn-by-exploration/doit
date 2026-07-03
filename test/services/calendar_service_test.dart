// Tests for CalendarService (v1.0 / Phase E PR 1 / ADR-023).
//
// Coverage:
//   - `init()` is idempotent.
//   - The broadcast events stream republishes every
//     CalendarEvent pushed by the source (start / end /
//     reminder / busy-change).
//   - `lastIsBusy` cache updates only on CalendarBusyChange
//     events.
//   - `listAccounts()` forwards to the source and returns the
//     configured accounts.
//   - `resetForTesting()` cancels the source subscription
//     and stops the source.
//   - A source that throws on `start()` does not crash the
//     service — it surfaces as a rethrown exception (the
//     `_ready` gate cannot complete with a broken source).
//   - Multiple listeners on the broadcast stream all
//     receive every push (the `RoutineExecutor` + future
//     debug screen both need this).

import 'package:doit/services/calendar_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEventStarted calStarted({
  String eventId = 'e1',
  String calendarId = 'cal1',
  String title = 'Standup',
}) => CalendarEventStarted(
  eventId: eventId,
  calendarId: calendarId,
  title: title,
  at: DateTime(2026, 6, 20, 9),
);

CalendarBusyChange calBusy({
  required bool isBusy,
  String eventId = 'e1',
  String calendarId = 'cal1',
}) => CalendarBusyChange(
  eventId: eventId,
  calendarId: calendarId,
  title: 'Standup',
  at: DateTime(2026, 6, 20, 9),
  isBusy: isBusy,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalendarService', () {
    late CalendarService service;
    late ScriptedCalendarSource source;

    setUp(() {
      service = CalendarService.instance;
      service.resetForTesting();
      source = ScriptedCalendarSource(
        accounts: const [
          CalendarAccount(accountId: 'a@x:1', displayName: 'Personal'),
          CalendarAccount(accountId: 'b@y:2', displayName: 'Work'),
        ],
      );
      service.debugSetSource(source);
    });

    tearDown(() {
      service.resetForTesting();
    });

    test('init() is idempotent', () async {
      await service.init();
      await service.init(); // second call must not throw
      expect(source.startCalls, 1, reason: 'start() must run once total.');
    });

    test('events stream republishes every source push', () async {
      await service.init();
      final fired = <CalendarEvent>[];
      final sub = service.events.listen(fired.add);

      source.push(calStarted());
      source.push(calBusy(isBusy: true));
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(2));
      expect(fired[0], isA<CalendarEventStarted>());
      expect(fired[1], isA<CalendarBusyChange>());
      await sub.cancel();
    });

    test('lastIsBusy updates only on CalendarBusyChange events', () async {
      await service.init();
      expect(service.lastIsBusy, isNull);

      source.push(calStarted());
      await Future<void>.delayed(Duration.zero);
      expect(service.lastIsBusy, isNull);

      source.push(calBusy(isBusy: true));
      await Future<void>.delayed(Duration.zero);
      expect(service.lastIsBusy, true);

      source.push(calStarted());
      await Future<void>.delayed(Duration.zero);
      expect(service.lastIsBusy, true);

      source.push(calBusy(isBusy: false));
      await Future<void>.delayed(Duration.zero);
      expect(service.lastIsBusy, false);
    });

    test('listAccounts() returns the source-provided accounts', () async {
      await service.init();
      final accounts = await service.listAccounts();
      expect(accounts, hasLength(2));
      expect(accounts[0].accountId, 'a@x:1');
      expect(accounts[1].displayName, 'Work');
    });

    test(
      'resetForTesting() cancels the subscription and stops the source',
      () async {
        await service.init();
        service.resetForTesting();
        expect(source.stopCalls, 1);
        // A second reset is a no-op (idempotent).
        service.resetForTesting();
        expect(source.stopCalls, 1);
      },
    );

    test('a source that throws on start() rethrows (the ready gate cannot '
        'complete with a broken source)', () async {
      service.resetForTesting();
      final failing = ScriptedCalendarSource()
        ..startError = StateError('plugin missing');
      service.debugSetSource(failing);
      await expectLater(service.init(), throwsA(isA<StateError>()));
    });

    test('multiple listeners all receive every push', () async {
      await service.init();
      final a = <CalendarEvent>[];
      final b = <CalendarEvent>[];
      final sa = service.events.listen(a.add);
      final sb = service.events.listen(b.add);

      source.push(calStarted());
      source.push(calBusy(isBusy: true));
      await Future<void>.delayed(Duration.zero);

      expect(a, hasLength(2));
      expect(b, hasLength(2));
      await sa.cancel();
      await sb.cancel();
    });
  });

  group('CalendarEvent value semantics', () {
    test('CalendarAccount equality on both fields', () {
      const a = CalendarAccount(accountId: 'a@x:1', displayName: 'Work');
      const b = CalendarAccount(accountId: 'a@x:1', displayName: 'Work');
      const c = CalendarAccount(accountId: 'a@x:2', displayName: 'Work');
      const d = CalendarAccount(accountId: 'a@x:1', displayName: 'Personal');
      expect(a, b);
      expect(a, isNot(c));
      expect(a, isNot(d));
      expect(a.hashCode, b.hashCode);
    });
  });

  // ---- v1.5-cyc-γ additions (coverage closure for
  // `_MethodChannelCalendarSource.decode()` + reminder/ended event
  // republishing + `listAccounts` edge cases) ----
  group('ScriptedCalendarSource event republishing (v1.5-cyc-γ)', () {
    late CalendarService service;
    late ScriptedCalendarSource source;

    setUp(() {
      service = CalendarService.instance;
      service.resetForTesting();
      source = ScriptedCalendarSource();
      service.debugSetSource(source);
    });

    tearDown(() => service.resetForTesting());

    test(
      'CalendarEventReminder republishes and does not flip lastIsBusy',
      () async {
        await service.init();
        final fired = <CalendarEvent>[];
        final sub = service.events.listen(fired.add);

        final reminder = CalendarEventReminder(
          eventId: 'e2',
          calendarId: 'cal1',
          title: 'Reminder',
          at: DateTime(2026, 6, 20, 9),
        );
        source.push(reminder);
        await Future<void>.delayed(Duration.zero);

        expect(fired, hasLength(1));
        expect(fired.single, isA<CalendarEventReminder>());
        expect(
          service.lastIsBusy,
          isNull,
          reason: 'Reminders must not write to the busy cache.',
        );
        await sub.cancel();
      },
    );

    test(
      'CalendarEventEnded republishes and does not flip lastIsBusy',
      () async {
        await service.init();
        final fired = <CalendarEvent>[];
        final sub = service.events.listen(fired.add);

        final ended = CalendarEventEnded(
          eventId: 'e3',
          calendarId: 'cal1',
          title: 'Standup',
          at: DateTime(2026, 6, 20, 10),
        );
        source.push(ended);
        await Future<void>.delayed(Duration.zero);

        expect(fired.single, isA<CalendarEventEnded>());
        expect(service.lastIsBusy, isNull);
        await sub.cancel();
      },
    );

    test('all four event types in sequence produce four subscribers', () async {
      await service.init();
      final fired = <CalendarEvent>[];
      final sub = service.events.listen(fired.add);

      source.push(calStarted());
      source.push(
        CalendarEventEnded(
          eventId: 'eX',
          calendarId: 'cal1',
          title: 'Standup',
          at: DateTime(2026, 6, 20, 10),
        ),
      );
      source.push(
        CalendarEventReminder(
          eventId: 'eX',
          calendarId: 'cal1',
          title: 'Standup',
          at: DateTime(2026, 6, 20, 8, 55),
        ),
      );
      source.push(calBusy(isBusy: true));
      await Future<void>.delayed(Duration.zero);

      expect(fired.map((e) => e.runtimeType), [
        CalendarEventStarted,
        CalendarEventEnded,
        CalendarEventReminder,
        CalendarBusyChange,
      ]);
      await sub.cancel();
    });
  });

  group('listAccounts() edge cases (v1.5-cyc-γ)', () {
    late CalendarService service;

    setUp(() {
      service = CalendarService.instance;
      service.resetForTesting();
    });

    tearDown(() => service.resetForTesting());

    test(
      'returns an empty list when the source returns an empty list',
      () async {
        service.debugSetSource(ScriptedCalendarSource());
        await service.init();
        expect(await service.listAccounts(), isEmpty);
      },
    );

    test('passes the configured accounts through verbatim', () async {
      const accounts = [
        CalendarAccount(accountId: 'a1', displayName: 'Personal'),
        CalendarAccount(accountId: 'a2', displayName: 'Family'),
        CalendarAccount(accountId: 'a3', displayName: 'Work'),
      ];
      service.debugSetSource(ScriptedCalendarSource(accounts: accounts));
      await service.init();
      final back = await service.listAccounts();
      expect(back, accounts);
    });
  });

  // _MethodChannelCalendarSource is library-private so it cannot
  // be tested directly from the test/ side. Coverage of its
  // platform-channel surface comes from the on-device smoke in
  // each release cycle (per CLAUDE.md "Pre-approved commands"
  // + the release-apk-pattern memory).

  // ---- v1.6-ζ additions (coverage closure for
  // `_MethodChannelCalendarSource._decode()` + `stop()`
  // MissingPluginException swallow) ----
  //
  // The `_MethodChannelCalendarSource` is library-private so we
  // exercise it through the public `CalendarService.init()`
  // surface with the `doit/calendar` `MethodChannel` mocked via
  // `TestDefaultBinaryMessenger`. We do NOT call
  // `debugSetSource(...)` so `init()` lazily constructs the real
  // production source.

  group('_MethodChannelCalendarSource (v1.6-ζ)', () {
    const channel = MethodChannel('doit/calendar');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = StandardMethodCodec();

    late CalendarService service;

    setUp(() {
      service = CalendarService.instance;
      service.resetForTesting();
      // Allow init() to construct the real _MethodChannelCalendarSource
      // (which sets up the platform-channel handler). The mock returns
      // null for Dart->platform calls (`startStream`, `stopStream`,
      // `listAccounts`).
      messenger.setMockMethodCallHandler(channel, (call) async => null);
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      service.resetForTesting();
    });

    /// Simulate a platform->Dart `onCalendarEvent` push by encoding
    /// the MethodCall and shipping it through the binary messenger.
    /// This is the same wire path the Kotlin `CalendarChannel.kt`
    /// uses to publish events.
    Future<void> pushOnCalendarEvent(Map<String, Object?> args) async {
      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(MethodCall('onCalendarEvent', args)),
        (_) {},
      );
    }

    test('start() invokes startStream on the channel', () async {
      final invoked = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        invoked.add(call.method);
        return null;
      });
      await service.init();
      expect(invoked, contains('startStream'));
    });

    test('handler decodes kind=start into CalendarEventStarted', () async {
      await service.init();
      final fired = <CalendarEvent>[];
      final sub = service.events.listen(fired.add);

      await pushOnCalendarEvent({
        'kind': 'start',
        'eventId': 'e-start',
        'calendarId': 'cal1',
        'title': 'Standup',
        'atMs': DateTime(2026, 6, 20, 9).millisecondsSinceEpoch,
      });
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(1));
      final ev = fired.single;
      expect(ev, isA<CalendarEventStarted>());
      expect((ev as CalendarEventStarted).eventId, 'e-start');
      expect(ev.calendarId, 'cal1');
      expect(ev.title, 'Standup');
      expect(ev.at, DateTime(2026, 6, 20, 9));
      await sub.cancel();
    });

    test('handler decodes kind=end into CalendarEventEnded', () async {
      await service.init();
      final fired = <CalendarEvent>[];
      final sub = service.events.listen(fired.add);

      await pushOnCalendarEvent({
        'kind': 'end',
        'eventId': 'e-end',
        'calendarId': 'cal1',
        'title': 'Standup',
        'atMs': DateTime(2026, 6, 20, 10).millisecondsSinceEpoch,
      });
      await Future<void>.delayed(Duration.zero);

      expect(fired.single, isA<CalendarEventEnded>());
      expect((fired.single as CalendarEventEnded).eventId, 'e-end');
      expect(
        service.lastIsBusy,
        isNull,
        reason: 'Ended events must not flip the busy cache.',
      );
      await sub.cancel();
    });

    test(
      'handler decodes kind=busy with isBusy=true into CalendarBusyChange',
      () async {
        await service.init();
        final fired = <CalendarEvent>[];
        final sub = service.events.listen(fired.add);

        await pushOnCalendarEvent({
          'kind': 'busy',
          'eventId': 'e-busy',
          'calendarId': 'cal1',
          'title': 'Focus',
          'atMs': DateTime(2026, 6, 20, 11).millisecondsSinceEpoch,
          'isBusy': true,
        });
        await Future<void>.delayed(Duration.zero);

        expect(fired.single, isA<CalendarBusyChange>());
        final ev = fired.single as CalendarBusyChange;
        expect(ev.eventId, 'e-busy');
        expect(ev.isBusy, true);
        expect(service.lastIsBusy, true);
        await sub.cancel();
      },
    );

    test('handler decodes unknown kind by ignoring the event', () async {
      await service.init();
      final fired = <CalendarEvent>[];
      final sub = service.events.listen(fired.add);

      await pushOnCalendarEvent({
        'kind': 'unknown_future_kind',
        'eventId': 'e-x',
        'calendarId': 'cal1',
        'title': '???',
        'atMs': 0,
      });
      await Future<void>.delayed(Duration.zero);

      expect(
        fired,
        isEmpty,
        reason:
            'The unknown-kind default branch must skip the push (forward-'
            'compat for new Kotlin-side kinds).',
      );
      await sub.cancel();
    });

    test('stop() swallows MissingPluginException when the platform side '
        'is gone (defensive tear-down)', () async {
      await service.init();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'stopStream') {
          throw MissingPluginException(
            'doit/calendar not registered (test only)',
          );
        }
        return null;
      });
      // resetForTesting calls _source!.stop() (fire-and-forget via
      // unawaited). The MissingPluginException must NOT propagate.
      await expectLater(
        Future<void>.sync(() => service.resetForTesting()),
        completes,
      );
    });
  });
}
