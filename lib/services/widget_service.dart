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
//   3. Handle widget taps: "Done" (v1.4a), "Skip today"
//      (v1.4f / SYS-120), and "Undo today" (v1.4f /
//      SYS-120). Each tap appends / deletes via
//      `CompletionLogService`, re-derives the state, and
//      asks the platform to repaint.
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
// v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047: added
// skip(habitId) + undo(habitId) to bring the widget to
// feature-parity with the in-app tile (mirrors v1.4c +
// v1.4d at the widget surface).
// v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052:
// handleRefreshRequest consults the cached
// `selectedHabitId` (v1.4f `restDaysPerMonth`
// precedent) and falls back to `firstActiveDo` when the
// selection is empty or the do no longer exists.
// `setSelectedHabitId(...)` is the entry point for the
// Kotlin `DoitWidgetConfigureActivity` to write a fresh
// selection.

// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import 'package:doit/do/consecutive_counter.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode_tag.dart';
import 'package:doit/do/skip_budget.dart';
import 'package:doit/reminders/alarm_scheduler.dart' show Reliability;
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/reliability_service.dart';
import 'package:doit/widget/doit_widget_state.dart';
import 'package:doit/widget/widget_action_invoker.dart';
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
    // v1.4g / SYS-121 / ADR-051 / WF-048: attach the inbound
    // `doit/widget` channel handler so the Kotlin side's
    // widget taps can invoke Dart's markDone / skip / undo.
    // attach() is idempotent — a second call (e.g., from a
    // test that re-runs init) is a no-op.
    await WidgetActionInvoker.attach();
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
  /// v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052:
  /// consults the cached `selectedHabitId` (the
  /// user-picked do for this widget instance) and falls
  /// back to [firstActiveDo] when the selection is empty
  /// (v1.4a behavior) or the do no longer exists (e.g.,
  /// the user deleted it while the widget was bound). On
  /// the fallback path the next cached state has
  /// `selectedHabitId = null` so a future re-bind starts
  /// fresh — the user is shown the empty-state copy
  /// (or `firstActiveDo` once they add a new do) without
  /// a stale selection hanging around in the JSON.
  ///
  /// Best-effort: a platform-side failure (cache write or
  /// refresh request) is swallowed per ADR-013; the
  /// next legitimate event triggers a re-derive.
  Future<void> handleRefreshRequest() async {
    if (_disposed) return;
    try {
      final activeDo = await _resolveActiveDo();
      final completions = activeDo == null
          ? const <CompletionLogEntry>[]
          : await _completionLogEntriesFor(activeDo);
      final reliability = _reliabilityService.value;
      final asOf = DateTime.now();
      final skipBudget = SkipBudget(
        doId: activeDo?.id ?? '',
        monthlyLimit: activeDo?.restDaysPerMonth ?? 0,
      );
      // v1.4k / SYS-125 / ADR-055 / WF-052. Reconciliation:
      // when `_resolveActiveDo` fell back to `firstActiveDo`
      // because the cached pick no longer maps to a do
      // (e.g., the user deleted the picked do while the
      // widget was bound), the pick must be cleared to
      // `null` for the next pass so a re-bind starts from
      // `firstActiveDo`. The clear is idempotent and runs
      // only on the rare stale-pick path.
      final cachedPick = _cache.cached?.selectedHabitId;
      final pickIsStale =
          cachedPick != null &&
          cachedPick.isNotEmpty &&
          activeDo != null &&
          activeDo.id != cachedPick;
      final pick = pickIsStale ? null : cachedPick;
      final state = buildWidgetState(
        activeDo: activeDo,
        completions: completions,
        reliability: reliability,
        asOf: asOf,
        skipBudget: skipBudget,
        selectedHabitId: pick,
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

  /// v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052. Pure
  /// resolve: the cached `selectedHabitId` is preferred
  /// over `firstActiveDo` when it is non-null AND
  /// `_doRepository.getById` returns non-null. Returns
  /// `null` for an empty selection OR for a selection
  /// that no longer maps to a do (the latter triggers
  /// the reconciliation clear in [handleRefreshRequest]).
  Future<Do?> _resolveActiveDo() async {
    final cached = _cache.cached;
    final pick = cached?.selectedHabitId;
    if (pick != null && pick.isNotEmpty) {
      final picked = await _doRepository.getById(pick);
      if (picked != null) return picked;
    }
    return firstActiveDo(repository: _doRepository);
  }

  /// v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052. Set
  /// the user-picked habit id for this widget instance.
  /// Called by the Kotlin `DoitWidgetConfigureActivity`
  /// via the `doit/widget` MethodChannel (or, in tests,
  /// directly). Writes a fresh [DoitWidgetState] to the
  /// cache so the next `WidgetRenderer.render` paints
  /// the picked do, and asks the platform to repaint.
  /// `null` clears the selection (reverts to
  /// `firstActiveDo` on the next refresh).
  ///
  /// Returns `true` on a clean write; `false` when the
  /// service is disposed.
  Future<bool> setSelectedHabitId(String? habitId) async {
    if (_disposed) return false;
    final activeDo = habitId == null || habitId.isEmpty
        ? await firstActiveDo(repository: _doRepository)
        : await _doRepository.getById(habitId);
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
      selectedHabitId: habitId,
    );
    _lastComputed = state;
    await _cache.save(state);
    await _bridge.cacheSnapshot(state);
    await _bridge.requestRefresh();
    return true;
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
  ///
  /// v1.4g / SYS-121 / ADR-051 / WF-048: returns `Future<bool>`
  /// (matching the v1.4f `skip` / `undo` contract) so the
  /// inbound channel handler can relay a success / failure
  /// outcome back to the Kotlin-side `WidgetChannel.invokeAction`
  /// caller. `true` on a successful append; `false` when the
  /// do does not exist (no append), when the service is
  /// disposed, or when the underlying write fails.
  Future<bool> markDone(String habitId) async {
    if (_disposed) return false;
    final activeDo = await _doRepository.getById(habitId);
    if (activeDo == null) return false;
    try {
      final asOf = DateTime.now();
      final day = DateTime(asOf.year, asOf.month, asOf.day);
      await _completionLog.append(
        habitId: habitId,
        day: day,
        source: CompletionSource.manual,
        proofModeAtTime: proofModeTag(activeDo.proofMode),
      );
    } catch (_) {
      return false;
    }
    await handleRefreshRequest();
    return true;
  }

  /// Append a rest-day completion for [habitId] via
  /// `CompletionLogService.append` (v1.4f / SYS-120 /
  /// ADR-050 / WF-047). Called from the widget's "Skip
  /// today" ImageButton via the Kotlin
  /// `WidgetChannel.skip` arm.
  ///
  /// Mirrors the in-app tile's `markDoSkipped` (v1.4c /
  /// SYS-117) at the widget surface — same source tag
  /// (`CompletionSource.restDay`), same
  /// `proofModeAtTime` snapshot, same rest-day budget
  /// check (`restDaysPerMonth > 0` and `used < limit`).
  ///
  /// Returns `true` if the rest-day row was appended,
  /// `false` if the do has no rest-day budget configured
  /// or the budget for the current month is exhausted.
  /// The widget shows no SnackBar surface (no
  /// `homeTileSkipBudgetExhausted` copy); the button is
  /// hidden on the widget surface when
  /// `restDaysPerMonth == 0` (see `WidgetRenderer` /
  /// `widget_medium.xml`), so the false return is purely
  /// defensive.
  Future<bool> skip(String habitId) async {
    if (_disposed) return false;
    final activeDo = await _doRepository.getById(habitId);
    if (activeDo == null) return false;
    if (activeDo.restDaysPerMonth <= 0) return false;
    final asOf = DateTime.now();
    final monthRestDays = await _completionLog.listRestDaysInMonth(
      activeDo.id,
      year: asOf.year,
      month: asOf.month,
    );
    if (monthRestDays.length >= activeDo.restDaysPerMonth) return false;
    final day = DateTime(asOf.year, asOf.month, asOf.day);
    await _completionLog.append(
      habitId: habitId,
      day: day,
      source: CompletionSource.restDay,
      proofModeAtTime: proofModeTag(activeDo.proofMode),
    );
    await handleRefreshRequest();
    return true;
  }

  /// Delete today's completion (or rest-day) row for
  /// [habitId] via `CompletionLogService.deleteById`
  /// (v1.4f / SYS-120 / ADR-050 / WF-047). Called from
  /// the widget's "Undo today" ImageButton via the Kotlin
  /// `WidgetChannel.undo` arm.
  ///
  /// Mirrors the in-app tile's `undoToday` (v1.4d /
  /// SYS-118) at the widget surface — same day-local-
  /// midnight filter (`dayMillis == midnight at now`), same
  /// first-match-wins tiebreak (matches `sparklineForDo` +
  /// `undoToday`), same single `deleteById` call on the
  /// happy path.
  ///
  /// Returns `true` if a row was deleted, `false` if no
  /// row matched today's local-midnight filter
  /// (`deleteById` was NOT called). The widget button is
  /// hidden when no completion row exists for today (the
  /// Dart-side state compute already returns
  /// `isCompletedToday == false`), so the false return is
  /// purely defensive against a concurrent rebuild
  /// racing the cached state read.
  Future<bool> undo(String habitId) async {
    if (_disposed) return false;
    final asOf = DateTime.now();
    final dayMillis = DateTime(
      asOf.year,
      asOf.month,
      asOf.day,
    ).millisecondsSinceEpoch;
    final rows = await _completionLog.listForHabit(habitId);
    for (final row in rows) {
      if (row.dayMillis == dayMillis) {
        await _completionLog.deleteById(row.id);
        await handleRefreshRequest();
        return true;
      }
    }
    return false;
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

  void _dispose() {
    _disposed = true;
    _reliabilitySub?.cancel();
    _reliabilitySub = null;
  }
}
