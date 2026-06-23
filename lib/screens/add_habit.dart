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

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:doit/do/do.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/routines/routine.dart';
import 'package:doit/routines/routine_executor.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/geofence_service.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/widgets/automation_reliability_dialog.dart';
import 'package:doit/services/template_repository.dart';
import 'package:doit/templates/template.dart';
import 'package:doit/templates/template_library.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:doit/widgets/category_chip.dart';
import 'package:doit/widgets/calendar_picker.dart';
import 'package:doit/widgets/icon_picker.dart';
import 'package:doit/widgets/location_picker.dart';
import 'package:doit/widgets/automation_reliability_badge.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key, this.habitId, this.initialPayload});

  /// If non-null, the screen loads the habit with this id and
  /// runs in edit mode. Save will overwrite; createdAt is
  /// preserved.
  final String? habitId;

  /// Optional pre-fill payload, mirroring the inner envelope
  /// key of a template (`{"scheduleType":...,"weekdays":...,
  /// "hour":..., ...}`). Used by the catalog screen when the
  /// user picks a template. Default `null` (blank form).
  ///
  /// The payload field set is the Phase B PR 1 contract; see
  /// `lib/templates/template_library.dart` for the schema.
  final Map<String, dynamic>? initialPayload;

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

  // v1.0 (Phase C, SYS-072). Non-default automation rules.
  // Empty list = the default ActionNotify (synthesized at
  // dispatch time). Stored on the row as
  // `Habits.automations_json`.
  List<Automation> _automations = const <Automation>[];

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
    } else {
      // Pre-fill from the optional initial payload (catalog
      // apply path). Edit mode wins — `initialPayload` is
      // ignored when editing an existing habit.
      final payload = widget.initialPayload;
      if (payload != null) _applyPayload(payload);
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
      _automations = h.automations;
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

  /// Apply a pre-fill payload to the form. Mirrors the inner
  /// envelope key of a do-template `payloadJson` (see
  /// `lib/templates/template_library.dart` for the schema).
  /// Unknown fields are ignored; missing fields keep their
  /// default. This is intentionally tolerant: a future
  /// schema bump adds new fields to the payload, and older
  /// clients simply ignore them.
  void _applyPayload(Map<String, dynamic> p) {
    _nameCtrl.text = (p['name'] as String?) ?? _nameCtrl.text;
    final cat = p['category'] as String?;
    if (cat != null) {
      try {
        _category = DoCategory.fromTag(cat);
      } on ArgumentError catch (e) {
        if (kDebugMode) {
          debugPrint('AddHabit.applyPayload: unknown category: $e');
        }
      }
    }
    if (p['iconName'] is String) {
      _iconName = p['iconName'] as String;
    }
    final scheduleType = p['scheduleType'] as String?;
    if (scheduleType != null) {
      _scheduleType = scheduleType;
    }
    final weekdays = p['weekdays'];
    if (weekdays is List) {
      _fixedWeekdays
        ..clear()
        ..addAll(weekdays.whereType<int>());
    }
    final hour = (p['hour'] as num?)?.toInt();
    final minute = (p['minute'] as num?)?.toInt();
    if (hour != null && minute != null) {
      _fixedTime = TimeOfDay(hour: hour, minute: minute);
      _twStart = _fixedTime;
    }
    final endHour = (p['endHour'] as num?)?.toInt();
    final endMinute = (p['endMinute'] as num?)?.toInt();
    if (endHour != null && endMinute != null) {
      _twEnd = TimeOfDay(hour: endHour, minute: endMinute);
    }
    final nDays = (p['nDays'] as num?)?.toInt();
    if (nDays != null && nDays > 0) {
      _intervalNDays = nDays;
    }
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
          if (_isEdit)
            PopupMenuButton<_HabitMenuAction>(
              key: const ValueKey('add_habit.menu'),
              tooltip: 'More',
              onSelected: (a) {
                if (a == _HabitMenuAction.saveAsTemplate) {
                  _saveAsTemplate();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem<_HabitMenuAction>(
                  key: ValueKey('add_habit.save_as_template'),
                  value: _HabitMenuAction.saveAsTemplate,
                  child: Text('Save as template'),
                ),
              ],
            ),
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
                'Routines',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            _RoutinesSection(
              automations: _automations,
              onAddLocation: _addLocationRoutine,
              onAddCalendar: _addCalendarRoutine,
              onRemove: (idx) => setState(
                () => _automations = List.of(_automations)..removeAt(idx),
              ),
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

  /// Cached most-recent successful Do from the last [_save].
  /// Used by [_saveAsTemplate] so the template reflects the
  /// same row that was persisted. Cleared in [dispose].
  Do? _lastSaved;

  /// Open the [LocationPicker] modal and append the result
  /// to [_automations]. The picker handles its own
  /// permission gate (SYS-076); we just consume the
  /// returned [Automation]. `null` returns are user cancels
  /// or denied permissions — silent no-op.
  Future<void> _addLocationRoutine() async {
    final auto = await LocationPicker.show(context);
    if (auto == null || !mounted) return;
    // Register the trigger's geofence with the platform
    // service so the matcher starts watching for it. We
    // only register geofence triggers here; non-location
    // triggers register at the executor (their seam is in
    // Phase D / E / F).
    final trigger = auto.trigger;
    if (trigger is TriggerLocation) {
      await GeofenceService.instance.register(trigger);
    }
    setState(() {
      _automations = List<Automation>.unmodifiable(<Automation>[
        ..._automations,
        auto,
      ]);
    });
  }

  /// Open the [CalendarPicker] modal and append the result
  /// to [_automations]. v1.0 / Phase E PR 2 / SYS-074.
  /// The picker gates on `PermissionKind.calendar` (the
  /// runtime `READ_CALENDAR` permission) and returns one of
  /// the four `TriggerCalendarEvent` leaves with a default
  /// `ActionNotify`.
  ///
  /// Calendar triggers are NOT registered with a
  /// per-trigger platform service the way location
  /// triggers are — `RoutineExecutor` subscribes to the
  /// single `CalendarService.events` stream once at init
  /// and matches each transition against the registered
  /// automation set (see `_registerRoutines`). So all this
  /// method needs to do is append to `_automations`; the
  /// save path does the executor-side registration.
  Future<void> _addCalendarRoutine() async {
    final auto = await CalendarPicker.show(context);
    if (auto == null || !mounted) return;
    setState(() {
      _automations = List<Automation>.unmodifiable(<Automation>[
        ..._automations,
        auto,
      ]);
    });
  }

  /// Re-register every location-triggered automation with
  /// the [GeofenceService]. Called after a successful save
  /// so the platform side knows which circles to watch.
  Future<void> _registerRoutines(String entityId) async {
    // Drop any prior registration for this entity so an
    // edit does not leave stale circles on the platform
    // side.
    RoutineExecutor.instance.unregister(entityId);
    for (final a in _automations) {
      final t = a.trigger;
      if (t is TriggerLocation) {
        await GeofenceService.instance.register(t);
      }
    }
    if (_automations.isNotEmpty) {
      RoutineExecutor.instance.register(entityId, _automations);
    }
  }

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
            automations: _automations,
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
            automations: _automations,
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
            automations: _automations,
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
            automations: _automations,
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
            automations: _automations,
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
      _lastSaved = habit;
      // v1.0 Phase C PR 2 (SYS-072): register the
      // routines' geofences with the platform service so
      // the executor can match transitions as soon as the
      // row is persisted.
      await _registerRoutines(habit.id);
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

  // --- save-as-template ------------------------------------------

  Future<void> _saveAsTemplate() async {
    final source = _lastSaved ?? _original;
    if (source == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Save the do first, then save as template.');
      return;
    }
    final templateName = await showDialog<String>(
      context: context,
      builder: (ctx) => _SaveAsTemplateDialog(defaultName: '$name template'),
    );
    if (templateName == null || templateName.trim().isEmpty) return;
    final inner = _doToMap(source);
    inner['name'] = templateName.trim();
    final payloadJson = jsonEncode({
      'k': TemplateLibrary.kTemplateFormatVersion,
      'do': inner,
    });
    try {
      await TemplateRepository.instance.save(
        Template(
          id: '',
          name: templateName.trim(),
          description: 'Saved from $name',
          iconName: source.iconName ?? 'check',
          entityType: TemplateEntityType.doEntity,
          payloadJson: payloadJson,
          isBuiltIn: false,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      _showSnack('Template saved');
    } on TemplateValidationException catch (e) {
      _showSnack('Template validation failed: ${e.message}');
    }
  }

  /// Convert a [Do] into the inner envelope map for a
  /// `payloadJson` (`{"k":1,"do":{...}}`). Mirrors the field
  /// set used by the curated library in
  /// `lib/templates/template_library.dart` (entries 1..15).
  /// Subclass-specific fields are flattened.
  Map<String, dynamic> _doToMap(Do d) {
    final weekdays = <int>[];
    int hour = 0;
    int minute = 0;
    int endHour = 0;
    int endMinute = 0;
    int nDays = 0;
    const int intervalMinutes = 0;
    final String scheduleType;
    switch (d) {
      case DoFixed():
        scheduleType = 'fixed';
        weekdays.addAll(d.weekdays);
        hour = d.time.hour;
        minute = d.time.minute;
      case DoInterval():
        scheduleType = 'interval';
        weekdays.addAll(List<int>.generate(7, (i) => i + 1));
        nDays = d.nDays;
        hour = 9;
        minute = 0;
      case DoAnchor():
        scheduleType = 'anchor';
        weekdays.addAll(List<int>.generate(7, (i) => i + 1));
        hour = 7;
        minute = 0;
      case DoDayOfX():
        scheduleType = 'dayOfX';
        weekdays.addAll(List<int>.generate(7, (i) => i + 1));
        hour = 9;
        minute = 0;
      case DoTimeWindow():
        scheduleType = 'timeWindow';
        weekdays.addAll(d.weekdays);
        hour = d.start.hour;
        minute = d.start.minute;
        endHour = d.end.hour;
        endMinute = d.end.minute;
    }
    return <String, dynamic>{
      'scheduleType': scheduleType,
      'weekdays': weekdays,
      'hour': hour,
      'minute': minute,
      'endHour': endHour,
      'endMinute': endMinute,
      'nDays': nDays,
      'intervalMinutes': intervalMinutes,
      'proofMode': 'soft',
      'restDaysPerMonth': d.restDaysPerMonth,
      'category': d.category.tag,
      'iconName': d.iconName ?? 'check',
      'name': d.name,
    };
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

enum _HabitMenuAction { saveAsTemplate }

class _SaveAsTemplateDialog extends StatefulWidget {
  const _SaveAsTemplateDialog({required this.defaultName});

  final String defaultName;

  @override
  State<_SaveAsTemplateDialog> createState() => _SaveAsTemplateDialogState();
}

class _SaveAsTemplateDialogState extends State<_SaveAsTemplateDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.defaultName,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save as template'),
      content: TextField(
        key: const ValueKey('add_habit.save_as_template.name'),
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Template name'),
        textInputAction: TextInputAction.done,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('add_habit.save_as_template.save'),
          onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
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

/// "Routines" section of the Add / Edit habit form (SYS-072).
/// Renders one [ListTile] per registered automation with a
/// description of the trigger + action, plus an "Add a
/// location routine" button that opens [LocationPicker]
/// and an "Add a calendar routine" button that opens
/// [CalendarPicker] (v1.0 / Phase E PR 2 / SYS-074).
///
/// The widget is intentionally dumb — the parent state owns
/// the [List<Automation>] and rebuilds on mutation.
class _RoutinesSection extends StatelessWidget {
  const _RoutinesSection({
    required this.automations,
    required this.onAddLocation,
    required this.onAddCalendar,
    required this.onRemove,
  });

  final List<Automation> automations;
  final VoidCallback onAddLocation;
  final VoidCallback onAddCalendar;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (automations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Text(
              'No routines yet. Add one to fire this do when you '
              'arrive at or leave a place, or when a calendar '
              'event starts, ends, hits its reminder, or '
              'changes your busy status.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          for (var i = 0; i < automations.length; i++)
            _RoutineRow(
              automation: automations[i],
              onRemove: () => onRemove(i),
            ),
        const SizedBox(height: Spacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
            children: [
              TextButton.icon(
                key: const ValueKey('add_habit.add_location_routine'),
                onPressed: onAddLocation,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add a location routine'),
              ),
              TextButton.icon(
                key: const ValueKey('add_habit.add_calendar_routine'),
                onPressed: onAddCalendar,
                icon: const Icon(Icons.event_outlined),
                label: const Text('Add a calendar routine'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.automation, required this.onRemove});

  final Automation automation;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final trigger = automation.trigger;
    final action = automation.action;
    final summary = switch (trigger) {
      TriggerLocationEnter(:final label, :final radiusMeters) =>
        'On enter $label ($radiusMeters m)',
      TriggerLocationExit(:final label, :final radiusMeters) =>
        'On exit $label ($radiusMeters m)',
      _ => trigger.runtimeType.toString(),
    };
    final actionLabel = switch (action) {
      ActionNotify(:final title) => 'Notify "$title"',
      _ => action.runtimeType.toString(),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.bolt_outlined),
      title: Text(summary),
      subtitle: Text(actionLabel),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AutomationReliabilityBadge(
            automation: automation,
            onTap: () => showAutomationReliabilityDialog(
              context,
              automation: automation,
            ),
          ),
          IconButton(
            key: const ValueKey('add_habit.remove_routine'),
            tooltip: 'Remove',
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
