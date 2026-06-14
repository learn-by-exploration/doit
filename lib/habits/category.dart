// HabitCategory — the visual-identity taxonomy for a habit.
//
// v0.2 (WF-031). Six buckets: health, mind, relationships,
// productivity, home, other. The category drives the default
// color and icon on the home screen; the user can override the
// color (8 swatches via colorSeed 0..7) and the icon (one of 64
// Material Symbols keys).
//
// Per .claude/rules/lib-habits.md: pure Dart, no Flutter imports.

import 'package:meta/meta.dart';

/// The visual / semantic category of a habit. Used for:
///   - the default color on the home screen tile,
///   - the default icon (overridable),
///   - the stats screen grouping.
enum HabitCategory {
  health,
  mind,
  relationships,
  productivity,
  home,
  other;

  /// Stable string used in the DB (`Habits.category`).
  String get tag => name;

  /// Parse from the DB tag. Falls back to [other] for unknown
  /// values (forward-compat: a v0.3+ category would not crash
  /// a v0.2 build).
  static HabitCategory fromTag(String tag) {
    for (final c in HabitCategory.values) {
      if (c.tag == tag) return c;
    }
    return HabitCategory.other;
  }
}

/// The 8-swatch color palette. The user can override the
/// category-assigned color by picking a `colorSeed` 0..7.
///
/// Per `.claude/rules/lib-habits.md`, this file must NOT import
/// Flutter. The mapping from `colorSeed` to a Flutter `Color`
/// lives in `lib/widgets/category_chip.dart` (which is the only
/// file allowed to bridge into the UI layer).
@immutable
class CategoryPalette {
  const CategoryPalette._();

  /// ARGB ints for the 8 swatches, ordered by the picker UI.
  /// The values are kept here (not in the widget) so unit tests
  /// can assert mapping without a Flutter harness.
  static const List<int> swatches = <int>[
    0xFF66BB6A, // green       (health default)
    0xFF26A69A, // teal        (mind default)
    0xFFFFB300, // amber       (relationships default)
    0xFF42A5F5, // blue        (productivity default)
    0xFF8D6E63, // brown       (home default)
    0xFF9E9E9E, // grey        (other default)
    0xFFAB47BC, // purple      (override)
    0xFFEC407A, // pink        (override)
  ];

  /// The default swatch index for a category.
  static int defaultSeedFor(HabitCategory c) {
    switch (c) {
      case HabitCategory.health:
        return 0;
      case HabitCategory.mind:
        return 1;
      case HabitCategory.relationships:
        return 2;
      case HabitCategory.productivity:
        return 3;
      case HabitCategory.home:
        return 4;
      case HabitCategory.other:
        return 5;
    }
  }

  /// Resolve a (category, colorSeed) pair to a swatch index.
  /// Out-of-range seeds clamp to the nearest valid index.
  static int seedFor(HabitCategory c, int colorSeed) {
    if (colorSeed <= 0) return defaultSeedFor(c);
    if (colorSeed >= swatches.length) return swatches.length - 1;
    return colorSeed;
  }
}

/// The 64-icon Material Symbols set used for the icon picker.
/// Stored as the `codepoint` name (e.g., `local_drink`,
/// `directions_run`). The icon picker in
/// `lib/widgets/icon_picker.dart` is the single source of UI.
@immutable
class HabitIcons {
  const HabitIcons._();

  /// The 64 icon keys. The order is the picker grid order
  /// (8 columns × 8 rows).
  static const List<String> keys = <String>[
    // Row 1 — physical
    'local_drink', 'directions_run', 'fitness_center', 'self_improvement',
    'bedtime', 'wb_sunny', 'restaurant', 'local_fire_department',
    // Row 2 — mind / mental
    'self_improvement', 'spa', 'air', 'menu_book',
    'edit_note', 'psychology_alt', 'lightbulb', 'auto_stories',
    // Row 3 — relational
    'call', 'chat', 'mail', 'group',
    'favorite', 'pets', 'volunteer_activism', 'diversity_3',
    // Row 4 — productivity
    'check_circle', 'task_alt', 'pending_actions', 'event',
    'today', 'schedule', 'work', 'school',
    // Row 5 — home
    'home', 'cleaning_services', 'kitchen', 'local_laundry_service',
    'yard', 'shopping_cart', 'receipt_long', 'savings',
    // Row 6 — discipline / recovery
    'block', 'do_not_disturb', 'pause_circle', 'repeat',
    'restore', 'undo', 'undo', 'check',
    // Row 7 — food (v0.2 user-named)
    'restaurant_menu', 'lunch_dining', 'local_pizza', 'cake',
    'coffee', 'liquor', 'set_meal', 'kitchen',
    // Row 8 — exercise (v0.2 user-named: "going for something")
    'directions_walk', 'directions_bike', 'pool', 'sports_gymnastics',
    'sports_tennis', 'sports_basketball', 'sports_soccer', 'hiking',
  ];

  /// The canonical icon for a category when the user has not
  /// picked an explicit icon. Matches the user-facing label.
  static String defaultForCategory(HabitCategory c) {
    switch (c) {
      case HabitCategory.health:
        return 'local_drink';
      case HabitCategory.mind:
        return 'self_improvement';
      case HabitCategory.relationships:
        return 'group';
      case HabitCategory.productivity:
        return 'task_alt';
      case HabitCategory.home:
        return 'home';
      case HabitCategory.other:
        return 'check_circle';
    }
  }

  /// Resolve (category, iconName) → the icon key to render.
  /// A null or unknown iconName falls back to the category
  /// default. The picker is the only UI that produces a
  /// non-null, non-default value.
  static String resolveFor({
    required HabitCategory category,
    required String? iconName,
  }) {
    if (iconName == null || iconName.isEmpty) {
      return defaultForCategory(category);
    }
    if (!keys.contains(iconName)) {
      return defaultForCategory(category);
    }
    return iconName;
  }
}
