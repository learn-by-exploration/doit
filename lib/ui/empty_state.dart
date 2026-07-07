// Canonical empty-state placeholder for the doit design system.
//
// Per UI_ORG_AUDIT.md C5 (empty/loading/error states), the
// screen / widget layer SHOULD NOT inline a hand-rolled
// `Center > Padding > Column(Icon, Text, Text)` for empty
// states — that pattern recurs across home, stats, and
// templates with no semantic structure (e.g., action slot,
// consistent title/body hierarchy, no `Semantics` wrapper).
//
// This module exposes one widget:
//
//   - [EmptyState] — full-area placeholder for "no data"
//     states. API: `{required String title, String? message,
//     IconData? icon, Widget? action, IconData? semanticIcon}`.
//
// Title + message are M3 `titleLarge` + `bodyMedium` (the
// canonical pairing). The icon uses `colorScheme.outline` for
// a calm, muted visual that does not compete with the
// "important" content area. The optional `action` slot
// receives a `Widget?` (e.g. a `PrimaryButton`) — the empty
// state is the right place to put a CTA that pulls the user
// forward (e.g. "Add your first do").
//
// When `icon` is omitted, the widget renders a single-column
// "title + body" (used by `templates.dart` where the empty
// state is a quiet line, not a hero).
//
// PR9 of 15 (UI consolidation). See SYS-184 / ADR-115 / WF-111.

import 'package:flutter/material.dart';

import 'package:doit/theme/app_theme.dart';

/// Canonical empty-state placeholder.
///
/// **Usage rule (per UI_ORG_AUDIT.md C5):**
/// - **DO** wrap any "no data" surface in
///   `EmptyState(title: ..., message: ...)` (optional
///   `icon:` and `action:`).
/// - **DO NOT** inline a hand-rolled
///   `Center > Padding > Column(Icon, Text, Text)` for empty
///   states outside this file. The primitive is the single
///   point of change for empty-state visuals.
///
/// The widget is theme-aware: colors come from
/// `Theme.of(context).colorScheme`; text styles come from
/// `Theme.of(context).textTheme`. Dark + light themes both
/// render correctly.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.action,
  });

  /// The headline. Required. M3 `titleLarge`.
  final String title;

  /// Optional subline. M3 `bodyMedium`. Omit for "quiet"
  /// empty states (e.g. a single-line "no templates" hint).
  final String? message;

  /// Optional hero icon. Renders at [Sizing.huge] in
  /// `colorScheme.outline` (the calm muted tone — NOT the
  /// primary brand color, which would compete with content).
  final IconData? icon;

  /// Optional action slot. Typically a `PrimaryButton` or
  /// `SecondaryButton` (e.g. "Add your first do", "Show me
  /// around"). Renders below the body with a `Spacing.md`
  /// gap.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasIcon = icon != null;
    final hasMessage = message != null;
    final hasAction = action != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasIcon) ...[
              Icon(icon, size: Sizing.huge, color: theme.colorScheme.outline),
              const SizedBox(height: Spacing.md),
            ],
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (hasMessage) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                message!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (hasAction) ...[const SizedBox(height: Spacing.md), action!],
          ],
        ),
      ),
    );
  }
}
