// Periodic nightly backup scheduler — wraps the `workmanager`
// plugin (v0.6.0) so the OS schedules a 24-hour recurring
// task that calls `BackupService.exportTo` against the user's
// SAF folder.
//
// Per .claude/rules/lib-services.md, this is a singleton
// service with `Completer<void> _ready` and idempotent
// `init()`. The actual platform call goes through
// `Workmanager().registerPeriodicTask(...)`, which requires a
// top-level entry-point dispatcher (the OS instantiates the
// Flutter engine from cold start to run a periodic task).
//
// The dispatcher is defined in `_backupTaskDispatcher` below
// and registered via `Workmanager().initialize(...)` from
// `init()`. The unique name is `streak.backup.nightly` and
// the task name is also `streak.backup.nightly` (workmanager
// requires both; the unique name dedupes, the task name
// dispatches).
//
// Per the project's no-INTERNET constraint, the scheduler is
// strictly local: the only side effect is `exportTo` writing
// to the user's SAF folder. No network, no analytics, no
// telemetry.
//
// v0.4b (SYS-060) — this file lands the scheduler that
// `BackupService` does not own. The actual `exportTo` call
// inside the dispatcher goes through `BackupService.instance`
// so the wire format stays in one place. The 24-hour
// frequency is the workmanager default; Android's WorkManager
// also enforces a 15-minute minimum, so 24 hours is well
// above the floor.

import 'dart:async';
import 'dart:io' show Directory, File;

import 'package:common_games/services/backup_service.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// The unique name and the task name for the nightly backup
/// periodic task. Both must be the same string for the OS to
/// match the schedule to the dispatcher.
@visibleForTesting
const String kBackupNightlyTaskName = 'streak.backup.nightly';

/// The SharedPreferences key the scheduler reads to find the
/// SAF folder URI the user picked on first launch. The
/// production path is the user-picked SAF folder; the
/// scheduler's job is just to find the file, not to choose
/// the folder.
const String _kBackupFolderKey = 'streak.backup.folder_uri';

/// Periodic frequency for the nightly backup. WorkManager's
/// minimum is 15 minutes; 24 hours is the documented Streak
/// cadence in [docs/v_model/plan.md] (nightly during
/// 02:00..04:00 local).
const Duration _kBackupFrequency = Duration(hours: 24);

/// Top-level function the OS calls when a periodic task
/// fires. Annotated `@pragma('vm:entry-point')` so the Dart
/// AOT compiler keeps it reachable from native entry points.
///
/// The dispatcher must be a top-level or static function so
/// `PluginUtilities.getCallbackHandle` can resolve it. The
/// `Workmanager().executeTask` switch dispatches by task
/// name; for now we only handle [kBackupNightlyTaskName].
///
/// The function does not throw — failures are swallowed and
/// logged as `false` to the OS. The OS retries the next
/// periodic interval.
@pragma('vm:entry-point')
Future<void> _backupTaskDispatcher() async {
  Workmanager().executeTask((task, inputData) async {
    if (task != kBackupNightlyTaskName) {
      return false;
    }
    return runBackupTask();
  });
}

/// The body of a nightly backup task. Exposed at top level
/// (and `@visibleForTesting`) so the dispatcher test can
/// invoke it without going through the
/// `Workmanager().executeTask` indirection (which is a
/// private method-channel callback the test harness cannot
/// reach). Returns `true` on success (including the
/// "no folder configured yet" no-op) and `false` on
/// failure.
@visibleForTesting
Future<bool> runBackupTask() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString(_kBackupFolderKey);
    if (uri == null || uri.isEmpty) {
      // No folder picked yet — the user has not finished
      // onboarding. The export is a no-op this run; the
      // next run will retry.
      return true;
    }
    final dir = Directory.fromUri(Uri.parse(uri));
    if (!await dir.exists()) {
      return true;
    }
    final out = File('${dir.path}/streak-backup.json');
    await BackupService.instance.exportTo(out);
    return true;
  } catch (_) {
    // Swallow. The next periodic interval will retry.
    return false;
  }
}

/// Singleton holder for the WorkManager-backed backup
/// scheduler. Mirrors the `AlarmScheduler` shape (see
/// `lib/reminders/alarm_scheduler.dart`).
class BackupScheduler {
  BackupScheduler._();

  /// The single global instance.
  static final BackupScheduler instance = BackupScheduler._();

  /// Init gate.
  Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  /// `true` once the periodic task is registered with the
  /// OS. Read by the settings page to show the "Nightly
  /// backup is on" badge.
  bool isNightlyScheduled = false;

  /// Idempotent. Calls `Workmanager().initialize(...)` (a
  /// no-op the second time) and resolves the gate. The
  /// caller (typically `main.dart`) awaits this before
  /// `scheduleNightlyBackup()`.
  Future<void> init() async {
    if (_ready.isCompleted) return;
    try {
      await Workmanager().initialize(_backupTaskDispatcher);
      if (!_ready.isCompleted) _ready.complete();
    } catch (e, st) {
      if (!_ready.isCompleted) _ready.completeError(e, st);
      rethrow;
    }
  }

  /// Register the 24-hour periodic task with WorkManager.
  /// Safe to call multiple times — the unique name dedupes.
  /// If `init()` was not awaited first, this throws
  /// `StateError`.
  Future<void> scheduleNightlyBackup() async {
    if (!_ready.isCompleted) {
      throw StateError(
        'BackupScheduler.init() must be awaited before '
        'scheduleNightlyBackup().',
      );
    }
    await Workmanager().registerPeriodicTask(
      kBackupNightlyTaskName,
      kBackupNightlyTaskName,
      frequency: _kBackupFrequency,
    );
    isNightlyScheduled = true;
  }

  /// Cancel the periodic task. Idempotent.
  Future<void> cancelNightlyBackup() async {
    if (!_ready.isCompleted) return;
    await Workmanager().cancelByUniqueName(kBackupNightlyTaskName);
    isNightlyScheduled = false;
  }

  /// Test helper. Resets the in-memory state. Production
  /// never calls this; tests use it to re-init the gate.
  // ignore: use_setters_to_change_properties
  void resetForTesting() {
    isNightlyScheduled = false;
    _ready = Completer<void>();
  }
}
