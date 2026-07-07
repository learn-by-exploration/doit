// Canonical error-state placeholder for the doit design system.
//
// Per UI_ORG_AUDIT.md C5 (empty/loading/error states), the
// screen / widget layer SHOULD NOT inline a hand-rolled
// `Center > Padding > Column(Text, FilledButton)` for error
// states — that pattern recurs across home, stats, and
// templates with no consistent retry-button label (some use
// `l.homeRetryButton`, others use the literal `'Retry'`),
// no shared `ValueKey` (so widget tests can't reliably find
// the retry button), and no central point of design-intent
// for the error visual.
//
// This module exposes one widget:
//
//   - [ErrorView] — full-area placeholder for "data load
//     failed" states. API: `{required String message,
//     required VoidCallback onRetry, String? retryLabel,
//     String? semanticLabel}`.
//
// The message is M3 `bodyLarge`. The retry button uses
// `FilledButton` (the project's primary CTA — see PR1) with
// the localized `homeRetryButton` text by default. The
// optional `retryLabel` overrides the default (e.g. a
// site-specific label like "Try again" or "Reload"). The
// `onRetry` callback is a `VoidCallback` — the caller
// typically calls `setState` to re-fire the FutureBuilder.
//
// The retry button carries a `ValueKey('error.retry')` so
// widget tests can `find.byKey(const ValueKey('error.retry'))`
// to tap the retry affordance unambiguously.
//
// PR10 of 15 (UI consolidation). See SYS-185 / ADR-116 / WF-112.

import 'package:flutter/material.dart';

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/theme/app_theme.dart';

/// Canonical error-state placeholder.
///
/// **Usage rule (per UI_ORG_AUDIT.md C5):**
/// - **DO** wrap any "data load failed" surface in
///   `ErrorView(message: ..., onRetry: ...)` (optional
///   `retryLabel:`).
/// - **DO NOT** inline a hand-rolled
///   `Center > Padding > Column(Text, FilledButton)` for
///   error states outside this file. The primitive is the
///   single point of change for error-state visuals.
///
/// The widget is theme-aware: text styles come from
/// `Theme.of(context).textTheme`; the retry button uses
/// the active `FilledButton` theme. Dark + light themes
/// both render correctly.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel,
  });

  /// The error headline. Required. M3 `bodyLarge`.
  final String message;

  /// The retry callback. Typically `setState(() { _future =
  /// _load(); })` to re-fire the FutureBuilder.
  final VoidCallback onRetry;

  /// Optional override for the retry button label. Defaults
  /// to `l.homeRetryButton` (the project's localized
  /// "Retry" string).
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: theme.textTheme.bodyLarge),
            const SizedBox(height: Spacing.md),
            FilledButton(
              key: const ValueKey('error.retry'),
              onPressed: onRetry,
              child: Text(retryLabel ?? l.homeRetryButton),
            ),
          ],
        ),
      ),
    );
  }
}
