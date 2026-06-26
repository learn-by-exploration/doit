// Pure-Dart "Undo today" helper for the in-app home tile.
//
// Mirrors `CompletionLogSection._confirmAndDelete` (v1.2m /
// SYS-108) but with one fewer tap (no scroll, no list, no
// per-row delete icon — just a confirm dialog on the tile
// itself). The existing `CompletionLogService.deleteById`
// (v1.2m) is re-used verbatim; no new Drift methods, no
// new `lib/services/` surface.
//
// Layer rules (per `.claude/rules/lib-screens.md`):
//   - The helper does NOT import `package:flutter/*`.
//     It is callable from a widget test without a Flutter
//     test harness.
//   - No `DateTime.now()` inside. The caller passes the
//     frozen `asOf`.
//   - Pure side-effecting function — the only side effect
//     is the `completionLog.deleteById` call on the happy
//     path.
//
// v1.4d / Phase 31 / SYS-118 / ADR-048 / WF-045.

import 'package:doit/do/do.dart';
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/db/schema.dart';

/// The result of an `undoToday` call.
///
/// Sealed value class with two factories:
///   - [UndoResult.removed] — the happy path; carries the
///     deleted row's id + the source tag so the caller
///     can decide which state flag to flip (`_isCompletedToday`
///     for `source: CompletionSource.manual`,
///     `_isSkippedToday` for `source: CompletionSource.restDay`).
///   - [UndoResult.nothingToUndo] — no row matched the
///     today-local-midnight filter; the caller shows the
///     defensive `homeTileUndoNotToday` snackbar.
sealed class UndoResult {
  const UndoResult();

  /// A row was found and deleted. [rowId] is the
  /// `CompletionRow.id` that was passed to
  /// `CompletionLogService.deleteById`; [source] is the
  /// source tag (`'manual'`, `'rest_day'`, ...) so the
  /// caller can flip the right state flag.
  const factory UndoResult.removed({
    required String rowId,
    required String source,
  }) = UndoResultRemoved;

  /// No row matched the today-local-midnight filter.
  /// `deleteById` was NOT called.
  const factory UndoResult.nothingToUndo() = UndoResultNothingToUndo;
}

class UndoResultRemoved extends UndoResult {
  const UndoResultRemoved({required this.rowId, required this.source});
  final String rowId;
  final String source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UndoResultRemoved &&
          other.rowId == rowId &&
          other.source == source);

  @override
  int get hashCode => Object.hash(rowId, source);

  @override
  String toString() => 'UndoResult.removed(rowId: $rowId, source: $source)';
}

class UndoResultNothingToUndo extends UndoResult {
  const UndoResultNothingToUndo();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UndoResultNothingToUndo;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'UndoResult.nothingToUndo()';
}

/// Delete today's completion (or rest-day) row for
/// [activeDo] via [completionLog].
///
/// The `day` filter is the local-midnight at [asOf]; the
/// matching row is the one whose `dayMillis == midnight
/// at asOf` (same convention as `markDoDone` +
/// `markDoSkipped`). The matching is by `day` only — the
/// `source` does not filter (a manual completion AND a
/// rest-day completion cannot coexist for the same
/// `(habitId, day)` because `CompletionLogService.append`
/// dedupes on `(habitId, day, source)` and at most one
/// source wins per day in practice). On a hit the helper
/// calls `completionLog.deleteById(row.id)` exactly once
/// and returns [UndoResult.removed] carrying the row's id
/// + source tag. On no hit the helper returns
/// [UndoResult.nothingToUndo] without touching the DB.
Future<UndoResult> undoToday({
  required Do activeDo,
  required DateTime asOf,
  required CompletionLogService completionLog,
}) async {
  // 1. List all completions for the do. The same query
  // backs `CompletionLogSection` (v1.2m / SYS-108) — the
  // DB is the source of truth. `listForHabit` is
  // sorted oldest-first by `dayMillis` ascending, but
  // the ordering does not matter here (we filter to a
  // single day).
  final rows = await completionLog.listForHabit(activeDo.id);

  // 2. Compute the local-midnight at `asOf` for the day
  // comparison. `CompletionRow.dayMillis` is stored as
  // `DateTime(year, month, day).millisecondsSinceEpoch`
  // (see `CompletionLogService._toDayMillis`), so we
  // rebuild the same value here. We avoid importing the
  // private `_toDayMillis`; we duplicate the computation
  // because the contract is "store local-midnight" and
  // the timezone math is local-by-construction.
  final dayMidnight = DateTime(asOf.year, asOf.month, asOf.day);
  final dayMillis = dayMidnight.millisecondsSinceEpoch;

  // 3. Find the row for today (if any). Defensive: the
  // dialog is gated on `_isResolvedToday == true`, but
  // a concurrent app-tile rebuild (e.g., an alarm fires
  // and writes a row) could leave a stale flag pointing
  // at a day whose row no longer matches. The DB is
  // the source of truth.
  CompletionRow? match;
  for (final row in rows) {
    if (row.dayMillis == dayMillis) {
      match = row;
      break;
    }
  }
  if (match == null) {
    return const UndoResult.nothingToUndo();
  }

  // 4. Delete the row. Exactly one call per invocation
  // on the happy path.
  await completionLog.deleteById(match.id);
  return UndoResult.removed(rowId: match.id, source: match.source);
}
