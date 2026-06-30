// v1.4-stab-L / Phase 52 / SYS-139 / ADR-070 / WF-067:
// widget-rebuild benchmark.
//
// Pins the per-cycle cost of a Listenable-driven rebuild
// inside a MaterialApp + Provider tree, similar to what
// the home screen does on every `setState`. Each scenario:
//   1. Build the widget tree ONCE outside the measurement
//      loop (no `pumpWidget` re-mounts inside the loop —
//      those would include FutureBuilder + DB queries and
//      dominate the signal).
//   2. Force a rebuild via a ValueNotifier push /
//      setState-equivalent.
//   3. Measure the median across 100 rebuilds.
//
// The budget (≤ 1 ms median per cycle) is generous — the
// rebuilt subtree is small. The point is to catch a future
// regression that introduces heavy synchronous work to
// build() (e.g. a `find.byType(...)` scan, a DB read on
// the UI thread, or a JSON parse in the hot path).

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/reliability_service.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/localized_app.dart';

/// Per-cycle drift lesson: use the median, not every-run, to
/// be robust against CI noise (single timings can spike 5-10x
/// across runs).
int _median(List<int> xs) {
  final sorted = List<int>.from(xs)..sort();
  return sorted[sorted.length ~/ 2];
}

/// A trivial widget that subscribes to a [Listenable] and
/// re-renders on each push. This is the widget we measure —
/// it stands in for "the home tile's render path".
class _CounterTile extends StatelessWidget {
  const _CounterTile({required this.notifier});

  final ValueNotifier<int> notifier;

  @override
  Widget build(BuildContext context) {
    final v = notifier.value;
    return Material(
      child: ListTile(
        leading: const Icon(Icons.check),
        title: Text('counter=$v'),
        subtitle: const Text('subtitle'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

Future<void> _resetDb() async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
}

Future<void> _bootstrapServices() async {
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
  ReliabilityService.resetForTesting();
  PermissionService.instance.resetForTesting();
  await PermissionService.instance.init();
  PermissionService.instance.statuses.value = {
    for (final k in PermissionKind.values) k: const PermissionResultGranted(),
  };
  await ReliabilityService.init(
    bridge: bridge,
    permissionService: PermissionService.instance,
  );
}

void main() {
  const iterations = 100;
  // Budgets calibrated against observed `flutter test`
  // numbers (debug build, fake-async). Real-device build
  // perf is 3-5x faster; the test pins the regression
  // direction, not absolute perf. See
  // `docs/v_model/performance_baseline.md` for the observed
  // baseline numbers.
  const coldMountBudgetMicros = 750000; // 750 ms — first
  const singleTileRebuildBudgetMicros = 5000; // 5 ms
  const tenTileRebuildBudgetMicros = 25000; // 25 ms

  setUp(() async {
    await _resetDb();
    addTearDown(() async {
      await AppDatabaseService.instance.closeForTesting();
    });
    await _bootstrapServices();
  });

  testWidgets('cold widget tree mount stays under budget', (tester) async {
    // Arrange — mount once to capture the cold-start cost.
    final sw = Stopwatch()..start();
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsService>.value(
        value: SettingsService.instance,
        child: localizedApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
    sw.stop();

    // Assert — cold mount budget. Mount includes
    // Theme.of, AppLocalizations delegate init, Provider
    // wiring.
    expect(
      sw.elapsedMicroseconds,
      lessThanOrEqualTo(coldMountBudgetMicros),
      reason:
          'cold mount took ${sw.elapsedMicroseconds} µs '
          '(> $coldMountBudgetMicros µs)',
    );
  });

  testWidgets('Listenable-driven rebuild stays under budget', (tester) async {
    // Arrange — build once, outside the measurement loop.
    final notifier = ValueNotifier<int>(0);
    addTearDown(notifier.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsService>.value(
        value: SettingsService.instance,
        child: localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: notifier,
              builder: (_, value, _) => _CounterTile(notifier: notifier),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Act — measure the per-rebuild cost.
    final samples = <int>[];
    for (var i = 0; i < iterations; i++) {
      notifier.value = i + 1;
      final sw = Stopwatch()..start();
      await tester.pump();
      sw.stop();
      samples.add(sw.elapsedMicroseconds);
    }

    // Assert
    final med = _median(samples);
    expect(
      med,
      lessThanOrEqualTo(singleTileRebuildBudgetMicros),
      reason:
          'Listenable-driven rebuild median $med µs exceeded '
          '$singleTileRebuildBudgetMicros µs over $iterations iterations',
    );
  });

  testWidgets('parent rebuild with stable child widget stays under budget', (
    tester,
  ) async {
    // Arrange — build a parent that rebuilds on every
    // push, with a child whose build is stable. Mirrors
    // the home-screen pattern: parent rebuilds (e.g. on
    // FutureBuilder snapshot), child reuses the same Do.
    final notifier = ValueNotifier<int>(0);
    addTearDown(notifier.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsService>.value(
        value: SettingsService.instance,
        child: localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: notifier,
              builder: (_, value, _) => ListView(
                children: [
                  for (var i = 0; i < 10; i++) _CounterTile(notifier: notifier),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Act
    final samples = <int>[];
    for (var i = 0; i < iterations; i++) {
      notifier.value = i + 1;
      final sw = Stopwatch()..start();
      await tester.pump();
      sw.stop();
      samples.add(sw.elapsedMicroseconds);
    }

    // Assert
    final med = _median(samples);
    expect(
      med,
      lessThanOrEqualTo(tenTileRebuildBudgetMicros),
      reason:
          '10-tile rebuild median $med µs exceeded '
          '$tenTileRebuildBudgetMicros µs over $iterations iterations',
    );
  });
}
