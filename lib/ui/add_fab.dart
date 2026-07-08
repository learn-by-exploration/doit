// `AddFab` — the canonical "tap me to add a thing" FAB.
//
// Wraps `Material.FloatingActionButton` with the project's M3
// defaults. Per `.claude/rules/lib-screens.md` every interactive
// element is ≥ 48dp × 48dp; the M3 FAB is 56dp by default
// (matches the `Sizing.tapHome` constant for visual consistency
// with the home tile's per-row buttons).
//
// The FAB carries a default `tooltip: 'Add'` so TalkBack
// announces the action on long-press / accessibility focus —
// a free a11y win from the primitive extraction (the prior
// 3 call sites in `home.dart` / `events.dart` /
// `person_groups.dart` had no tooltip).
//
// Callers that need a custom icon (e.g. a future "Scan barcode"
// FAB) can pass a different `child:` Widget.
//
// v1.8-15 / SYS-189 / ADR-120 / WF-116: the 18th `lib/ui/` file.
// Extracted during the Month 1 UI-consolidation sprint. The
// 3 prior call sites in `home.dart` (the `_AddFab` private
// widget, which opens the `_AddSheet` choice sheet),
// `events.dart` (the events add), and `person_groups.dart`
// (the contact group add) all migrate to AddFab in one sweep.

import 'package:flutter/material.dart';

/// The canonical "Add" FAB. Use for the home screen's add
/// button, the events add, the contact-group add, and any
/// future screen that needs a "create new X" affordance.
///
/// Renders a `FloatingActionButton` with `Icons.add` as the
/// default child. The `tooltip:` defaults to `'Add'` (a
/// future PR can pass `l.addFabTooltip` to localize).
///
/// Sizing: 56dp (M3 default; matches `Sizing.tapHome`). For
/// a custom-size FAB, use a `SizedBox` wrapper.
class AddFab extends StatelessWidget {
  const AddFab({super.key, required this.onPressed, this.tooltip = 'Add'});

  /// Tap handler. `null` is not allowed (a disabled FAB is
  /// typically hidden entirely via `if (condition) AddFab(...)`).
  final VoidCallback onPressed;

  /// Tooltip shown on long-press (and read by TalkBack).
  /// Defaults to `'Add'` for the standard case. Pass a
  /// localized string (e.g. `l.addFabTooltip`) when the screen
  /// context makes "Add" ambiguous.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      child: const Icon(Icons.add),
    );
  }
}
