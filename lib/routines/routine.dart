// Automation aggregate — the unit stored in
// `habits.automations_json` / `people.automations_json` /
// `events.automations_json`.
//
// Per the Phase C PR 1 spec:
//
//   - `Automation(id, trigger, condition?, action, enabled)`:
//     * `id` is a stable String (UUID-like; auto-assigned
//       on construction).
//     * `trigger` is **non-null** (a routine with no trigger
//       is meaningless).
//     * `condition` is **optional** (null = always-true).
//     * `action` is **single** (one routine fires one
//       action; compose via Condition tree for fan-out).
//     * `enabled` is the boolean (positive naming; NOT
//       `disabled`).
//
//   - Per-shape `toJson` / `fromJson` with stable `type`
//     discriminator strings. NO central envelope codec.
//
// The persistence path on a Do / Event / Person row is a
// `List<Automation>` (the codec lives at the row level,
// not here). PR C1 ships `encodeList` / `decodeList` as a
// convenience on top of the per-shape `toJson` /
// `fromJson` methods — no versioned envelope.

import 'dart:convert';

import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/condition.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:meta/meta.dart';

// ---------------------------------------------------------------------------
// Automation
// ---------------------------------------------------------------------------

/// One automation rule. Immutable. Equality is on the
/// (id, trigger, condition, action, enabled) tuple.
@immutable
class Automation {
  Automation({
    String? id,
    required this.trigger,
    this.condition,
    required this.action,
    this.enabled = true,
  }) : id = id ?? _mintId();

  /// Stable id. UUID-shaped string; auto-assigned on
  /// construction. Equality on the id alone is sufficient for
  /// set membership but the full payload is used for
  /// value-equality.
  final String id;

  /// The trigger source. **Non-null** per spec.
  final Trigger trigger;

  /// Optional gating condition. `null` means "no gate".
  final Condition? condition;

  /// The action to dispatch. **Single** action per spec.
  final Action action;

  /// User-facing on/off switch. Default `true`. POSITIVE
  /// naming (NOT `disabled`).
  final bool enabled;

  /// Validates the automation's invariants. Throws
  /// [AutomationValidationException] on the first defect.
  Automation validate() {
    trigger.validate();
    condition?.validate();
    action.validate();
    return this;
  }

  /// Per-Automation JSON. Shape:
  /// ```
  /// {
  ///   "id": "<uuid>",
  ///   "trigger": { ...triggerToJson... },
  ///   "condition": null | { ...conditionToJson... },
  ///   "action":   { ...actionToJson... },
  ///   "enabled":  true
  /// }
  /// ```
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'trigger': triggerToJson(trigger),
    'condition': condition == null ? null : conditionToJson(condition!),
    'action': actionToJson(action),
    'enabled': enabled,
  };

  /// Decode a single automation. Throws [FormatException] on
  /// a malformed payload.
  static Automation fromJson(Map<String, Object?> j) {
    final idRaw = j['id'];
    final id = idRaw is String ? idRaw : null;
    final triggerRaw = j['trigger'];
    if (triggerRaw is! Map<String, Object?>) {
      throw const FormatException('automation.trigger must be a JSON object');
    }
    final trigger = triggerFromJson(triggerRaw);
    final conditionRaw = j['condition'];
    Condition? condition;
    if (conditionRaw != null) {
      if (conditionRaw is! Map<String, Object?>) {
        throw const FormatException(
          'automation.condition must be a JSON object or null',
        );
      }
      condition = conditionFromJson(conditionRaw);
    }
    final actionRaw = j['action'];
    if (actionRaw is! Map<String, Object?>) {
      throw const FormatException('automation.action must be a JSON object');
    }
    final action = actionFromJson(actionRaw);
    final enabledRaw = j['enabled'];
    if (enabledRaw is! bool) {
      throw const FormatException('automation.enabled must be a bool');
    }
    return Automation(
      id: id,
      trigger: trigger,
      condition: condition,
      action: action,
      enabled: enabledRaw,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Automation) return false;
    return id == other.id &&
        trigger == other.trigger &&
        condition == other.condition &&
        action == other.action &&
        enabled == other.enabled;
  }

  @override
  int get hashCode => Object.hash(id, trigger, condition, action, enabled);
}

// ---------------------------------------------------------------------------
// Trigger JSON
// ---------------------------------------------------------------------------

/// Encode any [Trigger] to a JSON object with a stable
/// `type` discriminator.
Map<String, Object?> triggerToJson(Trigger t) {
  switch (t) {
    case TriggerTimeOfDay(:final hour, :final minute):
      return <String, Object?>{
        'type': 'timeOfDay',
        'hour': hour,
        'minute': minute,
      };
    case TriggerLocationEnter(
      :final geofenceId,
      :final label,
      :final latitude,
      :final longitude,
      :final radiusMeters,
    ):
      return <String, Object?>{
        'type': 'locationEnter',
        'geofenceId': geofenceId,
        'label': label,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
      };
    case TriggerLocationExit(
      :final geofenceId,
      :final label,
      :final latitude,
      :final longitude,
      :final radiusMeters,
    ):
      return <String, Object?>{
        'type': 'locationExit',
        'geofenceId': geofenceId,
        'label': label,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
      };
    case TriggerBatteryLow(:final percent):
      return <String, Object?>{'type': 'batteryLow', 'percent': percent};
    case TriggerBatteryFull():
      return <String, Object?>{'type': 'batteryFull'};
    case TriggerChargingStarted():
      return <String, Object?>{'type': 'chargingStarted'};
    case TriggerChargingStopped():
      return <String, Object?>{'type': 'chargingStopped'};
    case TriggerHeadphoneConnected():
      return <String, Object?>{'type': 'headphoneConnected'};
    case TriggerHeadphoneDisconnected():
      return <String, Object?>{'type': 'headphoneDisconnected'};
    case TriggerScreenOn():
      return <String, Object?>{'type': 'screenOn'};
    case TriggerScreenOff():
      return <String, Object?>{'type': 'screenOff'};
    case TriggerCalendarEventStart(:final calendarId, :final eventTitle):
      return <String, Object?>{
        'type': 'calendarEventStart',
        'calendarId': calendarId,
        'eventTitle': eventTitle,
      };
    case TriggerCalendarEventEnd(:final calendarId, :final eventTitle):
      return <String, Object?>{
        'type': 'calendarEventEnd',
        'calendarId': calendarId,
        'eventTitle': eventTitle,
      };
    case TriggerCalendarReminder(:final calendarId, :final eventTitle):
      return <String, Object?>{
        'type': 'calendarReminder',
        'calendarId': calendarId,
        'eventTitle': eventTitle,
      };
    case TriggerFreeBusy(:final calendarId, :final eventTitle):
      return <String, Object?>{
        'type': 'freeBusy',
        'calendarId': calendarId,
        'eventTitle': eventTitle,
      };
    case TriggerCallIncomingAny():
      return <String, Object?>{'type': 'callIncomingAny'};
    case TriggerCallIncomingKnownContact():
      return <String, Object?>{'type': 'callIncomingKnownContact'};
    case TriggerCallIncomingUnknownContact():
      return <String, Object?>{'type': 'callIncomingUnknownContact'};
  }
}

/// Decode a [Trigger] from a JSON object. Throws
/// [FormatException] on a malformed or unknown type.
Trigger triggerFromJson(Map<String, Object?> j) {
  final type = j['type'];
  if (type is! String) {
    throw const FormatException('trigger.type must be a string');
  }
  switch (type) {
    case 'timeOfDay':
      return TriggerTimeOfDay(
        hour: (j['hour'] as num).toInt(),
        minute: (j['minute'] as num).toInt(),
      );
    case 'locationEnter':
    case 'locationExit':
      final ctor = type == 'locationEnter'
          ? TriggerLocationEnter.new
          : TriggerLocationExit.new;
      return ctor(
        geofenceId: j['geofenceId'] as String,
        label: j['label'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        radiusMeters: (j['radiusMeters'] as num).toInt(),
      );
    case 'batteryLow':
      return TriggerBatteryLow((j['percent'] as num).toInt());
    case 'batteryFull':
      return const TriggerBatteryFull();
    case 'chargingStarted':
      return const TriggerChargingStarted();
    case 'chargingStopped':
      return const TriggerChargingStopped();
    case 'headphoneConnected':
      return const TriggerHeadphoneConnected();
    case 'headphoneDisconnected':
      return const TriggerHeadphoneDisconnected();
    case 'screenOn':
      return const TriggerScreenOn();
    case 'screenOff':
      return const TriggerScreenOff();
    case 'calendarEventStart':
      return TriggerCalendarEventStart(
        calendarId: j['calendarId'] as String,
        eventTitle: j['eventTitle'] as String,
      );
    case 'calendarEventEnd':
      return TriggerCalendarEventEnd(
        calendarId: j['calendarId'] as String,
        eventTitle: j['eventTitle'] as String,
      );
    case 'calendarReminder':
      return TriggerCalendarReminder(
        calendarId: j['calendarId'] as String,
        eventTitle: j['eventTitle'] as String,
      );
    case 'freeBusy':
      return TriggerFreeBusy(
        calendarId: j['calendarId'] as String,
        eventTitle: j['eventTitle'] as String,
      );
    case 'callIncomingAny':
      return const TriggerCallIncomingAny();
    case 'callIncomingKnownContact':
      return const TriggerCallIncomingKnownContact();
    case 'callIncomingUnknownContact':
      return const TriggerCallIncomingUnknownContact();
    default:
      throw FormatException('Unknown trigger.type: $type');
  }
}

// ---------------------------------------------------------------------------
// Condition JSON
// ---------------------------------------------------------------------------

/// Encode any [Condition] to a JSON object with a stable
/// `type` discriminator.
Map<String, Object?> conditionToJson(Condition c) {
  switch (c) {
    case ConditionAnd(:final left, :final right):
      return <String, Object?>{
        'type': 'and',
        'left': conditionToJson(left),
        'right': conditionToJson(right),
      };
    case ConditionOr(:final left, :final right):
      return <String, Object?>{
        'type': 'or',
        'left': conditionToJson(left),
        'right': conditionToJson(right),
      };
    case ConditionTimeWindow(
      :final startHour,
      :final startMinute,
      :final endHour,
      :final endMinute,
    ):
      return <String, Object?>{
        'type': 'timeWindow',
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
      };
    case ConditionDayOfWeek(:final weekdays):
      return <String, Object?>{
        'type': 'dayOfWeek',
        'weekdays': weekdays.toList()..sort(),
      };
    case ConditionCalendarBusy(:final calendarId):
      return <String, Object?>{
        'type': 'calendarBusy',
        'calendarId': calendarId,
      };
    case ConditionBatteryRange(:final low, :final high):
      return <String, Object?>{
        'type': 'batteryRange',
        'low': low,
        'high': high,
      };
    case ConditionSilentMode(:final mode):
      return <String, Object?>{'type': 'silentMode', 'mode': mode.name};
  }
}

/// Decode a [Condition] from a JSON object. Throws
/// [FormatException] on a malformed or unknown type.
Condition conditionFromJson(Map<String, Object?> j) {
  final type = j['type'];
  if (type is! String) {
    throw const FormatException('condition.type must be a string');
  }
  switch (type) {
    case 'and':
      return ConditionAnd(
        conditionFromJson((j['left'] as Map).cast<String, Object?>()),
        conditionFromJson((j['right'] as Map).cast<String, Object?>()),
      );
    case 'or':
      return ConditionOr(
        conditionFromJson((j['left'] as Map).cast<String, Object?>()),
        conditionFromJson((j['right'] as Map).cast<String, Object?>()),
      );
    case 'timeWindow':
      return ConditionTimeWindow(
        startHour: (j['startHour'] as num).toInt(),
        startMinute: (j['startMinute'] as num).toInt(),
        endHour: (j['endHour'] as num).toInt(),
        endMinute: (j['endMinute'] as num).toInt(),
      );
    case 'dayOfWeek':
      final raw = (j['weekdays'] as List).cast<num>().map((n) => n.toInt());
      return ConditionDayOfWeek(raw.toSet());
    case 'calendarBusy':
      return ConditionCalendarBusy(calendarId: j['calendarId'] as String);
    case 'batteryRange':
      return ConditionBatteryRange(
        low: (j['low'] as num?)?.toInt(),
        high: (j['high'] as num?)?.toInt(),
      );
    case 'silentMode':
      return ConditionSilentMode(SilentMode.values.byName(j['mode'] as String));
    default:
      throw FormatException('Unknown condition.type: $type');
  }
}

// ---------------------------------------------------------------------------
// Action JSON
// ---------------------------------------------------------------------------

/// Encode any [Action] to a JSON object with a stable
/// `type` discriminator.
Map<String, Object?> actionToJson(Action a) {
  switch (a) {
    case ActionNotify(:final title, :final body):
      return <String, Object?>{'type': 'notify', 'title': title, 'body': body};
    case ActionFullscreen():
      return <String, Object?>{'type': 'fullscreen'};
    case ActionCallIntercept(:final decision):
      return <String, Object?>{
        'type': 'callIntercept',
        'decision': decision.name,
      };
    case ActionOverrideSilent(:final targetMode):
      return <String, Object?>{
        'type': 'overrideSilent',
        'targetMode': targetMode.name,
      };
    case ActionOpenApp(:final route):
      return <String, Object?>{'type': 'openApp', 'route': route};
  }
}

/// Decode an [Action] from a JSON object. Throws
/// [FormatException] on a malformed or unknown type.
Action actionFromJson(Map<String, Object?> j) {
  final type = j['type'];
  if (type is! String) {
    throw const FormatException('action.type must be a string');
  }
  switch (type) {
    case 'notify':
      return ActionNotify(
        title: j['title'] as String,
        body: j['body'] as String,
      );
    case 'fullscreen':
      return const ActionFullscreen();
    case 'callIntercept':
      return ActionCallIntercept(
        decision: CallInterceptDecision.values.byName(j['decision'] as String),
      );
    case 'overrideSilent':
      return ActionOverrideSilent(
        targetMode: SilentMode.values.byName(j['targetMode'] as String),
      );
    case 'openApp':
      return ActionOpenApp(route: j['route'] as String);
    default:
      throw FormatException('Unknown action.type: $type');
  }
}

// ---------------------------------------------------------------------------
// List-level convenience codec (no envelope).
// ---------------------------------------------------------------------------

/// Encode a list of [Automation] to a JSON string (no
/// envelope — each Automation owns its own `toJson`).
String encodeAutomationList(List<Automation> automations) {
  return jsonEncode(automations.map((a) => a.toJson()).toList(growable: false));
}

/// Decode a JSON string into a list of [Automation]. A null
/// or empty input decodes to an empty list. Throws
/// [FormatException] on a malformed payload.
List<Automation> decodeAutomationList(String? raw) {
  if (raw == null || raw.isEmpty) return const <Automation>[];
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw const FormatException('automation list must be a JSON array');
  }
  return decoded
      .cast<Map<String, Object?>>()
      .map(Automation.fromJson)
      .toList(growable: false);
}

// ---------------------------------------------------------------------------
// Automation event — published on dispatch.
// ---------------------------------------------------------------------------

/// Stream event published when a [Automation] is dispatched.
/// UI / debug surfaces subscribe to this to render "fired"
/// chips in the home screen and the settings debug screen.
@immutable
class AutomationFired {
  const AutomationFired({required this.automation, required this.at});

  /// The fired automation (snapshot at dispatch time).
  final Automation automation;

  /// When the dispatch occurred. Wall-clock at the call site
  /// (the executor does not read the clock itself).
  final DateTime at;
}

// ---------------------------------------------------------------------------
// v1.1 (SYS-082) — open-app request envelope.
// ---------------------------------------------------------------------------

/// A request from the routine dispatcher for the home screen
/// (or any shell navigator listener) to push a Flutter
/// route. Produced when an automation with `ActionOpenApp`
/// fires; consumed by the home-screen `RoutineBanner` widget.
///
/// The executor is a singleton with no Flutter dependency;
/// it cannot push routes directly. Instead it appends a
/// `RoutineOpenAppRequest` to a `ValueListenable` that the
/// home screen drains on resume + on each change.
@immutable
class RoutineOpenAppRequest {
  const RoutineOpenAppRequest({required this.route, required this.at});

  /// The route to navigate to (e.g., `/event` or `do/<id>`).
  /// Forwarded verbatim to `Navigator.pushNamed`.
  final String route;

  /// When the request was produced. Wall-clock at the call
  /// site.
  final DateTime at;
}

// ---------------------------------------------------------------------------
// Validation exceptions.
// ---------------------------------------------------------------------------

@immutable
sealed class AutomationValidationException implements Exception {
  const AutomationValidationException(this.message);
  final String message;

  @override
  String toString() => 'AutomationValidationException: $message';
}

final class AutomationInvalid extends AutomationValidationException {
  const AutomationInvalid(this.cause)
    : super('Automation failed validation: $cause');
  final Object cause;
}

// ---------------------------------------------------------------------------
// Internal: id minting.
// ---------------------------------------------------------------------------

/// Minimal UUID-shaped id. Per spec the id is a "stable
/// String (UUID-like; auto-assigned on construction)". We
/// avoid pulling `package:uuid` into the pure-Dart layer;
/// `millis + counter` is sufficient for uniqueness within a
/// single process.
int _idCounter = 0;
String _mintId() {
  final millis = DateTime.now().millisecondsSinceEpoch;
  final n = ++_idCounter;
  return 'auto_${millis.toRadixString(16)}_${n.toRadixString(16)}';
}

/// Reset the id counter for tests. Test-only seam.
@visibleForTesting
void resetAutomationIdCounterForTesting() {
  _idCounter = 0;
}
