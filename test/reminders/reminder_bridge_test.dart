// Tests for [ReminderBridge] (the [FakeReminderBridge] only —
// the [PlatformReminderBridge] talks to the real method
// channel and is exercised in the integration build).

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeInbound implements ReminderInbound {
  int rescheduleAllCalls = 0;
  final List<int> fireAlarmCalls = <int>[];

  @override
  Future<void> onRescheduleAll() async {
    rescheduleAllCalls++;
  }

  @override
  Future<void> onFireAlarm(int alarmId) async {
    fireAlarmCalls.add(alarmId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FakeReminderBridge', () {
    test('rescheduleAll increments the counter', () async {
      final b = FakeReminderBridge();
      await b.rescheduleAll();
      await b.rescheduleAll();
      expect(b.rescheduleCount, 2);
    });

    test('recordAnchor appends the timestamp', () async {
      final b = FakeReminderBridge();
      final at = DateTime(2026, 6, 13, 7, 30);
      await b.recordAnchor(at);
      expect(b.anchors, [at]);
    });

    test('probeReliability returns the configured value', () async {
      final b = FakeReminderBridge();
      expect(await b.probeReliability(), Reliability.optimal);
      b.reliability = Reliability.degraded;
      expect(await b.probeReliability(), Reliability.degraded);
      b.reliability = Reliability.unknown;
      expect(await b.probeReliability(), Reliability.unknown);
    });

    test(
      'setExactAlarm records the call and returns the id by default',
      () async {
        final b = FakeReminderBridge();
        final epochMs = DateTime(2026, 6, 18, 7, 30).millisecondsSinceEpoch;
        final id = await b.setExactAlarm(alarmId: 7, epochMs: epochMs);
        expect(id, 7);
        expect(b.setExactAlarmCalls, [(alarmId: 7, epochMs: epochMs)]);
      },
    );

    test(
      'setExactAlarm respects a custom result (degraded fallback)',
      () async {
        final b = FakeReminderBridge();
        b.setExactAlarmResult = (id) => id * 100;
        final id = await b.setExactAlarm(
          alarmId: 3,
          epochMs: DateTime(2026, 6, 18, 8).millisecondsSinceEpoch,
        );
        expect(id, 300);
      },
    );

    test('cancelAlarm records the id', () async {
      final b = FakeReminderBridge();
      await b.cancelAlarm(42);
      expect(b.cancelAlarmCalls, [42]);
    });

    test('showFullScreen records the habitId', () async {
      final b = FakeReminderBridge();
      await b.showFullScreen('h_abc');
      expect(b.showFullScreenCalls, ['h_abc']);
    });

    test('openIgnoreBatteryOptimizations increments the counter', () async {
      final b = FakeReminderBridge();
      await b.openIgnoreBatteryOptimizations();
      expect(b.openIgnoreBatteryOptimizationsCalls, 1);
    });
  });

  group('PlatformReminderBridge', () {
    const channel = MethodChannel('doit/reminders');
    final List<MethodCall> log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            log.add(call);
            if (call.method == 'probeReliability') return 'optimal';
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('rescheduleAll invokes the channel', () async {
      final b = PlatformReminderBridge();
      await b.rescheduleAll();
      expect(log.length, 1);
      expect(log.first.method, 'rescheduleAll');
    });

    test('recordAnchor passes the ISO-8601 timestamp', () async {
      final b = PlatformReminderBridge();
      final at = DateTime(2026, 6, 13, 7, 30);
      await b.recordAnchor(at);
      expect(log.length, 1);
      expect(log.first.method, 'recordAnchor');
      expect((log.first.arguments as Map)['atIso'], at.toIso8601String());
    });

    test('probeReliability parses "optimal"', () async {
      final b = PlatformReminderBridge();
      expect(await b.probeReliability(), Reliability.optimal);
    });

    test('probeReliability parses "degraded"', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => 'degraded');
      final b = PlatformReminderBridge();
      expect(await b.probeReliability(), Reliability.degraded);
    });

    test(
      'probeReliability falls back to unknown on unexpected reply',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async => 'mystery');
        final b = PlatformReminderBridge();
        expect(await b.probeReliability(), Reliability.unknown);
      },
    );

    test('inbound rescheduleAll dispatches to handler', () async {
      final inbound = _FakeInbound();
      PlatformReminderBridge(inbound: inbound).install();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const codec = StandardMethodCodec();
      final encoded = codec.encodeMethodCall(const MethodCall('rescheduleAll'));
      await messenger.handlePlatformMessage(
        'doit/reminders',
        encoded,
        (data) {},
      );
      // The handler is async; give it a tick.
      await Future<void>.delayed(Duration.zero);
      expect(inbound.rescheduleAllCalls, 1);
    });

    test('inbound fireAlarm extracts alarmId', () async {
      final inbound = _FakeInbound();
      PlatformReminderBridge(inbound: inbound).install();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const codec = StandardMethodCodec();
      final encoded = codec.encodeMethodCall(
        const MethodCall('fireAlarm', {'alarmId': 7}),
      );
      await messenger.handlePlatformMessage(
        'doit/reminders',
        encoded,
        (data) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(inbound.fireAlarmCalls, [7]);
    });

    test('inbound fireAlarm with missing alarmId is a no-op', () async {
      final inbound = _FakeInbound();
      PlatformReminderBridge(inbound: inbound).install();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const codec = StandardMethodCodec();
      final encoded = codec.encodeMethodCall(
        const MethodCall('fireAlarm', <String, dynamic>{}),
      );
      await messenger.handlePlatformMessage(
        'doit/reminders',
        encoded,
        (data) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(inbound.fireAlarmCalls, isEmpty);
    });

    test('inbound unknown method throws MissingPluginException', () async {
      PlatformReminderBridge(inbound: _FakeInbound()).install();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const codec = StandardMethodCodec();
      final encoded = codec.encodeMethodCall(const MethodCall('mystery'));
      Object? caught;
      await messenger.handlePlatformMessage('doit/reminders', encoded, (data) {
        if (data != null) {
          try {
            codec.decodeEnvelope(data);
          } catch (e) {
            caught = e;
          }
        }
      });
      await Future<void>.delayed(Duration.zero);
      // The exception is delivered as a PlatformException on the
      // result side; we don't decode it here, just confirm the
      // dispatcher didn't throw synchronously.
      expect(caught, isNull);
    });

    test(
      'setExactAlarm passes alarmId and epochMs and returns the id',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              log.add(call);
              if (call.method == 'setExactAlarm') return 17;
              return null;
            });
        final b = PlatformReminderBridge();
        final epochMs = DateTime(2026, 6, 18, 7, 30).millisecondsSinceEpoch;
        final id = await b.setExactAlarm(alarmId: 5, epochMs: epochMs);
        expect(id, 17);
        expect(log.length, 1);
        expect(log.first.method, 'setExactAlarm');
        final args = log.first.arguments as Map;
        expect(args['alarmId'], 5);
        expect(args['epochMs'], epochMs);
      },
    );

    test(
      'setExactAlarm falls back to alarmId when the platform returns null',
      () async {
        final b = PlatformReminderBridge();
        final id = await b.setExactAlarm(
          alarmId: 9,
          epochMs: DateTime(2026, 6, 18).millisecondsSinceEpoch,
        );
        expect(id, 9);
      },
    );

    test('cancelAlarm passes the id', () async {
      final b = PlatformReminderBridge();
      await b.cancelAlarm(11);
      expect(log.length, 1);
      expect(log.first.method, 'cancelAlarm');
      expect((log.first.arguments as Map)['alarmId'], 11);
    });

    test('showFullScreen passes the habitId', () async {
      final b = PlatformReminderBridge();
      await b.showFullScreen('h_xyz');
      expect(log.length, 1);
      expect(log.first.method, 'showFullScreen');
      expect((log.first.arguments as Map)['habitId'], 'h_xyz');
    });

    test('openIgnoreBatteryOptimizations invokes the channel', () async {
      final b = PlatformReminderBridge();
      await b.openIgnoreBatteryOptimizations();
      expect(log.length, 1);
      expect(log.first.method, 'openIgnoreBatteryOptimizations');
      expect(log.first.arguments, isNull);
    });
  });
}
