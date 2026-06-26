// Unit tests for the widget bridge (v1.4a / Phase 28 /
// SYS-115 / ADR-045 / WF-042).
//
// Coverage:
//   - FakeWidgetBridge records cached snapshots + refreshes
//   - PlatformWidgetBridge.snapshot happy path
//   - PlatformWidgetBridge.snapshot swallows MissingPluginException (ADR-013)
//   - PlatformWidgetBridge.snapshot swallows PlatformException
//   - PlatformWidgetBridge.cacheSnapshot forwards JSON
//   - PlatformWidgetBridge.requestRefresh swallows MissingPluginException
//   - DoitWidgetState JSON round-trip

import 'package:doit/widget/doit_widget_state.dart';
import 'package:doit/widget/widget_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DoitWidgetState sample(DateTime asOf) => DoitWidgetState(
    habitId: 'h1',
    habitName: 'Read',
    streakNumber: 5,
    isCompletedToday: true,
    reliability: DoitWidgetReliability.optimal,
    asOf: asOf,
  );

  group('FakeWidgetBridge', () {
    test('cacheSnapshot records the state', () async {
      final bridge = FakeWidgetBridge();
      final state = sample(DateTime(2026, 6, 15));
      await bridge.cacheSnapshot(state);
      expect(bridge.cachedSnapshots.length, 1);
      expect(bridge.cachedSnapshots.first, equals(state));
    });

    test('requestRefresh increments the counter', () async {
      final bridge = FakeWidgetBridge();
      await bridge.requestRefresh();
      await bridge.requestRefresh();
      expect(bridge.refreshCount, 2);
    });

    test('snapshot returns the scripted value', () async {
      final bridge = FakeWidgetBridge();
      bridge.nextSnapshot = sample(DateTime(2026, 6, 15));
      expect(await bridge.snapshot(), isNotNull);
    });

    test('snapshot returns null by default', () async {
      final bridge = FakeWidgetBridge();
      expect(await bridge.snapshot(), isNull);
    });
  });

  group('PlatformWidgetBridge', () {
    const channel = MethodChannel('doit/widget');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('cacheSnapshot forwards the JSON envelope', () async {
      final bridge = PlatformWidgetBridge();
      Map<Object?, Object?>? captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'cacheSnapshot') {
          captured = call.arguments as Map<Object?, Object?>?;
        }
        return null;
      });
      await bridge.cacheSnapshot(sample(DateTime(2026, 6, 15, 10)));
      expect(captured, isNotNull);
      expect(captured!['habitId'], 'h1');
      expect(captured!['habitName'], 'Read');
      expect(captured!['streakNumber'], 5);
      expect(captured!['reliability'], 'optimal');
    });

    test('snapshot happy path returns the deserialized state', () async {
      final bridge = PlatformWidgetBridge();
      messenger.setMockMethodCallHandler(channel, (call) async {
        return <String, Object?>{
          'habitId': 'h2',
          'habitName': 'Walk',
          'streakNumber': 3,
          'isCompletedToday': false,
          'reliability': 'degraded',
          'asOfIso': '2026-06-15T10:00:00.000',
        };
      });
      final result = await bridge.snapshot();
      expect(result, isNotNull);
      expect(result!.habitId, 'h2');
      expect(result.habitName, 'Walk');
      expect(result.streakNumber, 3);
      expect(result.reliability, DoitWidgetReliability.degraded);
    });

    test('snapshot swallows MissingPluginException', () async {
      final bridge = PlatformWidgetBridge();
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException('not implemented');
      });
      expect(await bridge.snapshot(), isNull);
    });

    test('snapshot swallows PlatformException', () async {
      final bridge = PlatformWidgetBridge();
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'NO_IMPL');
      });
      expect(await bridge.snapshot(), isNull);
    });

    test('requestRefresh swallows MissingPluginException', () async {
      final bridge = PlatformWidgetBridge();
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException('not implemented');
      });
      await bridge.requestRefresh();
    });
  });

  group('DoitWidgetState JSON', () {
    test('round-trips through toJson / fromJson', () {
      final original = sample(DateTime(2026, 6, 15, 10, 30));
      final json = original.toJson();
      final restored = DoitWidgetState.fromJson(json);
      expect(restored, equals(original));
    });

    test('fromJson is defensive against missing fields', () {
      final restored = DoitWidgetState.fromJson(const <String, Object?>{});
      expect(restored.habitId, '');
      expect(restored.habitName, '');
      expect(restored.streakNumber, 0);
      expect(restored.isCompletedToday, isFalse);
      expect(restored.reliability, DoitWidgetReliability.unknown);
    });

    test('fromJson tolerates an unknown reliability tag', () {
      final restored = DoitWidgetState.fromJson(const <String, Object?>{
        'habitId': 'h1',
        'habitName': 'Read',
        'streakNumber': 5,
        'isCompletedToday': false,
        'reliability': 'unknown-future-value',
        'asOfIso': '2026-06-15T10:00:00.000',
      });
      expect(restored.reliability, DoitWidgetReliability.unknown);
    });
  });
}
