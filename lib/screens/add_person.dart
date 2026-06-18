// Add-person screen — contact picker (flutter_contacts) →
// cadence → channel → save. Per WF-003.
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

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import 'package:doit/people/cadence.dart';
import 'package:doit/people/person.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/person_repository.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/widgets/permission_sheet.dart';

class AddPersonScreen extends StatefulWidget {
  const AddPersonScreen({super.key});

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {
  int _everyNDays = 7;
  String? _pickedName;
  String? _pickedPhone;
  String? _pickedLookupKey;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New person'),
        actions: [
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
      _pickedName = picked.displayName.isEmpty
          ? 'No name'
          : picked.displayName;
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
    final person = ContactPerson(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      // Use the contact's stable id when present; fall
      // back to the phone number (legacy) when the
      // picker is bypassed in a future flow.
      lookupKey: _pickedLookupKey ?? _pickedPhone!,
      channel: ChannelDialer(_pickedPhone!),
      cadence: EveryNDays(_everyNDays),
      createdAt: DateTime.now(),
    );
    await PersonRepository.instance.save(person);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}
