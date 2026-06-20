// Template — a saved shape the user can pick to bootstrap a new
// do / event / person / routine. A template is intentionally
// flat (no sealed hierarchy): the screens do the dispatch on
// `entityType` after applying the `payloadJson` to the matching
// add form.
//
// Per .claude/rules/lib-services.md, this model is pure Dart
// (no Flutter imports). The repository layer maps to / from the
// Drift `TemplateRow`.
//
// v1.0 reframe (Phase B PR 1).

import 'package:meta/meta.dart';

/// The kind of entity this template bootstraps. Stored as the
/// `entityType` column on the `templates` table.
///
/// The Dart identifier `doEntity` is a workaround: `do` is a
/// Dart reserved keyword. The persisted string tag is still
/// `'do'`, so the DB column value and the `payloadJson`
/// envelope key (`{"k":1,"do":{...}}`) are unchanged.
enum TemplateEntityType {
  doEntity('do'),
  event('event'),
  person('person'),
  routine('routine');

  const TemplateEntityType(this.tag);

  /// Stable string used in the DB (`Templates.entityType`) and
  /// in the `payloadJson` envelope key (e.g., `{"k":1,"do":{...}}`).
  final String tag;

  /// Parse from the DB tag. Throws on unknown values: an
  /// unrecognized tag is a forward-compat hazard and should not
  /// silently fall back (use `DoCategory.fromTag` for the
  /// permissive case).
  static TemplateEntityType fromTag(String t) {
    for (final e in TemplateEntityType.values) {
      if (e.tag == t) return e;
    }
    throw ArgumentError('Unknown TemplateEntityType tag: $t');
  }
}

/// A template row. Immutable; use [copyWith] for changes.
@immutable
class Template {
  const Template({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.entityType,
    required this.payloadJson,
    required this.isBuiltIn,
    required this.createdAt,
    this.lastUsedAt,
  });

  /// Stable id. Built-ins use `t_builtin_NN`; user-saved rows
  /// get a generated `t_<millis>` id from
  /// [TemplateRepository.save].
  final String id;

  /// Display name. Shown on the template picker card.
  final String name;

  /// One-line description. Shown beneath the name on the
  /// picker card.
  final String description;

  /// Material Symbols key. Must be one of the 64 keys in
  /// [DoIcons.keys]. The repository does not validate this —
  /// the icon picker is the single source of UI-side truth.
  final String iconName;

  /// What the template bootstraps. The screens dispatch on this.
  final TemplateEntityType entityType;

  /// JSON envelope. Must parse as a `Map<String, dynamic>` with
  /// a top-level `k` integer equal to
  /// [TemplateLibrary.kTemplateFormatVersion] (currently `1`).
  /// The remaining key is the [entityType] tag: `do`, `event`,
  /// `person`, or `routine`. The exact field set within each
  /// envelope is what the add screens read in Phase B PR 2; see
  /// `lib/templates/template_library.dart` for the contract.
  final String payloadJson;

  /// True for seeded library templates. The repository refuses
  /// to delete a built-in (`TemplateValidationException`).
  final bool isBuiltIn;

  /// When the row was created. For built-ins this is a fixed
  /// `_epoch`; for user-saved rows it is the time of save.
  final DateTime createdAt;

  /// When the user last picked this template to bootstrap a
  /// new entity. Null until first use. Updated by
  /// [TemplateRepository.markUsed].
  final DateTime? lastUsedAt;

  Template copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    TemplateEntityType? entityType,
    String? payloadJson,
    bool? isBuiltIn,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return Template(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      entityType: entityType ?? this.entityType,
      payloadJson: payloadJson ?? this.payloadJson,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Template &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.iconName == iconName &&
        other.entityType == entityType &&
        other.payloadJson == payloadJson &&
        other.isBuiltIn == isBuiltIn &&
        other.createdAt == createdAt &&
        other.lastUsedAt == lastUsedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    iconName,
    entityType,
    payloadJson,
    isBuiltIn,
    createdAt,
    lastUsedAt,
  );

  @override
  String toString() =>
      'Template(id: $id, name: $name, entityType: ${entityType.tag}, '
      'isBuiltIn: $isBuiltIn)';
}

/// Thrown by [TemplateRepository.save] when the `payloadJson`
/// envelope is malformed or has the wrong format version, and
/// by [TemplateRepository.delete] when the caller tries to
/// delete a built-in.
class TemplateValidationException implements Exception {
  const TemplateValidationException(this.message);
  final String message;

  @override
  String toString() => 'TemplateValidationException: $message';
}
