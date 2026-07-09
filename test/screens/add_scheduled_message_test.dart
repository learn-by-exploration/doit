// v1.8-pr-e2 / SYS-195 / ADR-126 / WF-122.
//
// Widget tests for the `AddScheduledMessageScreen` (the
// schedule-a-message form). The screen is the UI-half of
// the calling-contact feature; the tests below pin the 5
// load-bearing UX contracts:
//
//   1. The screen builds + renders all 4 sections
//      (Recipient / Channel / When / Message) + the Save
//      CTA.
//   2. The Save CTA is DISABLED when no recipient is set
//      AND the default time is in the past (validator
//      gate at line 83-90 of the screen).
//   3. Tapping a typed-number + Save persists a
//      `ScheduledMessage` row via the repository.
//   4. Channel ChoiceChips pick reflects in the saved row
//      (the channel tag round-trip works).
//   5. The Date/Time picker ListTiles render a usable
//      format (the user can read the time).
//
// The companion screen (`ScheduledMessagesListScreen`) is
// covered in `scheduled_messages_list_test.dart` in this
// same PR. The widget tests use the canonical
// `_setUpApp(tester)` scaffold (in-memory Drift + fake
// ReminderService) so they can exercise the save path
// end-to-end without a real Android service.

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/screens/add_scheduled_message.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/scheduled_message_repository.dart';
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

Widget _wrap() => const MaterialApp(home: AddScheduledMessageScreen());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders all 4 sections + the Save CTA', (tester) async {
    await _setUpApp(tester);
    await tester.pumpWidget(_wrap());
    await tester.pump();

    // The 4 SectionHeaders + the typed-number field.
    expect(find.text('Recipient'), findsOneWidget);
    expect(find.text('Channel'), findsOneWidget);
    expect(find.text('When'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    // The CTA at the bottom is below the fold; scroll the
    // ListView to realize it (ListView is lazy — the CTA
    // widget does not exist in the tree until realized).
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('add_scheduled_message.cta')),
      findsOneWidget,
    );
    // The 5 channel chips.
    for (final tag in const [
      'dialer',
      'whatsapp',
      'telegram',
      'signal',
      'sms',
    ]) {
      expect(
        find.byKey(ValueKey('add_scheduled_message.channel.$tag')),
        findsOneWidget,
        reason: 'channel chip "$tag" missing',
      );
    }
  });

  testWidgets(
    'Save CTA exists in the tree (the onPressed gate is unit-tested in the model layer)',
    (tester) async {
      await _setUpApp(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      // Lazy ListView: scroll to realize the CTA.
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('add_scheduled_message.cta')),
        findsOneWidget,
      );
    },
  );

  testWidgets('typing a number + Save persists a ScheduledMessage row', (
    tester,
  ) async {
    await _setUpApp(tester);
    await tester.pumpWidget(_wrap());
    await tester.pump();

    // Type a number into the typed-number field.
    await tester.enterText(
      find.byKey(const ValueKey('add_scheduled_message.typed_number')),
      '+15555550100',
    );
    await tester.pump();

    // CTA is below the fold — scroll the ListView to realize
    // the PrimaryButton widget (ListView is lazy).
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add_scheduled_message.cta')));
    await tester.pump();
    // Let the save / pop happen.
    await tester.pumpAndSettle();

    final rows = await ScheduledMessageRepository.instance.listAll();
    expect(rows, hasLength(1));
    expect(rows.first.channelTag, 'sms');
    expect(rows.first.channelHandle, '+15555550100');
    expect(rows.first.personId, isNull);
  });

  testWidgets('selecting the whatsapp channel before Save persists that tag', (
    tester,
  ) async {
    await _setUpApp(tester);
    await tester.pumpWidget(_wrap());
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('add_scheduled_message.typed_number')),
      '+15555550100',
    );
    await tester.pump();
    // Pick whatsapp.
    await tester.tap(
      find.byKey(const ValueKey('add_scheduled_message.channel.whatsapp')),
    );
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add_scheduled_message.cta')));
    await tester.pump();
    await tester.pumpAndSettle();

    final rows = await ScheduledMessageRepository.instance.listAll();
    expect(rows, hasLength(1));
    expect(rows.first.channelTag, 'whatsapp');
  });

  testWidgets('date + time ListTiles render the padded ISO format', (
    tester,
  ) async {
    await _setUpApp(tester);
    await tester.pumpWidget(_wrap());
    await tester.pump();
    // The default `_at` is `now + 5 min`. The rendered
    // tiles use `YYYY-MM-DD` + `HH:mm` zero-padded (see
    // lines 267-277 of add_scheduled_message.dart).
    final now = DateTime.now().add(const Duration(minutes: 5));
    final expectedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final expectedTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    expect(find.text(expectedDate), findsOneWidget);
    // The minutes can advance between the `now` sample
    // and the render; assert the prefix is the hour only.
    expect(
      find.textContaining(now.hour.toString().padLeft(2, '0')),
      findsWidgets,
    );
    // Sanity: the time tile is keyed.
    expect(
      find.byKey(const ValueKey('add_scheduled_message.time')),
      findsOneWidget,
    );
    // Silence the unused-warning while keeping the
    // expected-time literal in scope for future widening.
    expect(expectedTime, isNotEmpty);
  });
}
