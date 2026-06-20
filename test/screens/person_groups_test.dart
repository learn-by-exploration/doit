// Widget tests for PersonGroupsScreen (WF-018).

import 'package:doit/people/cadence.dart';
import 'package:doit/people/person.dart';
import 'package:doit/people/person_group.dart';
import 'package:doit/screens/person_groups.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/person_group_repository.dart';
import 'package:doit/services/person_repository.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _resetDb(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });
}

Future<void> _seed({String groupId = 'g1', String personId = 'p1'}) async {
  await PersonRepository.instance.save(
    ContactPerson(
      id: personId,
      lookupKey: 'lk_$personId',
      channel: const ChannelWhatsApp('+10000000000'),
      cadence: const EveryNDays(7),
      createdAt: DateTime(2026, 6),
    ),
  );
  await PersonGroupRepository.instance.save(
    ContactGroup(
      id: groupId,
      name: 'Friends',
      cadence: const EveryNDays(7),
      semantic: GroupSemantic.rotation,
      channel: 'whatsapp',
      handle: 'chat_uri',
      createdAt: DateTime(2026, 6),
    ),
  );
  await PersonGroupRepository.instance.addMember(groupId, personId);
}

void main() {
  setUp(() async {
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
  });

  testWidgets('Empty state shows the "No contact groups" copy', (tester) async {
    await _resetDb(tester);
    await tester.pumpWidget(const MaterialApp(home: PersonGroupsScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('No contact groups yet'), findsOneWidget);
  });

  testWidgets('Renders a seeded group with the next member', (tester) async {
    await _resetDb(tester);
    await _seed();
    await tester.pumpWidget(const MaterialApp(home: PersonGroupsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Friends'), findsOneWidget);
    expect(find.textContaining('Next:'), findsOneWidget);
  });

  testWidgets('Add screen shows the form and the Save action', (tester) async {
    await _resetDb(tester);
    await tester.pumpWidget(const MaterialApp(home: AddPersonGroupScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Save'), findsOneWidget);
  });
}
