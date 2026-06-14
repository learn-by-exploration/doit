// EventsScreen — list of one-off date-specific reminders (WF-017).
//
// Per the rule doc (.claude/rules/lib-screens.md), this is a
// StatefulWidget that subscribes to the repository. The list is
// grouped into "Upcoming" and "Past" by the atMillis.

import 'package:flutter/material.dart';

import 'package:common_games/events/event.dart';
import 'package:common_games/services/event_repository.dart';
import 'package:common_games/services/reminder_service.dart';
import 'package:common_games/theme/app_theme.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late Future<List<Event>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = EventRepository.instance.listActive();
  }

  Future<void> _refresh() async {
    setState(() {
      _eventsFuture = EventRepository.instance.listActive();
    });
    // Re-schedule all event alarms.
    await ReminderService.instance.rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            key: const ValueKey('events.refresh'),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Event>>(
          future: _eventsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load events'),
                      const SizedBox(height: Spacing.sm),
                      FilledButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final events = snapshot.data ?? <Event>[];
            if (events.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(Spacing.lg),
                  child: Text(
                    'No events yet.\nTap + to add a one-off reminder.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return _EventsList(events: events, onChanged: _refresh);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('events.add'),
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddEventScreen()),
          );
          if (created == true) await _refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EventsList extends StatelessWidget {
  const _EventsList({required this.events, required this.onChanged});

  final List<Event> events;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = <Event>[];
    final past = <Event>[];
    for (final e in events) {
      if (e.atMillis > now.millisecondsSinceEpoch) {
        upcoming.add(e);
      } else {
        past.add(e);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        if (upcoming.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Text(
              'Upcoming',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final e in upcoming) _EventTile(event: e, onChanged: onChanged),
        ],
        if (past.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Text(
              'Past (unarchived)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final e in past) _EventTile(event: e, onChanged: onChanged),
        ],
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.onChanged});

  final Event event;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final at = DateTime.fromMillisecondsSinceEpoch(event.atMillis);
    return Card(
      child: ListTile(
        key: ValueKey('event.${event.id}'),
        title: Text(event.name),
        subtitle: Text(_formatAt(at)),
        trailing: Wrap(
          spacing: 4,
          children: [
            if (event.recurrence == EventRecurrence.annually)
              const Chip(label: Text('Yearly')),
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Archive',
              onPressed: () async {
                await EventRepository.instance.archive(
                  event.id,
                  DateTime.now(),
                );
                await ReminderService.instance.rescheduleAll();
                await onChanged();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () async {
                await EventRepository.instance.deleteById(event.id);
                await ReminderService.instance.rescheduleAll();
                await onChanged();
              },
            ),
          ],
        ),
        onTap: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => AddEventScreen(existing: event)),
          );
          if (changed == true) await onChanged();
        },
      ),
    );
  }

  String _formatAt(DateTime at) {
    final y = at.year.toString().padLeft(4, '0');
    final m = at.month.toString().padLeft(2, '0');
    final d = at.day.toString().padLeft(2, '0');
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key, this.existing});

  final Event? existing;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New event' : 'Edit event'),
        actions: [
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
