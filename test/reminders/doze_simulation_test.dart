// Doze + idle-window simulation tests for `ReliabilityService`.
//
// v1.4-stab-E / Phase 45 / SYS-132: validates that the
// 30 s fallback timer fires `refresh()` when the device
// enters an idle / maintenance window — the `Doze` mode
// behavior on Android. The real Doze mode pauses alarm
// delivery; do it's fallback path is to re-derive
// reliability from a fresh bridge probe so the home-screen
// banner reflects the post-Doze state.
//
// Pure-Dart; uses the same `_ScriptedBridge` +
// `_RecordingPeriodicFactory` patterns from
// `reliability_service_test.dart`.

import 'dart:async' show Timer;

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/reliability_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _drain() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _ScriptedBridge implements ReminderBridge {
  _ScriptedBridge();
  int probeCount = 0;

  @override
  Future<Reliability> probeReliability() async {
    probeCount++;
    return Reliability.optimal;
  }

  @override
  Future<void> rescheduleAll() async =>
      throw UnimplementedError('rescheduleAll');
  @override
  Future<void> recordAnchor(DateTime at) async =>
      throw UnimplementedError('recordAnchor');
  @override
  Future<int> setExactAlarm({
    required int alarmId,
    required int epochMs,
  }) async => throw UnimplementedError('setExactAlarm');
  @override
  Future<void> cancelAlarm(int alarmId) async =>
      throw UnimplementedError('cancelAlarm');
  @override
  Future<void> showFullScreen(String habitId) async =>
      throw UnimplementedError('showFullScreen');
  @override
  Future<void> showNotification({
    required int alarmId,
    required String habitName,
    String? body,
    bool strongMode = false,
  }) async => throw UnimplementedError('showNotification');
  @override
  Future<void> cancelNotification(int alarmId) async =>
      throw UnimplementedError('cancelNotification');
  @override
  Future<void> openIgnoreBatteryOptimizations() async =>
      throw UnimplementedError('openIgnoreBatteryOptimizations');
  @override
  Future<void> schedulePreAlarm({
    required int alarmId,
    required int leadTimeSeconds,
  }) async => throw UnimplementedError('schedulePreAlarm');
  @override
  Future<void> cancelPreAlarms(int alarmId) async =>
      throw UnimplementedError('cancelPreAlarms');
}

class _FakeTimer implements Timer {
  @override
  void cancel() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingPeriodicFactory {
  void Function(Timer)? lastCallback;
  Duration? lastDuration;

  Timer factory(Duration duration, void Function(Timer) cb) {
    lastCallback = cb;
    lastDuration = duration;
    return _FakeTimer();
  }
}

void _grantAllPermissions() {
  final granted = <PermissionKind, PermissionResult?>{
    for (final k in PermissionKind.values) k: const PermissionResultGranted(),
  };
  PermissionService.instance.statuses.value = granted;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    ReliabilityService.resetForTesting();
    PermissionService.instance.resetForTesting();
    _grantAllPermissions();
  });

  tearDown(() async {
    ReliabilityService.resetForTesting();
  });

  test('the 30 s fallback timer fires `refresh()` deterministically — '
      'idle-window simulation (SYS-132)', () async {
    final bridge = _ScriptedBridge();
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
    await _drain();
    final factory = _RecordingPeriodicFactory();
    ReliabilityService.instance.setPeriodicFactoryForTesting(factory.factory);
    await _drain();

    expect(
      factory.lastDuration,
      const Duration(seconds: 30),
      reason:
          'The fallback timer MUST be 30 s — matches the '
          '`kReliabilityCacheTtl` constant.',
    );
    expect(factory.lastCallback, isNotNull);

    final beforeProbeCount = bridge.probeCount;
    // Simulate the idle / maintenance window: fire the
    // callback as if 30 s have elapsed.
    factory.lastCallback!(_FakeTimer());
    await _drain();
    expect(
      bridge.probeCount,
      greaterThan(beforeProbeCount),
      reason:
          'The fallback timer MUST call `refresh()`, which re-probes '
          'the bridge.',
    );
  });
}
