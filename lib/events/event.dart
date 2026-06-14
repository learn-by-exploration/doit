// Event model — one-off date-specific reminders (WF-017).
//
// An Event is a named reminder at a specific date+time. It is NOT
// a habit: no streak, no rest-day budget, no proof mode by default.
// An optional mission chain is allowed (for "strong" events), but
// the default is a simple notification.
//
// Recurrence: 'none' (default) or 'annually' (birthdays,
// anniversaries). v0.2 ships 'none' and 'annually' only.
//
// The model is pure Dart; the Drift row mapping lives in
// `lib/services/event_repository.dart`.
//
// Layer rules (per .claude/rules/):
//   - No Flutter imports.
//   - Immutable; mutations go through [Event.copyWith].

import 'package:meta/meta.dart';

/// Stable, opaque event identifier. Same shape as [HabitId] /
/// `PersonId` — a String alias, ready to be promoted to a typed
/// value-class in v0.3.
typedef EventId = String;

/// Recurrence shape. 'none' fires once; 'annually' fires every
/// year on the same month/day. 'monthly' / 'weekly' are not in
/// v0.2 scope (the user can add a habit for those).
enum EventRecurrence { none, annually }

/// A one-off date-specific reminder. Carries a name, a fire time
/// (millis since epoch UTC), a lead time (how long before `atMillis`
/// to notify), an optional mission chain, and a recurrence shape.
@immutable
class Event {
  const Event({
    required this.id,
    required this.name,
    required this.atMillis,
    required this.leadTimeMillis,
    required this.createdAtMillis,
    this.missionChainJson,
    this.recurrence = EventRecurrence.none,
    this.archivedAtMillis,
  });

  final EventId id;
  final String name;
  final int atMillis;
  final int leadTimeMillis;
  final String? missionChainJson;
  final EventRecurrence recurrence;
  final int? archivedAtMillis;
  final int createdAtMillis;

  /// The millis at which the notification should fire.
  /// `atMillis - leadTimeMillis`.
  int get notifyAtMillis => atMillis - leadTimeMillis;

  /// `true` if the event is archived (fired and dismissed, or
  /// manually archived by the user).
  bool get isArchived => archivedAtMillis != null;

  /// `true` if the event has already fired.
  bool hasFired(DateTime now) => now.millisecondsSinceEpoch >= atMillis;

  /// Returns the next fire time after [from]. For 'none' events,
  /// returns null after the initial fire. For 'annually', returns
  /// the same month/day one year later, repeatedly.
  DateTime? nextOccurrence(DateTime from) {
    final at = DateTime.fromMillisecondsSinceEpoch(atMillis);
    if (recurrence == EventRecurrence.none) {
      return at.isAfter(from) ? at : null;
    }
    // annually: advance year until at > from.
    var year = at.year;
    while (true) {
      final candidate = DateTime(
        year + (at.isAfter(from) ? 0 : 1),
        at.month,
        at.day,
        at.hour,
        at.minute,
      );
      if (candidate.isAfter(from)) return candidate;
      year++;
    }
  }

  Event copyWith({
    String? name,
    int? atMillis,
    int? leadTimeMillis,
    String? missionChainJson,
    EventRecurrence? recurrence,
    int? archivedAtMillis,
    bool clearArchived = false,
  }) {
    return Event(
      id: id,
      name: name ?? this.name,
      atMillis: atMillis ?? this.atMillis,
      leadTimeMillis: leadTimeMillis ?? this.leadTimeMillis,
      missionChainJson: missionChainJson ?? this.missionChainJson,
      recurrence: recurrence ?? this.recurrence,
      archivedAtMillis: clearArchived
          ? null
          : (archivedAtMillis ?? this.archivedAtMillis),
      createdAtMillis: createdAtMillis,
    );
  }

  /// Validates the event's invariants. Throws [EventValidationException]
  /// on the first defect.
  void validate() {
    if (name.trim().isEmpty) {
      throw const EventNameEmpty();
    }
    if (atMillis <= 0) {
      throw const EventInvalidAtMillis();
    }
    if (leadTimeMillis < 0) {
      throw EventInvalidLeadTime(leadTimeMillis);
    }
  }

  @override
  bool operator ==(Object other) => other is Event && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Thrown by [Event.validate] when an invariant is violated.
sealed class EventValidationException implements Exception {
  const EventValidationException();
}

final class EventNameEmpty extends EventValidationException {
  const EventNameEmpty();
}

final class EventInvalidAtMillis extends EventValidationException {
  const EventInvalidAtMillis();
}

final class EventInvalidLeadTime extends EventValidationException {
  const EventInvalidLeadTime(this.leadTimeMillis);
  final int leadTimeMillis;
}
