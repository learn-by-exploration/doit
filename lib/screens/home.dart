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

import 'package:doit/do/do.dart';
import 'package:doit/do/do_description.dart';
import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/widgets/category_chip.dart';
import 'package:doit/widgets/reliability_banner.dart';
import 'package:doit/widgets/routine_banner.dart';
import 'package:doit/screens/add_habit.dart';
import 'package:doit/screens/add_person.dart';
import 'package:doit/screens/settings.dart';
import 'package:doit/screens/stats.dart';
import 'package:doit/screens/templates.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Future<List<Do>>? _habitsFuture;
  final Set<String> _selected = <String>{};
  bool _selectMode = false;

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
      _habitsFuture = DoRepository.instance.listAll();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      if (_selected.isEmpty) _selectMode = false;
    });
  }

  void _enterSelectMode(String firstId) {
    setState(() {
      _selectMode = true;
      _selected.add(firstId);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  /// Tap handler for a tile in normal (non-select) mode.
  /// Opens the edit screen and, if the screen pops with
  /// `true` (WF-022 hard delete), refreshes the home list
  /// so the deleted tile disappears immediately.
  Future<void> _onTileTap(String habitId) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => AddHabitScreen(habitId: habitId)),
    );
    if (deleted == true) _refresh();
  }

  Future<void> _completeSelected() async {
    final now = DateTime.now();
    for (final id in _selected) {
      await CompletionLogService.instance.append(
        habitId: id,
        day: now,
        source: CompletionSource.manual,
        proofModeAtTime: 'soft',
      );
    }
    if (!mounted) return;
    _exitSelectMode();
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(
            context,
          ).homeSnackbarMarkedCount(_selected.length),
        ),
      ),
    );
  }

  /// WF-021 (Phase 11d). Per-tile mark-done: writes a
  /// completion for [habit] (id + name) for today's local
  /// day bucket, then offers an Undo affordance.
  ///
  /// The per-tile "Mark done" button at `_HabitTile` used
  /// to be a stub that only fired a snackbar. Wiring it
  /// to a real check-off is the natural place for the
  /// per-day todo's daily completion (Nielsen #1: visibility
  /// of system status; Norman #2: feedback; Norman #3:
  /// user control via the Undo affordance).
  ///
  /// Errors are surfaced via a snackbar and the screen
  /// is left mounted so the user can retry.
  Future<void> _completeOne(Do habit) async {
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final String appendedId;
    try {
      appendedId = await CompletionLogService.instance.append(
        habitId: habit.id,
        day: now,
        source: CompletionSource.manual,
        proofModeAtTime: 'soft',
      );
    } on Object catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not mark done. Try again.')),
      );
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Marked "${habit.name}" done.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _undoCompletion(habit.id, appendedId),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    _refresh();
  }

  /// Undo the most-recent manual completion for [habitId]
  /// when [appendedId] matches. Best-effort: if the row
  /// was already deleted by a sync, the undo is a no-op.
  Future<void> _undoCompletion(String habitId, String appendedId) async {
    try {
      await CompletionLogService.instance.deleteById(appendedId);
    } on Object catch (_) {
      // Silent: the user can re-mark if they want to.
      return;
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectMode
              ? l.homeSelectionAppBarTitle(_selected.length)
              : l.homeAppBarTitle,
        ),
        leading: _selectMode
            ? IconButton(
                key: const ValueKey('home.cancel_select'),
                tooltip: 'Cancel',
                icon: const Icon(Icons.close),
                onPressed: _exitSelectMode,
              )
            : null,
        actions: [
          if (_selectMode)
            IconButton(
              key: const ValueKey('home.complete_selected'),
              tooltip: 'Mark selected done',
              icon: const Icon(Icons.check_circle),
              onPressed: _selected.isEmpty ? null : _completeSelected,
            )
          else ...[
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
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ReliabilityBanner.fromService(),
            const RoutineBanner(),
            const _AddAnchorButton(),
            Expanded(
              child: FutureBuilder<List<Do>>(
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
                  final habits = snap.data ?? <Do>[];
                  if (habits.isEmpty) {
                    return const _EmptyState();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(Spacing.md),
                    itemCount: habits.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Spacing.sm),
                    itemBuilder: (_, i) => _HabitTile(
                      habit: habits[i],
                      selected: _selected.contains(habits[i].id),
                      selectMode: _selectMode,
                      onLongPress: () => _enterSelectMode(habits[i].id),
                      onTap: _selectMode
                          ? () => _toggleSelect(habits[i].id)
                          : () => _onTileTap(habits[i].id),
                      onMarkDone: _selectMode
                          ? null
                          : () => _completeOne(habits[i]),
                    ),
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
  const _HabitTile({
    required this.habit,
    this.selected = false,
    this.selectMode = false,
    this.onLongPress,
    this.onTap,
    this.onMarkDone,
  });
  final Do habit;
  final bool selected;
  final bool selectMode;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  /// WF-021 (Phase 11d). The per-tile "Mark done" button
  /// calls this. The home screen wires it to a real
  /// completion via `_completeOne` (which offers an Undo
  /// affordance in a snackbar). The tile was a stub prior
  /// to v1.2n.
  final VoidCallback? onMarkDone;

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
          'Do ${habit.name}'
          '${isPaused ? ', paused' : ''}'
          '${selected ? ', selected' : ''}',
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.30)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('habit_tile.${habit.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                if (selectMode)
                  Padding(
                    padding: const EdgeInsets.only(right: Spacing.sm),
                    child: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: color,
                    ),
                  ),
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
                        describeDo(habit),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (habit is DoTimeWindow)
                        _FastingTimer(habit: habit as DoTimeWindow),
                    ],
                  ),
                ),
                if (!selectMode)
                  Semantics(
                    button: true,
                    label: 'Mark ${habit.name} done for today',
                    child: IconButton(
                      tooltip: 'Mark done',
                      icon: const Icon(Icons.check_circle_outline),
                      iconSize: Sizing.tapHome / 2,
                      onPressed: onMarkDone,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live-updating fasting timer shown on DoTimeWindow tiles.
/// Ticks every second; shows the time until the window closes
/// (or "starts in HH:MM" if the window hasn't opened yet).
class _FastingTimer extends StatefulWidget {
  const _FastingTimer({required this.habit});
  final DoTimeWindow habit;

  @override
  State<_FastingTimer> createState() => _FastingTimerState();
}

class _FastingTimerState extends State<_FastingTimer> {
  late Stream<DateTime> _tick;

  @override
  void initState() {
    super.initState();
    _tick = Stream<DateTime>.periodic(
      const Duration(seconds: 1),
      (_) => DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: _tick,
      builder: (context, snap) {
        final now = snap.data ?? DateTime.now();
        final label = _windowLabel(widget.habit, now);
        if (label == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: Spacing.xs),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16),
              const SizedBox(width: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }

  /// "Closes in 02:30" / "Opens in 12:00" / null if today is
  /// not a fasting weekday.
  String? _windowLabel(DoTimeWindow h, DateTime now) {
    if (!h.weekdays.contains(now.weekday)) return null;
    final open = DateTime(
      now.year,
      now.month,
      now.day,
      h.start.hour,
      h.start.minute,
    );
    final close = DateTime(
      now.year,
      now.month,
      now.day,
      h.end.hour,
      h.end.minute,
    );
    if (now.isBefore(open)) {
      return 'Opens in ${_fmt(open.difference(now))}';
    }
    if (now.isBefore(close)) {
      final remaining = close.difference(now);
      final target = h.targetHours;
      if (target != null) {
        return 'Fasting — ${_fmt(remaining)} left (target ${target}h)';
      }
      return 'Window closes in ${_fmt(remaining)}';
    }
    return null;
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({
    required this.category,
    required this.iconName,
    required this.color,
  });

  final DoCategory category;
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

  IconData _iconFor(DoCategory c, String? name) {
    final key = DoIcons.resolveFor(category: c, iconName: name);
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
              AppLocalizations.of(context).homeEmptyTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Tap the + to add a do or a person.',
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
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).homeRetryButton),
            ),
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
          case _AddChoice.template:
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TemplatesScreen()),
            );
        }
      },
      child: const Icon(Icons.add),
    );
  }
}

enum _AddChoice { habit, person, template }

class _AddSheet extends StatelessWidget {
  const _AddSheet();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('home.fab.habit'),
            leading: const Icon(Icons.checklist),
            title: Text(l.homeAddSheetNewDo),
            onTap: () => Navigator.of(context).pop(_AddChoice.habit),
          ),
          ListTile(
            key: const ValueKey('home.fab.person'),
            leading: const Icon(Icons.person_add_alt_1),
            title: Text(l.homeAddSheetNewPerson),
            onTap: () => Navigator.of(context).pop(_AddChoice.person),
          ),
          ListTile(
            key: const ValueKey('home.fab.template'),
            leading: const Icon(Icons.dashboard_customize),
            title: Text(l.homeAddSheetFromTemplate),
            onTap: () => Navigator.of(context).pop(_AddChoice.template),
          ),
          const SizedBox(height: Spacing.md),
        ],
      ),
    );
  }
}
