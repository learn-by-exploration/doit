// Routine overlay screen — the banner UI for routine-fired
// full-screen overlay launches.
//
// v1.3d / Phase 15 / SYS-114 / ADR-044. Lives in
// `lib/screens/` (NOT in `lib/routines/`) per
// `.claude/rules/lib-screens.md` — the routine engine
// itself is in `lib/routines/`. This widget is the
// user-visible surface for the routine-fired FSI launch.
//
// Surface:
//
//   The widget reads `title` / `body` from
//   `RouteSettings.arguments` (set by the Kotlin
//   `FullScreenActivity.getInitialRoute()` query-string
//   parser in `lib/main.dart`'s `onGenerateRoute`).
//   `null` / empty values fall back to a generic
//   "Routine alert" headline and a short explanation.
//
// Lifecycle:
//
//   The widget is mounted by `onGenerateRoute` when the
//   initial route is
//   `/mission?mode=overlay&title=...&body=...`. A single
//   "Dismiss" button at the bottom pops with `null` (the
//   routine executor has already published `AutomationFired`
//   so no further Dart-side action is needed).

import 'package:flutter/material.dart';

import 'package:doit/theme/app_theme.dart';

/// v1.3d / Phase 15 / SYS-114 / ADR-044. Banner widget
/// for the routine-fired full-screen overlay path.
class RoutineOverlayScreen extends StatelessWidget {
  const RoutineOverlayScreen({super.key, this.title, this.body});

  /// Optional headline from the launch intent. Falls back
  /// to "Routine alert" if `null` or empty.
  final String? title;

  /// Optional body text from the launch intent. Falls
  /// back to a short explanation if `null` or empty.
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = (title == null || title!.isEmpty)
        ? 'Routine alert'
        : title!;
    final detail = (body == null || body!.isEmpty)
        ? 'A routine fired and wants your attention.'
        : body!;
    return Scaffold(
      // The translucent + brand-color surface matches
      // the v1.2f overlay design comment in
      // `lib/services/platform_full_screen_intent.dart`
      // (the activity floats above the lockscreen; the
      // user dismisses with one tap).
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: Text(headline)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Spacing.xl),
              Text(detail, style: theme.textTheme.bodyLarge),
              const Spacer(),
              // Per .claude/rules/lib-screens.md, every
              // interactive element has a `Semantics`
              // label. Wrap the dismiss button in
              // `Semantics(button: true, label: ...)` so
              // TalkBack reads "Dismiss routine overlay,
              // button" instead of just "Dismiss".
              Semantics(
                button: true,
                label: 'Dismiss routine overlay',
                // 64dp tap target (parity with the
                // mission primary action).
                child: FilledButton(
                  key: const ValueKey('routineOverlay.dismiss'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(Sizing.tapPrimary),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
