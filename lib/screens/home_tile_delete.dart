// Per-tile delete helper for the in-app home screen
// (v1.4h / Phase 35 / SYS-122 / ADR-052 / WF-049).
//
// The home tile today has Skip / Undo / Done IconButtons
// (v1.4c / v1.4d / v1.4b respectively) but NO edit /
// delete affordance — the user has to long-press the tile
// to enter select-mode then tap the trash icon in the app
// bar, which is undiscoverable. v1.4h adds a per-tile
// trash IconButton that opens a confirm dialog + calls
// `DoRepository.deleteById` + shows a SnackBar with an
// Undo action that re-saves the captured do.
//
// This helper is the pure-Dart seam between the tile's
// `_DeleteButton` onPressed callback and the `DoRepository`
// singleton. The helper:
//
//   1. Captures the do as the function argument (the
//      caller passes a reference before calling `delete`).
//   2. Calls `repository.deleteById(do.id)`.
//   3. Returns `true` on the happy path so the caller
//      can refresh the home list (the deleted tile
//      disappears immediately).
//   4. Catches any throwable (DB locked, constraint
//      violation, etc.) and returns `false` so the caller
//      can show an error SnackBar WITHOUT removing the
//      tile.
//
// The undo path is handled by the caller — `_DeleteButton`
// captures the do reference in a closure, then if the
// SnackBar's "Undo" action fires, the closure re-saves
// the do via `DoRepository.save`. The undo path is NOT in
// this helper because it needs the `BuildContext` for the
// SnackBar (Material SnackBars can't be shown from a pure
// helper without a context).

import 'package:doit/do/do.dart';
import 'package:doit/services/do_repository.dart';

/// Delete the do from the repository. Returns `true` on
/// the happy path (caller should refresh the home list);
/// `false` on any throwable (caller should show an error
/// SnackBar and leave the tile in place).
///
/// Pure-Dart, no Flutter import, no `DateTime.now()`.
Future<bool> deleteDo({
  required Do activeDo,
  required DoRepository repository,
}) async {
  try {
    await repository.deleteById(activeDo.id);
    return true;
  } catch (_) {
    return false;
  }
}
