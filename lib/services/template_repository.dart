// CRUD + queries for templates. Pure SQL/Dart — no UI imports.
//
// The repository follows the singleton-with-`_ready` pattern
// in `.claude/rules/lib-services.md`. The drift row ↔ domain
// `Template` mapping lives here so the model layer stays free
// of drift annotations.
//
// v1.0 reframe (Phase B PR 1).

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/templates/template.dart';
import 'package:doit/templates/template_library.dart';

class TemplateRepository implements TemplateImportRepository {
  TemplateRepository._();

  static final TemplateRepository instance = TemplateRepository._();

  Future<void> get _ready => AppDatabaseService.instance.ready;
  AppDatabase get _db => AppDatabaseService.instance.db;

  /// Save (insert or update) a template. Validates the
  /// `payloadJson` envelope:
  ///   - must be valid JSON,
  ///   - top-level `k` must be an int equal to
  ///     [TemplateLibrary.kTemplateFormatVersion].
  ///
  /// If [Template.id] is empty, a stable id of the form
  /// `t_<millisSinceEpoch>` is assigned. Returns the saved id
  /// (the generated one, when applicable).
  @override
  Future<String> save(Template t) async {
    await _ready;
    _validateEnvelope(t);
    final id = t.id.isEmpty
        ? 't_${DateTime.now().millisecondsSinceEpoch}'
        : t.id;
    final row = _toRow(t.copyWith(id: id));
    await _db.into(_db.templates).insertOnConflictUpdate(row);
    return id;
  }

  /// Fetch a template by id. Returns `null` if not present.
  Future<Template?> getById(String id) async {
    await _ready;
    final row = await (_db.select(
      _db.templates,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// List all templates, oldest-first. Optional filters:
  ///   - [entityType]: only that type,
  ///   - [builtInOnly]: only `isBuiltIn = true` rows.
  ///
  /// Order is `createdAtMillis ASC, id ASC` so the picker UI
  /// shows built-ins in their curated order and user-saved rows
  /// after them.
  @override
  Future<List<Template>> listAll({
    TemplateEntityType? entityType,
    bool builtInOnly = false,
  }) async {
    await _ready;
    final query = _db.select(_db.templates);
    if (entityType != null) {
      query.where((t) => t.entityType.equals(entityType.tag));
    }
    if (builtInOnly) {
      query.where((t) => t.isBuiltIn.equals(true));
    }
    query.orderBy([
      (t) => OrderingTerm.asc(t.createdAtMillis),
      (t) => OrderingTerm.asc(t.id),
    ]);
    final rows = await query.get();
    return rows.map(_fromRow).toList(growable: false);
  }

  /// Refuses to delete a built-in template
  /// ([TemplateValidationException]). User-saved rows are
  /// removed. A no-op when the id is not present.
  Future<void> delete(String id) async {
    await _ready;
    final existing = await getById(id);
    if (existing == null) return;
    if (existing.isBuiltIn) {
      throw const TemplateValidationException(
        'Cannot delete a built-in template',
      );
    }
    await (_db.delete(_db.templates)..where((t) => t.id.equals(id))).go();
  }

  /// Update `lastUsedAtMillis` to [when]. Used by the add
  /// screens after the user picks a template to bootstrap a
  /// new entity, so the picker can sort by "most-used" later.
  Future<void> markUsed(String id, DateTime when) async {
    await _ready;
    await (_db.update(_db.templates)..where((t) => t.id.equals(id))).write(
      TemplatesCompanion(lastUsedAtMillis: Value(when.millisecondsSinceEpoch)),
    );
  }

  // --- envelope validation ---------------------------------------

  void _validateEnvelope(Template t) {
    Object? parsed;
    try {
      parsed = jsonDecode(t.payloadJson);
    } on FormatException catch (e) {
      throw TemplateValidationException(
        'payloadJson is not valid JSON: ${e.message}',
      );
    }
    if (parsed is! Map<String, dynamic>) {
      throw const TemplateValidationException(
        'payloadJson must be a JSON object',
      );
    }
    final k = parsed['k'];
    if (k is! int || k != TemplateLibrary.kTemplateFormatVersion) {
      throw TemplateValidationException(
        'payloadJson envelope k must equal '
        '${TemplateLibrary.kTemplateFormatVersion}, got: $k',
      );
    }
  }

  // --- mapping ---------------------------------------------------

  TemplateRow _toRow(Template t) {
    return TemplateRow(
      id: t.id,
      name: t.name,
      description: t.description,
      iconName: t.iconName,
      entityType: t.entityType.tag,
      payloadJson: t.payloadJson,
      isBuiltIn: t.isBuiltIn,
      createdAtMillis: t.createdAt.millisecondsSinceEpoch,
      lastUsedAtMillis: t.lastUsedAt?.millisecondsSinceEpoch,
    );
  }

  Template _fromRow(TemplateRow r) {
    return Template(
      id: r.id,
      name: r.name,
      description: r.description,
      iconName: r.iconName,
      entityType: TemplateEntityType.fromTag(r.entityType),
      payloadJson: r.payloadJson,
      isBuiltIn: r.isBuiltIn,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAtMillis),
      lastUsedAt: r.lastUsedAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r.lastUsedAtMillis!),
    );
  }
}
