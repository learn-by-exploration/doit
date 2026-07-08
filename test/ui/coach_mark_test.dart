// Widget tests for `lib/ui/coach_mark.dart`.
//
// The post-onboarding coach-mark tour primitive (v1.8-pr-b /
// SYS-191 / ADR-122 / WF-118). Covers:
//   - the per-step `CoachMarkOverlay` renders the title + body
//     verbatim (the M3 Card with the localized strings).
//   - the Next + Skip CTAs render with the canonical
//     `ValueKey('tour.next')` / `ValueKey('tour.skip')`.
//   - Next on the last step pops the route with `true`.
//   - Skip pops the route with `false`.
//   - the multi-step `CoachMarkController.start` walks both
//     steps in order (each pops before the next opens).
//   - a step's `onAdvance` hook fires when Next is tapped,
//     BEFORE the route pops (the contract for inter-step
//     navigation).
//   - the callout Card is wrapped in
//     `Semantics(liveRegion: true, label: tourBubbleAriaLabel)`
//     so TalkBack announces the step when the overlay opens.
//   - the `targetKey` rect lookup is robust to a missing
//     target (falls back to the top of the screen).

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/coach_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

void main() {
  group('CoachMarkOverlay — required content', () {
    testWidgets('renders the title verbatim', (tester) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return Scaffold(
                body: CoachMarkOverlay(
                  step: TourStep(
                    targetKey: GlobalKey(),
                    title: l.tourStep1Title,
                    body: l.tourStep1Body,
                  ),
                  isLast: false,
                ),
              );
            },
          ),
        ),
      );
      expect(find.text(l.tourStep1Title), findsOneWidget);
    });

    testWidgets('renders the body verbatim', (tester) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return Scaffold(
                body: CoachMarkOverlay(
                  step: TourStep(
                    targetKey: GlobalKey(),
                    title: l.tourStep1Title,
                    body: l.tourStep1Body,
                  ),
                  isLast: false,
                ),
              );
            },
          ),
        ),
      );
      expect(find.text(l.tourStep1Body), findsOneWidget);
    });
  });

  group('CoachMarkOverlay — CTAs', () {
    testWidgets('renders Next CTA with ValueKey(tour.next)', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: CoachMarkOverlay(
              step: TourStep(
                targetKey: GlobalKey(),
                title: 'Step 1',
                body: 'Body 1',
              ),
              isLast: false,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('tour.next')), findsOneWidget);
    });

    testWidgets('renders Skip CTA with ValueKey(tour.skip)', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: CoachMarkOverlay(
              step: TourStep(
                targetKey: GlobalKey(),
                title: 'Step 1',
                body: 'Body 1',
              ),
              isLast: false,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('tour.skip')), findsOneWidget);
    });

    testWidgets('last step renders "Done" instead of "Next" (tourDone ARB)', (
      tester,
    ) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return Scaffold(
                body: CoachMarkOverlay(
                  step: TourStep(
                    targetKey: GlobalKey(),
                    title: 'Step 2',
                    body: 'Body 2',
                  ),
                  isLast: true,
                ),
              );
            },
          ),
        ),
      );
      // The Next button (ValueKey tour.next) renders the
      // Done label on the last step.
      final nextFinder = find.byKey(const ValueKey('tour.next'));
      expect(nextFinder, findsOneWidget);
      final text = tester.widget<Text>(
        find.descendant(of: nextFinder, matching: find.byType(Text)),
      );
      expect(text.data, l.tourDone);
    });
  });

  group('CoachMarkOverlay — a11y (liveRegion)', () {
    testWidgets('callout is wrapped in Semantics(liveRegion: true, label: '
        'tourBubbleAriaLabel)', (tester) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return Scaffold(
                body: CoachMarkOverlay(
                  step: TourStep(
                    targetKey: GlobalKey(),
                    title: 'Step 1',
                    body: 'Body 1',
                  ),
                  isLast: false,
                ),
              );
            },
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.liveRegion == true &&
              (w.properties.label ?? '').contains('Step 1'),
        ),
        findsOneWidget,
      );
      // The aria-label combines title + body verbatim.
      final semantics = tester.getSemantics(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.liveRegion == true &&
              (w.properties.label ?? '').contains('Step 1'),
        ),
      );
      expect(semantics.label, l.tourBubbleAriaLabel('Step 1', 'Body 1'));
    });
  });

  group('CoachMarkController — multi-step', () {
    testWidgets(
      'controller walks N steps in order, each pops before the next',
      (tester) async {
        final visits = <int>[];
        final navObserver = _NavObserver(
          onPushed: (route) {
            if (route is MaterialPageRoute<bool>) {
              visits.add(route.settings.name?.hashCode ?? 0);
            }
          },
        );

        await tester.pumpWidget(
          localizedApp(
            theme: AppTheme.dark,
            navigatorObservers: [navObserver],
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        // Fire-and-forget; the test pops the
                        // routes manually below.
                        // ignore: unawaited_futures
                        CoachMarkController.start(context, [
                          TourStep(
                            targetKey: GlobalKey(),
                            title: 'Step 1',
                            body: 'Body 1',
                          ),
                          TourStep(
                            targetKey: GlobalKey(),
                            title: 'Step 2',
                            body: 'Body 2',
                          ),
                        ]);
                      },
                      child: const Text('Start'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('Start'));
        await tester.pumpAndSettle();

        // Step 1 overlay is mounted.
        expect(find.text('Step 1'), findsOneWidget);

        // Tap Next → step 1 pops, step 2 mounts.
        await tester.tap(find.byKey(const ValueKey('tour.next')));
        await tester.pumpAndSettle();
        expect(find.text('Step 1'), findsNothing);
        expect(find.text('Step 2'), findsOneWidget);

        // Tap Next on the last step → tour ends (no more
        // overlays mounted).
        await tester.tap(find.byKey(const ValueKey('tour.next')));
        await tester.pumpAndSettle();
        expect(find.text('Step 2'), findsNothing);
      },
    );

    testWidgets('step onAdvance hook fires when Next is tapped, BEFORE the '
        'route pops (the contract for inter-step navigation)', (tester) async {
      var advancedCalled = false;
      var popHappenedAfterAdvance = false;

      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: CoachMarkOverlay(
                  step: TourStep(
                    targetKey: GlobalKey(),
                    title: 'Step 1',
                    body: 'Body 1',
                    onAdvance: () async {
                      advancedCalled = true;
                      // After this hook returns, the route
                      // is popped by the overlay (mounted
                      // check is in place). We assert that
                      // the overlay has not popped yet.
                      popHappenedAfterAdvance = find
                          .byKey(const ValueKey('tour.next'))
                          .evaluate()
                          .isNotEmpty;
                    },
                  ),
                  isLast: true,
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('tour.next')));
      await tester.pumpAndSettle();
      expect(advancedCalled, isTrue);
      // The overlay route was popped AFTER the onAdvance
      // hook completed (the Next button was still on
      // screen when the hook ran, which means the route
      // had not been popped yet).
      expect(popHappenedAfterAdvance, isTrue);
      // The overlay itself is gone.
      expect(find.text('Step 1'), findsNothing);
    });

    testWidgets('Skip pops with false → controller returns early', (
      tester,
    ) async {
      final navObserver = _NavObserver();

      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          navigatorObservers: [navObserver],
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      // ignore: unawaited_futures
                      CoachMarkController.start(context, [
                        TourStep(
                          targetKey: GlobalKey(),
                          title: 'Step 1',
                          body: 'Body 1',
                        ),
                        TourStep(
                          targetKey: GlobalKey(),
                          title: 'Step 2',
                          body: 'Body 2',
                        ),
                      ]);
                    },
                    child: const Text('Start'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1'), findsOneWidget);

      // Tap Skip → step 1 pops with `false`; the controller
      // returns early so step 2 never mounts.
      await tester.tap(find.byKey(const ValueKey('tour.skip')));
      await tester.pumpAndSettle();
      expect(find.text('Step 1'), findsNothing);
      expect(find.text('Step 2'), findsNothing);
    });
  });
}

class _NavObserver extends NavigatorObserver {
  _NavObserver({this.onPushed});
  final void Function(Route<dynamic>)? onPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onPushed?.call(route);
    super.didPush(route, previousRoute);
  }
}
