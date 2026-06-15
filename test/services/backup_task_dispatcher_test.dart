// Tests for the WorkManager dispatcher body (v0.4b / SYS-060).
// `runBackupTask` is the test seam that the dispatcher
// delegates to; the dispatcher itself is a
// `@pragma('vm:entry-point')` wrapper that the test harness
// cannot easily reach.

import 'dart:io';

import 'package:common_games/services/backup_scheduler.dart';
import 'package:common_games/services/backup_service.dart';
import 'package:common_games/services/db.dart';
import 'package:common_games/services/db/schema.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _resetDb() async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  await AppDatabaseService.instance.ready;
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });
}

void main() {
  setUp(() async {
    await _resetDb();
    BackupService.resetForTesting();
    await BackupService.instance.init();
  });

  test('runBackupTask() with no folder URI returns true (no-op)', () async {
    SharedPreferences.setMockInitialValues({});
    final ok = await runBackupTask();
    expect(
      ok,
      isTrue,
      reason: 'A missing folder URI is a no-op, not a failure',
    );
  });

  test('runBackupTask() with a real folder writes a JSON file', () async {
    final dir = await Directory.systemTemp.createTemp('streak-backup-task-');
    final uri = dir.uri.toString();
    SharedPreferences.setMockInitialValues({'streak.backup.folder_uri': uri});
    final db = AppDatabaseService.instance.db;
    await db
        .into(db.habits)
        .insert(
          HabitsCompanion.insert(
            id: 'h1',
            name: 'Stretch',
            proofMode: 'soft',
            createdAtMillis: 1718000000000,
            scheduleType: 'fixed',
            weekdays: const Value('1,3,5'),
            hour: const Value(9),
            minute: const Value(0),
          ),
        );
    final ok = await runBackupTask();
    expect(ok, isTrue, reason: 'A valid folder should yield a successful run');
    final out = File('${dir.path}/streak-backup.json');
    expect(await out.exists(), isTrue);
    final contents = await out.readAsString();
    expect(
      contents,
      contains('"version":${BackupService.kBackupFormatVersion}'),
    );
    expect(contents, contains('Stretch'));
  });

  test('runBackupTask() with a missing folder returns true (no-op)', () async {
    final dir = await Directory.systemTemp.createTemp('streak-backup-missing-');
    // Do not create the directory. The URI points to a path
    // that does not exist.
    final uri = '${dir.uri.toString()}no-such-subdir/';
    SharedPreferences.setMockInitialValues({'streak.backup.folder_uri': uri});
    final ok = await runBackupTask();
    expect(
      ok,
      isTrue,
      reason:
          'A folder URI pointing to a non-existent directory is a '
          'no-op, not a failure. The user may have uninstalled the '
          'SAF folder; the next periodic run will recreate it.',
    );
  });
}
