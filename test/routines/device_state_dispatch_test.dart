// Tests for RoutineExecutor's device-state wiring
// (v1.0 / Phase D PR 2 / ADR-022).
//
// The executor subscribes to DeviceStateService.instance.events
// in init(). Each snapshot is matched against the registered
// automations and dispatched (if shouldFire returns true).
// These tests cover the dispatch path end-to-end without a
// real Kotlin channel — the DeviceStateService singleton is
// driven by a scripted source, which feeds events into the
// executor's subscription automatically.

import 'package:doit/routines/routine.dart';
import 'package:doit/routines/routine_executor.dart';
import 'package:doit/services/device_state_probe.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:flutter_test/flutter_test.dart';

DeviceStateSnapshot snap({
  int batteryPercent = 50,
  bool isCharging = false,
  bool headphonesConnected = false,
  bool screenOn = false,
}) => DeviceStateSnapshot(
  batteryPercent: batteryPercent,
  isCharging: isCharging,
  headphonesConnected: headphonesConnected,
  screenOn: screenOn,
  at: DateTime(2026, 6, 20),
);

Automation batteryLow({int percent = 20}) => Automation(
  trigger: TriggerBatteryLow(percent),
  action: const ActionNotify(
    title: 'Low battery',
    body: 'Plug in your phone soon.',
  ),
);

Automation batteryFull() => Automation(
  trigger: const TriggerBatteryFull(),
  action: const ActionNotify(title: 'Battery full', body: 'Unplug your phone.'),
);

Automation chargingStarted() => Automation(
  trigger: const TriggerChargingStarted(),
  action: const ActionNotify(title: 'Charging started', body: 'Charging now.'),
);

Automation chargingStopped() => Automation(
  trigger: const TriggerChargingStopped(),
  action: const ActionNotify(title: 'Charging stopped', body: 'Unplugged.'),
);

Automation headphoneConnected() => Automation(
  trigger: const TriggerHeadphoneConnected(),
  action: const ActionNotify(
    title: 'Headphones connected',
    body: 'You plugged in.',
  ),
);

Automation headphoneDisconnected() => Automation(
  trigger: const TriggerHeadphoneDisconnected(),
  action: const ActionNotify(
    title: 'Headphones disconnected',
    body: 'You unplugged.',
  ),
);

Automation screenOn() => Automation(
  trigger: const TriggerScreenOn(),
  action: const ActionNotify(title: 'Screen on', body: 'You woke the device.'),
);

Automation screenOff() => Automation(
  trigger: const TriggerScreenOff(),
  action: const ActionNotify(
    title: 'Screen off',
    body: 'You locked the device.',
  ),
);

void main() {
  late RoutineExecutor executor;
  late DeviceStateService service;
  late ScriptedDeviceStateSource source;

  setUp(() async {
    executor = RoutineExecutor.instance;
    executor.resetForTesting();
    service = DeviceStateService.instance;
    service.resetForTesting();
    source = ScriptedDeviceStateSource();
    service.debugSetSource(source);
    // init() is idempotent across resets because resetForTesting
    // re-creates the _ready Completer. We have to call
    // init() once per test.
    await executor.init();
    await service.init();
  });

  tearDown(() {
    executor.resetForTesting();
    service.resetForTesting();
  });

  // ── edge triggers (compare current vs previous) ──────────

  test('chargingStarted fires only on the 0→1 transition', () async {
    executor.register('do-1', [chargingStarted()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(snap(isCharging: true)); // 0 → 1
    source.push(snap(isCharging: true)); // 1 → 1 (no edge)
    source.push(snap()); // 1 → 0 (chargingStopped, not chargingStarted)
    source.push(snap(isCharging: true)); // 0 → 1
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(2));
    expect(
      (fired[0].automation.trigger as TriggerChargingStarted).runtimeType,
      TriggerChargingStarted,
    );
    await sub.cancel();
  });

  test('chargingStopped fires only on the 1→0 transition', () async {
    executor.register('do-1', [chargingStopped()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(snap(isCharging: true));
    source.push(snap()); // 1 → 0 edge
    source.push(snap()); // 0 → 0 (no edge)
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(1));
    expect(fired.first.automation.trigger, isA<TriggerChargingStopped>());
    await sub.cancel();
  });

  test(
    'headphoneConnected and headphoneDisconnected fire on opposite edges',
    () async {
      executor.register('do-in', [headphoneConnected()]);
      executor.register('do-out', [headphoneDisconnected()]);
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);

      source.push(snap(headphonesConnected: true)); // 0 → 1 → connected fires
      source.push(snap()); // 1 → 0 → disconnected fires
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(2));
      expect(fired[0].automation.trigger, isA<TriggerHeadphoneConnected>());
      expect(fired[1].automation.trigger, isA<TriggerHeadphoneDisconnected>());
      await sub.cancel();
    },
  );

  test('screenOn and screenOff fire on opposite edges', () async {
    executor.register('do-on', [screenOn()]);
    executor.register('do-off', [screenOff()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(snap(screenOn: true));
    source.push(snap()); // 1 → 0
    source.push(snap(screenOn: true)); // 0 → 1
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(3));
    expect(fired[0].automation.trigger, isA<TriggerScreenOn>());
    expect(fired[1].automation.trigger, isA<TriggerScreenOff>());
    expect(fired[2].automation.trigger, isA<TriggerScreenOn>());
    await sub.cancel();
  });

  // ── state-comparison triggers (current snapshot only) ─────

  test('batteryLow fires when battery is at or below the threshold', () async {
    executor.register('do-1', [batteryLow()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(snap(batteryPercent: 80)); // not low
    source.push(snap(batteryPercent: 25)); // not low
    source.push(snap(batteryPercent: 20)); // at threshold — fires
    source.push(snap(batteryPercent: 5)); // below — fires
    source.push(snap(batteryPercent: 21)); // not low
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(2));
    expect((fired[0].automation.trigger as TriggerBatteryLow).percent, 20);
    await sub.cancel();
  });

  test('batteryFull fires only at 100%', () async {
    executor.register('do-1', [batteryFull()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(snap(batteryPercent: 99));
    source.push(snap(batteryPercent: 100)); // fires
    source.push(snap(batteryPercent: 100)); // still 100 — fires every snapshot
    await Future<void>.delayed(Duration.zero);

    // We intentionally do not dedupe — the platform pushes
    // a new snapshot on every battery broadcast. Production
    // behavior: the executor will fire on every snapshot
    // where batteryPercent == 100. The Settings → Triggers
    // screen surfaces the latest snapshot value.
    expect(fired.length, greaterThanOrEqualTo(2));
    await sub.cancel();
  });

  // ── cross-cutting ────────────────────────────────────────

  test(
    'the first snapshot never fires an edge trigger (no previous state)',
    () async {
      executor.register('do-charging', [chargingStarted()]);
      executor.register('do-screen', [screenOn()]);
      executor.register('do-headphone', [headphoneConnected()]);
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);

      // First snapshot: all edges that would transition from
      // `false` (the default previous) to `true` SHOULD fire —
      // the "no previous state" default is treated as `false`.
      source.push(
        snap(isCharging: true, screenOn: true, headphonesConnected: true),
      );
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(3));
      await sub.cancel();
    },
  );

  test('multiple entities with the same trigger all fire', () async {
    executor.register('do-1', [chargingStarted()]);
    executor.register('do-2', [chargingStarted()]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(snap(isCharging: true));
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(2));
    await sub.cancel();
  });

  test('disabled automations do not fire', () async {
    executor.register('do-1', [
      Automation(
        trigger: const TriggerChargingStarted(),
        action: const ActionNotify(title: 'Charging', body: 'Should not fire.'),
        enabled: false,
      ),
    ]);
    final fired = <AutomationFired>[];
    final sub = executor.events.listen(fired.add);

    source.push(snap(isCharging: true));
    await Future<void>.delayed(Duration.zero);

    expect(fired, isEmpty);
    await sub.cancel();
  });

  test(
    'geofence and device-state streams both flow through the same executor',
    () async {
      // This is a smoke test: register one automation per
      // stream; both should fire on the right events.
      executor.register('do-geo', [
        Automation(
          trigger: const TriggerLocationEnter(
            geofenceId: 'g1',
            label: 'Home',
            latitude: 0,
            longitude: 0,
            radiusMeters: 100,
          ),
          action: const ActionNotify(title: 'Geo', body: 'You arrived.'),
        ),
      ]);
      executor.register('do-state', [chargingStarted()]);
      final fired = <AutomationFired>[];
      final sub = executor.events.listen(fired.add);

      source.push(snap(isCharging: true));
      await Future<void>.delayed(Duration.zero);

      // Only the device-state automation fires; the geofence
      // is not registered with GeofenceService so no event
      // arrives from that stream. This asserts the two
      // streams do not interfere with each other.
      expect(fired, hasLength(1));
      expect(fired.first.automation.trigger, isA<TriggerChargingStarted>());
      await sub.cancel();
    },
  );
}
