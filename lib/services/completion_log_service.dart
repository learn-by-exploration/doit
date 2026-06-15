// Append + query for the completion log. The completion log is
// the source of truth for streak calculation; the per-habit
// rest-day budget snapshot is a derived fast-read cache.
//
// Completions are deduplicated by `(habitId, local-day)` — a
// double-tap of "Done" inserts one row, not two. The dedupe
// key is computed by the caller (the home screen, the
// notification, the mission UI) and passed in as a
// `DateTime` midnight local. The service stores millis since
// epoch UTC for the day bucket.

import 'dart:async';

import 'package:drift/drift.dart';

import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';

/// Source of a completion event. Logged so the streak calculator
/// can distinguish manual completions from rest days.
enum CompletionSource { manual, notification, mission, restDay }

class CompletionLogService {
  CompletionLogService._();

  static final CompletionLogService instance = CompletionLogService._();

  Future<void> get _ready => AppDatabaseService.instance.ready;
  AppDatabase get _db => AppDatabaseService.instance.db;

  /// Append a completion. The `day` argument is the local-day
  /// midnight at which this completion counts; the service
  /// dedupes on (habitId, day) and returns the existing row's id
  /// if one already exists.
  ///
  /// `proofModeAtTime` records the mode in effect at the time of
  /// completion — important for stats when the mode changes
  /// mid-streak.
  Future<String> append({
    required String habitId,
    required DateTime day,
    required CompletionSource source,
    required String proofModeAtTime,
    String? note,
    String? missionResultsJson,
  }) async {
    await _ready;
    final dayMillis = _toDayMillis(day);
    final existing =
        await (_db.select(_db.completions)
              ..where(
                (t) =>
                    t.habitId.equals(habitId) & t.dayMillis.equals(dayMillis),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      return existing.id;
    }
    final id = _newId();
    await _db
        .into(_db.completions)
        .insert(
          CompletionRow(
            id: id,
            habitId: habitId,
            dayMillis: dayMillis,
            completedAtMillis: DateTime.now().millisecondsSinceEpoch,
            source: _sourceTag(source),
            proofModeAtTime: proofModeAtTime,
            note: note,
            missionResultsJson: missionResultsJson,
          ),
        );
    return id;
  }

  /// List all completions for a habit, oldest-first. Used by the
  /// streak calculator and the stats service.
  Future<List<CompletionRow>> listForHabit(String habitId) async {
    await _ready;
    return (_db.select(_db.completions)
          ..where((t) => t.habitId.equals(habitId))
          ..orderBy([(t) => OrderingTerm.asc(t.dayMillis)]))
        .get();
  }

  /// List completions for a habit within a closed `[from, to]`
  /// day range. The range is in local-day midnight millis.
  Future<List<CompletionRow>> listInRange(
    String habitId, {
    required DateTime from,
    required DateTime to,
  }) async {
    await _ready;
    final fromMillis = _toDayMillis(from);
    final toMillis = _toDayMillis(to);
    return (_db.select(_db.completions)
          ..where(
            (t) =>
                t.habitId.equals(habitId) &
                t.dayMillis.isBetweenValues(fromMillis, toMillis),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.dayMillis)]))
        .get();
  }

  /// List all rest-day completions for a habit within a calendar
  /// month. Used to derive the rest-day budget snapshot.
  Future<List<CompletionRow>> listRestDaysInMonth(
    String habitId, {
    required int year,
    required int month,
  }) async {
    await _ready;
    final first = DateTime(year, month);
    final lastExclusive = month == 12
        ? DateTime(year + 1)
        : DateTime(year, month + 1);
    final fromMillis = _toDayMillis(first);
    final toMillisExclusive = _toDayMillis(lastExclusive);
    return (_db.select(_db.completions)
          ..where(
            (t) =>
                t.habitId.equals(habitId) &
                t.source.equals('rest_day') &
                t.dayMillis.isBiggerOrEqualValue(fromMillis) &
                t.dayMillis.isSmallerThanValue(toMillisExclusive),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.dayMillis)]))
        .get();
  }

  /// Delete a completion by id. Used by tests and by the restore
  /// flow (which wipes the log before re-importing).
  Future<void> deleteById(String id) async {
    await _ready;
    await (_db.delete(_db.completions)..where((t) => t.id.equals(id))).go();
  }

  /// Wipe every completion row. Reserved for the restore flow;
  /// not used by the regular UI.
  Future<void> deleteAll() async {
    await _ready;
    await _db.delete(_db.completions).go();
  }

  int _toDayMillis(DateTime local) {
    final midnight = DateTime(local.year, local.month, local.day);
    return midnight.millisecondsSinceEpoch;
  }

  String _sourceTag(CompletionSource s) {
    return switch (s) {
      CompletionSource.manual => 'manual',
      CompletionSource.notification => 'notification',
      CompletionSource.mission => 'mission',
      CompletionSource.restDay => 'rest_day',
    };
  }

  int _seq = 0;
  String _newId() {
    _seq++;
    return 'c-${DateTime.now().millisecondsSinceEpoch}-$_seq';
  }
}
