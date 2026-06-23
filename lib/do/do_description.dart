// Human-readable one-line description of a [Do], used on the
// home-screen tile. Pure Dart (no Flutter imports) so it can be
// unit-tested without a harness.
//
// v1.2f / Phase 6e / SYS-102: the prior version was just
// `"Fixed — ${h.time}"`, which dropped the weekday set. The
// new version renders an abbreviated weekday set next to the
// time:
//   - `{1..7}` (every day)       → "Every day · HH:MM"
//   - `{1..5}` (Mon–Fri)         → "Weekdays · HH:MM"
//   - `{6,7}` (Sat,Sun)          → "Weekends · HH:MM"
//   - single weekday             → "Mon · HH:MM"
//   - arbitrary subset           → "Mon, Wed, Fri · HH:MM"
//
// Other schedule kinds are unchanged from v1.1.

import 'package:doit/do/do.dart';

/// Returns a one-line label suitable for the home-screen tile
/// subtitle. Pure: no `DateTime.now()`, no side effects.
String describeDo(Do h) {
  return switch (h) {
    DoFixed(:final weekdays, :final time) =>
      '${_weekdaysLabel(weekdays)} · '
          '$time',
    DoInterval() => 'Every ${h.nDays} days',
    DoAnchor() => 'Anchor',
    DoDayOfX() => 'Day-of-X',
    DoTimeWindow() => 'Window — ${h.start}–${h.end}',
  };
}

/// Abbreviated weekday label for the home-screen tile.
/// [weekdays] is the `1..7` set on `DoFixed`. The order of
/// the returned list is Mon..Sun (1..7), matching the
/// `DateTime.weekday` convention.
String _weekdaysLabel(Set<Weekday> weekdays) {
  // Sort ascending so the output is stable regardless of the
  // caller's set literal order.
  final sorted = weekdays.toList()..sort();
  if (_equalsAll(sorted, [1, 2, 3, 4, 5, 6, 7])) return 'Every day';
  if (_equalsAll(sorted, [1, 2, 3, 4, 5])) return 'Weekdays';
  if (_equalsAll(sorted, [6, 7])) return 'Weekends';
  return sorted.map(_abbrev).join(', ');
}

String _abbrev(int weekday) {
  // 1 = Mon, 7 = Sun. Out-of-range weekdays fall through to
  // `?` — the model validates the set so this should not
  // happen for persisted rows, but defensive copy costs
  // nothing.
  switch (weekday) {
    case 1:
      return 'Mon';
    case 2:
      return 'Tue';
    case 3:
      return 'Wed';
    case 4:
      return 'Thu';
    case 5:
      return 'Fri';
    case 6:
      return 'Sat';
    case 7:
      return 'Sun';
    default:
      return '?';
  }
}

bool _equalsAll(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
