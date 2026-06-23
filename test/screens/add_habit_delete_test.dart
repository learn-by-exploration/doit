// Tests for the WF-022 hard-delete affordance on
// `AddHabitScreen` (edit mode).
//
// Pinning:
//   1. The popup menu exposes a "Delete…" entry only in
//      edit mode; new-do mode has no delete path.
//   2. Tapping the menu entry opens a confirm dialog with
//      the habit name in the title and the destructive
//      copy in the body.
//   3. Cancel keeps the screen and the row intact.
//   4. Delete calls `DoRepository.deleteById(habitId)` and
//      pops the route with `true` so the caller knows to
//      refresh immediately (the home screen reads the
//      pop value and calls its refresh callback).
//   5. A platform failure (deleteById throws) shows the
//      error snackbar and does NOT pop.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/screens/add_habit.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart' show AppDatabase;
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DoFixed _habit({String id = 'h_existing', String name = 'Stretch'}) {
  return DoFixed(
    id: id,
    name: name,
    createdAt: DateTime(2026, 6),
    restDaysPerMonth: 2,
    proofMode: const SoftProof(),
    weekdays: const {1, 3, 5},
    time: const DoTime(9, 0),
  );
}

Future<void> _seed(Do h) async {
  await DoRepository.instance.save(h);
}

Future<void> _wireServices(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  addTearDown(AppDatabaseService.instance.closeForTesting);
  DoRepository.instance;
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

/// Hosts the screen via a real `Navigator.push` (not as
/// `MaterialApp.home`). `AddHabitScreen._confirmAndDelete`
/// pops the route with `Navigator.of(context).pop(true)`,
/// which is a no-op on the root route. To exercise the
/// pop path in widget tests we have to push the screen.
class _PushedHost extends StatefulWidget {
  const _PushedHost({this.habitId});
  final String? habitId;

  @override
  State<_PushedHost> createState() => _PushedHostState();
}

class _PushedHostState extends State<_PushedHost> {
  bool _pushed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const ValueKey('pushed_host.open'),
          onPressed: _pushed
              ? null
              : () {
                  setState(() => _pushed = true);
                  Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => AddHabitScreen(habitId: widget.habitId),
                    ),
                  );
                },
          child: const Text('Open'),
        ),
      ),
    );
  }
}

Future<void> _openPushed(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('pushed_host.open')),
    warnIfMissed: false,
  );
  await tester.pumpAndSettle();
}

Future<void> _openPushedWithId(WidgetTester tester, String habitId) async {
  // Re-host with the correct habitId so the pushed
  // AddHabitScreen loads it.
  await tester.pumpWidget(MaterialApp(home: _PushedHost(habitId: habitId)));
  await tester.pump();
  await _openPushed(tester);
}

Widget _host() => const MaterialApp(home: _PushedHost());

void main() {
  testWidgets('new-do mode does NOT expose the Delete menu entry', (
    tester,
  ) async {
    await _wireServices(tester);
    await tester.pumpWidget(_host());
    await tester.pump();
    await _openPushed(tester);
    // No menu button when habitId is null.
    expect(find.byKey(const ValueKey('add_habit.menu')), findsNothing);
  });

  testWidgets('edit mode exposes Delete… in the popup menu', (tester) async {
    await _wireServices(tester);
    await _seed(_habit());
    await tester.pumpWidget(_host());
    await tester.pump();
    await _openPushedWithId(tester, 'h_existing');
    expect(find.byKey(const ValueKey('add_habit.menu')), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('add_habit.menu')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('add_habit.delete')), findsOneWidget);
    expect(find.text('Delete…'), findsOneWidget);
  });

  testWidgets('tapping Delete opens the confirm dialog with the habit name', (
    tester,
  ) async {
    await _wireServices(tester);
    await _seed(_habit(name: 'Drink water'));
    await tester.pumpWidget(_host());
    await tester.pump();
    await _openPushedWithId(tester, 'h_existing');
    await tester.tap(
      find.byKey(const ValueKey('add_habit.menu')),
      warnIfMissed: false,
    );
    // Drain the menu's open animation. The PopupMenu
    // opens inside an Overlay; the tap target is the
    // item's inner InkWell which is fully laid out after
    // a couple frames.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Tap the delete item by key.
    await tester.tap(
      find.byKey(const ValueKey('add_habit.delete')),
      warnIfMissed: false,
    );
    // The menu dismisses synchronously; showDialog pushes
    // a route. Drive the async chain under real time so
    // the Future returned by showDialog resolves.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byType(AlertDialog),
      findsOneWidget,
      reason: 'tapping add_habit.delete should open the confirm dialog',
    );
    expect(
      find.byKey(const ValueKey('add_habit.delete.confirm')),
      findsOneWidget,
    );
    expect(find.text('Delete "Drink water"?'), findsOneWidget);
    expect(find.textContaining('This cannot be undone.'), findsOneWidget);
  });

  testWidgets('Cancel keeps the screen and the do intact', (tester) async {
    await _wireServices(tester);
    await _seed(_habit());
    await tester.pumpWidget(_host());
    await tester.pump();
    await _openPushedWithId(tester, 'h_existing');
    await tester.tap(
      find.byKey(const ValueKey('add_habit.menu')),
      warnIfMissed: false,
    );
    // Drain the menu's open animation so the tap target
    // is fully laid out.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(
      find.byKey(const ValueKey('add_habit.delete')),
      warnIfMissed: false,
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey('add_habit.delete.cancel')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AddHabitScreen), findsOneWidget);
    final list = await tester.runAsync<List<Do>>(DoRepository.instance.listAll);
    expect(list?.length, 1);
    expect(list?.first.id, 'h_existing');
  });

  testWidgets('Delete calls DoRepository.deleteById and pops', (tester) async {
    await _wireServices(tester);
    await _seed(_habit());
    await tester.pumpWidget(_host());
    await tester.pump();
    await _openPushedWithId(tester, 'h_existing');
    await tester.tap(
      find.byKey(const ValueKey('add_habit.menu')),
      warnIfMissed: false,
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(
      find.byKey(const ValueKey('add_habit.delete')),
      warnIfMissed: false,
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey('add_habit.delete.confirm_button')),
      warnIfMissed: false,
    );
    // Pop animation + repo write — drive the async chain
    // under real time so the Future returned by
    // `deleteById` resolves before the next pump.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.byType(AddHabitScreen), findsNothing);
    final list = await tester.runAsync<List<Do>>(DoRepository.instance.listAll);
    expect(list, isEmpty);
  });

  testWidgets(
    'a deleteById failure shows the error snackbar and does NOT pop',
    (tester) async {
      await _wireServices(tester);
      await _seed(_habit());
      await tester.pumpWidget(_host());
      await tester.pump();
      await _openPushedWithId(tester, 'h_existing');
      // Inject a throwing delete via the @visibleForTesting
      // hook on the state.
      final state = tester.state<AddHabitScreenState>(
        find.byType(AddHabitScreen),
      );
      state.deleteOverride = (String _) async {
        throw StateError('simulated platform failure');
      };
      await tester.tap(
        find.byKey(const ValueKey('add_habit.menu')),
        warnIfMissed: false,
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(
        find.byKey(const ValueKey('add_habit.delete')),
        warnIfMissed: false,
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.byKey(const ValueKey('add_habit.delete.confirm_button')),
        warnIfMissed: false,
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // The screen stays; the snackbar is visible.
      expect(find.byType(AddHabitScreen), findsOneWidget);
      expect(find.text('Delete failed. Please try again.'), findsOneWidget);
    },
  );
}
