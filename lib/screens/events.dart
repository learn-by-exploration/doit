// EventsScreen — list of one-off date-specific reminders (WF-017).
//
// Per the rule doc (.claude/rules/lib-screens.md), this is a
// StatefulWidget that subscribes to the repository. The list is
// grouped into "Upcoming" and "Past" by the atMillis.
//
// Phase B PR 2: AddEventScreen was extracted to
// `lib/screens/add_event.dart` so it can carry the `initialPayload`
// pre-fill path and the AppBar "Save as template" action without
// bloating this file. The class is re-exported here for callers
// that already import this file.

import 'package:flutter/material.dart';

import 'package:doit/events/event.dart';
import 'package:doit/screens/add_event.dart';
import 'package:doit/services/event_repository.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/theme/app_theme.dart';

export 'package:doit/screens/add_event.dart' show AddEventScreen;

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
