// Tests for the "Show me around" CTA on the home empty state.
//
// v1.8-pr-b / SYS-191 / ADR-122 / WF-118: the home empty
// state surfaces a `PrimaryButton` (rendered via
// `EmptyState.action`) when `SettingsService.tourSeen == false`,
// and hides it once the user has completed the tour.
//
// The CTA renders the localized `homeEmptyTourCta` label (e.g.,
// "Show me around" in en, "Muéstrame el tour" in es) and is
// pinned by `ValueKey('home.empty.tour_cta')` so the test can
// tap it deterministically without depending on the label text.
//
// These tests pin:
//   1. Empty state shows the "Show me around" CTA when the
//      user has never completed the tour.
//   2. Empty state hides the CTA once tourSeen flips to true
//      (the ValueListenableBuilder reacts).
//   3. The CTA renders in Spanish when the locale is `es`.
//   4. Tapping the CTA starts the tour (verified by waiting for
//      a CoachMarkOverlay route to push).
//
// Why a separate file from `home_test.dart`: the existing
// home_test.dart is large and focused on tile rendering. The
// tour CTA is a discrete surface; isolating its tests keeps the
// failure surface small and the assertions focused.

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/screens/home.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/coach_mark.dart';
import 'package:doit/ui/empty_state.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized_app.dart';

Future<void> _resetDb(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });
}

Widget _wrap({Locale locale = const Locale('en')}) {
  return ChangeNotifierProvider<SettingsService>.value(
    value: SettingsService.instance,
    child: localizedApp(
      theme: AppTheme.dark,
      home: const HomeScreen(),
      locale: locale,
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();
  });

  tearDown(SettingsService.instance.resetForTesting);

  testWidgets(
    'empty state shows the "Show me around" CTA when tourSeen=false',
    (tester) async {
      await _resetDb(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // No habits → EmptyState renders.
      expect(find.byType(EmptyState), findsOneWidget);
      // The CTA carries the canonical ValueKey.
      expect(find.byKey(const ValueKey('home.empty.tour_cta')), findsOneWidget);
    },
  );

  testWidgets('empty state hides the CTA when tourSeen=true (the notifier '
      'reacts)', (tester) async {
    await _resetDb(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home.empty.tour_cta')), findsOneWidget);

    // Flip tourSeen to true (simulates the user having
    // completed the tour). The ValueListenableBuilder
    // must rebuild and drop the CTA.
    SettingsService.instance.tourSeen.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home.empty.tour_cta')), findsNothing);
  });

  testWidgets('empty-state CTA renders the localized label in Spanish', (
    tester,
  ) async {
    await _resetDb(tester);
    await tester.pumpWidget(_wrap(locale: const Locale('es')));
    await tester.pumpAndSettle();

    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(find.byKey(const ValueKey('home.empty.tour_cta')), findsOneWidget);
    // The Spanish label must be rendered (the exact
    // copy is in app_es.arb). The test pins the
    // round-trip, not the copy.
    expect(find.text(l.homeEmptyTourCta), findsOneWidget);
  });

  testWidgets('tapping the CTA starts the tour (CoachMarkOverlay mounts)', (
    tester,
  ) async {
    await _resetDb(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // Tap the CTA. Step 1 of the tour mounts with a
    // localized title — the test pins the tour start
    // by the overlay's known title.
    await tester.tap(find.byKey(const ValueKey('home.empty.tour_cta')));
    await tester.pumpAndSettle();

    // The overlay mounted. We don't pin the literal
    // title (l10n may change) — instead we pin the
    // "tour" semantic: the Next CTA exists with its
    // canonical ValueKey.
    expect(find.byType(CoachMarkOverlay), findsOneWidget);
    expect(find.byKey(const ValueKey('tour.next')), findsOneWidget);
    expect(find.byKey(const ValueKey('tour.skip')), findsOneWidget);
  });
}
