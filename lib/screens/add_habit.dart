// Add / Edit habit screen.
//
// Per WF-002 (add) and WF-022 (edit). One screen with two
// modes:
//   - Add: no `habitId` arg. The save creates a new habit and
//     schedules the next occurrence.
//   - Edit: `habitId` arg provided. The form pre-fills from
//     `DoRepository.getById`. Saving overwrites the row in
//     place. The habit's `createdAt` and completion log are
//     preserved (the repo's `insertOnConflictUpdate` does not
//     touch Completions).
//
// v0.2 surface (SYS-031, SYS-042..047, WF-019, WF-022, WF-031):
//   - All 5 schedule types: fixed, interval, anchor, dayOfX,
//     timeWindow.
//   - Category picker (DoCategory + 8-swatch colorSeed).
//   - Icon picker (64-icon grid).
//   - The same screen is used for edit; passing a `habitId`
//     flips it into "edit" mode.

import 'package:flutter/material.dart';

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/widgets/category_chip.dart';
import 'package:doit/widgets/icon_picker.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key, this.habitId});

  /// If non-null, the screen loads the habit with this id and
  /// runs in edit mode. Save will overwrite; createdAt is
  /// preserved.
  final String? habitId;

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _nameCtrl = TextEditingController();
  final _nameKey = GlobalKey();
  String? _nameError;

  // Schedule-type discriminator + per-type fields.
  String _scheduleType = 'fixed';
  TimeOfDay _fixedTime = const TimeOfDay(hour: 9, minute: 0);
  final Set<int> _fixedWeekdays = <int>{1, 2, 3, 4, 5};
  int _intervalNDays = 2;
  String? _anchorTargetId; // chosen from existing habits
  int _dayOfXDayOfMonth = 1;
  int _dayOfXNth = 1;
  int _dayOfXWeekday = 1;
  TimeOfDay _twStart = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _twEnd = const TimeOfDay(hour: 13, minute: 0);
  int? _twTargetHours; // null for meals, 12/14/16/18/20 for fasting

  // v0.2 visual identity (SYS-045, SYS-046).
  DoCategory _category = DoCategory.other;
  int _colorSeed = 0;
  String? _iconName;

  // v0.2 pause state (SYS-047). The edit form lets the user
  // pause / unpause without leaving the form.
  DateTime? _pausedUntil;

  // Cached list of all other habits, for the anchor picker.
  List<Do> _otherHabits = const <Do>[];

  // The original habit (in edit mode), so we can re-save
  // preserving `createdAt` and `id`.
  Do? _original;

  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.habitId != null;
    if (_isEdit) {
      _loadExisting();
    }
    // Add mode does NOT eagerly load the anchor-target list.
    // The list is loaded lazily when the user opens the
    // "After habit" picker (see _pickAnchorTarget). This keeps
    // the initial build synchronous and avoids a pending Drift
    // query in widget tests.
  }

  Future<void> _loadExisting() async {
    final id = widget.habitId;
    if (id == null) return;
    final h = await DoRepository.instance.getById(id);
    if (h == null || !mounted) return;
    setState(() {
      _original = h;
      _nameCtrl.text = h.name;
      _category = h.category;
      _colorSeed = h.colorSeed;
      _iconName = h.iconName;
      _pausedUntil = h.pausedUntil;
    });
    // Type-specific fields.
    final self = h;
    if (self is DoFixed) {
      _scheduleType = 'fixed';
      _fixedTime = TimeOfDay(hour: self.time.hour, minute: self.time.minute);
      _fixedWeekdays
        ..clear()
        ..addAll(self.weekdays);
    } else if (self is DoInterval) {
      _scheduleType = 'interval';
      _intervalNDays = self.nDays;
    } else if (self is DoAnchor) {
      _scheduleType = 'anchor';
      _anchorTargetId = self.targetDoId;
    } else if (self is DoDayOfX) {
      _scheduleType = 'dayOfX';
      _dayOfXDayOfMonth = self.dayOfMonth ?? 1;
      _dayOfXNth = self.nth ?? 1;
      _dayOfXWeekday = self.weekday ?? 1;
    } else if (self is DoTimeWindow) {
      _scheduleType = 'timeWindow';
      _twStart = TimeOfDay(hour: self.start.hour, minute: self.start.minute);
      _twEnd = TimeOfDay(hour: self.end.hour, minute: self.end.minute);
      _twTargetHours = self.targetHours;
    }
    // Edit mode: also load the other-habits list for the
    // anchor picker.
    await _loadOtherHabits();
  }

  Future<void> _loadOtherHabits() async {
    final all = await DoRepository.instance.listAll();
    if (!mounted) return;
    setState(() {
      _otherHabits = all
          .where((h) => h.id != widget.habitId)
          .toList(growable: false);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit do' : 'New do'),
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
            // --- v0.2 visual identity row.
            Row(
              children: [
                Expanded(
                  child: CategoryChip(
                    category: _category,
                    colorSeed: _colorSeed,
                    onTap: _pickCategory,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                _IconThumb(
                  category: _category,
                  iconName: _iconName,
                  onTap: _pickIcon,
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Text(
                'Schedule',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            // --- Schedule-type picker.
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fixed', label: Text('Fixed')),
                ButtonSegment(value: 'interval', label: Text('Every N')),
                ButtonSegment(value: 'anchor', label: Text('After')),
                ButtonSegment(value: 'dayOfX', label: Text('Day-of-X')),
                ButtonSegment(value: 'timeWindow', label: Text('Window')),
              ],
              selected: <String>{_scheduleType},
              onSelectionChanged: (s) =>
                  setState(() => _scheduleType = s.first),
            ),
            const SizedBox(height: Spacing.md),
            _buildScheduleFields(),
            if (_isEdit) ...[
              const SizedBox(height: Spacing.lg),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                child: Text(
                  'Pause',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _PauseRow(
                pausedUntil: _pausedUntil,
                onPick: _pickPauseUntil,
                onClear: () => setState(() => _pausedUntil = null),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleFields() {
    switch (_scheduleType) {
      case 'fixed':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Time'),
              trailing: Text(_fixedTime.format(context)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _fixedTime,
                );
                if (picked != null) setState(() => _fixedTime = picked);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Text(
                'Days',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(_weekdayLabel(d)),
                    selected: _fixedWeekdays.contains(d),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _fixedWeekdays.add(d);
                        } else {
                          _fixedWeekdays.remove(d);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
        );
      case 'interval':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Every N days'),
              trailing: Text('$_intervalNDays'),
              onTap: _pickInterval,
            ),
          ],
        );
      case 'anchor':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('After do'),
              subtitle: Text(
                _anchorTargetId == null
                    ? '(none)'
                    : (_otherHabits
                              .where((h) => h.id == _anchorTargetId)
                              .map((h) => h.name)
                              .firstOrNull ??
                          '(none)'),
              ),
              onTap: _pickAnchorTarget,
            ),
          ],
        );
      case 'dayOfX':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Day of month'),
              trailing: Text('$_dayOfXDayOfMonth'),
              onTap: _pickDayOfMonth,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Or nth weekday of the month',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Nth'),
                    trailing: Text(_nthLabel(_dayOfXNth)),
                    onTap: _pickNth,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Weekday'),
                    trailing: Text(_weekdayLabel(_dayOfXWeekday)),
                    onTap: _pickDayOfXWeekday,
                  ),
                ),
              ],
            ),
          ],
        );
      case 'timeWindow':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start'),
              trailing: Text(_twStart.format(context)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _twStart,
                );
                if (picked != null) setState(() => _twStart = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End'),
              trailing: Text(_twEnd.format(context)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _twEnd,
                );
                if (picked != null) setState(() => _twEnd = picked);
              },
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Target hours (for fasting)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (final h in const [12, 14, 16, 18, 20])
                  ChoiceChip(
                    label: Text('$h h'),
                    selected: _twTargetHours == h,
                    onSelected: (v) => setState(() {
                      _twTargetHours = v ? h : null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Text(
                'Active days',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(_weekdayLabel(d)),
                    selected: _fixedWeekdays.contains(d),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _fixedWeekdays.add(d);
                        } else {
                          _fixedWeekdays.remove(d);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // --- pickers ----------------------------------------------------

  Future<void> _pickCategory() async {
    final picked = await CategoryPickerSheet.show(
      context,
      initialCategory: _category,
      initialColorSeed: _colorSeed,
    );
    if (picked != null) {
      setState(() {
        _category = picked.category;
        _colorSeed = picked.colorSeed;
      });
    }
  }

  Future<void> _pickIcon() async {
    final picked = await IconPickerSheet.show(
      context,
      initialIconName: _iconName,
      category: _category,
    );
    if (picked != null) {
      setState(() => _iconName = picked);
    } else if (picked == null && _iconName != null) {
      // User dismissed — keep the existing icon.
    }
  }

  Future<void> _pickInterval() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) {
        var n = _intervalNDays;
        return AlertDialog(
          title: const Text('Days between'),
          content: StatefulBuilder(
            builder: (ctx, setLocal) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Decrement',
                  onPressed: () => setLocal(() => n = (n - 1).clamp(1, 365)),
                  icon: const Icon(Icons.remove),
                ),
                Text('$n', style: Theme.of(ctx).textTheme.titleLarge),
                IconButton(
                  tooltip: 'Increment',
                  onPressed: () => setLocal(() => n = (n + 1).clamp(1, 365)),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(n),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    if (picked != null) setState(() => _intervalNDays = picked);
  }

  Future<void> _pickAnchorTarget() async {
    // Lazy-load the other-habits list the first time the user
    // opens the anchor picker. This keeps the form's initState
    // synchronous (no pending Drift query in widget tests).
    if (_otherHabits.isEmpty) {
      await _loadOtherHabits();
    }
    if (!mounted) return;
    if (_otherHabits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other dos to anchor on.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final h in _otherHabits)
              ListTile(
                title: Text(h.name),
                onTap: () => Navigator.of(ctx).pop(h.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _anchorTargetId = picked);
  }

  Future<void> _pickDayOfMonth() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) {
        var d = _dayOfXDayOfMonth;
        return AlertDialog(
          title: const Text('Day of month'),
          content: StatefulBuilder(
            builder: (ctx, setLocal) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Decrement',
                  onPressed: () => setLocal(() => d = (d - 1).clamp(1, 31)),
                  icon: const Icon(Icons.remove),
                ),
                Text('$d', style: Theme.of(ctx).textTheme.titleLarge),
                IconButton(
                  tooltip: 'Increment',
                  onPressed: () => setLocal(() => d = (d + 1).clamp(1, 31)),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(d),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    if (picked != null) setState(() => _dayOfXDayOfMonth = picked);
  }

  Future<void> _pickNth() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) {
        var n = _dayOfXNth;
        return AlertDialog(
          title: const Text('Nth weekday'),
          content: StatefulBuilder(
            builder: (ctx, setLocal) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Decrement',
                  onPressed: () => setLocal(() => n = (n - 1).clamp(1, 5)),
                  icon: const Icon(Icons.remove),
                ),
                Text(_nthLabel(n), style: Theme.of(ctx).textTheme.titleLarge),
                IconButton(
                  tooltip: 'Increment',
                  onPressed: () => setLocal(() => n = (n + 1).clamp(1, 5)),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(n),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    if (picked != null) setState(() => _dayOfXNth = picked);
  }

  Future<void> _pickDayOfXWeekday() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var d = 1; d <= 7; d++)
              ListTile(
                title: Text(_weekdayLabel(d)),
                onTap: () => Navigator.of(ctx).pop(d),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _dayOfXWeekday = picked);
  }

  Future<void> _pickPauseUntil() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _pausedUntil ?? DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(
        () => _pausedUntil = picked.add(const Duration(hours: 23, minutes: 59)),
      );
    }
  }

  // --- save -------------------------------------------------------

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
      return;
    }
    setState(() => _nameError = null);

    Do habit;
    final now = DateTime.now();
    final id = _original?.id ?? 'h_${now.millisecondsSinceEpoch}';
    final createdAt = _original?.createdAt ?? now;
    const proofMode = SoftProof();
    try {
      switch (_scheduleType) {
        case 'fixed':
          if (_fixedWeekdays.isEmpty) {
            _showSnack('Pick at least one weekday.');
            return;
          }
          habit = DoFixed(
            id: id,
            name: name,
            proofMode: proofMode,
            createdAt: createdAt,
            restDaysPerMonth: 2,
            weekdays: Set<int>.from(_fixedWeekdays),
            time: DoTime(_fixedTime.hour, _fixedTime.minute),
            category: _category,
            colorSeed: _colorSeed,
            iconName: _iconName,
            pausedUntil: _pausedUntil,
          );
        case 'interval':
          habit = DoInterval(
            id: id,
            name: name,
            proofMode: proofMode,
            createdAt: createdAt,
            restDaysPerMonth: 2,
            nDays: _intervalNDays,
            referenceDate: now,
            category: _category,
            colorSeed: _colorSeed,
            iconName: _iconName,
            pausedUntil: _pausedUntil,
          );
        case 'anchor':
          if (_anchorTargetId == null) {
            _showSnack('Pick a do to anchor on.');
            return;
          }
          habit = DoAnchor(
            id: id,
            name: name,
            proofMode: proofMode,
            createdAt: createdAt,
            restDaysPerMonth: 2,
            targetDoId: _anchorTargetId!,
            lastAnchor: null,
            category: _category,
            colorSeed: _colorSeed,
            iconName: _iconName,
            pausedUntil: _pausedUntil,
          );
        case 'dayOfX':
          habit = DoDayOfX(
            id: id,
            name: name,
            proofMode: proofMode,
            createdAt: createdAt,
            restDaysPerMonth: 2,
            dayOfMonth: _dayOfXDayOfMonth,
            nth: _dayOfXNth,
            weekday: _dayOfXWeekday,
            referenceDayOfMonth: _dayOfXDayOfMonth,
            category: _category,
            colorSeed: _colorSeed,
            iconName: _iconName,
            pausedUntil: _pausedUntil,
          );
        case 'timeWindow':
          if (_fixedWeekdays.isEmpty) {
            _showSnack('Pick at least one active day.');
            return;
          }
          habit = DoTimeWindow(
            id: id,
            name: name,
            proofMode: proofMode,
            createdAt: createdAt,
            restDaysPerMonth: 2,
            weekdays: Set<int>.from(_fixedWeekdays),
            start: DoTime(_twStart.hour, _twStart.minute),
            end: DoTime(_twEnd.hour, _twEnd.minute),
            targetHours: _twTargetHours,
            category: _category,
            colorSeed: _colorSeed,
            iconName: _iconName,
            pausedUntil: _pausedUntil,
          );
        default:
          _showSnack('Pick a schedule type.');
          return;
      }
    } on DoValidationException catch (e) {
      setState(() => _nameError = e.message);
      return;
    }

    try {
      await DoRepository.instance.save(habit);
      if (!_isEdit) {
        // Schedule the first reminder only for new habits.
        // Edits re-schedule lazily on the next listActive cycle.
        final next = habit.nextOccurrence(now);
        if (next != null) {
          await ReminderService.instance.scheduleHabit(habit, next);
        }
      } else {
        // For edits, the scheduler reads the new row state on
        // the next tick. Fire a re-schedule here so the user
        // sees the change immediately.
        await ReminderService.instance.rescheduleAll();
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on DuplicateDoName catch (_) {
      setState(() => _nameError = 'A do with this name already exists.');
    } catch (e, st) {
      // ignore: avoid_print
      debugPrint('AddHabit save failed: $e\n$st');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- labels -----------------------------------------------------

  String _weekdayLabel(int d) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[d - 1];
  }

  String _nthLabel(int n) {
    switch (n) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      default:
        return '${n}th';
    }
  }
}

class _IconThumb extends StatelessWidget {
  const _IconThumb({
    required this.category,
    required this.iconName,
    required this.onTap,
  });

  final DoCategory category;
  final String? iconName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = CategoryChipResolver.resolveFor(
      category: category,
      colorSeed: 0,
    );
    return Semantics(
      button: true,
      label: 'Icon picker',
      child: Material(
        color: Color(visual.color).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              _iconFor(category, iconName),
              color: Color(visual.color),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(DoCategory c, String? name) {
    // The same lookup as IconPickerSheet uses; we keep a
    // small inline map so the thumb doesn't pull in the
    // full registry.
    final key = DoIcons.resolveFor(category: c, iconName: name);
    return _iconMap[key] ?? Icons.check;
  }

  static const Map<String, IconData> _iconMap = <String, IconData>{
    'local_drink': Icons.local_drink,
    'directions_run': Icons.directions_run,
    'fitness_center': Icons.fitness_center,
    'self_improvement': Icons.self_improvement,
    'bedtime': Icons.bedtime,
    'wb_sunny': Icons.wb_sunny,
    'restaurant': Icons.restaurant,
    'local_fire_department': Icons.local_fire_department,
    'spa': Icons.spa,
    'air': Icons.air,
    'menu_book': Icons.menu_book,
    'edit_note': Icons.edit_note,
    'psychology_alt': Icons.psychology_alt,
    'lightbulb': Icons.lightbulb,
    'auto_stories': Icons.auto_stories,
    'call': Icons.call,
    'chat': Icons.chat,
    'mail': Icons.mail,
    'group': Icons.group,
    'favorite': Icons.favorite,
    'pets': Icons.pets,
    'volunteer_activism': Icons.volunteer_activism,
    'diversity_3': Icons.diversity_3,
    'check_circle': Icons.check_circle,
    'task_alt': Icons.task_alt,
    'pending_actions': Icons.pending_actions,
    'event': Icons.event,
    'today': Icons.today,
    'schedule': Icons.schedule,
    'work': Icons.work,
    'school': Icons.school,
    'home': Icons.home,
    'cleaning_services': Icons.cleaning_services,
    'kitchen': Icons.kitchen,
    'local_laundry_service': Icons.local_laundry_service,
    'yard': Icons.yard,
    'shopping_cart': Icons.shopping_cart,
    'receipt_long': Icons.receipt_long,
    'savings': Icons.savings,
    'block': Icons.block,
    'do_not_disturb': Icons.do_not_disturb,
    'pause_circle': Icons.pause_circle,
    'repeat': Icons.repeat,
    'restore': Icons.restore,
    'undo': Icons.undo,
    'check': Icons.check,
    'restaurant_menu': Icons.restaurant_menu,
    'lunch_dining': Icons.lunch_dining,
    'local_pizza': Icons.local_pizza,
    'cake': Icons.cake,
    'coffee': Icons.coffee,
    'liquor': Icons.liquor,
    'set_meal': Icons.set_meal,
    'directions_walk': Icons.directions_walk,
    'directions_bike': Icons.directions_bike,
    'pool': Icons.pool,
    'sports_gymnastics': Icons.sports_gymnastics,
    'sports_tennis': Icons.sports_tennis,
    'sports_basketball': Icons.sports_basketball,
    'sports_soccer': Icons.sports_soccer,
    'hiking': Icons.hiking,
  };
}

class _PauseRow extends StatelessWidget {
  const _PauseRow({
    required this.pausedUntil,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? pausedUntil;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final paused = pausedUntil;
    return Row(
      children: [
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Paused until'),
            subtitle: Text(
              paused == null
                  ? '(not paused)'
                  : '${paused.year}-${paused.month.toString().padLeft(2, '0')}-${paused.day.toString().padLeft(2, '0')}',
            ),
            onTap: onPick,
          ),
        ),
        if (paused != null)
          TextButton(onPressed: onClear, child: const Text('Resume')),
      ],
    );
  }
}
