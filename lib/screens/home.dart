// Home screen — the catalog + due-now strip + "I'm up" anchor.
//
// Per WF-002 (entry) and WF-004..010 / WF-014..016, the home
// screen:
//   - Lists every active habit in alphabetical order, with the
//     category color as the tile's accent.
//   - Shows a "due now" strip at the top (the next
//     occurrence of each habit that is past-due or due
//     within the next hour).
//   - Has a floating add button (FAB) for "Add habit" or
//     "Add person".
//   - Has an "I'm up" button that records the wake-up
//     anchor (manual mode).
//   - Renders the reliability banner when degraded.
//
// v0.2 (WF-022, WF-031, SYS-031): tap a tile to open
// `AddHabitScreen` in edit mode. The tile shows the
// habit's category color (8-swatch palette), icon, and
// pause badge if paused.
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
import 'package:common_games/widgets/category_chip.dart';
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
    final visual = CategoryChipResolver.resolveFor(
      category: habit.category,
      colorSeed: habit.colorSeed,
    );
    final color = Color(visual.color);
    final isPaused =
        habit.pausedUntil != null && habit.pausedUntil!.isAfter(DateTime.now());
    return Semantics(
      label:
          'Habit ${habit.name}'
          '${isPaused ? ', paused' : ''}',
      button: true,
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('habit_tile.${habit.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AddHabitScreen(habitId: habit.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                _TileIcon(
                  category: habit.category,
                  iconName: habit.iconName,
                  color: color,
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              habit.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (isPaused)
                            Tooltip(
                              message: 'Paused',
                              child: Icon(
                                Icons.pause_circle,
                                size: 18,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                        ],
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
      HabitTimeWindow() => 'Window — ${h.start}–${h.end}',
    };
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({
    required this.category,
    required this.iconName,
    required this.color,
  });

  final HabitCategory category;
  final String? iconName;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        shape: BoxShape.circle,
      ),
      child: Icon(_iconFor(category, iconName), color: color, size: 24),
    );
  }

  IconData _iconFor(HabitCategory c, String? name) {
    final key = HabitIcons.resolveFor(category: c, iconName: name);
    return _iconMap[key] ?? Icons.check;
  }

  static const Map<String, IconData> _iconMap = <String, IconData>{
    'local_drink': Icons.local_drink,
    'directions_run': Icons.directions_run,
    'fitness_center': Icons.fitness_center,
    'self_improvement': Icons.self_improvement,
    'bedtime': Icons.bedtime,
    'wb_sunny': Icons.wb_sunny,
    'restaurant': Icons.restaurant,
    'local_fire_department': Icons.local_fire_department,
    'spa': Icons.spa,
    'air': Icons.air,
    'menu_book': Icons.menu_book,
    'edit_note': Icons.edit_note,
    'psychology_alt': Icons.psychology_alt,
    'lightbulb': Icons.lightbulb,
    'auto_stories': Icons.auto_stories,
    'call': Icons.call,
    'chat': Icons.chat,
    'mail': Icons.mail,
    'group': Icons.group,
    'favorite': Icons.favorite,
    'pets': Icons.pets,
    'volunteer_activism': Icons.volunteer_activism,
    'diversity_3': Icons.diversity_3,
    'check_circle': Icons.check_circle,
    'task_alt': Icons.task_alt,
    'pending_actions': Icons.pending_actions,
    'event': Icons.event,
    'today': Icons.today,
    'schedule': Icons.schedule,
    'work': Icons.work,
    'school': Icons.school,
    'home': Icons.home,
    'cleaning_services': Icons.cleaning_services,
    'kitchen': Icons.kitchen,
    'local_laundry_service': Icons.local_laundry_service,
    'yard': Icons.yard,
    'shopping_cart': Icons.shopping_cart,
    'receipt_long': Icons.receipt_long,
    'savings': Icons.savings,
    'block': Icons.block,
    'do_not_disturb': Icons.do_not_disturb,
    'pause_circle': Icons.pause_circle,
    'repeat': Icons.repeat,
    'restore': Icons.restore,
    'undo': Icons.undo,
    'check': Icons.check,
    'restaurant_menu': Icons.restaurant_menu,
    'lunch_dining': Icons.lunch_dining,
    'local_pizza': Icons.local_pizza,
    'cake': Icons.cake,
    'coffee': Icons.coffee,
    'liquor': Icons.liquor,
    'set_meal': Icons.set_meal,
    'directions_walk': Icons.directions_walk,
    'directions_bike': Icons.directions_bike,
    'pool': Icons.pool,
    'sports_gymnastics': Icons.sports_gymnastics,
    'sports_tennis': Icons.sports_tennis,
    'sports_basketball': Icons.sports_basketball,
    'sports_soccer': Icons.sports_soccer,
    'hiking': Icons.hiking,
  };
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
