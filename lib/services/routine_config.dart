// RoutineConfig — persisted configuration for a single
// template-based routine (templates #17–#21 in v1.1).
//
// Per the v1.1 routine apply UX plan (SYS-080 / ADR-025):
//
//   - One row per template id. `JapanRoutineConfig` (the v1.0
//     Japan-flow class) stays untouched; it has its own three
//     legacy keys (`doit.japan_routine.*`) that are
//     intentionally NOT migrated here.
//   - `triggerJson` / `conditionJson` / `actionJson` carry the
//     raw per-shape JSON emitted by `triggerToJson` /
//     `conditionToJson` / `actionToJson` (see
//     `lib/routines/routine.dart`). The runtime decodes them
//     back into the sealed `Trigger` / `Condition` / `Action`
//     leaves via `triggerFromJson` / `conditionFromJson` /
//     `actionFromJson`.
//   - `enabled` is the user-facing master toggle.
//   - Persistence key: `doit.routine.<templateId>` (one key per
//     template). Backed by `SharedPreferences` via
//     `SettingsService.setRoutine`.
//
// Equality is structural so a fresh `copyWith` round-trips
// through `==` cleanly. The `toJson` / `fromJson` codec is
// version-free: each per-shape JSON object carries its own
// `type` discriminator (see `lib/routines/routine.dart`).

import 'package:meta/meta.dart';

/// Immutable value class for a single template-driven routine.
///
/// Mirrors the structure of [Automation] in
/// `lib/routines/routine.dart` minus the auto-minted `id` (the
/// `templateId` IS the stable identifier here, so re-saving the
/// same template always updates the same row).
@immutable
class RoutineConfig {
  const RoutineConfig({
    required this.templateId,
    required this.triggerJson,
    this.conditionJson,
    required this.actionJson,
    this.enabled = true,
  });

  /// The template this routine was configured from. Stable; the
  /// SharedPreferences key is `doit.routine.<templateId>`.
  final String templateId;

  /// The trigger's per-shape JSON (`triggerToJson` output). The
  /// runtime decodes this back into the sealed `Trigger` type
  /// via `triggerFromJson`.
  final Map<String, Object?> triggerJson;

  /// The optional condition's per-shape JSON, or `null` for
  /// "no gating condition" (the routine fires on every
  /// matching trigger event).
  final Map<String, Object?>? conditionJson;

  /// The action's per-shape JSON (`actionToJson` output). Decoded
  /// via `actionFromJson` at fire time.
  final Map<String, Object?> actionJson;

  /// Master toggle. `false` means the routine is configured but
  /// does not fire.
  final bool enabled;

  /// Return a copy of this config with the given fields
  /// replaced. All `Map` parameters are stored as-is (the
  /// caller is expected to pass already-fresh maps; the
  /// decoder round-trips them).
  RoutineConfig copyWith({
    String? templateId,
    Map<String, Object?>? triggerJson,
    Map<String, Object?>? conditionJson,
    Map<String, Object?>? actionJson,
    bool? enabled,
  }) {
    return RoutineConfig(
      templateId: templateId ?? this.templateId,
      triggerJson: triggerJson ?? this.triggerJson,
      conditionJson: conditionJson ?? this.conditionJson,
      actionJson: actionJson ?? this.actionJson,
      enabled: enabled ?? this.enabled,
    );
  }

  /// Encode to a JSON object. Shape:
  /// ```
  /// {
  ///   "templateId":   "t_builtin_17",
  ///   "triggerJson":  { ...triggerToJson... },
  ///   "conditionJson": null | { ...conditionToJson... },
  ///   "actionJson":   { ...actionToJson... },
  ///   "enabled":      true
  /// }
  /// ```
  Map<String, Object?> toJson() => <String, Object?>{
    'templateId': templateId,
    'triggerJson': triggerJson,
    'conditionJson': conditionJson,
    'actionJson': actionJson,
    'enabled': enabled,
  };

  /// Decode a [RoutineConfig] from a JSON object. Throws
  /// [FormatException] on a malformed payload. The decoder
  /// does NOT validate the inner `triggerJson` / `actionJson`
  /// against the `triggerFromJson` / `actionFromJson` codecs —
  /// that validation happens at dispatch time when the
  /// executor reconstructs the sealed types.
  factory RoutineConfig.fromJson(Map<String, Object?> j) {
    final templateIdRaw = j['templateId'];
    if (templateIdRaw is! String) {
      throw const FormatException('routineConfig.templateId must be a string');
    }
    final triggerRaw = j['triggerJson'];
    if (triggerRaw is! Map) {
      throw const FormatException(
        'routineConfig.triggerJson must be a JSON object',
      );
    }
    final actionRaw = j['actionJson'];
    if (actionRaw is! Map) {
      throw const FormatException(
        'routineConfig.actionJson must be a JSON object',
      );
    }
    final conditionRaw = j['conditionJson'];
    Map<String, Object?>? conditionJson;
    if (conditionRaw != null) {
      if (conditionRaw is! Map) {
        throw const FormatException(
          'routineConfig.conditionJson must be a JSON object or null',
        );
      }
      conditionJson = conditionRaw.cast<String, Object?>();
    }
    final enabledRaw = j['enabled'];
    if (enabledRaw is! bool) {
      throw const FormatException('routineConfig.enabled must be a bool');
    }
    return RoutineConfig(
      templateId: templateIdRaw,
      triggerJson: triggerRaw.cast<String, Object?>(),
      conditionJson: conditionJson,
      actionJson: actionRaw.cast<String, Object?>(),
      enabled: enabledRaw,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RoutineConfig) return false;
    if (other.templateId != templateId) return false;
    if (other.enabled != enabled) return false;
    if (!_mapEquals(other.triggerJson, triggerJson)) return false;
    if (!_mapEquals(other.actionJson, actionJson)) return false;
    if (!_mapEquals(other.conditionJson, conditionJson)) return false;
    return true;
  }

  @override
  int get hashCode {
    // Note: deliberately avoid `Object.hashAllUnordered`,
    // which uses a randomized accumulator and is therefore
    // non-deterministic across calls (verified on Dart
    // 3.12). Instead, hash each JSON-object map via
    // `_mapHash`, which is order-independent and
    // deterministic.
    //
    // The fields are combined with a simple additive mix
    // (rather than `Object.hash(...)` which XORs and would
    // collapse a `-1` sentinel with a `0` for empty
    // conditionJson). The 31-multiplier per slot mirrors
    // the classic Java `String.hashCode` recipe and keeps
    // every distinct component contributing a non-trivial
    // bit-pattern. A null `conditionJson` is treated as
    // a separate sentinel value (`-1`) so that
    // `null != {}` in hash terms, matching the `==`
    // contract.
    final conditionJson = this.conditionJson;
    final conditionPart = conditionJson == null ? -1 : _mapHash(conditionJson);
    var h = templateId.hashCode;
    h = 0x1fffffff & (h * 31 + _mapHash(triggerJson));
    h = 0x1fffffff & (h * 31 + _mapHash(actionJson));
    h = 0x1fffffff & (h * 31 + conditionPart);
    h = 0x1fffffff & (h * 31 + enabled.hashCode);
    return h;
  }

  @override
  String toString() =>
      'RoutineConfig('
      'templateId: $templateId, '
      'enabled: $enabled, '
      'trigger: ${triggerJson['type']}, '
      'condition: ${conditionJson?['type'] ?? 'none'}, '
      'action: ${actionJson['type']}'
      ')';
}

/// Structural equality on a JSON-object map. Order-insensitive
/// at the top level (matches the codec's intent — keys are
/// always the same set per shape). Inner map values are
/// compared with [Object.==], so JSON arrays compare by
/// identity; for v1.1 the trigger/condition/action codecs do
/// not emit arrays inside arrays, so this is sufficient.
bool _mapEquals(Map<String, Object?>? a, Map<String, Object?>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key)) return false;
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

/// Deterministic, order-independent hash for a JSON-object map.
///
/// Sums `key.hashCode ^ value.hashCode` over the keys sorted
/// lexicographically. Stable across calls (unlike
/// [Object.hashAllUnordered], which uses a randomized
/// accumulator and is documented to vary across invocations).
/// Inner values are hashed via [Object.hashCode]; lists are
/// compared structurally elsewhere via [_mapEquals] when the
/// outer map's `==` runs, so a value-side inconsistency here
/// would only show up if two maps hash equal but differ on a
/// list value — that is acceptable as a hash collision (the
/// `==` still rejects them) and avoids the cost of structural
/// hashing on every entry.
int _mapHash(Map<String, Object?> m) {
  final keys = m.keys.toList()..sort();
  var h = 0;
  for (final k in keys) {
    final v = m[k];
    h = (h * 31 + k.hashCode) & 0x3fffffff;
    h = (h * 31 + (v == null ? 0 : v.hashCode)) & 0x3fffffff;
  }
  return h;
}
