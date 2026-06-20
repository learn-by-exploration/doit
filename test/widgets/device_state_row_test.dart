// Tests for the DeviceStateRow widget (Settings → Device state).
//
// v1.0 / Phase D PR 2 / ADR-022. The row subscribes to
// `DeviceStateService.instance.events` and re-renders on every
// `DeviceStateSnapshot` pushed by the source. A test-only
// `ScriptedDeviceStateSource` drives the service so the test
// can assert the rendered state without a real platform
// channel.

import 'package:doit/services/device_state_probe.dart';
import 'package:doit/widgets/device_state_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

DeviceStateSnapshot _snap({
  int batteryPercent = 80,
  bool isCharging = false,
  bool headphonesConnected = false,
  bool screenOn = true,
  DateTime? at,
}) => DeviceStateSnapshot(
  batteryPercent: batteryPercent,
  isCharging: isCharging,
  headphonesConnected: headphonesConnected,
  screenOn: screenOn,
  at: at ?? DateTime(2026, 6, 20, 9, 30, 15),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeviceStateService service;
  late ScriptedDeviceStateSource source;

  setUp(() async {
    service = DeviceStateService.instance;
    service.resetForTesting();
    source = ScriptedDeviceStateSource();
    service.debugSetSource(source);
  });

  tearDown(() {
    service.resetForTesting();
  });

  // Pump the widget and let the widget's _bind() future, the
  // service's init(), and the source push all resolve in real
  // time. `tester.pump()` runs in the fake-async zone which
  // does not process real microtasks; `tester.runAsync` steps
  // out of it so the actual futures can resolve.
  Future<void> pumpWithPush(
    WidgetTester tester,
    DeviceStateSnapshot snap,
  ) async {
    await tester.pumpWidget(_wrap(const DeviceStateRow()));
    await tester.runAsync(() async {
      await service.ready;
      // Give the widget's _bind() a chance to attach the
      // service subscription before we push.
      await Future<void>.delayed(Duration.zero);
      source.push(snap);
      // Let the broadcast stream deliver the snapshot.
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
  }

  testWidgets('shows waiting copy before the first snapshot arrives', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const DeviceStateRow()));
    await tester.runAsync(() async {
      await service.ready;
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();

    expect(find.text('Waiting for first snapshot...'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings.device_state.at')),
      findsNothing,
    );
  });

  testWidgets('renders the formatted snapshot when one arrives', (
    tester,
  ) async {
    await pumpWithPush(tester, _snap(isCharging: true));

    expect(find.textContaining('Battery: 80%'), findsOneWidget);
    expect(find.textContaining('charging'), findsOneWidget);
    expect(find.textContaining('No headphones'), findsOneWidget);
    expect(find.textContaining('Screen: on'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings.device_state.at')),
      findsOneWidget,
    );
  });

  testWidgets('re-renders when a new snapshot is pushed', (tester) async {
    await tester.pumpWidget(_wrap(const DeviceStateRow()));
    await tester.runAsync(() async {
      await service.ready;
      await Future<void>.delayed(Duration.zero);
      source.push(_snap(batteryPercent: 50));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(find.textContaining('Battery: 50%'), findsOneWidget);

    // The second push is delivered to the broadcast stream
    // in real async time. We need to step out of the
    // fake-async zone and pump multiple times so the
    // broadcast stream event is delivered and the
    // StreamBuilder rebuilds.
    await tester.runAsync(() async {
      source.push(_snap(batteryPercent: 20, isCharging: true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Battery: 20%'), findsOneWidget);
    expect(find.textContaining('charging'), findsOneWidget);
  });

  testWidgets('shows the "connected" copy when headphones are plugged in', (
    tester,
  ) async {
    await pumpWithPush(tester, _snap(headphonesConnected: true));
    expect(find.textContaining('Headphones: connected'), findsOneWidget);
  });

  testWidgets('shows the "off" copy when the screen is locked', (tester) async {
    await pumpWithPush(tester, _snap(screenOn: false));
    expect(find.textContaining('Screen: off'), findsOneWidget);
  });

  testWidgets('renders the snapshot time in HH:MM:SS', (tester) async {
    await pumpWithPush(tester, _snap(at: DateTime(2026, 6, 20, 14, 5, 9)));
    expect(find.text('14:05:09'), findsOneWidget);
  });

  testWidgets('renders the diagnostic title and icon', (tester) async {
    await tester.pumpWidget(_wrap(const DeviceStateRow()));
    expect(find.text('Device state'), findsOneWidget);
    expect(find.byIcon(Icons.electrical_services_outlined), findsOneWidget);
  });
}
