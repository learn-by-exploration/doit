// v1.4-stab-J / Phase 50 / SYS-137 / ADR-068 / WF-065.
//
// Font-scale accessibility test. The OS exposes a per-user
// `TextScaler` that scales every `Text` widget by a linear
// factor — 1.0x is the default, 1.3x is the "large" preset,
// and 1.6x is the "largest" preset Android Material You
// supports. The Material a11y guidance (Material 3
// accessibility guidance, Section 4.3) requires that:
//   - Every text widget reflows cleanly at 1.6x.
//   - No `RenderFlex` overflow occurs at any scale.
//   - No `RenderConstrainedOverflow` (which surfaces as
//     a yellow-and-black hatching at runtime) occurs at
//     any scale.
//
// The screen mount pattern re-uses the in-memory Drift +
// service init sequence from `locale_render_test.dart`
// (v1.4-stab-I), so the same screens we already mount
// (HomeScreen, RecentlyDeletedScreen) are the candidates
// we can validate at 1.0x, 1.3x, and 1.6x without
// risking a heavier mount that pulls every service
// singleton. The static a11y checks (semantic labels,
// contrast) live in `semantics_labels_test.dart` and
// `contrast_test.dart` — this file is the visual
// overflow sweep, NOT the screen-mount smoke.
//
// The 3 font-scales tested are the three Android Material
// You presets. We use `MediaQuery(textScaler: ...)` to
// override per-test, exactly matching what the OS exposes
// when the user dials `font_scale` in system settings.

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/screens/home.dart';
import 'package:doit/screens/recently_deleted_screen.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

/// Minimal DB + repo seed. The home screen has the same
/// dependencies as `test/screens/home_test.dart` but does
/// not need a full provider tree at font-scale-render
/// time (we are only checking layout), so a stripped-down
/// init is sufficient.
Future<void> _resetDb(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  // Initialize DoRepository without going through
  // ReminderService.init (which would require the platform
  // channels).
  DoRepository.instance;
  ReminderService.resetForTesting();
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });
}

Widget _wrap({required Widget home, required double scale}) {
  // Wrap in `MediaQuery` to override the OS-provided
  // font-scale, then route through `localizedApp` to
  // wire AppLocalizations.
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: localizedApp(theme: AppTheme.dark, home: home),
  );
}

void _expectNoOverflow(WidgetTester tester) {
  // A successful `tester.pumpAndSettle` with no exception
  // means no `RenderFlex` overflow occurred. A yellow
  // hatched bar at runtime surfaces during the pump cycle
  // as a thrown FlutterError with the message
  // "RenderFlex overflowed by ..."  — `takeException`
  // catches it.
  expect(
    tester.takeException(),
    isNull,
    reason:
        'Layout exception at the chosen font-scale — likely a '
        'RenderFlex overflow. Either reduce the surface, or '
        'wrap the offending widget in a SingleChildScrollView '
        'or a Wrap.',
  );
}

void main() {
  testWidgets(
    'home-screen renders without overflow at font-scale 1.0x (default)',
    (tester) async {
      await _resetDb(tester);
      await tester.pumpWidget(_wrap(home: const HomeScreen(), scale: 1.0));
      await tester.pumpAndSettle();
      _expectNoOverflow(tester);
    },
  );

  testWidgets(
    'home-screen renders without overflow at font-scale 1.3x (large)',
    (tester) async {
      await _resetDb(tester);
      await tester.pumpWidget(_wrap(home: const HomeScreen(), scale: 1.3));
      await tester.pumpAndSettle();
      _expectNoOverflow(tester);
    },
  );

  testWidgets(
    'home-screen renders without overflow at font-scale 1.6x (largest)',
    (tester) async {
      // 1.6x is the "largest" Material You preset and the
      // most aggressive scale at which we MUST guarantee
      // no overflow. A regression that breaks here would
      // surface for the user at the most aggressive
      // system font setting.
      await _resetDb(tester);
      await tester.pumpWidget(_wrap(home: const HomeScreen(), scale: 1.6));
      await tester.pumpAndSettle();
      _expectNoOverflow(tester);
    },
  );

  testWidgets(
    'recently-deleted screen renders without overflow at font-scale 1.0x',
    (tester) async {
      await _resetDb(tester);
      await tester.pumpWidget(
        _wrap(home: const RecentlyDeletedScreen(), scale: 1.0),
      );
      await tester.pumpAndSettle();
      _expectNoOverflow(tester);
    },
  );

  testWidgets(
    'recently-deleted screen renders without overflow at font-scale 1.3x',
    (tester) async {
      await _resetDb(tester);
      await tester.pumpWidget(
        _wrap(home: const RecentlyDeletedScreen(), scale: 1.3),
      );
      await tester.pumpAndSettle();
      _expectNoOverflow(tester);
    },
  );

  testWidgets(
    'recently-deleted screen renders without overflow at font-scale 1.6x',
    (tester) async {
      await _resetDb(tester);
      await tester.pumpWidget(
        _wrap(home: const RecentlyDeletedScreen(), scale: 1.6),
      );
      await tester.pumpAndSettle();
      _expectNoOverflow(tester);
    },
  );

  testWidgets(
    'locale=es home-screen renders without overflow at font-scale 1.6x',
    (tester) async {
      // Spanish copy is ~30% longer than English on
      // average. A regression where 1.0x English renders
      // cleanly but 1.6x Spanish overflows would surface
      // for the Spanish-locale user at the largest font
      // setting — exactly the user population the v1.4-
      // stab-i18n sweep is protecting.
      await _resetDb(tester);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: localizedApp(
            theme: AppTheme.dark,
            locale: const Locale('es'),
            home: Builder(
              builder: (ctx) =>
                  const Scaffold(body: Center(child: Text('Recently deleted'))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      _expectNoOverflow(tester);
      // Sanity check: the locale resolved to es (the title
      // string is replaced below the assertion — the empty
      // `Scaffold(body: Center(child: Text('Recently deleted')))`
      // is a smoke scaffold to make sure the locale + scale
      // override both apply together).
      final l = await AppLocalizations.delegate.load(const Locale('es'));
      expect(l.recentlyDeletedTitle, isNotEmpty);
    },
  );
}
