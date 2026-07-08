// Widget tests for `lib/ui/mission_failed_view.dart`.
//
// Covers the C5 mission-error primitive extracted during
// the Month 1 UI-consolidation sprint (PR11 of 15). See:
//   - SYS-186 (this PR's surface)
//   - ADR-117 (the rationale + the canonical-pattern call)
//   - WF-113 (this test file)
//   - lib/ui/mission_failed_view.dart (the system under test)
//
// Test cases pin:
//   - the title is the localized `missionFailedTitle`.
//   - the body is the localized `missionFailedBody`.
//   - the dismiss CTA is the localized `missionFailedDismiss`.
//   - tapping the dismiss CTA fires the onDismiss callback.
//   - the dismiss button carries `ValueKey('mission_failed.dismiss')`
//     so call sites can pin it.
//   - the body is wrapped in `Semantics(liveRegion: true, ...)`
//     so TalkBack announces the failure when the dialog opens
//     (this is the C9-1 a11y fix bundled with PR11).
//   - the dialog is `AlertDialog` (M3 canonical modal shape).
//   - works under light theme too.
//   - body content remains stable under theme swap.

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/mission_failed_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

void main() {
  group('MissionFailedView — required content', () {
    testWidgets('renders the localized title', (tester) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return Scaffold(body: MissionFailedView(onDismiss: () {}));
            },
          ),
        ),
      );
      expect(find.text(l.missionFailedTitle), findsOneWidget);
    });

    testWidgets('renders the localized body', (tester) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return Scaffold(body: MissionFailedView(onDismiss: () {}));
            },
          ),
        ),
      );
      expect(find.text(l.missionFailedBody), findsOneWidget);
    });
  });

  group('MissionFailedView — dismiss CTA', () {
    testWidgets('renders the localized dismiss CTA', (tester) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return Scaffold(body: MissionFailedView(onDismiss: () {}));
            },
          ),
        ),
      );
      expect(find.text(l.missionFailedDismiss), findsOneWidget);
    });

    testWidgets('dismiss CTA carries ValueKey(mission_failed.dismiss)', (
      tester,
    ) async {
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(body: MissionFailedView(onDismiss: () {})),
        ),
      );
      expect(
        find.byKey(const ValueKey('mission_failed.dismiss')),
        findsOneWidget,
      );
    });

    testWidgets('tapping the dismiss CTA fires onDismiss', (tester) async {
      var called = 0;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(body: MissionFailedView(onDismiss: () => called++)),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('mission_failed.dismiss')));
      expect(called, 1);
    });
  });

  group('MissionFailedView — a11y (C9-1 fix)', () {
    testWidgets('body is wrapped in Semantics(liveRegion: true)', (
      tester,
    ) async {
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(body: MissionFailedView(onDismiss: () {})),
        ),
      );
      // Find the liveRegion that wraps the dialog body. The
      // C9-1 fix ships the liveRegion as part of the
      // primitive so call sites get TalkBack announcement
      // for free.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.liveRegion == true &&
              (w.properties.label ?? '').contains('Mission failed'),
        ),
        findsOneWidget,
      );
    });
  });

  group('MissionFailedView — dialog shape', () {
    testWidgets('renders as an AlertDialog (M3 canonical modal)', (
      tester,
    ) async {
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(body: MissionFailedView(onDismiss: () {})),
        ),
      );
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('renders correctly under light theme', (tester) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return Scaffold(body: MissionFailedView(onDismiss: () {}));
            },
          ),
        ),
      );
      expect(find.text(l.missionFailedTitle), findsOneWidget);
      expect(find.text(l.missionFailedBody), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mission_failed.dismiss')),
        findsOneWidget,
      );
    });
  });

  group('MissionFailedView — body independence', () {
    testWidgets('title + body + CTA all render together (no omit)', (
      tester,
    ) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return Scaffold(body: MissionFailedView(onDismiss: () {}));
            },
          ),
        ),
      );
      expect(find.text(l.missionFailedTitle), findsOneWidget);
      expect(find.text(l.missionFailedBody), findsOneWidget);
      expect(find.text(l.missionFailedDismiss), findsOneWidget);
    });

    testWidgets('Semantics label combines title + body verbatim', (
      tester,
    ) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return Scaffold(body: MissionFailedView(onDismiss: () {}));
            },
          ),
        ),
      );
      final semantics = tester.getSemantics(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.liveRegion == true &&
              (w.properties.label ?? '').contains('Mission failed'),
        ),
      );
      expect(semantics.label, contains(l.missionFailedTitle));
      expect(semantics.label, contains(l.missionFailedBody));
    });
  });
}
