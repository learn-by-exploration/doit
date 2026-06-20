// Condition sealed hierarchy — the "if" half of the
// Trigger / Condition / Action spine.
//
// A Condition is an optional guard placed between the
// Trigger and the Action. `null` (on Automation.condition)
// means "fire whenever the trigger fires"; a present
// Condition gates the firing on the runtime value of one or
// more leaves.
//
// Per the Phase C PR 1 spec, there are seven concrete shapes:
//
//   - ConditionAnd(left, right)        — BINARY, not list-based.
//                                        Nest for N-ary AND.
//   - ConditionOr(left, right)         — BINARY, not list-based.
//                                        Nest for N-ary OR.
//   - ConditionTimeWindow              — [start, end) wall-clock
//                                        window.
//   - ConditionDayOfWeek(weekdays)     — `Set<int>` in
//                                        `DateTime.weekday`
//                                        convention (1=Mon..7=Sun).
//   - ConditionCalendarBusy            — user is in a meeting.
//   - ConditionBatteryRange(low, high) — battery is in the range.
//   - ConditionSilentMode(mode)        — device's silent mode
//                                        matches.
//
// Layer rules (per .claude/rules/):
//   - No Flutter imports.
//   - Conditions are pure Dart; evaluation lives in
//     `lib/routines/routine_executor.dart` (PR C2+).
//   - No `DateTime.now()` in the model. The executor passes
//     `now` and the runtime probe results.

import 'package:doit/triggers/trigger.dart' show SilentMode;
import 'package:meta/meta.dart';

/// Sealed base for the seven condition kinds. A `null`
/// `Automation.condition` is the "always-true" gate.
@immutable
sealed class Condition {
  const Condition();

  /// Validates the condition's invariants. Pure.
  Condition validate();
}

/// Logical AND of two conditions. **Binary** — nest for
/// N-ary AND (`ConditionAnd(a, ConditionAnd(b, c))`).
@immutable
final class ConditionAnd extends Condition {
  const ConditionAnd(this.left, this.right);

  final Condition left;
  final Condition right;

  @override
  ConditionAnd validate() {
    left.validate();
    right.validate();
    return this;
  }

  @override
  bool operator ==(Object other) =>
      other is ConditionAnd && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// Logical OR of two conditions. **Binary** — nest for
/// N-ary OR.
@immutable
final class ConditionOr extends Condition {
  const ConditionOr(this.left, this.right);

  final Condition left;
  final Condition right;

  @override
  ConditionOr validate() {
    left.validate();
    right.validate();
    return this;
  }

  @override
  bool operator ==(Object other) =>
      other is ConditionOr && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// Time-of-day window in 24-hour clock. The condition is true
/// when the current local time is in
/// `[startHour:startMinute, endHour:endMinute)`. Endpoints
/// are validated by [ConditionTimeWindow.validate]. The
/// window may wrap midnight (e.g., 22:00..06:00); the
/// validation only rejects out-of-range clock values.
@immutable
final class ConditionTimeWindow extends Condition {
  const ConditionTimeWindow({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  @override
  ConditionTimeWindow validate() {
    if (startHour < 0 || startHour > 23) {
      throw ConditionTimeWindowInvalidHour('startHour', startHour);
    }
    if (endHour < 0 || endHour > 23) {
      throw ConditionTimeWindowInvalidHour('endHour', endHour);
    }
    if (startMinute < 0 || startMinute > 59) {
      throw ConditionTimeWindowInvalidMinute('startMinute', startMinute);
    }
    if (endMinute < 0 || endMinute > 59) {
      throw ConditionTimeWindowInvalidMinute('endMinute', endMinute);
    }
    return this;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ConditionTimeWindow) return false;
    return startHour == other.startHour &&
        startMinute == other.startMinute &&
        endHour == other.endHour &&
        endMinute == other.endMinute;
  }

  @override
  int get hashCode => Object.hash(startHour, startMinute, endHour, endMinute);
}

/// Day-of-week set in `DateTime.weekday` convention
/// (1 = Monday .. 7 = Sunday). The condition is true when
/// the current local weekday is in [weekdays]. [weekdays] is
/// a `Set<int>` (per spec) — order-insensitive and
/// deduplicated.
@immutable
final class ConditionDayOfWeek extends Condition {
  ConditionDayOfWeek(Set<int> weekdays) : weekdays = Set.unmodifiable(weekdays);

  final Set<int> weekdays;

  @override
  ConditionDayOfWeek validate() {
    if (weekdays.isEmpty) throw const ConditionDayOfWeekEmpty();
    for (final wd in weekdays) {
      if (wd < 1 || wd > 7) throw ConditionDayOfWeekInvalidWeekday(wd);
    }
    return this;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ConditionDayOfWeek) return false;
    return setEquals(weekdays, other.weekdays);
  }

  @override
  int get hashCode => Object.hashAllUnordered(weekdays);
}

/// The user is in a meeting on the named calendar. Empty
/// [calendarId] = any calendar.
@immutable
final class ConditionCalendarBusy extends Condition {
  const ConditionCalendarBusy({required this.calendarId});

  /// Empty string means "any calendar".
  final String calendarId;

  @override
  ConditionCalendarBusy validate() => this;

  @override
  bool operator ==(Object other) =>
      other is ConditionCalendarBusy && other.calendarId == calendarId;

  @override
  int get hashCode => calendarId.hashCode;
}

/// Battery in the `[low, high]` percent range (both
/// inclusive). `null` bound = open-ended.
@immutable
final class ConditionBatteryRange extends Condition {
  const ConditionBatteryRange({this.low, this.high});

  final int? low;
  final int? high;

  @override
  ConditionBatteryRange validate() {
    final lo = low;
    final hi = high;
    if (lo != null && (lo < 0 || lo > 100)) {
      throw ConditionBatteryRangeInvalidBound('low', lo);
    }
    if (hi != null && (hi < 0 || hi > 100)) {
      throw ConditionBatteryRangeInvalidBound('high', hi);
    }
    if (lo != null && hi != null && lo > hi) {
      throw const ConditionBatteryRangeInverted();
    }
    return this;
  }

  @override
  bool operator ==(Object other) =>
      other is ConditionBatteryRange && other.low == low && other.high == high;

  @override
  int get hashCode => Object.hash(low, high);
}

/// Device's silent / DnD mode matches [mode]. See
/// `SilentMode` in `lib/triggers/trigger.dart`.
@immutable
final class ConditionSilentMode extends Condition {
  const ConditionSilentMode(this.mode);

  final SilentMode mode;

  @override
  ConditionSilentMode validate() => this;

  @override
  bool operator ==(Object other) =>
      other is ConditionSilentMode && other.mode == mode;

  @override
  int get hashCode => mode.hashCode;
}

// ---------------------------------------------------------------------------
// Validation exceptions.
// ---------------------------------------------------------------------------

@immutable
sealed class ConditionValidationException implements Exception {
  const ConditionValidationException(this.message);
  final String message;

  @override
  String toString() => 'ConditionValidationException: $message';
}

final class ConditionTimeWindowInvalidHour
    extends ConditionValidationException {
  const ConditionTimeWindowInvalidHour(this.field, this.value)
    : super('Hour must be in 0..23.');
  final String field;
  final int value;
}

final class ConditionTimeWindowInvalidMinute
    extends ConditionValidationException {
  const ConditionTimeWindowInvalidMinute(this.field, this.value)
    : super('Minute must be in 0..59.');
  final String field;
  final int value;
}

final class ConditionDayOfWeekEmpty extends ConditionValidationException {
  const ConditionDayOfWeekEmpty() : super('weekdays must be non-empty.');
}

final class ConditionDayOfWeekInvalidWeekday
    extends ConditionValidationException {
  const ConditionDayOfWeekInvalidWeekday(this.value)
    : super('Weekday must be in 1..7 (Mon..Sun).');
  final int value;
}

final class ConditionBatteryRangeInvalidBound
    extends ConditionValidationException {
  const ConditionBatteryRangeInvalidBound(this.field, this.value)
    : super('Bound must be in 0..100.');
  final String field;
  final int value;
}

final class ConditionBatteryRangeInverted extends ConditionValidationException {
  const ConditionBatteryRangeInverted() : super('low must be <= high.');
}

// `setEquals` is in `package:collection` but we can keep the
// import surface narrow with a tiny local helper to avoid
// pulling in `package:collection` (the rest of the app does
// not depend on it).
bool setEquals<T>(Set<T> a, Set<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final v in a) {
    if (!b.contains(v)) return false;
  }
  return true;
}
