// Backup service — JSON export / import for Streak's local DB.
//
// The service is the only writer of backup files. Export
// serializes every table (Habits, People, Completions,
// RestDayBudgets, Settings, EventLogs) to a single JSON object;
// import wipes the local DB and replaces it with the parsed
// payload. The wire format is `{"version": 1, "tables": {...}}`.
//
// v0.4c.1 (SYS-061) adds the v2 envelope: AES-256-GCM over
// the same JSON payload, key derived from a user-supplied
// passphrase via PBKDF2-HMAC-SHA256 (≥ 100,000 iterations,
// 16-byte random salt). The v1 plain-JSON path stays
// supported on read for back-compat; writes default to v2
// when a passphrase is supplied. v0.4 does NOT auto-write
// v2 backups — the user opts in from the backup screen with
// a passphrase prompt.
//
// Layer rules (per .claude/rules/lib-services.md): singleton
// with `Completer<void> _ready`; all public methods async.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';

import 'package:common_games/services/db.dart';
import 'package:common_games/services/db/schema.dart';

/// Thrown by [BackupService.importFrom] when the file is missing,
/// unparseable, or has a different schema version.
class BackupFormatException implements Exception {
  BackupFormatException(this.message);
  final String message;
  @override
  String toString() => 'BackupFormatException: $message';
}

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  /// Idempotent. Production calls this from `main.dart` after
  /// `AppDatabaseService.init()`.
  Future<void> init() async {
    if (_ready.isCompleted) return;
    _ready.complete();
  }

  /// Reset for tests.
  static void resetForTesting() {
    instance._ready = Completer<void>();
  }

  AppDatabase get _db => AppDatabaseService.instance.db;

  /// Current backup format version. Bumped on any breaking
  /// change to the on-disk JSON layout.
  ///
  /// - v1: plain JSON envelope, no encryption. Read-only on
  ///   v0.4+; the import path still accepts v1 for back-compat.
  /// - v2 (v0.4c.1 / SYS-061): encrypted envelope. The JSON
  ///   payload is encrypted with AES-256-GCM using a key
  ///   derived from a user-supplied passphrase via
  ///   PBKDF2-HMAC-SHA256 (100,000 iterations, 16-byte salt).
  ///   The envelope is:
  ///   `{"version": 2, "kdf": {"name": "pbkdf2-hmac-sha256",
  ///   "iterations": 100000, "saltB64": "..."}, "ciphertextB64":
  ///   "...", "nonceB64": "..."}`.
  static const int kBackupFormatVersion = 2;

  /// Number of PBKDF2 iterations for the v2 envelope. 100,000
  /// is OWASP's 2023+ recommendation; lower values are not
  /// accepted on read.
  static const int kBackupKdfIterations = 100000;

  /// The plain-JSON v1 envelope version. Read-only on v0.4+;
  /// the import path still accepts it for back-compat.
  static const int kBackupFormatVersionV1 = 1;

  /// Write a JSON snapshot of every table to [file]. Overwrites
  /// any existing file. Returns the number of bytes written.
  ///
  /// If [passphrase] is `null`, writes a v1 plain-JSON
  /// envelope (back-compat). If [passphrase] is non-null,
  /// writes a v2 encrypted envelope.
  Future<int> exportTo(File file, {String? passphrase}) async {
    await ready;
    final payload = await _readAllTables();
    if (passphrase == null) {
      final bytes = utf8.encode(jsonEncode(payload));
      await file.writeAsBytes(bytes, flush: true);
      return bytes.length;
    }
    final envelope = await _encryptV2(payload, passphrase);
    final bytes = utf8.encode(jsonEncode(envelope));
    await file.writeAsBytes(bytes, flush: true);
    return bytes.length;
  }

  /// Read a JSON snapshot from [file] and replace the local DB
  /// contents with it. The current contents are wiped inside a
  /// transaction; if the file is malformed the transaction
  /// rolls back and the DB is left untouched.
  ///
  /// Accepts both v1 (plain JSON) and v2 (encrypted) envelopes.
  /// For v2 the caller must supply [passphrase]; a wrong
  /// passphrase throws [BackupFormatException] ("decryption
  /// failed"). For v1 the [passphrase] is ignored.
  Future<int> importFrom(File file, {String? passphrase}) async {
    await ready;
    if (!await file.exists()) {
      throw BackupFormatException('File does not exist: ${file.path}');
    }
    final raw = await file.readAsBytes();
    final Map<String, Object?> envelope;
    try {
      envelope = jsonDecode(utf8.decode(raw)) as Map<String, Object?>;
    } catch (e) {
      throw BackupFormatException('File is not valid JSON: $e');
    }
    final version = envelope['version'];
    if (version is! int || version > kBackupFormatVersion) {
      throw BackupFormatException(
        'Unsupported backup version: $version '
        '(this build understands up to $kBackupFormatVersion).',
      );
    }
    final Map<String, Object?> payload;
    if (version == kBackupFormatVersionV1) {
      payload = envelope;
    } else {
      // v2: decrypt with the user-supplied passphrase.
      if (passphrase == null || passphrase.isEmpty) {
        throw BackupFormatException(
          'Backup is encrypted (v2); a passphrase is required.',
        );
      }
      payload = await _decryptV2(envelope, passphrase);
    }
    final tables = payload['tables'] as Map<String, Object?>?;
    if (tables == null) {
      throw BackupFormatException('Missing "tables" object.');
    }
    final counts = <String, int>{};
    await _db.transaction(() async {
      // Wipe in FK-safe order: completions + budgets before
      // habits; people after habits (people don't reference
      // habits, but the order is stable for tests).
      await _db.delete(_db.eventLogs).go();
      await _db.delete(_db.settings).go();
      await _db.delete(_db.restDayBudgets).go();
      await _db.delete(_db.completions).go();
      await _db.delete(_db.habits).go();
      await _db.delete(_db.people).go();
      counts['habits'] = await _insertRows(
        'habits',
        tables['habits'] as List<Object?>? ?? const [],
        _habitFromJson,
      );
      counts['people'] = await _insertRows(
        'people',
        tables['people'] as List<Object?>? ?? const [],
        _personFromJson,
      );
      counts['completions'] = await _insertRows(
        'completions',
        tables['completions'] as List<Object?>? ?? const [],
        _completionFromJson,
      );
      counts['restDayBudgets'] = await _insertRows(
        'restDayBudgets',
        tables['restDayBudgets'] as List<Object?>? ?? const [],
        _budgetFromJson,
      );
      counts['settings'] = await _insertRows(
        'settings',
        tables['settings'] as List<Object?>? ?? const [],
        _settingFromJson,
      );
      counts['eventLogs'] = await _insertRows(
        'eventLogs',
        tables['eventLogs'] as List<Object?>? ?? const [],
        _eventLogFromJson,
      );
    });
    var total = 0;
    for (final c in counts.values) {
      total += c;
    }
    return total;
  }

  Future<Map<String, Object?>> _readAllTables() async {
    final habits = await _db.select(_db.habits).get();
    final people = await _db.select(_db.people).get();
    final completions = await _db.select(_db.completions).get();
    final budgets = await _db.select(_db.restDayBudgets).get();
    final settings = await _db.select(_db.settings).get();
    final events = await _db.select(_db.eventLogs).get();
    return {
      // The inner payload version is always 1 — the v2 envelope
      // wraps the same payload in an outer `{version: 2, kdf: ...}`
      // shell. Keeping the inner version at 1 means the v1
      // import path is the single source of truth on read, and
      // v1 fixtures stay back-compat.
      'version': kBackupFormatVersionV1,
      'exportedAtMillis': DateTime.now().toUtc().millisecondsSinceEpoch,
      'tables': {
        'habits': habits.map(_habitToJson).toList(growable: false),
        'people': people.map(_personToJson).toList(growable: false),
        'completions': completions
            .map(_completionToJson)
            .toList(growable: false),
        'restDayBudgets': budgets.map(_budgetToJson).toList(growable: false),
        'settings': settings.map(_settingToJson).toList(growable: false),
        'eventLogs': events.map(_eventLogToJson).toList(growable: false),
      },
    };
  }

  Future<int> _insertRows(
    String table,
    List<Object?> raw,
    Insertable<dynamic> Function(Map<String, Object?>) parse,
  ) async {
    var count = 0;
    for (final r in raw) {
      if (r is! Map<String, Object?>) continue;
      final row = parse(r);
      // The compiler can't infer the table here; we use the
      // generic `into(table).insert(row)` for each case via
      // runtime dispatch in a switch below.
      await _insertRow(table, row);
      count++;
    }
    return count;
  }

  Future<void> _insertRow(String table, Insertable<dynamic> row) async {
    switch (table) {
      case 'habits':
        await _db.into(_db.habits).insert(row as Insertable<HabitRow>);
      case 'people':
        await _db.into(_db.people).insert(row as Insertable<PersonRow>);
      case 'completions':
        await _db
            .into(_db.completions)
            .insert(row as Insertable<CompletionRow>);
      case 'restDayBudgets':
        await _db
            .into(_db.restDayBudgets)
            .insert(row as Insertable<RestDayBudgetRow>);
      case 'settings':
        await _db.into(_db.settings).insert(row as Insertable<SettingRow>);
      case 'eventLogs':
        await _db.into(_db.eventLogs).insert(row as Insertable<EventLogRow>);
    }
  }

  // --- HabitRow <-> JSON -----------------------------------------

  Map<String, Object?> _habitToJson(HabitRow r) => {
    'id': r.id,
    'name': r.name,
    'proofMode': r.proofMode,
    'createdAtMillis': r.createdAtMillis,
    'restDaysPerMonth': r.restDaysPerMonth,
    'scheduleType': r.scheduleType,
    'weekdays': r.weekdays,
    'hour': r.hour,
    'minute': r.minute,
    'nDays': r.nDays,
    'referenceDateMillis': r.referenceDateMillis,
    'targetHabitId': r.targetHabitId,
    'lastAnchorMillis': r.lastAnchorMillis,
    'dayOfMonth': r.dayOfMonth,
    'nth': r.nth,
    'weekday': r.weekday,
    'referenceDayOfMonth': r.referenceDayOfMonth,
    'missionChainJson': r.missionChainJson,
  };

  HabitsCompanion _habitFromJson(Map<String, Object?> j) => HabitsCompanion(
    id: Value(j['id']! as String),
    name: Value(j['name']! as String),
    proofMode: Value(j['proofMode']! as String),
    createdAtMillis: Value((j['createdAtMillis']! as num).toInt()),
    restDaysPerMonth: Value((j['restDaysPerMonth']! as num).toInt()),
    scheduleType: Value(j['scheduleType']! as String),
    weekdays: Value(j['weekdays'] as String?),
    hour: Value((j['hour'] as num?)?.toInt()),
    minute: Value((j['minute'] as num?)?.toInt()),
    nDays: Value((j['nDays'] as num?)?.toInt()),
    referenceDateMillis: Value((j['referenceDateMillis'] as num?)?.toInt()),
    targetHabitId: Value(j['targetHabitId'] as String?),
    lastAnchorMillis: Value((j['lastAnchorMillis'] as num?)?.toInt()),
    dayOfMonth: Value((j['dayOfMonth'] as num?)?.toInt()),
    nth: Value((j['nth'] as num?)?.toInt()),
    weekday: Value((j['weekday'] as num?)?.toInt()),
    referenceDayOfMonth: Value((j['referenceDayOfMonth'] as num?)?.toInt()),
    missionChainJson: Value(j['missionChainJson'] as String?),
  );

  // --- PersonRow <-> JSON ----------------------------------------

  Map<String, Object?> _personToJson(PersonRow r) => {
    'id': r.id,
    'lookupKey': r.lookupKey,
    'displayName': r.displayName,
    'channel': r.channel,
    'handle': r.handle,
    'createdAtMillis': r.createdAtMillis,
    'cadenceType': r.cadenceType,
    'nDays': r.nDays,
    'weekday': r.weekday,
    'dayOfMonth': r.dayOfMonth,
    'monthOfYear': r.monthOfYear,
    'anchoredToWakeup': r.anchoredToWakeup,
    'missionChainJson': r.missionChainJson,
  };

  PeopleCompanion _personFromJson(Map<String, Object?> j) => PeopleCompanion(
    id: Value(j['id']! as String),
    lookupKey: Value(j['lookupKey']! as String),
    displayName: Value(j['displayName']! as String),
    channel: Value(j['channel']! as String),
    handle: Value(j['handle']! as String),
    createdAtMillis: Value((j['createdAtMillis']! as num).toInt()),
    cadenceType: Value(j['cadenceType']! as String),
    nDays: Value((j['nDays'] as num?)?.toInt()),
    weekday: Value((j['weekday'] as num?)?.toInt()),
    dayOfMonth: Value((j['dayOfMonth'] as num?)?.toInt()),
    monthOfYear: Value((j['monthOfYear'] as num?)?.toInt()),
    anchoredToWakeup: Value((j['anchoredToWakeup'] as bool?) ?? false),
    missionChainJson: Value(j['missionChainJson'] as String?),
  );

  // --- CompletionRow <-> JSON ------------------------------------

  Map<String, Object?> _completionToJson(CompletionRow r) => {
    'id': r.id,
    'habitId': r.habitId,
    'dayMillis': r.dayMillis,
    'completedAtMillis': r.completedAtMillis,
    'source': r.source,
    'proofModeAtTime': r.proofModeAtTime,
    'note': r.note,
    'missionResultsJson': r.missionResultsJson,
  };

  CompletionsCompanion _completionFromJson(Map<String, Object?> j) =>
      CompletionsCompanion(
        id: Value(j['id']! as String),
        habitId: Value(j['habitId']! as String),
        dayMillis: Value((j['dayMillis']! as num).toInt()),
        completedAtMillis: Value((j['completedAtMillis']! as num).toInt()),
        source: Value(j['source']! as String),
        proofModeAtTime: Value(j['proofModeAtTime']! as String),
        note: Value(j['note'] as String?),
        missionResultsJson: Value(j['missionResultsJson'] as String?),
      );

  // --- RestDayBudgetRow <-> JSON ---------------------------------

  Map<String, Object?> _budgetToJson(RestDayBudgetRow r) => {
    'id': r.id,
    'habitId': r.habitId,
    'yearMonth': r.yearMonth,
    'used': r.used,
    'monthlyLimit': r.monthlyLimit,
  };

  RestDayBudgetsCompanion _budgetFromJson(Map<String, Object?> j) =>
      RestDayBudgetsCompanion(
        id: Value(j['id']! as String),
        habitId: Value(j['habitId']! as String),
        yearMonth: Value((j['yearMonth']! as num).toInt()),
        used: Value((j['used']! as num).toInt()),
        monthlyLimit: Value((j['monthlyLimit']! as num).toInt()),
      );

  // --- SettingRow <-> JSON ---------------------------------------

  Map<String, Object?> _settingToJson(SettingRow r) => {
    'key': r.key,
    'value': r.value,
  };

  SettingsCompanion _settingFromJson(Map<String, Object?> j) =>
      SettingsCompanion(
        key: Value(j['key']! as String),
        value: Value(j['value']! as String),
      );

  // --- EventLogRow <-> JSON --------------------------------------

  Map<String, Object?> _eventLogToJson(EventLogRow r) => {
    'id': r.id,
    'atMillis': r.atMillis,
    'kind': r.kind,
    'detailJson': r.detailJson,
  };

  EventLogsCompanion _eventLogFromJson(Map<String, Object?> j) =>
      EventLogsCompanion(
        id: Value(j['id']! as String),
        atMillis: Value((j['atMillis']! as num).toInt()),
        kind: Value(j['kind']! as String),
        detailJson: Value(j['detailJson'] as String?),
      );

  // --- v2 encryption envelope (SYS-061) ---------------------------
  //
  // The plaintext is the same JSON payload that v1 writes
  // (`{"version": 1, "tables": {...}, ...}` — note the inner
  // version stays 1 so the v1 parser is the single source of
  // truth on read). The envelope is:
  //
  //   {
  //     "version": 2,
  //     "kdf": { "name": "pbkdf2-hmac-sha256",
  //              "iterations": 100000,
  //              "saltB64": "<16 random bytes, base64>" },
  //     "ciphertextB64": "<AES-256-GCM ciphertext, base64>",
  //     "nonceB64": "<12 random bytes, base64>"
  //   }
  //
  // The MAC tag is appended to the ciphertext by the
  // `cryptography` package's AES-GCM; the v2 envelope does
  // not store it separately. A wrong passphrase surfaces
  // as a decryption failure (the MAC check rejects it).

  static final Random _rng = Random.secure();
  static final Pbkdf2 _pbkdf2 = Pbkdf2.hmacSha256(
    iterations: kBackupKdfIterations,
    bits: 256,
  );
  static final AesGcm _aesGcm = AesGcm.with256bits();

  Future<Map<String, Object?>> _encryptV2(
    Map<String, Object?> payload,
    String passphrase,
  ) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    final box = await _aesGcm.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: secretKey,
      nonce: nonce,
    );
    return {
      'version': kBackupFormatVersion,
      'kdf': {
        'name': 'pbkdf2-hmac-sha256',
        'iterations': kBackupKdfIterations,
        'saltB64': base64Encode(salt),
      },
      'ciphertextB64': base64Encode(box.cipherText),
      'macB64': base64Encode(box.mac.bytes),
      'nonceB64': base64Encode(nonce),
    };
  }

  Future<Map<String, Object?>> _decryptV2(
    Map<String, Object?> envelope,
    String passphrase,
  ) async {
    final kdf = envelope['kdf'];
    if (kdf is! Map) {
      throw BackupFormatException('Missing or malformed "kdf" object.');
    }
    final name = kdf['name'];
    final iterations = kdf['iterations'];
    final saltB64 = kdf['saltB64'];
    final ciphertextB64 = envelope['ciphertextB64'];
    final macB64 = envelope['macB64'];
    final nonceB64 = envelope['nonceB64'];
    if (name != 'pbkdf2-hmac-sha256' ||
        iterations is! int ||
        saltB64 is! String ||
        ciphertextB64 is! String ||
        macB64 is! String ||
        nonceB64 is! String) {
      throw BackupFormatException('Malformed v2 envelope.');
    }
    if (iterations < kBackupKdfIterations) {
      throw BackupFormatException(
        'KDF iterations below minimum: $iterations < $kBackupKdfIterations',
      );
    }
    final salt = base64Decode(saltB64);
    final ciphertext = base64Decode(ciphertextB64);
    final macBytes = base64Decode(macB64);
    final nonce = base64Decode(nonceB64);
    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    try {
      final clear = await _aesGcm.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(macBytes)),
        secretKey: secretKey,
      );
      return jsonDecode(utf8.decode(clear)) as Map<String, Object?>;
    } catch (e) {
      throw BackupFormatException('Decryption failed (wrong passphrase?).');
    }
  }

  List<int> _randomBytes(int n) {
    final out = List<int>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }
}
