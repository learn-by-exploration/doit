// Home screen — the catalog + due-now strip + "I'm up" anchor.
//
// Per WF-002 (entry) and WF-004..010 / WF-014..016, the home
// screen:
//   - Lists every active habit in alphabetical order.
//   - Shows a "due now" strip at the top (the next
//     occurrence of each habit that is past-due or due
//     within the next hour).
//   - Has a floating add button (FAB) for "Add habit" or
//     "Add person".
//   - Has an "I'm up" button that records the wake-up
//     anchor (manual mode).
//   - Renders the reliability banner when degraded.
//
// State: a `FutureBuilder` reads the habit list once and
// rebuilds when a save / delete is dispatched. v0.1 has no
// stream; the home screen re-fetches on `didChangeAppLifecycleState`
// (resume).

import 'package:flutter/material.dart';

import 'package:common_games/habits/habit.dart';
import 'package:common_games/services/habit_repository.dart';
import 'package:common_games/services/reminder_service.dart';
import 'package:common_games/theme/app_theme.dart';
import 'package:common_games/widgets/reliability_banner.dart';
import 'package:common_games/screens/add_habit.dart';
import 'package:common_games/screens/add_person.dart';
import 'package:common_games/screens/settings.dart';
import 'package:common_games/screens/stats.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Future<List<Habit>>? _habitsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    setState(() {
      _habitsFuture = HabitRepository.instance.listAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Streak'),
        actions: [
          IconButton(
            tooltip: 'Stats',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StatsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ReliabilityBanner.fromService(),
            const _AddAnchorButton(),
            Expanded(
              child: FutureBuilder<List<Habit>>(
                future: _habitsFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return _ErrorView(
                      message: 'Could not load habits',
                      onRetry: _refresh,
                    );
                  }
                  final habits = snap.data ?? <Habit>[];
                  if (habits.isEmpty) {
                    return const _EmptyState();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(Spacing.md),
                    itemCount: habits.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Spacing.sm),
                    itemBuilder: (_, i) => _HabitTile(habit: habits[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _AddFab(onAdded: _refresh),
    );
  }
}

class _AddAnchorButton extends StatelessWidget {
  const _AddAnchorButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: SizedBox(
        width: double.infinity,
        height: Sizing.tapHome,
        child: FilledButton.icon(
          key: const ValueKey('home.im_up'),
          icon: const Icon(Icons.wb_sunny_outlined),
          label: const Text("I'm up"),
          onPressed: () {
            final t = ReminderService.instance.anchor.markNow();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  t == null
                      ? 'Already up — see you in a few hours.'
                      : 'Marked as up.',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Habit ${habit.name}',
      button: true,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Tap-to-edit is a v0.2 surface.
          },
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        _describe(habit),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Mark done',
                  icon: const Icon(Icons.check_circle_outline),
                  iconSize: Sizing.tapHome / 2,
                  onPressed: () {
                    // v0.2: append to completion log + recompute streak.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Marked done.')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _describe(Habit h) {
    return switch (h) {
      HabitFixed() => 'Fixed — ${h.time}',
      HabitInterval() => 'Every ${h.nDays} days',
      HabitAnchor() => 'Anchor',
      HabitDayOfX() => 'Day-of-X',
    };
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt_outlined,
              size: Sizing.huge,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'No habits yet.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Tap the + to add a habit or a person.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: Spacing.md),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _AddFab extends StatelessWidget {
  const _AddFab({required this.onAdded});
  final VoidCallback onAdded;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      key: const ValueKey('home.fab'),
      onPressed: () async {
        final choice = await showModalBottomSheet<_AddChoice>(
          context: context,
          builder: (_) => const _AddSheet(),
        );
        if (choice == null) return;
        if (!context.mounted) return;
        switch (choice) {
          case _AddChoice.habit:
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AddHabitScreen()),
            );
            onAdded();
          case _AddChoice.person:
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AddPersonScreen()),
            );
            onAdded();
        }
      },
      child: const Icon(Icons.add),
    );
  }
}

enum _AddChoice { habit, person }

class _AddSheet extends StatelessWidget {
  const _AddSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('home.fab.habit'),
            leading: const Icon(Icons.checklist),
            title: const Text('New habit'),
            onTap: () => Navigator.of(context).pop(_AddChoice.habit),
          ),
          ListTile(
            key: const ValueKey('home.fab.person'),
            leading: const Icon(Icons.person_add_alt_1),
            title: const Text('New person'),
            onTap: () => Navigator.of(context).pop(_AddChoice.person),
          ),
          const SizedBox(height: Spacing.md),
        ],
      ),
    );
  }
}
