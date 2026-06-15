// CategoryChip — the *only* file in the v0.2 codebase that
// bridges `HabitCategory` (a pure-Dart enum in
// `lib/habits/category.dart`) into a Flutter `Color`.
//
// Per `.claude/rules/lib-habits.md`, the model layer must not
// import Flutter. The category-color mapping lives here, in
// the UI layer, so the model stays portable.
//
// The chip is used by:
//   - the home screen habit tile (background tint by category,
//     or the user-picked colorSeed if colorSeed > 0),
//   - the add/edit habit form (the "Color" picker row),
//   - the stats screen (per-category grouping header).
//
// Touch target: ≥ 48dp (per `.claude/rules/lib-screens.md`).

import 'package:flutter/material.dart';

import 'package:doit/habits/category.dart';

/// The resolved visual identity for a habit: the swatch ARGB
/// int to paint with, and the human-readable label of the
/// category (for the stats grouping header).
@immutable
class CategoryVisual {
  const CategoryVisual({required this.color, required this.label});

  /// ARGB int — call `Color(...)` at the use-site.
  final int color;

  /// The label of the category (`'Health'`, `'Mind'`, etc.).
  final String label;
}

/// Resolve a habit's `(category, colorSeed)` pair to a visual.
/// If [colorSeed] is 0, the category default is used; 1..7
/// override to a non-default swatch. See
/// `CategoryPalette.seedFor` for the exact mapping.
///
/// A null [iconName] returns the category default; an unknown
/// [iconName] also returns the default (the model layer's
/// `HabitIcons.resolveFor` does the same — this is the
/// UI-side mirror so the chip can render the icon).
class CategoryChipResolver {
  const CategoryChipResolver._();

  static CategoryVisual resolveFor({
    required HabitCategory category,
    required int colorSeed,
  }) {
    final seed = CategoryPalette.seedFor(category, colorSeed);
    return CategoryVisual(
      color: CategoryPalette.swatches[seed],
      label: _labelFor(category),
    );
  }

  static String resolveIconFor({
    required HabitCategory category,
    required String? iconName,
  }) {
    return HabitIcons.resolveFor(category: category, iconName: iconName);
  }

  static String _labelFor(HabitCategory c) {
    switch (c) {
      case HabitCategory.health:
        return 'Health';
      case HabitCategory.mind:
        return 'Mind';
      case HabitCategory.relationships:
        return 'Relationships';
      case HabitCategory.productivity:
        return 'Productivity';
      case HabitCategory.home:
        return 'Home';
      case HabitCategory.other:
        return 'Other';
    }
  }
}

/// The small chip shown in the add/edit form: a colored disc +
/// the category label. Tap to open the picker.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    required this.colorSeed,
    required this.onTap,
  });

  final HabitCategory category;
  final int colorSeed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = CategoryChipResolver.resolveFor(
      category: category,
      colorSeed: colorSeed,
    );
    return Semantics(
      button: true,
      label: 'Category ${visual.label}',
      child: Material(
        color: Color(visual.color).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(visual.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  visual.label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal bottom sheet that lets the user pick a category and an
/// optional color override. Returns a `(category, colorSeed)`
/// pair, or null if the user dismissed.
class CategoryPickerSheet extends StatelessWidget {
  const CategoryPickerSheet({
    super.key,
    required this.initialCategory,
    required this.initialColorSeed,
  });

  final HabitCategory initialCategory;
  final int initialColorSeed;

  static Future<({HabitCategory category, int colorSeed})?> show(
    BuildContext context, {
    required HabitCategory initialCategory,
    required int initialColorSeed,
  }) {
    return showModalBottomSheet<({HabitCategory category, int colorSeed})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryPickerSheet(
        initialCategory: initialCategory,
        initialColorSeed: initialColorSeed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PickerState(
      initialCategory: initialCategory,
      initialColorSeed: initialColorSeed,
    );
  }
}

class _PickerState extends StatefulWidget {
  const _PickerState({
    required this.initialCategory,
    required this.initialColorSeed,
  });

  final HabitCategory initialCategory;
  final int initialColorSeed;

  @override
  State<_PickerState> createState() => _PickerStateState();
}

class _PickerStateState extends State<_PickerState> {
  late HabitCategory _category;
  late int _colorSeed;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _colorSeed = widget.initialColorSeed;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in HabitCategory.values)
                  ChoiceChip(
                    key: ValueKey('category.${c.name}'),
                    label: Text(_label(c)),
                    selected: _category == c,
                    onSelected: (_) => setState(() {
                      _category = c;
                      // When the user switches category, reset to
                      // the category default (colorSeed = 0) so
                      // the swatch stays sensible.
                      _colorSeed = 0;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Color', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _SwatchRow(
              selected: _colorSeed,
              onPick: (i) => setState(() => _colorSeed = i),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('category_picker.save'),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop((category: _category, colorSeed: _colorSeed)),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _label(HabitCategory c) {
    switch (c) {
      case HabitCategory.health:
        return 'Health';
      case HabitCategory.mind:
        return 'Mind';
      case HabitCategory.relationships:
        return 'Relationships';
      case HabitCategory.productivity:
        return 'Productivity';
      case HabitCategory.home:
        return 'Home';
      case HabitCategory.other:
        return 'Other';
    }
  }
}

class _SwatchRow extends StatelessWidget {
  const _SwatchRow({required this.selected, required this.onPick});

  final int selected;
  final void Function(int) onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: CategoryPalette.swatches.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          // Index 0 = "default" (category's built-in color).
          // Indices 1..N = the override swatches.
          if (i == 0) {
            final isDefault = selected == 0;
            return Semantics(
              button: true,
              label: 'Default color',
              selected: isDefault,
              child: InkWell(
                onTap: () => onPick(0),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDefault
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      width: isDefault ? 3 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.auto_awesome, size: 20),
                ),
              ),
            );
          }
          final swatchIdx = i - 1;
          final argb = CategoryPalette.swatches[swatchIdx];
          final isSelected = selected == i;
          return Semantics(
            button: true,
            label: 'Color $i',
            selected: isSelected,
            child: InkWell(
              onTap: () => onPick(i),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(argb),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                    width: isSelected ? 3 : 1,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
