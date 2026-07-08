// Post-onboarding coach-mark tour primitive (v1.8-pr-b /
// SYS-191 / ADR-122 / WF-118).
//
// A 2-step (or N-step) guided tour shown after the user
// finishes onboarding. The user is walked through the home
// FAB and the schedule picker on the add-habit screen, with
// a "Skip" affordance on every step.
//
// API:
//   - `TourStep({required GlobalKey targetKey, required
//     String title, required String body})` — the
//     declaration of one step.
//   - `CoachMarkController.start(BuildContext context,
//     List<TourStep> steps)` — a static helper that
//     pushes a `MaterialPageRoute` per step in order. A
//     step pops with `true` when the user taps Next
//     (controller advances to the next step) and `false`
//     when the user taps Skip (controller aborts the
//     tour). After the last step, the controller
//     returns silently.
//   - `CoachMarkOverlay` — the per-step widget. Renders a
//     full-screen scrim + a positioned callout Card with
//     title + body + Next + Skip. v1 does NOT cut out the
//     target with `BlendMode.clear` (the scrim covers
//     everything at 54% opacity; the callout text names
//     the target so the user can find it). A future
//     v1.8-pr-b+1 PR may add the cutout via a
//     `CustomPaint` that uses `BlendMode.clear` for the
//     inner rect; flagged in ADR-122 as a follow-up.
//
// Per `lib/ui/` invariants (see .claude/rules/services.md
// and the design-system PRD):
//   - All colors from `Theme.of(context).colorScheme`.
//   - 48dp minimum touch target on every CTA
//     (Next + Skip use `FilledButton` / `TextButton` which
//     inherit the `filledButtonTheme.minimumSize: Size(0,
//     48)` from `app_theme.dart:233-237`).
//   - `Semantics(liveRegion: true, ...)` wraps the
//     callout Card so TalkBack announces the new step
//     when the user advances.
//
// Test surface (see
// `test/ui/coach_mark_test.dart`):
//   - renders the title + body verbatim
//   - Next + Skip CTAs render with the canonical
//     `ValueKey('tour.next')` / `ValueKey('tour.skip')`
//   - Next on the last step pops the controller with
//     `true` (and the controller returns)
//   - Skip pops the controller with `false` (and the
//     controller returns)
//   - 2-step controller walks both steps in order
//   - the target's rect is computed from the
//     `GlobalKey` (if present in the tree); if absent,
//     the callout falls back to the top of the screen
//     (the controller is robust to a missing target
//     so tests don't have to mount the target widget).

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// A single step in the post-onboarding coach-mark tour.
///
/// [targetKey] is the `GlobalKey` of the widget the user
/// should look at for this step. The overlay uses the
/// key to compute the target's on-screen rect and
/// positions the callout directly below (or above) it.
///
/// [title] is the short heading (e.g., "Add your first
/// do"). [body] is the longer explanation (e.g., "Tap the
/// + button to create a do, a person, or a template.").
///
/// [onAdvance] is an optional async hook called when the
/// user taps Next, BEFORE the step's route is popped. The
/// hook lets the caller navigate to a different screen
/// between steps (e.g., step 1 on home → push
/// `AddHabitScreen` → step 2 on the schedule picker).
/// The hook is `await`-ed so the navigation completes
/// before the next overlay is mounted.
class TourStep {
  const TourStep({
    required this.targetKey,
    required this.title,
    required this.body,
    this.onAdvance,
  });

  /// `GlobalKey` of the widget the user should look at.
  /// If the key's `currentContext` is `null` at render
  /// time (e.g., the test mounts the overlay without
  /// mounting the target), the overlay falls back to
  /// positioning the callout at the top of the screen.
  final GlobalKey targetKey;

  /// Short heading. Rendered as the callout's title.
  final String title;

  /// Longer explanation. Rendered as the callout's body.
  final String body;

  /// Optional async hook fired on Next (before the
  /// step pops). Used to navigate between steps that
  /// live on different screens. The route is only
  /// popped after the hook's future resolves (and the
  /// widget is still mounted — guarded).
  final Future<void> Function()? onAdvance;
}

/// Manages the multi-step coach-mark queue.
///
/// The v1 API is a single static helper, [start], that
/// walks the steps in order. Each step pushes its own
/// `MaterialPageRoute`; the route pops with `true` to
/// advance to the next step, `false` to abort the tour
/// (Skip CTA). After the last step, the controller
/// returns silently. The controller does NOT own a
/// `tourSeen` flag — that lives on `SettingsService` (the
/// caller is responsible for calling
/// `SettingsService.instance.markTourSeen()` after the
/// tour completes).
abstract final class CoachMarkController {
  /// Walk [steps] in order. Returns when the user
  /// finishes the last step (Next) or taps Skip on any
  /// step. Does not throw if [steps] is empty (returns
  /// immediately).
  static Future<void> start(BuildContext context, List<TourStep> steps) async {
    for (var i = 0; i < steps.length; i++) {
      final advanced = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          fullscreenDialog: true,
          // The overlay renders its own Scaffold so the
          // route must NOT contribute a back button. The
          // `fullscreenDialog: true` flag also gives the
          // route a "modal" feel (slides up from the
          // bottom on Android, matches the platform
          // tutorial pattern).
          builder: (_) =>
              CoachMarkOverlay(step: steps[i], isLast: i == steps.length - 1),
        ),
      );
      if (advanced != true) return; // User skipped.
    }
  }
}

/// The per-step widget. Renders a scrim + a positioned
/// callout with title + body + Next + Skip.
class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({super.key, required this.step, required this.isLast});

  /// The step this overlay represents.
  final TourStep step;

  /// `true` if this is the last step in the queue (the
  /// Next CTA renders the "Done" string instead of
  /// "Next" and the controller returns after this step
  /// pops with `true`).
  final bool isLast;

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay> {
  /// The target widget's on-screen rect, computed on
  /// the first post-frame callback after mount. `null`
  /// means the target is not in the tree (e.g., the
  /// test mounted the overlay without the target).
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    // Compute the target's rect after the first frame
    // so the target's `RenderBox` is laid out. If the
    // target is not in the tree, leave `_targetRect` as
    // `null` and the build method will fall back to
    // placing the callout at the top of the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = widget.step.targetKey.currentContext;
      if (ctx == null) return;
      final ro = ctx.findRenderObject();
      if (ro is! RenderBox) return;
      final topLeft = ro.localToGlobal(Offset.zero);
      setState(() {
        _targetRect = topLeft & ro.size;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final callout = _Callout(
      step: widget.step,
      isLast: widget.isLast,
      nextLabel: widget.isLast ? l.tourDone : l.tourNext,
      // v1.8-pr-b / SYS-191 / ADR-122 / WF-118:
      // await the step's `onAdvance` hook (if any)
      // BEFORE popping the overlay's route. The hook
      // is the contract for inter-step navigation
      // (e.g., step 1 on home → push AddHabitScreen
      // → step 2 on the schedule picker). Guarded
      // with `context.mounted` (not State's
      // `mounted`, which guards `setState`) because
      // the lint specifically tracks BuildContext
      // use across async gaps.
      onNext: () async {
        await widget.step.onAdvance?.call();
        if (!context.mounted) return;
        Navigator.of(context).pop(true);
      },
      onSkip: () => Navigator.of(context).pop(false),
    );
    return Scaffold(
      // The scrim is the `backgroundColor` — the body
      // is empty (the callout is rendered as a
      // `Positioned` widget in a `Stack`).
      backgroundColor: Colors.black54,
      body: Stack(
        children: [
          // The "look here" pointer + ring. v1 just
          // paints a thin white border around the
          // target's rect (no `BlendMode.clear` cutout
          // — the scrim covers everything at 54%
          // opacity; the callout text names the
          // target). A future v1.8-pr-b+1 PR may
          // upgrade this to a true cutout overlay.
          if (_targetRect != null)
            Positioned.fromRect(
              rect: _targetRect!,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          // The callout. Positioned below the target if
          // there is room; otherwise above; otherwise
          // centered. The card is `IgnorePointer`-free
          // (the user must be able to tap Next + Skip).
          _positionedCallout(context, callout, media),
        ],
      ),
    );
  }

  Widget _positionedCallout(
    BuildContext context,
    Widget callout,
    MediaQueryData media,
  ) {
    const margin = 16.0;
    const gap = 16.0;
    final rect = _targetRect;
    if (rect == null) {
      // Target not in the tree — fall back to the top
      // of the screen. The controller is robust to a
      // missing target so tests don't have to mount
      // the target widget.
      return Positioned(
        left: margin,
        right: margin,
        top: media.padding.top + margin,
        child: callout,
      );
    }
    final belowTop = rect.bottom + gap;
    final aboveBottom = media.size.height - rect.top + gap;
    const cardHeightEstimate = 200.0; // conservative
    if (belowTop + cardHeightEstimate < media.size.height) {
      return Positioned(
        left: margin,
        right: margin,
        top: belowTop,
        child: callout,
      );
    }
    if (rect.top - cardHeightEstimate - gap > media.padding.top) {
      return Positioned(
        left: margin,
        right: margin,
        bottom: aboveBottom,
        child: callout,
      );
    }
    // Fall back to the top.
    return Positioned(
      left: margin,
      right: margin,
      top: media.padding.top + margin,
      child: callout,
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.step,
    required this.isLast,
    required this.nextLabel,
    required this.onNext,
    required this.onSkip,
  });

  final TourStep step;
  final bool isLast;
  final String nextLabel;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      // liveRegion so TalkBack announces the new step
      // when the overlay opens (the user may not have
      // noticed the page-route transition).
      liveRegion: true,
      label: l.tourBubbleAriaLabel(step.title, step.body),
      child: Card(
        color: theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(step.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(step.body, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    // Canonical skip CTA — tour can be
                    // skipped on any step. Required by
                    // the a11y spec (see ADR-122 §Drift
                    // lessons (c)).
                    key: const ValueKey('tour.skip'),
                    onPressed: onSkip,
                    child: Text(l.tourSkip),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    // Canonical next/done CTA. The
                    // label switches from "Next" to
                    // "Done" on the last step (the
                    // caller passes the right string).
                    key: const ValueKey('tour.next'),
                    onPressed: onNext,
                    child: Text(nextLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
