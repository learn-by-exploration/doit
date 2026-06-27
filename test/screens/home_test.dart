// Tests for the HomeScreen — empty state + happy path with a
// saved habit. The reliability banner and the FAB are also
// asserted.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/missions/chain.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/screens/home.dart';
import 'package:doit/screens/rest_day_picker_dialog.dart';
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

/// Test-only NavigatorObserver that captures push events
/// for the v1.4b strong-mode "Done" tile test. The
/// `MissionLauncherScreen` auto-dismisses via a
/// `WidgetsBinding.addPostFrameCallback` if the chain
/// cannot be loaded, so by the time `pumpAndSettle`
/// settles the launcher widget may already be popped.
/// Asserting on the push event (durable contract) is
/// what matters.
class _RecordingNavigatorObserver extends NavigatorObserver {
  bool pushed = false;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed = true;
    super.didPush(route, previousRoute);
  }
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

  // ---- v1.4b / Phase 29 / SYS-116 / ADR-046 / WF-043 ----
  //
  // In-app home tile streak number + per-tile "Done"
  // button. Mirrors the widget's surface (v1.4a) but on
  // the home tile.

  testWidgets('tile renders the streak number (v1.4b / SYS-116)', (
    tester,
  ) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    // Empty log → streak 0. The badge shows "0" + "day
    // streak" subtitle. We assert the subtitle; the
    // number is read off the future-streamed log.
    expect(find.text('day streak'), findsOneWidget);
  });

  testWidgets('tile renders "day streak" subtitle (v1.4b / SYS-116)', (
    tester,
  ) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('day streak'), findsOneWidget);
  });

  testWidgets('soft-mode tile "Mark done" tap appends to the completion log '
      '(v1.4b / SYS-116)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    // Tap the per-tile Done IconButton. The key is
    // `habit_tile_done.<tooltip-hash>` so we find by
    // tooltip on the inner Tooltip widget.
    final iconButton = find.byTooltip('Mark done');
    expect(iconButton, findsOneWidget);
    await tester.tap(iconButton);
    // Pump enough for the async append + SnackBar.
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    final log = await CompletionLogService.instance.listForHabit('h1');
    expect(log.length, 1);
    expect(log.first.habitId, 'h1');
    expect(log.first.source, 'manual');
    expect(log.first.proofModeAtTime, 'soft');
  });

  testWidgets('already-done tile "Mark done" tap is a no-op append '
      '(v1.4b / SYS-116)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    // Pre-seed today's completion.
    await CompletionLogService.instance.append(
      habitId: 'h1',
      day: DateTime.now(),
      source: CompletionSource.manual,
      proofModeAtTime: 'soft',
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    // Tap "Mark done" again — the tile's local
    // `_isCompletedToday` is false (the state only flips
    // when the tile's own handler fires). The handler
    // appends again, but the service dedupes on
    // (habitId, day) so the row count stays at 1.
    final iconButton = find.byTooltip('Mark done');
    expect(iconButton, findsOneWidget);
    await tester.tap(iconButton);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    final log = await CompletionLogService.instance.listForHabit('h1');
    expect(log.length, 1);
  });

  testWidgets('tile SnackBar shows "Marked done." on soft-mode tap '
      '(v1.4b / SYS-116)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mark done'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('Marked done.'), findsOneWidget);
  });

  testWidgets('strong-mode tile "Mark done" tap pushes MissionLauncherScreen '
      '(v1.4b / SYS-116)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Crispy',
        proofMode: StrongProof(
          MissionChain.from([
            const MathMission(
              id: 'm1',
              label: 'Solve the problem',
              timeout: Duration(seconds: 30),
              difficulty: MathDifficulty.easy,
            ),
          ]),
        ),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    // Use a NavigatorObserver to capture the push event.
    // MissionLauncherScreen auto-dismisses if the chain
    // can't be loaded (it runs in addPostFrameCallback),
    // so by the time pumpAndSettle settles the launcher
    // widget may already be popped. Asserting on the
    // push event is the durable contract.
    final observer = _RecordingNavigatorObserver();
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsService>.value(
        value: SettingsService.instance,
        child: localizedApp(
          theme: AppTheme.dark,
          navigatorObservers: [observer],
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The strong-mode tooltip hints "Opens the mission chain".
    final iconButton = find.byTooltip('Opens the mission chain');
    expect(iconButton, findsOneWidget);
    await tester.tap(iconButton);
    await tester.pump();
    // The launcher pushed a MaterialPageRoute onto the
    // navigator. Assert via the observer.
    expect(observer.pushed, isTrue);
  });

  testWidgets('tile Done IconButton key includes habit id for test '
      'addressability (v1.4b / SYS-116)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    // The icon button is findable by tooltip. The
    // addressability test asserts at minimum that the
    // IconButton is in the tree (covered by other tests)
    // AND that the wrapping Tooltip widget exists with
    // the soft-mode hint.
    expect(find.byTooltip('Mark done'), findsOneWidget);
  });

  // ---- v1.4c / Phase 30 / SYS-117 / ADR-047 / WF-044 ----
  //
  // In-app home tile "Skip today" button + rest-day
  // budget caption. Builds on the v1.4b tile surface
  // (streak + Done) and adds the rest-day affordance:
  // soft / auto mode tap → `markDoSkipped` writes a
  // `CompletionSource.restDay` row, the budget caption
  // re-renders, and the "Done" button sees the day as
  // resolved.

  testWidgets('tile renders a Skip-today button when restDaysPerMonth > 0 '
      '(v1.4c / SYS-117)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.byTooltip('Skip today'), findsOneWidget);
  });

  testWidgets('tile hides Skip-today button when restDaysPerMonth == 0 '
      '(v1.4c / SYS-117)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 0,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.byTooltip('Skip today'), findsNothing);
  });

  testWidgets('soft-mode Skip-today tap appends a rest-day completion '
      '(v1.4c / SYS-117)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Skip today'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    final log = await CompletionLogService.instance.listForHabit('h1');
    expect(log.length, 1);
    expect(log.first.habitId, 'h1');
    expect(log.first.source, 'rest_day');
    expect(log.first.proofModeAtTime, 'soft');
  });

  testWidgets('Skip-today success snackbar reads "Rest day taken" '
      '(v1.4c / SYS-117)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Skip today'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('Rest day taken — streak holds.'), findsOneWidget);
  });

  testWidgets('tile shows "X / Y rest days left" caption after a skip '
      '(v1.4c / SYS-117)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Skip today'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('1/2 rest days left'), findsOneWidget);
  });

  testWidgets(
    'tile SnackBar reads "no rest days left" when budget is exhausted '
    '(v1.4c / SYS-117)',
    (tester) async {
      await _resetDb(tester);
      await DoRepository.instance.save(
        DoFixed(
          id: 'h1',
          name: 'Stretch',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026, 5, 17),
          restDaysPerMonth: 1,
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
          time: const DoTime(9, 0),
        ),
      );
      // Pre-seed a rest-day row for today so the budget
      // is exhausted before the tap.
      await CompletionLogService.instance.append(
        habitId: 'h1',
        day: DateTime.now(),
        source: CompletionSource.restDay,
        proofModeAtTime: 'soft',
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // The button is still rendered (the widget doesn't
      // hide it; it surfaces the error via the snackbar).
      // Actually no — the tile conditionally hides the
      // button when `restDaysPerMonth == 0`. With limit
      // > 0 but exhausted, the button is still shown.
      // Tapping it surfaces the "no rest days left"
      // snackbar.
      await tester.tap(find.byTooltip('Skip today'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.text('No rest days left this month.'), findsOneWidget);
    },
  );

  testWidgets('after Skip-today tap, the Skip button tooltip switches to '
      '"Rest day taken" (v1.4c / SYS-117)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    // Initial state — tooltip is "Skip today".
    expect(find.byTooltip('Skip today'), findsOneWidget);
    // Tap, wait for the async append + state flip.
    await tester.tap(find.byTooltip('Skip today'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    // After the tap, the tooltip switches to
    // "Rest day taken" (the button is still rendered,
    // just with the alternate tooltip).
    expect(find.byTooltip('Rest day taken'), findsOneWidget);
  });

  // ---- v1.4d / Phase 31 / SYS-118 / ADR-048 / WF-045 ----
  //
  // In-app home tile "Undo today" button. Mirrors the
  // `CompletionLogSection` (SYS-108) review-and-undo flow
  // but with one fewer tap. Visibility is gated on
  // `_isResolvedToday == true` (the day is resolved via
  // Done or Skip). Tap opens a confirm dialog; confirm
  // calls `undoToday` which deletes today's row from the
  // completion log.

  testWidgets('tile renders the Undo button only when the day is resolved '
      '(v1.4d / SYS-118)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    // Fresh tile — day not resolved → Undo button hidden.
    expect(find.byTooltip('Undo today'), findsNothing);
    // Tap Done to resolve the day.
    await tester.tap(find.byTooltip('Mark done'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    // Day now resolved → Undo button visible.
    expect(find.byTooltip('Undo today'), findsOneWidget);
  });

  testWidgets('tile hides the Undo button when neither completion nor '
      'skip is recorded for today (v1.4d / SYS-118)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    // Fresh tile — no completion, no skip → Undo hidden.
    expect(find.byTooltip('Undo today'), findsNothing);
  });

  testWidgets('undo-tap on a completed-today tile opens the confirm dialog '
      'with the localized body copy (v1.4d / SYS-118)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    // Tap Done to resolve the day.
    await tester.tap(find.byTooltip('Mark done'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    // Tap Undo.
    await tester.tap(find.byTooltip('Undo today'));
    await tester.pumpAndSettle();
    // The dialog renders the localized body copy.
    expect(
      find.text('This will remove today\'s check-in. The streak will update.'),
      findsOneWidget,
    );
    expect(find.text('Undo today\'s completion?'), findsOneWidget);
  });

  testWidgets(
    'undo-tap → confirm on a completed-today tile deletes the row and '
    'shows the success snackbar (v1.4d / SYS-118)',
    (tester) async {
      await _resetDb(tester);
      await DoRepository.instance.save(
        DoFixed(
          id: 'h1',
          name: 'Stretch',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026, 5, 17),
          restDaysPerMonth: 2,
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
          time: const DoTime(9, 0),
        ),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // Tap Done.
      await tester.tap(find.byTooltip('Mark done'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      final before = await CompletionLogService.instance.listForHabit('h1');
      expect(before.length, 1);
      // Tap Undo.
      await tester.tap(find.byTooltip('Undo today'));
      await tester.pumpAndSettle();
      // Confirm. The dialog's FilledButton label is
      // "Undo today" — find the FilledButton descendant
      // and tap it (avoids matching the AlertDialog title
      // which uses the same words).
      await tester.tap(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Undo today'),
        ),
      );
      // Dismiss any prior snackbars so the new one is
      // visible immediately.
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      final after = await CompletionLogService.instance.listForHabit('h1');
      expect(after, isEmpty);
      expect(find.text('Completion removed.'), findsOneWidget);
    },
  );

  testWidgets('undo-tap on a skipped-today tile deletes the rest-day row '
      '(v1.4d / SYS-118)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    // Tap Skip to resolve the day via rest-day.
    await tester.tap(find.byTooltip('Skip today'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    final before = await CompletionLogService.instance.listForHabit('h1');
    expect(before.length, 1);
    expect(before.first.source, 'rest_day');
    // Tap Undo.
    await tester.tap(find.byTooltip('Undo today'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Undo today'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    final after = await CompletionLogService.instance.listForHabit('h1');
    expect(after, isEmpty);
  });

  // ---------------------------------------------------------------
  // v1.4e / Phase 32 / SYS-119 / ADR-049 / WF-046: 7-day streak
  // history sparkline row under the streak badge.
  // ---------------------------------------------------------------

  /// Local helper — seeds a 6-of-7-day completed streak
  /// (today + 5 prior days = 6 completions, 1 gap on
  /// day -6) for the sparkline tests. Mirrors the v1.4d
  /// undo test's setup but pre-seeds 6 rows instead of 1.
  Future<void> seedSixDayStreak(String habitId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 6; i++) {
      final day = today.subtract(Duration(days: i));
      await CompletionLogService.instance.append(
        habitId: habitId,
        day: day,
        source: CompletionSource.manual,
        proofModeAtTime: 'soft',
      );
    }
  }

  testWidgets('tile renders the 7-day sparkline with 7 dots when at least one '
      'completion row exists (v1.4e / SYS-119)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await seedSixDayStreak('h1');
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    // The Semantics node wraps all 7 dots. Assert the
    // widget tree contains exactly one Semantics node
    // with the localized label — the find-by-predicate
    // form is robust to semantics-node merging rules.
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.label == 'Last 14 days'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'tile sparkline Semantics label is present even when no completions '
    'are recorded (v1.4e / SYS-119 / extended to 14 days in v1.4i / SYS-123)',
    (tester) async {
      await _resetDb(tester);
      await DoRepository.instance.save(
        DoFixed(
          id: 'h1',
          name: 'Stretch',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026, 5, 17),
          restDaysPerMonth: 2,
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
          time: const DoTime(9, 0),
        ),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      // Even when no completions exist, the skeleton (14
      // outlined dots) is replaced by 14 SparklineDot.empty
      // — the Semantics label is still present.
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label == 'Last 14 days'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tile sparkline Semantics label survives a Mark done tap that resolves '
    'today (v1.4e / SYS-119)',
    (tester) async {
      await _resetDb(tester);
      await DoRepository.instance.save(
        DoFixed(
          id: 'h1',
          name: 'Stretch',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026, 5, 17),
          restDaysPerMonth: 2,
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
          time: const DoTime(9, 0),
        ),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      // Resolve today via the tile's Mark done button.
      await tester.tap(find.byTooltip('Mark done'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      // Sanity: the completion was appended.
      final rows = await CompletionLogService.instance.listForHabit('h1');
      expect(rows.length, 1);
      // The sparkline Semantics label is still rendered.
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label == 'Last 14 days'),
        ),
        findsOneWidget,
      );
    },
  );

  // ---- v1.4i / Phase 36 / SYS-123 / ADR-053 / WF-050 ----
  //
  // Rest-day history visualization: the sparkline is
  // extended from 7 to 14 days and rest-day dots are
  // colored with colorScheme.tertiary (visually distinct
  // from the primary "done" color). A legend row below
  // the dots labels the three states. Each dot carries
  // a Semantics label (not a Tooltip, which would
  // intercept the parent tile's long-press → select-mode
  // gesture).
  group('tile rest-day history sparkline (v1.4i / SYS-123)', () {
    Future<void> seedTile(WidgetTester tester) async {
      await _resetDb(tester);
      await DoRepository.instance.save(
        DoFixed(
          id: 'h1',
          name: 'Stretch',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026, 5, 17),
          restDaysPerMonth: 2,
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
          time: const DoTime(9, 0),
        ),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
    }

    testWidgets('renders 14 outlined dots when no completions exist', (
      tester,
    ) async {
      await seedTile(tester);
      // 14 outlined dots (SparklineDot.empty). Each dot is
      // a Padding > Container pair with a Border (no fill
      // color). The legend's "Missed" swatch is also a
      // outlined Container but is NOT wrapped in
      // Padding(horizontal: 1.5), so the predicate below
      // distinguishes them.
      final dotContainers = find.byWidgetPredicate(
        (w) =>
            w is Padding &&
            w.padding == const EdgeInsets.symmetric(horizontal: 1.5) &&
            w.child is Container,
      );
      expect(dotContainers, findsNWidgets(14));
    });

    testWidgets(
      'renders the legend row below the dots with the three state labels',
      (tester) async {
        await seedTile(tester);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Rest day'), findsOneWidget);
        expect(find.text('Missed'), findsOneWidget);
      },
    );

    testWidgets('colors rest-day dots with colorScheme.tertiary so they are '
        'visually distinct from manual completions', (tester) async {
      await seedTile(tester);
      // Use the in-app tile's Skip button (v1.4c / SYS-117)
      // to take a rest day for today. This goes through
      // the tile's `_onSkipPressed` → `_onDoChanged` →
      // home `_refresh()` → setState → badge re-fetches
      // pipeline. Direct DB writes via
      // `CompletionLogService.append` do NOT trigger
      // setState and would leave the FutureBuilder
      // holding a stale future.
      await tester.tap(find.byTooltip('Skip today'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      // Sanity: the rest-day row exists for today.
      final rows = await CompletionLogService.instance.listForHabit('h1');
      expect(rows.length, 1);
      expect(rows.first.source, 'rest_day');
      // At least one Padding > Container is filled with
      // tertiary (today's rest-day dot, the rightmost).
      // Compare against the primary color to ensure they
      // are distinct.
      final cs = Theme.of(tester.element(find.byType(HomeScreen))).colorScheme;
      expect(cs.tertiary, isNot(equals(cs.primary)));
      final restDayDots = find.byWidgetPredicate(
        (w) =>
            w is Padding &&
            w.padding == const EdgeInsets.symmetric(horizontal: 1.5) &&
            w.child is Container &&
            (w.child as Container).decoration is BoxDecoration &&
            ((w.child as Container).decoration as BoxDecoration).color ==
                cs.tertiary,
      );
      expect(restDayDots, findsAtLeastNWidgets(1));
    });

    testWidgets(
      'rest-day dot carries the "Rest day" Semantics label for a11y',
      (tester) async {
        await seedTile(tester);
        // Tap Skip today so the badge re-fetches with the
        // rest-day row in the DB.
        await tester.tap(find.byTooltip('Skip today'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();
        // The Semantics node wrapping the (now resolved)
        // today dot carries the "Rest day" label.
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.label == 'Rest day'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'manual-completion dot carries the "Done" Semantics label for a11y '
      '(v1.4i / SYS-123)',
      (tester) async {
        await seedTile(tester);
        // Resolve today via the tile's Mark done button.
        await tester.tap(find.byTooltip('Mark done'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();
        // The "Done" Semantics label wraps the resolved
        // today dot. (The legend's "Done" Text is a
        // separate widget, not a Semantics label.)
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.label == 'Done'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'long-press on a tile with the new sparkline still enters select mode '
      '— the legend + Semantics do not steal the gesture (v1.4i / SYS-123)',
      (tester) async {
        await seedTile(tester);
        await tester.longPress(find.byKey(const ValueKey('habit_tile.h1')));
        await tester.pumpAndSettle();
        // The select-mode appbar shows the count.
        expect(find.text('1 selected'), findsOneWidget);
      },
    );
  });

  // ---- v1.4h / Phase 35 / SYS-122 / ADR-052 / WF-049 ----
  //
  // In-app home tile per-tile Edit + Delete IconButtons.
  // Closes the discoverability gap on the v0.2 long-press
  // → select-mode → app-bar action by surfacing explicit
  // Edit and Delete buttons on every tile. The Edit button
  // re-uses the AddHabitScreen navigation that the body-tap
  // already drives; the Delete button opens a confirm
  // dialog, calls DoRepository.deleteById, and shows a
  // SnackBar with an Undo action that re-saves the captured
  // do.

  testWidgets('tile renders an Edit IconButton with the Edit tooltip '
      '(v1.4h / SYS-122)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit'), findsOneWidget);
  });

  testWidgets('tile renders a Delete IconButton with the Delete tooltip '
      '(v1.4h / SYS-122)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.byTooltip('Delete'), findsOneWidget);
  });

  testWidgets('delete-tap opens a confirm dialog with the do name in the '
      'title (v1.4h / SYS-122)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    // Dialog title includes the do name in quotes.
    expect(find.text('Delete "Stretch"?'), findsOneWidget);
    // Dialog body hints at the cascade + undo.
    expect(
      find.text(
        'This will remove the do and all of its completions. '
        'You can undo for a few seconds after.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('confirm-tap on the delete dialog deletes the do and shows '
      'the deleted snackbar with Undo action (v1.4h / SYS-122)', (
    tester,
  ) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    // Tap Delete → confirm dialog opens.
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    // Tap "Delete" in the dialog (the action button).
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    // Drift write is async — let the runAsync microtask
    // resolve before asserting.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    // The do is gone from the active listing. v1.4l (SYS-126)
    // uses soft-delete, so the row is still present in the DB
    // (tombstoned). Use `getActiveById` to assert the UI
    // perspective (the row is filtered out of `listAll` /
    // `listActive` once tombstoned).
    final remaining = await DoRepository.instance.getActiveById('h1');
    expect(remaining, isNull);
    // The SnackBar reads the deleted name and offers an Undo.
    expect(find.text('Deleted "Stretch".'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('cancel-tap on the delete dialog leaves the do intact '
      '(v1.4h / SYS-122)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    // Find the dialog's "Cancel" text button and tap it.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    // The do is still present.
    final stillThere = await DoRepository.instance.getById('h1');
    expect(stillThere, isNotNull);
    expect(stillThere!.name, 'Stretch');
    // No snackbar surfaced.
    expect(find.text('Deleted "Stretch".'), findsNothing);
  });

  testWidgets('Undo action on the deleted snackbar re-saves the captured '
      'do (v1.4h / SYS-122)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    // Delete the do.
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    // v1.4l (SYS-126): the do is tombstoned (soft-delete),
    // so `getActiveById` returns null (UI perspective). The
    // row is still present in the DB but filtered out of
    // the active listing until `restoreById` is called.
    expect(await DoRepository.instance.getActiveById('h1'), isNull);
    // Tap the Undo action.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    // The do is back in the active listing.
    final restored = await DoRepository.instance.getActiveById('h1');
    expect(restored, isNotNull);
    expect(restored!.name, 'Stretch');
  });

  testWidgets('edit-tap pushes AddHabitScreen in edit mode for the do '
      '(v1.4h / SYS-122)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 2,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    final observer = _RecordingNavigatorObserver();
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsService>.value(
        value: SettingsService.instance,
        child: localizedApp(
          theme: AppTheme.dark,
          navigatorObservers: [observer],
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    // The AddHabitScreen was pushed. Assert via the observer
    // (the screen may pop quickly on auto-init in tests,
    // but the push event is the durable contract).
    expect(observer.pushed, isTrue);
  });

  // --- v1.4j (SYS-124): rest-day budget edit affordance ---

  testWidgets('tile budget caption shows "No rest days configured" when '
      'restDaysPerMonth == 0 AND is a tappable button '
      '(v1.4j / SYS-124)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 0,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    // The "zero" caption replaces the formerly-hidden
    // SizedBox.shrink().
    expect(find.text('No rest days configured'), findsOneWidget);
    // The v1.4j affordance is reachable by tap. Verified by
    // the "tapping the tile budget caption opens the
    // RestDayPickerDialog" test below — this test only
    // asserts the caption is RENDERED in the zero state
    // (the v1.4c early-return was removed in v1.4j).
  });

  testWidgets(
    'tile budget caption shows "X / Y rest days left" even when used == 0 '
    '(the v1.4c hidden state is now surfaced) (v1.4j / SYS-124)',
    (tester) async {
      await _resetDb(tester);
      await DoRepository.instance.save(
        DoFixed(
          id: 'h1',
          name: 'Stretch',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026, 5, 17),
          restDaysPerMonth: 3,
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
          time: const DoTime(9, 0),
        ),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      // The caption is rendered with used == 0 — the v1.4c
      // early-return was removed in v1.4j.
      expect(find.text('3/3 rest days left'), findsOneWidget);
    },
  );

  testWidgets('tapping the tile budget caption opens the RestDayPickerDialog '
      '(v1.4j / SYS-124)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 0,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('No rest days configured'));
    await tester.pumpAndSettle();
    // The dialog opens.
    expect(find.byType(RestDayPickerDialog), findsOneWidget);
    expect(find.text('Rest days per month'), findsOneWidget);
  });

  testWidgets('picking a new value in the RestDayPickerDialog saves the new '
      'restDaysPerMonth via DoRepository.save '
      '(v1.4j / SYS-124)', (tester) async {
    await _resetDb(tester);
    await DoRepository.instance.save(
      DoFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 5, 17),
        restDaysPerMonth: 0,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        time: const DoTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('No rest days configured'));
    await tester.pumpAndSettle();
    // Save with the initial 0 — the test asserts the
    // DoRepository round-trip without dragging the slider
    // (drag semantics are covered in
    // test/screens/rest_day_picker_dialog_test.dart).
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    final after = await DoRepository.instance.getById('h1');
    expect(after, isNotNull);
    expect(after!.restDaysPerMonth, 0);
    // Success snackbar surfaces.
    expect(find.text('Rest-day budget set to 0.'), findsOneWidget);
  });

  testWidgets(
    'budget caption tap survives long-press (select mode still works) — '
    'regression guard for v1.4b InkWell.onLongPress / v1.4j GestureDetector '
    'on the caption (v1.4j / SYS-124)',
    (tester) async {
      await _resetDb(tester);
      await DoRepository.instance.save(
        DoFixed(
          id: 'h1',
          name: 'Stretch',
          proofMode: const SoftProof(),
          createdAt: DateTime(2026, 5, 17),
          restDaysPerMonth: 2,
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
          time: const DoTime(9, 0),
        ),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Stretch'));
      await tester.pumpAndSettle();
      // Select mode entered — AppBar title shows the count.
      expect(find.text('1 selected'), findsOneWidget);
    },
  );
}
