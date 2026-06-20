// Do model — sealed hierarchy of 5 schedule types.
//
// A do is the source of truth for "what does the user want to
// do, and when". The model is immutable; mutations go through
// [Do.copyWith] which returns a new instance.
//
// v1.0 reframe (Phase A): renamed from `Do` to `Do`. The DB
// table stays `Habits` and the column names stay the same (no
// schema migration). Sealed subclasses were `DoFixed`,
// `DoInterval`, `DoAnchor`, `DoDayOfX`,
// `DoTimeWindow` — now `DoFixed`, `DoInterval`, `DoAnchor`,
// `DoDayOfX`, `DoTimeWindow`.
//
// Layer rules (per .claude/rules/lib-do.md): no Flutter
// imports. TimeOfDay is `(hour, minute)` for purity.
//
// v0.2 additions (SYS-042..SYS-047) carried over verbatim:
//   - category (DoCategory)
//   - colorSeed (int, 0..7)
//   - iconName (String?, one of DoIcons.keys)
//   - pausedUntil (DateTime?)
//   - a fifth schedule type, DoTimeWindow (defined inline),
//     which is the foundation for WF-019 (v0.2d).

import 'package:doit/do/category.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/missions/chain.dart';
import 'package:meta/meta.dart';

export 'package:doit/do/category.dart'
    show DoCategory, CategoryPalette, DoIcons;
export 'package:doit/missions/mission.dart'
    show
        Mission,
        ShakeMission,
        TypeMission,
        HoldMission,
        MathMission,
        MathDifficulty,
        MemoryMission;

/// Stable, opaque do identifier. Wrapping the String in a typed
/// value-class would be tempting, but v0.1 persists dos as plain
/// rows in Drift; a typed wrapper adds churn without payoff.
/// Keep it as a `String` alias.
typedef DoId = String;

/// Hour + minute in 24-hour clock. Pure-Dart replacement for
/// `package:flutter/material.dart`'s `TimeOfDay` so the model
/// can be unit-tested without a Flutter harness.
@immutable
class DoTime {
  const DoTime(this.hour, this.minute);
  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is DoTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, "0")}:${minute.toString().padLeft(2, "0")}';
}

/// Thrown by [Do.validate] when the immutable invariants are
/// violated.
@immutable
sealed class DoValidationException implements Exception {
  const DoValidationException(this.message);
  final String message;

  @override
  String toString() => 'DoValidationException: $message';
}

final class DoNameEmpty extends DoValidationException {
  const DoNameEmpty() : super('Do name must be non-empty (trimmed).');
}

final class DoInvalidTime extends DoValidationException {
  const DoInvalidTime(this.hour, this.minute)
    : super('Time of day out of range.');
  final int hour;
  final int minute;
}

final class DoInvalidInterval extends DoValidationException {
  const DoInvalidInterval() : super('Interval must be >= 1 day.');
}

final class DoNoWeekdaysSelected extends DoValidationException {
  const DoNoWeekdaysSelected()
    : super('Fixed dos must have at least one weekday.');
}

final class DoInvalidDayOfMonth extends DoValidationException {
  const DoInvalidDayOfMonth(this.day) : super('Day-of-month must be in 1..31.');
  final int day;
}

final class DoInvalidNthWeekday extends DoValidationException {
  const DoInvalidNthWeekday(this.nth) : super('Nth weekday must be in 1..5.');
  final int nth;
}

final class DoInvalidWeekday extends DoValidationException {
  const DoInvalidWeekday(this.weekday)
    : super('Weekday must be in 1..7 (Mon..Sun).');
  final int weekday;
}

final class DoInvalidRestDays extends DoValidationException {
  const DoInvalidRestDays(this.value) : super('restDaysPerMonth must be >= 0.');
  final int value;
}

final class DoDayOfXMismatch extends DoValidationException {
  const DoDayOfXMismatch()
    : super(
        'DayOfX dos must specify either a day-of-month '
        'or a (nth, weekday) pair.',
      );
}

final class DoAnchorSelfReference extends DoValidationException {
  const DoAnchorSelfReference()
    : super('Anchor dos cannot reference themselves.');
}

final class DoInvalidColorSeed extends DoValidationException {
  const DoInvalidColorSeed(this.value) : super('colorSeed must be in 0..7.');
  final int value;
}

final class DoInvalidIconName extends DoValidationException {
  const DoInvalidIconName(this.value)
    : super('iconName is not in the 64-icon set.');
  final String value;
}

final class DoInvalidTargetHours extends DoValidationException {
  const DoInvalidTargetHours(this.value)
    : super('targetHours must be in 1..23.');
  final int value;
}

/// Day-of-week. We use Dart's [DateTime.weekday] convention:
/// 1 = Monday .. 7 = Sunday. Typed for readability.
typedef Weekday = int;

/// A sealed do. The 5 schedule types are exhaustive; adding a
/// new schedule means adding a new subclass.
@immutable
sealed class Do {
  const Do({
    required this.id,
    required this.name,
    required this.proofMode,
    required this.createdAt,
    required this.restDaysPerMonth,
    this.category = DoCategory.other,
    this.colorSeed = 0,
    this.iconName,
    this.pausedUntil,
  });

  final DoId id;
  final String name;
  final DoProofMode proofMode;
  final DateTime createdAt;

  /// Default 2 per calendar month. Stored on the do so the
  /// budget survives do moves across devices.
  final int restDaysPerMonth;

  /// v0.2 (SYS-045). Visual category. Drives the default color
  /// and icon; the user can override both.
  final DoCategory category;

  /// v0.2 (SYS-045). 0..7 — the index into `CategoryPalette.swatches`.
  /// 0 means "use the category default".
  final int colorSeed;

  /// v0.2 (SYS-046). One of `DoIcons.keys`, or null (= use the
  /// category default).
  final String? iconName;

  /// v0.2 (SYS-047). When set and in the future, the scheduler
  /// shall not fire reminders for this do. A paused period does
  /// not break the consecutive-run.
  final DateTime? pausedUntil;

  /// Mission chain — non-empty for Strong, empty for Soft /
  /// Auto. Always reflectable: derived from [proofMode].
  MissionChain get missionChain {
    final mode = proofMode;
    if (mode is StrongProof) return mode.chain;
    return MissionChain.empty;
  }

  /// True iff the do is currently paused (i.e., [pausedUntil]
  /// is in the future relative to [now]). Caller passes the
  /// reference time so the model stays pure.
  bool isPausedAt(DateTime now) {
    final p = pausedUntil;
    return p != null && p.isAfter(now);
  }

  /// Returns a copy with selected fields replaced. Subclasses
  /// override to add their schedule-specific fields, but the
  /// base v0.2 fields ([pausedUntil], [category], [colorSeed],
  /// [iconName]) live on every subclass, so the base signature
  /// includes them and subclasses accept the call via super.
  Do copyWith({
    String? name,
    DoProofMode? proofMode,
    int? restDaysPerMonth,
    DoCategory? category,
    int? colorSeed,
    String? iconName,
    DateTime? pausedUntil,
    bool clearPausedUntil = false,
  });

  /// Pure: same input → same output. Returns the next
  /// occurrence strictly after [from]. If no future occurrence
  /// exists, returns `null` — the caller schedules
  /// `nextOccurrence(from.add(Duration(days: 1)))` instead.
  DateTime? nextOccurrence(DateTime from);

  /// Validates the do's invariants. Throws
  /// [DoValidationException] on the first defect.
  void validate() {
    if (name.trim().isEmpty) {
      throw const DoNameEmpty();
    }
    if (restDaysPerMonth < 0) {
      throw DoInvalidRestDays(restDaysPerMonth);
    }
    if (colorSeed < 0 || colorSeed > 7) {
      throw DoInvalidColorSeed(colorSeed);
    }
    final icon = iconName;
    if (icon != null && !DoIcons.keys.contains(icon)) {
      throw DoInvalidIconName(icon);
    }
    final self = this;
    switch (self) {
      case DoFixed(:final time, :final weekdays):
        _validateTime(time);
        if (weekdays.isEmpty) {
          throw const DoNoWeekdaysSelected();
        }
        for (final wd in weekdays) {
          if (wd < 1 || wd > 7) throw DoInvalidWeekday(wd);
        }
      case DoInterval(:final nDays):
        if (nDays < 1) throw const DoInvalidInterval();
      case DoAnchor(:final targetDoId):
        if (targetDoId == id) throw const DoAnchorSelfReference();
      case DoDayOfX(
        :final nth,
        :final weekday,
        :final dayOfMonth,
        :final referenceDayOfMonth,
      ):
        if (dayOfMonth == null && nth == null) {
          throw const DoDayOfXMismatch();
        }
        if (dayOfMonth != null && (dayOfMonth < 1 || dayOfMonth > 31)) {
          throw DoInvalidDayOfMonth(dayOfMonth);
        }
        if (nth != null && (nth < 1 || nth > 5)) {
          throw DoInvalidNthWeekday(nth);
        }
        if (weekday != null && (weekday < 1 || weekday > 7)) {
          throw DoInvalidWeekday(weekday);
        }
        if (referenceDayOfMonth != null &&
            (referenceDayOfMonth < 1 || referenceDayOfMonth > 31)) {
          throw DoInvalidDayOfMonth(referenceDayOfMonth);
        }
      case DoTimeWindow(
        :final start,
        :final end,
        :final weekdays,
        :final targetHours,
      ):
        _validateTime(start);
        _validateTime(end);
        if (weekdays.isEmpty) {
          throw const DoNoWeekdaysSelected();
        }
        for (final wd in weekdays) {
          if (wd < 1 || wd > 7) throw DoInvalidWeekday(wd);
        }
        if (targetHours != null && (targetHours < 1 || targetHours > 23)) {
          throw DoInvalidTargetHours(targetHours);
        }
    }
    validateProofMode(proofMode);
  }

  static void _validateTime(DoTime t) {
    if (t.hour < 0 || t.hour > 23 || t.minute < 0 || t.minute > 59) {
      throw DoInvalidTime(t.hour, t.minute);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Do) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Fixed schedule: do the do on the given weekdays at [time].
/// At least one weekday must be selected.
@immutable
final class DoFixed extends Do {
  const DoFixed({
    required super.id,
    required super.name,
    required super.proofMode,
    required super.createdAt,
    required super.restDaysPerMonth,
    required this.weekdays,
    required this.time,
    super.category,
    super.colorSeed,
    super.iconName,
    super.pausedUntil,
  });

  /// Set of 1..7 (1 = Monday .. 7 = Sunday). Must be non-empty.
  final Set<Weekday> weekdays;
  final DoTime time;

  @override
  DoFixed copyWith({
    String? name,
    DoProofMode? proofMode,
    int? restDaysPerMonth,
    Set<Weekday>? weekdays,
    DoTime? time,
    DoCategory? category,
    int? colorSeed,
    String? iconName,
    DateTime? pausedUntil,
    bool clearPausedUntil = false,
  }) {
    return DoFixed(
      id: id,
      name: name ?? this.name,
      proofMode: proofMode ?? this.proofMode,
      createdAt: createdAt,
      restDaysPerMonth: restDaysPerMonth ?? this.restDaysPerMonth,
      weekdays: weekdays ?? this.weekdays,
      time: time ?? this.time,
      category: category ?? this.category,
      colorSeed: colorSeed ?? this.colorSeed,
      iconName: iconName ?? this.iconName,
      pausedUntil: clearPausedUntil ? null : (pausedUntil ?? this.pausedUntil),
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
final class DoInterval extends Do {
  const DoInterval({
    required super.id,
    required super.name,
    required super.proofMode,
    required super.createdAt,
    required super.restDaysPerMonth,
    required this.nDays,
    required this.referenceDate,
    super.category,
    super.colorSeed,
    super.iconName,
    super.pausedUntil,
  });

  final int nDays;
  final DateTime referenceDate;

  @override
  DoInterval copyWith({
    String? name,
    DoProofMode? proofMode,
    int? restDaysPerMonth,
    int? nDays,
    DateTime? referenceDate,
    DoCategory? category,
    int? colorSeed,
    String? iconName,
    DateTime? pausedUntil,
    bool clearPausedUntil = false,
  }) {
    return DoInterval(
      id: id,
      name: name ?? this.name,
      proofMode: proofMode ?? this.proofMode,
      createdAt: createdAt,
      restDaysPerMonth: restDaysPerMonth ?? this.restDaysPerMonth,
      nDays: nDays ?? this.nDays,
      referenceDate: referenceDate ?? this.referenceDate,
      category: category ?? this.category,
      colorSeed: colorSeed ?? this.colorSeed,
      iconName: iconName ?? this.iconName,
      pausedUntil: clearPausedUntil ? null : (pausedUntil ?? this.pausedUntil),
    );
  }

  @override
  DateTime? nextOccurrence(DateTime from) {
    final fromLocal = from.toLocal();
    final ref = referenceDate.toLocal();
    final refDay = DateTime(ref.year, ref.month, ref.day);
    // If `from` is strictly before refDay, the next occurrence
    // is refDay itself. If `from` is on refDay (any time of
    // day), the next strictly-after occurrence is refDay +
    // nDays.
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
/// target do.
@immutable
final class DoAnchor extends Do {
  const DoAnchor({
    required super.id,
    required super.name,
    required super.proofMode,
    required super.createdAt,
    required super.restDaysPerMonth,
    required this.targetDoId,
    required this.lastAnchor,
    super.category,
    super.colorSeed,
    super.iconName,
    super.pausedUntil,
  });

  final DoId targetDoId;
  final DateTime? lastAnchor;

  @override
  DoAnchor copyWith({
    String? name,
    DoProofMode? proofMode,
    int? restDaysPerMonth,
    DoId? targetDoId,
    DateTime? lastAnchor,
    bool clearLastAnchor = false,
    DoCategory? category,
    int? colorSeed,
    String? iconName,
    DateTime? pausedUntil,
    bool clearPausedUntil = false,
  }) {
    return DoAnchor(
      id: id,
      name: name ?? this.name,
      proofMode: proofMode ?? this.proofMode,
      createdAt: createdAt,
      restDaysPerMonth: restDaysPerMonth ?? this.restDaysPerMonth,
      targetDoId: targetDoId ?? this.targetDoId,
      lastAnchor: clearLastAnchor ? null : (lastAnchor ?? this.lastAnchor),
      category: category ?? this.category,
      colorSeed: colorSeed ?? this.colorSeed,
      iconName: iconName ?? this.iconName,
      pausedUntil: clearPausedUntil ? null : (pausedUntil ?? this.pausedUntil),
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
final class DoDayOfX extends Do {
  const DoDayOfX({
    required super.id,
    required super.name,
    required super.proofMode,
    required super.createdAt,
    required super.restDaysPerMonth,
    this.dayOfMonth,
    this.nth,
    this.weekday,
    this.referenceDayOfMonth,
    super.category,
    super.colorSeed,
    super.iconName,
    super.pausedUntil,
  }) : assert(
         dayOfMonth != null || nth != null,
         'Specify either dayOfMonth or (nth, weekday).',
       );

  final int? dayOfMonth;
  final int? nth;
  final Weekday? weekday;
  final int? referenceDayOfMonth;

  @override
  DoDayOfX copyWith({
    String? name,
    DoProofMode? proofMode,
    int? restDaysPerMonth,
    int? dayOfMonth,
    int? nth,
    Weekday? weekday,
    int? referenceDayOfMonth,
    DoCategory? category,
    int? colorSeed,
    String? iconName,
    DateTime? pausedUntil,
    bool clearPausedUntil = false,
  }) {
    return DoDayOfX(
      id: id,
      name: name ?? this.name,
      proofMode: proofMode ?? this.proofMode,
      createdAt: createdAt,
      restDaysPerMonth: restDaysPerMonth ?? this.restDaysPerMonth,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      nth: nth ?? this.nth,
      weekday: weekday ?? this.weekday,
      referenceDayOfMonth: referenceDayOfMonth ?? this.referenceDayOfMonth,
      category: category ?? this.category,
      colorSeed: colorSeed ?? this.colorSeed,
      iconName: iconName ?? this.iconName,
      pausedUntil: clearPausedUntil ? null : (pausedUntil ?? this.pausedUntil),
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

/// Schedule: the do is "active" between [start] and [end] on
/// the listed [weekdays]. For fasting, [targetHours] gives the
/// goal duration (e.g., 16); for meals, null.
///
/// v0.2d (WF-019). Declared now (with the rest of the sealed
/// `Do` family) so the hierarchy stays exhaustive; the home
/// screen and DB migration get the actual UI in v0.2d.
@immutable
final class DoTimeWindow extends Do {
  const DoTimeWindow({
    required super.id,
    required super.name,
    required super.proofMode,
    required super.createdAt,
    required super.restDaysPerMonth,
    required this.weekdays,
    required this.start,
    required this.end,
    this.targetHours,
    super.category,
    super.colorSeed,
    super.iconName,
    super.pausedUntil,
  });

  /// Set of 1..7 (1 = Monday .. 7 = Sunday). Must be non-empty.
  final Set<int> weekdays;
  final DoTime start;
  final DoTime end;

  /// Optional target duration in hours (12, 14, 16, 18, 20) for
  /// fasting windows. Null for plain meal windows.
  final int? targetHours;

  @override
  DoTimeWindow copyWith({
    String? name,
    DoProofMode? proofMode,
    int? restDaysPerMonth,
    Set<int>? weekdays,
    DoTime? start,
    DoTime? end,
    int? targetHours,
    bool clearTargetHours = false,
    DoCategory? category,
    int? colorSeed,
    String? iconName,
    DateTime? pausedUntil,
    bool clearPausedUntil = false,
  }) {
    return DoTimeWindow(
      id: id,
      name: name ?? this.name,
      proofMode: proofMode ?? this.proofMode,
      createdAt: createdAt,
      restDaysPerMonth: restDaysPerMonth ?? this.restDaysPerMonth,
      weekdays: weekdays ?? this.weekdays,
      start: start ?? this.start,
      end: end ?? this.end,
      targetHours: clearTargetHours ? null : (targetHours ?? this.targetHours),
      category: category ?? this.category,
      colorSeed: colorSeed ?? this.colorSeed,
      iconName: iconName ?? this.iconName,
      pausedUntil: clearPausedUntil ? null : (pausedUntil ?? this.pausedUntil),
    );
  }

  @override
  DateTime? nextOccurrence(DateTime from) {
    final fromLocal = from.toLocal();
    // The "next occurrence" is the next [start] time on a
    // weekday in [weekdays] strictly after [from]. If [from]
    // is already inside today's window, return [from] (the
    // caller will not re-fire until the window closes; this
    // matches the spec — see WF-019).
    final startToday = DateTime(
      fromLocal.year,
      fromLocal.month,
      fromLocal.day,
      start.hour,
      start.minute,
    );
    final endToday = DateTime(
      fromLocal.year,
      fromLocal.month,
      fromLocal.day,
      end.hour,
      end.minute,
    );
    if (weekdays.contains(fromLocal.weekday) &&
        !fromLocal.isBefore(startToday) &&
        fromLocal.isBefore(endToday)) {
      return fromLocal;
    }
    for (var offset = 0; offset <= 7; offset++) {
      final day = fromLocal.add(Duration(days: offset));
      if (!weekdays.contains(day.weekday)) continue;
      final candidate = DateTime(
        day.year,
        day.month,
        day.day,
        start.hour,
        start.minute,
      );
      if (candidate.isAfter(fromLocal)) return candidate;
    }
    return null;
  }
}
