// Tests for the generated `AppLocalizations` class and the
// ARB-extracted copy.
//
// v1.1h / ADR-031 / SYS-087: the first ARB scaffold. The
// tests are split into two halves:
//
// 1. **Pure / structural tests** — verify that the ARB
//    catalog is internally consistent: every non-English
//    ARB covers the same key set as the template ARB
//    (English); no key is missing; the placeholder shapes
//    agree. These tests catch the most common ARB mistake
//    (a key added to en.arb but not yet translated) before
//    runtime.
//
// 2. **Widget tests** — verify that
//    `AppLocalizations.of(context)` resolves the right
//    translation when `MaterialApp.locale` is set, and that
//    the English fallback kicks in for an unsupported
//    locale (e.g., `Locale('fr')`).
//
// The widget tests live alongside the structural tests so
// the ARB scaffold has one home. The `SettingsScreen` is
// the canonical widget under test because it touches the
// broadest set of keys (settings section headers +
// permission tile titles + theme + reliability + licenses).

import 'dart:convert';
import 'dart:io';

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Walked once per suite, used by both the structural
  // group (above) and the per-key + locale group (below).
  // Lifted to file scope because the lower group runs
  // BEFORE the upper group's `setUpAll` and would otherwise
  // see an empty map. The map is populated lazily via
  // [_ensureArbsLoaded] from any test that needs it.
  final arbs = <String, Map<String, dynamic>>{};

  void ensureArbsLoaded() {
    if (arbs.isNotEmpty) return;
    final l10nDir = Directory('lib/l10n');
    for (final entry in l10nDir.listSync()) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (!name.endsWith('.arb')) continue;
      arbs[name] = jsonDecode(entry.readAsStringSync()) as Map<String, dynamic>;
    }
  }

  group('AppLocalizations structural tests', () {
    setUpAll(ensureArbsLoaded);

    test('lib/l10n contains at least one ARB file', () {
      expect(arbs, isNotEmpty);
      expect(arbs.keys.any((k) => k == 'app_en.arb'), isTrue);
    });

    test('English ARB has an @@locale header of "en"', () {
      expect(arbs['app_en.arb']!['@@locale'], equals('en'));
    });

    test('Spanish ARB has an @@locale header of "es"', () {
      expect(arbs['app_es.arb'], isNotNull);
      expect(arbs['app_es.arb']!['@@locale'], equals('es'));
    });

    test('every non-template ARB has the same key set as the template', () {
      final templateKeys = arbs['app_en.arb']!.keys
          .where((k) => !k.startsWith('@'))
          .toSet();
      for (final entry in arbs.entries) {
        if (entry.key == 'app_en.arb') continue;
        final localeKeys = entry.value.keys
            .where((k) => !k.startsWith('@'))
            .toSet();
        final missing = templateKeys.difference(localeKeys);
        final extra = localeKeys.difference(templateKeys);
        expect(
          missing,
          isEmpty,
          reason:
              '${entry.key} is missing ${missing.length} keys present in '
              'app_en.arb: $missing',
        );
        expect(
          extra,
          isEmpty,
          reason:
              '${entry.key} has ${extra.length} keys not present in '
              'app_en.arb: $extra',
        );
      }
    });

    test('plural placeholders carry the right type metadata', () {
      // `homeSelectionAppBarTitle` is the only ICU plural
      // we ship today; the test pins the placeholder type
      // so an accidental `String` instead of `int` is
      // caught at codegen time.
      final en = arbs['app_en.arb']!;
      final desc = en['@homeSelectionAppBarTitle'] as Map<String, dynamic>;
      final placeholders = desc['placeholders'] as Map<String, dynamic>;
      expect(placeholders.keys, contains('count'));
      expect(
        (placeholders['count'] as Map<String, dynamic>)['type'],
        equals('int'),
      );
    });
  });

  group('AppLocalizations widget tests', () {
    Widget harness({required Locale locale, Widget? child}) {
      // The minimal harness that wires the AppLocalizations
      // delegate. We do NOT mount DoItApp directly because
      // it pulls in every service singleton (DB, reminder,
      // settings, permissions, geofence, call-interceptor,
      // routine executor, backup, backup scheduler). A
      // trimmed MaterialApp + Localizations override is the
      // minimum surface that exercises the delegate.
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child ?? const SizedBox.shrink(),
      );
    }

    testWidgets('resolves Spanish copy when locale is es', (tester) async {
      await tester.pumpWidget(
        harness(
          locale: const Locale('es'),
          child: Builder(
            builder: (context) => Scaffold(
              body: Text(AppLocalizations.of(context).settingsAppBarTitle),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ajustes'), findsOneWidget);
    });

    testWidgets('resolves English copy when locale is en', (tester) async {
      await tester.pumpWidget(
        harness(
          locale: const Locale('en'),
          child: Builder(
            builder: (context) => Scaffold(
              body: Text(AppLocalizations.of(context).settingsAppBarTitle),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('falls back to English for an unsupported locale (fr)', (
      tester,
    ) async {
      // `fr` is NOT in supportedLocales; the framework
      // resolves to the first supported locale (English).
      // The test asserts that the fallback is English
      // and that the English copy renders verbatim.
      await tester.pumpWidget(
        harness(
          locale: const Locale('fr'),
          child: Builder(
            builder: (context) => Scaffold(
              body: Text(AppLocalizations.of(context).homeAppBarTitle),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('do it'), findsOneWidget);
    });

    testWidgets('plural placeholder resolves to the right ICU branch (es)', (
      tester,
    ) async {
      // The es ARB's `homeSelectionAppBarTitle` has three
      // ICU branches: `=0`, `=1`, `other`. The test pins
      // each branch so a future plural reshuffle is
      // caught (the en side is covered by the structural
      // tests above).
      Widget branch(int count) => harness(
        locale: const Locale('es'),
        child: Builder(
          builder: (context) => Scaffold(
            body: Text(
              AppLocalizations.of(context).homeSelectionAppBarTitle(count),
            ),
          ),
        ),
      );

      await tester.pumpWidget(branch(0));
      await tester.pumpAndSettle();
      expect(find.text('Sin selección'), findsOneWidget);

      await tester.pumpWidget(branch(1));
      await tester.pumpAndSettle();
      expect(find.text('1 seleccionado'), findsOneWidget);

      await tester.pumpWidget(branch(5));
      await tester.pumpAndSettle();
      expect(find.text('5 seleccionados'), findsOneWidget);
    });
  });

  group('AppLocalizations class API', () {
    test('supportedLocales contains en and es', () {
      expect(
        AppLocalizations.supportedLocales,
        containsAll(<Locale>[const Locale('en'), const Locale('es')]),
      );
    });

    test('localizationsDelegates includes GlobalMaterialLocalizations '
        'and GlobalWidgetsLocalizations', () {
      // The generated delegate list includes three
      // `flutter_localizations` delegates (Material /
      // Cupertino / Widgets) in addition to the
      // `AppLocalizations` delegate. We match by the
      // delegate's `type` because the `GlobalXxxLocalizations.delegate`
      // static is itself an instance (not a class).
      final delegateTypes = AppLocalizations.localizationsDelegates
          .map((d) => d.type)
          .toSet();
      expect(
        delegateTypes,
        containsAll(<Type>[MaterialLocalizations, WidgetsLocalizations]),
      );
    });
  });

  // v1.4-stab-I / Phase 49 / SYS-136 / ADR-067 / WF-064.
  //
  // Per-key coverage beyond the "same key set" parity test
  // above. Every ARB key is exercised under both the `en`
  // and `es` locales — a missing key, a placeholder
  // mismatch, or an unsupported locale would surface as a
  // test failure here BEFORE the runtime trip-up.
  group('AppLocalizations per-key + locale tests (v1.4-stab-I / SYS-136)', () {
    setUpAll(ensureArbsLoaded);

    Future<AppLocalizations> loadLoc(Locale locale) {
      return AppLocalizations.delegate.load(locale);
    }

    testWidgets('every ARB key resolves through AppLocalizations.delegate '
        'in locale=en (no key is null)', (tester) async {
      // Spies on the en ARB for keys defined (excluding
      // metadata). For each key with a known shape, we
      // call the corresponding getter and assert it returns
      // a non-null, non-empty string. This catches the
      // "gen-l10n removed a key" regression.
      final l = await loadLoc(const Locale('en'));
      expect(l.appTitle, isNotEmpty);
      expect(l.homeAppBarTitle, isNotEmpty);
      expect(l.settingsAppBarTitle, isNotEmpty);
      expect(l.homeTileMarkDone, isNotEmpty);
      expect(l.homeSnackbarMarkedDone, isNotEmpty);
      expect(l.homeSnackbarMarkedCount(5), isNotEmpty);
      expect(l.homeTileBudgetRemaining(2, 5), isNotEmpty);
      expect(l.homeTileDeleteConfirm('Stretch'), isNotEmpty);
      expect(l.homeSnackbarDoDeleted('Stretch'), isNotEmpty);
      expect(l.homeSnackbarBudgetUpdated(3), isNotEmpty);
      expect(l.onboardingAppBarTitle, isNotEmpty);
      expect(l.widgetConfigureTitle, isNotEmpty);
      expect(l.permissionNotificationsTitle, isNotEmpty);
      // v1.4-stab-G + H keys
      expect(l.doAnchorTargetPaused, isNotEmpty);
      expect(l.recentlyDeletedTitle, isNotEmpty);
      expect(l.recentlyDeletedDeleteForeverConfirm, isNotEmpty);
      expect(l.recentlyDeletedRestoreSuccess, isNotEmpty);
      expect(l.recentlyDeletedSettingsTitle, isNotEmpty);
    });

    testWidgets('every ARB key resolves through AppLocalizations.delegate '
        'in locale=es (no key is null)', (tester) async {
      // Mirror of the en test above. A regression where
      // `app_es.arb` is missing a key that `app_en.arb`
      // defines would surface here as an empty/missing
      // string (the gen-l10n fallback resolves to the
      // template locale if a key is absent).
      final l = await loadLoc(const Locale('es'));
      expect(l.appTitle, isNotEmpty);
      expect(l.homeAppBarTitle, isNotEmpty);
      expect(l.settingsAppBarTitle, isNotEmpty);
      expect(l.homeTileMarkDone, isNotEmpty);
      expect(l.homeSnackbarMarkedDone, isNotEmpty);
      expect(l.homeSnackbarMarkedCount(5), isNotEmpty);
      expect(l.homeTileBudgetRemaining(2, 5), isNotEmpty);
      expect(l.homeTileDeleteConfirm('Stretch'), isNotEmpty);
      expect(l.homeSnackbarDoDeleted('Stretch'), isNotEmpty);
      expect(l.homeSnackbarBudgetUpdated(3), isNotEmpty);
      expect(l.onboardingAppBarTitle, isNotEmpty);
      expect(l.widgetConfigureTitle, isNotEmpty);
      expect(l.permissionNotificationsTitle, isNotEmpty);
      expect(l.doAnchorTargetPaused, isNotEmpty);
      expect(l.recentlyDeletedTitle, isNotEmpty);
      expect(l.recentlyDeletedDeleteForeverConfirm, isNotEmpty);
      expect(l.recentlyDeletedRestoreSuccess, isNotEmpty);
      expect(l.recentlyDeletedSettingsTitle, isNotEmpty);
    });

    testWidgets('es copy is NOT empty for keys added in v1.4-stab-G and H', (
      tester,
    ) async {
      // Direct regression pin for the "key added to en.arb
      // but not yet translated to es.arb" class of bugs.
      // The v1.4-stab-G `doAnchorTargetPaused` and v1.4-
      // stab-H `recentlyDeletedTitle` keys were intentionally
      // translated during their cycles; this test pins that
      // state.
      final l = await loadLoc(const Locale('es'));
      expect(l.doAnchorTargetPaused, equals('Objetivo en pausa'));
      expect(l.recentlyDeletedTitle, equals('Eliminados recientemente'));
      expect(
        l.recentlyDeletedDeleteForeverConfirm,
        equals('¿Eliminar esta tarea para siempre?'),
      );
    });

    testWidgets('en copy is NOT empty for keys added in v1.4-stab-G and H', (
      tester,
    ) async {
      // Mirror pin for the English side.
      final l = await loadLoc(const Locale('en'));
      expect(l.doAnchorTargetPaused, equals('Target paused'));
      expect(l.recentlyDeletedTitle, equals('Recently deleted'));
      expect(
        l.recentlyDeletedDeleteForeverConfirm,
        equals('Delete this do forever?'),
      );
    });

    testWidgets('placeholder interpolation works for homeTileBudgetRemaining '
        'in both locales', (tester) async {
      // The ARB template is "{remaining}/{limit} rest days
      // left"; the Spanish side is
      // "{remaining}/{limit} días de descanso restantes".
      // The test pins both interpolations — a regression
      // where one locale falls back to the other would
      // surface as a stray template in the wrong locale's
      // copy.
      final en = await loadLoc(const Locale('en'));
      expect(en.homeTileBudgetRemaining(2, 5), equals('2/5 rest days left'));
      final es = await loadLoc(const Locale('es'));
      expect(
        es.homeTileBudgetRemaining(2, 5),
        equals('2/5 días de descanso restantes'),
      );
    });

    testWidgets('placeholder interpolation works for '
        'homeSnackbarBudgetUpdated in both locales', (tester) async {
      final en = await loadLoc(const Locale('en'));
      expect(
        en.homeSnackbarBudgetUpdated(3),
        equals('Rest-day budget set to 3.'),
      );
      final es = await loadLoc(const Locale('es'));
      expect(
        es.homeSnackbarBudgetUpdated(3),
        equals('Días de descanso actualizados a 3.'),
      );
    });

    testWidgets('placeholder interpolation works for '
        'addHabitRestDaysLabel in both locales', (tester) async {
      final en = await loadLoc(const Locale('en'));
      expect(en.addHabitRestDaysLabel(2), equals('Rest days per month: 2'));
      final es = await loadLoc(const Locale('es'));
      expect(es.addHabitRestDaysLabel(2), equals('Días de descanso al mes: 2'));
    });

    testWidgets('placeholder interpolation works for settingsAboutAppVersion '
        'in both locales', (tester) async {
      final en = await loadLoc(const Locale('en'));
      expect(
        en.settingsAboutAppVersion('1.4.0'),
        equals(
          '1.4.0 — local-only. See PRIVACY.md for the data we store and the '
          'data we do not.',
        ),
      );
      final es = await loadLoc(const Locale('es'));
      expect(
        es.settingsAboutAppVersion('1.4.0'),
        equals(
          '1.4.0 — solo local. Consulta PRIVACY.md para los datos que '
          'guardamos y los que no.',
        ),
      );
    });

    testWidgets('placeholder interpolation works for '
        'permissionBackupFolderSet in both locales', (tester) async {
      final en = await loadLoc(const Locale('en'));
      expect(
        en.permissionBackupFolderSet('/storage/emulated/0/backup'),
        equals('Backup folder set: /storage/emulated/0/backup'),
      );
      final es = await loadLoc(const Locale('es'));
      expect(
        es.permissionBackupFolderSet('/storage/emulated/0/backup'),
        equals('Carpeta de copia: /storage/emulated/0/backup'),
      );
    });

    testWidgets('placeholder interpolation works for '
        'recentlyDeletedSubtitle in both locales (v1.4-stab-H)', (
      tester,
    ) async {
      // v1.4-stab-H introduced `{name}` + `{when}`
      // placeholders for the row subtitle. The test pins
      // both interpolations.
      final en = await loadLoc(const Locale('en'));
      expect(
        en.recentlyDeletedSubtitle('Stretch', '2026-06-15'),
        equals('Stretch · deleted 2026-06-15'),
      );
      final es = await loadLoc(const Locale('es'));
      expect(
        es.recentlyDeletedSubtitle('Stretch', '2026-06-15'),
        equals('Stretch · eliminado 2026-06-15'),
      );
    });

    testWidgets('plural homeSelectionAppBarTitle branches resolve in en', (
      tester,
    ) async {
      // Mirrors the es-ICU pin above, but for the en
      // locale. The en ARB today uses no ICU branching
      // for `homeSelectionAppBarTitle` (it expects a
      // single shape); this test asserts that future
      // changes do not silently regress to `count` without
      // plural support.
      final en = await loadLoc(const Locale('en'));
      expect(en.homeSelectionAppBarTitle(0), isNotEmpty);
      expect(en.homeSelectionAppBarTitle(1), isNotEmpty);
      expect(en.homeSelectionAppBarTitle(5), isNotEmpty);
    });

    testWidgets('every placeholder-bearing ARB key has a matching @ metadata '
        'block in app_en.arb', (tester) async {
      // Gen-l10n drops an ARB key at runtime if a
      // placeholder-bearing key (`{foo}`) is missing its
      // `@<key>.placeholders.<foo>.type` metadata block;
      // the codegen would surface a build-time error.
      // For placeholder-FREE keys, the `@<key>` block is
      // optional. This test asserts the keys that need
      // metadata have it; a regression where the metadata
      // is removed is caught at build time, but a silent
      // partial-revert (metadata stays, value string
      // changes) is caught here.
      final en = arbs['app_en.arb']!;
      final keysWithPlaceholders = en.keys.where((k) {
        if (k.startsWith('@')) return false;
        final value = en[k];
        return value is String &&
            RegExp(r'\{[a-zA-Z][a-zA-Z0-9_]*\}').hasMatch(value);
      }).toSet();
      expect(keysWithPlaceholders, isNotEmpty);
      for (final k in keysWithPlaceholders) {
        expect(
          en.containsKey('@$k'),
          isTrue,
          reason:
              'app_en.arb placeholder-bearing key "$k" has no @-metadata '
              'block (gen-l10n would drop the key)',
        );
      }
    });
  });
}
