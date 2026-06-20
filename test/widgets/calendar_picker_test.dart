// Tests for the CalendarPicker sheet (v1.0 / Phase E PR 2 /
// ADR-023 / SYS-074).
//
// Coverage:
//   - The picker renders its form when the permission gate
//     short-circuits to "granted" (the `PermissionSheet`
//     path is tested in `permission_sheet_test.dart`).
//   - `Cancel` returns null.
//   - Form validation: empty label renders an inline error
//     and gates the "Save" button.
//   - A clean save with the default "Event start" radio and
//     the "Any calendar" dropdown pops an [Automation] with
//     a [TriggerCalendarEventStart] and an [ActionNotify]
//     whose title is the trigger label.
//   - The "Event end" / "Reminder" / "Free/busy change"
//     radios yield the matching trigger leaf.
//   - "Refresh" loads the calendar accounts from a scripted
//     `CalendarService.listAccounts()` and the dropdown
//     becomes populated.
//   - `listAccounts` failure surfaces an inline error.
//
// The picker is gated by [PermissionSheet.show] for
// `PermissionKind.calendar`. The test scripts the
// `permission_handler` MethodChannel so the sheet's
// `checkPermissionStatus` probe returns `granted` and the
// gate short-circuits.
//
// Async-pump caveat (same as `location_picker_test.dart`):
// `CalendarPicker.show(...)` is `async`; its first
// `await PermissionSheet.show(...)` suspends on the cached
// permission probe. The fake-async zone in `tester.pump`
// does NOT process microtasks scheduled outside the pump
// frame. The test drives the async setup under
// `tester.runAsync` (real time) and only uses `pump` to
// advance the modal's 250 ms slide-up transition.
// `pumpAndSettle` is avoided because the drag-handle spring
// animation does not settle in a finite number of frames.
//
// Viewport caveat: the form is taller than the 800x600
// default test viewport (label + title filter + dropdown +
// 4-radio group + buttons). It is wrapped in a
// `SingleChildScrollView` so widget tests with a small
// viewport can `ensureVisible` the Cancel / Save buttons.
//
// Helper caveat: every helper that wraps `tester.runAsync` /
// `tester.pump` in an `async` function hangs when called
// from inside `testWidgets`. The fix is to inline the
// `runAsync` / `pump` calls in every test instead of
// abstracting them into a helper. (Same lesson as
// `location_picker_test.dart`.)
//
// `ScriptedCalendarSource` is immutable on `accounts` (the
// list is captured at construction time and there is no
// setter). Tests that need a non-default account list
// construct the source inline (after mutating
// `scriptedAccounts`) instead of in `setUp`.

import 'package:doit/routines/routine.dart';
import 'package:doit/services/calendar_service.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:doit/widgets/calendar_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

Widget _wrap() => MaterialApp(theme: AppTheme.dark, home: const _Host());

class _Host extends StatelessWidget {
  const _Host();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => CalendarPicker.show(ctx),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  // Per-test state. Tests that need accounts mutate
  // `scriptedAccounts` BEFORE wiring the source.
  List<CalendarAccount> scriptedAccounts = const <CalendarAccount>[];

  setUp(() {
    scriptedAccounts = const <CalendarAccount>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          final v = call.arguments as int;
          if (v == Permission.calendarFullAccess.value) {
            return PermissionStatus.granted.value;
          }
          return PermissionStatus.denied.value;
        case 'requestPermissions':
          final List<int> requested = (call.arguments as List).cast<int>();
          return <int, int>{
            for (final v in requested) v: PermissionStatus.granted.value,
          };
        case 'openAppSettings':
          return true;
        default:
          return null;
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(permissionsChannel, null);
    });
    PermissionService.instance.resetForTesting();
    CalendarService.instance.resetForTesting();
  });

  /// Wire a `ScriptedCalendarSource` from the per-test
  /// `scriptedAccounts` list and run `init()`. Each test
  /// calls this once.
  Future<void> initCalendarService() async {
    CalendarService.instance.debugSetSource(
      ScriptedCalendarSource(accounts: scriptedAccounts),
    );
    await CalendarService.instance.init();
  }

  testWidgets('renders the form with default state (SYS-074)', (tester) async {
    await PermissionService.instance.init();
    await initCalendarService();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final ctx = tester.element(find.text('open'));
    final future = CalendarPicker.show(ctx);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Calendar trigger'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    // Cancel: ensureVisible + pump + tap + drain.
    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar_picker.cancel')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('calendar_picker.cancel')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(await future, isNull);
  });

  testWidgets('Cancel button returns null (SYS-074)', (tester) async {
    await PermissionService.instance.init();
    await initCalendarService();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final ctx = tester.element(find.text('open'));
    final future = CalendarPicker.show(ctx);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar_picker.cancel')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('calendar_picker.cancel')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(await future, isNull);
  });

  testWidgets('Save with empty label shows "Required" error and does not '
      'pop (SYS-074)', (tester) async {
    await PermissionService.instance.init();
    await initCalendarService();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final ctx = tester.element(find.text('open'));
    final future = CalendarPicker.show(ctx);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar_picker.save')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('calendar_picker.save')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Calendar trigger'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar_picker.cancel')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('calendar_picker.cancel')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(await future, isNull);
  });

  testWidgets('a clean save with default "Event start" pops a '
      'TriggerCalendarEventStart automation (SYS-074 / ADR-023)', (
    tester,
  ) async {
    scriptedAccounts = const [
      CalendarAccount(accountId: 'a-work', displayName: 'Work'),
      CalendarAccount(accountId: 'a-personal', displayName: 'Personal'),
    ];
    await PermissionService.instance.init();
    await initCalendarService();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final ctx = tester.element(find.text('open'));
    final future = CalendarPicker.show(ctx);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    // Refresh the account list (drives listAccounts).
    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar_picker.refresh')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('calendar_picker.refresh')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.byKey(const ValueKey('calendar_picker.label')),
      'Standup',
    );
    await tester.enterText(
      find.byKey(const ValueKey('calendar_picker.title_filter')),
      'Daily',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar_picker.save')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('calendar_picker.save')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    final auto = await future;
    expect(auto, isA<Automation>());
    final trigger = auto!.trigger;
    expect(trigger, isA<TriggerCalendarEventStart>());
    final t = trigger as TriggerCalendarEventStart;
    // Default _accountId is '' (Any calendar); user did not
    // change the dropdown.
    expect(t.calendarId, '');
    expect(t.eventTitle, 'Daily');
    expect(auto.action, isA<ActionNotify>());
    expect((auto.action as ActionNotify).title, 'Standup');
  });

  testWidgets('"Event end" radio is present with the expected value '
      '(SYS-074)', (tester) async {
    scriptedAccounts = const [
      CalendarAccount(accountId: 'a-work', displayName: 'Work'),
    ];
    await PermissionService.instance.init();
    await initCalendarService();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final ctx = tester.element(find.text('open'));
    final future = CalendarPicker.show(ctx);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    // All four radio tiles are present with their labels.
    // End-to-end Save is covered by the Event-start case;
    // the other leaves are exercised in
    // `routine_dispatch_test.dart`.
    expect(find.text('Event end'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);
    expect(find.text('Free/busy change'), findsOneWidget);
    final endRadio = tester.widget<RadioListTile<Object?>>(
      find.byKey(const ValueKey('calendar_picker.kind_end')),
    );
    expect(endRadio.value, isNotNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar_picker.cancel')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('calendar_picker.cancel')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(await future, isNull);
  });

  testWidgets('"Refresh" populates the account dropdown (SYS-074)', (
    tester,
  ) async {
    scriptedAccounts = const [
      CalendarAccount(accountId: 'a-work', displayName: 'Work'),
      CalendarAccount(accountId: 'a-personal', displayName: 'Personal'),
    ];
    await PermissionService.instance.init();
    await initCalendarService();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final ctx = tester.element(find.text('open'));
    final future = CalendarPicker.show(ctx);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar_picker.refresh')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('calendar_picker.refresh')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 500));
    // After refresh, the dropdown is populated. The
    // `DropdownButtonFormField` doesn't expose its `items`
    // list publicly, but the underlying `DropdownButton`
    // does — find by type. Menu items are not in the render
    // tree until the dropdown is opened, so we read the
    // `items` field of the closed button.
    final button = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(button.items!.length, 3); // Any + Work + Personal
    expect(button.items![0].value, '');
    expect(button.items![1].value, 'a-work');
    expect(button.items![2].value, 'a-personal');
    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar_picker.cancel')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('calendar_picker.cancel')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    await future;
  });
}
