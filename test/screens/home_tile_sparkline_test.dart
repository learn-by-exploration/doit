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
//
// Coverage:
//   - v1.4e baseline (Phase 32): 7-day window, source-tag
//     preservation, multiple-rows-same-day tiebreak, outside-
//     window skip, chronological-order monotonicity.
//   - v1.4i extension (SYS-123): 14-day `extendedSparklineForDo`
//     with arbitrary `days:` arg.
//   - v1.4-stab-G (SYS-134): BUG-019 single-completion render.
//   - v1.6-θ (SYS-153 / ADR-084 / WF-081): +4 cross-cutting
//     invariants — `'auto'` source tag preservation, 14-day
//     boundary at day-15, determinism across two consecutive
//     calls, `SparklineDotFilled.toString` debug representation.

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

    // ---- v1.6-θ / SYS-153 / ADR-084 / WF-081 ----
    // Four additional coverage tests targeting the helper's
    // cross-cutting invariants and the boundary cases that the
    // v1.4-stab-G baseline (13 tests) did not pin.
    test('SparklineDotFilled preserves non-manual source tags '
        '(v1.6-θ) — the widget branches on the tag for color', () async {
      // Arrange — a day with a `'auto'` source (e.g., a future
      // `trigger` automation resolving the do). The v1.4e
      // baseline covers `'manual'` + `'rest_day'`; v1.6-θ
      // extends the pin to any source tag passed through the
      // helper.
      final today = DateTime(2026, 6, 13, 14, 30);
      final dayMinus1 = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 1));
      final fake = _FakeCompletionLog(
        seeded: [
          _row(id: 'c-auto', habitId: 'h1', day: dayMinus1, source: 'auto'),
        ],
      );

      // Act.
      final dots = await sparklineForDo(
        activeDo: _do(),
        asOf: today,
        completionLog: fake,
      );

      // Assert — day -1 is filled and the source is preserved
      // verbatim. The widget renders this as a distinct color
      // per SYS-123.
      expect(dots[5], isA<SparklineDotFilled>());
      expect((dots[5] as SparklineDotFilled).source, 'auto');
    });

    test('extendedSparklineForDo(days: 14) ignores a row 15 days ago '
        '(boundary at day-15 — v1.6-θ)', () async {
      // Arrange — a row 15 days old is OUTSIDE the 14-day
      // window; the helper must skip it. (The v1.4e baseline
      // pins the 7-day boundary; this pins the 14-day one.)
      final today = DateTime(2026, 6, 13, 14, 30);
      final dayMinus15 = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 15));
      final fake = _FakeCompletionLog(
        seeded: [_row(id: 'c-old', habitId: 'h1', day: dayMinus15)],
      );

      // Act.
      final dots = await extendedSparklineForDo(
        activeDo: _do(),
        asOf: today,
        completionLog: fake,
      );

      // Assert — all 14 dots are empty; the day-15 row is
      // outside the window.
      expect(dots, hasLength(14));
      expect(dots.every((d) => d is SparklineDotEmpty), isTrue);
    });

    test('extendedSparklineForDo is deterministic across two consecutive '
        'calls with the same args (idempotency — v1.6-θ)', () async {
      // Arrange — the helper is a `Future` over the
      // `completionLog.listForHabit` call, so two calls must
      // produce structurally equal dot lists (a regression
      // here would surface as a flickering home tile).
      final today = DateTime(2026, 6, 13, 14, 30);
      final dayMinus3 = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 3));
      final fake = _FakeCompletionLog(
        seeded: [_row(id: 'c-1', habitId: 'h1', day: dayMinus3)],
      );

      // Act — call twice with identical args.
      final first = await extendedSparklineForDo(
        activeDo: _do(),
        asOf: today,
        completionLog: fake,
      );
      final second = await extendedSparklineForDo(
        activeDo: _do(),
        asOf: today,
        completionLog: fake,
      );

      // Assert — element-by-element equality (uses the
      // sealed `SparklineDot.==` defined per factory).
      expect(first, equals(second));
      expect(first.length, second.length);
      for (var i = 0; i < first.length; i++) {
        expect(first[i], equals(second[i]));
        expect(first[i].day, second[i].day);
      }
    });

    test('SparklineDotFilled.toString includes day + source for debugging '
        '(debug-representation pin — v1.6-θ)', () async {
      // Arrange — the `toString` is the primary debugging
      // surface for the home tile (logged in widget asserts
      // and the V-Model reviewer's crash dumps). A regression
      // that strips either field would make crash dumps
      // useless.
      final today = DateTime(2026, 6, 13);
      final dot = SparklineDot.filled(day: today, source: 'rest_day');

      // Act.
      final rendered = dot.toString();

      // Assert — both day and source are present in the
      // debug string. The format is implementation-defined
      // (per the v1.4e `toString` override), but the two
      // fields MUST appear so a debugger can read them off
      // the log line.
      expect(rendered, contains(today.toString()));
      expect(rendered, contains('rest_day'));
    });

    test('BUG-019: sparkline renders empty placeholder when only 1 '
        'completion exists — avoids a single-point over-stretched line '
        '(v1.4-stab-G / Phase 47 / SYS-134)', () async {
      // The BUG-019 invariant: a single completion row would
      // otherwise stretch to a misleading single dot at the
      // right edge of the chart. The helper still emits 7 dots
      // (the 7-day window), but the empty-state copy visual
      // is what guards against the over-stretched line.
      //
      // We pin the behavior at the helper level: with only
      // 1 completion (today), the helper returns 7 dots
      // where 6 of them are `empty` (no completion row on
      // those days) and 1 is `filled` for today. The widget
      // rendering consumes this and shows the empty-state
      // placeholder when 6+ are empty (the v1.4-stab-G pin).
      final asOf = DateTime(2026, 6, 13, 9);
      final doFixture = DoFixed(
        id: 'h-bug-19',
        name: 'Single completion',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 1, 15),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      );
      final fake = _FakeCompletionLog(
        seeded: [
          _row(
            id: 'c-bug-19',
            habitId: 'h-bug-19',
            day: asOf,
            source: 'rest_day',
          ),
        ],
      );
      final dots = await sparklineForDo(
        activeDo: doFixture,
        asOf: asOf,
        completionLog: fake,
      );
      expect(dots, hasLength(7));
      final filledCount = dots.whereType<SparklineDotFilled>().length;
      expect(filledCount, 1);
      // The today dot is the only filled one. The other 6 are
      // either empty or future. We assert at most 1 filled —
      // the BUG-019 invariant. (The widget layer's empty-state
      // placeholder is keyed off this count in home.dart.)
      expect(filledCount, lessThanOrEqualTo(1));
    });
  });
}
