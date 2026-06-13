// Habit model — sealed hierarchy of 4 schedule types.
//
// A habit is the source of truth for "what does the user want
// to do, and when". The model is immutable; mutations go
// through [Habit.copyWith] which returns a new instance.
//
// Layer rules (per .claude/rules/lib-habits.md): no Flutter
// imports. TimeOfDay is `(hour, minute)` for purity.

import 'package:common_games/habits/proof_mode.dart';
import 'package:common_games/missions/chain.dart';
import 'package:meta/meta.dart';

export 'package:common_games/missions/mission.dart'
    show
        Mission,
        ShakeMission,
        TypeMission,
        HoldMission,
        MathMission,
        MathDifficulty,
        MemoryMission;

/// Stable, opaque habit identifier. Wrapping the String in a
/// typed value-class would be tempting, but v0.1 persists
/// habits as plain rows in Drift; a typed wrapper adds churn
/// without payoff. Keep it as a `String` alias.
typedef HabitId = String;

/// Hour + minute in 24-hour clock. Pure-Dart replacement for
/// `package:flutter/material.dart`'s `TimeOfDay` so the model
/// can be unit-tested without a Flutter harness.
@immutable
class HabitTime {
  const HabitTime(this.hour, this.minute);
  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is HabitTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, "0")}:${minute.toString().padLeft(2, "0")}';
}

/// Thrown by [Habit.validate] when the immutable invariants
/// are violated.
@immutable
sealed class HabitValidationException implements Exception {
  const HabitValidationException(this.message);
  final String message;

  @override
  String toString() => 'HabitValidationException: $message';
}

final class HabitNameEmpty extends HabitValidationException {
  const HabitNameEmpty() : super('Habit name must be non-empty (trimmed).');
}

final class HabitInvalidTime extends HabitValidationException {
  const HabitInvalidTime(this.hour, this.minute)
    : super('Time of day out of range.');
  final int hour;
  final int minute;
}

final class HabitInvalidInterval extends HabitValidationException {
  const HabitInvalidInterval() : super('Interval must be >= 1 day.');
}

final class HabitNoWeekdaysSelected extends HabitValidationException {
  const HabitNoWeekdaysSelected()
    : super('Fixed habits must have at least one weekday.');
}

final class HabitInvalidDayOfMonth extends HabitValidationException {
  const HabitInvalidDayOfMonth(this.day)
    : super('Day-of-month must be in 1..31.');
  final int day;
}

final class HabitInvalidNthWeekday extends HabitValidationException {
  const HabitInvalidNthWeekday(this.nth)
    : super('Nth weekday must be in 1..5.');
  final int nth;
}

final class HabitInvalidWeekday extends HabitValidationException {
  const HabitInvalidWeekday(this.weekday)
    : super('Weekday must be in 1..7 (Mon..Sun).');
  final int weekday;
}

final class HabitInvalidRestDays extends HabitValidationException {
  const HabitInvalidRestDays(this.value)
    : super('restDaysPerMonth must be >= 0.');
  final int value;
}

final class HabitDayOfXMismatch extends HabitValidationException {
  const HabitDayOfXMismatch()
    : super(
        'DayOfX habits must specify either a day-of-month '
        'or a (nth, weekday) pair.',
      );
}

final class HabitAnchorSelfReference extends HabitValidationException {
  const HabitAnchorSelfReference()
    : super('Anchor habits cannot reference themselves.');
}

/// Day-of-week. We use Dart's [DateTime.weekday] convention:
/// 1 = Monday .. 7 = Sunday. Typed for readability.
typedef Weekday = int;

/// A sealed habit. The 4 v0.1 schedule types are exhaustive;
/// adding a v0.2 schedule means adding a new subclass.
@immutable
sealed class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.proofMode,
    required this.createdAt,
    required this.restDaysPerMonth,
  });

  final HabitId id;
  final String name;
  final HabitProofMode proofMode;
  final DateTime createdAt;

  /// Default 2 per calendar month. Stored on the habit so the
  /// budget survives habit moves across devices.
  final int restDaysPerMonth;

  /// Mission chain — non-empty for Strong, empty for Soft /
  /// Auto. Always reflectable: derived from [proofMode].
  MissionChain get missionChain {
    final mode = proofMode;
    if (mode is StrongProof) return mode.chain;
    return MissionChain.empty;
  }

  /// Returns a copy with selected fields replaced. Subclasses
  /// override to add their schedule-specific fields.
  Habit copyWith();

  /// Pure: same input → same output. Returns the next
  /// occurrence strictly after [from]. If no future occurrence
  /// exists, returns `null` — the caller schedules
  /// `nextOccurrence(from.add(Duration(days: 1)))` instead.
  DateTime? nextOccurrence(DateTime from);

  /// Validates the habit's invariants. Throws
  /// [HabitValidationException] on the first defect.
  void validate() {
    if (name.trim().isEmpty) {
      throw const HabitNameEmpty();
    }
    if (restDaysPerMonth < 0) {
      throw HabitInvalidRestDays(restDaysPerMonth);
    }
    final self = this;
    switch (self) {
      case HabitFixed(:final time, :final weekdays):
        _validateTime(time);
        if (weekdays.isEmpty) {
          throw const HabitNoWeekdaysSelected();
        }
        for (final wd in weekdays) {
          if (wd < 1 || wd > 7) throw HabitInvalidWeekday(wd);
        }
      case HabitInterval(:final nDays):
        if (nDays < 1) throw const HabitInvalidInterval();
      case HabitAnchor(:final targetHabitId):
        if (targetHabitId == id) throw const HabitAnchorSelfReference();
      case HabitDayOfX(
        :final nth,
        :final weekday,
        :final dayOfMonth,
        :final referenceDayOfMonth,
      ):
        if (dayOfMonth == null && nth == null) {
          throw const HabitDayOfXMismatch();
        }
        if (dayOfMonth != null && (dayOfMonth < 1 || dayOfMonth > 31)) {
          throw HabitInvalidDayOfMonth(dayOfMonth);
        }
        if (nth != null && (nth < 1 || nth > 5)) {
          throw HabitInvalidNthWeekday(nth);
        }
        if (weekday != null && (weekday < 1 || weekday > 7)) {
          throw HabitInvalidWeekday(weekday);
        }
        if (referenceDayOfMonth != null &&
            (referenceDayOfMonth < 1 || referenceDayOfMonth > 31)) {
          throw HabitInvalidDayOfMonth(referenceDayOfMonth);
        }
    }
    validateProofMode(proofMode);
  }

  static void _validateTime(HabitTime t) {
    if (t.hour < 0 || t.hour > 23 || t.minute < 0 || t.minute > 59) {
      throw HabitInvalidTime(t.hour, t.minute);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Habit) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Fixed schedule: do the habit on the given weekdays at
/// [time]. At least one weekday must be selected.
@immutable
final class HabitFixed extends Habit {
  const HabitFixed({
    required super.id,
    required super.name,
    required super.proofMode,
    required super.createdAt,
    required super.restDaysPerMonth,
    required this.weekdays,
    required this.time,
  });

  /// Set of 1..7 (1 = Monday .. 7 = Sunday). Must be non-empty.
  final Set<Weekday> weekdays;
  final HabitTime time;

  @override
  HabitFixed copyWith({
    String? name,
    HabitProofMode? proofMode,
    int? restDaysPerMonth,
    Set<Weekday>? weekdays,
    HabitTime? time,
  }) {
    return HabitFixed(
      id: id,
      name: name ?? this.name,
      proofMode: proofMode ?? this.proofMode,
      createdAt: createdAt,
      restDaysPerMonth: restDaysPerMonth ?? this.restDaysPerMonth,
      weekdays: weekdays ?? this.weekdays,
      time: time ?? this.time,
    );
  }

  @override
  DateTime? nextOccurrence(DateTime from) {
    final fromLocal = from.toLocal();
    final candidate = DateTime(
      fromLocal.year,
      fromLocal.month,
      fromLocal.day,
      time.hour,
      time.minute,
    );
    if (weekdays.contains(fromLocal.weekday) && candidate.isAfter(fromLocal)) {
      return candidate;
    }
    for (var offset = 1; offset <= 7; offset++) {
      final next = fromLocal.add(Duration(days: offset));
      if (weekdays.contains(next.weekday)) {
        return DateTime(
          next.year,
          next.month,
          next.day,
          time.hour,
          time.minute,
        );
      }
    }
    return null;
  }
}

/// Interval schedule: every [nDays] days, starting from
/// [referenceDate] (inclusive). Intervals align on whole
/// calendar days — "every 3 days" means refDay, refDay+3,
/// refDay+6, ...
@immutable
final class HabitInterval extends Habit {
  const HabitInterval({
    required super.id,
    required super.name,
    required super.proofMode,
    required super.createdAt,
    required super.restDaysPerMonth,
    required this.nDays,
    required this.referenceDate,
  });

  final int nDays;
  final DateTime referenceDate;

  @override
  HabitInterval copyWith({
    String? name,
    HabitProofMode? proofMode,
    int? restDaysPerMonth,
    int? nDays,
    DateTime? referenceDate,
  }) {
    return HabitInterval(
      id: id,
      name: name ?? this.name,
      proofMode: proofMode ?? this.proofMode,
      createdAt: createdAt,
      restDaysPerMonth: restDaysPerMonth ?? this.restDaysPerMonth,
      nDays: nDays ?? this.nDays,
      referenceDate: referenceDate ?? this.referenceDate,
    );
  }

  @override
  DateTime? nextOccurrence(DateTime from) {
    final fromLocal = from.toLocal();
    final ref = referenceDate.toLocal();
    final refDay = DateTime(ref.year, ref.month, ref.day);
    // If `from` is strictly before refDay, the next
    // occurrence is refDay itself. If `from` is on refDay
    // (any time of day), the next strictly-after occurrence
    // is refDay + nDays.
    if (fromLocal.isBefore(refDay)) return refDay;
    if (_isSameDay(fromLocal, refDay)) {
      return refDay.add(Duration(days: nDays));
    }
    final diffDays = fromLocal.difference(refDay).inDays;
    var k = diffDays ~/ nDays;
    var candidate = refDay.add(Duration(days: k * nDays));
    var guard = 0;
    while (!candidate.isAfter(fromLocal)) {
      k++;
      candidate = refDay.add(Duration(days: k * nDays));
      guard++;
      if (guard > 366) return null;
    }
    return candidate;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Anchor schedule: the day after the user completes the
/// target habit.
@immutable
final class HabitAnchor extends Habit {
  const HabitAnchor({
    required super.id,
    required super.name,
    required super.proofMode,
    required super.createdAt,
    required super.restDaysPerMonth,
    required this.targetHabitId,
    required this.lastAnchor,
  });

  final HabitId targetHabitId;
  final DateTime? lastAnchor;

  @override
  HabitAnchor copyWith({
    String? name,
    HabitProofMode? proofMode,
    int? restDaysPerMonth,
    HabitId? targetHabitId,
    DateTime? lastAnchor,
    bool clearLastAnchor = false,
  }) {
    return HabitAnchor(
      id: id,
      name: name ?? this.name,
      proofMode: proofMode ?? this.proofMode,
      createdAt: createdAt,
      restDaysPerMonth: restDaysPerMonth ?? this.restDaysPerMonth,
      targetHabitId: targetHabitId ?? this.targetHabitId,
      lastAnchor: clearLastAnchor ? null : (lastAnchor ?? this.lastAnchor),
    );
  }

  @override
  DateTime? nextOccurrence(DateTime from) {
    final fromLocal = from.toLocal();
    final anchor = lastAnchor?.toLocal();
    final base = anchor ?? fromLocal;
    // The "next occurrence" is the calendar day *after* the
    // anchor, returned as midnight. Comparing calendar days
    // (not time-of-day) is the right call: a user can have a
    // `from` of 08:00 on 2026-06-11 with an anchor of
    // 2026-06-10 — the next occurrence is 2026-06-11 00:00,
    // not 2026-06-12.
    final fromDay = DateTime(fromLocal.year, fromLocal.month, fromLocal.day);
    final tomorrow = DateTime(
      base.year,
      base.month,
      base.day,
    ).add(const Duration(days: 1));
    if (tomorrow.isAfter(fromDay) || _isSameDay(tomorrow, fromDay)) {
      return tomorrow;
    }
    return fromDay.add(const Duration(days: 1));
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Day-of-X schedule. One of:
///  - "the [dayOfMonth] of every month" (e.g., the 1st).
///  - "the [nth] [weekday] of every month" (e.g., 2nd Tuesday).
///  - "the [referenceDayOfMonth] of every month" (alias of
///    dayOfMonth; reserved for future variants).
@immutable
final class HabitDayOfX extends Habit {
  const HabitDayOfX({
    required super.id,
    required super.name,
    required super.proofMode,
    required super.createdAt,
    required super.restDaysPerMonth,
    this.dayOfMonth,
    this.nth,
    this.weekday,
    this.referenceDayOfMonth,
  }) : assert(
         dayOfMonth != null || nth != null,
         'Specify either dayOfMonth or (nth, weekday).',
       );

  final int? dayOfMonth;
  final int? nth;
  final Weekday? weekday;
  final int? referenceDayOfMonth;

  @override
  HabitDayOfX copyWith({
    String? name,
    HabitProofMode? proofMode,
    int? restDaysPerMonth,
    int? dayOfMonth,
    int? nth,
    Weekday? weekday,
    int? referenceDayOfMonth,
  }) {
    return HabitDayOfX(
      id: id,
      name: name ?? this.name,
      proofMode: proofMode ?? this.proofMode,
      createdAt: createdAt,
      restDaysPerMonth: restDaysPerMonth ?? this.restDaysPerMonth,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      nth: nth ?? this.nth,
      weekday: weekday ?? this.weekday,
      referenceDayOfMonth: referenceDayOfMonth ?? this.referenceDayOfMonth,
    );
  }

  @override
  DateTime? nextOccurrence(DateTime from) {
    final fromLocal = from.toLocal();
    final dayOfMonth = this.dayOfMonth;
    final nth = this.nth;
    final weekday = this.weekday;
    final refDom = referenceDayOfMonth;
    if (dayOfMonth != null) return _nextByDayOfMonth(fromLocal, dayOfMonth);
    if (nth != null && weekday != null) {
      return _nextByNthWeekday(fromLocal, nth, weekday);
    }
    if (refDom != null) return _nextByDayOfMonth(fromLocal, refDom);
    return null;
  }

  static DateTime _nextByDayOfMonth(DateTime from, int dom) {
    final daysInThisMonth = _daysInMonth(from.year, from.month);
    if (dom <= daysInThisMonth) {
      final candidate = DateTime(from.year, from.month, dom);
      if (candidate.isAfter(from)) return candidate;
    }
    final nextMonth = from.month == 12
        ? DateTime(from.year + 1)
        : DateTime(from.year, from.month + 1);
    final daysInNextMonth = _daysInMonth(nextMonth.year, nextMonth.month);
    final domNext = dom <= daysInNextMonth ? dom : daysInNextMonth;
    return DateTime(nextMonth.year, nextMonth.month, domNext);
  }

  static DateTime? _nextByNthWeekday(DateTime from, int nth, int weekday) {
    for (var offset = 0; offset < 24; offset++) {
      final ym = _addMonths(DateTime(from.year, from.month), offset);
      final day = _nthWeekdayOfMonth(ym.year, ym.month, nth, weekday);
      if (day != null && day.isAfter(from)) return day;
    }
    return null;
  }

  static DateTime? _nthWeekdayOfMonth(
    int year,
    int month,
    int nth,
    int weekday,
  ) {
    if (nth < 1 || nth > 5) return null;
    final firstOfMonth = DateTime(year, month);
    final firstWd = firstOfMonth.weekday;
    final dayOffset = (weekday - firstWd + 7) % 7;
    final firstWeekdayDay = 1 + dayOffset;
    final dayOfMonth = firstWeekdayDay + (nth - 1) * 7;
    if (dayOfMonth > _daysInMonth(year, month)) return null;
    return DateTime(year, month, dayOfMonth);
  }

  static DateTime _addMonths(DateTime d, int months) {
    final m = d.month - 1 + months;
    final newYear = d.year + m ~/ 12;
    final newMonth = (m % 12) + 1;
    return DateTime(newYear, newMonth);
  }

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}
