// Tests for the DoAnchorTargetPausedBadge widget. v1.4-stab-G /
// Phase 47 / SYS-134 / ADR-065 / WF-062.
//
// The badge is a *pure-presentational* widget — it takes the
// resolved target habit (the parent does the lookup) and
// self-gates on `target.isDeleted`. We test the 6
// behaviors from ADR-065:
//   1. Renders when target is tombstoned.
//   2. Hides when target is active (no deletedAt).
//   3. Hides when target is null.
//   4. Semantics label is present (TalkBack).
//   5. Uses Theme.of(context).colorScheme.tertiary.
//   6. Color contrast against surface meets WCAG 4.5:1.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/widgets/do_anchor_paused_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en'), Locale('es')],
  home: Scaffold(body: child),
);

/// Minimal `Do` fixture — the badge only reads `isDeleted`
/// (a getter on the base `Do` class). We extend the
/// concrete `DoFixed` because `Do` is `sealed`.
DoFixed _stub({DateTime? deletedAt, String id = 'h-stub'}) {
  return DoFixed(
    id: id,
    name: 'stub',
    proofMode: const SoftProof(),
    createdAt: DateTime.utc(2026, 1, 15),
    restDaysPerMonth: 2,
    weekdays: const {1}, // 1 = Monday (DateTime convention).
    time: const DoTime(9, 0),
    deletedAt: deletedAt,
  );
}

double relativeLuminance(Color c) {
  double channel(double v) {
    if (v <= 0.03928) {
      return v / 12.92;
    }
    final t = (v + 0.055) / 1.055;
    return t * t * t;
  }

  final r = channel(c.r);
  final g = channel(c.g);
  final b = channel(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrast(Color a, Color b) {
  final la = relativeLuminance(a) + 0.05;
  final lb = relativeLuminance(b) + 0.05;
  return la > lb ? la / lb : lb / la;
}

void main() {
  testWidgets('renders the badge label when target is tombstoned', (
    tester,
  ) async {
    final deleted = _stub(deletedAt: DateTime(2026, 6));
    await tester.pumpWidget(
      _wrap(DoAnchorTargetPausedBadge(habitId: 'h-anchor-1', target: deleted)),
    );
    await tester.pump();
    final l = AppLocalizations.of(
      tester.element(find.byType(DoAnchorTargetPausedBadge)),
    );
    expect(find.text(l.doAnchorTargetPaused), findsOneWidget);
    // The KeyedSubtree test seam — ADR-065.
    expect(
      find.byKey(const Key('doAnchorTargetPaused-h-anchor-1')),
      findsOneWidget,
    );
  });

  testWidgets('hides when target is active (no deletedAt)', (tester) async {
    final active = _stub();
    await tester.pumpWidget(
      _wrap(DoAnchorTargetPausedBadge(habitId: 'h-anchor-2', target: active)),
    );
    await tester.pump();
    final l = AppLocalizations.of(
      tester.element(find.byType(DoAnchorTargetPausedBadge)),
    );
    expect(find.text(l.doAnchorTargetPaused), findsNothing);
    expect(
      find.byKey(const Key('doAnchorTargetPaused-h-anchor-2')),
      findsNothing,
    );
  });

  testWidgets('hides when target is null', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const DoAnchorTargetPausedBadge(
          habitId: 'h-anchor-3',
          // target is null by default — the common case
          // for non-`DoAnchor` tiles.
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('doAnchorTargetPaused-h-anchor-3')),
      findsNothing,
    );
  });

  testWidgets('Semantics wrapper exposes the localized label (TalkBack)', (
    tester,
  ) async {
    final deleted = _stub(deletedAt: DateTime(2026, 6));
    await tester.pumpWidget(
      _wrap(DoAnchorTargetPausedBadge(habitId: 'h-anchor-4', target: deleted)),
    );
    await tester.pump();
    final l = AppLocalizations.of(
      tester.element(find.byType(DoAnchorTargetPausedBadge)),
    );
    // The badge renders a `Semantics(label: l.doAnchorTargetPaused)` wrapper
    // so TalkBack announces the localized label. We verify the Semantics
    // wrapper exists and walks its `properties.label` to assert the value.
    final semanticsWidgets = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .toList();
    final hasLocalizedLabel = semanticsWidgets.any(
      (s) => s.properties.label == l.doAnchorTargetPaused,
    );
    expect(
      hasLocalizedLabel,
      isTrue,
      reason:
          'TalkBack label "${l.doAnchorTargetPaused}" expected on a Semantics widget',
    );
  });

  testWidgets(
    'uses Theme.of(context).colorScheme.tertiary (no hard-coded color)',
    (tester) async {
      final deleted = _stub(deletedAt: DateTime(2026, 6));
      late ThemeData capturedTheme;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: Builder(
            builder: (context) {
              capturedTheme = Theme.of(context);
              return Scaffold(
                body: DoAnchorTargetPausedBadge(
                  habitId: 'h-anchor-5',
                  target: deleted,
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.link_off));
      expect(iconWidget.color, capturedTheme.colorScheme.tertiary);
    },
  );

  testWidgets('color contrast against surface meets WCAG 4.5:1', (
    tester,
  ) async {
    final deleted = _stub(deletedAt: DateTime(2026, 6));
    late ColorScheme scheme;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        home: Builder(
          builder: (context) {
            scheme = Theme.of(context).colorScheme;
            return Scaffold(
              body: DoAnchorTargetPausedBadge(
                habitId: 'h-anchor-6',
                target: deleted,
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    final ratio = contrast(scheme.tertiary, scheme.surface);
    expect(ratio, greaterThanOrEqualTo(4.5));
  });
}
