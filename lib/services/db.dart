// Drift database singleton. The rest of the app goes through
// `AppDatabaseService.instance.db` and `await`s `ready` before
// reading or writing.
//
// The singleton pattern follows `.claude/rules/lib-services.md`:
// one `Completer<void> _ready` field, idempotent `init()`,
// public reads/writes `await ready` first. Public methods are
// async even for synchronous results so the caller can `await`
// them.
//
// The DB file lives at `getApplicationSupportDirectory()/streak.db`
// — a path the platform clears on uninstall. The location is
// resolved lazily at `init()` time so the singleton can be
// constructed at compile time without a binding.

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:common_games/services/db/schema.dart';

/// Singleton holder for the Drift database.
class AppDatabaseService {
  AppDatabaseService._();

  /// The single global instance. Constructed lazily on first
  /// access; the Drift executor is bound at `init()` time.
  static final AppDatabaseService instance = AppDatabaseService._();

  AppDatabase? _db;
  Completer<void> _ready = Completer<void>();

  /// The Drift database. Throws until `init()` has resolved.
  AppDatabase get db {
    final d = _db;
    if (d == null) {
      throw StateError(
        'AppDatabaseService.init() must complete before db is read.',
      );
    }
    return d;
  }

  /// Resolves when `init()` has finished. All public reads /
  /// writes in repository / log services MUST `await ready`
  /// before touching the DB.
  Future<void> get ready => _ready.future;

  /// Idempotent. Subsequent calls resolve immediately. The first
  /// call opens the DB file (or creates it on first run) and
  /// runs `onCreate` / `onUpgrade` as needed.
  ///
  /// [overrideDb] is the test-only seam: pass an in-memory or
  /// temp-file Drift DB to swap out the production executor.
  /// In production, leave it null.
  Future<void> init({AppDatabase? overrideDb}) async {
    if (_ready.isCompleted) return;
    if (overrideDb != null) {
      _db = overrideDb;
      _ready.complete();
      return;
    }
    try {
      final dir = await getApplicationSupportDirectory();
      final dbPath = p.join(dir.path, 'streak.db');
      final file = await _ensureFile(dbPath);
      _db = AppDatabase(NativeDatabase(file));
      _ready.complete();
    } catch (e, st) {
      _ready.completeError(e, st);
      rethrow;
    }
  }

  /// Closes the DB and resets the singleton so a future
  /// `init()` can re-open. Production code never calls this;
  /// it exists for test teardown.
  Future<void> closeForTesting() async {
    final d = _db;
    _db = null;
    if (d != null) await d.close();
    if (!_ready.isCompleted) {
      // init() was never awaited; resolve the empty completer
      // so a future ready.future doesn't hang.
      _ready.complete();
    }
    _ready = Completer<void>();
  }
}

Future<File> _ensureFile(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    await file.create(recursive: true);
  }
  return file;
}
