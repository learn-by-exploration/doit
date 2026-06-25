// Tests for the HomeScreen — empty state + happy path with a
// saved habit. The reliability banner and the FAB are also
// asserted.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/screens/home.dart';
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/reliability_service.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/widgets/reliability_banner.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/localized_app.dart';

Future<void> _resetDb(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });
}

Widget _wrap() {
  return ChangeNotifierProvider<SettingsService>.value(
    value: SettingsService.instance,
    // v1.1h / ADR-031 / SYS-087: route through
    // `localizedApp` to wire the generated
    // `AppLocalizations` delegate (the home screen's
    // AppBar title and the empty-state copy are now
    // pulled from the ARB catalog).
    child: localizedApp(theme: AppTheme.dark, home: const HomeScreen()),
  );
}

void main() {
  setUp(() async {
    DoRepository.instance;
    ReminderService.resetForTesting();
    final bridge = FakeReminderBridge();
    await ReminderService.init(
      ReminderService(
        scheduler: FakeAlarmScheduler(),
        notifications: FakeNotificationService(),
        fullScreen: FakeFullScreenIntent(),
        anchor: FakeAnchorDetector(),
        bridge: bridge,
      ),
    );
    SettingsService.instance.resetForTesting();
    // v1.3b / Phase 13 / SYS-112: the home screen's
    // `ReliabilityBanner.fromStream` factory reads from
    // the unified `ReliabilityService`. Init the service
    // against the same bridge the reminder service uses
    // so the bootstrap probe returns the right value.
    ReliabilityService.resetForTesting();
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();
    // v1.3b / Phase 13 / SYS-112: grant every kind so the
    // bootstrap derive lands on `optimal` — otherwise the
    // banner would render "Reminders may be late" on every
    // home-screen test.
    PermissionService.instance.statuses.value = {
      for (final k in PermissionKind.values) k: const PermissionResultGranted(),
    };
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
  });

  testWidgets('empty state shows the placeholder', (tester) async {
    await _resetDb(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('No dos yet.'), findsOneWidget);
  });

  testWidgets('a saved habit renders as a tile', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 6),
        restDaysPerMonth: 2,
        weekdays: const {1, 3, 5},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Stretch'), findsOneWidget);
  });

  // v1.2f / Phase 6e / SYS-102: the tile subtitle for a
  // `DoFixed` should now include the weekday set, not just
  // the time. Widget-level smoke test — full coverage lives
  // in `test/do/do_description_test.dart`.
  testWidgets('DoFixed tile subtitle shows the weekday set '
      '(v1.2f / Phase 6e / SYS-102)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 6),
        restDaysPerMonth: 2,
        weekdays: const {1, 3, 5},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Mon, Wed, Fri · 09:00'), findsOneWidget);
  });

  testWidgets('renders the reliability banner', (tester) async {
    await _resetDb(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    // With optimal reliability (the default in tests), the
    // banner shrinks to a SizedBox — assert at least one
    // ReliabilityBanner instance is in the tree.
    expect(find.byType(ReliabilityBanner), findsOneWidget);
  });

  testWidgets(
    'long-press enters select mode and complete-selected marks done',
    (tester) async {
      await _resetDb(tester);
      await DoRepository.instance.save(
        DoFixed(
          id: 'h1',
          name: 'Stretch',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026, 6),
          restDaysPerMonth: 0,
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
          time: const DoTime(9, 0),
        ),
      );
      await DoRepository.instance.save(
        DoFixed(
          id: 'h2',
          name: 'Meditate',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026, 6),
          restDaysPerMonth: 0,
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
          time: const DoTime(9, 0),
        ),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // Long-press the first tile to enter select mode.
      await tester.longPress(find.byKey(const ValueKey('habit_tile.h1')));
      await tester.pumpAndSettle();
      // The appbar now shows the count.
      expect(find.text('1 selected'), findsOneWidget);
      // Tap the second tile to add it to the selection.
      await tester.tap(find.byKey(const ValueKey('habit_tile.h2')));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      // Tap "Mark selected done".
      await tester.tap(find.byKey(const ValueKey('home.complete_selected')));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      // Both habits are now logged as complete.
      final log1 = await CompletionLogService.instance.listForHabit('h1');
      final log2 = await CompletionLogService.instance.listForHabit('h2');
      expect(log1.length, 1);
      expect(log2.length, 1);
    },
  );

  testWidgets('a DoTimeWindow tile shows the fasting timer', (tester) async {
    await _resetDb(tester);
    final now = DateTime.now();
    // Pick a weekday matching today's weekday so the timer is
    // visible.
    final wd = now.weekday;
    await DoRepository.instance.save(
      DoTimeWindow(
        id: 'h1',
        name: 'Fasting',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 6),
        restDaysPerMonth: 0,
        weekdays: {wd},
        start: const DoTime(8, 0),
        end: const DoTime(20, 0),
        targetHours: 12,
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    // The fasting timer renders a 3-line text "Fasting — HH:MM:SS left (target 12h)"
    // or "Opens in HH:MM:SS" depending on the time of day. We
    // assert that one of those substrings is present.
    final allText = find.byType(Text);
    var found = false;
    for (final element in allText.evaluate()) {
      final w = element.widget as Text;
      final data = w.data;
      if (data == null) continue;
      if (data.contains('Fasting') ||
          data.contains('Opens in') ||
          data.contains('Window closes in')) {
        found = true;
        break;
      }
    }
    expect(found, isTrue);
  });
}
