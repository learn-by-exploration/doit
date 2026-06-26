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
import 'package:doit/do/proof_mode_tag.dart';
import 'package:doit/services/completion_log_service.dart';

/// Append a manual completion for [activeDo] via
/// [completionLog]. The `day` argument is the local-midnight
/// at [asOf]; the `source` is [CompletionSource.manual] (the
/// tile's "Done" tap is conceptually identical to the home
/// app-bar action — same audit trail).
///
/// The `proofModeAtTime` tag mirrors the do's current
/// `proofMode` via the shared [proofModeTag] helper
/// (v1.4c / SYS-117 consolidation):
///   - `SoftProof`  → `'soft'`
///   - `StrongProof` → `'strong'`
///   - `AutoProof`   → `'auto'`
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
    proofModeAtTime: proofModeTag(activeDo.proofMode),
  );
}
