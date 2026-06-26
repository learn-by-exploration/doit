// Unit tests for `home_tile_sparkline.dart` — the pure-Dart
// `sparklineForDo` helper that backs the in-app home tile's
// 7-day streak history sparkline (v1.4e / Phase 32 / SYS-119
// / ADR-049 / WF-046).
//
// The helper's only job is to build the 7-day row of dots:
// for each of the last 7 local-midnights, emit
// `SparklineDot.filled(day, source)` if a completion row
// exists for that day, `SparklineDot.empty(day)` if not, or
// `SparklineDot.future(day)` if the day is in the future of
// `asOf`.
//
// Because the helper imports the singleton
// `CompletionLogService` (which holds a Drift DB), the
// tests use a hand-rolled fake that records the last
// `listForHabit` call AND seeds the matching rows. This
// avoids mockito (not in pubspec dev_dependencies) AND
// avoids spinning up a real database for a pure helper.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/screens/home_tile_sparkline.dart';
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/db/schema.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCompletionLog implements CompletionLogService {
  // Pre-seeded completions for the helper's `listForHabit`
  // call. The helper uses this to find the matching day
  // rows.
  final List<CompletionRow> seeded;
  _FakeCompletionLog({this.seeded = const <CompletionRow>[]});

  @override
  Future<List<CompletionRow>> listForHabit(String habitId) async {
    return seeded.where((r) => r.habitId == habitId).toList(growable: false);
  }

  // The helper does not call these — the methods exist
  // only to satisfy the `implements CompletionLogService`
  // contract.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Do _do({String id = 'h1'}) {
  return DoFixed(
    id: id,
    name: 'Stretch',
    proofMode: const SoftProof(),
    createdAt: DateTime(2026, 5, 17),
    restDaysPerMonth: 2,
    weekdays: const {1, 2, 3, 4, 5, 6, 7},
    time: const DoTime(9, 0),
  );
}

CompletionRow _row({
  required String id,
  required String habitId,
  required DateTime day,
  String source = 'manual',
}) {
  return CompletionRow(
    id: id,
    habitId: habitId,
    dayMillis: DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
    completedAtMillis: day.millisecondsSinceEpoch,
    source: source,
    proofModeAtTime: 'soft',
  );
}

void main() {
  group('sparklineForDo', () {
    test(
      'returns 7 dots in oldest-first order with today as the last dot',
      () async {
        final today = DateTime(2026, 6, 13, 14, 30);
        final fake = _FakeCompletionLog();
        final dots = await sparklineForDo(
          activeDo: _do(),
          asOf: today,
          completionLog: fake,
        );
        expect(dots, hasLength(7));
        // First dot is today - 6 days.
        expect(
          dots.first.day,
          DateTime(
            today.year,
            today.month,
            today.day,
          ).subtract(const Duration(days: 6)),
        );
        // Last dot is today (local-midnight at asOf).
        expect(dots.last.day, DateTime(today.year, today.month, today.day));
        // Days are strictly increasing.
        for (var i = 1; i < dots.length; i++) {
          expect(dots[i].day.isAfter(dots[i - 1].day), isTrue);
        }
      },
    );

    test('marks a dot as SparklineDot.filled(day, source) when a manual '
        'row exists for that day\'s local-midnight', () async {
      final today = DateTime(2026, 6, 13, 14, 30);
      final dayMinus2 = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 2));
      final fake = _FakeCompletionLog(
        seeded: [_row(id: 'c1', habitId: 'h1', day: dayMinus2)],
      );
      final dots = await sparklineForDo(
        activeDo: _do(),
        asOf: today,
        completionLog: fake,
      );
      // Day -2 is the 5th dot (index 4) — days 0..3 are
      // empty, day 4 is filled, days 5..6 are empty.
      expect(dots[4], isA<SparklineDotFilled>());
      expect((dots[4] as SparklineDotFilled).source, 'manual');
      expect(dots[4].day, dayMinus2);
      // Surrounding dots are empty.
      expect(dots[3], isA<SparklineDotEmpty>());
      expect(dots[5], isA<SparklineDotEmpty>());
    });

    test('marks a dot as SparklineDot.filled(day, source) when a '
        'rest_day row exists for that day\'s local-midnight', () async {
      final today = DateTime(2026, 6, 13, 14, 30);
      final dayMinus3 = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 3));
      final fake = _FakeCompletionLog(
        seeded: [
          _row(id: 'c1', habitId: 'h1', day: dayMinus3, source: 'rest_day'),
        ],
      );
      final dots = await sparklineForDo(
        activeDo: _do(),
        asOf: today,
        completionLog: fake,
      );
      // Day -3 is the 4th dot (index 3).
      expect(dots[3], isA<SparklineDotFilled>());
      expect((dots[3] as SparklineDotFilled).source, 'rest_day');
    });

    test('returns SparklineDot.empty for days with no rows', () async {
      final today = DateTime(2026, 6, 13, 14, 30);
      final fake = _FakeCompletionLog();
      final dots = await sparklineForDo(
        activeDo: _do(),
        asOf: today,
        completionLog: fake,
      );
      expect(dots.every((d) => d is SparklineDotEmpty), isTrue);
    });

    test('emits exactly one dot per day even when multiple rows exist for '
        'the same day', () async {
      final today = DateTime(2026, 6, 13, 14, 30);
      final dayMinus1 = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 1));
      // Two rows for the same day with different
      // completedAtMillis but identical dayMillis. The
      // helper matches by day only (local-midnight
      // convention).
      final fake = _FakeCompletionLog(
        seeded: [
          _row(
            id: 'manual-id',
            habitId: 'h1',
            day: dayMinus1.add(const Duration(hours: 8)),
          ),
          _row(
            id: 'rest-id',
            habitId: 'h1',
            day: dayMinus1.add(const Duration(hours: 20)),
            source: 'rest_day',
          ),
        ],
      );
      final dots = await sparklineForDo(
        activeDo: _do(),
        asOf: today,
        completionLog: fake,
      );
      expect(dots, hasLength(7));
      // Day -1 is the 6th dot (index 5). It should be
      // filled — the helper picks the first matching row
      // in `rowDays` iteration order, which is the manual
      // row (added first to the fake's seeded list).
      expect(dots[5], isA<SparklineDotFilled>());
      expect((dots[5] as SparklineDotFilled).source, 'manual');
      // No other day is filled.
      final filledCount = dots.whereType<SparklineDotFilled>().length;
      expect(filledCount, 1);
    });

    test('does NOT match rows from outside the 7-day window', () async {
      final today = DateTime(2026, 6, 13, 14, 30);
      // A row 8 days ago is OUTSIDE the 7-day window.
      final dayMinus8 = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 8));
      final fake = _FakeCompletionLog(
        seeded: [_row(id: 'c1', habitId: 'h1', day: dayMinus8)],
      );
      final dots = await sparklineForDo(
        activeDo: _do(),
        asOf: today,
        completionLog: fake,
      );
      // All 7 dots are empty — the day-8 row is outside
      // the window.
      expect(dots.every((d) => d is SparklineDotEmpty), isTrue);
    });

    test('returns dots in chronological order with monotonically increasing '
        'day values', () async {
      final today = DateTime(2026, 6, 13, 14, 30);
      final fake = _FakeCompletionLog();
      final dots = await sparklineForDo(
        activeDo: _do(),
        asOf: today,
        completionLog: fake,
      );
      for (var i = 1; i < dots.length; i++) {
        expect(
          dots[i].day.difference(dots[i - 1].day),
          const Duration(days: 1),
        );
      }
    });

    test('extendedSparklineForDo with days: 14 returns 14 dots with today as '
        'the last dot (v1.4i / SYS-123)', () async {
      final today = DateTime(2026, 6, 13, 14, 30);
      final fake = _FakeCompletionLog();
      final dots = await extendedSparklineForDo(
        activeDo: _do(),
        asOf: today,
        completionLog: fake,
      );
      expect(dots, hasLength(14));
      // First dot is today - 13 days.
      expect(
        dots.first.day,
        DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(const Duration(days: 13)),
      );
      // Last dot is today (local-midnight at asOf).
      expect(dots.last.day, DateTime(today.year, today.month, today.day));
    });

    test('extendedSparklineForDo defaults to 14 days when no window arg is '
        'passed (v1.4i / SYS-123)', () async {
      final today = DateTime(2026, 6, 13, 14, 30);
      final fake = _FakeCompletionLog();
      final dots = await extendedSparklineForDo(
        activeDo: _do(),
        asOf: today,
        completionLog: fake,
      );
      expect(dots, hasLength(14));
    });

    test(
      'extendedSparklineForDo honors an arbitrary window (v1.4i / SYS-123)',
      () async {
        final today = DateTime(2026, 6, 13, 14, 30);
        final fake = _FakeCompletionLog();
        final dots30 = await extendedSparklineForDo(
          activeDo: _do(),
          asOf: today,
          completionLog: fake,
          days: 30,
        );
        expect(dots30, hasLength(30));
        final dots3 = await extendedSparklineForDo(
          activeDo: _do(),
          asOf: today,
          completionLog: fake,
          days: 3,
        );
        expect(dots3, hasLength(3));
        expect(dots3.last.day, DateTime(today.year, today.month, today.day));
      },
    );

    test(
      'extendedSparklineForDo preserves the source tag on filled dots '
      '(v1.4i / SYS-123) — the widget uses the tag to pick the color',
      () async {
        final today = DateTime(2026, 6, 13, 14, 30);
        final dayMinus2 = DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(const Duration(days: 2));
        final dayMinus7 = DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(const Duration(days: 7));
        final fake = _FakeCompletionLog(
          seeded: [
            _row(id: 'c1', habitId: 'h1', day: dayMinus2, source: 'rest_day'),
            _row(id: 'c2', habitId: 'h1', day: dayMinus7),
          ],
        );
        final dots = await extendedSparklineForDo(
          activeDo: _do(),
          asOf: today,
          completionLog: fake,
        );
        // Day -2 is the 12th dot (index 11) in a 14-day
        // window — rest day.
        final dMinus2 = dots[11];
        expect(dMinus2, isA<SparklineDotFilled>());
        expect((dMinus2 as SparklineDotFilled).source, 'rest_day');
        // Day -7 is the 7th dot (index 6) — manual.
        final dMinus7 = dots[6];
        expect(dMinus7, isA<SparklineDotFilled>());
        expect((dMinus7 as SparklineDotFilled).source, 'manual');
      },
    );

    test('SparklineDot value-equality holds for all three factories', () {
      // Filled equality: same day + same source → equal.
      final today = DateTime(2026, 6, 13);
      final a = SparklineDot.filled(day: today, source: 'manual');
      final b = SparklineDot.filled(day: today, source: 'manual');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);

      // Different source → not equal.
      final c = SparklineDot.filled(day: today, source: 'rest_day');
      expect(a == c, isFalse);

      // Empty equality: same day → equal.
      final e1 = SparklineDot.empty(day: today);
      final e2 = SparklineDot.empty(day: today);
      expect(e1, equals(e2));
      expect(e1.hashCode, e2.hashCode);

      // Future equality: same day → equal.
      final f1 = SparklineDot.future(day: today);
      final f2 = SparklineDot.future(day: today);
      expect(f1, equals(f2));

      // Different variants → not equal.
      expect(a == e1, isFalse);
      expect(e1 == f1, isFalse);
      expect(a == f1, isFalse);

      // Different day → not equal.
      final tomorrow = today.add(const Duration(days: 1));
      final a2 = SparklineDot.filled(day: tomorrow, source: 'manual');
      expect(a == a2, isFalse);
    });
  });
}
