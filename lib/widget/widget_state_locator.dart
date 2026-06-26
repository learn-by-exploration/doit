// Pure-Dart locator for the home widget's "first-active do".
//
// The widget shows the user's anchor do — the oldest
// non-paused do, in creation order. This mirrors the
// "anchor do" mental model: the user adds a do, sets it as
// their recurring anchor, the widget surfaces its state.
// Paused dos are skipped (matches `DoRepository.listActive`'s
// filter).
//
// User-configurable widget selection is v1.4b. v1.4a always
// shows the first-active do; if none exists, the widget
// renders the empty-state copy ("Add a do in do it").
//
// Layer rules:
//   - Pure Dart. No Flutter imports.
//   - The locator takes the `DoRepository.instance` as a
//     dependency (passed in by the test), so widget tests
//     can inject a fake list without monkey-patching the
//     singleton.
//
// v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042.

import 'package:doit/do/do.dart';
import 'package:doit/services/do_repository.dart';

/// Returns the first-active do (oldest by `createdAt`
/// ascending, skipping paused dos). Returns `null` when
/// the repository has no non-paused do.
///
/// `now` is the reference time used for the paused-until
/// comparison; the caller passes the frozen `DateTime`
/// so the widget tests are deterministic.
Future<Do?> firstActiveDo({DoRepository? repository, DateTime? now}) async {
  final repo = repository ?? DoRepository.instance;
  final reference = now ?? DateTime.now();
  final all = await repo.listAll();
  // Sort ascending by createdAt so the oldest do wins,
  // independent of the repository's return order.
  final sorted = <Do>[...all]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  for (final entry in sorted) {
    if (!entry.isPausedAt(reference)) return entry;
  }
  return null;
}
