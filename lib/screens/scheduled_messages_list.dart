// v1.8-pr-e2 / SYS-196 / ADR-126 / WF-122.
//
// List of scheduled messages (pending + recent). Pending
// rows show a cancel `AppIconButton`; fired + cancelled
// rows are read-only history. Tapping a row navigates
// to `AddScheduledMessageScreen` (edit mode for that
// row would land in a follow-up PR; the read-only
// affordance is enough for v1.8).
//
// Layer rules (lib-screens.md):
//   - State is local; refreshes on every `initState`
//     and after a successful `cancel` action.
//   - Empty state uses the `EmptyState` primitive
//     (lib/ui/empty_state.dart) for consistency with
//     the home screen.

import 'package:flutter/material.dart';

import 'package:doit/services/scheduled_message_repository.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/empty_state.dart';
import 'package:doit/ui/icon_button.dart';
import 'package:doit/ui/section_header.dart';

class ScheduledMessagesListScreen extends StatefulWidget {
  const ScheduledMessagesListScreen({super.key});

  @override
  State<ScheduledMessagesListScreen> createState() =>
      _ScheduledMessagesListScreenState();
}

class _ScheduledMessagesListScreenState
    extends State<ScheduledMessagesListScreen> {
  late Future<List<ScheduledMessage>> _pending;
  late Future<List<ScheduledMessage>> _history;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _pending = ScheduledMessageRepository.instance.listPending();
      _history = ScheduledMessageRepository.instance.listAll();
    });
  }

  Future<void> _cancel(ScheduledMessage row) async {
    await ScheduledMessageRepository.instance.cancel(row.id);
    await ReminderService.instance.cancelScheduledMessage(row.id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled messages'),
        actions: [
          IconButton(
            key: const ValueKey('scheduled_messages_list.refresh'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<ScheduledMessage>>(
          future: _pending,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final pending = snap.data ?? const <ScheduledMessage>[];
            if (pending.isEmpty) {
              return const EmptyState(
                title: 'No scheduled messages',
                message:
                    'Tap "+" on a person to schedule a message for a specific date and time.',
              );
            }
            return ListView(
              padding: const EdgeInsets.all(Spacing.md),
              children: [
                const SectionHeader('Pending'),
                for (final row in pending)
                  _ScheduledMessageTile(
                    key: ValueKey('scheduled_messages_list.row.${row.id}'),
                    row: row,
                    showCancel: true,
                    onCancel: () => _cancel(row),
                  ),
                const SizedBox(height: Spacing.lg),
                FutureBuilder<List<ScheduledMessage>>(
                  future: _history,
                  builder: (context, snap2) {
                    final past = (snap2.data ?? const <ScheduledMessage>[])
                        .where((r) => !r.isPending)
                        .toList();
                    if (past.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader('History'),
                        for (final row in past)
                          _ScheduledMessageTile(
                            key: ValueKey(
                              'scheduled_messages_list.history.${row.id}',
                            ),
                            row: row,
                            showCancel: false,
                            onCancel: null,
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScheduledMessageTile extends StatelessWidget {
  const _ScheduledMessageTile({
    super.key,
    required this.row,
    required this.showCancel,
    required this.onCancel,
  });
  final ScheduledMessage row;
  final bool showCancel;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (row.status) {
      ScheduledMessageStatus.pending => 'Pending',
      ScheduledMessageStatus.fired => 'Sent',
      ScheduledMessageStatus.cancelled => 'Cancelled',
    };
    return Card(
      child: ListTile(
        title: Text(row.personId ?? row.channelHandle),
        subtitle: Text(
          '${row.channelTag} • ${_formatFireAt(row.fireAt)} • $statusLabel',
        ),
        trailing: showCancel
            ? AppIconButton(
                key: ValueKey('scheduled_messages_list.cancel.${row.id}'),
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
                onPressed: onCancel,
              )
            : null,
      ),
    );
  }

  String _formatFireAt(DateTime at) {
    final y = at.year.toString();
    final m = at.month.toString().padLeft(2, '0');
    final d = at.day.toString().padLeft(2, '0');
    final h = at.hour.toString().padLeft(2, '0');
    final min = at.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}
