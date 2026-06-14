// Hold-tap mission screen. Press and hold the central button
// for the duration specified by the mission. The screen pops
// with a [HoldInput] (or null on cancel/timeout) so the caller
// can run the chain executor.
//
// Per SYS-009 the hold duration is 3-5 seconds; the per-mission
// `holdDuration` is the source of truth.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:common_games/missions/mission.dart';
import 'package:common_games/missions/mission_input.dart';
import 'package:common_games/theme/app_theme.dart';

class MissionHoldScreen extends StatefulWidget {
  const MissionHoldScreen({super.key, required this.mission});

  final HoldMission mission;

  @override
  State<MissionHoldScreen> createState() => _MissionHoldScreenState();
}

class _MissionHoldScreenState extends State<MissionHoldScreen> {
  Timer? _poll;
  Timer? _timeoutTimer;
  Duration _elapsed = Duration.zero;
  bool _popping = false;
  // Counts poll ticks; a tick is a fixed 50 ms wall-clock slot.
  // We track ticks rather than reading a Stopwatch so the screen
  // is testable under `tester.pump(duration)` (fake-async) — a
  // real `Stopwatch` returns real-time, not the fake clock.
  int _ticks = 0;
  static const _tickInterval = Duration(milliseconds: 50);

  @override
  void initState() {
    super.initState();
    // Cap the mission to the per-mission timeout as a wall-clock
    // safety net.
    _timeoutTimer = Timer(widget.mission.timeout, _timeout);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
    if (_popping) return;
    // If the screen is being torn down without a result, the
    // chain is aborted by the caller (null result).
  }

  void _onHoldStart() {
    if (_poll?.isActive ?? false) return;
    _ticks = 0;
    _poll = Timer.periodic(_tickInterval, (_) {
      if (!mounted) return;
      _ticks += 1;
      _elapsed = _tickInterval * _ticks;
      setState(() {});
      if (_elapsed >= widget.mission.holdDuration) {
        _poll?.cancel();
        _finish();
      }
    });
  }

  void _onHoldEnd() {
    _poll?.cancel();
    final dur = _elapsed;
    _ticks = 0;
    setState(() => _elapsed = Duration.zero);
    if (dur < widget.mission.holdDuration) {
      // Released too early. The screen stays; the user can
      // try again. We do not pop.
    }
  }

  void _finish() {
    if (_popping) return;
    _popping = true;
    Navigator.of(context).pop(HoldInput(_elapsed));
  }

  void _timeout() {
    if (_popping) return;
    _popping = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.mission.holdDuration;
    final progress = (_elapsed.inMilliseconds / target.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.mission.label)),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label:
                    'Hold to confirm, ${(_elapsed.inMilliseconds / 1000).toStringAsFixed(1)} of ${target.inSeconds} seconds',
                child: GestureDetector(
                  key: const ValueKey('mission_hold.press'),
                  onTapDown: (_) => _onHoldStart(),
                  onTapUp: (_) => _onHoldEnd(),
                  onTapCancel: _onHoldEnd,
                  child: SizedBox(
                    width: Sizing.huge * 3,
                    height: Sizing.huge * 3,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: Sizing.huge * 3,
                          height: Sizing.huge * 3,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 12,
                          ),
                        ),
                        Text(
                          '${(_elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              Text(
                'Hold for ${target.inSeconds} seconds',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
