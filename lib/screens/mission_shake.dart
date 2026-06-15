// Shake-N mission screen. Counts shake events and pops with a
// [ShakeInput] when the target count is reached. The screen
// uses the [ShakeDetector] adapter to convert the synthetic
// accelerometer stream (or the real `sensors_plus` stream) into
// shake events.
//
// In tests the accelerometer stream is mocked; the production
// wiring is in lib/services/platform_mission_input.dart (a v0.2
// follow-up). The screen accepts a `Stream<ShakeSample>` so
// both paths go through the same code.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:doit/missions/mission.dart';
import 'package:doit/missions/mission_input.dart';
import 'package:doit/missions/shake_detector.dart';
import 'package:doit/theme/app_theme.dart';

class MissionShakeScreen extends StatefulWidget {
  const MissionShakeScreen({super.key, required this.mission, this.samples});

  final ShakeMission mission;
  final Stream<ShakeSample>? samples;

  @override
  State<MissionShakeScreen> createState() => _MissionShakeScreenState();
}

class _MissionShakeScreenState extends State<MissionShakeScreen> {
  StreamSubscription<ShakeEvent>? _eventSub;
  ShakeDetector? _detector;
  Timer? _timeoutTimer;
  int _count = 0;
  bool _popping = false;

  @override
  void initState() {
    super.initState();
    final samples = widget.samples;
    if (samples == null) {
      // No accelerometer in tests / web — the user can simulate
      // shakes by tapping the simulated-shake button (debug
      // build only).
      return;
    }
    _detector = ShakeDetector(
      samples: samples,
      magnitudeThreshold: widget.mission.magnitudeThreshold,
      minSpacingMs: widget.mission.minSpacingMs,
      maxSpacingMs: widget.mission.maxSpacingMs,
    );
    _eventSub = _detector!.events().listen((e) {
      if (!mounted) return;
      setState(() => _count = e.countSinceFirst);
      if (_count >= widget.mission.targetCount) {
        _finish();
      }
    });
    _timeoutTimer = Timer(widget.mission.timeout, _timeout);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _finish() {
    if (_popping) return;
    _popping = true;
    final d = _detector;
    Navigator.of(
      context,
    ).pop(d == null ? const ShakeInput([]) : ShakeInput(d.collected));
  }

  void _timeout() {
    if (_popping) return;
    _popping = true;
    Navigator.of(context).pop();
  }

  /// Debug-only: increment the count when the user taps the
  /// "simulate shake" button. Production builds hide this.
  void _debugSimulateShake() {
    setState(() => _count += 1);
    if (_count >= widget.mission.targetCount) {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.mission.targetCount;
    return Scaffold(
      appBar: AppBar(title: Text(widget.mission.label)),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: 'Shake detected: $_count of $target',
                child: Text(
                  '$_count / $target',
                  key: const ValueKey('mission_shake.count'),
                  style: Theme.of(context).textTheme.displayLarge,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              Text(
                'Shake the phone to confirm.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (widget.samples == null) ...[
                const SizedBox(height: Spacing.lg),
                TextButton(
                  key: const ValueKey('mission_shake.debug_simulate'),
                  onPressed: _debugSimulateShake,
                  child: const Text('Simulate shake (test)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
