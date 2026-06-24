// Stats screen — per-habit + overall streak counts, grouped
// by category.
//
// Per WF-011 (v0.1) + WF-031 (v0.2). Reads the habit list
// from `DoRepository` and the per-habit completion log
// from `CompletionLogService`, then runs
// `ConsecutiveCounter.compute` once per habit. The result is
// grouped by `DoCategory` and rendered with the
// category's swatch color in the group header.
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
  const _HabitStats({required this.habit, required this.snapshot});
  final Do habit;
  final StreakSnapshot snapshot;
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
      final snap = ConsecutiveCounter.compute(
        log: log,
        // WF-023 (Phase 11f). Honor the per-do override
        // when set; otherwise fall back to the global
        // 3-hour default from SYS-019.
        config: h.effectiveStreakConfig(
          skipBudget: SkipBudget(doId: h.id, monthlyLimit: h.restDaysPerMonth),
        ),
        asOf: DateTime.now(),
      );
      perHabit.add(_HabitStats(habit: h, snapshot: snap));
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
    return Semantics(
      label:
          '${stats.habit.name}: consecutive done ${stats.snapshot.currentStreak}, '
          'longest ${stats.snapshot.longestStreak}',
      child: Card(
        margin: const EdgeInsets.only(bottom: Spacing.sm),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          title: Text(stats.habit.name, style: theme.textTheme.titleLarge),
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
