// Tests for the `runBackupTask` early-return when no backup
// folder has been picked (v1.4-stab-F / Phase 46 / SYS-133).
//
// v1.4-stab-A audit: 5 lines uncovered in
// `lib/services/backup_scheduler.dart` were the
// `ScheduleMode.none` early-return + the `dir.exists()`
// false-branch + the exception-swallow catch. This file pins
// the `ScheduleMode.none` path (the user has not finished
// onboarding yet) — the early-return at `backup_scheduler.dart:111-115`
// MUST return `true` (per the contract at
// `backup_scheduler.dart:103-105`: "Returns `true` on success
// (including the 'no folder configured yet' no-op)").

import 'package:doit/services/backup_scheduler.dart';
import 'package:doit/services/backup_service.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Reset the singletons so the test starts clean. The
    // scheduler holds stateful `Completer`s; the DB singleton
    // holds a Drift connection.
    BackupScheduler.instance.resetForTesting();
    BackupService.resetForTesting();
    await AppDatabaseService.instance.closeForTesting();
    final memDb = AppDatabase(NativeDatabase.memory());
    await AppDatabaseService.instance.init(overrideDb: memDb);
    await AppDatabaseService.instance.ready;
    addTearDown(() async {
      BackupScheduler.instance.resetForTesting();
      BackupService.resetForTesting();
      await AppDatabaseService.instance.closeForTesting();
    });
  });

  test('runBackupTask returns true when no backup folder has been '
      'picked yet (ScheduleMode.none early-return / SYS-133)',
      () async {
    // The user has not completed onboarding; SharedPreferences
    // has no value for 'doit.backup.folder_uri'. The scheduler
    // MUST short-circuit to a `true` return (success-no-op)
    // rather than calling `exportTo` with a null out path or
    // crashing.
    SharedPreferences.setMockInitialValues({});

    final ok = await runBackupTask();
    expect(
      ok,
      isTrue,
      reason: 'When no folder is configured, runBackupTask must '
          'return true (the "no-op success" path) so the '
          'WorkManager periodic task does not flag the run as '
          'failed. The next periodic interval retries.',
    );
  });
}
