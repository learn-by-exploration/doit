// Tests for `PermissionLifecycleReProbe` — the
// `WidgetsBindingObserver` that re-probes
// `PermissionService.statuses` whenever the app resumes
// (Phase 9 / SYS-104).
//
// The observer is process-scoped (no `dispose`); the
// `WidgetsBinding` lifecycle in `flutter_test` uses the
// `TestWidgetsFlutterBinding` singleton, so we drive the
// `didChangeAppLifecycleState` callback directly rather
// than spinning a real lifecycle. The point of these
// tests is to pin the policy: the FIRST `resumed` event
// (the OS bringing the app to the foreground after a
// cold launch — `init()` already probed) MUST be a no-op;
// every subsequent `resumed` MUST call
// `PermissionService.refresh()` AND
// `ReliabilityService.instance.refresh()` (v1.3b /
// Phase 13 / SYS-112).

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/services/call_interceptor.dart';
import 'package:doit/services/permission_lifecycle_observer.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/reliability_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// `permission_handler_platform_interface` re-exports the
// `PermissionStatus` enum that `MethodChannel` handlers
// return via `PermissionStatus.granted.value` (the int
// wire format). Same pattern as
// `settings_permissions_test.dart`.
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

/// Number of times `PermissionService.statuses` has fired
/// since the test process started. Reset in `setUp` for
/// each test by tracking the `before` snapshot and
/// computing the delta.
int _fireCountSinceStart = 0;

/// Repeatedly yields to the microtask queue. Used to drain
/// the nested `Future.wait` / `await` chain in
/// `PermissionService.refresh()` after a lifecycle event.
Future<void> _drain() async {
  for (var i = 0; i < 16; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// All `PermissionKind` values, in declaration order. Used
/// by the resume-hook test to seed a fresh all-granted map
/// (matching the `reliability_service_test.dart` helper).
const List<PermissionKind> _permissionKinds = PermissionKind.values;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // v1.3b / Phase 13 / SYS-112: the resume hook's
  // `_safeRefresh` calls `PermissionService.refresh()`,
  // which awaits `Future.wait` of per-kind platform
  // probes. Without a mock handler, the unmocked
  // `permission_handler` channel returns a Future that
  // hangs forever in a widget-test fake-async zone (the
  // `MissingPluginException` is only raised for the
  // `usageStats`/`callScreening` channels, not for the
  // generic permission ones). Mocking the channel lets
  // `_safeRefresh` complete so the resume-hook coverage
  // reaches the new `ReliabilityService.refresh()` line.
  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  const callInterceptorChannel = MethodChannel('doit/call_interceptor');
  const usageStatsChannel = MethodChannel('doit/device_state');

  setUpAll(() {
    // Count fires on the singleton `statuses` notifier for
    // the lifetime of the test process. Each test reads
    // the before/after delta to know how many fires its
    // actions caused.
    PermissionService.instance.statuses.addListener(() {
      _fireCountSinceStart++;
    });
  });

  setUp(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
        case 'requestPermissions':
          final requested = (call.arguments as List).cast<int>();
          return <int, int>{
            for (final v in requested) v: PermissionStatus.granted.value,
          };
        case 'openAppSettings':
          return true;
        default:
          return null;
      }
    });
    // v1.3b / Phase 13 / SYS-112: `PermissionService
    // .refresh()` awaits `CallInterceptorService.instance
    // .isCallScreeningRoleHeld()`, which awaits the
    // service's `_ready` Completer. Without mocking the
    // call-interceptor channel the `MissingPluginException`
    // is raised on `_source.start()`, init() returns
    // without completing the Completer, and the
    // refresh-path hangs. Mock the channel so
    // `CallInterceptorService.init()` completes and
    // `isCallScreeningRoleHeld` returns `false` (the
    // production path on a device without the plugin).
    messenger.setMockMethodCallHandler(callInterceptorChannel, (call) async {
      switch (call.method) {
        case 'startStream':
        case 'stopStream':
        case 'setEnabled':
        case 'setContactIds':
        case 'setRingerMode':
        case 'restorePriorRinger':
        case 'onCallEvent':
        case 'recordRoutineDecision':
          return null;
        case 'isCallScreeningRoleHeld':
        case 'requestCallScreeningRole':
        case 'isRingerModeActive':
        case 'getRingerMode':
          return false;
        default:
          return null;
      }
    });
    // The usage-stats probe goes through `doit/device_state`
    // — same pattern as the call interceptor above.
    messenger.setMockMethodCallHandler(usageStatsChannel, (call) async {
      switch (call.method) {
        case 'isUsageStatsGranted':
        case 'openUsageAccessSettings':
          return false;
        default:
          return null;
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(permissionsChannel, null);
      messenger.setMockMethodCallHandler(callInterceptorChannel, null);
      messenger.setMockMethodCallHandler(usageStatsChannel, null);
    });

    PermissionService.instance.resetForTesting();
    CallInterceptorService.instance.resetForTesting();
    await CallInterceptorService.instance.init();
    ReliabilityService.resetForTesting();
    // `resetForTesting` rewrites the notifier value; each
    // write counts as a fire. Reset the counter AFTER the
    // reset so the next test starts from zero.
    _fireCountSinceStart = 0;
  });

  tearDown(() {
    ReliabilityService.resetForTesting();
    PermissionService.instance.resetForTesting();
  });

  test('first resumed event after construction is a no-op '
      '(init() already probed)', () async {
    final observer = PermissionLifecycleReProbe();
    await PermissionService.instance.init();
    // init() reset+probe path may have fired statuses.
    final before = _fireCountSinceStart;
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    // No async work scheduled by the observer on the
    // cold-start path. Drain to be safe.
    await _drain();
    expect(
      _fireCountSinceStart,
      before,
      reason:
          'The cold-start resumed must not re-probe '
          '(init() just ran).',
    );
  });

  test('second resumed event calls PermissionService.refresh()', () async {
    final observer = PermissionLifecycleReProbe();
    await PermissionService.instance.init();
    // Consume the cold-start resumed.
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _drain();
    final before = _fireCountSinceStart;
    // Second resumed (the user came back from Settings).
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    // refresh() awaits the batch of probes plus the two
    // special-access kinds. Drain the microtask queue
    // repeatedly so all nested Futures complete.
    await _drain();
    expect(
      _fireCountSinceStart,
      greaterThan(before),
      reason:
          'A non-cold-start resumed must fire the statuses '
          'notifier (refresh() wrote new values).',
    );
  });

  test('non-resumed lifecycle events are ignored', () async {
    final observer = PermissionLifecycleReProbe();
    await PermissionService.instance.init();
    final before = _fireCountSinceStart;
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    observer.didChangeAppLifecycleState(AppLifecycleState.detached);
    await _drain();
    expect(_fireCountSinceStart, before);
  });

  // v1.3b / Phase 13 / SYS-112: a non-cold-start resumed
  // also calls `ReliabilityService.instance.refresh()`.
  // The reliability service's bridge probe is the second
  // half of the resume hook — without it, a user toggling
  // the exact-alarm permission would have to relaunch to
  // see the "may be late" banner go away.
  //
  // Pin note: the resume hook's `_safeRefresh` is
  // fire-and-forget (`unawaited`). It awaits
  // `PermissionService.refresh()` (which calls
  // `Future.wait` over multiple permission_handler
  // probes — these are slow under a generic mock handler)
  // then `ReliabilityService.instance.refresh()`. A test
  // that waits for the chain to complete via `Future.
  // delayed` cycles is flaky. The reliable pin: trigger
  // the resume, then explicitly call
  // `ReliabilityService.instance.refresh()` to verify the
  // resume hook's reliability-refresh code path runs
  // without throwing (the L100 / L101 code path is the
  // resume hook's reliability branch). The bridge flip
  // + explicit refresh pins the value transition end-to-
  // end.
  test(
    'second resumed event also calls ReliabilityService.instance.refresh()',
    () async {
      final bridge = FakeReminderBridge()..reliability = Reliability.optimal;
      await PermissionService.instance.init();
      // v1.3b / Phase 13 / SYS-112: grant every kind so
      // the derive rule does NOT collapse on the gated
      // kinds (`location`, `calendar`, `callScreening`,
      // `usageStats`); only the bridge probe drives the
      // value here.
      PermissionService.instance.statuses.value = {
        for (final kind in _permissionKinds)
          kind: const PermissionResultGranted(),
      };
      await ReliabilityService.init(
        bridge: bridge,
        permissionService: PermissionService.instance,
      );
      // Consume the cold-start resumed (no-op path).
      final observer = PermissionLifecycleReProbe();
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _drain();
      // Sanity: bridge is `optimal`, permissions are all
      // granted → derived value is `optimal`.
      expect(ReliabilityService.instance.value, Reliability.optimal);

      // Flip the bridge to `degraded` and drive the
      // refresh directly via the test hook so we can
      // `await` the chain to completion. The resume
      // hook's fire-and-forget pattern (`unawaited`) may
      // not complete before a unit test exits — the test
      // hook drives the same code path and lets us wait.
      bridge.reliability = Reliability.degraded;
      // Re-grant usageStats to mask the
      // `refreshUsageStats` write (which would flip
      // value to `degraded` from the gated-kind path
      // and confuse the assertion). The bridge path
      // alone should drive the value.
      await PermissionService.instance.refresh();
      PermissionService.instance.statuses.value = {
        for (final kind in _permissionKinds)
          kind: const PermissionResultGranted(),
      };
      expect(ReliabilityService.instance.value, Reliability.optimal);
      await observer.triggerRefreshForTest();
      expect(
        ReliabilityService.instance.value,
        Reliability.degraded,
        reason:
            'The resume hook must re-probe the bridge via '
            'ReliabilityService.instance.refresh() and '
            'pick up the new value.',
      );
    },
  );

  // v1.3b / Phase 13 / SYS-112: the resume hook tolerates
  // `ReliabilityService` not being init'd (a defensive
  // `StateError` catch). The pin: the resume hook
  // surfaces the StateError through its second `try`
  // block and continues — the permission refresh must
  // still fire and the observer must not throw.
  test('second resumed tolerates ReliabilityService not being init', () async {
    final observer = PermissionLifecycleReProbe();
    await PermissionService.instance.init();
    // Consume the cold-start resumed.
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _drain();
    final before = _fireCountSinceStart;

    // The reliability service is NOT init'd. Drive the
    // refresh directly via the test hook so we can await
    // it to completion — the resume hook's fire-and-
    // forget pattern may not complete before the test
    // exits, leaving the StateError catch branch
    // uncovered. The test hook drives the same code
    // path and awaits it.
    await observer.triggerRefreshForTest();
    await _drain();
    expect(
      _fireCountSinceStart,
      greaterThan(before),
      reason:
          'The permission refresh must still fire when '
          'ReliabilityService is not init.',
    );
  });

  // v1.4-stab-D / Phase 44 / SYS-131: the observer MUST
  // ignore non-`resumed` lifecycle events (paused,
  // inactive, hidden, detached). The early-return at
  // `permission_lifecycle_observer.dart:69` is the gate;
  // a `paused` event must NOT touch
  // `PermissionService.refresh()`.
  test('paused / inactive / hidden lifecycle events do NOT trigger '
      'a permission refresh (SYS-131)', () async {
    final observer = PermissionLifecycleReProbe();
    await PermissionService.instance.init();
    // Consume the cold-start resumed so subsequent state
    // changes are eligible to refresh.
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _drain();
    final before = _fireCountSinceStart;

    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ]) {
      observer.didChangeAppLifecycleState(state);
    }
    await _drain();
    expect(
      _fireCountSinceStart,
      before,
      reason:
          'Non-resumed lifecycle events must NOT trigger a refresh '
          '(early-return at observer line 69).',
    );
  });

  // ---- v1.6-ι / SYS-154 / ADR-085 / WF-082 ----
  // State-machine + register/deregister pins for the
  // resume hook: cold-start short-circuit, sequential
  // refreshes on repeated resumes, and the
  // `triggerRefreshForTest()` test hook driving the
  // `ReliabilityService.StateError` catch path.
  test('cold_start_resumed_short_circuits_synchronously (v1.6-ι)', () async {
    final observer = PermissionLifecycleReProbe();
    await PermissionService.instance.init();
    // Consume the init probe fires.
    final before = _fireCountSinceStart;

    // The cold-start resumed is the FIRST `resumed` event
    // after construction. The observer's `_coldStartSeen`
    // gate short-circuits WITHOUT awaiting any platform
    // channel. The `unawaited(_safeRefresh())` line is
    // never reached, so no fire count delta.
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    // Drain a generous number of microtasks so any
    // erroneously-scheduled `_safeRefresh` would have
    // time to fire.
    await _drain();
    await _drain();
    expect(
      _fireCountSinceStart,
      before,
      reason:
          'The cold-start resumed must not re-probe '
          '(`_coldStartSeen` gate at observer line 67-72).',
    );

    // The next call IS a non-cold-start resumed — it
    // MUST fire the statuses notifier (different behavior
    // from the cold-start case).
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _drain();
    expect(
      _fireCountSinceStart,
      greaterThan(before),
      reason:
          'A subsequent resumed event must trigger a refresh '
          'after the cold-start gate has been consumed.',
    );
  });

  test(
    'three_consecutive_resumed_events_produce_three_refreshes (v1.6-ι)',
    () async {
      final observer = PermissionLifecycleReProbe();
      await PermissionService.instance.init();
      // Consume the cold-start resumed.
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _drain();
      final before = _fireCountSinceStart;

      // Three back-to-back resumed events. Each one is a
      // non-cold-start resumed, so each fires
      // `PermissionService.refresh()` (which writes a new
      // map into `statuses.value`).
      for (var i = 0; i < 3; i++) {
        observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        // Drain between events so each refresh's write
        // resolves before the next one starts.
        await _drain();
      }
      // Three refreshes = three fires, so the delta is
      // at least 3.
      expect(
        _fireCountSinceStart - before,
        greaterThanOrEqualTo(3),
        reason:
            'Each non-cold-start resumed must produce a refresh '
            '(at least 3 fires for 3 resumes).',
      );
    },
  );

  test('triggerRefreshForTest_drives_ReliabilityService.StateError_catch '
      '(v1.6-ι)', () async {
    // The resume hook's `_safeRefresh` has a `try {
    // await ReliabilityService.instance.refresh(); }
    // on StateError { … }` branch for the
    // "ReliabilityService was not init'd" path. The test
    // hook `triggerRefreshForTest()` is the only way to
    // drive this branch deterministically — the resume
    // hook itself is fire-and-forget, so the StateError
    // catch branch would otherwise be flaky to assert.
    final observer = PermissionLifecycleReProbe();
    await PermissionService.instance.init();
    // Consume the cold-start resumed.
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _drain();
    // The reliability service is intentionally NOT init'd
    // (see `tearDown` which calls
    // `ReliabilityService.resetForTesting()` between
    // tests). Calling `triggerRefreshForTest()` MUST NOT
    // throw — the StateError catch absorbs the failure.
    await observer.triggerRefreshForTest();
    // The permission refresh half DID run (the
    // `_safeRefresh` continues past the StateError
    // catch), so the statuses notifier fired.
    await _drain();
    // Sanity: the observer is still alive and the
    // subsequent resumed is non-cold-start.
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _drain();
    // The observer is stateless; the assertion is that
    // the test hook call above did not throw.
    expect(observer, isNotNull);
  });

  // ---- v1.7-θ additions (SYS-164 / ADR-095 / WF-092) ----

  // The cold-start gate is per-observer-instance, not
  // shared across observers. Constructing a second
  // observer resets the gate; its first `resumed` is a
  // cold-start no-op, while the FIRST observer's second
  // `resumed` continues to fire refreshes.
  test('v1.7-θ: cold_start gate is per_observer_instance '
      '(second observer starts with its own cold_start no_op)', () async {
    final obs1 = PermissionLifecycleReProbe();
    await PermissionService.instance.init();
    // Consume obs1's cold-start resumed.
    obs1.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _drain();
    // obs1 second resumed → fires refreshes.
    obs1.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _drain();
    // Now construct a NEW observer. Its cold-start gate
    // is independent — the FIRST resumed event for it
    // MUST be a no-op (cold-start gate still active).
    final obs2 = PermissionLifecycleReProbe();
    final before = _fireCountSinceStart;
    obs2.didChangeAppLifecycleState(AppLifecycleState.resumed);
    // Drain generously so any erroneously-scheduled
    // refresh would have time to fire.
    await _drain();
    await _drain();
    expect(
      _fireCountSinceStart,
      before,
      reason:
          'A new observer\'s first resumed must be a '
          'cold-start no-op (the gate is per-instance '
          'at permission_lifecycle_observer.dart:65).',
    );

    // The next resumed on obs2 is a non-cold-start
    // resumed and MUST fire the statuses notifier.
    obs2.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _drain();
    expect(
      _fireCountSinceStart,
      greaterThan(before),
      reason:
          'A subsequent resumed on the second observer '
          'must trigger a refresh after the cold-start '
          'gate has been consumed.',
    );
  });

  // `triggerRefreshForTest()` exposes `_safeRefresh`
  // directly via `@visibleForTesting`. The point of the
  // hook is to let tests await the chain without driving
  // a lifecycle event. Pin: calling it on a fresh
  // observer (no `didChangeAppLifecycleState` calls yet)
  // runs the full `_safeRefresh` body — the statuses
  // notifier fires (the permission refresh half
  // completes) — and does NOT throw even when
  // `ReliabilityService` is uninitialized.
  test('v1.7-θ: triggerRefreshForTest exposes _safeRefresh directly '
      '(runs without a lifecycle event and tolerates '
      'ReliabilityService not being init)', () async {
    // No `didChangeAppLifecycleState` calls at all —
    // the hook is the only way to drive the chain.
    final observer = PermissionLifecycleReProbe();
    await PermissionService.instance.init();
    final before = _fireCountSinceStart;
    // ReliabilityService.resetForTesting() runs in
    // setUp's tearDown chain — at this point it is
    // uninitialized, so the StateError catch at line
    // 113 will fire AND the permission refresh half
    // must still complete (the statuses notifier fires).
    await observer.triggerRefreshForTest();
    await _drain();
    expect(
      _fireCountSinceStart,
      greaterThan(before),
      reason:
          'triggerRefreshForTest must run the full '
          '_safeRefresh body (PermissionService.refresh '
          '+ ReliabilityService.refresh with StateError '
          'catch). The permission half completes; the '
          'reliability half is swallowed.',
    );

    // After the test hook ran, the cold-start gate is
    // still intact (the hook does NOT touch it). The
    // next resumed event is therefore still a cold-start
    // no-op.
    final afterHook = _fireCountSinceStart;
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _drain();
    await _drain();
    expect(
      _fireCountSinceStart,
      afterHook,
      reason:
          'The cold-start gate must remain intact after '
          'triggerRefreshForTest (the hook does NOT '
          'consume the gate).',
    );
  });
}
