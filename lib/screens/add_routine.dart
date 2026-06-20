// AddRoutineScreen — configures the Japan silent-mode
// routine (template #16, Phase F PR 2 / SYS-075 / SYS-079).
//
// Per WF-037 the routine is configured end-to-end here:
//
//   1. Enable toggle.
//   2. Multi-select contacts (via the platform contact
//      picker, gated by READ_CONTACTS through the on-demand
//      PermissionSheet — same pattern as
//      [AddPersonScreen._pickContact]).
//   3. Target-mode radio (`SilentMode.normal` / `vibrate` /
//      `silent`).
//   4. Save: persists to [SettingsService.setJapanRoutine]
//      AND pushes the contact list to
//      [CallInterceptorService.configure] so the screening
//      service matches the new list on the next incoming
//      call.
//
// The screen is read-write and only used for the Japan
// routine in v1.0. The v1.1 line item adds a generic
// routine apply UX for templates #17..#21.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import 'package:doit/services/call_interceptor.dart';
import 'package:doit/services/japan_routine_config.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/triggers/trigger.dart' show SilentMode;
import 'package:doit/widgets/permission_sheet.dart';

class AddRoutineScreen extends StatefulWidget {
  const AddRoutineScreen({super.key});

  @override
  State<AddRoutineScreen> createState() => _AddRoutineScreenState();
}

class _AddRoutineScreenState extends State<AddRoutineScreen> {
  /// One picked contact. The routine's contactIds list
  /// carries the picked phones (E.164), not the contacts
  /// themselves — only the phone numbers are persisted (per
  /// the privacy contract: lib-people.md).
  final List<_PickedContact> _picked = <_PickedContact>[];

  late bool _enabled;
  late SilentMode _targetMode;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Seed from the persisted config so the screen is
    // edit-friendly on second-and-later visits. The user
    // can clear or change anything; the screen does not
    // require a fresh state on entry.
    final initial = SettingsService.instance.japanRoutine.value;
    _enabled = initial.enabled;
    _targetMode = initial.targetMode;
    for (final phone in initial.contactIds) {
      _picked.add(_PickedContact(name: phone, phone: phone));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Japan silent mode')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            Text(
              'When the phone is on silent, calls from the contacts '
              'below will ring through at the mode you pick.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Spacing.md),
            SwitchListTile.adaptive(
              key: const ValueKey('add_routine.enabled'),
              title: const Text('Enable routine'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: Spacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Text(
                'Contacts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              'Pick the contacts whose calls should ring through. '
              'Calls from anyone else stay on the current silent mode.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.sm),
            _ContactsList(
              picked: _picked,
              onAdd: _pickContact,
              onRemove: (i) => setState(() => _picked.removeAt(i)),
            ),
            const SizedBox(height: Spacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Text(
                'Ringer mode',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              'When a chosen contact calls, the phone snaps to this mode '
              'for the duration of the call.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.sm),
            _TargetModeRadio(
              value: _targetMode,
              onChanged: (m) => setState(() => _targetMode = m),
            ),
            const SizedBox(height: Spacing.lg),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Text(
                  _error!,
                  key: const ValueKey('add_routine.error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              key: const ValueKey('add_routine.save'),
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickContact() async {
    final granted = await PermissionSheet.show(
      context,
      PermissionKind.contacts,
    );
    if (!granted) return;
    if (!mounted) return;
    final Contact? picked = await FlutterContacts.openExternalPick();
    if (!mounted || picked == null) return;
    if (picked.phones.isEmpty) {
      setState(() {
        _error = 'That contact has no phone number. Pick another.';
      });
      return;
    }
    final phone = picked.phones.first.number;
    if (_picked.any((c) => c.phone == phone)) {
      setState(() {
        _error = 'That contact is already on the list.';
      });
      return;
    }
    setState(() {
      _error = null;
      _picked.add(
        _PickedContact(
          name: picked.displayName.isEmpty ? phone : picked.displayName,
          phone: phone,
        ),
      );
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final config = JapanRoutineConfig(
        enabled: _enabled,
        contactIds: List<String>.unmodifiable(_picked.map((c) => c.phone)),
        targetMode: _targetMode,
      );
      await SettingsService.instance.setJapanRoutine(config);
      // Push the new contact list to the screening service.
      // When `_enabled` is false the service treats every
      // call as a pass-through — the contactIds are still
      // pushed so toggling `enabled` from the Settings tile
      // is instant.
      await CallInterceptorService.instance.configure(
        enabled: _enabled,
        contactIds: config.contactIds,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AddRoutineScreen._save failed: $e\n$st');
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Save failed: $e';
      });
    }
  }
}

class _PickedContact {
  const _PickedContact({required this.name, required this.phone});
  final String name;
  final String phone;
}

class _ContactsList extends StatelessWidget {
  const _ContactsList({
    required this.picked,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_PickedContact> picked;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < picked.length; i++)
          ListTile(
            key: ValueKey('add_routine.contact.$i'),
            leading: const Icon(Icons.person_outline),
            title: Text(picked[i].name),
            subtitle: Text(picked[i].phone),
            trailing: IconButton(
              key: ValueKey('add_routine.contact.$i.remove'),
              icon: const Icon(Icons.close),
              tooltip: 'Remove contact',
              onPressed: () => onRemove(i),
            ),
          ),
        const SizedBox(height: Spacing.sm),
        FilledButton.tonal(
          key: const ValueKey('add_routine.add_contact'),
          onPressed: onAdd,
          child: const Text('Add contact'),
        ),
      ],
    );
  }
}

class _TargetModeRadio extends StatelessWidget {
  const _TargetModeRadio({required this.value, required this.onChanged});

  final SilentMode value;
  final ValueChanged<SilentMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<SilentMode>(
      groupValue: value,
      onChanged: (m) {
        if (m != null) onChanged(m);
      },
      child: Column(
        children: [
          for (final entry in const [
            (SilentMode.normal, 'Normal — sound + vibrate'),
            (SilentMode.vibrate, 'Vibrate — no sound'),
            (SilentMode.silent, 'Silent — no sound, no vibrate'),
          ])
            RadioListTile<SilentMode>(
              key: ValueKey('add_routine.target_mode.${entry.$1.name}'),
              title: Text(entry.$2),
              value: entry.$1,
            ),
        ],
      ),
    );
  }
}
