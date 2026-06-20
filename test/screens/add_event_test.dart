// Tests for AddEventScreen (Phase B PR 2):
//   - Pre-fills the form from an `initialPayload` (catalog apply
//     path) — name, lead time, recurrence, day-of-month.
//   - AppBar "Save as template" action captures the form state
//     into a Template row (`isBuiltIn: false`).
//   - The menu is shown in edit mode (existing != null) and
//     hidden in add mode (existing == null, only initialPayload).

import 'package:doit/events/event.dart';
import 'package:doit/screens/add_event.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/event_repository.dart';
import 'package:doit/services/template_repository.dart';
import 'package:doit/templates/template.dart';
import 'package:doit/templates/template_library.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _initDb() async {
  await AppDatabaseService.instance.closeForTesting();
  await AppDatabaseService.instance.init(
    overrideDb: AppDatabase(NativeDatabase.memory()),
  );
  await AppDatabaseService.instance.ready;
  // Touch the lazy singletons so the test path does not race
  // the seed/listAll future when AddEventScreen loads.
  EventRepository.instance;
  TemplateRepository.instance;
}

Future<void> _tearDown() => AppDatabaseService.instance.closeForTesting();

Widget _wrap(Widget child) {
  return MaterialApp(home: child);
}

/// Build a minimal Event suitable for the edit-mode test path.
Event _makeEvent(String name) {
  final now = DateTime.now();
  return Event(
    id: 'e_test_${now.millisecondsSinceEpoch}',
    name: name,
    atMillis: now.add(const Duration(days: 7)).millisecondsSinceEpoch,
    leadTimeMillis: const Duration(days: 1).inMilliseconds,
    createdAtMillis: now.millisecondsSinceEpoch,
  );
}

void main() {
  setUp(_initDb);
  tearDown(_tearDown);

  testWidgets('initialPayload pre-fills the name field', (tester) async {
    const payload = <String, dynamic>{
      'name': 'Pay rent reminder',
      'recurrence': 'monthly',
      'dayOfMonth': 1,
      'monthOfYear': 0,
      'leadTimeMillis': 86400000,
    };
    await tester.pumpWidget(
      _wrap(const AddEventScreen(initialPayload: payload)),
    );
    await tester.pumpAndSettle();
    final nameField = find.widgetWithText(TextField, 'Pay rent reminder');
    expect(nameField, findsOneWidget);
  });

  testWidgets('initialPayload with dayOfMonth rolls the date to day 1', (
    tester,
  ) async {
    const payload = <String, dynamic>{
      'name': 'Pay rent reminder',
      'recurrence': 'monthly',
      'dayOfMonth': 1,
      'monthOfYear': 0,
      'leadTimeMillis': 86400000,
    };
    await tester.pumpWidget(
      _wrap(const AddEventScreen(initialPayload: payload)),
    );
    await tester.pumpAndSettle();
    final dateTile = find.byWidgetPredicate(
      (w) =>
          w is ListTile && w.title is Text && (w.title as Text).data == 'Date',
    );
    expect(dateTile, findsOneWidget);
    final trailing = (tester.widget<ListTile>(dateTile).trailing as Text).data;
    expect(trailing, isNotNull);
    expect(trailing, endsWith('-01'));
  });

  testWidgets('Add mode (existing == null) hides the "Save as template" menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const AddEventScreen(
          initialPayload: <String, dynamic>{
            'name': 'My event',
            'recurrence': 'none',
            'leadTimeMillis': 60000,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The popup menu is only rendered in edit mode.
    expect(find.byKey(const ValueKey('add_event.menu')), findsNothing);
  });

  // Phase C PR 2 / SYS-072: the event form has a "Routines"
  // section. Verify the empty-state copy + Add a location
  // routine button render. Full automation UX is covered by
  // test/widgets/location_picker_test.dart and
  // test/routines/location_dispatch_test.dart.
  testWidgets('Routines section renders the empty-state and both '
      'Add a location routine / Add a calendar routine buttons '
      '(SYS-072 / Phase C PR 2 + SYS-074 / Phase E PR 2)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AddEventScreen(
          initialPayload: <String, dynamic>{
            'name': 'My event',
            'recurrence': 'none',
            'leadTimeMillis': 60000,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Routines'), findsOneWidget);
    expect(
      find.text(
        'No routines yet. Add one to fire this event when you '
        'arrive at or leave a place, or when a calendar '
        'event starts, ends, hits its reminder, or '
        'changes your busy status.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('add_event.add_location_routine')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('add_event.add_calendar_routine')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Edit mode (existing != null) shows the "Save as template" menu',
    (tester) async {
      final event = _makeEvent('Doctor appointment');
      // Drift writes must run in runAsync to step out of the
      // fake-async zone (Drift's stream-combinator does not
      // settle in testWidgets's microtask queue).
      await tester.runAsync(() => EventRepository.instance.save(event));
      await tester.pumpWidget(_wrap(AddEventScreen(existing: event)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add_event.menu')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('add_event.menu')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('add_event.save_as_template')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Save-as-template dialog writes a user-saved template with event envelope',
    (tester) async {
      final event = _makeEvent('Doctor appointment');
      await tester.runAsync(() => EventRepository.instance.save(event));
      await tester.pumpWidget(_wrap(AddEventScreen(existing: event)));
      await tester.pumpAndSettle();
      // Open menu → tap "Save as template".
      await tester.tap(find.byKey(const ValueKey('add_event.menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('add_event.save_as_template')),
      );
      await tester.pumpAndSettle();
      final nameField = find.byKey(
        const ValueKey('add_event.save_as_template.name'),
      );
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'My doctor template');
      await tester.tap(
        find.byKey(const ValueKey('add_event.save_as_template.save')),
      );
      // Save hits the Drift writer — step out of the
      // fake-async zone so the insertOnConflictUpdate
      // completes.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      final all =
          await tester.runAsync<List<Template>>(
            TemplateRepository.instance.listAll,
          ) ??
          <Template>[];
      final user = all.where((t) => !t.isBuiltIn).toList(growable: false);
      expect(user, hasLength(1));
      expect(user.first.name, 'My doctor template');
      expect(user.first.entityType, TemplateEntityType.event);
      expect(
        user.first.payloadJson,
        contains('"k":${TemplateLibrary.kTemplateFormatVersion}'),
      );
      expect(user.first.payloadJson, contains('"event"'));
    },
  );
}
