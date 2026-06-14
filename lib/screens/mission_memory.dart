// Memory mission screen. A grid of face-down cards; the user
// flips two at a time and tries to match pairs. Uses
// [MemoryGame.generate] with a fixed seed for deterministic
// widget tests.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:common_games/missions/mission.dart';
import 'package:common_games/missions/mission_input.dart';
import 'package:common_games/theme/app_theme.dart';

class MissionMemoryScreen extends StatefulWidget {
  const MissionMemoryScreen({super.key, required this.mission, int? seed})
    : _seed = seed ?? 42;

  final MemoryMission mission;
  final int _seed;

  @override
  State<MissionMemoryScreen> createState() => _MissionMemoryScreenState();
}

class _MissionMemoryScreenState extends State<MissionMemoryScreen> {
  late final List<MemoryCard> _deck = MemoryGame.generate(
    rows: widget.mission.rows,
    cols: widget.mission.cols,
    theme: widget.mission.theme,
    seed: widget._seed,
  );
  final List<int> _flipped = <int>[];
  final List<MemoryPair> _matched = <MemoryPair>[];
  final List<MemoryPair> _pairBuffer = <MemoryPair>[];
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timeoutTimer;
  bool _popping = false;

  int get _totalPairs => (widget.mission.rows * widget.mission.cols) ~/ 2;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _timeoutTimer = Timer(widget.mission.timeLimit, _timeout);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _onTap(int index) {
    if (_popping) return;
    if (_matched.any((p) => p.a == index || p.b == index)) return;
    if (_flipped.contains(index)) return;
    if (_pairBuffer.isNotEmpty &&
        (_pairBuffer.last.a == index || _pairBuffer.last.b == index)) {
      // Same card; ignore.
      return;
    }
    setState(() {
      _flipped.add(index);
      if (_flipped.length % 2 == 0) {
        // Two cards flipped — check for a match.
        final a = _flipped[_flipped.length - 2];
        final b = _flipped[_flipped.length - 1];
        if (_deck[a].pairId == _deck[b].pairId) {
          _matched.add(MemoryPair(a, b));
          _pairBuffer.add(MemoryPair(a, b));
        }
      }
      if (_matched.length >= _totalPairs) {
        _finish();
      }
    });
  }

  void _finish() {
    if (_popping) return;
    _popping = true;
    _stopwatch.stop();
    Navigator.of(context).pop(
      MemoryInput(
        matchedPairs: List<MemoryPair>.unmodifiable(_matched),
        elapsed: _stopwatch.elapsed,
      ),
    );
  }

  void _timeout() {
    if (_popping) return;
    _popping = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mission.label),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            child: Center(
              child: Semantics(
                label:
                    'Memory game, ${_matched.length} of $_totalPairs pairs matched',
                child: Text(
                  '${_matched.length} / $_totalPairs',
                  key: const ValueKey('mission_memory.score'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.mission.cols,
              mainAxisSpacing: Spacing.sm,
              crossAxisSpacing: Spacing.sm,
              childAspectRatio: 1.4,
            ),
            itemCount: _deck.length,
            itemBuilder: (context, index) {
              final revealed =
                  _flipped.contains(index) ||
                  _matched.any((p) => p.a == index || p.b == index);
              return Card(
                key: ValueKey('mission_memory.card.$index'),
                color: revealed
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: InkWell(
                  onTap: () => _onTap(index),
                  child: Center(
                    child: Text(
                      revealed ? _deck[index].symbol : '?',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
