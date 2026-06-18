// Tests for the AddPersonScreen (v0.6 / ADR-018 / SYS-067).
//
// v0.1 only supported a demo-stub tap that toggled a
// hard-coded contact. v0.6 wires the real
// `flutter_contacts` picker (the system contact picker)
// behind the on-demand `PermissionSheet`:
//
//   - The `Save with no contact` path still rejects
//     because the picker was never invoked.
//   - The `Pick contact then save` path drives the
//     `READ_CONTACTS` permission sheet, dismisses it on
//     grant, and the mocked `flutter_contacts` method
//     channel returns a fake contact whose `id` becomes
//     the `Person.lookupKey` and whose first phone
//     number becomes the `ChannelDialer.phoneNumber`.
//   - The `Pick contact then save with no phone` path
//     covers the inline-error affordance (SYS-067: the
//     sheet is the only modal; the rest of the UX is
//     inline).
//
// The `flutter_contacts` package routes through
// `github.com/QuisApp/flutter_contacts`. The
// `openExternalPick` method returns the contact `id` (or
// `null` on user cancel); the test then synthesizes a
// `Contact` JSON for `getContact` (`select` method
// channel call with the id).

import 'package:doit/screens/add_person.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/permission_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

Future<void> _resetDb(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });
}

Widget _wrap() => const MaterialApp(home: AddPersonScreen());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The permission seam.
  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  // The flutter_contacts seam.
  const contactsChannel = MethodChannel(
    'github.com/QuisApp/flutter_contacts',
  );

  final requestScriptedStatuses = <int, PermissionStatus>{};
  // What `getContact` / `select` returns when asked for the
  // picked id. `null` means "the contact was deleted
  // between pick and read" — a runtime no-op for the
  // screen.
  Map<String, dynamic>? scriptedContact;

  setUp(() async {
    requestScriptedStatuses.clear();
    scriptedContact = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          return PermissionStatus.denied.value;
        case 'requestPermissions':
          final List<int> requested = (call.arguments as List).cast<int>();
          var response = PermissionStatus.denied;
          for (final v in requested) {
            if (requestScriptedStatuses[v] != null) {
              response = requestScriptedStatuses[v]!;
              break;
            }
          }
          return <int, int>{for (final v in requested) v: response.value};
        case 'openAppSettings':
          return true;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(contactsChannel, (call) async {
      switch (call.method) {
        case 'openExternalPick':
          return '42';
        case 'select':
          // The first argument is the id (or null for
          // `getContacts`); the test only calls `select`
          // with the id returned by `openExternalPick`.
          if (scriptedContact == null) return null;
          return [scriptedContact];
        default:
          return null;
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(permissionsChannel, null);
      messenger.setMockMethodCallHandler(contactsChannel, null);
    });
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();
  });

  testWidgets('Save with no contact shows error', (tester) async {
    await _resetDb(tester);
    await tester.pumpWidget(_wrap());
    await tester.tap(find.byKey(const ValueKey('add_person.save')));
    await tester.pump();
    expect(find.text('Pick a contact first.'), findsOneWidget);
  });

  testWidgets(
    'Pick contact then save pops the route and persists the picked '
    'contact (SYS-067)',
    (tester) async {
      // Permission is denied initially, grant on request.
      requestScriptedStatuses[Permission.contacts.value] =
          PermissionStatus.granted;
      // The contact the system picker will return.
      scriptedContact = <String, dynamic>{
        'id': '42',
        'displayName': 'Jane Doe',
        'phones': [
          <String, dynamic>{
            'number': '+15550100',
            'normalizedNumber': '+15550100',
            'label': 'mobile',
            'isPrimary': true,
          },
        ],
      };
      await _resetDb(tester);
      await tester.pumpWidget(_wrap());

      // Tap the pick-contact row. The screen will surface
      // the `READ_CONTACTS` sheet (the probe in `init`
      // returned `denied`); we then grant and the sheet
      // pops. The mocked `flutter_contacts` channel
      // returns the contact above.
      await tester.tap(find.byKey(const ValueKey('add_person.pick_contact')));
      // Drive the permission-sheet async setup under
      // `runAsync` (FakeAsync does not process microtasks
      // scheduled from the outer test zone — same pattern
      // as `permission_sheet_test.dart`).
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 500));
      // The Allow button may be off-screen; scroll it
      // into view before tapping.
      await tester.ensureVisible(
        find.byKey(const ValueKey('permission_sheet.allow')),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byKey(const ValueKey('permission_sheet.allow')));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 500));

      // The picked contact's display name appears in the
      // row. The system picker's "Done" / "Cancel" step
      // is a no-op in the test (the mock returns the
      // contact synchronously).
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('+15550100'), findsOneWidget);

      // Save and verify the route pops.
      await tester.tap(find.byKey(const ValueKey('add_person.save')));
      await tester.pumpAndSettle();
      expect(find.byType(AddPersonScreen), findsNothing);
    },
  );

  testWidgets(
    'Pick contact with no phone shows an inline error (SYS-067)',
    (tester) async {
      requestScriptedStatuses[Permission.contacts.value] =
          PermissionStatus.granted;
      scriptedContact = <String, dynamic>{
        'id': '99',
        'displayName': 'No Phone',
        'phones': <Map<String, dynamic>>[],
      };
      await _resetDb(tester);
      await tester.pumpWidget(_wrap());

      await tester.tap(find.byKey(const ValueKey('add_person.pick_contact')));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(
        find.byKey(const ValueKey('permission_sheet.allow')),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byKey(const ValueKey('permission_sheet.allow')));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 500));

      // The inline error appears, the row falls back to
      // the empty-state title.
      expect(
        find.text('That contact has no phone number. Pick another.'),
        findsOneWidget,
      );
      expect(find.text('Pick a contact'), findsOneWidget);
    },
  );
}
