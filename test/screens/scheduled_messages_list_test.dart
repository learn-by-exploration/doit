// v1.8-pr-e2 / SYS-196 / ADR-126 / WF-122.
//
// Widget tests for the `ScheduledMessagesListScreen` (the
// "see + manage pending messages" view). The tests pin:
//   1. The empty state renders when there are zero pending
//      rows.
//   2. A pending row renders the cancel `AppIconButton`.
//   3. Tapping cancel removes the row from pending +
//      transitions it to the history section.
//   4. The history section is hidden when no history rows
//      exist.
//
// The widget tests use the canonical `_setUpApp(tester)`
// scaffold (in-memory Drift + fake ReminderService) so they
// can exercise the persistence path end-to-end without a
// real Android service.

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/screens/scheduled_messages_list.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/scheduled_message_repository.dart';
import 'package:doit/ui/empty_state.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _setUpApp(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  await AppDatabaseService.instance.init(
    overrideDb: AppDatabase(NativeDatabase.memory()),
  );
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });
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

Widget _wrap() => const MaterialApp(home: ScheduledMessagesListScreen());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty state renders when there are no rows', (tester) async {
    await _setUpApp(tester);
    await tester.pumpWidget(_wrap());
    await tester.pump();

    // The empty-state Primitive (lib/ui/empty_state.dart).
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No scheduled messages'), findsOneWidget);
  });

  testWidgets('a single pending row renders + shows the cancel CTA', (
    tester,
  ) async {
    await _setUpApp(tester);
    // Insert one row directly via the repository.
    await ScheduledMessageRepository.instance.insert(
      id: 'sm-1',
      personId: null,
      channelTag: 'sms',
      channelHandle: '+15555550100',
      messageBody: 'hello',
      fireAt: DateTime.now().add(const Duration(hours: 1)),
      createdAt: DateTime.now(),
    );
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.pumpAndSettle();

    // The tile renders the channel handle in the title.
    expect(find.text('+15555550100'), findsOneWidget);
    // The cancel button is keyed by row id.
    expect(
      find.byKey(const ValueKey('scheduled_messages_list.cancel.sm-1')),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping cancel transitions the row out of pending + into history',
    (tester) async {
      await _setUpApp(tester);
      await ScheduledMessageRepository.instance.insert(
        id: 'sm-cancel',
        personId: null,
        channelTag: 'sms',
        channelHandle: '+15555550100',
        messageBody: 'x',
        fireAt: DateTime.now().add(const Duration(hours: 1)),
        createdAt: DateTime.now(),
      );
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('scheduled_messages_list.cancel.sm-cancel')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('scheduled_messages_list.cancel.sm-cancel')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // The pending list is gone.
      final pending = await ScheduledMessageRepository.instance.listPending();
      expect(pending, isEmpty);
      // The total list still has the row (now cancelled).
      final all = await ScheduledMessageRepository.instance.listAll();
      expect(all, hasLength(1));
      expect(all.first.status.name, 'cancelled');
      // The pending cancel button is gone.
      expect(
        find.byKey(const ValueKey('scheduled_messages_list.cancel.sm-cancel')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'history section renders only when at least one non-pending row exists',
    (tester) async {
      await _setUpApp(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pumpAndSettle();

      // Empty DB → no "History" header.
      expect(find.text('History'), findsNothing);
      expect(find.text('Pending'), findsNothing);
    },
  );
}
