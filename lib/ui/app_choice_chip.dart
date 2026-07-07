// `AppChoiceChip` — the canonical ChoiceChip wrapper.
//
// Lifts the bare [ChoiceChip] pattern (used across
// `add_event.dart`, `add_habit.dart`, `person_groups.dart`,
// and the Settings screens) into a primitive that:
//   - Forces a canonical ≥48dp tap target via explicit
//     `padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)`
//     (per the project's touch-target minimum in
//     [Sizing.tapMin] — see
//     [docs/v_model/architecture_options.md] § Touch targets).
//   - Forwards the canonical M3 selected/unselected colors via
//     the active theme (no override needed; the default
//     `ChoiceChip` derives colors from the active ColorScheme).
//
// Extracted during the Month 1 UI-consolidation sprint
// (PR7 of 15). See:
//   - SYS-173 (this PR's surface)
//   - ADR-104 (the rationale + the canonical-pattern call)
//   - WF-101 (the test file)
//   - lib/ui/app_choice_chip.dart (the system under test)

import 'package:flutter/material.dart';

class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  /// The text shown inside the chip. Callers pass a `Text`
  /// widget (e.g., `Text('weekly_on')`) so the framework
  /// handles localization + theme typography.
  final Widget label;

  /// Whether the chip is currently in the selected state.
  /// Drives the M3 selected background + border color.
  final bool selected;

  /// Forwarded to the underlying [ChoiceChip.onSelected].
  /// Called with the new selection state when the user
  /// taps the chip.
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: label,
      selected: selected,
      onSelected: onSelected,
      // The canonical 48dp tap target. ChoiceChip's default
      // padding produces a ~32dp-tall chip on most densities
      // which falls short of the project's `Sizing.tapMin`
      // minimum. The horizontal:12 + vertical:8 padding
      // gives the chip the canonical rhythm of the M3 spec
      // for selectable chips and meets the touch-target
      // minimum.
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
