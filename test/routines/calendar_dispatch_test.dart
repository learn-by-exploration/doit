// Tests for RoutineExecutor's calendar-event wiring
// (v1.0 / Phase E PR 1 / ADR-023).
//
// The executor subscribes to CalendarService.instance.events
// in init(). Each CalendarEvent is matched against the
// registered automations and dispatched (if shouldFire
// returns true). These tests cover the dispatch path
// end-to-end without a real Kotlin channel — the
// CalendarService singleton is driven by a
// ScriptedCalendarSource, which feeds events into the
// executor's subscription automatically.

import 'package:doit/routines/routine.dart';
import 'package:doit/routines/routine_executor.dart';
import 'package:doit/services/calendar_service.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEventStarted calStarted({
  String eventId = 'e1',
  String calendarId = 'cal1',
  String title = 'Standup',
}) => CalendarEventStarted(
  eventId: eventId,
  calendarId: calendarId,
  title: title,
  at: DateTime(2026, 6, 20),
);

CalendarEventEnded calEnded({
  String eventId = 'e1',
  String calendarId = 'cal1',
  String title = 'Standup',
}) => CalendarEventEnded(
  eventId: eventId,
  calendarId: calendarId,
  title: title,
  at: DateTime(2026, 6, 20),
);

CalendarEventReminder calReminder({
  String eventId = 'e1',
  String calendarId = 'cal1',
  String title = 'Standup',
}) => CalendarEventReminder(
  eventId: eventId,
  calendarId: calendarId,
  title: title,
  at: DateTime(2026, 6, 20),
);

CalendarBusyChange calBusy({
  required bool isBusy,
  String eventId = 'e1',
  String calendarId = 'cal1',
  String title = 'Standup',
}) => CalendarBusyChange(
  eventId: eventId,
  calendarId: calendarId,
  title: title,
  at: DateTime(2026, 6, 20),
  isBusy: isBusy,
);

Automation calStart({String calendarId = '', String title = ''}) => Automation(
  trigger: TriggerCalendarEventStart(calendarId: calendarId, eventTitle: title),
  action: const ActionNotify(title: 'Meeting started', body: 'Tap to join.'),
);

Automation calEnd({String calendarId = '', String title = ''}) => Automation(
  trigger: TriggerCalendarEventEnd(calendarId: calendarId, eventTitle: title),
  action: const ActionNotify(title: 'Meeting ended', body: 'Wrap up notes.'),
);

Automation calReminderTrigger({
  String calendarId = '',
  String title = '',
}) => Automation(
  trigger: TriggerCalendarReminder(calendarId: calendarId, eventTitle: title),
  action: const ActionNotify(title: 'Meeting reminder', body: 'Starts soon.'),
);

Automation freeBusyTrigger({String calendarId = '', String title = ''}) =>
    Automation(
      trigger: TriggerFreeBusy(calendarId: calendarId, eventTitle: title),
      action: const ActionNotify(
        title: 'Calendar busy',
        body: 'Focus mode on.',
      ),
    );

void main() {
  late RoutineExecutor executor;
  late CalendarService service;
  late ScriptedCalendarSource source;

  setUp(() async {
    executor = RoutineExecutor.instance;
    executor.resetForTesting();
    service = CalendarService.instance;
    service.resetForTesting();
    source = ScriptedCalendarSource();
    service.debugSetSource(source);
    await service.init();
    await executor.init();
  });

  tearDown(() {
    executor.resetForTesting();
    service.resetForTesting();
  });

  // ── event-start leaf ────────────────────────────────────

  test('calendarEventStart fires only on a CalendarEventStarted', () async {
    executor.register('do-1', [calStart()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(calEnded());
    source.push(calReminder());
    source.push(calBusy(isBusy: true));
    source.push(calStarted()); // fires
    source.push(calStarted(title: 'Other')); // fires (no title filter)
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(2));
    expect(fired[0].automation.trigger, isA<TriggerCalendarEventStart>());
    expect(fired[1].automation.trigger, isA<TriggerCalendarEventStart>());
    await sub.cancel();
  });

  // ── event-end leaf ──────────────────────────────────────

  test('calendarEventEnd fires only on a CalendarEventEnded', () async {
    executor.register('do-1', [calEnd()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(calStarted());
    source.push(calReminder());
    source.push(calEnded()); // fires
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(1));
    expect(fired.first.automation.trigger, isA<TriggerCalendarEventEnd>());
    await sub.cancel();
  });

  // ── event-reminder leaf ─────────────────────────────────

  test('calendarReminder fires only on a CalendarEventReminder', () async {
    executor.register('do-1', [calReminderTrigger()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(calStarted());
    source.push(calEnded());
    source.push(calReminder()); // fires
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(1));
    expect(fired.first.automation.trigger, isA<TriggerCalendarReminder>());
    await sub.cancel();
  });

  // ── free-busy edge detection ────────────────────────────

  test(
    'freeBusy fires on the false→true transition (first busy event)',
    () async {
      executor.register('do-1', [freeBusyTrigger()]);
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);

      // No prior state. First busy event: edge fires.
      source.push(calBusy(isBusy: true));
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(1));
      expect(fired.first.automation.trigger, isA<TriggerFreeBusy>());
      expect(executor.lastIsBusy, true);
      await sub.cancel();
    },
  );

  test('freeBusy fires on the true→false transition (end of busy)', () async {
    executor.register('do-1', [freeBusyTrigger()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(calBusy(isBusy: true)); // edge
    source.push(calBusy(isBusy: false)); // edge — fire on the way out
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(2));
    expect(executor.lastIsBusy, false);
    await sub.cancel();
  });

  test('freeBusy does not fire on a true→true repeat', () async {
    executor.register('do-1', [freeBusyTrigger()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(calBusy(isBusy: true)); // edge
    source.push(calBusy(isBusy: true)); // repeat — no edge
    source.push(calBusy(isBusy: true)); // repeat — no edge
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(1));
    await sub.cancel();
  });

  test('freeBusy does not fire on a false→false repeat', () async {
    executor.register('do-1', [freeBusyTrigger()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(calBusy(isBusy: false)); // baseline (no prior state)
    source.push(calBusy(isBusy: false)); // repeat — no edge
    await Future<void>.delayed(Duration.zero);

    expect(fired, isEmpty);
    expect(executor.lastIsBusy, false);
    await sub.cancel();
  });

  // ── calendar-id and title filtering ─────────────────────

  test(
    'calendarEventStart with calendarId filter rejects other calendars',
    () async {
      executor.register('do-1', [calStart(calendarId: 'work')]);
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);

      source.push(calStarted(calendarId: 'personal'));
      source.push(calStarted(calendarId: 'work')); // matches
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(1));
      await sub.cancel();
    },
  );

  test('calendarEventStart with title filter rejects other titles', () async {
    executor.register('do-1', [calStart(title: 'Standup')]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(calStarted(title: 'Lunch'));
    source.push(calStarted()); // matches
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(1));
    await sub.cancel();
  });

  // ── cross-cutting ───────────────────────────────────────

  test('multiple entities with calendarEventStart all fire', () async {
    executor.register('do-1', [calStart()]);
    executor.register('do-2', [calStart()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(calStarted());
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(2));
    await sub.cancel();
  });

  test('disabled calendar automations do not fire', () async {
    executor.register('do-1', [
      Automation(
        trigger: const TriggerCalendarEventStart(
          calendarId: '',
          eventTitle: '',
        ),
        action: const ActionNotify(title: 'Meeting', body: 'Should not fire.'),
        enabled: false,
      ),
    ]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(calStarted());
    await Future<void>.delayed(Duration.zero);

    expect(fired, isEmpty);
    await sub.cancel();
  });

  test('calendarMatches exposes pure predicate for tests', () {
    const t = TriggerCalendarEventStart(
      calendarId: 'work',
      eventTitle: 'Standup',
    );
    expect(executor.calendarMatches(t, calStarted(calendarId: 'work')), true);
    expect(
      executor.calendarMatches(t, calStarted(calendarId: 'personal')),
      false,
    );
    expect(
      executor.calendarMatches(
        t,
        calStarted(calendarId: 'work', title: 'Lunch'),
      ),
      false,
    );
    expect(executor.calendarMatches(t, calEnded(calendarId: 'work')), false);
  });
}
