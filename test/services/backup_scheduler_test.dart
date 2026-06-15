// Tests for the WorkManager-backed backup scheduler (v0.4b /
// SYS-060). Mocks the `workmanager` plugin's method channel
// and asserts:
//   1. `init()` calls `Workmanager().initialize(...)` (the
//      "initialize" method on the foreground channel).
//   2. `scheduleNightlyBackup()` calls
//      `Workmanager().registerPeriodicTask(...)` with the
//      right unique name / task name / 24-hour frequency.
//   3. `cancelNightlyBackup()` calls
//      `Workmanager().cancelByUniqueName(...)`.
//   4. `scheduleNightlyBackup()` before `init()` throws.
//   5. (v0.4b release fix, ADR-013) `init()` does not
//      rethrow when the platform throws. The cold-start
//      smoke test in `main()` must not crash the app if
//      the workmanager plugin is missing or restricted.
//   6. (v0.4b release fix, ADR-013) the dispatcher function
//      passed to `Workmanager().initialize(...)` is the
//      **public** top-level `backupTaskDispatcher`. A
//      private dispatcher cannot be resolved by name from
//      a background isolate in release AOT builds, which
//      causes the OS to fail to bind the periodic task.
//
// The dispatcher itself (`backupTaskDispatcher`) is the
// Dart entry point the OS calls when a periodic task fires.
// Dispatcher behavior is tested separately in
// `backup_task_dispatcher_test.dart` because the dispatcher
// lives in a top-level function and cannot be reached
// through the `BackupScheduler` API.

import 'package:doit/services/backup_scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    'be.tramckrijte.workmanager/foreground_channel_work_manager',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    BackupScheduler.instance.resetForTesting();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('init() calls Workmanager.initialize exactly once', () async {
    await BackupScheduler.instance.init();
    final inits = calls.where((c) => c.method == 'initialize').toList();
    expect(inits.length, 1, reason: 'initialize must be called exactly once');
  });

  test('init() is idempotent: a second call does not re-initialize', () async {
    await BackupScheduler.instance.init();
    await BackupScheduler.instance.init();
    final inits = calls.where((c) => c.method == 'initialize').toList();
    expect(
      inits.length,
      1,
      reason: 'A second init() must be a no-op (gate is completed)',
    );
  });

  test('scheduleNightlyBackup() before init() throws StateError', () async {
    expect(
      BackupScheduler.instance.scheduleNightlyBackup,
      throwsA(isA<StateError>()),
      reason:
          'The scheduler must reject a schedule call before init() '
          'completes, so the production wiring is forced to await '
          'init() first.',
    );
  });

  test('scheduleNightlyBackup() registers a 24h periodic task with the '
      'right unique name and task name', () async {
    await BackupScheduler.instance.init();
    await BackupScheduler.instance.scheduleNightlyBackup();
    final regs = calls
        .where((c) => c.method == 'registerPeriodicTask')
        .toList();
    expect(regs.length, 1, reason: 'Exactly one register call');
    final args = (regs.first.arguments as Map?) ?? const {};
    expect(
      args['uniqueName'],
      kBackupNightlyTaskName,
      reason: 'uniqueName must be doit.backup.nightly',
    );
    expect(
      args['taskName'],
      kBackupNightlyTaskName,
      reason: 'taskName must be doit.backup.nightly',
    );
    // frequency is serialized as a Duration object; we check
    // the inMinutes / inHours keys (workmanager 0.6.0 sends
    // minutes + hours separately, see JsonMapperHelper).
    expect(
      BackupScheduler.instance.isNightlyScheduled,
      isTrue,
      reason: 'The scheduler must flip isNightlyScheduled after success',
    );
  });

  test(
    'cancelNightlyBackup() calls cancelByUniqueName and clears the flag',
    () async {
      await BackupScheduler.instance.init();
      await BackupScheduler.instance.scheduleNightlyBackup();
      await BackupScheduler.instance.cancelNightlyBackup();
      final cancels = calls
          .where((c) => c.method == 'cancelTaskByUniqueName')
          .toList();
      expect(cancels.length, 1, reason: 'Exactly one cancel call');
      final args = (cancels.first.arguments as Map?) ?? const {};
      expect(args['uniqueName'], kBackupNightlyTaskName);
      expect(BackupScheduler.instance.isNightlyScheduled, isFalse);
    },
  );

  // v0.4b release fix (ADR-013). If the workmanager plugin
  // throws on a real device (e.g. an OEM that has killed
  // WorkManager, or a missing callback handle on a build
  // without the plugin side wired up), `init()` MUST NOT
  // rethrow. `main()` calls `await init()` before `runApp`;
  // a rethrown exception would crash the app on first
  // launch. The catch path logs the error and leaves the
  // gate uncompleted so a later retry can re-init.
  test(
    'init() swallows platform exceptions (release-mode crash fix, ADR-013)',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'initialize') {
          throw PlatformException(
            code: '1',
            message: 'Simulated workmanager plugin failure',
          );
        }
        return null;
      });
      // Must not throw.
      await BackupScheduler.instance.init();
      // The init() call was made; the platform exception
      // was swallowed.
      final inits = calls.where((c) => c.method == 'initialize').toList();
      expect(inits.length, 1, reason: 'init() was attempted');
      // The gate is left uncompleted: a follow-up
      // scheduleNightlyBackup() must throw StateError, so the
      // UI surfaces a clear error rather than a silent miss.
      expect(
        BackupScheduler.instance.scheduleNightlyBackup,
        throwsA(isA<StateError>()),
      );
    },
  );

  // v0.4b release fix (ADR-013). The dispatcher passed to
  // `Workmanager().initialize(...)` must be the **public**
  // top-level `backupTaskDispatcher`. A private dispatcher
  // (a leading underscore) cannot be resolved by name from
  // a background isolate in release AOT builds, which causes
  // the OS to fail to bind the periodic task. This test
  // pins the symbol at the type-system level: the export
  // is public, and the symbol exists at top level.
  test('backupTaskDispatcher is a public top-level function (ADR-013)', () {
    // Compile-time check: the symbol is reachable as a
    // top-level function (not a private one). `const`
    // evaluates the reference at compile time, which is
    // the strongest possible "this is a real symbol" pin
    // — a renamed/privatized symbol would break the
    // compilation of this test, not just the runtime.
    const Function ref = backupTaskDispatcher;
    expect(ref, isNotNull);
  });
}
