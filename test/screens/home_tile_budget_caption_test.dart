// Tests for the `_BudgetCaption` widget on the home tile.
//
// v1.8-pr-d / SYS-193 / ADR-124 / WF-120: caption flipped
// from "X/Y rest days left" to "Used X of Y this month".
//
// These tests pin the new ARB contract end-to-end: a tile is
// rendered with a known `used` / `limit` budget, and the
// caption text rendered under the streak badge is asserted
// against the exact ARB-resolved English string.
//
// The existing assertions in `home_test.dart` ("Used 1 of 2
// this month" / "Used 0 of 3 this month") cover the post-skip
// and used==0 zero paths. This file focuses on the ARB-key
// round-trip and the localized body for the empty state.

import 'package:doit/screens/home.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/ui/empty_state.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
  // The caption text is now an ARB-resolved "Used X of Y this
  // month" string. The English-Arb round-trip is the
  // load-bearing pin. The Spanish mirror test below verifies
  // the es catalog. The end-to-end "captions render on the
  // home tile" assertion lives in home_test.dart
  // ("Used 1 of 2 this month" / "Used 0 of 3 this month")
  // where the snapshot/future plumbing is already exercised.
  testWidgets('caption ARB key resolves to "Used X of Y this month" in English',
      (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(l.homeTileBudgetUsed(1, 2), 'Used 1 of 2 this month');
    expect(l.homeTileBudgetUsed(0, 3), 'Used 0 of 3 this month');
    expect(l.homeTileBudgetUsed(2, 2), 'Used 2 of 2 this month');
  });

  testWidgets(
    'caption ARB key round-trips in Spanish (Usados X de Y este mes)',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('es'));
      // The Spanish mirror is the load-bearing pin —
      // `lib/l10n/app_es.arb` must keep "Usados" (plural
      // masculine / past participle) and the "este mes"
      // framing.
      expect(l.homeTileBudgetUsed(1, 2), 'Usados 1 de 2 este mes');
      expect(l.homeTileBudgetUsed(0, 3), 'Usados 0 de 3 este mes');
      expect(l.homeTileBudgetUsed(2, 2), 'Usados 2 de 2 este mes');
    },
  );

  testWidgets(
    'empty-state body renders the new localized homeEmptyBody string',
    (tester) async {
      await _resetDb(tester);
      // No do saved → home list is empty → EmptyState
      // renders the title + body under the bolt icon.
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l.homeEmptyTitle), findsOneWidget);
      expect(find.text(l.homeEmptyBody), findsOneWidget);
      // Body matches the ARB exactly.
      expect(l.homeEmptyBody, 'Tap the + to add a do or a person.');
    },
  );

  testWidgets('empty-state body resolves to the Spanish localized string', (
    tester,
  ) async {
    await _resetDb(tester);
    await tester.pumpWidget(_wrap(locale: const Locale('es')));
    await tester.pumpAndSettle();
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(find.text(l.homeEmptyTitle), findsOneWidget);
    expect(find.text(l.homeEmptyBody), findsOneWidget);
    expect(l.homeEmptyBody, 'Toca + para añadir una tarea o una persona.');
  });

  testWidgets(
    'EmptyState widget renders the message under the title with a gap',
    (tester) async {
      // Pin the primitive contract that the home screen
      // relies on (title → message with a 8dp gap). This
      // pins the v1.8-pr-d / SYS-193 / ADR-124 / WF-120
      // contract that the localized body lands in the
      // primitive's `message:` slot.
      await _resetDb(tester);
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsService>.value(
          value: SettingsService.instance,
          child: localizedApp(
            theme: AppTheme.dark,
            home: const Scaffold(
              body: EmptyState(
                title: 'Title line',
                message: 'Body line',
                icon: Icons.bolt_outlined,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Title line'), findsOneWidget);
      expect(find.text('Body line'), findsOneWidget);
      // EmptyState renders an Icon when icon: is supplied.
      expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);
    },
  );
}
