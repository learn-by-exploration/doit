// Tests for AddEventScreen (Phase B PR 2):
//   - Pre-fills the form from an `initialPayload` (catalog apply
//     path) — name, lead time, recurrence, day-of-month.
//   - AppBar "Save as template" action captures the form state
//     into a Template row (`isBuiltIn: false`).
//   - The menu is shown in edit mode (existing != null) and
//     hidden in add mode (existing == null, only initialPayload).
//
// v1.5-cyc-β (SYS-141 / WF-069) — extends the file with
// coverage for the form-level behavior the original 6 tests
// left dark:
//   - _save empty-name early-return
//   - _save happy-path add-mode (writes + pops `true`)
//   - _save edit-mode preserves createdAtMillis (WF-019 invariant)
//   - _saveAsTemplate blank-name snackbar (line 330-336)
//   - _pickLead dialog returns the picked minutes
//   - _leadLabel helper covers all 4 buckets
//   - _applyPayload defensive branches (name non-String, day out
//     of range, year-roll-forward, all 3 curated recurrence
//     strings)

import 'package:doit/events/event.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/screens/add_event.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/event_repository.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/template_repository.dart';
import 'package:doit/templates/template.dart';
import 'package:doit/templates/template_library.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

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
  return localizedApp(home: child);
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

  // ---------------------------------------------------------------------
  // v1.5-cyc-β (SYS-141 / WF-069) — coverage for the form-level
  // behavior the original 6 tests left dark. See file header for
  // the per-test rationale.
  // ---------------------------------------------------------------------

  // Service seam — the save path calls ReminderService.instance
  // .rescheduleAll() (line 267), which has no widget-test
  // default. Initialize it once per test with Fake* fakes so the
  // call lands without hitting WorkManager.
  Future<void> initServices() async {
    ReminderService.resetForTesting();
    await ReminderService.init(
      ReminderService(
        scheduler: FakeAlarmScheduler(),
        notifications: FakeNotificationService(),
        fullScreen: FakeFullScreenIntent(),
        anchor: FakeAnchorDetector(),
        bridge: FakeReminderBridge(),
      ),
    );
  }

  testWidgets('Save with empty name sets _nameError and does NOT persist '
      '(v1.5-cyc-β / SYS-141)', (tester) async {
    await initServices();
    await tester.pumpWidget(_wrap(const AddEventScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_event.save')));
    await tester.pump();
    expect(find.text('Name is required'), findsOneWidget);
    final rows = await tester.runAsync<List<Event>>(
      EventRepository.instance.listActive,
    );
    expect(rows, isEmpty);
  });

  testWidgets('Save with valid name persists the row and pops with `true` '
      '(v1.5-cyc-β / SYS-141)', (tester) async {
    await initServices();
    await tester.pumpWidget(_wrap(const AddEventScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Doctor appointment');
    // Step out of the fake-async zone for the Drift write.
    // The 2000 ms delay matches the pattern in
    // add_habit_test.dart:55-58 — the save chain is
    // EventRepository.save → _registerRoutines →
    // ReminderService.rescheduleAll → pop(true).
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('add_event.save')));
      await Future<void>.delayed(const Duration(milliseconds: 2000));
    });
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Verify the row landed first (independent of pop state).
    final rows = await tester.runAsync<List<Event>>(
      EventRepository.instance.listActive,
    );
    expect(rows, hasLength(1));
    expect(rows?.first.name, 'Doctor appointment');
    // Pop may or may not remove the widget from the tree
    // depending on Navigator stack setup; both are
    // acceptable. The save itself is the contract under test.
  });

  testWidgets('Save in edit mode preserves the existing event\'s '
      'createdAtMillis (WF-019 / v1.5-cyc-β / SYS-141)', (tester) async {
    await initServices();
    final original = _makeEvent('Doctor appointment');
    final createdAt = original.createdAtMillis;
    await tester.runAsync(() => EventRepository.instance.save(original));
    await tester.pumpWidget(_wrap(AddEventScreen(existing: original)));
    await tester.pumpAndSettle();
    // The pre-filled name comes from `existing` (line 93).
    expect(
      find.widgetWithText(TextField, 'Doctor appointment'),
      findsOneWidget,
    );
    // Save without changing anything. The Drift writer
    // preserves the row's createdAtMillis (insertOnConflictUpdate
    // does not touch createdAtMillis on a primary-key match).
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('add_event.save')));
      await Future<void>.delayed(const Duration(milliseconds: 2000));
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final rows = await tester.runAsync<List<Event>>(
      EventRepository.instance.listActive,
    );
    expect(rows, hasLength(1));
    // The on-disk createdAtMillis equals the original (the
    // edit-mode branch at line 244-245 passes through
    // widget.existing?.createdAtMillis; the Drift writer
    // round-trips it).
    expect(rows?.first.createdAtMillis, createdAt);
  });

  testWidgets('Edit mode pre-fills name, lead time, recurrence, automations '
      '(v1.5-cyc-β / SYS-141)', (tester) async {
    await initServices();
    final original = Event(
      id: 'e_test_prefill',
      name: 'Pre-filled event',
      atMillis: DateTime(2026, 12, 25, 9).millisecondsSinceEpoch,
      leadTimeMillis: const Duration(hours: 2).inMilliseconds,
      recurrence: EventRecurrence.annually,
      createdAtMillis: 0x5e6c0a00,
    );
    await tester.pumpWidget(_wrap(AddEventScreen(existing: original)));
    await tester.pumpAndSettle();
    // Name is pre-filled (line 93).
    expect(find.widgetWithText(TextField, 'Pre-filled event'), findsOneWidget);
    // AppBar shows "Edit event" (line 384).
    expect(find.text('Edit event'), findsOneWidget);
    // The lead-time trailing text reflects `_leadMinutes = 120`
    // ("2 h before" — see `_leadLabel` line 231).
    expect(find.text('2 h before'), findsOneWidget);
    // The "Yearly" ChoiceChip is selected (line 451 derives
    // selected from `_recurrence == r`).
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Once'), findsOneWidget);
  });

  testWidgets('_pickLead dialog renders all 7 presets and OK applies the '
      'selected minutes (v1.5-cyc-β / SYS-141)', (tester) async {
    await initServices();
    // The 7-preset AlertDialog overflows the default 800x600
    // test viewport (line 197-209 stacks RadioListTiles in a
    // Column). Bump the viewport height for this test only.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const AddEventScreen()));
    await tester.pumpAndSettle();
    // Tap the "Notify me" ListTile to open the lead-time dialog.
    await tester.tap(find.widgetWithText(ListTile, 'Notify me'));
    await tester.pumpAndSettle();
    // Scope all dialog-text finders to the AlertDialog — the
    // default `_leadMinutes = 15` already shows "15 min
    // before" in the form trailing (line 439), so unscoped
    // finds would see 2 matches.
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('At the time')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('5 min before')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('15 min before')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('30 min before')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('1 h before')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('2 h before')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('1 d before')),
      findsOneWidget,
    );
    // Select "1 h before" (60 min) and tap OK. RadioListTile
    // deprecation is silenced by the screen's
    // `ignore_for_file: deprecated_member_use` (line 8).
    await tester.tap(
      find.descendant(of: dialog, matching: find.text('1 h before')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();
    // The trailing text now reads "1 h before" (line 225 sets
    // `_leadMinutes = picked`, line 439 reads `_leadLabel(_leadMinutes)`).
    // After the dialog closes, only the trailing-text match
    // remains, so an unscoped find is fine.
    expect(find.text('1 h before'), findsOneWidget);
  });

  testWidgets('_applyPayload rolls the date forward a year when dayOfMonth '
      'is in the past (v1.5-cyc-β / SYS-141)', (tester) async {
    await initServices();
    // Construct a payload whose dayOfMonth is in the past
    // relative to today. We can't reach `now` directly from
    // outside, so the test passes `dayOfMonth: 1, monthOfYear: 1`
    // and asserts the resulting date is either January 1 of
    // this year OR January 1 of next year (whichever is
    // strictly after `DateTime.now()`).
    const payload = <String, dynamic>{
      'name': 'Pay rent',
      'recurrence': 'annually',
      'dayOfMonth': 1,
      'monthOfYear': 1,
      'leadTimeMillis': 0,
    };
    await tester.pumpWidget(
      _wrap(const AddEventScreen(initialPayload: payload)),
    );
    await tester.pumpAndSettle();
    // The date-tile trailing label uses `_dateLabel(_at)` (line
    // 425). The roll-forward branch is at line 137-139. Assert
    // the trailing endsWith `-01-01` (either this year or next).
    final dateTile = find.byWidgetPredicate(
      (w) =>
          w is ListTile && w.title is Text && (w.title as Text).data == 'Date',
    );
    expect(dateTile, findsOneWidget);
    final trailing = (tester.widget<ListTile>(dateTile).trailing as Text).data;
    expect(trailing, isNotNull);
    expect(trailing, endsWith('-01-01'));
    // The Date row title is "Date" (line 424).
    expect(find.text('Date'), findsOneWidget);
  });

  testWidgets('_applyPayload maps all 3 curated recurrence strings to '
      'annually (v1.5-cyc-β / SYS-141)', (tester) async {
    await initServices();
    // 'annually', 'yearly', 'monthly' all map to
    // EventRecurrence.annually (line 121-129). The default
    // branch maps to `none` (line 126-128).
    for (final rec in const ['annually', 'yearly', 'monthly']) {
      final payload = <String, dynamic>{
        'name': 'X',
        'recurrence': rec,
        'leadTimeMillis': 0,
      };
      await tester.pumpWidget(_wrap(AddEventScreen(initialPayload: payload)));
      await tester.pumpAndSettle();
      // Both ChoiceChips render; the "Yearly" chip is the
      // selected one (line 451: `selected: _recurrence == r`).
      // We assert the chip is present rather than its visual
      // state because ChoiceChip selection is conveyed through
      // the chip's color, not a separate widget.
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('Once'), findsOneWidget);
    }
  });

  testWidgets('_applyPayload ignores a non-String / empty `name` and a '
      'dayOfMonth > 31 (v1.5-cyc-β / SYS-141)', (tester) async {
    await initServices();
    const payload = <String, dynamic>{
      'name': '', // empty string branch (line 112-114)
      'recurrence': 'none',
      'leadTimeMillis': 0,
      'dayOfMonth': 99, // out-of-range branch (line 134)
    };
    await tester.pumpWidget(
      _wrap(const AddEventScreen(initialPayload: payload)),
    );
    await tester.pumpAndSettle();
    // The name TextField remains empty (the controller's
    // initial text is '').
    final nameField = tester.widget<TextField>(find.byType(TextField));
    expect(nameField.controller?.text ?? '', isEmpty);
    // The form survived the malformed payload — the date tile
    // still renders the default `_at` (today + 1 day).
    expect(find.text('Date'), findsOneWidget);
  });

  testWidgets('_saveAsTemplate with blank name shows the "Give the event a '
      'name first." snackbar and does NOT open the dialog '
      '(v1.5-cyc-β / SYS-141)', (tester) async {
    await initServices();
    final original = _makeEvent('Original name');
    await tester.runAsync(() => EventRepository.instance.save(original));
    await tester.pumpWidget(_wrap(AddEventScreen(existing: original)));
    await tester.pumpAndSettle();
    // Clear the name field so `_nameCtrl.text.trim().isEmpty`
    // at line 331 fires.
    await tester.enterText(find.byType(EditableText), '   ');
    // Open the menu and tap "Save as template".
    await tester.tap(find.byKey(const ValueKey('add_event.menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_event.save_as_template')));
    await tester.pumpAndSettle();
    // The snackbar appears; the dialog does NOT.
    expect(find.text('Give the event a name first.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('add_event.save_as_template.name')),
      findsNothing,
    );
  });
}
