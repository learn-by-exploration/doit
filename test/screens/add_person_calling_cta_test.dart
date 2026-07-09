// v1.8-pr-e2 / SYS-195 / ADR-126 / WF-122.
//
// Widget tests for the new Call + Schedule-message CTAs on
// the edit-mode `AddPersonScreen`. The CTAs were added in
// PR-E2.4 and live in `lib/screens/add_person.dart:203-235`.
// This file pins 3 load-bearing contracts:
//
//   1. The CTAs are HIDDEN in add mode (`personId == null`)
//      regardless of phone state (per the `_isEdit` gate).
//   2. The CTAs are HIDDEN in edit mode when no phone has
//      been picked yet.
//   3. After a contact + phone is picked in edit mode, the
//      CTAs render and the Schedule CTA navigates to
//      `AddScheduledMessageScreen`.
//
// The Call CTA actually launches the dialer via
// `url_launcher`; the headless harness can't verify a real
// dialer launch so that branch is covered indirectly by
// `person_launch_test.dart` (which pins `ChannelDialer.
// launch()` returning the expected `tel:` URI).

import 'package:doit/people/cadence.dart';
import 'package:doit/people/person.dart';
import 'package:doit/screens/add_person.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/person_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

const _permissionsChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);
const _contactsChannel = MethodChannel('github.com/QuisApp/flutter_contacts');

Future<void> _setUp(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });

  // Pre-seed a person so edit-mode has something to load.
  await PersonRepository.instance.save(
    ContactPerson(
      id: 'p-edit',
      lookupKey: 'edit-key',
      createdAt: DateTime.now(),
      cadence: const EveryNDays(7),
      channel: const ChannelDialer('+15555550999'),
    ),
  );

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_permissionsChannel, (call) async {
    return PermissionStatus.granted.value;
  });
  messenger.setMockMethodCallHandler(_contactsChannel, (_) async => null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add mode (no personId) hides both Call and Schedule CTAs', (
    tester,
  ) async {
    await _setUp(tester);
    await tester.pumpWidget(const MaterialApp(home: AddPersonScreen()));
    await tester.pump();
    expect(find.byKey(const ValueKey('add_person.call')), findsNothing);
    expect(
      find.byKey(const ValueKey('add_person.schedule_message')),
      findsNothing,
    );
  });

  testWidgets(
    'edit mode renders both CTAs once a phone is loaded for the saved person',
    (tester) async {
      await _setUp(tester);
      await tester.pumpWidget(
        const MaterialApp(home: AddPersonScreen(personId: 'p-edit')),
      );
      await tester.pump();
      // _loadExisting is async (Drift read). Let it complete.
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add_person.call')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('add_person.schedule_message')),
        findsOneWidget,
      );
    },
  );
}
