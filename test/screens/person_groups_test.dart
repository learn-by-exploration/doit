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

  testWidgets(
    'Paused group renders the "Paused" chip instead of the semantic chip',
    (tester) async {
      await _resetDb(tester);
      await _seed();
      // Pause the group for 30 days.
      final group = (await PersonGroupRepository.instance.getById('g1'))!;
      await PersonGroupRepository.instance.save(
        group.copyWith(pausedUntil: DateTime(2027, 6)),
      );
      await tester.pumpWidget(const MaterialApp(home: PersonGroupsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
      // The "Rotation" semantic chip must NOT render while paused.
      expect(find.text('Rotation'), findsNothing);
    },
  );

  testWidgets('Semantic "any" group does NOT render the "Next:" line', (
    tester,
  ) async {
    await _resetDb(tester);
    await _seed();
    // Switch to GroupSemantic.any.
    final g = (await PersonGroupRepository.instance.getById('g1'))!;
    await PersonGroupRepository.instance.save(
      g.copyWith(semantic: GroupSemantic.any),
    );
    await tester.pumpWidget(const MaterialApp(home: PersonGroupsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Next:'), findsNothing);
    // The Mark-contacted CTA is NOT gated on semantic (per
    // `_GroupCard`: `row.nextPerson != null && !paused`), so it
    // still renders for semantic=any. The semantic only
    // affects the "Next:" label.
    expect(find.byKey(const ValueKey('group.g1.mark')), findsOneWidget);
  });

  testWidgets('Semantic "all" group does NOT render the "Next:" line', (
    tester,
  ) async {
    await _resetDb(tester);
    await _seed();
    final g = (await PersonGroupRepository.instance.getById('g1'))!;
    await PersonGroupRepository.instance.save(
      g.copyWith(semantic: GroupSemantic.all),
    );
    await tester.pumpWidget(const MaterialApp(home: PersonGroupsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Next:'), findsNothing);
  });

  testWidgets('Members count renders the count from the membership table', (
    tester,
  ) async {
    await _resetDb(tester);
    // Seed 3 people + 1 group, then add all 3 to the group.
    await _seed();
    await PersonRepository.instance.save(
      ContactPerson(
        id: 'p2',
        lookupKey: 'lk_p2',
        channel: const ChannelWhatsApp('+10000000002'),
        cadence: const EveryNDays(7),
        createdAt: DateTime(2026, 6),
      ),
    );
    await PersonRepository.instance.save(
      ContactPerson(
        id: 'p3',
        lookupKey: 'lk_p3',
        channel: const ChannelWhatsApp('+10000000003'),
        cadence: const EveryNDays(7),
        createdAt: DateTime(2026, 6),
      ),
    );
    await PersonGroupRepository.instance.addMember('g1', 'p2');
    await PersonGroupRepository.instance.addMember('g1', 'p3');
    await tester.pumpWidget(const MaterialApp(home: PersonGroupsScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Members: 3'), findsOneWidget);
  });

  testWidgets(
    'Tap Mark contacted updates lastContactedMillis on the membership row',
    (tester) async {
      await _resetDb(tester);
      await _seed();
      // Sanity: lastContactedMillis is null on the fresh member.
      final membersBefore = await PersonGroupRepository.instance.listMembers(
        'g1',
      );
      expect(membersBefore.first.lastContactedMillis, isNull);
      await tester.pumpWidget(const MaterialApp(home: PersonGroupsScreen()));
      await tester.pumpAndSettle();
      // Tap the Mark contacted CTA on the g1 row.
      await tester.tap(find.byKey(const ValueKey('group.g1.mark')));
      await tester.pumpAndSettle();
      final membersAfter = await PersonGroupRepository.instance.listMembers(
        'g1',
      );
      expect(membersAfter.first.lastContactedMillis, isNotNull);
    },
  );

  testWidgets('Tap Delete removes the group from the list', (tester) async {
    await _resetDb(tester);
    await _seed();
    await tester.pumpWidget(const MaterialApp(home: PersonGroupsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Friends'), findsOneWidget);
    // Tap delete on the g1 row.
    await tester.tap(find.byKey(const ValueKey('group.g1.delete')));
    await tester.pumpAndSettle();
    // After delete + refresh, the empty-state copy is shown.
    expect(find.text('Friends'), findsNothing);
    expect(find.textContaining('No contact groups yet'), findsOneWidget);
  });

  testWidgets(
    'Add screen surfaces a name validation error when Save is tapped empty',
    (tester) async {
      await _resetDb(tester);
      await tester.pumpWidget(const MaterialApp(home: AddPersonGroupScreen()));
      await tester.pumpAndSettle();
      // Tap Save with both name and handle empty.
      await tester.tap(find.byKey(const ValueKey('add_person_group.save')));
      await tester.pumpAndSettle();
      // The form's name-error path runs first ("Name is required").
      expect(find.text('Name is required'), findsOneWidget);
    },
  );

  testWidgets(
    'Add screen surfaces a handle validation error when only name is set',
    (tester) async {
      await _resetDb(tester);
      await tester.pumpWidget(const MaterialApp(home: AddPersonGroupScreen()));
      await tester.pumpAndSettle();
      // Enter name only.
      await tester.enterText(
        find.widgetWithText(TextField, 'Group name'),
        'Test group',
      );
      await tester.tap(find.byKey(const ValueKey('add_person_group.save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Handle'), findsOneWidget);
    },
  );

  testWidgets(
    'Add screen: tapping Weekly cadence switches the params widget to a '
    'weekday DropdownButton',
    (tester) async {
      await _resetDb(tester);
      await tester.pumpWidget(const MaterialApp(home: AddPersonGroupScreen()));
      await tester.pumpAndSettle();
      // Default is every_n_days — "Days:" label visible.
      expect(find.text('Days:'), findsOneWidget);
      // Tap the Weekly ChoiceChip.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Weekly'));
      await tester.pumpAndSettle();
      // Params switch to a "Weekday:" DropdownButton. The
      // Dropdown's selected value defaults to Monday
      // (`DateTime.monday` = 1); the other 6 weekday items are
      // only visible after the dropdown is opened.
      expect(find.text('Weekday:'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
    },
  );

  testWidgets(
    'Add screen: completing the form + Save persists the group with members',
    (tester) async {
      await _resetDb(tester);
      // Seed 2 people so the member picker has rows.
      await _seed();
      await PersonRepository.instance.save(
        ContactPerson(
          id: 'p2',
          lookupKey: 'lk_p2',
          channel: const ChannelWhatsApp('+10000000002'),
          cadence: const EveryNDays(7),
          createdAt: DateTime(2026, 6),
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: AddPersonGroupScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Group name'),
        'Squad',
      );
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Channel handle (URI / phone / @handle)',
        ),
        '@squad',
      );
      // Tap the member checkbox for p1.
      await tester.tap(find.byKey(const ValueKey('group.member.p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add_person_group.save')));
      await tester.pumpAndSettle();
      // The seed inserted 'Friends' as group 'g1'; this test added
      // 'Squad' as a second group with id auto-generated as
      // `g_${millisSinceEpoch}`. Verify both exist.
      final all = await PersonGroupRepository.instance.listAll();
      expect(all.length, 2);
      expect(
        all.any((g) => g.name == 'Squad'),
        isTrue,
        reason: 'New "Squad" group should be persisted alongside "Friends"',
      );
      final squadId = all.firstWhere((g) => g.name == 'Squad').id;
      final members = await PersonGroupRepository.instance.listMembers(squadId);
      expect(members.length, 1);
      expect(members.first.personId, 'p1');
    },
  );
}
