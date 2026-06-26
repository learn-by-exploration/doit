// Integration test for the Kotlin → Dart round-trip on
// the `doit/widget` MethodChannel (v1.4g / Phase 34 /
// SYS-121 / ADR-051 / WF-048).
//
// This test verifies the production wiring end-to-end:
//   1. `WidgetActionInvoker.attach()` registers the
//      inbound handler.
//   2. The handler routes the inbound `MethodCall` to
//      `WidgetService.instance.markDone` / `.skip` /
//      `.undo`.
//   3. The service writes to the completion log via
//      `CompletionLogService.append` / `.deleteById`.
//   4. The dispatcher returns the service's `bool` result.
//
// We exercise the dispatch path through the public
// `widgetActionDispatch` function — the exact same
// function the production channel handler invokes. Driving
// it through a `MethodChannel` directly is brittle in
// Flutter's test environment (the test binary messenger
// doesn't always route through the real channel handler
// registration), so we test the integration at the
// dispatcher seam instead. The unit tests in
// `widget_action_invoker_test.dart` cover the channel
// handler's argument-parsing + lifecycle; this file
// covers the dispatcher → service → completion-log path.

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/reminders/alarm_scheduler.dart' show Reliability;
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/db/schema.dart' show CompletionRow;
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/reliability_service.dart';
import 'package:doit/services/widget_service.dart';
import 'package:doit/widget/widget_action_invoker.dart';
import 'package:doit/widget/widget_bridge.dart';
import 'package:doit/widget/widget_state_cache.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Do _fixed(String id, String name) => DoFixed(
  id: id,
  name: name,
  proofMode: const SoftProof(),
  createdAt: DateTime(2026, 5, 17),
  restDaysPerMonth: 3,
  weekdays: const <int>{1, 2, 3, 4, 5, 6, 7},
  time: const DoTime(9, 0),
);

class _FakeDoRepo implements DoRepository {
  final List<Do> dos;
  _FakeDoRepo(this.dos);

  @override
  Future<List<Do>> listAll() async => dos;

  @override
  Future<Do?> getById(String id) async {
    for (final d in dos) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Future<void> save(Do d) async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<List<Do>> listActive(DateTime now) async => dos;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCompletionLog implements CompletionLogService {
  final List<String> appendedHabitIds = <String>[];
  final List<CompletionSource> appendedSources = <CompletionSource>[];
  final List<CompletionRow> rows = <CompletionRow>[];

  @override
  Future<String> append({
    required String habitId,
    required DateTime day,
    required CompletionSource source,
    required String proofModeAtTime,
    String? note,
    String? missionResultsJson,
  }) async {
    appendedHabitIds.add(habitId);
    appendedSources.add(source);
    final id = 'fake-${rows.length + 1}';
    rows.add(
      CompletionRow(
        id: id,
        habitId: habitId,
        dayMillis: day.millisecondsSinceEpoch,
        completedAtMillis: day.millisecondsSinceEpoch,
        source: source == CompletionSource.restDay ? 'rest_day' : 'manual',
        proofModeAtTime: proofModeAtTime,
        note: note,
        missionResultsJson: missionResultsJson,
      ),
    );
    return id;
  }

  @override
  Future<List<CompletionRow>> listForHabit(String habitId) async =>
      rows.where((r) => r.habitId == habitId).toList(growable: false);

  @override
  Future<List<CompletionRow>> listRestDaysInMonth(
    String habitId, {
    required int year,
    required int month,
  }) async => const <CompletionRow>[];

  @override
  Future<void> deleteById(String id) async {
    rows.removeWhere((r) => r.id == id);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReliabilityService implements ReliabilityService {
  @override
  Reliability get value => Reliability.optimal;

  @override
  Stream<Reliability> get reliability => const Stream<Reliability>.empty();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    WidgetStateCache.instance.resetForTesting();
    WidgetService.resetForTesting();
    WidgetActionInvoker.resetForTesting();
  });

  test('Inbound markDone round-trips to completion log via the '
      'production dispatcher (v1.4g / SYS-121)', () async {
    final bridge = FakeWidgetBridge();
    final repo = _FakeDoRepo(<Do>[_fixed('h1', 'Read')]);
    final log = _FakeCompletionLog();
    final rel = _FakeReliabilityService();
    await WidgetService.init(
      bridge: bridge,
      doRepository: repo,
      completionLog: log,
      reliabilityService: rel,
    );
    await WidgetService.ready;
    await WidgetActionInvoker.ready;

    // Simulate the Kotlin-side widget tap landing on the
    // Dart-side channel handler.
    final result = await widgetActionDispatch(
      const MethodCall('markDone', {'habitId': 'h1'}),
    );
    expect(result, isTrue);
    expect(log.appendedHabitIds, ['h1']);
    expect(log.appendedSources.last, CompletionSource.manual);
    expect(bridge.refreshCount, greaterThan(0));
  });

  test('Inbound skip round-trips to a rest-day completion log row '
      '(v1.4g / SYS-121)', () async {
    final bridge = FakeWidgetBridge();
    final repo = _FakeDoRepo(<Do>[_fixed('h1', 'Read')]);
    final log = _FakeCompletionLog();
    final rel = _FakeReliabilityService();
    await WidgetService.init(
      bridge: bridge,
      doRepository: repo,
      completionLog: log,
      reliabilityService: rel,
    );
    await WidgetService.ready;
    await WidgetActionInvoker.ready;

    final result = await widgetActionDispatch(
      const MethodCall('skip', {'habitId': 'h1'}),
    );
    expect(result, isTrue);
    expect(log.appendedSources.last, CompletionSource.restDay);
  });

  test('Inbound undo deletes today\'s completion row '
      '(v1.4g / SYS-121)', () async {
    final bridge = FakeWidgetBridge();
    final repo = _FakeDoRepo(<Do>[_fixed('h1', 'Read')]);
    final log = _FakeCompletionLog();
    final rel = _FakeReliabilityService();
    await WidgetService.init(
      bridge: bridge,
      doRepository: repo,
      completionLog: log,
      reliabilityService: rel,
    );
    await WidgetService.ready;
    await WidgetActionInvoker.ready;
    // Seed a row for today so undo has something to delete.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await log.append(
      habitId: 'h1',
      day: today,
      source: CompletionSource.manual,
      proofModeAtTime: 'soft',
    );

    final result = await widgetActionDispatch(
      const MethodCall('undo', {'habitId': 'h1'}),
    );
    expect(result, isTrue);
    expect(log.rows, isEmpty);
  });

  test('Inbound markDone returns false when the habit does not exist '
      '(v1.4g / SYS-121)', () async {
    final bridge = FakeWidgetBridge();
    final repo = _FakeDoRepo(<Do>[_fixed('h1', 'Read')]);
    final log = _FakeCompletionLog();
    final rel = _FakeReliabilityService();
    await WidgetService.init(
      bridge: bridge,
      doRepository: repo,
      completionLog: log,
      reliabilityService: rel,
    );
    await WidgetService.ready;
    await WidgetActionInvoker.ready;

    final result = await widgetActionDispatch(
      const MethodCall('markDone', {'habitId': 'nope'}),
    );
    expect(result, isFalse);
    expect(log.appendedHabitIds, isEmpty);
  });
}
