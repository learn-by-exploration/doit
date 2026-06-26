// Proof-mode tag helper — forward conversion from the
// sealed `DoProofMode` hierarchy to the persisted text tag
// stored in the `habits.proofMode` Drift column (and the
// `completions.proofModeAtTime` column).
//
// The persisted tags are 3-value:
//   - 'soft'
//   - 'strong'
//   - 'auto'
//
// Multiple call sites need to do the conversion:
//   - `lib/services/do_repository.dart` (writes the row)
//   - `lib/screens/mission_launcher.dart` (writes the
//     completion row)
//   - `lib/screens/home_tile_completion.dart` (writes
//     the completion row from the tile's "Done" tap)
//
// v1.4c (SYS-117) consolidates the 3 inline copies that
// were sitting at those sites. The duplication was a
// known v1.4b deferred consolidation (see comment in
// `home_tile_completion.dart`); the helpers stayed
// byte-identical so the extract is a pure refactor with
// no behavior change.
//
// The inverse direction (`DoProofMode` ← text tag) lives
// at the call sites because the `'strong'` case needs to
// deserialize the accompanying `MissionChain` — the
// conversion is per-call-site, not shared.
//
// Layer rules (per `.claude/rules/lib-habits.md`):
//   - Pure Dart. No Flutter imports.
//   - No `DateTime.now()` inside.

import 'package:doit/do/proof_mode.dart';

/// Convert a [DoProofMode] to its persisted text tag.
///
/// Throws [ArgumentError] for an unknown subclass — the
/// sealed hierarchy guarantees exhaustiveness, so this
/// only fires if a new subclass is added without updating
/// this file (the test for that case lives in
/// `test/do/proof_mode_tag_test.dart`).
String proofModeTag(DoProofMode m) {
  if (m is SoftProof) return 'soft';
  if (m is StrongProof) return 'strong';
  if (m is AutoProof) return 'auto';
  throw ArgumentError('Unknown proof mode: $m');
}
