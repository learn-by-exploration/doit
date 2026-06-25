// Tests for the v3 encrypted backup envelope (v1.4a /
// SYS-115 / ADR-045). Round-trips a habit row through the
// export + import with a passphrase, asserts the wrong
// passphrase fails, asserts a v1 fixture is still readable
// on the v0.4+ import path (back-compat), asserts a v2
// (PBKDF2) fixture is still readable on the v1.4a+ import
// path (reads-from-v2 back-compat), and asserts the Argon2id
// iteration / memory floors are enforced.

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:doit/services/backup_service.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<File> _writeTemp(String name, String body) async {
  final dir = await Directory.systemTemp.createTemp('doit-enc-');
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
    'encrypted export + import round-trip with the right passphrase (v3)',
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
      expect(contents, contains('"version":3'));
      expect(contents, contains('"kdf"'));
      expect(contents, contains('"name":"argon2id"'));
      expect(contents, contains('"memoryKiB":19456'));
      expect(contents, contains('"iterations":2'));
      expect(contents, contains('"parallelism":1'));
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
      reason: 'A v3 envelope without a passphrase must be rejected',
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

  test('v2 PBKDF2 envelope still imports on the v1.4a path', () async {
    // Hand-craft a v2 envelope. The plaintext is the same JSON
    // the v1 writer emits, encrypted with PBKDF2-HMAC-SHA256
    // (100,000 iterations) + AES-256-GCM using the test
    // passphrase. This round-trips through the v2 reader.
    final db = AppDatabaseService.instance.db;
    final plaintext = utf8.encode(
      '{"version":1,"tables":{"habits":[{"id":"h1","name":"Stretch",'
      '"proofMode":"soft","createdAtMillis":1718000000000,'
      '"restDaysPerMonth":2,"scheduleType":"fixed","weekdays":'
      '"1,3,5","hour":9,"minute":0,"nDays":null,'
      '"referenceDateMillis":null,"targetHabitId":null,'
      '"lastAnchorMillis":null,"dayOfMonth":null,"nth":null,'
      '"weekday":null,"referenceDayOfMonth":null,'
      '"missionChainJson":null}]}}',
    );
    final salt = List<int>.filled(16, 0x42);
    final nonce = List<int>.filled(12, 0x33);
    final pbkdf2 = Pbkdf2.hmacSha256(
      iterations: BackupService.kBackupKdfIterations,
      bits: 256,
    );
    final aesGcm = AesGcm.with256bits();
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode('correct horse battery staple')),
      nonce: salt,
    );
    final box = await aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    final envelope = {
      'version': 2,
      'kdf': {
        'name': 'pbkdf2-hmac-sha256',
        'iterations': BackupService.kBackupKdfIterations,
        'saltB64': base64Encode(salt),
      },
      'ciphertextB64': base64Encode(box.cipherText),
      'macB64': base64Encode(box.mac.bytes),
      'nonceB64': base64Encode(nonce),
    };
    final tmp = await _writeTemp('v2.json', jsonEncode(envelope));
    final count = await BackupService.instance.importFrom(
      tmp,
      passphrase: 'correct horse battery staple',
    );
    expect(count, 1, reason: 'v2 PBKDF2 envelope must still be importable');
    final rows = await db.select(db.habits).get();
    expect(rows.first.id, 'h1');
    expect(rows.first.name, 'Stretch');
  });

  test('Argon2id iteration floor is enforced on read', () async {
    // Hand-craft a v3 envelope with iterations below the
    // floor; the importer must reject it.
    final tmp = await _writeTemp(
      'low-iter.json',
      '{"version":3,"kdf":{"name":"argon2id",'
          '"memoryKiB":19456,"iterations":1,"parallelism":1,'
          '"saltB64":"AAAAAAAAAAAAAAAAAAAAAA=="},'
          '"ciphertextB64":"","macB64":"","nonceB64":'
          '"AAAAAAAAAAAAAAAA"}}',
    );
    expect(
      () => BackupService.instance.importFrom(tmp, passphrase: 'x'),
      throwsA(isA<BackupFormatException>()),
      reason: 'A v3 envelope with iterations below the floor must be rejected',
    );
  });

  test('Argon2id memory floor is enforced on read', () async {
    final tmp = await _writeTemp(
      'low-mem.json',
      '{"version":3,"kdf":{"name":"argon2id",'
          '"memoryKiB":1024,"iterations":2,"parallelism":1,'
          '"saltB64":"AAAAAAAAAAAAAAAAAAAAAA=="},'
          '"ciphertextB64":"","macB64":"","nonceB64":'
          '"AAAAAAAAAAAAAAAA"}}',
    );
    expect(
      () => BackupService.instance.importFrom(tmp, passphrase: 'x'),
      throwsA(isA<BackupFormatException>()),
      reason: 'A v3 envelope with memory below the floor must be rejected',
    );
  });

  test('unknown KDF name is rejected', () async {
    final tmp = await _writeTemp(
      'unknown-kdf.json',
      '{"version":3,"kdf":{"name":"scrypt",'
          '"memoryKiB":19456,"iterations":2,"parallelism":1,'
          '"saltB64":"AAAAAAAAAAAAAAAAAAAAAA=="},'
          '"ciphertextB64":"","macB64":"","nonceB64":'
          '"AAAAAAAAAAAAAAAA"}}',
    );
    expect(
      () => BackupService.instance.importFrom(tmp, passphrase: 'x'),
      throwsA(isA<BackupFormatException>()),
      reason: 'A v3 envelope with an unknown KDF must be rejected',
    );
  });

  test('v3 envelope round-trips every table (people, completions, '
      'restDayBudgets, settings, eventLogs)', () async {
    // Insert one row per remaining table so every
    // `_personFromJson` / `_budgetFromJson` /
    // `_settingFromJson` / `_eventLogFromJson` parser runs
    // on import. The export side touches every
    // `_habitToJson` / `_personToJson` / `_completionToJson` /
    // `_budgetToJson` / `_settingToJson` / `_eventLogToJson`.
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
    await db
        .into(db.people)
        .insert(
          PeopleCompanion.insert(
            id: 'p1',
            lookupKey: 'lookup-p1',
            displayName: 'Alice',
            channel: 'sms',
            handle: '+15551234567',
            createdAtMillis: 1718000000000,
            cadenceType: 'every_n_days',
            nDays: const Value(3),
          ),
        );
    await db
        .into(db.completions)
        .insert(
          CompletionsCompanion.insert(
            id: 'c1',
            habitId: 'h1',
            dayMillis: 1718064000000,
            completedAtMillis: 1718067600000,
            source: 'manual',
            proofModeAtTime: 'soft',
          ),
        );
    await db
        .into(db.restDayBudgets)
        .insert(
          RestDayBudgetsCompanion.insert(
            id: 'b1',
            habitId: 'h1',
            yearMonth: 202406,
            used: const Value(0),
            monthlyLimit: 2,
          ),
        );
    await db
        .into(db.settings)
        .insert(
          SettingsCompanion.insert(
            key: 'backup_dir_uri',
            value: 'content://com.doit/backup',
          ),
        );
    await db
        .into(db.eventLogs)
        .insert(
          EventLogsCompanion.insert(
            id: 'e1',
            atMillis: 1718100000000,
            kind: 'habit.completed',
            detailJson: const Value('{"habitId":"h1"}'),
          ),
        );
    final tmp = await _writeTemp('full.json', '');
    await BackupService.instance.exportTo(
      tmp,
      passphrase: 'correct horse battery staple',
    );
    // Wipe everything, then restore and verify each table.
    await db.delete(db.eventLogs).go();
    await db.delete(db.settings).go();
    await db.delete(db.restDayBudgets).go();
    await db.delete(db.completions).go();
    await db.delete(db.habits).go();
    await db.delete(db.people).go();
    final count = await BackupService.instance.importFrom(
      tmp,
      passphrase: 'correct horse battery staple',
    );
    expect(count, 6, reason: 'All 6 table inserts must be counted');

    final habits = await db.select(db.habits).get();
    expect(habits.length, 1);
    expect(habits.first.name, 'Stretch');

    final people = await db.select(db.people).get();
    expect(people.length, 1);
    expect(people.first.displayName, 'Alice');

    final completions = await db.select(db.completions).get();
    expect(completions.length, 1);
    expect(completions.first.habitId, 'h1');

    final budgets = await db.select(db.restDayBudgets).get();
    expect(budgets.length, 1);
    expect(budgets.first.monthlyLimit, 2);

    final settings = await db.select(db.settings).get();
    expect(settings.length, 1);
    expect(settings.first.key, 'backup_dir_uri');

    final events = await db.select(db.eventLogs).get();
    expect(events.length, 1);
    expect(events.first.kind, 'habit.completed');
  });

  test('v3 envelope round-trips the v0.2 / v1.0 schema fields '
      '(pausedUntil, endHour, endMinute, targetHours, category, '
      'colorSeed, iconName, automationsJson) on habits + people', () async {
    final db = AppDatabaseService.instance.db;
    await db
        .into(db.habits)
        .insert(
          HabitsCompanion.insert(
            id: 'h1',
            name: 'Fast',
            proofMode: 'strong',
            createdAtMillis: 1718000000000,
            scheduleType: 'timeWindow',
            weekdays: const Value('1,2,3,4,5'),
            hour: const Value(20),
            minute: const Value(0),
            endHour: const Value(12),
            endMinute: const Value(0),
            targetHours: const Value(16),
            category: const Value('health'),
            colorSeed: const Value(3),
            iconName: const Value('restaurant'),
            pausedUntilMillis: const Value(1820000000000),
            automationsJson: const Value(
              '[{"trigger":"alarm","action":"notify"}]',
            ),
          ),
        );
    await db
        .into(db.people)
        .insert(
          PeopleCompanion.insert(
            id: 'p1',
            lookupKey: 'lookup-p1',
            displayName: 'Alice',
            channel: 'sms',
            handle: '+15551234567',
            createdAtMillis: 1718000000000,
            cadenceType: 'every_n_days',
            nDays: const Value(3),
            pausedUntilMillis: const Value(1825000000000),
            automationsJson: const Value(
              '[{"trigger":"contact","action":"notify"}]',
            ),
          ),
        );
    final tmp = await _writeTemp('schema2.json', '');
    await BackupService.instance.exportTo(
      tmp,
      passphrase: 'correct horse battery staple',
    );
    // Wipe + restore.
    await db.delete(db.habits).go();
    await db.delete(db.people).go();
    await BackupService.instance.importFrom(
      tmp,
      passphrase: 'correct horse battery staple',
    );
    final habits = await db.select(db.habits).get();
    expect(habits.length, 1);
    expect(habits.first.endHour, 12);
    expect(habits.first.endMinute, 0);
    expect(habits.first.targetHours, 16);
    expect(habits.first.category, 'health');
    expect(habits.first.colorSeed, 3);
    expect(habits.first.iconName, 'restaurant');
    expect(habits.first.pausedUntilMillis, 1820000000000);
    expect(
      habits.first.automationsJson,
      '[{"trigger":"alarm","action":"notify"}]',
    );

    final people = await db.select(db.people).get();
    expect(people.length, 1);
    expect(people.first.pausedUntilMillis, 1825000000000);
    expect(
      people.first.automationsJson,
      '[{"trigger":"contact","action":"notify"}]',
    );
  });

  test('exportTo accepts an optional reliability snapshot', () async {
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
    // With a reliability snapshot.
    final tmp = await _writeTemp('rel.json', '');
    await BackupService.instance.exportTo(
      tmp,
      passphrase: 'correct horse battery staple',
      reliability: 'degraded',
    );
    // The snapshot survives a round-trip; we re-import the
    // file (which decrypts + inserts the habit row), proving
    // the payload decoded successfully. The reliability key
    // itself is not stored in the DB, so a follow-up export
    // confirms its presence/absence semantics.
    await db.delete(db.habits).go();
    await BackupService.instance.importFrom(
      tmp,
      passphrase: 'correct horse battery staple',
    );
    expect((await db.select(db.habits).get()).length, 1);

    // Without a reliability snapshot, the key is absent.
    final tmp2 = await _writeTemp('no-rel.json', '');
    await BackupService.instance.exportTo(tmp2);
    final body = await tmp2.readAsString();
    expect(
      body.contains('"reliability"'),
      isFalse,
      reason: 'No reliability key when caller omits the param',
    );
  });

  test('v1 payload (no schemaVersion) still imports, missing '
      'v0.2 / v1.0 fields default to schema defaults', () async {
    final db = AppDatabaseService.instance.db;
    final tmp = await _writeTemp(
      'v1-no-schema2.json',
      '{"version":1,"tables":{"habits":[{"id":"h1","name":"Stretch",'
          '"proofMode":"soft","createdAtMillis":1718000000000,'
          '"restDaysPerMonth":2,"scheduleType":"fixed","weekdays":'
          '"1,3,5","hour":9,"minute":0,"nDays":null,'
          '"referenceDateMillis":null,"targetHabitId":null,'
          '"lastAnchorMillis":null,"dayOfMonth":null,"nth":null,'
          '"weekday":null,"referenceDayOfMonth":null,'
          '"missionChainJson":null}]}}',
    );
    await BackupService.instance.importFrom(tmp);
    final habits = await db.select(db.habits).get();
    expect(habits.length, 1);
    expect(habits.first.category, 'other', reason: 'schema default');
    expect(habits.first.colorSeed, 0, reason: 'schema default');
    expect(habits.first.iconName, isNull);
    expect(habits.first.pausedUntilMillis, isNull);
    expect(habits.first.automationsJson, isNull);
    expect(habits.first.endHour, isNull);
    expect(habits.first.targetHours, isNull);
  });
}
