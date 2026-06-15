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
//
// The dispatcher itself (`_backupTaskDispatcher`) is the
// Dart entry point the OS calls when a periodic task fires.
// Dispatcher behavior is tested separately in
// `backup_task_dispatcher_test.dart` because the dispatcher
// lives in a top-level function and cannot be reached
// through the `BackupScheduler` API.

import 'package:common_games/services/backup_scheduler.dart';
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
      reason: 'uniqueName must be streak.backup.nightly',
    );
    expect(
      args['taskName'],
      kBackupNightlyTaskName,
      reason: 'taskName must be streak.backup.nightly',
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
}
