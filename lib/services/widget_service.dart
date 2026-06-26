// Home widget service — singleton-with-`_ready` that owns
// the home widget lifecycle (v1.4a / Phase 28 / SYS-115 /
// ADR-045 / WF-042).
//
// Responsibilities:
//   1. Compute the widget state from the active do +
//      completion log + current reliability on every
//      relevant change.
//   2. Persist the freshly-computed state to the Kotlin
//      `WidgetStateCache` (via the `doit/widget`
//      MethodChannel) so the cold-start fallback has the
//      last-known state.
//   3. Handle the "Done" tap from the widget: append the
//      completion via `CompletionLogService`, re-derive
//      the state, and ask the platform to repaint.
//
// Layer rules (per .claude/rules/lib-services.md):
//   - Singleton with `Completer<void> _ready`.
//   - `init()` is idempotent.
//   - All public methods are async; they return
//     `Future<T>` even for synchronous results.
//
// The service is the consumer side; the bridge is the
// platform side. `FakeWidgetBridge` is the test seam.
//
// v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042.

// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import 'package:doit/do/consecutive_counter.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/do/skip_budget.dart';
import 'package:doit/reminders/alarm_scheduler.dart' show Reliability;
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/reliability_service.dart';
import 'package:doit/widget/doit_widget_state.dart';
import 'package:doit/widget/widget_bridge.dart';
import 'package:doit/widget/widget_state_builder.dart';
import 'package:doit/widget/widget_state_cache.dart';
import 'package:doit/widget/widget_state_locator.dart';

class WidgetService {
  WidgetService._({
    required WidgetBridge bridge,
    required DoRepository doRepository,
    required CompletionLogService completionLog,
    required ReliabilityService reliabilityService,
    required WidgetStateCache cache,
  }) : _bridge = bridge,
       _doRepository = doRepository,
       _completionLog = completionLog,
       _reliabilityService = reliabilityService,
       _cache = cache;

  final WidgetBridge _bridge;
  final DoRepository _doRepository;
  final CompletionLogService _completionLog;
  final ReliabilityService _reliabilityService;
  final WidgetStateCache _cache;

  StreamSubscription<Reliability>? _reliabilitySub;
  bool _disposed = false;
  DoitWidgetState? _lastComputed;

  /// How the singleton is reached. `null` before [init] and
  /// after [resetForTesting].
  static WidgetService? _instance;

  /// Init gate. Public reads may `await ready` before
  /// calling [handleRefreshRequest] or [markDone].
  static Completer<void> _ready = Completer<void>();

  /// Initialize the singleton. Idempotent: the first call
  /// wins; subsequent calls resolve immediately. Wires the
  /// reliability-stream subscription so every
  /// `ReliabilityService` value change triggers a state
  /// re-derive.
  static Future<void> init({
    required WidgetBridge bridge,
    required DoRepository doRepository,
    required CompletionLogService completionLog,
    required ReliabilityService reliabilityService,
    WidgetStateCache? cache,
  }) async {
    if (_instance != null) {
      await _ready.future;
      return;
    }
    final service = WidgetService._(
      bridge: bridge,
      doRepository: doRepository,
      completionLog: completionLog,
      reliabilityService: reliabilityService,
      cache: cache ?? WidgetStateCache.instance,
    );
    _instance = service;
    // Subscribe to the reliability stream. Production
    // wires this to `ReliabilityService.instance.reliability`;
    // tests inject a fake stream via the test seam (the
    // `_FakeWidgetService` helper or direct subscription).
    final stream = reliabilityService.reliability;
    service._reliabilitySub = stream.listen(
      (_) => unawaited(service.handleRefreshRequest()),
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('WidgetService reliability listener: $e\n$st');
        }
      },
    );
    // Prime the cache + platform on init.
    unawaited(service.handleRefreshRequest());
    if (!_ready.isCompleted) _ready.complete();
  }

  /// The initialized service. Throws if [init] was not
  /// called.
  static WidgetService get instance {
    final s = _instance;
    if (s == null) {
      throw StateError('WidgetService.init() was not called.');
    }
    return s;
  }

  /// Future that completes after [init] has wired the
  /// singleton.
  static Future<void> get ready => _ready.future;

  /// Reset for tests. Cancels the listener and clears the
  /// singleton.
  static void resetForTesting() {
    final s = _instance;
    if (s != null) {
      s._dispose();
    }
    _instance = null;
    if (!_ready.isCompleted) {
      _ready = Completer<void>();
    }
  }

  /// The most-recently computed widget state, or `null` if
  /// [handleRefreshRequest] has not yet resolved. Useful
  /// for tests that want to assert against the singleton's
  /// internal snapshot.
  DoitWidgetState? get lastComputed => _lastComputed;

  /// Re-compute the widget state and persist it. Called
  /// from the reliability-stream listener, from
  /// [markDone] (after the completion write), and from
  /// any external trigger that wants to force a refresh.
  ///
  /// Best-effort: a platform-side failure (cache write or
  /// refresh request) is swallowed per ADR-013; the
  /// next legitimate event triggers a re-derive.
  Future<void> handleRefreshRequest() async {
    if (_disposed) return;
    try {
      final activeDo = await firstActiveDo(repository: _doRepository);
      final completions = activeDo == null
          ? const <CompletionLogEntry>[]
          : await _completionLogEntriesFor(activeDo);
      final reliability = _reliabilityService.value;
      final asOf = DateTime.now();
      final skipBudget = SkipBudget(
        doId: activeDo?.id ?? '',
        monthlyLimit: activeDo?.restDaysPerMonth ?? 0,
      );
      final state = buildWidgetState(
        activeDo: activeDo,
        completions: completions,
        reliability: reliability,
        asOf: asOf,
        skipBudget: skipBudget,
      );
      _lastComputed = state;
      await _cache.save(state);
      await _bridge.cacheSnapshot(state);
      await _bridge.requestRefresh();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('WidgetService.handleRefreshRequest: $e\n$st');
      }
    }
  }

  /// Append a completion for [habitId] via
  /// `CompletionLogService.append`, then re-derive the
  /// widget state. Called from the widget's "Done" button
  /// (via the Kotlin `WidgetChannel.markDone` arm).
  ///
  /// The `source` is [CompletionSource.manual] because the
  /// widget "Done" tap is conceptually identical to the
  /// home-tile "Done" tap — same audit trail, same
  /// `proofModeAtTime` snapshot.
  Future<void> markDone(String habitId) async {
    if (_disposed) return;
    final activeDo = await _doRepository.getById(habitId);
    if (activeDo == null) return;
    final asOf = DateTime.now();
    final day = DateTime(asOf.year, asOf.month, asOf.day);
    await _completionLog.append(
      habitId: habitId,
      day: day,
      source: CompletionSource.manual,
      proofModeAtTime: _proofModeTag(activeDo.proofMode),
    );
    await handleRefreshRequest();
  }

  /// Read the completion log for [activeDo] and convert each
  /// [CompletionRow] to a [CompletionLogEntry]. The
  /// [ConsecutiveCounter] algorithm expects local-day
  /// [DateTime] values; the conversion floors each
  /// `dayMillis` to its local midnight.
  Future<List<CompletionLogEntry>> _completionLogEntriesFor(Do activeDo) async {
    final rows = await _completionLog.listForHabit(activeDo.id);
    return rows
        .map(
          (row) => CompletionLogEntry(
            doId: activeDo.id,
            date: DateTime.fromMillisecondsSinceEpoch(row.dayMillis),
          ),
        )
        .toList(growable: false);
  }

  String _proofModeTag(DoProofMode m) {
    if (m is SoftProof) return 'soft';
    if (m is StrongProof) return 'strong';
    if (m is AutoProof) return 'auto';
    throw ArgumentError('Unknown proof mode: $m');
  }

  void _dispose() {
    _disposed = true;
    _reliabilitySub?.cancel();
    _reliabilitySub = null;
  }
}
