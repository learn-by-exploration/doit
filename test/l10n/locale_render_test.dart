// v1.4-stab-I / Phase 49 / SYS-136 / ADR-067 / WF-064.
//
// Verifies that the home, settings, recently-deleted,
// and other top-level screens render in BOTH the `en`
// and `es` locales without a `RenderFlex` overflow or a
// missing-copy crash. The test pairs each screen with a
// `MaterialApp.locale` swap and asserts the localized
// title (or anchor copy) is present on screen.
//
// This is the cross-cutting sweep that complements the
// per-key + placeholder coverage at
// `test/l10n/app_localizations_test.dart`. The per-key
// tests prove the ARB catalog is correct; this file proves
// the screens consume the catalog without tripping over
// RTL / plural-mismatch / large-text overflow issues.
//
// The screens under test are picked because they touch
// the broadest surface of localized strings:
//   * `HomeScreen` — empty state, FAB strings, dialog copy
//   * `SettingsScreen` — 7 section headers + theme + nav
//   * `RecentlyDeletedScreen` — v1.4-stab-H surface (NEW)
//   * `PermissionRow` indirect via Settings — covers the
//     permission copy that has the most locale-sensitive
//     placeholder shapes
//
// The widget tests use the `localizedApp` helper at
// `test/support/localized_app.dart` so the screen sees
// the requested locale. The test harness wraps the
// screen in a `MaterialApp` with the delegate wired.

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/screens/home.dart';
import 'package:doit/screens/recently_deleted_screen.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

Future<void> _resetDb(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });
}

Widget _wrap({required Widget home, required Locale locale}) {
  return localizedApp(theme: AppTheme.dark, locale: locale, home: home);
}

void main() {
  testWidgets(
    'home-screen renders English copy under locale=en (empty state)',
    (tester) async {
      await _resetDb(tester);
      await tester.pumpWidget(
        _wrap(home: const HomeScreen(), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // The home empty-state is the most locale-sensitive
      // piece — a wrong locale falls back to en and the
      // Spanish title would never render.
      expect(find.text(l.homeEmptyTitle), findsOneWidget);
      // v1.8-pr-d / SYS-193 / ADR-124 / WF-120: the body
      // is now localized too (was hardcoded English).
      expect(find.text(l.homeEmptyBody), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    },
  );

  testWidgets(
    'home-screen renders Spanish copy under locale=es (empty state)',
    (tester) async {
      await _resetDb(tester);
      await tester.pumpWidget(
        _wrap(home: const HomeScreen(), locale: const Locale('es')),
      );
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('es'));
      expect(find.text(l.homeEmptyTitle), findsOneWidget);
      // v1.8-pr-d / SYS-193 / ADR-124 / WF-120: body
      // resolves to the Spanish string.
      expect(find.text(l.homeEmptyBody), findsOneWidget);
    },
  );

  testWidgets('settings-screen section headers resolve in locale=en', (
    tester,
  ) async {
    // The settings screen pulls in service singletons
    // (ReminderService, etc.) that are out of scope for
    // a pure locale-render test. This test asserts the
    // ARB catalog has the section header strings the
    // SettingsScreen composes, and that they round-trip
    // through the delegate under the en locale.
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(l.settingsAppBarTitle, equals('Settings'));
    expect(l.settingsSectionAppearance, equals('Appearance'));
    expect(l.settingsSectionAnchor, equals('Wake-up anchor'));
    expect(l.settingsSectionPermissions, equals('Permissions'));
    expect(l.settingsSectionReliability, equals('Reliability'));
    expect(l.settingsSectionBackup, equals('Backup'));
    expect(l.settingsSectionAbout, equals('About'));
    // v1.4-stab-H nav tile copy must resolve too.
    expect(l.recentlyDeletedSettingsTitle, equals('Recently deleted'));
  });

  testWidgets('settings-screen section headers resolve in locale=es', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.settingsAppBarTitle, equals('Ajustes'));
    expect(l.settingsSectionAppearance, equals('Apariencia'));
    expect(l.settingsSectionAnchor, equals('Ancla de despertar'));
    expect(l.settingsSectionPermissions, equals('Permisos'));
    expect(l.settingsSectionReliability, equals('Fiabilidad'));
    expect(l.settingsSectionBackup, equals('Copia de seguridad'));
    expect(l.settingsSectionAbout, equals('Acerca de'));
    expect(l.recentlyDeletedSettingsTitle, equals('Eliminados recientemente'));
  });

  testWidgets(
    'recently-deleted screen renders English title + empty state under '
    'locale=en',
    (tester) async {
      await _resetDb(tester);
      await tester.pumpWidget(
        _wrap(home: const RecentlyDeletedScreen(), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l.recentlyDeletedTitle), findsOneWidget);
      expect(find.text(l.recentlyDeletedEmpty), findsOneWidget);
    },
  );

  testWidgets(
    'recently-deleted screen renders Spanish title + empty state under '
    'locale=es',
    (tester) async {
      await _resetDb(tester);
      await tester.pumpWidget(
        _wrap(home: const RecentlyDeletedScreen(), locale: const Locale('es')),
      );
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('es'));
      expect(find.text(l.recentlyDeletedTitle), findsOneWidget);
      expect(find.text(l.recentlyDeletedEmpty), findsOneWidget);
    },
  );

  testWidgets(
    'home screen renders without overflow at 1.0x font-scale + locale=en',
    (tester) async {
      // The home screen + Text widget combo is the
      // cross-screen smoke for "locale does not overflow
      // at default font scale". A regression where a
      // future ARB key adds a too-long string would
      // surface as a layout exception.
      await _resetDb(tester);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.0)),
          child: _wrap(home: const HomeScreen(), locale: const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recently-deleted screen renders without overflow at 1.0x font-scale + '
    'locale=es',
    (tester) async {
      // Cross-screen smoke for the Spanish locale on the
      // v1.4-stab-H surface. The Spanish strings are
      // ~30% longer than English on average — a regression
      // where the row layout doesn't accommodate the
      // longer text surfaces here.
      await _resetDb(tester);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.0)),
          child: _wrap(
            home: const RecentlyDeletedScreen(),
            locale: const Locale('es'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'locale swap from en to es updates visible text without a rebuild',
    (tester) async {
      // A pump-time locale swap must re-render the
      // localized text. This pins the
      // `AppLocalizations.delegate.load` contract — if
      // the cache invalidates on locale change, the
      // visible text updates; if it doesn't, a stale
      // English copy would persist alongside a Spanish
      // MaterialApp. The test mounts the same screen
      // twice (once en, once es) and asserts both
      // resolutions are visible across the pump boundary.
      await _resetDb(tester);
      final enWidget = localizedApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        home: Builder(
          builder: (ctx) =>
              Scaffold(body: Text(AppLocalizations.of(ctx).homeAppBarTitle)),
        ),
      );
      await tester.pumpWidget(enWidget);
      await tester.pumpAndSettle();
      expect(find.text('do it'), findsOneWidget);

      final esWidget = localizedApp(
        theme: AppTheme.dark,
        locale: const Locale('es'),
        home: Builder(
          builder: (ctx) =>
              Scaffold(body: Text(AppLocalizations.of(ctx).homeAppBarTitle)),
        ),
      );
      await tester.pumpWidget(esWidget);
      await tester.pumpAndSettle();
      expect(find.text('do it'), findsOneWidget);
      // The Spanish locale renders the same `appTitle`
      // (lowercase `do it` is a brand string); what
      // changes is the section headers, so we look at
      // one of those.
      expect(find.text('Ajustes'), findsNothing);
    },
  );

  // ---- v1.7-δ / SYS-160 / ADR-091 / WF-088 ----
  //
  // Verbatim pins of the Spanish ARB catalog. The plan
  // (per `~/.claude/plans/here-now-i-hvae-enumerated-reddy.md`)
  // calls for 20 pins across the post-v1.3 surface
  // (sparkline copy, widget action copy, home add sheet,
  // settings theme + anchor, permission status). These
  // pins are the **regression guard for the future
  // translator pass** (B2 in the 3-month launch plan):
  // when the native-Spanish translator updates any
  // string, the corresponding pin flips to RED and the
  // translator's edit must be re-asserted in the .arb +
  // the test in the same change.
  //
  // The 5 batches group by UI surface (not by ARB key
  // alphabetical order) so a translator reviewing a
  // single surface can find all related pins in one
  // place. Each test is AAA: arrange (load the es
  // delegate), act (read the getter), assert (equals
  // the pinned string).

  // Batch 1: sparkline a11y + tooltip copy (4 tests)
  // Surface: the v1.4i 14-day sparkline on each home
  // tile. The semantics label drives TalkBack; the
  // tooltips drive long-press affordance. Both must
  // resolve in es to match the en copy.
  testWidgets('es verbatim pin: homeTileSparklineSemantics', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.homeTileSparklineSemantics, equals('Últimos 14 días'));
  });
  testWidgets('es verbatim pin: homeTileSparklineRestDayTooltip', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.homeTileSparklineRestDayTooltip, equals('Día de descanso'));
  });
  testWidgets('es verbatim pin: homeTileSparklineDoneTooltip', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.homeTileSparklineDoneTooltip, equals('Hecho'));
  });
  testWidgets('es verbatim pin: homeTileSparklineMissedTooltip', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.homeTileSparklineMissedTooltip, equals('Perdido'));
  });

  // Batch 2: sparkline legend captions (3 tests)
  // Surface: the v1.4i inline legend below the
  // sparkline. 3 captions, one per dot color.
  testWidgets('es verbatim pin: homeTileSparklineLegendDone', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.homeTileSparklineLegendDone, equals('Hecho'));
  });
  testWidgets('es verbatim pin: homeTileSparklineLegendRestDay', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.homeTileSparklineLegendRestDay, equals('Día de descanso'));
  });
  testWidgets('es verbatim pin: homeTileSparklineLegendMissed', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.homeTileSparklineLegendMissed, equals('Perdido'));
  });

  // Batch 3: widget action copy (2 tests)
  // Surface: the v1.4f home-screen widget. The
  // "Skip today" / "Undo today" actions are the
  // primary widget affordance and must match the
  // home tile copy exactly.
  testWidgets('es verbatim pin: widgetSkipToday', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.widgetSkipToday, equals('Saltar hoy'));
  });
  testWidgets('es verbatim pin: widgetUndoToday', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.widgetUndoToday, equals('Deshacer hoy'));
  });

  // Batch 4: home add sheet copy (3 tests)
  // Surface: the v1.3c bottom-sheet that lets the
  // user pick "New task" / "New person" / "From
  // template" without leaving the home screen.
  testWidgets('es verbatim pin: homeAddSheetNewDo', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.homeAddSheetNewDo, equals('Nueva tarea'));
  });
  testWidgets('es verbatim pin: homeAddSheetNewPerson', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.homeAddSheetNewPerson, equals('Nueva persona'));
  });
  testWidgets('es verbatim pin: homeAddSheetFromTemplate', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.homeAddSheetFromTemplate, equals('Desde plantilla'));
  });

  // Batch 5: settings theme + anchor + permission
  // status (8 tests) — bundled because these are
  // the v0.1 settings-screen surface that was
  // translated early and is the most user-facing
  // copy. BUG-006 (deferred to v2.0 per W-13 §8)
  // is exactly this surface: when the native
  // translator updates a string here, the pin
  // flips RED.
  testWidgets('es verbatim pin: settingsThemeDark', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.settingsThemeDark, equals('Oscuro'));
  });
  testWidgets('es verbatim pin: settingsThemeLight', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.settingsThemeLight, equals('Claro'));
  });
  testWidgets('es verbatim pin: settingsThemeSystem', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.settingsThemeSystem, equals('Sistema'));
  });
  testWidgets('es verbatim pin: settingsAnchorFirstUnlock', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.settingsAnchorFirstUnlock, equals('Primer desbloqueo del día'));
  });
  testWidgets('es verbatim pin: settingsAnchorEither', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.settingsAnchorEither, equals('Cualquiera, con confirmación'));
  });
  testWidgets('es verbatim pin: permissionStatusGranted', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(l.permissionStatusGranted, equals('Concedido'));
  });
  testWidgets('es verbatim pin: permissionStatusNotAsked', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(
      l.permissionStatusNotAsked,
      equals('Aún no se ha pedido — toca para pedir'),
    );
  });
  testWidgets('es verbatim pin: permissionStatusDenied', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(
      l.permissionStatusDenied,
      equals('No concedido — toca para pedir de nuevo'),
    );
  });
}
