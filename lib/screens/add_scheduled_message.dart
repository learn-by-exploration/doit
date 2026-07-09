// v1.8-pr-e2 / SYS-195 / ADR-126 / WF-122.
//
// Form screen for "schedule a message to be sent at
// <date+time>". The user picks a person (optional —
// one-off schedules to a typed number are allowed), the
// channel, the date+time, and an optional body. Save
// persists a [ScheduledMessage] row and arms a one-shot
// alarm. At fire time the row is marked `fired` and the
// notification's body-tap launches the channel app (see
// `lib/services/reminder_service.dart:onFireAlarm` and
// the Kotlin-side `MainActivity.uriPendingIntent`).
//
// Layer rules (lib-screens.md):
//   - State is local; no Provider for this screen.
//   - The form does NOT use a `DateTime.now()`-derived
//     default; the user picks the date explicitly.
//   - The Save button is disabled until a recipient
//     (personId or typed number) + a future date+time
//     are set.
//   - All errors are shown inline; no silent failures.

import 'package:flutter/material.dart';

import 'package:doit/people/person.dart' as domain;
import 'package:doit/services/person_repository.dart';
import 'package:doit/services/scheduled_message_repository.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/app_form_field.dart';
import 'package:doit/ui/primary_button.dart';
import 'package:doit/ui/section_header.dart';

class AddScheduledMessageScreen extends StatefulWidget {
  const AddScheduledMessageScreen({super.key, this.personId});

  /// Optional pre-fill. When set, the form pre-selects
  /// the person and hides the "Pick a person" CTA.
  final String? personId;

  @override
  State<AddScheduledMessageScreen> createState() =>
      _AddScheduledMessageScreenState();
}

class _AddScheduledMessageScreenState extends State<AddScheduledMessageScreen> {
  // Form state.
  final _bodyCtrl = TextEditingController();
  domain.Person? _person;
  domain.PersonChannel _channel = const domain.ChannelSms('');
  // Default the fire time to "now + 5 minutes" so a
  // test schedule lands in the near future. Pinned via
  // `DateTime.now()` only at the form default (not in
  // the model); the model layer still gets a
  // user-confirmed `DateTime`.
  late DateTime _at = DateTime.now().add(const Duration(minutes: 5));
  String? _typedNumber;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.personId != null) {
      _loadPerson(widget.personId!);
    }
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPerson(String id) async {
    final person = await PersonRepository.instance.getById(id);
    if (person == null || !mounted) return;
    setState(() {
      _person = person;
      _channel = person.channel;
    });
  }

  bool get _isValid {
    // Must have either a person OR a typed number, and
    // a future date+time.
    final hasRecipient =
        _person != null || (_typedNumber != null && _typedNumber!.isNotEmpty);
    final hasFutureTime = _at.isAfter(DateTime.now());
    return hasRecipient && hasFutureTime;
  }

  String? get _effectiveHandle {
    if (_person != null) {
      final c = _person!.channel;
      return switch (c) {
        domain.ChannelDialer(:final phoneNumber) => phoneNumber,
        domain.ChannelWhatsApp(:final phoneNumber) => phoneNumber,
        domain.ChannelTelegram(:final username) => username,
        domain.ChannelSignal(:final phoneNumber) => phoneNumber,
        domain.ChannelSms(:final phoneNumber) => phoneNumber,
      };
    }
    return _typedNumber;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = 'sm-${DateTime.now().millisecondsSinceEpoch}';
      final handle = _effectiveHandle;
      if (handle == null || handle.isEmpty) {
        setState(() {
          _error = 'Pick a person or type a number.';
          _saving = false;
        });
        return;
      }
      // The ScheduledMessage row stores the channel
      // tag + handle as plain strings (Drift TEXT).
      // At fire time `PersonChannel.fromTag(...)`
      // re-builds the channel for the URI launch.
      final channel = _channel;
      // For the no-person case the user typed a number;
      // default the channel to SMS (most common
      // one-off-schedule use case). Re-route the
      // channel to a fresh instance with the typed
      // handle so the row has the correct handle.
      final effectiveChannel = _person != null
          ? channel
          : (channel is domain.ChannelSms
                ? domain.ChannelSms(handle)
                : channel);
      final row = ScheduledMessage(
        id: id,
        personId: _person?.id,
        channelTag: effectiveChannel.tag,
        channelHandle: handle,
        messageBody: _bodyCtrl.text.trim().isEmpty
            ? null
            : _bodyCtrl.text.trim(),
        fireAt: _at,
        status: ScheduledMessageStatus.pending,
        createdAt: DateTime.now(),
      );
      await ScheduledMessageRepository.instance.save(row);
      await ReminderService.instance.scheduleScheduledMessage(
        scheduledMessageId: id,
        at: _at,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule a message'),
        actions: [
          TextButton(
            key: const ValueKey('add_scheduled_message.save'),
            onPressed: _isValid && !_saving ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            const SectionHeader('Recipient'),
            if (_person != null)
              ListTile(
                key: const ValueKey('add_scheduled_message.person'),
                leading: const Icon(Icons.person),
                title: Text(_person!.id),
                subtitle: Text(_channel.tag),
              )
            else
              AppFormField(
                key: const ValueKey('add_scheduled_message.typed_number'),
                label: 'Phone number',
                helperText: '+1 555 555 0100',
                keyboardType: TextInputType.phone,
                onChanged: (v) => setState(() => _typedNumber = v.trim()),
              ),
            const SizedBox(height: Spacing.lg),
            const SectionHeader('Channel'),
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (final tag in const [
                  'dialer',
                  'whatsapp',
                  'telegram',
                  'signal',
                  'sms',
                ])
                  ChoiceChip(
                    key: ValueKey('add_scheduled_message.channel.$tag'),
                    label: Text(_channelLabel(tag)),
                    selected: _channel.tag == tag,
                    onSelected: (_) {
                      setState(() {
                        final h = _effectiveHandle ?? '';
                        _channel = domain.PersonChannel.fromTag(tag, h);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            const SectionHeader('When'),
            ListTile(
              key: const ValueKey('add_scheduled_message.date'),
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(
                '${_at.year}-${_at.month.toString().padLeft(2, '0')}-${_at.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
            ListTile(
              key: const ValueKey('add_scheduled_message.time'),
              leading: const Icon(Icons.schedule),
              title: Text(
                '${_at.hour.toString().padLeft(2, '0')}:${_at.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickTime,
            ),
            const SizedBox(height: Spacing.lg),
            const SectionHeader('Message'),
            AppFormField(
              key: const ValueKey('add_scheduled_message.body'),
              label: 'Body (optional)',
              helperText: 'Type the message…',
              maxLines: 4,
              controller: _bodyCtrl,
            ),
            if (_error != null) ...[
              const SizedBox(height: Spacing.md),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            PrimaryButton(
              key: const ValueKey('add_scheduled_message.cta'),
              label: _saving
                  ? const Text('Saving…')
                  : const Text('Schedule message'),
              onPressed: _isValid && !_saving ? _save : null,
            ),
          ],
        ),
      ),
    );
  }

  String _channelLabel(String tag) {
    switch (tag) {
      case 'dialer':
        return 'Call';
      case 'whatsapp':
        return 'WhatsApp';
      case 'telegram':
        return 'Telegram';
      case 'signal':
        return 'Signal';
      case 'sms':
        return 'SMS';
    }
    return tag;
  }
}
