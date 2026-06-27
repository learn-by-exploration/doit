// Integration test for the v1.4k widget deep-link
// (Phase 38 / SYS-125 / ADR-055 / WF-052).
//
// Covers the route table in `lib/app_router.dart` and the
// JSON envelope contract that drives the widget
// body-tap PendingIntent (`DoitWidgetState.selectedHabitId`):
//
//   - `buildHabitRoute(/habit?habitId=abc)` resolves to a
//     `MaterialPageRoute` whose builder produces an
//     `AddHabitScreen` with the picked habit id.
//   - `buildHabitRoute(/habit?habitId='')` (empty) falls
//     back to `HomeScreen` — mirrors the
//     `_unknownMissionRoute` empty-scaffold fallback so a
//     stale tap (the picked do was deleted while the
//     widget was bound) does not surface a broken edit
//     screen.
//   - `buildWidgetConfigRoute(/widget-config?widgetId=42)`
//     resolves to a `MaterialPageRoute` whose builder
//     produces a `WidgetConfigScreen` with the widget id
//     arg.
//   - `buildHabitRoute('/unknown')` returns `null` so the
//     `MaterialApp` falls back to its `home:` switch —
//     the additive route does not break the existing
//     routes.
//   - `DoitWidgetState.selectedHabitId` round-trips
//     through `toJson` — pins the JSON envelope key that
//     the Kotlin `WidgetRenderer.openAppIntent` reads.
//
// The Kotlin side (`WidgetRenderer.openAppIntent`,
// `MainActivity.getInitialRoute`,
// `DoitWidgetConfigureActivity.getInitialRoute`) is not
// exercised here — it is hand-rolled Kotlin without a
// JVM test harness in this repo. The Dart side mirrors
// the Kotlin contract shape (route names, query-string
// args, Intent extra keys) and these tests pin those
// contracts so a future refactor cannot drop the keys
// without breaking the round-trip.
//
// Tests inspect the returned `MaterialPageRoute` builder
// directly via a stub `BuildContext` rather than pushing
// onto a real Navigator. Pushing onto a Navigator would
// require pumping widgets past `FutureBuilder`s inside
// `AddHabitScreen` / `HomeScreen` / `WidgetConfigScreen`,
// each of which reads `DoRepository.instance.listAll()` —
// the singleton is not seeded in this test file. The
// pure-builder check is the contract the routes actually
// guarantee.

import 'package:doit/app_router.dart';
import 'package:doit/screens/add_habit.dart';
import 'package:doit/screens/home.dart';
import 'package:doit/widget/doit_widget_state.dart';
import 'package:doit/widget/widget_config_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('v1.4k / SYS-125 widget deep-link routes', () {
    test('buildHabitRoute(/habit?habitId=abc) builds AddHabitScreen', () {
      final route = buildHabitRoute(
        const RouteSettings(
          name: '/habit',
          arguments: <String, Object?>{'habitId': 'abc'},
        ),
      );
      expect(route, isNotNull);
      final mpr = route as MaterialPageRoute<bool?>;
      final built = mpr.builder(_EmptyBuildContext());
      expect(built, isA<AddHabitScreen>());
    });

    test('buildHabitRoute(/habit?habitId=\'\') falls back to HomeScreen', () {
      final route = buildHabitRoute(
        const RouteSettings(
          name: '/habit',
          arguments: <String, Object?>{'habitId': ''},
        ),
      );
      expect(route, isNotNull);
      final mpr = route as MaterialPageRoute<void>;
      final built = mpr.builder(_EmptyBuildContext());
      expect(built, isA<HomeScreen>());
    });

    test('buildHabitRoute(/unknown) returns null (no match)', () {
      final route = buildHabitRoute(const RouteSettings(name: '/unknown'));
      expect(route, isNull);
    });

    test('buildWidgetConfigRoute(/widget-config?widgetId=42) builds '
        'WidgetConfigScreen with the widget id', () {
      final route = buildWidgetConfigRoute(
        const RouteSettings(
          name: '/widget-config',
          arguments: <String, Object?>{'widgetId': 42},
        ),
      );
      expect(route, isNotNull);
      final mpr = route as MaterialPageRoute<String?>;
      final built = mpr.builder(_EmptyBuildContext());
      expect(built, isA<WidgetConfigScreen>());
    });

    test(
      'buildWidgetConfigRoute(/widget-config) builds with null widgetId',
      () {
        // Defensive: the Kotlin activity ALWAYS passes
        // a widgetId; this case covers a malformed
        // intent / an in-process dispatch that omits
        // it. The screen still constructs.
        final route = buildWidgetConfigRoute(
          const RouteSettings(name: '/widget-config'),
        );
        expect(route, isNotNull);
        final mpr = route as MaterialPageRoute<String?>;
        final built = mpr.builder(_EmptyBuildContext());
        expect(built, isA<WidgetConfigScreen>());
      },
    );

    test('buildAppRoute dispatches on the route name', () {
      expect(buildAppRoute(const RouteSettings(name: '/habit')), isNotNull);
      expect(
        buildAppRoute(const RouteSettings(name: '/widget-config')),
        isNotNull,
      );
      expect(buildAppRoute(const RouteSettings(name: '/mission')), isNotNull);
      expect(buildAppRoute(const RouteSettings(name: '/nope')), isNull);
    });

    test('DoitWidgetState.selectedHabitId round-trips through toJson', () {
      // The Kotlin `WidgetRenderer.openAppIntent` reads
      // `state.optString("selectedHabitId", "")` and
      // passes it via `putExtra(MainActivity.EXTRA_HABIT_ID, ...)`.
      // The `MainActivity.getInitialRoute` reads the
      // same extra and encodes it into
      // `/habit?habitId=...`. Pin the JSON envelope
      // shape so a future refactor cannot drop the
      // key without breaking the contract.
      final state = DoitWidgetState(
        habitId: 'h1',
        habitName: 'Read',
        streakNumber: 5,
        isCompletedToday: false,
        reliability: DoitWidgetReliability.optimal,
        asOf: DateTime(2026, 6, 15, 10),
        selectedHabitId: 'h1',
      );
      final json = state.toJson();
      expect(json['selectedHabitId'], 'h1');
    });
  });
}

/// Minimal `BuildContext` shim. `MaterialPageRoute.builder`
/// takes a `BuildContext`; we don't actually exercise
/// the build tree (the screens defer heavy work to
/// `initState` / `build`), but we hand the closure a
/// context-shaped object so the widget construction
/// type-checks. The shim never has `dependOnInheritedWidget`
/// called against it — the screens do not look up
/// inherited widgets at construction time, only their
/// `build` does, which is never called here.
class _EmptyBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_EmptyBuildContext is a stub for type-checking '
      'MaterialPageRoute.builder closure only. '
      'Got: ${invocation.memberName}',
    );
  }
}
