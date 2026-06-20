// Add / Edit event screen — one-off date-specific reminders.
//
// Per WF-017 (event create) and WF-019 (event edit). One screen
// with two modes:
//   - Add: no `existing` arg. Saves a new event and re-schedules
//     alarms.
//   - Edit: `existing` arg provided. Pre-fills from the row;
//     save overwrites in place; `createdAtMillis` is preserved.
//
// Phase B (PR 2) adds:
//   - `initialPayload` — pre-fill from a template's `payloadJson`
//     inner envelope (`{"recurrence":...,"leadTimeMillis":N, ...}`).
//     The field set matches the curated library entries
//     `t_builtin_22..25` in `lib/templates/template_library.dart`.
//   - AppBar "Save as template" action — captures the current
//     form state (NOT the persisted row) as a user-saved
//     template. Mirrors the same affordance on AddHabitScreen
//     and AddPersonScreen so the catalog's "Your templates" tab
//     is reachable from any entity-type form.
//
// Recurrence: the curated event library uses 'monthly' and 'yearly'
// tags; the runtime [EventRecurrence] enum is only
// `none | annually`. The pre-fill maps 'monthly' / 'yearly' to
// `annually` (the user can change it) — the dayOfMonth /
// monthOfYear fields are honored when present so a "Pay rent on
// the 1st" template lands on the 1st of the next month.

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:doit/events/event.dart';
import 'package:doit/services/event_repository.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/template_repository.dart';
import 'package:doit/templates/template.dart';
import 'package:doit/templates/template_library.dart';
import 'package:doit/theme/app_theme.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key, this.existing, this.initialPayload});

  /// If non-null, the screen pre-fills from this event and runs
  /// in edit mode. Save overwrites the row; `createdAtMillis`
  /// is preserved.
  final Event? existing;

  /// Optional pre-fill payload, mirroring the inner envelope key
  /// of an event template (`{"recurrence":...,"leadTimeMillis":
  /// N,"dayOfMonth":N,"monthOfYear":N,"name":"..."}`). Used by
  /// the catalog screen when the user picks an event template.
  /// Default `null` (blank form). Edit mode wins — `initialPayload`
  /// is ignored when editing an existing event.
  final Map<String, dynamic>? initialPayload;

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _nameCtrl = TextEditingController();
  DateTime _at = DateTime.now().add(const Duration(days: 1));
  int _leadMinutes = 15;
  EventRecurrence _recurrence = EventRecurrence.none;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _at = DateTime.fromMillisecondsSinceEpoch(e.atMillis);
      _leadMinutes = (e.leadTimeMillis / 60000).round();
      _recurrence = e.recurrence;
    } else {
      // Catalog apply path: pre-fill from the template payload.
      final payload = widget.initialPayload;
      if (payload != null) _applyPayload(payload);
    }
  }

  /// Pre-fill form state from a template's `payloadJson` inner
  /// envelope. The `name` field is honored; the recurrence
  /// string is mapped onto the [EventRecurrence] enum (with
  /// 'monthly' and 'yearly' both → `annually` — the day-of-month
  /// / month-of-year fields drive the date pick instead).
  void _applyPayload(Map<String, dynamic> payload) {
    final name = payload['name'];
    if (name is String && name.isNotEmpty) {
      _nameCtrl.text = name;
    }
    final lead = payload['leadTimeMillis'];
    if (lead is int) {
      _leadMinutes = (lead / 60000).round();
    }
    final rec = payload['recurrence'];
    if (rec is String) {
      switch (rec) {
        case 'annually':
        case 'yearly':
        case 'monthly':
          _recurrence = EventRecurrence.annually;
        case 'none':
        case _:
          _recurrence = EventRecurrence.none;
      }
    }
    final day = payload['dayOfMonth'];
    final month = payload['monthOfYear'];
    final now = DateTime.now();
    if (day is int && day > 0 && day <= 31) {
      final m = (month is int && month >= 1 && month <= 12) ? month : now.month;
      var candidate = DateTime(now.year, m, day, 9);
      if (!candidate.isAfter(now)) {
        // Roll forward a year if the date is in the past.
        candidate = DateTime(now.year + 1, m, day, 9);
      }
      _at = candidate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      initialDate: _at,
    );
    if (picked != null) {
      setState(() {
        _at = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _at.hour,
          _at.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _at.hour, minute: _at.minute),
    );
    if (picked != null) {
      setState(() {
        _at = DateTime(
          _at.year,
          _at.month,
          _at.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _pickLead() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) {
        var n = _leadMinutes;
        return AlertDialog(
          title: const Text('Notify me before'),
          content: StatefulBuilder(
            builder: (ctx, setLocal) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in const [0, 5, 15, 30, 60, 120, 1440])
                  RadioListTile<int>(
                    title: Text(_leadLabel(m)),
                    value: m,
                    groupValue: n,
                    onChanged: (v) {
                      if (v != null) setLocal(() => n = v);
                    },
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
    if (picked != null) setState(() => _leadMinutes = picked);
  }

  String _leadLabel(int m) {
    if (m == 0) return 'At the time';
    if (m < 60) return '$m min before';
    if (m < 1440) return '${m ~/ 60} h before';
    return '${m ~/ 1440} d before';
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
      return;
    }
    final id =
        widget.existing?.id ?? 'e_${DateTime.now().millisecondsSinceEpoch}';
    final createdAt =
        widget.existing?.createdAtMillis ??
        DateTime.now().millisecondsSinceEpoch;
    final event = Event(
      id: id,
      name: name,
      atMillis: _at.millisecondsSinceEpoch,
      leadTimeMillis: _leadMinutes * 60000,
      recurrence: _recurrence,
      createdAtMillis: createdAt,
    );
    try {
      event.validate();
    } on EventValidationException catch (e) {
      setState(() => _nameError = e.toString());
      return;
    }
    await EventRepository.instance.save(event);
    await ReminderService.instance.rescheduleAll();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  // --- save-as-template -------------------------------------------

  Future<void> _saveAsTemplate() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the event a name first.')),
      );
      return;
    }
    final templateName = await showDialog<String>(
      context: context,
      builder: (ctx) => _SaveAsTemplateDialog(defaultName: '$name template'),
    );
    if (templateName == null || templateName.trim().isEmpty) return;
    final inner = <String, dynamic>{
      'recurrence': _recurrence == EventRecurrence.annually
          ? 'annually'
          : 'none',
      'dayOfMonth': _at.day,
      'monthOfYear': _at.month,
      'leadTimeMillis': _leadMinutes * 60000,
      'name': templateName.trim(),
    };
    final payloadJson = jsonEncode({
      'k': TemplateLibrary.kTemplateFormatVersion,
      'event': inner,
    });
    try {
      await TemplateRepository.instance.save(
        Template(
          id: '',
          name: templateName.trim(),
          description: 'Saved from $name',
          iconName: 'event',
          entityType: TemplateEntityType.event,
          payloadJson: payloadJson,
          isBuiltIn: false,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Template saved')));
    } on TemplateValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template validation failed: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New event' : 'Edit event'),
        actions: [
          if (widget.existing != null)
            PopupMenuButton<_EventMenuAction>(
              key: const ValueKey('add_event.menu'),
              tooltip: 'More',
              onSelected: (a) {
                if (a == _EventMenuAction.saveAsTemplate) {
                  _saveAsTemplate();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem<_EventMenuAction>(
                  key: ValueKey('add_event.save_as_template'),
                  value: _EventMenuAction.saveAsTemplate,
                  child: Text('Save as template'),
                ),
              ],
            ),
          TextButton(
            key: const ValueKey('add_event.save'),
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
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: Spacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              trailing: Text(_dateLabel(_at)),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Time'),
              trailing: Text(
                TimeOfDay(hour: _at.hour, minute: _at.minute).format(context),
              ),
              onTap: _pickTime,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notify me'),
              trailing: Text(_leadLabel(_leadMinutes)),
              onTap: _pickLead,
            ),
            const SizedBox(height: Spacing.md),
            Text('Repeats', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (final r in EventRecurrence.values)
                  ChoiceChip(
                    label: Text(_recurrenceLabel(r)),
                    selected: _recurrence == r,
                    onSelected: (_) => setState(() => _recurrence = r),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _recurrenceLabel(EventRecurrence r) {
    return switch (r) {
      EventRecurrence.none => 'Once',
      EventRecurrence.annually => 'Yearly',
    };
  }
}

enum _EventMenuAction { saveAsTemplate }

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
        key: const ValueKey('add_event.save_as_template.name'),
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
          key: const ValueKey('add_event.save_as_template.save'),
          onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
