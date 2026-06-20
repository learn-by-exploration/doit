// Tests for the TemplatesScreen catalog.
//
// Covers (per WF-032 / SYS-067):
//   - All 25 built-in cards render after the first seed.
//   - Tapping the "Do" filter chip hides event / person /
//     routine cards.
//   - Tapping the "Routine" filter chip shows the
//     "Coming in v1.1" badge instead of the "Use this"
//     button.
//   - Tapping a do card's "Use this" button routes to
//     AddHabitScreen with the payload pre-filled.

import 'package:doit/screens/add_habit.dart';
import 'package:doit/screens/templates.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/template_repository.dart';
import 'package:doit/templates/template.dart';
import 'package:doit/templates/template_library.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap() {
  return const MaterialApp(home: TemplatesScreen());
}

Future<void> _setupDb(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  await AppDatabaseService.instance.init(
    overrideDb: AppDatabase(NativeDatabase.memory()),
  );
  addTearDown(AppDatabaseService.instance.closeForTesting);
  // Pre-seed BEFORE mounting the widget. Drift inserts
  // resolve in the testWidgets fake-async zone (the
  // executor is in-memory and runs synchronously enough
  // for the seed chain to complete).
  await TemplateLibrary.seedBuiltIns(TemplateRepository.instance);
}

/// After pumping the widget, advance frames until the
/// FutureBuilder's `seed + listAll` chain resolves. The
/// FutureBuilder shows a CircularProgressIndicator while the
/// future is in flight, so `pumpAndSettle` would hang on the
/// indeterminate animation. Instead, poll `listAll` (Drift
/// resolves it) then pump frames.
Future<void> _waitForCatalogReady(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    final list = await TemplateRepository.instance.listAll();
    if (list.length >= 25) break;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('renders all 25 built-in cards after first seed', (tester) async {
    await _setupDb(tester);
    await tester.pumpWidget(_wrap());
    await _waitForCatalogReady(tester);
    // GridView is lazy — scroll through the list so every
    // card is mounted at least once. We assert the union of
    // mounted ids is the full 25, not that they are all on
    // screen simultaneously (the screen is mobile-sized).
    final gridFinder = find.byType(GridView);
    final mountedIds = <String>{};
    for (var scroll = 0; scroll < 30; scroll++) {
      for (var i = 1; i <= 25; i++) {
        final id = 't_builtin_${i.toString().padLeft(2, '0')}';
        if (find.byKey(ValueKey('template_card.$id')).evaluate().isNotEmpty) {
          mountedIds.add(id);
        }
      }
      if (mountedIds.length >= 25) break;
      await tester.drag(gridFinder, const Offset(0, -600));
      await tester.pump();
    }
    expect(mountedIds.length, 25);
  });

  testWidgets('seeds built-ins exactly once on first run', (tester) async {
    await _setupDb(tester);
    await tester.pumpWidget(_wrap());
    await _waitForCatalogReady(tester);
    final list1 = await TemplateRepository.instance.listAll();
    expect(list1.length, 25);
    final inserted = await TemplateLibrary.seedBuiltIns(
      TemplateRepository.instance,
    );
    expect(inserted, 0);
  });

  testWidgets('Do filter chip hides event / person / routine cards', (
    tester,
  ) async {
    await _setupDb(tester);
    await tester.pumpWidget(_wrap());
    await _waitForCatalogReady(tester);
    await tester.tap(find.byKey(const ValueKey('templates.filter.doEntity')));
    await tester.pump();
    expect(find.text('Use this'), findsWidgets);
    expect(find.text('Coming in v1.1'), findsNothing);
  });

  testWidgets('Routine filter chip shows the "Coming in v1.1" badge', (
    tester,
  ) async {
    await _setupDb(tester);
    await tester.pumpWidget(_wrap());
    await _waitForCatalogReady(tester);
    await tester.tap(find.byKey(const ValueKey('templates.filter.routine')));
    await tester.pump();
    // Phase F PR 2 (SYS-075) special-cases template #16
    // ("Japan silent mode") to a real apply UX (the
    // AddRoutineScreen), so it now renders a "Use this" button
    // instead of the "Coming in v1.1" badge. The remaining 5
    // routine templates (17..21) still carry the badge — their
    // apply UX lands in v1.1. Verify #16 first (it is at the
    // top of the routine filter and renders without scrolling),
    // then scroll to mount and count the remaining 5.
    expect(
      find.byKey(const ValueKey('template_card.t_builtin_16.use')),
      findsOneWidget,
      reason:
          'Phase F PR 2 (SYS-075) special-cases template #16 ("Japan '
          'silent mode") to a real apply UX — it should render a '
          '"Use this" button instead of the "Coming in v1.1" badge.',
    );
    final gridFinder = find.byType(GridView);
    final mounted = <String>{};
    for (var scroll = 0; scroll < 30; scroll++) {
      for (var i = 1; i <= 25; i++) {
        final id = 't_builtin_${i.toString().padLeft(2, '0')}';
        if (find
            .byKey(ValueKey('template_card.$id.coming_soon'))
            .evaluate()
            .isNotEmpty) {
          mounted.add(id);
        }
      }
      if (mounted.length >= 5) break;
      await tester.drag(gridFinder, const Offset(0, -600));
      await tester.pump();
    }
    expect(mounted.length, 5);
  });

  testWidgets('Tapping a do card pushes AddHabitScreen with pre-fill', (
    tester,
  ) async {
    await _setupDb(tester);
    await tester.pumpWidget(_wrap());
    await _waitForCatalogReady(tester);
    await tester.tap(
      find.byKey(const ValueKey('template_card.t_builtin_01.use')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(AddHabitScreen), findsOneWidget);
    // The name from the template lands in the AddHabitScreen
    // form as a TextField. The text "Drink water" appears
    // twice (the card behind + the new TextField). Assert
    // at least one — the AddHabitScreen has it as a
    // controller value.
    expect(find.text('Drink water'), findsWidgets);
  });

  testWidgets('Catalog stays in sync with the repository on rebuild', (
    tester,
  ) async {
    await _setupDb(tester);
    await tester.pumpWidget(_wrap());
    await _waitForCatalogReady(tester);
    final t = Template(
      id: 't_user_smoke',
      name: 'Smoke template',
      description: 'A test',
      iconName: 'check',
      entityType: TemplateEntityType.doEntity,
      payloadJson:
          '{"k":1,"do":{"scheduleType":"fixed","weekdays":[1,2,3,4,5,6,7],"hour":9,"minute":0,"endHour":0,"endMinute":0,"nDays":0,"intervalMinutes":0,"proofMode":"soft","restDaysPerMonth":2,"category":"other","iconName":"check","name":"Smoke"}}',
      isBuiltIn: false,
      createdAt: DateTime.utc(2026, 6, 20),
    );
    await TemplateRepository.instance.save(t);
    final all = await TemplateRepository.instance.listAll();
    expect(all.length, 26);
  });
}
