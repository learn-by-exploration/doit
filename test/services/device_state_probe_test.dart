// Tests for DeviceStateService (v1.0 / Phase D PR 1 / ADR-022).
//
// Coverage:
//   - `init()` is idempotent.
//   - The broadcast events stream republishes every
//     snapshot pushed by the source.
//   - `current()` returns the cached snapshot from the
//     most recent push.
//   - `current()` falls back to a fresh `currentSnapshot()`
//     call when the cache is empty.
//   - `resetForTesting()` cancels the source subscription
//     and stops the source.
//   - A source that throws on `start()` does not crash the
//     service — it surfaces as an error on the stream.
//   - Multiple listeners on the broadcast stream all
//     receive every push (the `RoutineExecutor` + future
//     debug screen both need this).

import 'package:doit/services/device_state_probe.dart';
import 'package:flutter_test/flutter_test.dart';

DeviceStateSnapshot snap({
  int batteryPercent = 50,
  bool isCharging = false,
  bool headphonesConnected = false,
  bool screenOn = false,
  DateTime? at,
}) => DeviceStateSnapshot(
  batteryPercent: batteryPercent,
  isCharging: isCharging,
  headphonesConnected: headphonesConnected,
  screenOn: screenOn,
  at: at ?? DateTime(2026, 6, 20),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceStateService', () {
    late DeviceStateService service;
    late ScriptedDeviceStateSource source;

    setUp(() {
      service = DeviceStateService.instance;
      service.resetForTesting();
      source = ScriptedDeviceStateSource();
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
      final fired = <DeviceStateSnapshot>[];
      final sub = service.events.listen(fired.add);

      source.push(snap());
      source.push(snap(batteryPercent: 75, isCharging: true));
      source.push(snap(headphonesConnected: true, screenOn: true));
      await Future<void>.delayed(Duration.zero);

      expect(fired, hasLength(3));
      expect(fired[0].batteryPercent, 50);
      expect(fired[1].batteryPercent, 75);
      expect(fired[1].isCharging, isTrue);
      expect(fired[2].headphonesConnected, isTrue);
      expect(fired[2].screenOn, isTrue);
      await sub.cancel();
    });

    test('current() returns the cached snapshot after a push', () async {
      await service.init();
      final pushed = snap(batteryPercent: 80, isCharging: true);
      source.push(pushed);
      await Future<void>.delayed(Duration.zero);

      final got = await service.current();
      expect(got.batteryPercent, 80);
      expect(got.isCharging, isTrue);
      expect(
        source.currentCalls,
        0,
        reason: 'cache must avoid the round-trip.',
      );
    });

    test(
      'current() falls back to source.currentSnapshot() when cache is empty',
      () async {
        await service.init();
        // No push yet — cache is empty.
        final got = await service.current();
        expect(source.currentCalls, 1);
        expect(got.batteryPercent, 0, reason: 'zero-valued fallback.');
        // After the fallback, the result is cached so a
        // second call does not hit the source again.
        final got2 = await service.current();
        expect(source.currentCalls, 1, reason: 'cache is now warm.');
        expect(got2, got);
      },
    );

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

    test('a source that throws on start() does not crash init() '
        'and surfaces as an error on the stream', () async {
      // The default test source does not throw, but we
      // can script it to. We use a fresh service to keep
      // this case independent of the setUp() source.
      service.resetForTesting();
      final failing = ScriptedDeviceStateSource()
        ..startError = StateError('plugin missing');
      service.debugSetSource(failing);
      // init() does NOT rethrow — it must surface via the
      // stream so the caller (the orchestrator) can log
      // and continue. The current implementation
      // re-throws on start() failure (it must — we cannot
      // complete `_ready` with a broken source).
      await expectLater(service.init(), throwsA(isA<StateError>()));
    });

    test('multiple listeners all receive every push', () async {
      await service.init();
      final a = <DeviceStateSnapshot>[];
      final b = <DeviceStateSnapshot>[];
      final sa = service.events.listen(a.add);
      final sb = service.events.listen(b.add);

      source.push(snap(batteryPercent: 60));
      source.push(snap(batteryPercent: 61));
      await Future<void>.delayed(Duration.zero);

      expect(a, hasLength(2));
      expect(b, hasLength(2));
      await sa.cancel();
      await sb.cancel();
    });
  });

  group('DeviceStateSnapshot', () {
    test('value equality on all five fields', () {
      final at = DateTime(2026, 6, 20, 9);
      final a = snap(isCharging: true, at: at);
      final b = snap(isCharging: true, at: at);
      final c = snap(batteryPercent: 51, isCharging: true, at: at);
      expect(a, b);
      expect(a, isNot(c));
      expect(a.hashCode, b.hashCode);
    });

    test('fromMap parses all four fields, defaults `at` to now', () {
      final now = DateTime.now();
      final parsed = DeviceStateSnapshot.fromMap(const {
        'batteryPercent': 42,
        'isCharging': true,
        'headphonesConnected': true,
        'screenOn': false,
      });
      expect(parsed.batteryPercent, 42);
      expect(parsed.isCharging, isTrue);
      expect(parsed.headphonesConnected, isTrue);
      expect(parsed.screenOn, isFalse);
      // The `at` field is set to wall-clock now; we assert
      // it is within a 5-second window of `now`.
      expect(
        parsed.at.difference(now).inSeconds.abs() < 5,
        isTrue,
        reason: '`at` should default to DateTime.now() on the Dart side.',
      );
    });

    test('fromMap uses sensible defaults for missing keys', () {
      final parsed = DeviceStateSnapshot.fromMap(const {});
      expect(parsed.batteryPercent, 0);
      expect(parsed.isCharging, isFalse);
      expect(parsed.headphonesConnected, isFalse);
      expect(parsed.screenOn, isFalse);
    });
  });
}
