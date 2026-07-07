// Canonical loading indicator for the doit design system.
//
// Per UI_ORG_AUDIT.md C5 (empty/loading/error states), the
// screen / widget layer SHOULD NOT inline a hand-rolled
// `Center(child: CircularProgressIndicator())` for full-area
// loading — that pattern recurs across home, events, and
// person-groups with no consistent size/stroke width and no
// inline spinner variant for in-row loading.
//
// This module exposes one widget + one static helper:
//
//   - [LoadingView] — full-area `Center(CircularProgressIndicator())`
//     placeholder for "data still loading" states.
//   - [LoadingView.inline] — small in-row spinner (e.g. for
//     a list row that is fetching, or a button that is busy).
//
// The default indicator uses Flutter's
// `CircularProgressIndicator` with the theme's `colorScheme.primary`
// (M3 canonical accent) at 36dp with a 4dp stroke. The
// inline variant is 20dp / 2dp stroke — the canonical
// "small spinner" for in-row use.
//
// PR9 of 15 (UI consolidation). See SYS-184 / ADR-115 / WF-111.

import 'package:flutter/material.dart';

/// Canonical loading indicator.
///
/// **Usage rule (per UI_ORG_AUDIT.md C5):**
/// - **DO** wrap a "data still loading" surface in
///   `const LoadingView()` (full-area) or
///   `LoadingView.inline()` (in-row).
/// - **DO NOT** inline
///   `Center(child: CircularProgressIndicator())` outside
///   this file. The primitive is the single point of change
///   for loading visuals.
///
/// The widget is theme-aware: the indicator color comes from
/// `Theme.of(context).colorScheme.primary` (M3 canonical
/// accent) at construction time; Flutter re-renders the
/// indicator on theme switch.
class LoadingView extends StatelessWidget {
  const LoadingView({
    super.key,
    this.size = _kDefaultSize,
    this.strokeWidth = _kDefaultStroke,
  });

  /// Default size (full-area): 36dp. M3 "comfortable" spinner.
  static const double _kDefaultSize = 36;

  /// Default stroke width: 4dp. M3 "comfortable" stroke.
  static const double _kDefaultStroke = 4;

  /// Spinner diameter. Defaults to 36dp.
  final double size;

  /// Spinner stroke width. Defaults to 4dp.
  final double strokeWidth;

  /// Build an in-row loading spinner (20dp / 2dp stroke).
  ///
  /// Use for "this row is fetching" states (e.g. a contact
  /// resolution row, a per-person streak query).
  const LoadingView.inline({super.key, this.size = 20, this.strokeWidth = 2});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: strokeWidth),
      ),
    );
  }
}
