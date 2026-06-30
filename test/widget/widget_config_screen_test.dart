// Tests for the WidgetConfigScreen (v1.5-cyc-α / Phase 53 /
// SYS-140 / ADR-071 / WF-068).
//
// The screen is the picker shown inside the Android
// `DoitWidgetConfigureActivity` (lib/widget/widget_config_screen.dart,
// v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052). It reads
// `DoRepository.instance.listAll()` on `initState` (line 78)
// and forwards the picked habitId to a `WidgetServiceProxy`
// (line 49 seam) before popping with the id (line 89).
//
// Coverage today: 2.3% (1/44 lines hit — only the `createState`
// override from a transitive import). These tests are the
// regression net for the screen's 5 code paths:
//
//   1. `initState` → seed `_dosFuture = DoRepository.instance.listAll()`
//   2. `build`'s loading branch → `CircularProgressIndicator`
//   3. `build`'s empty branch → `_EmptyState` with "Back to do it" button
//   4. `build`'s list branch → `ListView.separated` with `_PickerRow` per do
//   5. `_onPicked(habitId)` happy path → calls `widget.proxy.setSelectedHabitId`
//      + pops with the habitId
//
// The proxy seam (constructor arg `WidgetServiceProxy`) is
// exercised via a `_RecordingProxy` subclass — the same pattern
// documented at lib/widget/widget_service_proxy.dart:13-21
// and tested in `test/widget/widget_service_proxy_test.dart`.
//
// Mirror the v1.4-stab-H `recently_deleted_screen_test.dart`
// pattern: `_resetDb(tester)` per-test, `_wrap` helper with the
// `localizedApp` support helper, `localizedApp(locale: const
// Locale('es'))` for the ARB-parity sweep.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/widget/widget_config_screen.dart';
import 'package:doit/widget/widget_service_proxy.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

class _RecordingProxy extends WidgetServiceProxy {
  final List<String?> calls = <String?>[];

  @override
  Future<bool> setSelectedHabitId(String? habitId) async {
    calls.add(habitId);
    return true;
  }
}

class _PopObserver extends NavigatorObserver {
  String? poppedResult;
  Route<dynamic>? poppedRoute;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    poppedRoute = route;
    super.didPop(route, previousRoute);
  }
}

Future<void> _resetDb(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });
}

Future<DoFixed> _saveDo(
  WidgetTester tester, {
  required String id,
  required String name,
}) async {
  final item = DoFixed(
    id: id,
    name: name,
    proofMode: const SoftProof(),
    createdAt: DateTime(2026, 6, 15),
    restDaysPerMonth: 2,
    weekdays: const {1, 3, 5},
    time: const DoTime(9, 0),
  );
  await DoRepository.instance.save(item);
  return item;
}

Widget _wrap({
  Locale? locale,
  WidgetServiceProxy? proxy,
  NavigatorObserver? observer,
}) {
  return localizedApp(
    theme: AppTheme.dark,
    locale: locale,
    navigatorObservers: observer == null
        ? const <NavigatorObserver>[]
        : <NavigatorObserver>[observer],
    home: WidgetConfigScreen(proxy: proxy ?? const WidgetServiceProxy()),
  );
}

void main() {
  testWidgets('list-loaded: shows one row per do', (tester) async {
    await _resetDb(tester);
    await _saveDo(tester, id: 'h1', name: 'Stretch');
    await _saveDo(tester, id: 'h2', name: 'Read');
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('list-empty: shows the empty-state copy + Back button', (
    tester,
  ) async {
    await _resetDb(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l.widgetConfigureEmptyState), findsOneWidget);
    expect(find.text(l.widgetConfigureBackToHome), findsOneWidget);
  });

  testWidgets('picker-row tap forwards to proxy and pops with the habitId', (
    tester,
  ) async {
    await _resetDb(tester);
    await _saveDo(tester, id: 'h1', name: 'Stretch');
    final fake = _RecordingProxy();
    final observer = _PopObserver();
    await tester.pumpWidget(_wrap(proxy: fake, observer: observer));
    await tester.pumpAndSettle();
    // Tap the row.
    await tester.tap(find.text('Stretch'));
    await tester.pumpAndSettle();
    expect(
      fake.calls,
      <String?>['h1'],
      reason: 'The picker must forward the picked habitId to the proxy.',
    );
    expect(
      observer.poppedRoute,
      isNotNull,
      reason: 'The picker must pop the route after the proxy write.',
    );
  });

  testWidgets('loading-state: shows CircularProgressIndicator before the '
      'future resolves', (tester) async {
    await _resetDb(tester);
    await _saveDo(tester, id: 'h1', name: 'Stretch');
    // pumpWidget renders the first frame BEFORE the
    // `DoRepository.listAll()` future resolves. The
    // FutureBuilder is in `waiting` state, so the loading
    // branch must render a CircularProgressIndicator.
    // Do NOT pumpAndSettle — that would advance past the
    // loading branch into the list branch.
    await tester.pumpWidget(_wrap());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Now settle to confirm the loading branch was transient.
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Stretch'), findsOneWidget);
  });

  testWidgets('AppBar title is the localized widgetConfigureTitle', (
    tester,
  ) async {
    await _resetDb(tester);
    await _saveDo(tester, id: 'h1', name: 'Stretch');
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l.widgetConfigureTitle), findsOneWidget);
  });

  testWidgets('ARB-parity: Spanish locale renders the localized strings', (
    tester,
  ) async {
    await _resetDb(tester);
    await _saveDo(tester, id: 'h1', name: 'Stretch');
    await tester.pumpWidget(_wrap(locale: const Locale('es')));
    await tester.pumpAndSettle();
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(find.text(l.widgetConfigureTitle), findsOneWidget);
  });

  testWidgets('empty-state Back button pops the route', (tester) async {
    await _resetDb(tester);
    final observer = _PopObserver();
    await tester.pumpWidget(_wrap(observer: observer));
    await tester.pumpAndSettle();
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l.widgetConfigureBackToHome));
    await tester.pumpAndSettle();
    expect(
      observer.poppedRoute,
      isNotNull,
      reason:
          'The Back button in the empty state must pop the route so '
          'the launcher\'s RESULT_CANCELED handshake completes.',
    );
  });
}
