// Unit tests for WidgetService (v1.4a / Phase 28 / SYS-115 /
// ADR-045 / WF-042).
//
// Coverage:
//   - init is idempotent
//   - handleRefreshRequest computes + caches + persists state
//   - markDone appends the completion then re-derives
//   - markDone is a no-op when the habit does not exist
//   - reliability change triggers a re-derive
//   - MissingPluginException from the bridge does NOT crash
//     the service (ADR-013)
//
// Tests use hand-rolled fakes (no mockito codegen) per the
// project's convention (see ReminderBridge tests).

import 'dart:async';

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/reminders/alarm_scheduler.dart' show Reliability;
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/db/schema.dart' show CompletionRow;
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/reliability_service.dart';
import 'package:doit/services/widget_service.dart';
import 'package:doit/widget/doit_widget_state.dart';
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
  // v1.4f / Phase 33 / SYS-120: track deleted ids so
  // the undo tests can assert against the deleted row.
  final List<String> deletedIds = <String>[];

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
        source: _sourceTag(source),
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
  }) async {
    final first = DateTime(year, month).millisecondsSinceEpoch;
    final last = month == 12
        ? DateTime(year + 1).millisecondsSinceEpoch
        : DateTime(year, month + 1).millisecondsSinceEpoch;
    return rows
        .where(
          (r) =>
              r.habitId == habitId &&
              r.source == 'rest_day' &&
              r.dayMillis >= first &&
              r.dayMillis < last,
        )
        .toList(growable: false);
  }

  @override
  Future<void> deleteById(String id) async {
    deletedIds.add(id);
    rows.removeWhere((r) => r.id == id);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  static String _sourceTag(CompletionSource s) {
    switch (s) {
      case CompletionSource.manual:
        return 'manual';
      case CompletionSource.notification:
        return 'notification';
      case CompletionSource.mission:
        return 'mission';
      case CompletionSource.restDay:
        return 'rest_day';
    }
  }
}

class _FakeReliabilityService implements ReliabilityService {
  Reliability _value = Reliability.optimal;
  final StreamController<Reliability> _ctl =
      StreamController<Reliability>.broadcast();

  @override
  Reliability get value => _value;

  set value(Reliability v) {
    if (_value != v) {
      _value = v;
      _ctl.add(v);
    }
  }

  @override
  Stream<Reliability> get reliability => _ctl.stream.distinct();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    WidgetStateCache.instance.resetForTesting();
    WidgetService.resetForTesting();
  });

  test('init is idempotent', () async {
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
    final firstInstance = WidgetService.instance;
    await WidgetService.init(
      bridge: bridge,
      doRepository: repo,
      completionLog: log,
      reliabilityService: rel,
    );
    expect(WidgetService.instance, same(firstInstance));
  });

  test('handleRefreshRequest computes + caches + persists state', () async {
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
    await WidgetService.instance.handleRefreshRequest();

    expect(bridge.cachedSnapshots.length, greaterThanOrEqualTo(1));
    expect(bridge.refreshCount, greaterThanOrEqualTo(1));
    final state = WidgetService.instance.lastComputed;
    expect(state, isNotNull);
    expect(state!.habitId, 'h1');
    expect(state.habitName, 'Read');
    expect(state.streakNumber, 0);
  });

  test('markDone appends the completion then re-derives', () async {
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
    // Let the prime refresh finish first so we can isolate
    // the post-markDone snapshot count.
    await WidgetService.instance.handleRefreshRequest();
    final primeCount = bridge.cachedSnapshots.length;

    await WidgetService.instance.markDone('h1');
    expect(log.appendedHabitIds, ['h1']);
    expect(bridge.cachedSnapshots.length, greaterThan(primeCount));
    expect(WidgetService.instance.lastComputed!.isCompletedToday, isTrue);
  });

  test('markDone is a no-op when the habit does not exist', () async {
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
    await WidgetService.instance.markDone('nope');
    expect(log.appendedHabitIds, isEmpty);
  });

  test(
    'skip appends a rest_day completion then re-derives (v1.4f / SYS-120)',
    () async {
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
      await WidgetService.instance.handleRefreshRequest();
      final primeCount = bridge.cachedSnapshots.length;

      final ok = await WidgetService.instance.skip('h1');
      expect(ok, isTrue);
      expect(log.appendedSources.last, CompletionSource.restDay);
      expect(bridge.cachedSnapshots.length, greaterThan(primeCount));
    },
  );

  test('skip returns false when the do has restDaysPerMonth == 0 '
      '(v1.4f / SYS-120)', () async {
    final bridge = FakeWidgetBridge();
    final noRestDo = _fixed('h1', 'Read').copyWith(restDaysPerMonth: 0);
    final repo = _FakeDoRepo(<Do>[noRestDo]);
    final log = _FakeCompletionLog();
    final rel = _FakeReliabilityService();
    await WidgetService.init(
      bridge: bridge,
      doRepository: repo,
      completionLog: log,
      reliabilityService: rel,
    );
    await WidgetService.ready;
    final ok = await WidgetService.instance.skip('h1');
    expect(ok, isFalse);
    expect(log.appendedHabitIds, isEmpty);
  });

  test('skip returns false when the rest-day budget is exhausted for '
      'the current month (v1.4f / SYS-120)', () async {
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
    // Seed two rest-day rows in the current month
    // (limit is 3 in _fixed). After 2 consumes, 1 unit
    // is still available; the third consume should succeed.
    // For this test we want exhaustion, so seed 3 rows.
    final now = DateTime.now();
    for (var i = 0; i < 3; i++) {
      await log.append(
        habitId: 'h1',
        day: DateTime(now.year, now.month, i + 1),
        source: CompletionSource.restDay,
        proofModeAtTime: 'soft',
      );
    }
    final ok = await WidgetService.instance.skip('h1');
    expect(ok, isFalse);
    // The third seeded append means we've issued 3 log
    // writes; the failing skip should NOT add a 4th.
    expect(log.appendedHabitIds.length, 3);
  });

  test(
    'skip returns false when the habit does not exist (v1.4f / SYS-120)',
    () async {
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
      final ok = await WidgetService.instance.skip('nope');
      expect(ok, isFalse);
      expect(log.appendedHabitIds, isEmpty);
    },
  );

  test('undo deletes today\'s completion then re-derives '
      '(v1.4f / SYS-120)', () async {
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
    // Seed a row for today so undo has something to
    // delete.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final seededId = await log.append(
      habitId: 'h1',
      day: today,
      source: CompletionSource.manual,
      proofModeAtTime: 'soft',
    );
    await WidgetService.instance.handleRefreshRequest();
    final primeCount = bridge.cachedSnapshots.length;

    final ok = await WidgetService.instance.undo('h1');
    expect(ok, isTrue);
    expect(log.deletedIds, contains(seededId));
    expect(bridge.cachedSnapshots.length, greaterThan(primeCount));
  });

  test('undo returns false when there is no completion row for today '
      '(v1.4f / SYS-120)', () async {
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
    final ok = await WidgetService.instance.undo('h1');
    expect(ok, isFalse);
    expect(log.deletedIds, isEmpty);
  });

  test(
    'undo only matches today\'s day-local-midnight (v1.4f / SYS-120)',
    () async {
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
      // Seed a row for YESTERDAY only. The undo helper
      // filters by today's local-midnight; yesterday's row
      // must NOT be deleted.
      final now = DateTime.now();
      final yesterday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      final seededId = await log.append(
        habitId: 'h1',
        day: yesterday,
        source: CompletionSource.manual,
        proofModeAtTime: 'soft',
      );
      final ok = await WidgetService.instance.undo('h1');
      expect(ok, isFalse);
      expect(log.deletedIds, isNot(contains(seededId)));
      // The yesterday row is still in the log.
      expect(log.rows.where((r) => r.id == seededId), isNotEmpty);
    },
  );

  test('undo returns false when the habit does not exist '
      '(v1.4f / SYS-120)', () async {
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
    final ok = await WidgetService.instance.undo('nope');
    expect(ok, isFalse);
    expect(log.deletedIds, isEmpty);
  });

  test('reliability change triggers a re-derive', () async {
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
    await WidgetService.instance.handleRefreshRequest();
    final beforeCount = bridge.cachedSnapshots.length;
    rel.value = Reliability.degraded;
    // Allow the stream listener + re-derive to settle.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bridge.cachedSnapshots.length, greaterThan(beforeCount));
    expect(
      WidgetService.instance.lastComputed!.reliability,
      DoitWidgetReliability.degraded,
    );
  });

  test(
    'MissingPluginException from the bridge does NOT crash the service',
    () async {
      const channel = MethodChannel('doit/widget');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException('not implemented');
      });

      final bridge = PlatformWidgetBridge();
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
      // handleRefreshRequest must NOT throw even though
      // every MethodChannel call raises MissingPluginException.
      await WidgetService.instance.handleRefreshRequest();

      messenger.setMockMethodCallHandler(channel, null);
    },
  );
}
