// Person cadence — sealed hierarchy.
//
// A cadence is the answer to "how often should I reach out
// to this person?" It is the schedule for a Person, not a
// Do — the app's domain separation keeps the two
// schedule engines clean.
//
// Layer rules (per .claude/rules/lib-people.md):
//   - No Flutter imports.
//   - `nextOccurrence(from)` is pure: same input → same
//     output. Caller passes the reference time.

import 'package:meta/meta.dart';

/// A sealed cadence. The 4 v0.1 shapes are exhaustive; add a
/// v0.2 shape by adding a new subclass.
@immutable
sealed class PersonCadence {
  const PersonCadence();

  /// Pure: returns the next occurrence strictly after [from].
  /// `null` means "no future occurrence" (e.g., an Every-N-Days
  /// with `nDays < 1`); the service layer treats null as
  /// "never schedule".
  DateTime? nextOccurrence(DateTime from);
}

/// Every N days. The cadence is anchored to the person's
/// creation date by the service layer; here we treat [from]
/// as the reference, returning `from + nDays` (whole days).
final class EveryNDays extends PersonCadence {
  const EveryNDays(this.nDays);
  final int nDays;

  @override
  DateTime? nextOccurrence(DateTime from) {
    if (nDays < 1) return null;
    final l = from.toLocal();
    return DateTime(l.year, l.month, l.day).add(Duration(days: nDays));
  }
}

/// Weekly on a specific weekday (1 = Monday .. 7 = Sunday).
final class WeeklyOn extends PersonCadence {
  const WeeklyOn(this.weekday);
  final int weekday;

  @override
  DateTime? nextOccurrence(DateTime from) {
    if (weekday < 1 || weekday > 7) return null;
    final l = from.toLocal();
    for (var offset = 1; offset <= 7; offset++) {
      final next = l.add(Duration(days: offset));
      if (next.weekday == weekday) {
        return DateTime(next.year, next.month, next.day);
      }
    }
    return null;
  }
}

/// Monthly on a specific day of the month (1..31). If the
/// month has fewer days, the last day of the month is used.
final class MonthlyOn extends PersonCadence {
  const MonthlyOn(this.dayOfMonth);
  final int dayOfMonth;

  @override
  DateTime? nextOccurrence(DateTime from) {
    if (dayOfMonth < 1 || dayOfMonth > 31) return null;
    final l = from.toLocal();
    final daysInThisMonth = DateTime(l.year, l.month + 1, 0).day;
    final domThis = dayOfMonth <= daysInThisMonth
        ? dayOfMonth
        : daysInThisMonth;
    final candidateThis = DateTime(l.year, l.month, domThis);
    if (candidateThis.isAfter(l)) return candidateThis;
    final nextMonth = l.month == 12
        ? DateTime(l.year + 1)
        : DateTime(l.year, l.month + 1);
    final daysInNextMonth = DateTime(
      nextMonth.year,
      nextMonth.month + 1,
      0,
    ).day;
    final domNext = dayOfMonth <= daysInNextMonth
        ? dayOfMonth
        : daysInNextMonth;
    return DateTime(nextMonth.year, nextMonth.month, domNext);
  }
}

/// Yearly on a specific (month, day). February 29 rolls to
/// February 28 in non-leap years.
final class YearlyOn extends PersonCadence {
  const YearlyOn(this.month, this.day);
  final int month;
  final int day;

  @override
  DateTime? nextOccurrence(DateTime from) {
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    final l = from.toLocal();
    DateTime candidate(int y) {
      final daysInMonth = DateTime(y, month + 1, 0).day;
      final d = day <= daysInMonth ? day : daysInMonth;
      return DateTime(y, month, d);
    }

    final thisYear = candidate(l.year);
    if (thisYear.isAfter(l)) return thisYear;
    return candidate(l.year + 1);
  }
}
