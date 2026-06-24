// Stats screen — per-habit + overall streak counts, grouped
// by category.
//
// Per WF-011 (v0.1) + WF-031 (v0.2) + SYS-116 (v1.3a).
// Reads the habit list from `DoRepository` and the per-habit
// completion log from `CompletionLogService`, then runs
// `ConsecutiveCounter.compute` once per habit. The result is
// grouped by `DoCategory` and rendered with the category's
// swatch color in the group header.
//
// v1.3a (Phase 12) adds four new per-habit fields:
//   - `completionsLast30Days`
//   - `completionsPrev30Days`
//   - `completionRate30` (integer percent of the last 30 days
//     on which the habit has at least one completion)
//   - `completionsLast7Days` (length 7, day 0 = today)
//
// The streak calculator's `StreakConfig` is now produced by
// `Do.effectiveStreakConfig` (SYS-113 + SYS-116) so the
// per-do `graceWindowOverride` flows through end-to-end. The
// reference time `asOf` is captured once at the top of
// `_load()` (frozen) — keeps the 30-day and prior-30-day
// windows consistent with the streak calculation, and the
// 7-day buckets aligned to "today".
//
// Layer rules (per .claude/rules/lib-screens.md):
//   - StatefulWidget, FutureBuilder pattern.
//   - Loading → skeleton / spinner. Error → Retry.
//   - Touch targets ≥ 48dp.

import 'package:flutter/material.dart';

import 'package:doit/do/do.dart';
import 'package:doit/do/skip_budget.dart';
import 'package:doit/do/consecutive_counter.dart';
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/widgets/category_chip.dart';

/// A pre-baked row. Computed in the screen's `initState` /
/// `_load()` so the build method is pure.
class _HabitStats {
  const _HabitStats({
    required this.habit,
    required this.snapshot,
    required this.completionsLast30Days,
    required this.completionsPrev30Days,
    required this.completionRate30,
    required this.completionsLast7Days,
  });
  final Do habit;
  final StreakSnapshot snapshot;
  final int completionsLast30Days;
  final int completionsPrev30Days;

  /// Percent of the last 30 local days with at least one
  /// completion. Integer 0..100. Days strictly after `asOf`
  /// are clipped out of the denominator.
  final int completionRate30;

  /// 7-entry list, day 0 = today (per the screen's frozen
  /// `asOf`), day 6 = six days ago. Count of completions per
  /// local-calendar day.
  final List<int> completionsLast7Days;
}

/// A category-bucketed view of `_HabitStats`. The order of
/// the buckets matches `DoCategory.values`.
class _CategoryBucket {
  const _CategoryBucket({required this.category, required this.stats});
  final DoCategory category;
  final List<_HabitStats> stats;
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Future<List<_CategoryBucket>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_CategoryBucket>> _load() async {
    // Frozen reference time for the whole load pass. Using a
    // single value keeps the streak's "is the run still
    // alive at asOf?" check, the 30-day window end, and the
    // 7-day bucket labels all consistent. The previous
    // implementation called DateTime.now() inside the
    // ConsecutiveCounter.compute call which would drift
    // across the per-habit loop if a clock tick landed
    // between iterations.
    final asOf = DateTime.now();
    final habits = await DoRepository.instance.listAll();
    final perHabit = <_HabitStats>[];
    for (final h in habits) {
      final completions = await CompletionLogService.instance.listForHabit(
        h.id,
      );
      final log = completions
          .map(
            (r) => CompletionLogEntry(
              doId: r.habitId,
              date: DateTime.fromMillisecondsSinceEpoch(r.dayMillis),
            ),
          )
          .toList(growable: false);
      // SYS-116: route the StreakConfig through the per-do
      // factory so the `graceWindowOverride` (SYS-113) is
      // honored end-to-end.
      final config = h.effectiveStreakConfig(
        skipBudget: SkipBudget(doId: h.id, monthlyLimit: h.restDaysPerMonth),
      );
      final snap = ConsecutiveCounter.compute(
        log: log,
        config: config,
        asOf: asOf,
      );

      // v1.3a (SYS-116): 30-day completion rate + MoM delta
      // + 7-day bars. Computed via the inclusive day-range
      // query primitive; window is the last 30 / prior 30
      // local days, both clipped at `asOf`.
      final window30 = _last30Window(asOf);
      final last30 = await CompletionLogService.instance.listInRange(
        h.id,
        from: window30.start,
        to: window30.end,
      );
      final prev30 = await CompletionLogService.instance.listInRange(
        h.id,
        from: window30.prevStart,
        to: window30.prevEnd,
      );
      // Distinct local-day count: multiple completions on
      // the same day count as one. listInRange is
      // day-millis-keyed, so a Set of dayMillis is enough.
      final last30Days = last30.map((r) => r.dayMillis).toSet().length;
      final prev30Days = prev30.map((r) => r.dayMillis).toSet().length;
      final completionRate30 = _rate30(
        completed: last30Days,
        asOf: asOf,
        window30: window30,
      );

      // Last-7-day bars: day 0 = today, day 6 = six days
      // ago. Count is total completions (not de-duped) —
      // matches the user-facing definition "I did it N
      // times on this day".
      final bars = await _last7Days(hId: h.id, asOf: asOf);

      perHabit.add(
        _HabitStats(
          habit: h,
          snapshot: snap,
          completionsLast30Days: last30Days,
          completionsPrev30Days: prev30Days,
          completionRate30: completionRate30,
          completionsLast7Days: bars,
        ),
      );
    }
    // Group by category. Order: DoCategory.values order.
    final groups = <DoCategory, List<_HabitStats>>{};
    for (final s in perHabit) {
      groups.putIfAbsent(s.habit.category, () => <_HabitStats>[]).add(s);
    }
    return [
      for (final c in DoCategory.values)
        if (groups.containsKey(c))
          _CategoryBucket(category: c, stats: groups[c]!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: SafeArea(
        child: FutureBuilder<List<_CategoryBucket>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorView(
                onRetry: () {
                  setState(() => _future = _load());
                },
              );
            }
            final buckets = snap.data ?? <_CategoryBucket>[];
            if (buckets.isEmpty) {
              return const _EmptyView();
            }
            return ListView.builder(
              padding: const EdgeInsets.all(Spacing.md),
              itemCount: buckets.length,
              itemBuilder: (context, i) => _CategorySection(bucket: buckets[i]),
            );
          },
        ),
      ),
    );
  }
}

/// Result of [_last30Window]: a closed `[start, end]` window
/// for the last 30 local days, plus a `prevStart..prevEnd`
/// for the 30 days before that.
class _ThirtyDayWindow {
  const _ThirtyDayWindow({
    required this.start,
    required this.end,
    required this.prevStart,
    required this.prevEnd,
  });
  final DateTime start;
  final DateTime end;
  final DateTime prevStart;
  final DateTime prevEnd;
}

/// Computes the last-30-day and prior-30-day windows in local
/// calendar days, both clipped at [asOf] (so the windows
/// don't peek into the future).
_ThirtyDayWindow _last30Window(DateTime asOf) {
  final asOfDay = DateTime(asOf.year, asOf.month, asOf.day);
  // Window is 30 calendar days inclusive of `asOfDay`: start
  // is `asOfDay - 29 days` and end is `asOfDay`. (30 entries
  // total: asOfDay, asOfDay-1, ..., asOfDay-29.)
  final start = asOfDay.subtract(const Duration(days: 29));
  final end = asOfDay;
  final prevEnd = start.subtract(const Duration(days: 1));
  final prevStart = prevEnd.subtract(const Duration(days: 29));
  return _ThirtyDayWindow(
    start: start,
    end: end,
    prevStart: prevStart,
    prevEnd: prevEnd,
  );
}

/// Returns the integer percent (0..100) of the last 30 days
/// (clipped at [asOf]) on which [completed] distinct days
/// appear. The denominator is the number of days in the
/// window up to and including `asOf` (so the future half of
/// a not-yet-ended 30-day window doesn't penalize the rate).
int _rate30({
  required int completed,
  required DateTime asOf,
  required _ThirtyDayWindow window30,
}) {
  // 30 calendar days inclusive: if asOfDay == window30.end
  // and the current time is later than 00:00, the full 30
  // days have passed. If the asOf is in the middle of the
  // day, the day still counts as a valid "miss" slot, so
  // the denominator is the full window length (30). The
  // clipping happens at the upstream `listInRange` (which
  // doesn't include future days).
  const denominator = 30;
  if (denominator == 0) return 0;
  final pct = (completed * 100) ~/ denominator;
  return pct.clamp(0, 100);
}

Future<List<int>> _last7Days({
  required String hId,
  required DateTime asOf,
}) async {
  // 7 days inclusive of today: day 0 = today, day 6 = six
  // days ago.
  final asOfDay = DateTime(asOf.year, asOf.month, asOf.day);
  final start = asOfDay.subtract(const Duration(days: 6));
  final rows = await CompletionLogService.instance.listInRange(
    hId,
    from: start,
    to: asOfDay,
  );
  // Bucket each row into its day offset (0 = today).
  final buckets = List<int>.filled(7, 0);
  for (final r in rows) {
    final dt = DateTime.fromMillisecondsSinceEpoch(r.dayMillis);
    final day = DateTime(dt.year, dt.month, dt.day);
    final offset = asOfDay.difference(day).inDays;
    if (offset < 0 || offset > 6) continue;
    buckets[6 - offset] += 1;
  }
  return buckets;
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.bucket});
  final _CategoryBucket bucket;

  @override
  Widget build(BuildContext context) {
    final visual = CategoryChipResolver.resolveFor(
      category: bucket.category,
      colorSeed: 0,
    );
    final color = Color(visual.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  visual.label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Text(
                  '${bucket.stats.length} '
                  '${bucket.stats.length == 1 ? 'do' : 'dos'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          for (final s in bucket.stats) _StatsCard(stats: s),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final _HabitStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = _momDeltaLabel(stats);
    final bars = _Last7DaysChart(counts: stats.completionsLast7Days);
    return Semantics(
      label:
          '${stats.habit.name}: consecutive done ${stats.snapshot.currentStreak}, '
          'longest ${stats.snapshot.longestStreak}, '
          'last 30 days ${stats.completionsLast30Days} ($delta), '
          'on time ${stats.completionRate30}%',
      child: Card(
        margin: const EdgeInsets.only(bottom: Spacing.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  stats.habit.name,
                  style: theme.textTheme.titleLarge,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: Spacing.xs),
                  child: Text(
                    'Longest: ${stats.snapshot.longestStreak} '
                    '· Today: ${stats.snapshot.currentStreak}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                trailing: Text(
                  '${stats.snapshot.currentStreak}',
                  key: const ValueKey('stats.current_streak'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'Last 30 days: ${stats.completionsLast30Days} '
                '($delta vs prior 30 days)',
                key: const ValueKey('stats.last30'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'On time: ${stats.completionRate30}%',
                key: const ValueKey('stats.rate30'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: Spacing.sm),
              bars,
              const SizedBox(height: Spacing.xs),
            ],
          ),
        ),
      ),
    );
  }

  /// Month-over-month delta label. Returns "+N%" / "-N%" /
  /// "0%" / "new" (no prior data) — never throws divide-by-
  /// zero because we branch on prev30 == 0 first.
  static String _momDeltaLabel(_HabitStats s) {
    final last = s.completionsLast30Days;
    final prev = s.completionsPrev30Days;
    if (prev == 0) {
      return last == 0 ? '0%' : 'new';
    }
    final diff = ((last - prev) * 100) ~/ prev;
    if (diff == 0) return '0%';
    return diff > 0 ? '+$diff%' : '$diff%';
  }
}

/// 7-bar last-7-days chart. Bar heights are proportional to
/// the maximum count in the window (so the tallest bar is
/// always full-height). The bar with the max count is colored
/// [primary]; others use [surfaceContainerHighest].
class _Last7DaysChart extends StatelessWidget {
  const _Last7DaysChart({required this.counts});
  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      key: const ValueKey('stats.last7'),
      height: Sizing.tapMin,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < counts.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Semantics(
                  label:
                      '${counts[i]} completions, ${i == 0 ? "today" : "$i days ago"}',
                  child: Container(
                    height: maxCount == 0
                        ? 2
                        : 4 + (counts[i] / maxCount) * (Sizing.tapMin - 8),
                    decoration: BoxDecoration(
                      color: counts[i] == maxCount && maxCount > 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: Sizing.huge,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'No stats yet.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Add a do to start tracking consecutive runs.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load stats.'),
            const SizedBox(height: Spacing.md),
            FilledButton(
              key: const ValueKey('stats.retry'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
