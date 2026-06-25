// Mission launcher — the chain-level orchestrator for
// strong-mode habit mission launches.
//
// v1.3d / Phase 15 / SYS-114 / ADR-044. Lives in
// `lib/screens/` (NOT in `lib/missions/`) per
// `.claude/rules/lib-missions.md` — the model layer is pure
// Dart. The launcher is a widget that wires the
// `MissionChainExecutor` to the per-mission UI screens.
//
// Lifecycle:
//
//   1. `initState` resolves the habit by id via the
//      injected `habitLoader` (production:
//      `DoRepository.instance.getById`). If the habit is
//      missing OR not in `StrongProof` mode OR carries an
//      empty chain, the widget pops with `null` (the
//      streak stays untouched).
//   2. `_runChain` iterates the `MissionChain` in order.
//      For each `Mission`, `_runMission` pushes the
//      matching `MissionXxxScreen` and `await`s the pop
//      value. A `null` pop (cancel or timeout) aborts
//      the chain immediately and pops with `null`.
//   3. When the full chain has produced one input per
//      mission, `_onChainCompleted` runs
//      `MissionChainExecutor.run(chain, inputs)`. A
//      `ChainPassed` appends a completion via the
//      injected `completionAppender` (production:
//      `CompletionLogService.instance.append`) and pops
//      with `true`. Any `ChainFailedAt` / `ChainTimedOut`
//      pops with `null` (the streak breaks per the
//      v1.1f grace-window contract).
//
// Test seam:
//
//   The `habitLoader` and `completionAppender` are
//   injectable via the constructor. Production callers
//   (the route resolver in `lib/main.dart`) use the
//   defaults; widget tests inject mocks that return
//   hardcoded `Do` instances and record completion
//   appends.

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/missions/chain.dart';
import 'package:doit/missions/chain_executor.dart';
import 'package:doit/missions/mission_input.dart';
import 'package:doit/missions/mission_result.dart';
import 'package:doit/screens/mission_hold.dart';
import 'package:doit/screens/mission_math.dart';
import 'package:doit/screens/mission_memory.dart';
import 'package:doit/screens/mission_shake.dart';
import 'package:doit/screens/mission_type.dart';
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/do_repository.dart';

/// Default habit loader — reads from the local DB via the
/// Drift-backed `DoRepository` singleton. Exposed as a
/// `top-level function` (NOT a closure on the widget) so
/// widget tests can call it directly to verify the
/// production seam still works end-to-end.
Future<Do?> _defaultHabitLoader(String habitId) =>
    DoRepository.instance.getById(habitId);

/// Default completion appender — calls the
/// `CompletionLogService.instance.append` singleton with
/// `CompletionSource.mission` and the proof-mode tag
/// derived from the habit. The `day` argument is the
/// current local midnight; the service dedupes on
/// `(habitId, day)` so a double-launch of the same alarm
/// does not insert two rows.
Future<String> _defaultCompletionAppender({
  required String habitId,
  required DateTime day,
  required String proofModeAtTime,
  String? note,
  String? missionResultsJson,
}) => CompletionLogService.instance.append(
  habitId: habitId,
  day: day,
  source: CompletionSource.mission,
  proofModeAtTime: proofModeAtTime,
  note: note,
  missionResultsJson: missionResultsJson,
);

/// The chain-level mission orchestrator widget. Mounted by
/// `MaterialApp.onGenerateRoute` when the initial route is
/// `/mission?mode=habit&habitId=...` (set by the Kotlin
/// `FullScreenActivity.getInitialRoute`).
class MissionLauncherScreen extends StatefulWidget {
  const MissionLauncherScreen({
    super.key,
    required this.habitId,
    Future<Do?> Function(String habitId)? habitLoader,
    Future<String> Function({
      required String habitId,
      required DateTime day,
      required String proofModeAtTime,
      String? note,
      String? missionResultsJson,
    })?
    completionAppender,
    DateTime Function()? nowProvider,
  }) : _habitLoader = habitLoader ?? _defaultHabitLoader,
       _completionAppender = completionAppender ?? _defaultCompletionAppender,
       _nowProvider = nowProvider ?? DateTime.now;

  /// The habit id from the launch intent query string.
  final String habitId;

  final Future<Do?> Function(String) _habitLoader;
  final Future<String> Function({
    required String habitId,
    required DateTime day,
    required String proofModeAtTime,
    String? note,
    String? missionResultsJson,
  })
  _completionAppender;
  final DateTime Function() _nowProvider;

  @override
  State<MissionLauncherScreen> createState() => _MissionLauncherScreenState();
}

class _MissionLauncherScreenState extends State<MissionLauncherScreen> {
  bool _running = false;

  @override
  void initState() {
    super.initState();
    // Schedule the chain for the next frame so the widget
    // tree has a chance to mount before we start pushing
    // mission routes on top of it. `Navigator.push` from
    // `initState` is allowed but the route resolution
    // happens after the first frame; deferring avoids a
    // subtle race where the launcher's first build has
    // not yet finished when the mission screen pushes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runOrDismiss();
    });
  }

  Future<void> _runOrDismiss() async {
    if (_running) return;
    _running = true;
    final habit = await widget._habitLoader(widget.habitId);
    if (!mounted) return;
    if (habit == null) {
      _dismissWith(reason: 'habit-not-found', result: null);
      return;
    }
    final mode = habit.proofMode;
    if (mode is! StrongProof) {
      _dismissWith(reason: 'not-strong-proof', result: null);
      return;
    }
    final chain = mode.chain;
    if (chain.isEmpty) {
      _dismissWith(reason: 'empty-chain', result: null);
      return;
    }
    await _runChain(habit, chain);
  }

  Future<void> _runChain(Do habit, MissionChain chain) async {
    final inputs = <MissionInput>[];
    for (final mission in chain) {
      final input = await _runMission(mission);
      if (input == null) {
        // Cancel / timeout / dismiss for this mission
        // aborts the whole chain. The streak stays
        // broken (v1.1f grace-window semantics).
        _dismissWith(reason: 'mission-aborted', result: null);
        return;
      }
      inputs.add(input);
    }
    final result = const MissionChainExecutor().run(chain, inputs);
    await _onChainCompleted(habit, result, inputs);
  }

  Future<MissionInput?> _runMission(Mission m) {
    return switch (m) {
      ShakeMission() => Navigator.of(context).push<ShakeInput>(
        MaterialPageRoute(builder: (_) => MissionShakeScreen(mission: m)),
      ),
      TypeMission() => Navigator.of(context).push<TextInput>(
        MaterialPageRoute(builder: (_) => MissionTypeScreen(mission: m)),
      ),
      HoldMission() => Navigator.of(context).push<HoldInput>(
        MaterialPageRoute(builder: (_) => MissionHoldScreen(mission: m)),
      ),
      MathMission() => Navigator.of(context).push<MathInput>(
        MaterialPageRoute(builder: (_) => MissionMathScreen(mission: m)),
      ),
      MemoryMission() => Navigator.of(context).push<MemoryInput>(
        MaterialPageRoute(builder: (_) => MissionMemoryScreen(mission: m)),
      ),
    };
  }

  Future<void> _onChainCompleted(
    Do habit,
    MissionChainResult result,
    List<MissionInput> inputs,
  ) async {
    switch (result) {
      case ChainPassed():
        // v1.1f grace-window semantics: the
        // completion is appended on ChainPassed. A
        // daily-dedupe key prevents double-fire
        // appends if the alarm re-arms before the
        // scheduler clears it.
        final now = widget._nowProvider();
        final day = DateTime(now.year, now.month, now.day);
        try {
          await widget._completionAppender(
            habitId: habit.id,
            day: day,
            proofModeAtTime: _proofModeTag(habit.proofMode),
            missionResultsJson: _serializeResults(inputs),
          );
        } catch (e, st) {
          // The launcher's contract is to dismiss
          // regardless. A DB write failure leaves
          // the streak un-updated but does not
          // crash the launcher (the user can
          // re-tap the soft "Done" on the home
          // screen to backfill).
          if (kDebugMode) {
            debugPrint(
              'MissionLauncherScreen.completion append '
              'failed: $e\n$st',
            );
          }
        }
        _dismissWith(reason: 'chain-passed', result: true);
      case ChainFailedAt():
        // ChainFailedAt is the parent of
        // ChainTimedOut — both branches dismiss
        // with `null` (streak stays broken per
        // the v1.1f grace-window contract).
        _dismissWith(reason: 'chain-failed', result: null);
    }
  }

  void _dismissWith({required String reason, required bool? result}) {
    if (kDebugMode) {
      debugPrint('MissionLauncherScreen.dismiss: $reason');
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  String _proofModeTag(DoProofMode m) {
    if (m is StrongProof) return 'strong';
    if (m is SoftProof) return 'soft';
    if (m is AutoProof) return 'auto';
    return 'unknown';
  }

  String? _serializeResults(List<MissionInput> inputs) {
    // A short, human-readable summary string so the
    // completion log can surface "what did the user
    // do?" without exposing raw inputs. Per-mission
    // detail (e.g., the shake count, the typed
    // phrase) is intentionally NOT serialized —
    // mission verification is the source of truth
    // and a separate `MissionResult` row would be
    // needed for full provenance (a v1.4+ follow-up).
    return 'missions=${inputs.length}';
  }

  @override
  Widget build(BuildContext context) {
    // The launcher is a routing widget: it does not
    // render its own UI. The first frame is a blank
    // scaffold; `_runOrDismiss` schedules the chain
    // (or the dismiss) on the next frame. The
    // mission screens pushed on top of this scaffold
    // are the user-visible surface.
    return const Scaffold(body: SizedBox.shrink());
  }
}
