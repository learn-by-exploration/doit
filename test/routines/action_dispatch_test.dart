// Tests for RoutineExecutor._dispatchAction (v1.1 / SYS-082).
//
// v1.0 (Phase F PR 1) only dispatched `ActionOverrideSilent`
// and `ActionCallIntercept`. v1.1 generalizes `_dispatchCallAction`
// into `_dispatchAction` covering all five `Action` leaves:
//
//   - `ActionOverrideSilent`  → CallInterceptorService.setRingerMode
//   - `ActionNotify`          → ReminderService.notifications.show
//   - `ActionFullscreen`      → no-op (banner listener picks up
//                                the AutomationFired event)
//   - `ActionCallIntercept`   → no-op (Kotlin service already
//                                routed the call; ADR-019)
//   - `ActionOpenApp`         → pendingOpenApp ValueListenable
//
// The first three are tested by driving each leaf through the
// call path (the only path that exercises _dispatchAction today,
// because that's where the Phase F PR 1 wiring was — every other
// trigger source is now also wired in v1.1 PR 1, but the action
// dispatcher is identical across paths so exercising one path
// covers the dispatcher).

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/routines/routine.dart';
import 'package:doit/routines/routine_executor.dart';
import 'package:doit/services/call_interceptor.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:flutter_test/flutter_test.dart';

Automation _callAnyWith(Action action) =>
    Automation(trigger: const TriggerCallIncomingAny(), action: action);

CallIncomingAny _call({String number = '+15551234567'}) => CallIncomingAny(
  number: number,
  displayName: 'Alice',
  at: DateTime(2026, 6, 20, 9),
);

void main() {
  late RoutineExecutor executor;
  late CallInterceptorService callService;
  late ScriptedCallSource source;
  late FakeNotificationService notifications;
  late ReminderService reminder;

  setUp(() async {
    executor = RoutineExecutor.instance;
    executor.resetForTesting();
    callService = CallInterceptorService.instance;
    callService.resetForTesting();
    source = ScriptedCallSource();
    callService.debugSetSource(source);
    await callService.init();

    // Wire a fresh ReminderService with a FakeNotificationService
    // for the ActionNotify path.
    ReminderService.resetForTesting();
    notifications = FakeNotificationService();
    reminder = ReminderService(
      scheduler: FakeAlarmScheduler(),
      notifications: notifications,
      fullScreen: FakeFullScreenIntent(),
      anchor: FakeAnchorDetector(),
      bridge: FakeReminderBridge(),
    );
    await ReminderService.init(reminder);

    await executor.init();
  });

  tearDown(() {
    executor.resetForTesting();
    callService.resetForTesting();
    ReminderService.resetForTesting();
  });

  // ── ActionOverrideSilent ────────────────────────────────────────

  test(
    'ActionOverrideSilent fires CallInterceptorService.setRingerMode',
    () async {
      executor.register('do-1', [
        _callAnyWith(const ActionOverrideSilent(targetMode: SilentMode.silent)),
      ]);
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);

      source.push(_call());
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(1));
      // The ScriptedCallSource records the most recent
      // setRingerMode call. Silent maps to RingerMode.silent.
      expect(source.lastRingerMode, RingerMode.silent);
      await sub.cancel();
    },
  );

  test('ActionOverrideSilent maps every SilentMode variant', () async {
    Future<void> expectMapped(SilentMode sm, RingerMode expected) async {
      executor.resetForTesting();
      await executor.init();
      executor.register('do-1', [
        _callAnyWith(ActionOverrideSilent(targetMode: sm)),
      ]);
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);
      source.push(_call(number: '+1${sm.index}5550000'));
      await Future<void>.delayed(Duration.zero);
      expect(fired, hasLength(1), reason: 'expected one fire for $sm');
      expect(source.lastRingerMode, expected, reason: 'mapping for $sm');
      await sub.cancel();
    }

    await expectMapped(SilentMode.silent, RingerMode.silent);
    await expectMapped(SilentMode.vibrate, RingerMode.vibrate);
    await expectMapped(SilentMode.normal, RingerMode.normal);
  });

  // ── ActionNotify ────────────────────────────────────────────────

  test('ActionNotify shows a system notification with title + body', () async {
    executor.register('do-1', [
      _callAnyWith(
        const ActionNotify(title: 'Workout', body: 'Tap to log sets.'),
      ),
    ]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(_call());
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(1));
    expect(notifications.shown, hasLength(1));
    final ev = notifications.shown.single;
    expect(ev.habitName, 'Workout');
    expect(ev.body, 'Tap to log sets.');
    await sub.cancel();
  });

  test(
    'ActionNotify swallows StateError when ReminderService is not init',
    () async {
      // Tear down ReminderService so the singleton throws
      // StateError on .instance. The dispatcher must NOT break
      // the AutomationFired stream.
      ReminderService.resetForTesting();
      executor.register('do-1', [
        _callAnyWith(const ActionNotify(title: 'x', body: 'y')),
      ]);
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);

      source.push(_call());
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(1));
      await sub.cancel();

      // Restore for tearDown.
      await ReminderService.init(reminder);
    },
  );

  // ── ActionFullscreen ────────────────────────────────────────────

  test('ActionFullscreen opens a routine-fired overlay via '
      'ReminderService.fullScreen.showRoutineOverlay', () async {
    // v1.2f / Phase 6: the executor now wires
    // ActionFullscreen to the routine-overlay seam. The
    // AutomationFired event still drives the home-screen
    // RoutineBanner listener; the overlay is the
    // escalation path.
    final fakeFullScreen = FakeFullScreenIntent();
    ReminderService.resetForTesting();
    await ReminderService.init(
      ReminderService(
        scheduler: FakeAlarmScheduler(),
        notifications: notifications,
        fullScreen: fakeFullScreen,
        anchor: FakeAnchorDetector(),
        bridge: FakeReminderBridge(),
      ),
    );

    executor.register('do-1', [_callAnyWith(const ActionFullscreen())]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(_call());
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(1));
    // The routine-overlay seam receives one call. Title
    // and body are null (no Do/MissionChain to anchor
    // them).
    expect(fakeFullScreen.routineOverlays, hasLength(1));
    expect(fakeFullScreen.routineOverlays.single.title, isNull);
    expect(fakeFullScreen.routineOverlays.single.body, isNull);
    // The habit-side seam (show) is unchanged.
    expect(fakeFullScreen.launches, isEmpty);
    await sub.cancel();
  });

  test(
    'ActionFullscreen swallows StateError when ReminderService is not init',
    () async {
      // ADR-013: a missing service must NOT break the
      // AutomationFired stream.
      ReminderService.resetForTesting();
      executor.register('do-1', [_callAnyWith(const ActionFullscreen())]);
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);

      source.push(_call());
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(1));
      await sub.cancel();

      // Restore for tearDown.
      await ReminderService.init(reminder);
    },
  );

  // ── ActionCallIntercept ─────────────────────────────────────────

  test('ActionCallIntercept records the routine decision via '
      'CallInterceptorService.recordRoutineDecision', () async {
    // v1.2f / Phase 6: the executor now wires
    // ActionCallIntercept to a post-call hook on the
    // call-screening service. The decision is captured
    // for analytics / debug; the ringer is untouched
    // (ADR-019).
    executor.register('do-1', [
      _callAnyWith(
        const ActionCallIntercept(decision: CallInterceptDecision.mute),
      ),
    ]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(_call());
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(1));
    // The scripted source records the decision.
    expect(source.routineDecisions, [CallInterceptDecision.mute]);
    // The ringer is NOT touched (ADR-019).
    expect(source.lastRingerMode, isNull);
    await sub.cancel();
  });

  test(
    'ActionCallIntercept captures every CallInterceptDecision variant',
    () async {
      // Map each variant to one call and confirm the
      // recording is order-preserving.
      for (final decision in CallInterceptDecision.values) {
        executor.resetForTesting();
        await executor.init();
        executor.register('do-1', [
          _callAnyWith(ActionCallIntercept(decision: decision)),
        ]);
        final fired = <AutomationFired>[];
        final sub = executor.events.listen(fired.add);

        source.push(_call(number: '+1${decision.index}5550000'));
        await Future<void>.delayed(Duration.zero);

        expect(fired, hasLength(1), reason: 'fire for $decision');
        expect(source.routineDecisions.last, decision, reason: 'for $decision');
        expect(source.lastRingerMode, isNull, reason: 'ringer for $decision');
        await sub.cancel();
      }
    },
  );

  // ── ActionOpenApp ───────────────────────────────────────────────

  test(
    'ActionOpenApp appends a RoutineOpenAppRequest to pendingOpenApp',
    () async {
      executor.register('do-1', [
        _callAnyWith(const ActionOpenApp(route: '/event')),
      ]);
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);

      expect(executor.pendingOpenApp.value, isEmpty);
      source.push(_call());
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(1));
      expect(executor.pendingOpenApp.value, hasLength(1));
      expect(executor.pendingOpenApp.value.single.route, '/event');
      await sub.cancel();
    },
  );

  test('ActionOpenApp accumulates one request per fire', () async {
    executor.register('do-1', [
      _callAnyWith(const ActionOpenApp(route: '/do/d-1')),
    ]);
    final sub = executor.events.listen((_) {});

    source.push(_call(number: '+15550000001'));
    source.push(_call(number: '+15550000002'));
    source.push(_call(number: '+15550000003'));
    await Future<void>.delayed(Duration.zero);

    expect(executor.pendingOpenApp.value, hasLength(3));
    expect(executor.pendingOpenApp.value.map((r) => r.route).toList(), <String>[
      '/do/d-1',
      '/do/d-1',
      '/do/d-1',
    ]);
    await sub.cancel();
  });

  test('ActionOpenApp fires the pendingOpenApp ValueListenable', () async {
    executor.register('do-1', [
      _callAnyWith(const ActionOpenApp(route: '/event')),
    ]);
    var notifyCount = 0;
    void listener() => notifyCount++;
    executor.pendingOpenApp.addListener(listener);
    addTearDown(() => executor.pendingOpenApp.removeListener(listener));

    final sub = executor.events.listen((_) {});
    source.push(_call());
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(notifyCount, greaterThanOrEqualTo(1));
  });

  test('resetForTesting clears pendingOpenApp', () async {
    executor.register('do-1', [
      _callAnyWith(const ActionOpenApp(route: '/event')),
    ]);
    final sub = executor.events.listen((_) {});
    source.push(_call());
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(executor.pendingOpenApp.value, isNotEmpty);

    executor.resetForTesting();
    expect(executor.pendingOpenApp.value, isEmpty);
    // Restore for tearDown.
    await executor.init();
  });
}
