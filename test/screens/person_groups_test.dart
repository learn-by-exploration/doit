// Widget tests for PersonGroupsScreen (WF-018).

// v1.7-η additions (SYS-163 / ADR-094 / WF-091): +8 tests
// covering the paused-chip + null-rotation + empty-state surfaces.
//
// Test count: 13 → 21 (+8 net — exactly matches plan).
// APK SHA1: N/A (tests-only cycle; see ADR-094 (e)).

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

  // ---------------- v1.7-η additions (SYS-163 / ADR-094 / WF-091) ----------------
  //
  // 8 tests across 3 batches:
  //   Batch 1 — Paused-chip (2 tests): pinned the per-row guards at
  //             `_GroupCard` (person_groups.dart:201, :215-223).
  //   Batch 2 — Null-rotation (3 tests): pinned the rotation selector
  //             invariant at `pickNextMember` (person_group.dart:166-185)
  //             exercised via the widget's `_load` (person_groups.dart:35-47).
  //   Batch 3 — Empty-state (3 tests): pinned the AddPersonGroupScreen
  //             title + empty-people copy + 5-channel ChoiceChips.

  // ----- Batch 1 — Paused-chip (2 tests) -----

  testWidgets(
    'Paused group does NOT render the Mark contacted CTA (still renders Delete) (v1.7-η / SYS-163)',
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
      // Sanity: the Paused chip IS rendered.
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
      // The Mark-contacted CTA must NOT render while paused
      // (person_groups.dart:201 — `if (row.nextPerson != null && !paused)`).
      expect(find.byKey(const ValueKey('group.g1.mark')), findsNothing);
      // The Delete IconButton must STILL render (no `!paused` guard at
      // person_groups.dart:215-223). The user can unpause by deleting + re-adding.
      expect(find.byKey(const ValueKey('group.g1.delete')), findsOneWidget);
    },
  );

  testWidgets(
    'Paused group still renders the cadence label + Members count (only Mark is suppressed) (v1.7-η / SYS-163)',
    (tester) async {
      await _resetDb(tester);
      await _seed();
      final group = (await PersonGroupRepository.instance.getById('g1'))!;
      await PersonGroupRepository.instance.save(
        group.copyWith(pausedUntil: DateTime(2027, 6)),
      );
      await tester.pumpWidget(const MaterialApp(home: PersonGroupsScreen()));
      await tester.pumpAndSettle();
      // The cadence label + Members count are unconditional (rendered
      // regardless of `paused`). Pins person_groups.dart:180-188.
      expect(find.textContaining('Every 7 days'), findsOneWidget);
      expect(find.textContaining('Members: 1'), findsOneWidget);
    },
  );

  // ----- Batch 2 — Null-rotation (3 tests) -----

  testWidgets(
    'Empty members list renders the group row but hides the "Next:" line + suppresses Mark (v1.7-η / SYS-163)',
    (tester) async {
      await _resetDb(tester);
      // Seed a group with NO members.
      await PersonGroupRepository.instance.save(
        ContactGroup(
          id: 'g_empty',
          name: 'EmptyGroup',
          cadence: const EveryNDays(7),
          semantic: GroupSemantic.rotation,
          channel: 'whatsapp',
          handle: '@empty',
          createdAt: DateTime(2026, 6),
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: PersonGroupsScreen()));
      await tester.pumpAndSettle();
      // The group name still renders.
      expect(find.text('EmptyGroup'), findsOneWidget);
      // No "Next:" line (person_groups.dart:189-196 — guarded on
      // `row.nextPerson != null && g.semantic == GroupSemantic.rotation`).
      expect(find.textContaining('Next:'), findsNothing);
      // Mark CTA also hidden (person_groups.dart:201 — `row.nextPerson != null`).
      expect(find.byKey(const ValueKey('group.g_empty.mark')), findsNothing);
      // Delete still available.
      expect(
        find.byKey(const ValueKey('group.g_empty.delete')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Pre-existing lastContacted on the older member → next pick is the null-lastContacted newer member (null beats contacted) (v1.7-η / SYS-163)',
    (tester) async {
      await _resetDb(tester);
      // Seed 2 people + 1 group + both members.
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
      await PersonGroupRepository.instance.addMember('g1', 'p2');
      // Mark p1 (the older member) as already contacted BEFORE pumping
      // the screen. Now p1.lastContactedMillis is set; p2 is null.
      // pickNextMember must pick p2 (null beats contacted, per
      // person_group.dart:176-177).
      await PersonGroupRepository.instance.markContacted(
        'g1',
        'p1',
        DateTime(2026, 6),
      );
      await tester.pumpWidget(const MaterialApp(home: PersonGroupsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Next: p2'), findsOneWidget);
      expect(find.text('Next: p1'), findsNothing);
    },
  );

  testWidgets(
    'Mark contacted on the current next → page refresh shows the OTHER member as next (rotation advances) (v1.7-η / SYS-163)',
    (tester) async {
      await _resetDb(tester);
      // Seed 2 people + 1 group + both members. Both start with
      // lastContactedMillis = null. Initial tie-break by addedAtMillis
      // (older wins, per person_group.dart:181) → p1 is the initial next.
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
      await PersonGroupRepository.instance.addMember('g1', 'p2');
      await tester.pumpWidget(const MaterialApp(home: PersonGroupsScreen()));
      await tester.pumpAndSettle();
      // Sanity: p1 is the initial next (addedAtMillis tie-break).
      expect(find.text('Next: p1'), findsOneWidget);
      // Tap Mark for p1.
      await tester.tap(find.byKey(const ValueKey('group.g1.mark')));
      await tester.pumpAndSettle();
      // After markContacted(p1) → p1.lastContacted is now; p2 is null.
      // pickNextMember → null beats contacted → p2 wins.
      expect(find.text('Next: p2'), findsOneWidget);
      expect(find.text('Next: p1'), findsNothing);
    },
  );

  // ----- Batch 3 — Empty-state (3 tests) -----

  testWidgets(
    'Add screen with existing != null shows "Edit group" title in AppBar (v1.7-η / SYS-163)',
    (tester) async {
      await _resetDb(tester);
      final existing = ContactGroup(
        id: 'g_edit',
        name: 'Edit Me',
        cadence: const EveryNDays(7),
        semantic: GroupSemantic.rotation,
        channel: 'whatsapp',
        handle: '@edit',
        createdAt: DateTime(2026, 6),
      );
      await tester.pumpWidget(
        MaterialApp(home: AddPersonGroupScreen(existing: existing)),
      );
      await tester.pumpAndSettle();
      // Pins person_groups.dart:378 — title is "Edit group" when existing != null.
      expect(find.text('Edit group'), findsOneWidget);
      expect(find.text('New group'), findsNothing);
    },
  );

  testWidgets(
    'Add screen with empty people list shows "No people added yet" copy (v1.7-η / SYS-163)',
    (tester) async {
      await _resetDb(tester);
      // No people seeded → _people list is empty after _loadPeople.
      await tester.pumpWidget(const MaterialApp(home: AddPersonGroupScreen()));
      await tester.pumpAndSettle();
      // Pins person_groups.dart:464-470 — empty-people branch.
      expect(find.textContaining('No people added yet'), findsOneWidget);
    },
  );

  testWidgets(
    'Add screen renders 5 channel ChoiceChips (dialer, whatsapp, telegram, signal, sms) (v1.7-η / SYS-163)',
    (tester) async {
      await _resetDb(tester);
      await tester.pumpWidget(const MaterialApp(home: AddPersonGroupScreen()));
      await tester.pumpAndSettle();
      // Pins person_groups.dart:410-416 — 5 channel ChoiceChips render.
      for (final ch in const [
        'dialer',
        'whatsapp',
        'telegram',
        'signal',
        'sms',
      ]) {
        expect(
          find.widgetWithText(ChoiceChip, ch),
          findsOneWidget,
          reason: 'Channel ChoiceChip for "$ch" must render',
        );
      }
    },
  );
}
