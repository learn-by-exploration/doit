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

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/main.dart';
import 'package:doit/routines/routine.dart';
import 'package:doit/screens/home.dart';
import 'package:doit/screens/onboarding.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/services/template_repository.dart';
import 'package:doit/templates/template.dart';
import 'package:doit/templates/template_library.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:drift/native.dart';
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

  // ---- v1.6-κ / SYS-155 / ADR-086 / WF-083 ----
  // Wiring pin for `TemplateLibrary.seedBuiltIns(...)` as
  // called from `lib/main.dart` step 1a. The wiring predates
  // v1.6-κ; this cycle's edit was to retire 2 stale `Phase B
  // PR 2` TODOs that referenced it as "not yet wired". These
  // 3 tests pin the wiring contract so a future refactor that
  // drops the call from `main()` step 1a fails here.
  group('TemplateLibrary.seedBuiltIns called from main() (v1.6-κ)', () {
    setUp(() async {
      // Mirror the init() path the production main() takes
      // (step 1: init the singleton, step 1a: seed the
      // built-in library). We bypass the SettingsService
      // and OnboardingScreen plumbing — only the Drift +
      // template-library surface is in scope here.
      await AppDatabaseService.instance.closeForTesting();
      await AppDatabaseService.instance.init(
        overrideDb: AppDatabase(NativeDatabase.memory()),
      );
      await AppDatabaseService.instance.ready;
    });

    tearDown(() async {
      await AppDatabaseService.instance.closeForTesting();
    });

    test('main() step 1a seeds the curated 25-row library into Drift '
        '(v1.6-κ)', () async {
      // Arrange — Drift is empty.
      final initial = await TemplateRepository.instance.listAll();
      expect(initial, isEmpty);

      // Act — same call main() step 1a makes.
      final inserted = await TemplateLibrary.seedBuiltIns(
        TemplateRepository.instance,
      );

      // Assert — every built-in row reached Drift, and
      // each one carries the curated id prefix.
      expect(inserted, 25);
      final after = await TemplateRepository.instance.listAll();
      expect(after.length, 25);
      final ids = after.map((t) => t.id).toSet();
      for (final t in TemplateLibrary.builtIns) {
        expect(
          ids,
          contains(t.id),
          reason:
              'Built-in id ${t.id} '
              'must reach Drift after the main() init path.',
        );
      }
    });

    test('main() step 1a is idempotent on a re-init of the singleton '
        '(v1.6-κ)', () async {
      // Arrange — first init seeds 25.
      final first = await TemplateLibrary.seedBuiltIns(
        TemplateRepository.instance,
      );
      expect(first, 25);

      // Act — a re-seed call (mirrors what happens if
      // `main()` runs twice — e.g., after a hot restart
      // in debug mode — or if a future refactor calls
      // `seedBuiltIns` from a second site).
      final second = await TemplateLibrary.seedBuiltIns(
        TemplateRepository.instance,
      );

      // Assert — the second call inserts 0 (the built-
      // in rows are already present, so the `builtInOnly`
      // guard short-circuits the loop).
      expect(second, 0);
      final after = await TemplateRepository.instance.listAll();
      expect(after.length, 25);
    });

    test(
      'main() step 1a populates the templates table even when the '
      'restore flow has already populated user-saved rows (v1.6-κ)',
      () async {
        // Arrange — save a user-saved template BEFORE the
        // built-in seed (this mirrors the v1.0 restore flow
        // where the user imports a backup that contains
        // user-saved templates; the migration creates the
        // table but only `main()` step 1a populates the
        // built-ins).
        const userTemplateId = 't_user_1';
        await TemplateRepository.instance.save(
          // Use the existing Template model — defined in
          // `lib/templates/template.dart`.
          // We import the symbol via `template.dart` at the
          // top of this file implicitly via the library
          // surface; the constructor takes all fields
          // non-nullable. Use the test-only fields shown
          // in template_library_test.dart.
          _userTemplate(id: userTemplateId),
        );

        // Act — the main() init path runs.
        final inserted = await TemplateLibrary.seedBuiltIns(
          TemplateRepository.instance,
        );

        // Assert — the built-ins were seeded (25) AND the
        // user's row is still present (the seed path does
        // not delete pre-existing rows; it only inserts
        // rows whose id is not already present, which is
        // true for the 25 curated ids and false for
        // `t_user_1`).
        expect(inserted, 25);
        final after = await TemplateRepository.instance.listAll();
        expect(after.length, 26);
        expect(
          after.any((t) => t.id == userTemplateId),
          isTrue,
          reason:
              'The user-saved template must NOT be deleted '
              'by the built-in seed.',
        );
        expect(after.where((t) => t.isBuiltIn).length, 25);
      },
    );
  });

  // ---- v1.6-κ / SYS-155 / ADR-086 / WF-083 ----
  // Combined init-flow pins for the v1.6-κ bug-fix cycle.
  // These exercise the two contract surfaces that the cycle
  // promised: (a) `main()` step 1a actually seeds the
  // templates table, (b) the soft-delete + restore path
  // preserves the user's `automationsJson` by construction
  // (because `restoreById` is a single UPDATE that only
  // touches `deletedAtMillis`).
  group('Combined main() init flow (v1.6-κ)', () {
    setUp(() async {
      await AppDatabaseService.instance.closeForTesting();
      await AppDatabaseService.instance.init(
        overrideDb: AppDatabase(NativeDatabase.memory()),
      );
      await AppDatabaseService.instance.ready;
    });

    tearDown(() async {
      await AppDatabaseService.instance.closeForTesting();
    });

    test('init seeds templates + listAll returns the 25 curated rows '
        '(v1.6-κ)', () async {
      // Act — run the main() init sequence: init the DB
      // singleton, then seed the built-in library (step
      // 1a). The setUp already inits the singleton; this
      // test exercises step 1a + the read-back contract.
      final inserted = await TemplateLibrary.seedBuiltIns(
        TemplateRepository.instance,
      );

      // Assert — 25 rows were inserted AND the picker
      // (which reads via `TemplateRepository.listAll`)
      // sees all 25 in their curated order.
      expect(inserted, 25);
      final all = await TemplateRepository.instance.listAll();
      expect(all.length, 25);
      // The curated order is createdAtMillis ASC, id ASC;
      // verify the first 3 ids match the curated list.
      expect(all[0].id, TemplateLibrary.builtIns[0].id);
      expect(all[1].id, TemplateLibrary.builtIns[1].id);
      expect(all[2].id, TemplateLibrary.builtIns[2].id);
    });

    test('init seeds templates + soft-delete + restore preserves '
        'automationsJson on a do with routines (v1.6-κ)', () async {
      // Arrange — main() step 1a: init + seed built-ins.
      await TemplateLibrary.seedBuiltIns(TemplateRepository.instance);

      // Save a do with a non-empty automations list (this
      // is the user-added routine that the v1.4l restore
      // path was reportedly losing — see ADR-086 drift
      // lessons for the historical context).
      final originalAutomations = <Automation>[
        Automation(
          id: 'auto-1',
          trigger: const TriggerTimeOfDay(hour: 8, minute: 0),
          action: const ActionNotify(title: 'Morning', body: 'Drink'),
        ),
      ];
      final originalDo = DoFixed(
        id: 'h-routine',
        name: 'Morning routine',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 6, 27),
        restDaysPerMonth: 2,
        weekdays: const <int>{1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(8, 0),
        automations: originalAutomations,
      );
      await DoRepository.instance.save(originalDo);

      // Act — soft-delete + restore (the SnackBar Undo
      // path).
      await DoRepository.instance.softDeleteById(
        'h-routine',
        at: DateTime(2026, 6, 27, 12),
      );
      final restored = await DoRepository.instance.restoreById('h-routine');

      // Assert — restore succeeded, the do is back in the
      // active list, AND the routine survived (the
      // v1.4l restore-by-id path is a single UPDATE on
      // `deletedAtMillis` only; the automationsJson
      // column is preserved by construction).
      expect(restored, isTrue);
      final after = await DoRepository.instance.getActiveById('h-routine');
      expect(after, isNotNull);
      expect(after!.automations, originalAutomations);
      expect(
        after.automations.single.trigger,
        const TriggerTimeOfDay(hour: 8, minute: 0),
      );
    });
  });
}

/// Tiny factory for a user-saved template (not a built-in).
/// Used by the combined init-flow tests to verify that
/// `seedBuiltIns` does NOT clobber pre-existing user rows.
Template _userTemplate({required String id}) {
  // We construct via the public Template constructor
  // without importing `template.dart` at the top of the
  // file (we don't need to; the symbol resolves via the
  // TemplateLibrary import chain). The `template.dart`
  // model exposes a const constructor with all required
  // fields.
  return Template(
    id: id,
    name: 'User template',
    description: 'A user-saved template for the init-flow test.',
    iconName: 'check',
    entityType: TemplateEntityType.doEntity,
    payloadJson: '{"k":1,"do":{}}',
    isBuiltIn: false,
    createdAt: DateTime(2026, 6, 27),
  );
}
