// Tests for RoutineExecutor's call-event wiring
// (v1.0 / Phase F PR 1 / ADR-019 / SYS-075).
//
// The executor subscribes to CallInterceptorService.instance.events
// in init(). Each CallEvent is matched against the registered
// automations and dispatched (if shouldFire returns true). These
// tests cover the dispatch path end-to-end without a real Kotlin
// channel — the CallInterceptorService singleton is driven by a
// ScriptedCallSource, which feeds events into the executor's
// subscription automatically. The script also asserts the
// ActionOverrideSilent side-effect path: the executor must call
// CallInterceptorService.setRingerMode with the configured
// SilentMode mapped to RingerMode.

import 'package:doit/routines/routine.dart';
import 'package:doit/routines/routine_executor.dart';
import 'package:doit/services/call_interceptor.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:flutter_test/flutter_test.dart';

CallIncomingAny callAny({String number = '+15551234567'}) => CallIncomingAny(
  number: number,
  displayName: 'Alice',
  at: DateTime(2026, 6, 20, 9),
);

CallRingerOverridden callRingerOverridden({
  String number = '+15551234567',
  RingerMode priorMode = RingerMode.silent,
  RingerMode targetMode = RingerMode.normal,
}) => CallRingerOverridden(
  number: number,
  displayName: '',
  at: DateTime(2026, 6, 20, 9),
  priorMode: priorMode,
  targetMode: targetMode,
);

Automation callAnyTrigger() => Automation(
  trigger: const TriggerCallIncomingAny(),
  action: const ActionNotify(title: 'Call', body: 'Phone is ringing.'),
);

Automation callKnownTrigger() => Automation(
  trigger: const TriggerCallIncomingKnownContact(),
  action: const ActionNotify(title: 'Known call', body: 'Tap to answer.'),
);

Automation callUnknownTrigger() => Automation(
  trigger: const TriggerCallIncomingUnknownContact(),
  action: const ActionNotify(title: 'Unknown call', body: 'Possible spam.'),
);

Automation overrideSilentTrigger({required SilentMode targetMode}) =>
    Automation(
      trigger: const TriggerCallIncomingAny(),
      action: ActionOverrideSilent(targetMode: targetMode),
    );

Automation interceptTrigger() => Automation(
  trigger: const TriggerCallIncomingAny(),
  action: const ActionCallIntercept(decision: CallInterceptDecision.mute),
);

void main() {
  late RoutineExecutor executor;
  late CallInterceptorService service;
  late ScriptedCallSource source;

  setUp(() async {
    executor = RoutineExecutor.instance;
    executor.resetForTesting();
    service = CallInterceptorService.instance;
    service.resetForTesting();
    source = ScriptedCallSource();
    service.debugSetSource(source);
    await service.init();
    await executor.init();
  });

  tearDown(() {
    executor.resetForTesting();
    service.resetForTesting();
  });

  // ── TriggerCallIncomingAny ──────────────────────────────────────

  test('callIncomingAny fires on every CallIncomingAny', () async {
    executor.register('do-1', [callAnyTrigger()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(callAny(number: '+15551110000'));
    source.push(callAny(number: '+15552220000'));
    source.push(callRingerOverridden()); // NOT a call — no match
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(2));
    expect(fired[0].automation.trigger, isA<TriggerCallIncomingAny>());
    expect(fired[1].automation.trigger, isA<TriggerCallIncomingAny>());
    await sub.cancel();
  });

  // ── TriggerCallIncomingKnownContact ────────────────────────────

  test(
    'callIncomingKnownContact fires only when number is in contactIds',
    () async {
      service.contactIds = {'+15551234567'};
      executor.register('do-1', [callKnownTrigger()]);
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);

      source.push(callAny(number: '+15559999999')); // not in list
      source.push(callAny()); // matches
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(1));
      expect(
        fired.first.automation.trigger,
        isA<TriggerCallIncomingKnownContact>(),
      );
      await sub.cancel();
    },
  );

  test('callIncomingKnownContact fires on no calls when contactIds is '
      'empty', () async {
    service.contactIds = <String>{};
    executor.register('do-1', [callKnownTrigger()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(callAny());
    await Future<void>.delayed(Duration.zero);

    expect(fired, isEmpty);
    await sub.cancel();
  });

  // ── TriggerCallIncomingUnknownContact ──────────────────────────

  test(
    'callIncomingUnknownContact fires when number is NOT in contactIds',
    () async {
      service.contactIds = {'+15551234567'};
      executor.register('do-1', [callUnknownTrigger()]);
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);

      source.push(callAny()); // known — no match
      source.push(callAny(number: '+15559999999')); // unknown — match
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(1));
      expect(
        fired.first.automation.trigger,
        isA<TriggerCallIncomingUnknownContact>(),
      );
      await sub.cancel();
    },
  );

  test('callIncomingUnknownContact fires on every call when contactIds '
      'is empty', () async {
    service.contactIds = <String>{};
    executor.register('do-1', [callUnknownTrigger()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(callAny());
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(1));
    await sub.cancel();
  });

  // ── CallRingerOverridden is not an incoming event ─────────────

  test('CallRingerOverridden does NOT match any call trigger', () async {
    service.contactIds = {'+15551234567'};
    executor.register('do-1', [callAnyTrigger()]);
    executor.register('do-2', [callKnownTrigger()]);
    executor.register('do-3', [callUnknownTrigger()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(callRingerOverridden());
    await Future<void>.delayed(Duration.zero);

    expect(fired, isEmpty);
    await sub.cancel();
  });

  // ── Cross-cutting ───────────────────────────────────────────────

  test('multiple entities with callIncomingAny all fire', () async {
    executor.register('do-1', [callAnyTrigger()]);
    executor.register('do-2', [callAnyTrigger()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(callAny());
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(2));
    await sub.cancel();
  });

  test('disabled call automations do not fire', () async {
    executor.register('do-1', [
      Automation(
        trigger: const TriggerCallIncomingAny(),
        action: const ActionNotify(title: 'Call', body: 'Should not fire.'),
        enabled: false,
      ),
    ]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(callAny());
    await Future<void>.delayed(Duration.zero);

    expect(fired, isEmpty);
    await sub.cancel();
  });

  // ── ActionOverrideSilent dispatch ──────────────────────────────

  test(
    'ActionOverrideSilent.normal snaps the source ringer to normal',
    () async {
      executor.register('do-1', [
        overrideSilentTrigger(targetMode: SilentMode.normal),
      ]);
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);

      source.push(callAny());
      // Let the unawaited dispatch future complete.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(1));
      expect(source.lastRingerMode, RingerMode.normal);
      await sub.cancel();
    },
  );

  test('ActionOverrideSilent.vibrate maps to RingerMode.vibrate', () async {
    executor.register('do-1', [
      overrideSilentTrigger(targetMode: SilentMode.vibrate),
    ]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(callAny());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(1));
    expect(source.lastRingerMode, RingerMode.vibrate);
    await sub.cancel();
  });

  test('ActionOverrideSilent.silent maps to RingerMode.silent', () async {
    executor.register('do-1', [
      overrideSilentTrigger(targetMode: SilentMode.silent),
    ]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(callAny());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(1));
    expect(source.lastRingerMode, RingerMode.silent);
    await sub.cancel();
  });

  // ── ActionCallIntercept is a no-op on the executor side ───────

  test('ActionCallIntercept fires AutomationFired but does not touch the '
      'ringer', () async {
    executor.register('do-1', [interceptTrigger()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(callAny());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(1));
    // No ringer change — ActionCallIntercept is a no-op on the
    // executor side; the Kotlin screening service already routed
    // the call.
    expect(source.lastRingerMode, isNull);
    await sub.cancel();
  });

  // ── Pure predicate accessor ───────────────────────────────────

  test('callMatchesFor exposes the top-level callMatches predicate', () async {
    service.contactIds = {'+15551234567'};

    expect(
      executor.callMatchesFor(const TriggerCallIncomingAny(), callAny()),
      true,
    );
    expect(
      executor.callMatchesFor(
        const TriggerCallIncomingKnownContact(),
        callAny(),
      ),
      true,
    );
    expect(
      executor.callMatchesFor(
        const TriggerCallIncomingKnownContact(),
        callAny(number: '+15559999999'),
      ),
      false,
    );
    expect(
      executor.callMatchesFor(
        const TriggerCallIncomingUnknownContact(),
        callAny(number: '+15559999999'),
      ),
      true,
    );
  });
}
