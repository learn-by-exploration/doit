// Tests for the v2 encrypted backup envelope (v0.4c.1 /
// SYS-061). Round-trips a habit row through the export +
// import with a passphrase, asserts the wrong passphrase
// fails, asserts a v1 fixture is still readable on the
// v0.4+ import path (back-compat), and asserts the KDF
// iteration floor is enforced.

import 'dart:io';

import 'package:common_games/services/backup_service.dart';
import 'package:common_games/services/db.dart';
import 'package:common_games/services/db/schema.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<File> _writeTemp(String name, String body) async {
  final dir = await Directory.systemTemp.createTemp('streak-enc-');
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

  test(
    'encrypted export + import round-trip with the right passphrase',
    () async {
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
      final tmp = await _writeTemp('enc.json', '');
      await BackupService.instance.exportTo(
        tmp,
        passphrase: 'correct horse battery staple',
      );
      final contents = await tmp.readAsString();
      expect(contents, contains('"version":2'));
      expect(contents, contains('"kdf"'));
      expect(contents, contains('"ciphertextB64"'));
      expect(contents, contains('"macB64"'));
      expect(contents, contains('"nonceB64"'));
      // The plaintext must NOT appear in the file.
      expect(contents, isNot(contains('Stretch')));

      // Wipe and restore.
      await db.delete(db.habits).go();
      expect((await db.select(db.habits).get()).length, 0);
      final count = await BackupService.instance.importFrom(
        tmp,
        passphrase: 'correct horse battery staple',
      );
      expect(count, 1);
      final rows = await db.select(db.habits).get();
      expect(rows.length, 1);
      expect(rows.first.id, 'h1');
      expect(rows.first.name, 'Stretch');
    },
  );

  test('encrypted import with the wrong passphrase throws', () async {
    final tmp = await _writeTemp('enc.json', '');
    await BackupService.instance.exportTo(tmp, passphrase: 'right');
    expect(
      () => BackupService.instance.importFrom(tmp, passphrase: 'wrong'),
      throwsA(isA<BackupFormatException>()),
      reason: 'A wrong passphrase must surface as a format error',
    );
  });

  test('encrypted import with no passphrase throws', () async {
    final tmp = await _writeTemp('enc.json', '');
    await BackupService.instance.exportTo(tmp, passphrase: 'right');
    expect(
      () => BackupService.instance.importFrom(tmp),
      throwsA(isA<BackupFormatException>()),
      reason: 'A v2 envelope without a passphrase must be rejected',
    );
  });

  test('v1 plain-JSON import still works on the v0.4+ path', () async {
    final db = AppDatabaseService.instance.db;
    final tmp = await _writeTemp(
      'v1.json',
      '{"version":1,"tables":{"habits":[{"id":"h1","name":"Stretch",'
          '"proofMode":"soft","createdAtMillis":1718000000000,'
          '"restDaysPerMonth":2,"scheduleType":"fixed","weekdays":'
          '"1,3,5","hour":9,"minute":0,"nDays":null,'
          '"referenceDateMillis":null,"targetHabitId":null,'
          '"lastAnchorMillis":null,"dayOfMonth":null,"nth":null,'
          '"weekday":null,"referenceDayOfMonth":null,'
          '"missionChainJson":null}]}}',
    );
    final count = await BackupService.instance.importFrom(tmp);
    expect(count, 1, reason: 'v1 plain-JSON must still be importable');
    final rows = await db.select(db.habits).get();
    expect(rows.first.id, 'h1');
    expect(rows.first.name, 'Stretch');
  });

  test('KDF iteration floor is enforced on read', () async {
    // Hand-craft a v2 envelope with iterations below the
    // floor; the importer must reject it.
    final tmp = await _writeTemp(
      'low-iter.json',
      '{"version":2,"kdf":{"name":"pbkdf2-hmac-sha256",'
          '"iterations":1000,"saltB64":"AAAAAAAAAAAAAAAAAAAAAA=="},'
          '"ciphertextB64":"","macB64":"","nonceB64":'
          '"AAAAAAAAAAAAAAAA"}}',
    );
    expect(
      () => BackupService.instance.importFrom(tmp, passphrase: 'x'),
      throwsA(isA<BackupFormatException>()),
      reason: 'A v2 envelope with iterations below the floor must be rejected',
    );
  });
}
