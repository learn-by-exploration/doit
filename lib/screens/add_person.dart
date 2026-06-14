// Add-person screen — contact picker (flutter_contacts) →
// cadence → channel → save. Per WF-003.
//
// v0.1 supports the EveryNDays cadence and a single channel
// (Dialer). WeeklyOn / MonthlyOn / YearlyOn and the other 4
// channels (WhatsApp / Telegram / Signal / Sms) are the
// v0.2 line items.
//
// The contact picker is a thin wrapper around
// `flutter_contacts`. The screen reads the picked contact
// and shows a confirmation step before save.

import 'package:flutter/material.dart';

import 'package:common_games/people/cadence.dart';
import 'package:common_games/people/person.dart';
import 'package:common_games/services/person_repository.dart';
import 'package:common_games/theme/app_theme.dart';

class AddPersonScreen extends StatefulWidget {
  const AddPersonScreen({super.key});

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {
  int _everyNDays = 7;
  String? _pickedName;
  String? _pickedPhone;
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
    // v0.1: stub that the contact picker wrapper fills in
    // once flutter_contacts is wired through the platform
    // channel. For now, an in-memory demo contact.
    setState(() {
      _pickedName = _pickedName == null ? 'Demo Contact' : null;
      _pickedPhone = _pickedPhone == null ? '+1 555 0100' : null;
    });
  }

  Future<void> _save() async {
    if (_pickedName == null || _pickedPhone == null) {
      setState(() => _error = 'Pick a contact first.');
      return;
    }
    final person = ContactPerson(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      lookupKey: _pickedPhone!,
      channel: ChannelDialer(_pickedPhone!),
      cadence: EveryNDays(_everyNDays),
      createdAt: DateTime.now(),
    );
    await PersonRepository.instance.save(person);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}
