// Pure-Dart "Done" helper for the in-app home tile.
//
// Mirrors `WidgetService.markDone` (v1.4a) but for the
// in-app tile surface. The two callers share the same
// `CompletionLogService.append(...)` call shape so the
// completion write is byte-identical across surfaces (the
// `CompletionLogService.append` already dedupes on
// `(habitId, day)` so a double-tap inserts one row, not
// two).
//
// NOTE: the `_proofModeTag` helper inlined below mirrors
// the one in `lib/services/widget_service.dart:234-239`
// (v1.4a). A future PR will consolidate them into a
// shared `lib/do/proof_mode_tag.dart` once the v1.4a
// branch lands on `main`. Until then the two callers are
// kept in lockstep manually (the unit tests in
// `test/screens/home_tile_completion_test.dart` pin the
// tag shape so a drift is caught at CI).
//
// Layer rules (per `.claude/rules/lib-screens.md`):
//   - The helper does NOT import `package:flutter/*`.
//     It is callable from a widget test without a Flutter
//     test harness.
//   - No `DateTime.now()` inside. The caller passes the
//     frozen `asOf`.
//   - Pure side-effecting function — the only side effect
//     is the `completionLog.append` call.
//
// v1.4b / Phase 29 / SYS-116 / ADR-046 / WF-043.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/services/completion_log_service.dart';

/// Append a manual completion for [activeDo] via
/// [completionLog]. The `day` argument is the local-midnight
/// at [asOf]; the `source` is [CompletionSource.manual] (the
/// tile's "Done" tap is conceptually identical to the home
/// app-bar action — same audit trail).
///
/// The `proofModeAtTime` tag mirrors the do's current
/// `proofMode`:
///   - `SoftProof`  → `'soft'`
///   - `StrongProof` → `'strong'`
///   - `AutoProof`   → `'auto'`
///
/// Future consolidation: extract `_proofModeTag` into
/// `lib/do/proof_mode_tag.dart` once the v1.4a branch is
/// on `main`. Until then the two helpers are pinned
/// byte-identical by `home_tile_completion_test.dart`.
Future<void> markDoDone({
  required Do activeDo,
  required DateTime asOf,
  required CompletionLogService completionLog,
}) async {
  final day = DateTime(asOf.year, asOf.month, asOf.day);
  await completionLog.append(
    habitId: activeDo.id,
    day: day,
    source: CompletionSource.manual,
    proofModeAtTime: _proofModeTag(activeDo.proofMode),
  );
}

// Inline copy of `WidgetService._proofModeTag`. Keep in
// lockstep with `lib/services/widget_service.dart` until
// the v1.4a branch lands and the helper is extracted to
// `lib/do/proof_mode_tag.dart`.
String _proofModeTag(DoProofMode m) {
  if (m is SoftProof) return 'soft';
  if (m is StrongProof) return 'strong';
  if (m is AutoProof) return 'auto';
  throw ArgumentError('Unknown proof mode: $m');
}
