// Add-habit screen — name → schedule type → parameters →
// proof mode → save. Per WF-002.
//
// v0.1 supports the Fixed schedule only. Interval, Anchor,
// and Day-of-X are the v0.2 line items. Strong-mode mission
// chain selection is a v0.2 follow-up (the v0.1 chain is a
// single Hold-tap for the rare case a user wants Strong).

import 'package:flutter/material.dart';

import 'package:common_games/habits/habit.dart';
import 'package:common_games/habits/proof_mode.dart';
import 'package:common_games/services/habit_repository.dart';
import 'package:common_games/services/reminder_service.dart';
import 'package:common_games/theme/app_theme.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _nameCtrl = TextEditingController();
  final _nameKey = GlobalKey();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  final Set<int> _weekdays = <int>{1, 2, 3, 4, 5};
  String? _nameError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New habit'),
        actions: [
          TextButton(
            key: const ValueKey('add_habit.save'),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            TextField(
              key: _nameKey,
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _nameError,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: Spacing.md),
            ListTile(
              title: const Text('Time'),
              trailing: Text(_time.format(context)),
              onTap: _pickTime,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Text(
                'Days',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(_weekdayLabel(d)),
                    selected: _weekdays.contains(d),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _weekdays.add(d);
                        } else {
                          _weekdays.remove(d);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _weekdayLabel(int d) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[d - 1];
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
      return;
    }
    if (_weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one weekday.')),
      );
      return;
    }
    final habit = HabitFixed(
      id: 'h_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      proofMode: const SoftProof(),
      createdAt: DateTime.now(),
      restDaysPerMonth: 2,
      weekdays: Set<int>.from(_weekdays),
      time: HabitTime(_time.hour, _time.minute),
    );
    try {
      await HabitRepository.instance.save(habit);
      // Schedule the next occurrence.
      final next = habit.nextOccurrence(DateTime.now());
      if (next != null) {
        await ReminderService.instance.scheduleHabit(habit, next);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on DuplicateHabitName catch (_) {
      setState(() => _nameError = 'A habit with this name already exists.');
    } on HabitValidationException catch (e) {
      setState(() => _nameError = e.message);
    } catch (e, st) {
      // ignore: avoid_print
      debugPrint('AddHabit save failed: $e\n$st');
    }
  }
}
