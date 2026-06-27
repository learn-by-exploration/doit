// Per-tile delete + restore helpers for the in-app home
// screen (v1.4l / Phase 39 / SYS-126 / ADR-056 / WF-053).
//
// The home tile has Skip / Undo / Done IconButtons (v1.4c /
// v1.4d / v1.4b respectively) plus the per-tile Edit +
// Delete IconButtons from v1.4h. v1.4l replaces v1.4h's
// hard-delete path with a soft-delete + restore path so the
// Undo SnackBar is a true restore (the streak reconstructs
// from the intact completion log; see ADR-056 §"Tombstone =
// invisible to UI, visible to restore + backup-restore").
//
// The helpers here are the pure-Dart seams between the
// tile's UI callbacks and the `DoRepository` singleton.
//
//   1. [softDeleteDo] — sets `deletedAtMillis = at` on the
//      do's row. The `Habits` row + `Completions` +
//      `RestDayBudgets` rows stay in the DB (no FK declared,
//      no cascade). The do disappears from `listAll` /
//      `listActive` until [restoreDo] is called.
//   2. [restoreDo] — sets `deletedAtMillis = NULL` on the
//      matching row. Idempotent on an active row.
//
// Both helpers catch any throwable (DB locked, constraint
// violation, etc.) and return a `bool` so the tile's UI
// layer can branch without `try/catch` blocks. The Undo
// path is the caller's responsibility (it needs the
// `BuildContext` for the SnackBar — Material SnackBars
// can't be shown from a pure helper without a context).

import 'package:doit/do/do.dart';
import 'package:doit/services/do_repository.dart';

/// Soft-delete the do from the repository. Returns `true`
/// on the happy path (caller should refresh the home list
/// so the tile disappears immediately); `false` on any
/// throwable (caller should show an error SnackBar and
/// leave the tile in place) or if no matching active row
/// existed.
///
/// v1.4l (SYS-126) supersedes the v1.4h `deleteDo` helper,
/// which hard-deleted the row (and silently broke streak
/// restoration on Undo — see ADR-056). The new path is
/// idempotent on a tombstoned do (the SQL UPDATE filters
/// `deletedAtMillis IS NULL` so re-soft-deleting returns
/// `false` rather than bumping the tombstone timestamp).
///
/// Pure-Dart, no Flutter import, no `DateTime.now()`
/// inside (the caller passes the reference time).
Future<bool> softDeleteDo({
  required Do activeDo,
  required DateTime at,
  required DoRepository repository,
}) async {
  try {
    return await repository.softDeleteById(activeDo.id, at: at);
  } catch (_) {
    return false;
  }
}

/// Restore a tombstoned do. Returns `true` on the happy
/// path (the do is back in `listAll`); `false` on any
/// throwable or if the row was not tombstoned (idempotent
/// on an active row — the SQL UPDATE filters
/// `deletedAtMillis IS NOT NULL` so re-restoring returns
/// `false`).
///
/// v1.4l (SYS-126) supersedes the v1.4h Undo path, which
/// called `DoRepository.save(habit)` and re-inserted the
/// row via `insertOnConflictUpdate`. The v1.4h path
/// triggered `DuplicateDoName` if the user had created a
/// new do with the same name in the SnackBar window, and
/// the row recreation lost the user's `automations` (a
/// separate latent bug — the `_toRow` mapping does not
/// write `automationsJson`, tracked for a v1.4l+ follow-up).
/// The v1.4l restore path is a single UPDATE so neither
/// failure mode applies.
///
/// Pure-Dart, no Flutter import.
Future<bool> restoreDo({
  required Do tombstonedDo,
  required DoRepository repository,
}) async {
  try {
    return await repository.restoreById(tombstonedDo.id);
  } catch (_) {
    return false;
  }
}
