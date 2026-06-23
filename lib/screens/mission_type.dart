// Type-phrase mission screen. The user must type the expected
// phrase exactly (case-insensitive, whitespace-trimmed,
// punctuation-stripped — see [TypeMission._normalize]). The
// screen pops with a [TextInput] on success or null on cancel.
//
// Per WF-030 (uniform 3-wrong take-a-break), the user gets
// up to 3 wrong attempts before the mission auto-fails;
// the 3rd wrong attempt also surfaces a one-shot "take a
// break" `SnackBar` (matching the Math mission).

import 'package:flutter/material.dart';

import 'package:doit/missions/mission.dart';
import 'package:doit/missions/mission_attempts.dart';
import 'package:doit/missions/mission_input.dart';
import 'package:doit/missions/mission_result.dart';
import 'package:doit/theme/app_theme.dart';

class MissionTypeScreen extends StatefulWidget {
  const MissionTypeScreen({super.key, required this.mission});

  final TypeMission mission;

  @override
  State<MissionTypeScreen> createState() => _MissionTypeScreenState();
}

class _MissionTypeScreenState extends State<MissionTypeScreen> {
  final _ctrl = TextEditingController();
  final _attempts = MissionWrongAttempts();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final result = widget.mission.verify(TextInput(_ctrl.text));
    if (result is MissionPassed) {
      Navigator.of(context).pop(TextInput(_ctrl.text));
      return;
    }
    final shouldAutoFail = _attempts.recordWrong();
    if (shouldAutoFail) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _error = _attempts.errorLabel());
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
              Text(
                'Type this phrase exactly:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Spacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Text(
                    widget.mission.expectedPhrase,
                    key: const ValueKey('mission_type.expected'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                key: const ValueKey('mission_type.input'),
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Type the phrase',
                  errorText: _error,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: Spacing.md),
              FilledButton(
                key: const ValueKey('mission_type.submit'),
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
