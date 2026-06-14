// Stats screen — per-habit + overall streak counts.
//
// Per WF-011. Reads the habit list from `HabitRepository` and
// the per-habit completion log from `CompletionLogService`,
// then runs `StreakCalculator.compute` once per habit.
//
// Layer rules (per .claude/rules/lib-screens.md):
//   - StatefulWidget, FutureBuilder pattern.
//   - Loading → skeleton / spinner. Error → Retry.
//   - Touch targets ≥ 48dp.

import 'package:flutter/material.dart';

import 'package:common_games/habits/habit.dart';
import 'package:common_games/habits/rest_day_budget.dart';
import 'package:common_games/habits/streak_calculator.dart';
import 'package:common_games/services/completion_log_service.dart';
import 'package:common_games/services/habit_repository.dart';
import 'package:common_games/theme/app_theme.dart';

/// A pre-baked row. Computed in the screen's `initState` /
/// `_load()` so the build method is pure.
class _HabitStats {
  const _HabitStats({required this.habit, required this.snapshot});
  final Habit habit;
  final StreakSnapshot snapshot;
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Future<List<_HabitStats>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_HabitStats>> _load() async {
    final habits = await HabitRepository.instance.listAll();
    final result = <_HabitStats>[];
    for (final h in habits) {
      final completions = await CompletionLogService.instance.listForHabit(
        h.id,
      );
      final log = completions
          .map(
            (r) => CompletionLogEntry(
              habitId: r.habitId,
              date: DateTime.fromMillisecondsSinceEpoch(r.dayMillis),
            ),
          )
          .toList(growable: false);
      final snap = StreakCalculator.compute(
        log: log,
        config: StreakConfig(
          graceWindow: const Duration(hours: 3),
          restDayBudget: RestDayBudget(
            habitId: h.id,
            monthlyLimit: h.restDaysPerMonth,
          ),
        ),
        asOf: DateTime.now(),
      );
      result.add(_HabitStats(habit: h, snapshot: snap));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: SafeArea(
        child: FutureBuilder<List<_HabitStats>>(
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
            final rows = snap.data ?? <_HabitStats>[];
            if (rows.isEmpty) {
              return const _EmptyView();
            }
            return ListView.separated(
              padding: const EdgeInsets.all(Spacing.md),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
              itemBuilder: (_, i) => _StatsCard(stats: rows[i]),
            );
          },
        ),
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
          '${stats.habit.name}: current streak ${stats.snapshot.currentStreak}, '
          'longest ${stats.snapshot.longestStreak}',
      child: Card(
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
              'Add a habit to start tracking streaks.',
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
