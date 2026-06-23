// Trigger sealed hierarchy — the "when" half of the
// Trigger / Condition / Action spine.
//
// A Trigger is the *event source* for a non-time-fired
// automation. Per the Phase C PR 1 spec, there are seven
// top-level kinds:
//
//   - TimeOfDay            — fires at a wall-clock time.
//   - LocationEnter        — geofence enter.
//   - LocationExit         — geofence exit.
//   - DeviceState          — sealed inner (battery,
//                            charging, headphone, ...).
//   - CalendarEvent        — sealed inner (event-start,
//                            event-end, event-reminder,
//                            free-busy).
//   - CallIncoming         — sealed inner (any / known
//                            contact / unknown contact).
//   - ForegroundApp        — v1.2 addition (SYS-086 / ADR-030
//                            follow-up): fires when the user
//                            opens a configured app. Gated by
//                            the special-access
//                            `PACKAGE_USAGE_STATS` permission
//                            (PermissionKind.usageStats). The
//                            matching engine watches the
//                            `DeviceStateService.events` stream
//                            for `ForegroundAppChanged`
//                            snapshots; the predicate in
//                            `routine_executor.dart` filters on
//                            [packageName]. The shape is fixed
//                            (no sealed inner) because the
//                            matching surface is one app id.
//
// Each leaf implements a `validate()` for the cheap
// invariant checks; runtime evaluation lives in
// `lib/routines/routine_executor.dart` (PR C2+).
//
// The SilentMode enum (used by ActionOverrideSilent) is
// declared here so the action layer can reference it without
// a circular import.
//
// Layer rules (per .claude/rules/):
//   - No Flutter imports. Models are pure Dart.
//   - The `RoutineExecutor` (lib/routines/) is the only
//     consumer of the exhaustive `switch (trigger)` form.

import 'package:meta/meta.dart';

/// Sealed base for the seven trigger kinds. Add a new trigger
/// by adding a new subclass here (and a corresponding case in
/// `RoutineExecutor.dispatch`).
@immutable
sealed class Trigger {
  const Trigger();

  /// Validates the trigger's invariants. Throws on the first
  /// defect. Pure: no side effects, no `DateTime.now()`.
  Trigger validate();
}

// ---------------------------------------------------------------------------
// 1. TimeOfDay — fires at a wall-clock time.
// ---------------------------------------------------------------------------

/// Fires daily at [hour]:[minute] local time. The executor
/// subscribes via the existing `AlarmScheduler` path; the
/// trigger itself is data, not a side effect.
@immutable
final class TriggerTimeOfDay extends Trigger {
  const TriggerTimeOfDay({required this.hour, required this.minute});

  /// 0..23 (24-hour clock).
  final int hour;

  /// 0..59.
  final int minute;

  @override
  TriggerTimeOfDay validate() {
    if (hour < 0 || hour > 23) {
      throw TriggerTimeOfDayInvalidHour(hour);
    }
    if (minute < 0 || minute > 59) {
      throw TriggerTimeOfDayInvalidMinute(minute);
    }
    return this;
  }

  @override
  bool operator ==(Object other) =>
      other is TriggerTimeOfDay && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

// ---------------------------------------------------------------------------
// 2 + 3. LocationEnter / LocationExit — geofence triggers.
// ---------------------------------------------------------------------------

/// Geofence-based trigger shared by [TriggerLocationEnter]
/// and [TriggerLocationExit]. The geofence circle is
/// `(latitude, longitude, radiusMeters)`; the executor
/// subscribes via `GeofenceService.instance.events`.
@immutable
sealed class TriggerLocation extends Trigger {
  const TriggerLocation({
    required this.geofenceId,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  /// Stable id (used as the equality key and as the geofence
  /// registration key on the platform side). Callers generate
  /// this with a UUID / millis-suffix.
  final String geofenceId;

  /// Human-readable label ("Home", "Office", "Gym"). UI-only.
  final String label;

  /// Latitude in degrees, validated to `[-90, 90]`.
  final double latitude;

  /// Longitude in degrees, validated to `[-180, 180]`.
  final double longitude;

  /// Radius of the geofence circle in meters, validated to
  /// `50..5000`.
  final int radiusMeters;

  @override
  TriggerLocation validate() {
    if (geofenceId.isEmpty) throw const TriggerLocationEmptyId();
    if (label.trim().isEmpty) throw const TriggerLocationEmptyLabel();
    if (latitude < -90.0 || latitude > 90.0) {
      throw TriggerLocationInvalidLatitude(latitude);
    }
    if (longitude < -180.0 || longitude > 180.0) {
      throw TriggerLocationInvalidLongitude(longitude);
    }
    if (radiusMeters < 50 || radiusMeters > 5000) {
      throw TriggerLocationInvalidRadius(radiusMeters);
    }
    return this;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TriggerLocation) return false;
    return geofenceId == other.geofenceId &&
        label == other.label &&
        latitude == other.latitude &&
        longitude == other.longitude &&
        radiusMeters == other.radiusMeters;
  }

  @override
  int get hashCode =>
      Object.hash(geofenceId, label, latitude, longitude, radiusMeters);
}

/// Fires when the device enters the geofence circle.
@immutable
final class TriggerLocationEnter extends TriggerLocation {
  const TriggerLocationEnter({
    required super.geofenceId,
    required super.label,
    required super.latitude,
    required super.longitude,
    required super.radiusMeters,
  });
}

/// Fires when the device exits the geofence circle.
@immutable
final class TriggerLocationExit extends TriggerLocation {
  const TriggerLocationExit({
    required super.geofenceId,
    required super.label,
    required super.latitude,
    required super.longitude,
    required super.radiusMeters,
  });
}

// ---------------------------------------------------------------------------
// 4. DeviceState — sealed inner (battery, charging, headphone,
//    bluetooth, wifi, dnd, screen-on).
// ---------------------------------------------------------------------------

/// Sealed device-state trigger. The seven leaves are:
///   - TriggerBatteryLow
///   - TriggerBatteryFull
///   - TriggerChargingStarted
///   - TriggerChargingStopped
///   - TriggerHeadphoneConnected
///   - TriggerHeadphoneDisconnected
///   - TriggerScreenOn
///   - TriggerScreenOff
@immutable
sealed class TriggerDeviceState extends Trigger {
  const TriggerDeviceState();

  @override
  TriggerDeviceState validate() => this;
}

/// Fires when the device battery drops to or below [percent].
@immutable
final class TriggerBatteryLow extends TriggerDeviceState {
  const TriggerBatteryLow(this.percent);
  final int percent;

  @override
  TriggerBatteryLow validate() {
    if (percent < 0 || percent > 100) {
      throw TriggerBatteryInvalidPercent(percent);
    }
    return this;
  }

  @override
  bool operator ==(Object other) =>
      other is TriggerBatteryLow && other.percent == percent;

  @override
  int get hashCode => percent.hashCode;
}

/// Fires when the device battery reaches 100% (or whatever
/// "full" threshold the platform reports).
@immutable
final class TriggerBatteryFull extends TriggerDeviceState {
  const TriggerBatteryFull();
}

/// Fires when charging starts.
@immutable
final class TriggerChargingStarted extends TriggerDeviceState {
  const TriggerChargingStarted();
}

/// Fires when charging stops.
@immutable
final class TriggerChargingStopped extends TriggerDeviceState {
  const TriggerChargingStopped();
}

/// Fires when a wired / bluetooth headphone is connected.
@immutable
final class TriggerHeadphoneConnected extends TriggerDeviceState {
  const TriggerHeadphoneConnected();
}

/// Fires when the previously-connected headphone disconnects.
@immutable
final class TriggerHeadphoneDisconnected extends TriggerDeviceState {
  const TriggerHeadphoneDisconnected();
}

/// Fires when the screen turns on (manual unlock excluded;
/// just the on/off event).
@immutable
final class TriggerScreenOn extends TriggerDeviceState {
  const TriggerScreenOn();
}

/// Fires when the screen turns off.
@immutable
final class TriggerScreenOff extends TriggerDeviceState {
  const TriggerScreenOff();
}

// ---------------------------------------------------------------------------
// 5. CalendarEvent — sealed inner (event-start, event-end,
//    event-reminder, free-busy).
// ---------------------------------------------------------------------------

/// Sealed calendar-event trigger. The four leaves are:
///   - TriggerCalendarEventStart
///   - TriggerCalendarEventEnd
///   - TriggerCalendarReminder
///   - TriggerFreeBusy
@immutable
sealed class TriggerCalendarEvent extends Trigger {
  const TriggerCalendarEvent({
    required this.calendarId,
    required this.eventTitle,
  });

  /// Stable id of the calendar (e.g., the Android
  /// `CalendarContract.Calendars._ID`). Empty string = match
  /// any calendar (the trigger fires on event transitions
  /// from any installed calendar account).
  final String calendarId;

  /// Human-readable title pattern. Empty string = any event.
  final String eventTitle;

  @override
  TriggerCalendarEvent validate() {
    // Both `calendarId` and `eventTitle` are sentinels —
    // empty means "match any". The executor's
    // `_calendarMatches` predicate (lib/routines/routine_executor.dart)
    // treats an empty `trigger.calendarId` as "match any
    // calendar" and an empty `trigger.eventTitle` as "match
    // any event title". The validate method only throws on
    // a malformed instance we cannot reason about (e.g.,
    // negative numbers in a future iteration); today every
    // well-formed instance is acceptable.
    return this;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TriggerCalendarEvent) return false;
    return calendarId == other.calendarId && eventTitle == other.eventTitle;
  }

  @override
  int get hashCode => Object.hash(calendarId, eventTitle);
}

/// Fires when a calendar event starts.
@immutable
final class TriggerCalendarEventStart extends TriggerCalendarEvent {
  const TriggerCalendarEventStart({
    required super.calendarId,
    required super.eventTitle,
  });
}

/// Fires when a calendar event ends.
@immutable
final class TriggerCalendarEventEnd extends TriggerCalendarEvent {
  const TriggerCalendarEventEnd({
    required super.calendarId,
    required super.eventTitle,
  });
}

/// Fires at the calendar event's reminder offset (e.g., 5
/// minutes before the start).
@immutable
final class TriggerCalendarReminder extends TriggerCalendarEvent {
  const TriggerCalendarReminder({
    required super.calendarId,
    required super.eventTitle,
  });
}

/// Fires when the user transitions from "free" to "busy" or
/// vice versa.
@immutable
final class TriggerFreeBusy extends TriggerCalendarEvent {
  const TriggerFreeBusy({required super.calendarId, required super.eventTitle});
}

// ---------------------------------------------------------------------------
// 6. CallIncoming — sealed inner (any / known / unknown).
// ---------------------------------------------------------------------------

/// Sealed incoming-call trigger. The three leaves are:
///   - TriggerCallIncomingAny
///   - TriggerCallIncomingKnownContact
///   - TriggerCallIncomingUnknownContact
@immutable
sealed class TriggerCallIncoming extends Trigger {
  const TriggerCallIncoming();

  @override
  TriggerCallIncoming validate() => this;
}

/// Fires for every incoming call.
@immutable
final class TriggerCallIncomingAny extends TriggerCallIncoming {
  const TriggerCallIncomingAny();
}

/// Fires for an incoming call from a contact that resolves via
/// the user's address book.
@immutable
final class TriggerCallIncomingKnownContact extends TriggerCallIncoming {
  const TriggerCallIncomingKnownContact();
}

/// Fires for an incoming call from a number not in the
/// address book (private / spam).
@immutable
final class TriggerCallIncomingUnknownContact extends TriggerCallIncoming {
  const TriggerCallIncomingUnknownContact();
}

// ---------------------------------------------------------------------------
// 7. ForegroundApp — fires when the user opens a configured app.
//
// v1.2 addition. The match is exact on [packageName]
// (e.g., `com.instagram.android`). The OS only reports the
// foreground transition if the user has granted the
// special-access `PACKAGE_USAGE_STATS` permission
// (PermissionKind.usageStats); the v1.2 reliability badge
// reads that kind's status and falls back to `degraded`
// when the grant is missing. Until the device-state probe
// wires the `ForegroundAppChanged` event (a v1.2 follow-up),
// this trigger cannot fire on real hardware — the model
// ships now so the routine executor / reliability code
// stays exhaustive, and so the templates picker can show
// the leaf as a planning placeholder.
// ---------------------------------------------------------------------------

/// Fires when the user opens the app whose Android package
/// name equals [packageName]. The label is UI-only
/// (rendered in the routine row + the trigger editor);
/// equality is on [packageName] alone (case-sensitive, as
/// the OS reports it).
///
/// Validation rules (see [validate]):
///   - `packageName` MUST be non-empty after trim.
///   - `packageName` MUST contain at least one `.` (a
///     bare name like `instagram` is not a valid Android
///     package id and would never match an OS event).
///
/// The trigger does NOT validate that the package is
/// installed on the device — the OS may not have a record
/// of an app the user has never opened. The matching
/// engine treats "package not installed" as "no event,
/// never fires" (the predicate returns `false` on every
/// `ForegroundAppChanged` snapshot, silently).
@immutable
final class TriggerForegroundApp extends Trigger {
  const TriggerForegroundApp({required this.packageName, this.label = ''});

  /// Android package id (e.g., `com.instagram.android`).
  /// Compared case-sensitively against the platform's
  /// foreground-app reports.
  final String packageName;

  /// Human-readable label ("Instagram"). UI-only; not part
  /// of [==] / [hashCode] so re-saving the same package
  /// under a fresh label does not duplicate the
  /// automation.
  final String label;

  @override
  TriggerForegroundApp validate() {
    if (packageName.trim().isEmpty) {
      throw const TriggerForegroundAppEmptyPackage();
    }
    if (!packageName.contains('.')) {
      throw TriggerForegroundAppInvalidPackage(packageName);
    }
    return this;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TriggerForegroundApp) return false;
    return packageName == other.packageName;
  }

  @override
  int get hashCode => packageName.hashCode;

  @override
  String toString() =>
      'TriggerForegroundApp(packageName: $packageName, label: $label)';
}

// ---------------------------------------------------------------------------
// SilentMode enum — shared by Trigger* and ActionOverrideSilent.
// ---------------------------------------------------------------------------

/// The device's silent / DnD mode. Used by
/// [ActionOverrideSilent] and (in PR 2+) the matching
/// Condition leaves.
enum SilentMode {
  /// The `RINGER_MODE_SILENT` mode. No sound, no vibrate.
  silent,

  /// The `RINGER_MODE_VIBRATE` mode. Vibrate but no sound.
  vibrate,

  /// The `RINGER_MODE_NORMAL` mode. Sound + vibrate.
  normal,
}

// ---------------------------------------------------------------------------
// Validation exceptions — sealed hierarchy mirroring the
// DoValidationException pattern.
// ---------------------------------------------------------------------------

@immutable
sealed class TriggerValidationException implements Exception {
  const TriggerValidationException(this.message);
  final String message;

  @override
  String toString() => 'TriggerValidationException: $message';
}

final class TriggerTimeOfDayInvalidHour extends TriggerValidationException {
  const TriggerTimeOfDayInvalidHour(this.value) : super('Hour must be 0..23.');
  final int value;
}

final class TriggerTimeOfDayInvalidMinute extends TriggerValidationException {
  const TriggerTimeOfDayInvalidMinute(this.value)
    : super('Minute must be 0..59.');
  final int value;
}

final class TriggerLocationEmptyId extends TriggerValidationException {
  const TriggerLocationEmptyId() : super('geofenceId must be non-empty.');
}

final class TriggerLocationEmptyLabel extends TriggerValidationException {
  const TriggerLocationEmptyLabel()
    : super('label must be non-empty (trimmed).');
}

final class TriggerLocationInvalidLatitude extends TriggerValidationException {
  const TriggerLocationInvalidLatitude(this.value)
    : super('latitude must be in [-90, 90].');
  final double value;
}

final class TriggerLocationInvalidLongitude extends TriggerValidationException {
  const TriggerLocationInvalidLongitude(this.value)
    : super('longitude must be in [-180, 180].');
  final double value;
}

final class TriggerLocationInvalidRadius extends TriggerValidationException {
  const TriggerLocationInvalidRadius(this.value)
    : super('radiusMeters must be in 50..5000.');
  final int value;
}

final class TriggerBatteryInvalidPercent extends TriggerValidationException {
  const TriggerBatteryInvalidPercent(this.value)
    : super('percent must be in 0..100.');
  final int value;
}

final class TriggerForegroundAppEmptyPackage
    extends TriggerValidationException {
  const TriggerForegroundAppEmptyPackage()
    : super('packageName must be non-empty (trimmed).');
}

final class TriggerForegroundAppInvalidPackage
    extends TriggerValidationException {
  const TriggerForegroundAppInvalidPackage(this.value)
    : super('packageName must contain at least one ".".');
  final String value;
}
