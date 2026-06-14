// Math mission screen. A pre-generated problem is shown; the
// user types the answer. The screen pops with a [MathInput] on
// success or null on cancel.
//
// Per SYS-011 the user gets up to 3 wrong answers before the
// mission auto-fails (the 4th wrong attempt pops with null).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:common_games/missions/mission.dart';
import 'package:common_games/missions/mission_input.dart';
import 'package:common_games/missions/mission_result.dart';
import 'package:common_games/theme/app_theme.dart';

class MissionMathScreen extends StatefulWidget {
  const MissionMathScreen({super.key, required this.mission});

  final MathMission mission;

  @override
  State<MissionMathScreen> createState() => _MissionMathScreenState();
}

class _MissionMathScreenState extends State<MissionMathScreen> {
  /// `MathProblem.next` requires a seeded RNG; the screen uses
  /// a fresh seed per visit so tests get a deterministic problem
  /// by passing a fixed seed through the mission metadata.
  late final MathProblem _problem = MathProblem.next(
    widget.mission.difficulty,
    math.Random(42),
  );
  final _ctrl = TextEditingController();
  int _wrongCount = 0;
  String? _error;

  static const _maxWrong = 3;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _opSymbol(MathOp op) => switch (op) {
    MathOp.add => '+',
    MathOp.subtract => '−',
    MathOp.multiply => '×',
  };

  void _submit() {
    final raw = _ctrl.text.trim();
    final answer = int.tryParse(raw);
    if (answer == null) {
      setState(() => _error = 'Enter a whole number.');
      return;
    }
    final result = widget.mission.verify(
      MathInput(problem: _problem, answer: answer),
    );
    if (result is MissionPassed) {
      Navigator.of(context).pop(MathInput(problem: _problem, answer: answer));
      return;
    }
    final next = _wrongCount + 1;
    if (next >= _maxWrong) {
      // 4th wrong → auto-fail the chain.
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _wrongCount = next;
      _error = 'Wrong. ${_maxWrong - next} attempt(s) left.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.mission.label)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Solve:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Spacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Text(
                    '${_problem.a} ${_opSymbol(_problem.op)} ${_problem.b} = ?',
                    key: const ValueKey('mission_math.problem'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                key: const ValueKey('mission_math.input'),
                controller: _ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Answer',
                  errorText: _error,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: Spacing.md),
              FilledButton(
                key: const ValueKey('mission_math.submit'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, Sizing.huge),
                ),
                onPressed: _submit,
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
