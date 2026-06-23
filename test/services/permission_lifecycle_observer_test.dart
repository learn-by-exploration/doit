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
// `PermissionService.refresh()`.

import 'package:doit/services/permission_lifecycle_observer.dart';
import 'package:doit/services/permission_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Count fires on the singleton `statuses` notifier for
    // the lifetime of the test process. Each test reads
    // the before/after delta to know how many fires its
    // actions caused.
    PermissionService.instance.statuses.addListener(() {
      _fireCountSinceStart++;
    });
  });

  setUp(() {
    PermissionService.instance.resetForTesting();
    // `resetForTesting` rewrites the notifier value; each
    // write counts as a fire. Reset the counter AFTER the
    // reset so the next test starts from zero.
    _fireCountSinceStart = 0;
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
}
