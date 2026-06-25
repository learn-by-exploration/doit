// Backup service — JSON export / import for do it's local DB.
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
// 16-byte random salt). v1.4a (SYS-115 / ADR-045) bumps the
// envelope to v3: Argon2id (OWASP 2024 params: memory=19 MiB,
// iterations=2, parallelism=1) replaces PBKDF2. v2 stays
// supported on read for back-compat; writes default to v3
// when a passphrase is supplied. The v1 plain-JSON path is
// also still readable.
//
// Layer rules (per .claude/rules/lib-services.md): singleton
// with `Completer<void> _ready`; all public methods async.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';

import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';

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
  ///   Read-only on v1.4a+; the import path still accepts v2.
  /// - v3 (v1.4a / SYS-115 / ADR-045): encrypted envelope with
  ///   Argon2id (OWASP 2024 params: memory=19 MiB, iterations=2,
  ///   parallelism=1) replacing PBKDF2. The envelope is:
  ///   `{"version": 3, "kdf": {"name": "argon2id", "memoryKiB":
  ///   19456, "iterations": 2, "parallelism": 1, "saltB64":
  ///   "..."}, "ciphertextB64": "...", "macB64": "...",
  ///   "nonceB64": "..."}`.
  static const int kBackupFormatVersion = 3;

  /// Number of PBKDF2 iterations for the v2 envelope. 100,000
  /// is OWASP's 2023+ recommendation; lower values are not
  /// accepted on read.
  static const int kBackupKdfIterations = 100000;

  /// The plain-JSON v1 envelope version. Read-only on v0.4+;
  /// the import path still accepts it for back-compat.
  static const int kBackupFormatVersionV1 = 1;

  /// The PBKDF2-based v2 envelope version. Read-only on v1.4a+;
  /// the import path still accepts v2 for back-compat.
  static const int kBackupFormatVersionV2 = 2;

  /// Argon2id memory cost in KiB. 19456 KiB = 19 MiB, the
  /// OWASP 2024 recommendation for Argon2id v1.3.
  static const int kBackupArgon2MemoryKiB = 19456;

  /// Argon2id iteration count. 2 is the OWASP 2024
  /// recommendation when memory = 19 MiB.
  static const int kBackupArgon2Iterations = 2;

  /// Argon2id parallelism (lanes). 1 is the OWASP 2024
  /// recommendation for single-user mobile derive.
  static const int kBackupArgon2Parallelism = 1;

  /// Salt length for both PBKDF2 (v2) and Argon2id (v3).
  /// 16 bytes matches the v2 wire shape and is the lower
  /// bound OWASP recommends for Argon2id.
  static const int kBackupSaltBytes = 16;

  /// Current inner payload schema version. The outer
  /// envelope version (v1 / v2 / v3) is decoupled from the
  /// inner schema; the inner schema tracks the on-disk
  /// table-shape itself.
  ///
  /// - 1: v0.4c.1 (SYS-061) — the original payload shape.
  ///   Habits + people + completions + restDayBudgets +
  ///   settings + eventLogs with the v0.4 fields.
  /// - 2 (v1.4a / SYS-115 / ADR-045): adds the v0.2 visual
  ///   identity (category, colorSeed, iconName), the v0.2
  ///   time-window end + fasting target (endHour, endMinute,
  ///   targetHours), the v0.2 pause state (pausedUntilMillis
  ///   on habits + people), the v1.0 non-default automation
  ///   rules (automationsJson on habits + people), and a
  ///   top-level `reliability` snapshot carrying the last
  ///   `Reliability` enum value at export time. Old v1
  ///   payloads stay importable: every new field is optional
  ///   on read.
  static const int kBackupPayloadSchemaVersion = 2;

  /// The v0.4c.1 inner payload schema version. Read-only on
  /// v1.4a+; the import path still accepts it.
  static const int kBackupPayloadSchemaVersionV1 = 1;

  /// Write a JSON snapshot of every table to [file]. Overwrites
  /// any existing file. Returns the number of bytes written.
  ///
  /// If [passphrase] is `null`, writes a v1 plain-JSON
  /// envelope (back-compat). If [passphrase] is non-null,
  /// writes a v3 encrypted envelope (Argon2id + AES-256-GCM).
  ///
  /// [reliability] is the optional `Reliability` enum name
  /// (`optimal` / `degraded` / `unknown`) to snapshot into the
  /// payload's top-level `reliability` field. The caller is
  /// `main.dart` which reads `ReliabilityService.instance.value`.
  Future<int> exportTo(
    File file, {
    String? passphrase,
    String? reliability,
  }) async {
    await ready;
    final payload = await _readAllTables(reliability: reliability);
    if (passphrase == null) {
      final bytes = utf8.encode(jsonEncode(payload));
      await file.writeAsBytes(bytes, flush: true);
      return bytes.length;
    }
    final envelope = await _encryptV3(payload, passphrase);
    final bytes = utf8.encode(jsonEncode(envelope));
    await file.writeAsBytes(bytes, flush: true);
    return bytes.length;
  }

  /// Read a JSON snapshot from [file] and replace the local DB
  /// contents with it. The current contents are wiped inside a
  /// transaction; if the file is malformed the transaction
  /// rolls back and the DB is left untouched.
  ///
  /// Accepts v1 (plain JSON), v2 (PBKDF2 + AES-256-GCM), and
  /// v3 (Argon2id + AES-256-GCM) envelopes. For v2 / v3 the
  /// caller must supply [passphrase]; a wrong passphrase
  /// throws [BackupFormatException] ("decryption failed").
  /// For v1 the [passphrase] is ignored.
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
      // v2 / v3: decrypt with the user-supplied passphrase.
      if (passphrase == null || passphrase.isEmpty) {
        throw BackupFormatException(
          'Backup is encrypted (v$version); a passphrase is required.',
        );
      }
      payload = await _decrypt(envelope, passphrase, version);
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

  Future<Map<String, Object?>> _readAllTables({String? reliability}) async {
    final habits = await _db.select(_db.habits).get();
    final people = await _db.select(_db.people).get();
    final completions = await _db.select(_db.completions).get();
    final budgets = await _db.select(_db.restDayBudgets).get();
    final settings = await _db.select(_db.settings).get();
    final events = await _db.select(_db.eventLogs).get();
    return {
      // The inner payload `version` field stays at 1 — the v2
      // / v3 envelope wraps the same payload in an outer
      // `{version: N, kdf: ...}` shell. The new
      // `schemaVersion` field tracks the on-disk table-shape
      // itself; v1.4a bumps it 1 → 2 to add the v0.2 / v1.0
      // fields that the v0.4c.1 schema omitted.
      'version': kBackupFormatVersionV1,
      'schemaVersion': kBackupPayloadSchemaVersion,
      'exportedAtMillis': DateTime.now().toUtc().millisecondsSinceEpoch,
      // The reliability snapshot is the last-known
      // `Reliability` enum value at export time. Optional on
      // read: v1 payloads and un-set callers omit it.
      'reliability': ?reliability,
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
    // v0.2: timeWindow end + fasting target. Optional; null
    // for non-window / non-fasting habits.
    'endHour': r.endHour,
    'endMinute': r.endMinute,
    'targetHours': r.targetHours,
    'missionChainJson': r.missionChainJson,
    // v0.2: visual identity (category / colorSeed / iconName).
    // The defaults match the schema defaults; existing v1
    // payloads restore with the v0.4 defaults on read.
    'category': r.category,
    'colorSeed': r.colorSeed,
    'iconName': r.iconName,
    // v0.2: pause state. When set and in the future, the
    // scheduler does not fire reminders.
    'pausedUntilMillis': r.pausedUntilMillis,
    // v1.0: non-default automation rules (RoutineConfig).
    'automationsJson': r.automationsJson,
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
    endHour: Value((j['endHour'] as num?)?.toInt()),
    endMinute: Value((j['endMinute'] as num?)?.toInt()),
    targetHours: Value((j['targetHours'] as num?)?.toInt()),
    missionChainJson: Value(j['missionChainJson'] as String?),
    category: Value((j['category'] as String?) ?? 'other'),
    colorSeed: Value((j['colorSeed'] as num?)?.toInt() ?? 0),
    iconName: Value(j['iconName'] as String?),
    pausedUntilMillis: Value((j['pausedUntilMillis'] as num?)?.toInt()),
    automationsJson: Value(j['automationsJson'] as String?),
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
    // v0.2: pause state. Same semantics as habits.
    'pausedUntilMillis': r.pausedUntilMillis,
    // v1.0: non-default automation rules (RoutineConfig).
    'automationsJson': r.automationsJson,
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
    pausedUntilMillis: Value((j['pausedUntilMillis'] as num?)?.toInt()),
    automationsJson: Value(j['automationsJson'] as String?),
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

  // --- v3 encryption envelope (SYS-115 / ADR-045) -----------------
  //
  // The plaintext is the same JSON payload that v1 writes
  // (`{"version": 1, "tables": {...}, ...}` — note the inner
  // version stays 1 so the v1 parser is the single source of
  // truth on read). The envelope is:
  //
  //   {
  //     "version": 3,
  //     "kdf": { "name": "argon2id",
  //              "memoryKiB": 19456,
  //              "iterations": 2,
  //              "parallelism": 1,
  //              "saltB64": "<16 random bytes, base64>" },
  //     "ciphertextB64": "<AES-256-GCM ciphertext, base64>",
  //     "macB64": "<AES-GCM MAC tag, base64>",
  //     "nonceB64": "<12 random bytes, base64>"
  //   }
  //
  // OWASP 2024 recommends Argon2id with memory=19 MiB,
  // iterations=2, parallelism=1 (RFC 9106 "Argon2id v1.3").
  // The AES-GCM MAC tag is stored in `macB64` (matching the v2
  // wire shape) so a single ciphertext decoder serves both
  // envelopes. A wrong passphrase surfaces as a decryption
  // failure (the MAC check rejects it).
  //
  // v2 envelopes (PBKDF2-HMAC-SHA256) are still readable for
  // back-compat via the dispatcher in [_decrypt]. Reads-from-v2
  // are tested in `backup_encryption_test.dart`.

  static final Random _rng = Random.secure();
  static final Pbkdf2 _pbkdf2 = Pbkdf2.hmacSha256(
    iterations: kBackupKdfIterations,
    bits: 256,
  );
  static final Argon2id _argon2id = Argon2id(
    parallelism: kBackupArgon2Parallelism,
    memory: kBackupArgon2MemoryKiB,
    iterations: kBackupArgon2Iterations,
    hashLength: 32,
  );
  static final AesGcm _aesGcm = AesGcm.with256bits();

  Future<Map<String, Object?>> _encryptV3(
    Map<String, Object?> payload,
    String passphrase,
  ) async {
    final salt = _randomBytes(kBackupSaltBytes);
    final nonce = _randomBytes(12);
    final secretKey = await _argon2id.deriveKey(
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
        'name': 'argon2id',
        'memoryKiB': kBackupArgon2MemoryKiB,
        'iterations': kBackupArgon2Iterations,
        'parallelism': kBackupArgon2Parallelism,
        'saltB64': base64Encode(salt),
      },
      'ciphertextB64': base64Encode(box.cipherText),
      'macB64': base64Encode(box.mac.bytes),
      'nonceB64': base64Encode(nonce),
    };
  }

  /// Dispatch on the envelope's KDF name. v3 (Argon2id) is the
  /// current write path; v2 (PBKDF2) stays readable for back-compat.
  Future<Map<String, Object?>> _decrypt(
    Map<String, Object?> envelope,
    String passphrase,
    int version,
  ) async {
    final kdf = envelope['kdf'];
    if (kdf is! Map) {
      throw BackupFormatException('Missing or malformed "kdf" object.');
    }
    final name = kdf['name'];
    if (name == 'argon2id') {
      return _decryptV3(envelope, passphrase);
    }
    if (name == 'pbkdf2-hmac-sha256') {
      return _decryptV2(envelope, passphrase);
    }
    throw BackupFormatException(
      'Unsupported KDF "$name" in v$version envelope.',
    );
  }

  Future<Map<String, Object?>> _decryptV3(
    Map<String, Object?> envelope,
    String passphrase,
  ) async {
    final kdf = envelope['kdf'] as Map;
    final memoryKiB = kdf['memoryKiB'];
    final iterations = kdf['iterations'];
    final parallelism = kdf['parallelism'];
    final saltB64 = kdf['saltB64'];
    final ciphertextB64 = envelope['ciphertextB64'];
    final macB64 = envelope['macB64'];
    final nonceB64 = envelope['nonceB64'];
    if (memoryKiB is! int ||
        iterations is! int ||
        parallelism is! int ||
        saltB64 is! String ||
        ciphertextB64 is! String ||
        macB64 is! String ||
        nonceB64 is! String) {
      throw BackupFormatException('Malformed v3 envelope.');
    }
    if (iterations < kBackupArgon2Iterations) {
      throw BackupFormatException(
        'Argon2id iterations below minimum: '
        '$iterations < $kBackupArgon2Iterations',
      );
    }
    if (memoryKiB < kBackupArgon2MemoryKiB) {
      throw BackupFormatException(
        'Argon2id memory below minimum: '
        '$memoryKiB KiB < $kBackupArgon2MemoryKiB KiB',
      );
    }
    final argon2 = Argon2id(
      parallelism: parallelism,
      memory: memoryKiB,
      iterations: iterations,
      hashLength: 32,
    );
    final salt = base64Decode(saltB64);
    final ciphertext = base64Decode(ciphertextB64);
    final macBytes = base64Decode(macB64);
    final nonce = base64Decode(nonceB64);
    final secretKey = await argon2.deriveKey(
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

  Future<Map<String, Object?>> _decryptV2(
    Map<String, Object?> envelope,
    String passphrase,
  ) async {
    final kdf = envelope['kdf'] as Map;
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
