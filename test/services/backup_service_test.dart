// Tests for the BackupService. Covers export / import round
// trips on a memory DB and the version-mismatch / malformed
// input error paths.

import 'dart:io';

import 'package:common_games/services/backup_service.dart';
import 'package:common_games/services/db.dart';
import 'package:common_games/services/db/schema.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<File> _writeTemp(String name, String body) async {
  final dir = await Directory.systemTemp.createTemp('streak-backup-');
  final f = File('${dir.path}/$name');
  await f.writeAsString(body);
  return f;
}

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

  test('export on an empty DB writes a valid JSON envelope', () async {
    final tmp = await _writeTemp('empty.json', '');
    final bytes = await BackupService.instance.exportTo(tmp);
    expect(bytes, greaterThan(0));
    final contents = await tmp.readAsString();
    expect(
      contents,
      contains('"version":${BackupService.kBackupFormatVersion}'),
    );
    expect(contents, contains('"tables"'));
  });

  test('export round-trip preserves habit rows', () async {
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
    final tmp = await _writeTemp('with-habit.json', '');
    await BackupService.instance.exportTo(tmp);
    // Wipe.
    await db.delete(db.habits).go();
    expect((await db.select(db.habits).get()).length, 0);
    // Restore.
    final count = await BackupService.instance.importFrom(tmp);
    expect(count, 1);
    final rows = await db.select(db.habits).get();
    expect(rows.length, 1);
    expect(rows.first.id, 'h1');
    expect(rows.first.name, 'Stretch');
    expect(rows.first.scheduleType, 'fixed');
    expect(rows.first.weekdays, '1,3,5');
  });

  test('import from a missing file throws BackupFormatException', () async {
    final tmp = await _writeTemp('gone.json', '{}');
    await tmp.delete();
    expect(
      () => BackupService.instance.importFrom(tmp),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('import from a malformed JSON throws BackupFormatException', () async {
    final tmp = await _writeTemp('bad.json', 'not-json');
    expect(
      () => BackupService.instance.importFrom(tmp),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test(
    'import from a future-version JSON throws BackupFormatException',
    () async {
      final tmp = await _writeTemp(
        'future.json',
        '{"version":${BackupService.kBackupFormatVersion + 1}, "tables":{}}',
      );
      expect(
        () => BackupService.instance.importFrom(tmp),
        throwsA(isA<BackupFormatException>()),
      );
    },
  );

  test('import with no tables object throws BackupFormatException', () async {
    final tmp = await _writeTemp('no-tables.json', '{"version":1}');
    expect(
      () => BackupService.instance.importFrom(tmp),
      throwsA(isA<BackupFormatException>()),
    );
  });
}
