// EventRepository — CRUD for one-off date-specific reminders
// (WF-017).
//
// Maps the Drift `Events` row to/from the pure-Dart `Event` domain
// model. The repository owns no state; it delegates to the Drift
// singleton. All public methods `await AppDatabaseService.instance.ready`
// first.
//
// Recurrence: the row stores 'none' | 'annually'. The domain model
// uses the sealed `EventRecurrence` enum.

import 'package:doit/events/event.dart';
import 'package:doit/routines/routine.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:drift/drift.dart';

class EventRepository {
  EventRepository._();

  static final EventRepository instance = EventRepository._();

  Future<void> get _ready => AppDatabaseService.instance.ready;
  AppDatabase get _db => AppDatabaseService.instance.db;

  /// Persist an event. The repository delegates input validation
  /// to the model (`event.validate()`).
  Future<void> save(Event event) async {
    await _ready;
    event.validate();
    await _db.into(_db.events).insertOnConflictUpdate(_toRow(event));
  }

  /// Fetch an event by id. Returns `null` if not present.
  Future<Event?> getById(String id) async {
    await _ready;
    final row = await (_db.select(
      _db.events,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// List all active (non-archived) events, soonest-first.
  Future<List<Event>> listActive() async {
    await _ready;
    final rows =
        await (_db.select(_db.events)
              ..where((t) => t.archivedAtMillis.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.atMillis)]))
            .get();
    return rows.map(_fromRow).toList(growable: false);
  }

  /// List events that have already fired (atMillis <= now) and are
  /// not yet archived. The scheduler calls this on each tick to
  /// auto-archive fired events.
  Future<List<Event>> listPendingArchive(DateTime now) async {
    await _ready;
    final rows =
        await (_db.select(_db.events)
              ..where(
                (t) =>
                    t.archivedAtMillis.isNull() &
                    t.atMillis.isSmallerOrEqualValue(
                      now.millisecondsSinceEpoch,
                    ),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.atMillis)]))
            .get();
    return rows.map(_fromRow).toList(growable: false);
  }

  /// Archive an event (mark as fired-and-dismissed).
  Future<void> archive(String id, DateTime at) async {
    await _ready;
    await (_db.update(_db.events)..where((t) => t.id.equals(id))).write(
      EventsCompanion(archivedAtMillis: Value(at.millisecondsSinceEpoch)),
    );
  }

  /// Hard-delete an event.
  Future<void> deleteById(String id) async {
    await _ready;
    await (_db.delete(_db.events)..where((t) => t.id.equals(id))).go();
  }

  EventRow _toRow(Event e) {
    return EventRow(
      id: e.id,
      name: e.name,
      atMillis: e.atMillis,
      leadTimeMillis: e.leadTimeMillis,
      missionChainJson: e.missionChainJson,
      recurrence: _recurrenceToString(e.recurrence),
      archivedAtMillis: e.archivedAtMillis,
      createdAtMillis: e.createdAtMillis,
      automationsJson: e.automations.isEmpty
          ? null
          : encodeAutomationList(e.automations),
    );
  }

  Event _fromRow(EventRow r) {
    return Event(
      id: r.id,
      name: r.name,
      atMillis: r.atMillis,
      leadTimeMillis: r.leadTimeMillis,
      missionChainJson: r.missionChainJson,
      recurrence: _recurrenceFromString(r.recurrence),
      archivedAtMillis: r.archivedAtMillis,
      createdAtMillis: r.createdAtMillis,
      automations: decodeAutomationList(r.automationsJson),
    );
  }

  String _recurrenceToString(EventRecurrence r) {
    return switch (r) {
      EventRecurrence.none => 'none',
      EventRecurrence.annually => 'annually',
    };
  }

  EventRecurrence _recurrenceFromString(String s) {
    return switch (s) {
      'annually' => EventRecurrence.annually,
      _ => EventRecurrence.none,
    };
  }
}
