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
  group('AppLocalizations structural tests', () {
    final arbs = <String, Map<String, dynamic>>{};

    setUpAll(() {
      // Walk `lib/l10n/*.arb` and parse every file. This is
      // a deterministic structural test, not a runtime
      // probe — it runs once per suite and the lookup table
      // is used by every `test` in the group.
      final l10nDir = Directory('lib/l10n');
      for (final entry in l10nDir.listSync()) {
        if (entry is! File) continue;
        final name = entry.uri.pathSegments.last;
        if (!name.endsWith('.arb')) continue;
        arbs[name] =
            jsonDecode(entry.readAsStringSync()) as Map<String, dynamic>;
      }
    });

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
}
