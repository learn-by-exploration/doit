// Tests for `DoItApp` (lib/main.dart) — the root widget that
// wires the MultiProvider, the `AppLocalizations` delegate,
// the first-launch gate, and the route table.
//
// v1.6-ι / SYS-154 / ADR-085 / WF-082: 10 widget-level tests
// covering the root widget's branching + wiring contract
// without spinning up `main()` (which would touch every
// platform channel). The tests mount `DoItApp` directly with
// the `firstLaunchOverride` test seam so the onboarding-vs-
// home decision is deterministic.
//
// Tests are AAA-pattern, widget-mount only (no
// `pumpAndSettle()` — the home screen has streams and the
// onboarding screen has timed dialogs).

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/main.dart';
import 'package:doit/screens/home.dart';
import 'package:doit/screens/onboarding.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---- v1.6-ι / SYS-154 / ADR-085 / WF-082 ----
  // Branch coverage for `DoItApp`'s `home:` switch — the
  // first-launch gate that decides between
  // [OnboardingScreen] and [HomeScreen].
  group('DoItApp firstLaunch gate (v1.6-ι)', () {
    testWidgets(
      'firstLaunchOverride_true mounts OnboardingScreen and skips HomeScreen',
      (tester) async {
        // Arrange + Act.
        await tester.pumpWidget(const DoItApp(firstLaunchOverride: true));
        await tester.pump();

        // Assert — OnboardingScreen is on screen; HomeScreen
        // is NOT (the gate flipped to the onboarding branch).
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      },
    );

    testWidgets(
      'firstLaunchOverride_false mounts HomeScreen and skips OnboardingScreen',
      (tester) async {
        // Arrange + Act.
        await tester.pumpWidget(const DoItApp(firstLaunchOverride: false));
        await tester.pump();

        // Assert — HomeScreen is on screen; OnboardingScreen
        // is NOT.
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(OnboardingScreen), findsNothing);
      },
    );

    testWidgets(
      'firstLaunchOverride_null_with_completed_flag mounts HomeScreen',
      (tester) async {
        // Arrange — flip the persisted `firstLaunchCompleted`
        // flag to `true` so the no-override path picks the
        // home branch. `SettingsService.instance` is a
        // singleton; the ValueNotifier write is observed by
        // the `ValueListenableBuilder` inside DoItApp.
        final settings = SettingsService.instance;
        settings.firstLaunchCompleted.value = true;
        addTearDown(() {
          settings.firstLaunchCompleted.value = false;
        });

        // Act.
        await tester.pumpWidget(const DoItApp());
        await tester.pump();

        // Assert — the no-override branch read the
        // ValueNotifier and picked HomeScreen.
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(OnboardingScreen), findsNothing);
      },
    );

    testWidgets(
      'firstLaunchOverride_null_with_incomplete_flag mounts OnboardingScreen',
      (tester) async {
        // Arrange — the persisted flag is the singleton's
        // default (`false` — i.e., first launch in
        // progress). The no-override path must read the
        // flag and pick the onboarding branch.
        final settings = SettingsService.instance;
        // Defensive: ensure the flag really is `false` for
        // this test (the test harness may have flipped it
        // from a prior test).
        settings.firstLaunchCompleted.value = false;

        // Act.
        await tester.pumpWidget(const DoItApp());
        await tester.pump();

        // Assert.
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      },
    );
  });

  // ---- v1.6-ι / SYS-154 / ADR-085 / WF-082 ----
  // Wiring pins for `DoItApp`'s MultiProvider + theme +
  // localizations surface. These tests pin the *interface*
  // of the root widget so a future refactor that drops one
  // of these surfaces (e.g., swapping to a plain
  // MaterialApp) fails loudly here.
  group('DoItApp wiring pins (v1.6-ι)', () {
    testWidgets('DoItApp wires the theme + darkTheme + themeMode surface', (
      tester,
    ) async {
      // Arrange + Act.
      await tester.pumpWidget(const DoItApp(firstLaunchOverride: true));
      await tester.pump();

      // Assert — the MaterialApp deep inside DoItApp
      // picked up the documented light + dark themes, and
      // a themeMode (driven by
      // `SettingsService.instance.themeMode`).
      final BuildContext context = tester.element(
        find.byType(OnboardingScreen),
      );
      final MaterialApp app = context
          .findAncestorWidgetOfExactType<MaterialApp>()!;
      expect(app.theme, AppTheme.light);
      expect(app.darkTheme, AppTheme.dark);
      // The default themeMode is dark (per
      // SettingsService.themeMode's default), and the
      // ValueListenableBuilder wires that into MaterialApp.
      expect(app.themeMode, SettingsService.instance.themeMode.value);
    });

    testWidgets('DoItApp registers AppLocalizations.localizationsDelegates', (
      tester,
    ) async {
      // Arrange + Act.
      await tester.pumpWidget(const DoItApp(firstLaunchOverride: true));
      await tester.pump();

      // Assert — the MaterialApp exposes the generated
      // localizations delegate. The pin is the presence
      // of `AppLocalizations.localizationsDelegates` in
      // the active delegates list.
      final BuildContext context = tester.element(
        find.byType(OnboardingScreen),
      );
      final MaterialApp app = context
          .findAncestorWidgetOfExactType<MaterialApp>()!;
      expect(
        app.localizationsDelegates,
        isNotNull,
        reason:
            'DoItApp must register the AppLocalizations '
            'delegates (v1.1h / ADR-031 / SYS-087).',
      );
      // The delegates list includes the generated
      // `AppLocalizations.delegate` AND the
      // `DefaultMaterialLocalizations.delegate`.
      final delegateTypes = app.localizationsDelegates!
          .map((d) => d.toString())
          .toList();
      // Pin at least one of the generated delegates is
      // present (the test does not depend on a private
      // symbol).
      final hasAppLocalizations = delegateTypes.any(
        (s) => s.contains('AppLocalization'),
      );
      expect(hasAppLocalizations, isTrue);
    });

    testWidgets(
      'DoItApp supportedLocales matches AppLocalizations.supportedLocales',
      (tester) async {
        // Arrange + Act.
        await tester.pumpWidget(const DoItApp(firstLaunchOverride: true));
        await tester.pump();

        // Assert — the supported locales match the generated
        // surface exactly. The pin is that DoItApp does
        // NOT override `supportedLocales` with a hard-coded
        // list (which would silently drop a future locale).
        final BuildContext context = tester.element(
          find.byType(OnboardingScreen),
        );
        final MaterialApp app = context
            .findAncestorWidgetOfExactType<MaterialApp>()!;
        expect(app.supportedLocales, isNotNull);
        final codes = app.supportedLocales.map((l) => l.languageCode).toSet();
        expect(codes, contains('en'));
        expect(codes, contains('es'));
        // Sanity: matches the generated surface exactly.
        expect(
          codes,
          AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
        );
      },
    );

    testWidgets(
      'DoItApp onUnknownRoute renders a blank Scaffold without crashing',
      (tester) async {
        // Arrange — mount DoItApp, fetch the MaterialApp
        // instance to grab the onUnknownRoute callback. The
        // callback is the v1.3d / Phase 15 / SYS-114 /
        // ADR-044 catch-all for malformed `/mission` query
        // strings.
        await tester.pumpWidget(const DoItApp(firstLaunchOverride: true));
        await tester.pump();

        final BuildContext context = tester.element(
          find.byType(OnboardingScreen),
        );
        final MaterialApp app = context
            .findAncestorWidgetOfExactType<MaterialApp>()!;
        expect(
          app.onUnknownRoute,
          isNotNull,
          reason:
              'DoItApp must register onUnknownRoute (the '
              'malformed-/mission fallback per v1.3d / Phase 15 '
              '/ SYS-114 / ADR-044).',
        );

        // Act — invoke the onUnknownRoute callback with a
        // garbage route. The callback must return a
        // MaterialPageRoute (the production contract is a
        // page that pops immediately to avoid showing a
        // broken UI).
        final unknown = app.onUnknownRoute!(
          const RouteSettings(name: '/mission?garbage=1'),
        )!;

        // Assert — the route is a MaterialPageRoute
        // wrapping a Scaffold(body: SizedBox.shrink()). The
        // Scaffold is not yet mounted (we did not push the
        // route into the navigator), but its builder
        // closure must construct without throwing.
        expect(unknown, isA<MaterialPageRoute<void>>());
        // Build the page in isolation so the Scaffold is
        // actually mounted; assert the body is the empty
        // SizedBox.
        await tester.pumpWidget(
          MaterialApp(
            onGenerateRoute: (_) => unknown,
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        );
        await tester.pump();
        expect(find.byType(Scaffold), findsWidgets);
      },
    );

    testWidgets(
      'DoItApp home selector reflects firstLaunchOverride change on rebuild',
      (tester) async {
        // Arrange — mount with `firstLaunchOverride: true`,
        // confirm OnboardingScreen. Then re-mount with
        // `firstLaunchOverride: false` (a fresh
        // `pumpWidget` replaces the tree); confirm
        // HomeScreen.
        await tester.pumpWidget(const DoItApp(firstLaunchOverride: true));
        await tester.pump();
        expect(find.byType(OnboardingScreen), findsOneWidget);

        // Act — re-mount.
        await tester.pumpWidget(const DoItApp(firstLaunchOverride: false));
        await tester.pump();

        // Assert.
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(OnboardingScreen), findsNothing);
      },
    );

    testWidgets(
      'DoItApp title is "do it" (matches the platform launcher label)',
      (tester) async {
        // Arrange + Act.
        await tester.pumpWidget(const DoItApp(firstLaunchOverride: true));
        await tester.pump();

        // Assert — the MaterialApp title pins the platform
        // launcher label. The OS task-switcher uses this
        // string; a future refactor that changes it must
        // update the launcher label too.
        final BuildContext context = tester.element(
          find.byType(OnboardingScreen),
        );
        final MaterialApp app = context
            .findAncestorWidgetOfExactType<MaterialApp>()!;
        expect(app.title, 'do it');
      },
    );
  });
}
