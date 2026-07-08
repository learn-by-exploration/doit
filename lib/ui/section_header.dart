// `SectionHeader` — the canonical form-section heading.
//
// Lifted from the private `_SectionHeader` widget that lived in
// `lib/screens/settings.dart` (8 invocations across the settings
// sections) and the inline `Padding(EdgeInsets.symmetric(vertical:
// Spacing.sm)) + Text(titleLarge/titleMedium, ...)` pattern that
// recurred across `add_habit.dart`, `add_person.dart`,
// `add_routine.dart`, `events.dart`, and `person_groups.dart`.
//
// The [compact] flag selects between two flavors:
//   - default (false) — full `titleLarge` with canonical
//     `EdgeInsets.symmetric(vertical: Spacing.sm)` padding.
//     Used by settings.dart + the form sections in add_habit /
//     add_person / add_routine.
//   - compact (true) — smaller `titleMedium` with no padding.
//     Used by events.dart (Upcoming / Past) and person_groups.dart
//     (Channel / Cadence / Semantic / Members) where the header
//     sits inside a scrollable list with its own inter-section
//     spacing.
//
// The padding is part of the contract — `EdgeInsets.symmetric(
// vertical: Spacing.sm)` is the canonical vertical breathing room
// between the previous section and the new heading, and removing
// it in the default variant produces a noticeably tighter
// layout in the rendered settings screen.
//
// Extracted during the Month 1 UI-consolidation sprint
// (PR6 of 15). See:
//   - SYS-172 (this PR's surface)
//   - ADR-103 (the rationale + the canonical-pattern call)
//   - WF-100 (the test file)
//   - lib/ui/section_header.dart (the system under test)

import 'package:flutter/material.dart';

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/app_text_styles.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.compact = false});

  /// The heading text. No truncation policy — callers pass the
  /// already-localized title.
  final String title;

  /// When true, renders [titleMedium] with no padding (compact
  /// inline section header inside a list). Default false
  /// renders [titleLarge] with `EdgeInsets.symmetric(vertical:
  /// Spacing.sm)` padding (form-section header at the top of a
  /// vertical block).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      // Compact variant: titleMedium, no padding. Used when the
      // section sits inside an already-padded list (events.dart,
      // person_groups.dart) and the surrounding spacing is owned
      // by the list's SizedBox(height: ...) rhythm.
      // v1.8-13 / SYS-187 / ADR-118: letterSpacing + height
      // come from the AppTextStyles helper (and ultimately from
      // the DoItTypography theme extension).
      return Text(
        title,
        style: AppTextStyles.sectionHeaderTitleCompact(context),
      );
    }
    // Default variant: titleLarge with the canonical vertical
    // breathing room. The padding is symmetric so the heading
    // breathes on both sides; the 8dp value is the Spacing.sm
    // token (canonical 4dp grid).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Text(title, style: AppTextStyles.sectionHeaderTitle(context)),
    );
  }
}
