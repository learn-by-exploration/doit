// Tests for the template #16 ("Japan silent mode") routing
// short-circuit in TemplatesScreen
// (v1.0 / Phase F PR 2 / SYS-075 / ADR-019 follow-up) and
// the v1.1 (SYS-083) generic apply UX routing for
// templates #17..#21.
//
// Drives the screen through its public surface (no private
// widget re-export). Three assertions:
//   - Tapping template #16 routes to AddRoutineScreen.
//   - Tapping template #17 routes to RoutineApplyScreen (the
//     v1.1 generic apply UX, SYS-083 / ADR-027).
//   - Template #17 does NOT show the v1.0 "Coming in v1.1"
//     snackbar (the snackbar was replaced by the generic
//     apply UX in v1.1d).

import 'package:doit/screens/add_routine.dart';
import 'package:doit/screens/routine_apply.dart';
import 'package:doit/screens/templates.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/template_repository.dart';
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
  await TemplateLibrary.seedBuiltIns(TemplateRepository.instance);
}

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
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping template #16 routes to AddRoutineScreen', (
    tester,
  ) async {
    await _setupDb(tester);
    await tester.pumpWidget(_wrap());
    await _waitForCatalogReady(tester);

    // Filter to the Routine entity type so the test only
    // sees templates 16..21 (no scrolling through the
    // other 19 templates).
    await tester.tap(find.byKey(const ValueKey('templates.filter.routine')));
    await tester.pump();

    // Find template #16's card by its stable key.
    final cardFinder = find.byKey(const ValueKey('template_card.t_builtin_16'));
    expect(cardFinder, findsOneWidget);

    await tester.tap(cardFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(AddRoutineScreen), findsOneWidget);
  });

  testWidgets('tapping template #17 routes to the generic apply UX', (
    tester,
  ) async {
    await _setupDb(tester);
    await tester.pumpWidget(_wrap());
    await _waitForCatalogReady(tester);

    await tester.tap(find.byKey(const ValueKey('templates.filter.routine')));
    await tester.pump();

    final cardFinder = find.byKey(const ValueKey('template_card.t_builtin_17'));
    expect(cardFinder, findsOneWidget);

    await tester.tap(cardFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // v1.1d (SYS-083 / ADR-027): template #17 routes to the
    // generic RoutineApplyScreen, not the v1.0 Japan-only
    // AddRoutineScreen and not the v1.0 "Coming in v1.1"
    // snackbar.
    expect(find.byType(RoutineApplyScreen), findsOneWidget);
    expect(find.byType(AddRoutineScreen), findsNothing);
    expect(find.text('Routines land in v1.1.'), findsNothing);
  });
}
