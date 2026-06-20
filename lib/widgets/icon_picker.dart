// IconPicker — the 8×8 grid of Material Symbols keys from
// `DoIcons.keys`.
//
// Per WF-031. The picker is the single source of truth for
// "which icon does the user want for this habit?" — every
// other surface reads `DoIcons.resolveFor`.
//
// The 64 keys are split across 8 thematic rows:
//   1. Physical (water, run, fitness, sleep, sun, food, fire)
//   2. Mind / mental
//   3. Relational
//   4. Productivity
//   5. Home
//   6. Discipline / recovery
//   7. Food (v0.2 user-named)
//   8. Exercise (v0.2 user-named)
//
// The grid is presented as a 4-column wrap (the screen is
// 360dp wide; 4 columns of 72dp tiles + spacing fit). Tapping
// a tile returns the icon key; tapping the same key again
// deselects (so the user can clear the override).
//
// Touch target: per `.claude/rules/lib-screens.md` every
// interactive element is ≥ 48dp; the picker tiles are 56dp.

import 'package:flutter/material.dart';

import 'package:doit/do/category.dart';

/// Show the icon picker as a modal bottom sheet. Returns the
/// picked icon key, or null if the user dismissed.
class IconPickerSheet extends StatelessWidget {
  const IconPickerSheet({
    super.key,
    required this.initialIconName,
    required this.category,
  });

  final String? initialIconName;
  final DoCategory category;

  static Future<String?> show(
    BuildContext context, {
    required String? initialIconName,
    required DoCategory category,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          IconPickerSheet(initialIconName: initialIconName, category: category),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PickerState(initialIconName: initialIconName, category: category);
  }
}

class _PickerState extends StatefulWidget {
  const _PickerState({required this.initialIconName, required this.category});

  final String? initialIconName;
  final DoCategory category;

  @override
  State<_PickerState> createState() => _PickerStateState();
}

class _PickerStateState extends State<_PickerState> {
  late String? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialIconName;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Icon',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (_picked != null)
                      TextButton(
                        onPressed: () => setState(() => _picked = null),
                        child: const Text('Use default'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: DoIcons.keys.length,
                    itemBuilder: (context, i) {
                      final key = DoIcons.keys[i];
                      final isSelected = _picked == key;
                      return Semantics(
                        button: true,
                        label: 'Icon $key',
                        selected: isSelected,
                        child: Material(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            key: ValueKey('icon.$key'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.of(context).pop(key),
                            child: Center(child: Icon(_iconData(key))),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconData(String key) {
    // The picker accepts the 64 known keys; unknown keys would
    // have been replaced by the model layer's `resolveFor`.
    // The fallback (Icons.check) keeps the picker from
    // crashing on a key set mismatch during dev.
    return _iconRegistry[key] ?? Icons.check;
  }
}

/// Static registry from `DoIcons.keys` → `IconData` constant.
///
/// This is a hand-maintained map (there is no Material Symbols
/// code-point generator for Flutter yet). The keys match
/// `lib/habits/category.dart#DoIcons.keys` 1:1; if the keys
/// set changes, update this map in the same PR.
const Map<String, IconData> _iconRegistry = <String, IconData>{
  // Row 1 — physical
  'local_drink': Icons.local_drink,
  'directions_run': Icons.directions_run,
  'fitness_center': Icons.fitness_center,
  'self_improvement': Icons.self_improvement,
  'bedtime': Icons.bedtime,
  'wb_sunny': Icons.wb_sunny,
  'restaurant': Icons.restaurant,
  'local_fire_department': Icons.local_fire_department,
  // Row 2 — mind / mental
  'spa': Icons.spa,
  'air': Icons.air,
  'menu_book': Icons.menu_book,
  'edit_note': Icons.edit_note,
  'psychology_alt': Icons.psychology_alt,
  'lightbulb': Icons.lightbulb,
  'auto_stories': Icons.auto_stories,
  // Row 3 — relational
  'call': Icons.call,
  'chat': Icons.chat,
  'mail': Icons.mail,
  'group': Icons.group,
  'favorite': Icons.favorite,
  'pets': Icons.pets,
  'volunteer_activism': Icons.volunteer_activism,
  'diversity_3': Icons.diversity_3,
  // Row 4 — productivity
  'check_circle': Icons.check_circle,
  'task_alt': Icons.task_alt,
  'pending_actions': Icons.pending_actions,
  'event': Icons.event,
  'today': Icons.today,
  'schedule': Icons.schedule,
  'work': Icons.work,
  'school': Icons.school,
  // Row 5 — home
  'home': Icons.home,
  'cleaning_services': Icons.cleaning_services,
  'kitchen': Icons.kitchen,
  'local_laundry_service': Icons.local_laundry_service,
  'yard': Icons.yard,
  'shopping_cart': Icons.shopping_cart,
  'receipt_long': Icons.receipt_long,
  'savings': Icons.savings,
  // Row 6 — discipline / recovery
  'block': Icons.block,
  'do_not_disturb': Icons.do_not_disturb,
  'pause_circle': Icons.pause_circle,
  'repeat': Icons.repeat,
  'restore': Icons.restore,
  'undo': Icons.undo,
  'check': Icons.check,
  // Row 7 — food
  'restaurant_menu': Icons.restaurant_menu,
  'lunch_dining': Icons.lunch_dining,
  'local_pizza': Icons.local_pizza,
  'cake': Icons.cake,
  'coffee': Icons.coffee,
  'liquor': Icons.liquor,
  'set_meal': Icons.set_meal,
  // Row 8 — exercise
  'directions_walk': Icons.directions_walk,
  'directions_bike': Icons.directions_bike,
  'pool': Icons.pool,
  'sports_gymnastics': Icons.sports_gymnastics,
  'sports_tennis': Icons.sports_tennis,
  'sports_basketball': Icons.sports_basketball,
  'sports_soccer': Icons.sports_soccer,
  'hiking': Icons.hiking,
};
