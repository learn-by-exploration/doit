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
}
