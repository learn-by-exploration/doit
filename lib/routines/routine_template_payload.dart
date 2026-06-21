// RoutineTemplatePayload — codec for the v1.1 (SYS-083)
// generic routine apply UX (templates #17–#21).
//
// Templates #17..#21 carry a `payloadJson` of the shape
//   {"k": 1, "routine": {<opaque triple>}}
// where `<opaque triple>` is one of:
//
//   { "trigger":   "<kind>",       // location | calendar | ...
//     "condition": "<kind>:<arg>[;<arg2>...]",
//     "action":    "<kind>:<arg>",
//     "note":      "<free text>" }
//
// Today (v1.1d), the per-template placeholders are
// stringly-typed — the apply UX round-trips them as opaque
// maps through [RoutineConfig] without trying to map them
// to the sealed [Trigger] / [Condition] / [Action] leaves.
// The mapping lands in v1.1e (per-template picker UIs) once
// the per-shape pickers are designed.
//
// Why the codec is a separate value class (not a method on
// [RoutineConfig]):
//
//   - The template envelope is *opaque* to the runtime
//     (`triggerJson` / `actionJson` already accept any
//     per-shape JSON object). The codec's job is to lift
//     the template's outer envelope (`k`, `routine`) and
//     split the inner triple into the three JSON blobs the
//     config wants.
//   - The codec is testable in isolation: malformed
//     envelopes, future `k` values, missing inner keys, all
//     are exercised in `routine_template_payload_test.dart`.
//   - The screen layer reads the codec to render the
//     template's metadata (name, description, decoded
//     note) and to seed the apply form.
//
// Layer rules (per `.claude/rules/lib-routines.md`):
//   - Pure Dart, no Flutter imports.
//   - Models are immutable; equality is structural.

import 'dart:convert' show jsonDecode;

import 'package:doit/services/routine_config.dart';
import 'package:doit/templates/template.dart';
import 'package:meta/meta.dart';

/// The decoded inner triple of a template's `payloadJson`.
///
/// The `trigger` / `condition` / `action` fields are
/// placeholder strings; v1.1d keeps them as raw strings (no
/// mapping to the sealed [Trigger] / [Condition] / [Action]
/// leaves). v1.1e lands the per-template picker UIs that
/// resolve the placeholders into structured values.
@immutable
class RoutineTemplatePayload {
  const RoutineTemplatePayload({
    required this.templateId,
    required this.name,
    required this.description,
    required this.trigger,
    required this.condition,
    required this.action,
    required this.note,
  });

  /// The template's stable id (e.g. `t_builtin_17`).
  final String templateId;

  /// The template's display name (e.g. "Focus block"). Cached
  /// from the [Template] row for the apply-screen label.
  final String name;

  /// The template's display description (e.g. "When a focus
  /// block starts, silence notifications."). Cached from the
  /// [Template] row for the apply-screen subtitle.
  final String description;

  /// The trigger placeholder string (e.g. `"location"`,
  /// `"calendar"`). Opaque to v1.1d; the apply-screen
  /// surfaces it as a read-only chip.
  final String trigger;

  /// The condition placeholder string (e.g.
  /// `"enter_country:JP"`, `"event:meeting;-15min"`). May be
  /// empty when the template's envelope omits the field.
  final String condition;

  /// The action placeholder string (e.g. `"set_ringer:silent"`,
  /// `"dn:on"`, `"show:agenda"`). Opaque to v1.1d; the
  /// apply-screen surfaces it as a read-only chip.
  final String action;

  /// The template's free-text note (e.g.
  /// `"Phase C+ apply UX"`). Surfaced verbatim in the
  /// apply-screen as a small caption.
  final String note;

  /// Decode a [Template] row's `payloadJson` envelope. Returns
  /// `null` on any defect:
  ///
  ///   - The JSON is malformed.
  ///   - The envelope is not a JSON object.
  ///   - The `routine` inner key is missing or not a JSON
  ///     object.
  ///   - The inner `trigger` / `condition` / `action` fields
  ///     are missing or not strings (an empty `condition` is
  ///     tolerated; `trigger` and `action` must be non-empty
  ///     after trim).
  ///
  /// The decoder is fail-soft by design: a malformed template
  /// surfaces as a "could not load" snackbar in the apply
  /// screen, not an uncaught exception. This matches the
  /// built-in / user-saved symmetry — `TemplateRepository`
  /// tolerates malformed payloads at read time and validates
  /// at save time.
  static RoutineTemplatePayload? fromTemplate(Template t) {
    try {
      final outer = jsonDecode(t.payloadJson);
      if (outer is! Map) return null;
      final inner = outer['routine'];
      if (inner is! Map) return null;
      final triggerRaw = inner['trigger'];
      final conditionRaw = inner['condition'];
      final actionRaw = inner['action'];
      final noteRaw = inner['note'];
      if (triggerRaw is! String || triggerRaw.trim().isEmpty) return null;
      if (conditionRaw is! String) return null;
      if (actionRaw is! String || actionRaw.trim().isEmpty) return null;
      if (noteRaw is! String) return null;
      return RoutineTemplatePayload(
        templateId: t.id,
        name: t.name,
        description: t.description,
        trigger: triggerRaw,
        condition: conditionRaw,
        action: actionRaw,
        note: noteRaw,
      );
    } on FormatException {
      return null;
    }
  }

  /// Project the codec into a [RoutineConfig] suitable for
  /// [SettingsService.setRoutine]. The `enabled` flag is
  /// taken from the caller (the apply-screen's master
  /// toggle).
  ///
  /// The trigger / condition / action placeholders are
  /// wrapped into JSON envelopes with a `"type"` field that
  /// the v1.1e mapper can recognize at decode time. The
  /// `"type"` is `"routine_placeholder.v1"` — a sentinel
  /// the v1.1 runtime can match on if it ever decodes the
  /// inner trigger / action JSON before the picker UX
  /// lands. v1.1d never decodes them; the executor treats
  /// them as opaque maps and only the matching engine's
  /// pre-fire validation surfaces a "unsupported" error.
  RoutineConfig toRoutineConfig({required bool enabled}) {
    return RoutineConfig(
      templateId: templateId,
      enabled: enabled,
      triggerJson: <String, Object?>{
        'type': 'routine_placeholder.v1',
        'kind': trigger,
        'raw': condition, // trigger is bound to the condition for placeholders
      },
      actionJson: <String, Object?>{
        'type': 'routine_placeholder.v1',
        'kind': action,
        'note': note,
      },
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RoutineTemplatePayload) return false;
    return other.templateId == templateId &&
        other.name == name &&
        other.description == description &&
        other.trigger == trigger &&
        other.condition == condition &&
        other.action == action &&
        other.note == note;
  }

  @override
  int get hashCode => Object.hash(
    templateId,
    name,
    description,
    trigger,
    condition,
    action,
    note,
  );

  @override
  String toString() =>
      'RoutineTemplatePayload('
      'templateId: $templateId, '
      'trigger: $trigger, '
      'condition: $condition, '
      'action: $action'
      ')';
}
