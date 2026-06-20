// Add / Edit person screen — contact picker (flutter_contacts)
// → cadence → channel → save. Per WF-003 and WF-022
// (edit). One screen with two modes:
//   - Add: no `personId` arg.
//   - Edit: `personId` arg provided; the form pre-fills.
//
// v0.1 supports the EveryNDays cadence and a single channel
// (Dialer). WeeklyOn / MonthlyOn / YearlyOn and the other 4
// channels (WhatsApp / Telegram / Signal / Sms) are the
// v0.2 line items.
//
// The contact picker is a thin wrapper around
// `flutter_contacts`. v0.6 (ADR-018) wires the picker
// behind the on-demand `PermissionSheet` (SYS-067): tapping
// the contact row checks `READ_CONTACTS` first; if missing,
// the modal sheet appears before the system picker is
// shown. Per the privacy contract (lib-people.md), the
// app stores only the contact's stable `id` (used as
// `lookupKey`) and a phone number — never the full vCard.
//
// Phase B PR 2: the screen also accepts an `initialPayload`
// (mirroring the inner envelope of a `person` template) to
// pre-fill the cadence + channel for the catalog apply path.
// The "Save as template" AppBar action is only available in
// edit mode (a fresh add has no persisted person to
// template).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import 'package:doit/people/cadence.dart';
import 'package:doit/people/person.dart';
import 'package:doit/routines/routine.dart';
import 'package:doit/routines/routine_executor.dart';
import 'package:doit/services/geofence_service.dart';
import 'package:doit/services/person_repository.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/template_repository.dart';
import 'package:doit/templates/template.dart';
import 'package:doit/templates/template_library.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:doit/widgets/calendar_picker.dart';
import 'package:doit/widgets/location_picker.dart';
import 'package:doit/widgets/permission_sheet.dart';

class AddPersonScreen extends StatefulWidget {
  const AddPersonScreen({super.key, this.personId, this.initialPayload});

  /// If non-null, the screen loads the person with this id
  /// and runs in edit mode. Save will overwrite; createdAt
  /// is preserved. The "Save as template" AppBar action is
  /// only available when this is non-null.
  final String? personId;

  /// Optional pre-fill payload, mirroring the inner envelope
  /// key of a person template
  /// (`{"cadenceType":...,"nDays":N,"weekday":N,
  /// "dayOfMonth":N,"monthOfYear":N,"channel":"dialer",
  /// "name":"..."}`). Used by the catalog screen when the
  /// user picks a template. Default `null` (blank form).
  final Map<String, dynamic>? initialPayload;

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {
  int _everyNDays = 7;
  String? _pickedName;
  String? _pickedPhone;
  String? _pickedLookupKey;
  String? _error;

  /// Persisted name (used by save-as-template as a fallback
  /// for the description when the user has not picked a
  /// contact yet — rare in edit mode).
  String? _persistedName;

  /// Cached most-recent successful save. Used by the
  /// "Save as template" action.
  Person? _lastSaved;

  // v1.0 (Phase C, SYS-072). Non-default automation rules.
  // Empty list = the default ActionNotify (synthesized at
  // dispatch time). Stored on the row as
  // `People.automations_json`.
  List<Automation> _automations = const <Automation>[];

  bool get _isEdit => widget.personId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadExisting();
    } else {
      final payload = widget.initialPayload;
      if (payload != null) _applyPayload(payload);
    }
  }

  Future<void> _loadExisting() async {
    final id = widget.personId;
    if (id == null) return;
    final person = await PersonRepository.instance.getById(id);
    if (person == null || !mounted) return;
    setState(() {
      _persistedName = person.lookupKey;
      if (person is ContactPerson) {
        // The phone is the ChannelDialer handle for the
        // v0.1 model. Other channels land in v0.2.
        final channel = person.channel;
        if (channel is ChannelDialer) {
          _pickedPhone = channel.phoneNumber;
        }
        _pickedLookupKey = person.lookupKey;
        _pickedName = person.lookupKey;
        final cadence = person.cadence;
        if (cadence is EveryNDays) {
          _everyNDays = cadence.nDays;
        }
        _automations = person.automations;
      }
      _lastSaved = person;
    });
  }

  /// Apply a pre-fill payload to the form.
  void _applyPayload(Map<String, dynamic> p) {
    final name = p['name'] as String?;
    if (name != null) {
      _persistedName = name;
    }
    final nDays = (p['nDays'] as num?)?.toInt();
    if (nDays != null && nDays > 0) {
      _everyNDays = nDays;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit person' : 'New person'),
        actions: [
          if (_isEdit)
            PopupMenuButton<_PersonMenuAction>(
              key: const ValueKey('add_person.menu'),
              tooltip: 'More',
              onSelected: (a) {
                if (a == _PersonMenuAction.saveAsTemplate) {
                  _saveAsTemplate();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem<_PersonMenuAction>(
                  key: ValueKey('add_person.save_as_template'),
                  value: _PersonMenuAction.saveAsTemplate,
                  child: Text('Save as template'),
                ),
              ],
            ),
          TextButton(
            key: const ValueKey('add_person.save'),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            ListTile(
              key: const ValueKey('add_person.pick_contact'),
              leading: const Icon(Icons.contacts),
              title: Text(_pickedName ?? 'Pick a contact'),
              subtitle: _pickedPhone == null ? null : Text(_pickedPhone!),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickContact,
            ),
            if (_error != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const Divider(height: Spacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Text(
                'Cadence',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              title: const Text('Every N days'),
              trailing: SizedBox(
                width: 80,
                child: TextFormField(
                  key: const ValueKey('add_person.every_n'),
                  textAlign: TextAlign.right,
                  initialValue: _everyNDays.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) {
                      _everyNDays = n;
                    }
                  },
                ),
              ),
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
          ],
        ),
      ),
    );
  }

  Future<void> _pickContact() async {
    // SYS-067: gate on READ_CONTACTS at the moment of use.
    // The on-demand sheet is the only seam for runtime
    // permission requests; do not call `Permission.contacts.request()`
    // directly from a widget (lib-screens.md).
    final granted = await PermissionSheet.show(
      context,
      PermissionKind.contacts,
    );
    if (!granted) {
      // The user denied or dismissed the sheet. The row
      // stays in the empty state; no inline error (the sheet
      // already showed the rationale).
      return;
    }
    if (!mounted) return;
    // Open the system contact picker (the platform's native
    // picker handles Android 11+'s contacts provider
    // permission model — the picker is granted its own
    // `READ_CONTACTS` scope per Android's "picker" pattern,
    // so a separate process-level grant is not required for
    // this method to work; the `PermissionSheet` gate above
    // is for the *full* `READ_CONTACTS` read that the
    // service layer uses for cadence resolution).
    final Contact? picked = await FlutterContacts.openExternalPick();
    if (!mounted) return;
    if (picked == null) {
      // The user dismissed the system picker. No-op.
      return;
    }
    // A picked contact with no phone is rejected — the
    // ChannelDialer requires a phone number. Show an inline
    // error and let the user pick again.
    if (picked.phones.isEmpty) {
      setState(() {
        _error = 'That contact has no phone number. Pick another.';
        _pickedName = null;
        _pickedPhone = null;
      });
      return;
    }
    setState(() {
      _error = null;
      _pickedName = picked.displayName.isEmpty ? 'No name' : picked.displayName;
      _pickedPhone = picked.phones.first.number;
      // Stash the contact's stable id so future re-resolutions
      // (per `PersonResolver`) can match the same record even
      // if the display name changes. flutter_contacts uses
      // the platform's contact id directly; we hash it to
      // avoid storing anything user-identifiable in the
      // cadence log (privacy contract: lib-people.md).
      _pickedLookupKey = picked.id;
    });
  }

  Future<void> _save() async {
    if (_pickedName == null || _pickedPhone == null) {
      setState(() => _error = 'Pick a contact first.');
      return;
    }
    final now = DateTime.now();
    final person = ContactPerson(
      id: widget.personId ?? 'p_${now.millisecondsSinceEpoch}',
      // Use the contact's stable id when present; fall
      // back to the phone number (legacy) when the
      // picker is bypassed in a future flow.
      lookupKey: _pickedLookupKey ?? _pickedPhone!,
      channel: ChannelDialer(_pickedPhone!),
      cadence: EveryNDays(_everyNDays),
      createdAt: _lastSaved?.createdAt ?? now,
      automations: _automations,
    );
    await PersonRepository.instance.save(person);
    _lastSaved = person;
    // v1.0 Phase C PR 2 (SYS-072): register the routines'
    // geofences with the platform service so the executor
    // can match transitions as soon as the row is
    // persisted.
    await _registerRoutines(person.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// Open the [LocationPicker] modal and append the result
  /// to [_automations]. The picker handles its own
  /// permission gate (SYS-076); we just consume the
  /// returned [Automation]. `null` returns are user cancels
  /// or denied permissions — silent no-op.
  Future<void> _addLocationRoutine() async {
    final auto = await LocationPicker.show(context);
    if (auto == null || !mounted) return;
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
  /// Calendar triggers are matched by `RoutineExecutor`
  /// against the `CalendarService.events` stream — there is
  /// no per-trigger platform registration the way
  /// `GeofenceService.register` exists for locations, so we
  /// just append the result and the save path re-registers
  /// the automation set with the executor.
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

  Future<void> _saveAsTemplate() async {
    final source = _lastSaved;
    if (source == null) return;
    final name = _pickedName ?? _persistedName ?? 'Person';
    final templateName = await showDialog<String>(
      context: context,
      builder: (ctx) => _SaveAsTemplateDialog(defaultName: '$name template'),
    );
    if (templateName == null || templateName.trim().isEmpty) return;
    final inner = _personToMap(source);
    inner['name'] = templateName.trim();
    final payloadJson = jsonEncode({
      'k': TemplateLibrary.kTemplateFormatVersion,
      'person': inner,
    });
    try {
      await TemplateRepository.instance.save(
        Template(
          id: '',
          name: templateName.trim(),
          description: 'Saved from $name',
          iconName: 'group',
          entityType: TemplateEntityType.person,
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

  Map<String, dynamic> _personToMap(Person p) {
    String cadenceType = 'every_n_days';
    int nDays = 0;
    int weekday = 0;
    int dayOfMonth = 0;
    int monthOfYear = 0;
    final cadence = p.cadence;
    if (cadence is EveryNDays) {
      cadenceType = 'every_n_days';
      nDays = cadence.nDays;
    } else if (cadence is WeeklyOn) {
      cadenceType = 'weekly_on';
      weekday = cadence.weekday;
    } else if (cadence is MonthlyOn) {
      cadenceType = 'monthly_on';
      dayOfMonth = cadence.dayOfMonth;
    } else if (cadence is YearlyOn) {
      cadenceType = 'yearly_on';
      monthOfYear = cadence.month;
      dayOfMonth = cadence.day;
    }
    return <String, dynamic>{
      'cadenceType': cadenceType,
      'nDays': nDays,
      'weekday': weekday,
      'dayOfMonth': dayOfMonth,
      'monthOfYear': monthOfYear,
      'channel': 'dialer',
      'name': _pickedName ?? _persistedName ?? 'Person',
    };
  }
}

enum _PersonMenuAction { saveAsTemplate }

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
        key: const ValueKey('add_person.save_as_template.name'),
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
          key: const ValueKey('add_person.save_as_template.save'),
          onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// "Routines" section of the Add / Edit person form
/// (SYS-072). Mirrors the [lib/screens/add_habit.dart] /
/// [lib/screens/add_event.dart] sections so the pattern is
/// uniform across the entity-type forms.
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
              'No routines yet. Add one to remind you to reach '
              'out when you arrive at or leave a place, or when '
              'a calendar event starts, ends, hits its reminder, '
              'or changes your busy status.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          for (var i = 0; i < automations.length; i++)
            _PersonRoutineRow(
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
                key: const ValueKey('add_person.add_location_routine'),
                onPressed: onAddLocation,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add a location routine'),
              ),
              TextButton.icon(
                key: const ValueKey('add_person.add_calendar_routine'),
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

class _PersonRoutineRow extends StatelessWidget {
  const _PersonRoutineRow({required this.automation, required this.onRemove});

  final Automation automation;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final trigger = automation.trigger;
    final summary = switch (trigger) {
      TriggerLocationEnter(:final label, :final radiusMeters) =>
        'On enter $label ($radiusMeters m)',
      TriggerLocationExit(:final label, :final radiusMeters) =>
        'On exit $label ($radiusMeters m)',
      _ => trigger.runtimeType.toString(),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.bolt_outlined),
      title: Text(summary),
      trailing: IconButton(
        key: const ValueKey('add_person.remove_routine'),
        tooltip: 'Remove',
        icon: const Icon(Icons.close),
        onPressed: onRemove,
      ),
    );
  }
}
