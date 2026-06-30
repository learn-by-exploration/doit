// Tests for the unified `ReliabilityService` (v1.3b /
// Phase 13 / SYS-112 / ADR-042).
//
// The service merges the alarm-system bridge probe with
// the `PermissionService.statuses` map. These tests pin:
//
//   1. The initial value is `optimal` (closes the
//      first-read race that the previous
//      `PlatformAlarmScheduler.reliability` getter had).
//   2. `refresh()` re-probes the bridge.
//   3. A permissions change re-derives the value
//      (location/calendar/call-screening/usage-stats flip
//      to `degraded`).
//   4. An unrelated permissions change does NOT re-derive.
//   5. The 30 s fallback timer calls `refresh()` (using a
//      fake-async clock).
//   6. The stream emits `distinct()` values (no duplicate
//      emits).
//   7. `resetForTesting()` clears the singleton + closes
//      the stream controller.
//   8. `init()` is idempotent (a second call resolves
//      immediately without rebinding the listener).
//   9. A probe failure keeps the prior value (per
//      ADR-013).
//  10. The 6 gated kinds (v1.5b: location, calendar,
//      callScreening, usageStats, fullScreenIntent,
//      notificationPolicy) are the only ones that flip the
//      service to `degraded` from a permissions change.

import 'dart:async' show Completer, Timer;

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/reliability_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drains pending microtasks. The service runs the bridge
/// probe + the listener in a real-async chain; we step the
/// queue forward so the next assertion sees the post-probe
/// value.
Future<void> _drain() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A scripted `ReminderBridge` whose `reliability` value
/// is mutable (and whose `probeReliability` call count is
/// exposed). The fake mirrors the production
/// `FakeReminderBridge.reliability` setter pattern.
class _ScriptedBridge implements ReminderBridge {
  _ScriptedBridge({this.reliability = Reliability.optimal});

  Reliability reliability;
  int probeCount = 0;
  bool throwOnProbe = false;

  @override
  Future<Reliability> probeReliability() async {
    probeCount++;
    if (throwOnProbe) {
      throwOnProbe = false; // one-shot throw so the test can re-probe
      throw StateError('scripted bridge probe failure');
    }
    return reliability;
  }

  // The other methods are not exercised by these tests;
  // we throw to surface any unintended call.
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

/// Default the `PermissionService.statuses` map to granted
/// for every kind. The real `PermissionService.init()`
/// populates the map with `PermissionResultDenied` because
/// the platform channel is missing in the test harness —
/// the `ReliabilityService` would then flip every test to
/// `degraded` regardless of what the test is verifying.
/// Tests that want to exercise the denied path overwrite
/// the relevant key in the test body.
void _grantAllPermissions() {
  final granted = <PermissionKind, PermissionResult?>{
    for (final k in PermissionKind.values) k: const PermissionResultGranted(),
  };
  PermissionService.instance.statuses.value = granted;
}

void main() {
  setUp(() async {
    // Reset both singletons so the test starts from a
    // clean slate. `PermissionService.resetForTesting` is
    // safe to call even if the service has not been
    // init'd yet.
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();
    _grantAllPermissions();
    ReliabilityService.resetForTesting();
  });

  tearDown(() {
    ReliabilityService.resetForTesting();
    PermissionService.instance.resetForTesting();
  });

  test('initial value is optimal (no first-read race)', () async {
    final bridge = _ScriptedBridge();
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
    // The notifier is primed at construction; the value is
    // `optimal` before the bootstrap probe completes.
    expect(ReliabilityService.instance.value, Reliability.optimal);
  });

  test('refresh() re-probes the bridge and re-derives', () async {
    final bridge = _ScriptedBridge(reliability: Reliability.degraded);
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
    // The bootstrap probe already ran by the time `init`
    // returns (the service awaits the unawaited probe via
    // the `_bootstrap` future — the notifier is updated
    // synchronously, so we can read the post-probe value
    // after a microtask drain).
    await _drain();
    expect(ReliabilityService.instance.value, Reliability.degraded);
    expect(bridge.probeCount, greaterThanOrEqualTo(1));

    // Flip the bridge back to optimal; the next refresh
    // picks it up.
    bridge.reliability = Reliability.optimal;
    final before = bridge.probeCount;
    await ReliabilityService.instance.refresh();
    expect(bridge.probeCount, before + 1);
    expect(ReliabilityService.instance.value, Reliability.optimal);
  });

  test('a permissions change to a gated kind re-derives to degraded', () async {
    final bridge = _ScriptedBridge();
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
    await _drain();
    expect(ReliabilityService.instance.value, Reliability.optimal);

    // Build a fresh map each time so the `ValueNotifier`
    // setter fires its listener (same-reference assignments
    // are no-ops).
    Map<PermissionKind, PermissionResult?> flip(
      PermissionKind k,
      PermissionResult? r,
    ) {
      final next = Map<PermissionKind, PermissionResult?>.from(
        PermissionService.instance.statuses.value,
      )..[k] = r;
      return next;
    }

    PermissionService.instance.statuses.value = flip(
      PermissionKind.location,
      const PermissionResultDenied(canOpenSettings: true),
    );
    expect(ReliabilityService.instance.value, Reliability.degraded);

    PermissionService.instance.statuses.value = flip(
      PermissionKind.calendar,
      const PermissionResultDenied(canOpenSettings: true),
    );
    expect(ReliabilityService.instance.value, Reliability.degraded);

    PermissionService.instance.statuses.value = flip(
      PermissionKind.callScreening,
      const PermissionResultPermanentlyDenied(),
    );
    expect(ReliabilityService.instance.value, Reliability.degraded);

    PermissionService.instance.statuses.value = flip(
      PermissionKind.usageStats,
      const PermissionResultDenied(canOpenSettings: true),
    );
    expect(ReliabilityService.instance.value, Reliability.degraded);
  });

  test('an unrelated permission kind does NOT re-derive', () async {
    final bridge = _ScriptedBridge();
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
    await _drain();
    expect(ReliabilityService.instance.value, Reliability.optimal);

    // `notifications` is NOT in `_kReliabilityGatedKinds`
    // (notifications / contacts / exact-alarm / battery-
    // optimization are gated by the onboarding flow, not
    // by the banner). A status flip here must not flip the
    // service to `degraded`.
    PermissionService.instance.statuses.value = {
      ...PermissionService.instance.statuses.value,
      PermissionKind.notifications: const PermissionResultDenied(
        canOpenSettings: true,
      ),
    };
    expect(ReliabilityService.instance.value, Reliability.optimal);
  });

  test('the 30 s fallback timer calls refresh()', () async {
    final bridge = _ScriptedBridge();
    final fakeTimer = _RecordingPeriodicFactory();
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
      periodicFactory: fakeTimer.factory,
    );
    await _drain();
    final probesAfterInit = bridge.probeCount;

    // The bootstrap has installed the periodic timer via
    // the fake factory; fire one tick to simulate the
    // 30 s elapsing.
    expect(fakeTimer.lastCallback, isNotNull);
    fakeTimer.lastCallback!(_FakeTimer());
    await _drain();
    expect(bridge.probeCount, greaterThan(probesAfterInit));
  });

  test('the stream emits distinct() values (no duplicate emits)', () async {
    final bridge = _ScriptedBridge();
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
    await _drain();
    // The initial `optimal` is the current value of the
    // notifier — read it directly. The stream only fires on
    // changes; new listeners do not see a replayed value.
    expect(ReliabilityService.instance.value, Reliability.optimal);
    final stream = ReliabilityService.instance.reliability;
    final values = <Reliability>[];
    final sub = stream.listen(values.add);

    // Trigger a refresh that produces the SAME value.
    // The notifier write is skipped (distinct()), so the
    // stream does not emit.
    await ReliabilityService.instance.refresh();
    await _drain();
    expect(values, isEmpty);

    // Flip the bridge; the next refresh re-derives to
    // `degraded`.
    bridge.reliability = Reliability.degraded;
    await ReliabilityService.instance.refresh();
    await _drain();
    expect(values, [Reliability.degraded]);

    await sub.cancel();
  });

  test(
    'resetForTesting() clears the singleton + closes the controller',
    () async {
      final bridge = _ScriptedBridge();
      await ReliabilityService.init(
        bridge: bridge,
        permissionService: PermissionService.instance,
      );
      await _drain();
      // Capture the controller's open state via a quick
      // listen-and-cancel.
      final stream = ReliabilityService.instance.reliability;
      final completer = Completer<void>();
      final sub = stream.listen((_) {}, onDone: completer.complete);

      ReliabilityService.resetForTesting();
      expect(
        () => ReliabilityService.instance,
        throwsStateError,
        reason: 'After resetForTesting, instance must throw.',
      );

      // The stream controller was closed during disposal;
      // the broadcast listener receives an immediate
      // `onDone`. The completer fires synchronously.
      await completer.future.timeout(const Duration(seconds: 1));
      await sub.cancel();
    },
  );

  test('init() is idempotent', () async {
    final bridge1 = _ScriptedBridge();
    await ReliabilityService.init(
      bridge: bridge1,
      permissionService: PermissionService.instance,
    );
    await _drain();

    // A second init call with a different bridge must NOT
    // re-bind (the first call wins).
    final bridge2 = _ScriptedBridge(reliability: Reliability.degraded);
    await ReliabilityService.init(
      bridge: bridge2,
      permissionService: PermissionService.instance,
    );
    await _drain();
    // The service is still bound to bridge1 (the first
    // call wins); bridge2's degraded value is ignored.
    expect(ReliabilityService.instance.value, Reliability.optimal);
  });

  test('a probe failure keeps the prior value (ADR-013)', () async {
    final bridge = _ScriptedBridge();
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
    await _drain();
    expect(ReliabilityService.instance.value, Reliability.optimal);

    // Force the next probe to throw. The service swallows
    // the error and keeps the prior value.
    bridge.reliability = Reliability.degraded;
    bridge.throwOnProbe = true;
    await ReliabilityService.instance.refresh();
    await _drain();
    // The probe threw, so the cached value is unchanged.
    // The derive falls through to the (still-empty)
    // statuses map and stays `optimal`.
    expect(ReliabilityService.instance.value, Reliability.optimal);

    // A subsequent successful probe re-derives correctly.
    await ReliabilityService.instance.refresh();
    await _drain();
    expect(ReliabilityService.instance.value, Reliability.degraded);
  });

  test('the 6 gated kinds are the only ones that flip to degraded', () async {
    final bridge = _ScriptedBridge();
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
    await _drain();
    expect(ReliabilityService.instance.value, Reliability.optimal);

    // Iterate over every `PermissionKind` and verify only
    // the 5 gated kinds flip the value to `degraded`.
    for (final kind in PermissionKind.values) {
      // Reset to optimal between iterations by writing a
      // fresh all-granted map. (A mutation of the previous
      // map + a same-reference assignment is a no-op on the
      // `ValueNotifier` setter, so we always allocate a new
      // map.)
      PermissionService.instance.statuses.value = {
        for (final k in PermissionKind.values)
          k: const PermissionResultGranted(),
      };
      // Sanity: optimal.
      expect(
        ReliabilityService.instance.value,
        Reliability.optimal,
        reason: 'precondition before flipping $kind',
      );

      // Flip the kind under test to denied (in a fresh map).
      PermissionService.instance.statuses.value = {
        ...PermissionService.instance.statuses.value,
        kind: const PermissionResultDenied(canOpenSettings: true),
      };
      // v1.3c / Phase 14 / SYS-113: `fullScreenIntent` joins
      // the 4 v1.3b gated kinds (location, calendar,
      // callScreening, usageStats). v1.5b / Phase 25:
      // `notificationPolicy` joins as the 6th gated kind
      // (mirrors the v1.5b `_kReliabilityGatedKinds`
      // constant in
      // `lib/services/reliability_service.dart` — the two
      // must stay in sync).
      const gated = {
        PermissionKind.location,
        PermissionKind.calendar,
        PermissionKind.callScreening,
        PermissionKind.usageStats,
        PermissionKind.fullScreenIntent,
        PermissionKind.notificationPolicy,
      };
      final expected = gated.contains(kind)
          ? Reliability.degraded
          : Reliability.optimal;
      expect(
        ReliabilityService.instance.value,
        expected,
        reason:
            'Flipping $kind to denied must yield $expected '
            '(gated set: $gated).',
      );
    }
  });

  test('flipping fullScreenIntent to denied re-derives to '
      'degraded (v1.3c / Phase 14 / SYS-113 / ADR-043)', () async {
    final bridge = _ScriptedBridge()..reliability = Reliability.optimal;
    await PermissionService.instance.init();
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
    await _drain();
    // All kinds granted → optimal.
    PermissionService.instance.statuses.value = {
      for (final k in PermissionKind.values) k: const PermissionResultGranted(),
    };
    expect(ReliabilityService.instance.value, Reliability.optimal);

    // Flip `fullScreenIntent` to denied. The derive rule
    // must re-emit `degraded` because `fullScreenIntent` is
    // in the gated set (added in v1.3c).
    PermissionService.instance.statuses.value = {
      ...PermissionService.instance.statuses.value,
      PermissionKind.fullScreenIntent: const PermissionResultDenied(
        canOpenSettings: true,
      ),
    };
    expect(
      ReliabilityService.instance.value,
      Reliability.degraded,
      reason:
          'A denial on the new fullScreenIntent kind must '
          'flip the unified reliability stream to degraded '
          '(SYS-113 / ADR-043).',
    );
  });

  // ── v1.4-stab-E / Phase 45 / SYS-132 ─────────────────────
  // Coverage cycle: every Reliability.optimal / .degraded /
  // .unknown path exercised + the `_safeProbe` platform-
  // channel error swallow pinned.

  test('a probe that throws StateError keeps the prior cached value '
      '(SYS-132 / ADR-013)', () async {
    final bridge = _ScriptedBridge();
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
    await _drain();
    expect(ReliabilityService.instance.value, Reliability.optimal);

    // Flip the bridge to a value that WOULD re-derive, but
    // make the next probe throw. The cached `_lastProbed`
    // must keep returning `optimal` (the prior value).
    bridge.reliability = Reliability.degraded;
    bridge.throwOnProbe = true;
    await ReliabilityService.instance.refresh();
    await _drain();
    expect(
      ReliabilityService.instance.value,
      Reliability.optimal,
      reason:
          'A probe throw MUST keep the prior cached value, NOT '
          'flip to degraded (the v0.4b-release-fix lesson, '
          'extended via ADR-013).',
    );
  });

  test('a fresh cold-start with no probe yet initializes to optimal '
      '(SYS-132 / first-read race fix)', () async {
    final bridge = _ScriptedBridge();
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
    // Read the value SYNCHRONOUSLY without draining
    // microtasks. The initial value MUST be `optimal`, not
    // `unknown`, so the home-screen reliability banner does
    // not flash "may be late" on cold start.
    expect(
      ReliabilityService.instance.value,
      Reliability.optimal,
      reason:
          'First-read race fix: cold start reads `optimal`, not '
          '`unknown`.',
    );
  });

  test('refresh() after a permissions change re-probes the bridge AND '
      're-derives (SYS-132)', () async {
    final bridge = _ScriptedBridge();
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
    await _drain();
    expect(ReliabilityService.instance.value, Reliability.optimal);

    // Flip a gated kind to denied; then trigger a refresh.
    final statuses = Map<PermissionKind, PermissionResult?>.from(
      PermissionService.instance.statuses.value,
    );
    statuses[PermissionKind.location] = const PermissionResultDenied(
      canOpenSettings: true,
    );
    PermissionService.instance.statuses.value = statuses;

    final beforeProbeCount = bridge.probeCount;
    await ReliabilityService.instance.refresh();
    await _drain();
    expect(
      bridge.probeCount,
      greaterThan(beforeProbeCount),
      reason: 'refresh() must re-probe the bridge.',
    );
    expect(
      ReliabilityService.instance.value,
      Reliability.degraded,
      reason: 'After a gated-kind denial + refresh, value is degraded.',
    );
  });

  test('the stream emits Reliability.optimal when a transition lands '
      'on `optimal` (SYS-132)', () async {
    final bridge = _ScriptedBridge(reliability: Reliability.degraded);
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
    await _drain();

    final received = <Reliability>[];
    final sub = ReliabilityService.instance.reliability.listen(received.add);

    // Flip the bridge so a `refresh()` MUST observe a
    // distinct value transition (`degraded` → `optimal`)
    // and emit on the stream. This pins the broadcast
    // controller's contract: subscribers added after
    // init see every subsequent distinct transition.
    bridge.reliability = Reliability.optimal;
    await ReliabilityService.instance.refresh();
    await _drain();

    expect(
      received,
      [Reliability.optimal],
      reason:
          'The stream MUST surface a distinct value '
          'transition. A broadcast+distinct stream does '
          'NOT replay past values to new subscribers, so '
          'this test pins the AFTER-init emit path.',
    );

    await sub.cancel();
  });

  test('dispose() closes the broadcast stream controller '
      '(SYS-132 / no-leak invariant)', () async {
    final bridge = _ScriptedBridge();
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
    await _drain();

    final completer = Completer<void>();
    final sub = ReliabilityService.instance.reliability.listen(
      (_) {},
      onDone: completer.complete,
    );

    ReliabilityService.resetForTesting();
    // The broadcast controller was closed during disposal;
    // the listener receives an immediate `onDone`.
    await completer.future.timeout(const Duration(seconds: 1));
    await sub.cancel();
  });
}

/// A trivial `Timer` implementation for the fallback-timer
/// test. The real `Timer.periodic` factory is replaced
/// during the test via `setPeriodicFactoryForTesting`; the
/// fake keeps a reference to the callback so the test can
/// drive ticks.
class _FakeTimer implements Timer {
  _FakeTimer();

  @override
  void cancel() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A periodic-factory stub that records the callback the
/// service installs. The test fires the callback manually
/// to simulate the 30 s tick without waiting.
class _RecordingPeriodicFactory {
  void Function(Timer)? lastCallback;
  Duration? lastDuration;

  Timer factory(Duration duration, void Function(Timer) cb) {
    lastCallback = cb;
    lastDuration = duration;
    return _FakeTimer();
  }
}
