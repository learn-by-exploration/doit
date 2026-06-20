// Mission chain — an unmodifiable ordered list of [Mission]s.
//
// The chain is the source of truth for Strong-mode proof
// composition. A chain executes its missions in declared order;
// a failure in mission N forces a retry of N, not a restart
// of the chain (see docs/v_model/mission_catalog.md § Chain
// execution contract).

import 'dart:collection';

import 'package:doit/missions/mission.dart';

/// An unmodifiable, ordered list of missions.
///
/// [MissionChain] is the canonical type for a habit's
/// `missionChain` field. Construct with [MissionChain.from];
/// access via [missions] or [length] / indexer.
class MissionChain extends UnmodifiableListView<Mission> {
  MissionChain(super.source);

  /// Convenience for callers that have a `List<Mission>` already
  /// validated.
  factory MissionChain.from(List<Mission> source) =>
      MissionChain(List.unmodifiable(source));

  /// Empty chain. A chain of length 0 is not a valid Strong-mode
  /// proof; [Do.validate] rejects it.
  static final empty = MissionChain(<Mission>[]);

  /// Sum of per-mission timeouts. The chain executor (Phase 3)
  /// uses this to enforce SYS-031 (max 5 minutes).
  Duration get totalTimeout => fold(Duration.zero, (acc, m) => acc + m.timeout);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MissionChain) return false;
    if (other.length != length) return false;
    for (var i = 0; i < length; i++) {
      if (this[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var h = Object.hashAll([length]);
    for (final m in this) {
      h = Object.hash(h, Object.hashAll([m.id, m.label, m.timeout]));
    }
    return h;
  }
}
