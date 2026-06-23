// Editable completion-log section for the edit screen
// (`AddHabitScreen` in edit mode). Renders the most-recent
// N completions for the habit as a list with a "delete"
// (undo) action per row. Tapping delete opens a confirm
// dialog, removes the row from the log, and rebuilds the
// list.
//
// Per WF-025 ("edit completion log"), users must be able
// to undo an accidental completion without leaving the
// edit screen. The completion log is the source of truth
// for streak calculation; removing an entry is the
// simplest corrective action and is sufficient for the
// v1.2 use case (changing the day bucket or timestamp of
// an entry is a v2.0 polish item).

import 'package:flutter/material.dart';

import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/db/schema.dart' show CompletionRow;
import 'package:doit/theme/app_theme.dart';

/// Cap on the number of completions rendered in the
/// section. Anything older than this is hidden — the user
/// can see "Older entries hidden — view all" if there are
/// more rows in the log.
const int kCompletionLogSectionMaxRows = 30;

class CompletionLogSection extends StatefulWidget {
  const CompletionLogSection({super.key, required this.habitId});

  final String habitId;

  @override
  State<CompletionLogSection> createState() => _CompletionLogSectionState();
}

class _CompletionLogSectionState extends State<CompletionLogSection> {
  late Future<List<CompletionRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CompletionRow>> _load() async {
    final rows = await CompletionLogService.instance.listForHabit(
      widget.habitId,
    );
    // Newest first for the UI.
    final sorted = [...rows]
      ..sort((a, b) => b.completedAtMillis.compareTo(a.completedAtMillis));
    return sorted;
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _confirmAndDelete(CompletionRow row) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('completion_log.delete.confirm'),
        title: const Text('Delete this completion?'),
        content: Text(_rowDescription(row)),
        actions: [
          TextButton(
            key: const ValueKey('completion_log.delete.cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('completion_log.delete.confirm_button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await CompletionLogService.instance.deleteById(row.id);
    } on Object catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete entry.')),
      );
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Completion removed.')),
    );
    _refresh();
  }

  String _rowDescription(CompletionRow row) {
    final day = DateTime.fromMillisecondsSinceEpoch(row.dayMillis);
    final completedAt = DateTime.fromMillisecondsSinceEpoch(
      row.completedAtMillis,
    );
    final dayLabel = _formatDay(day);
    final timeLabel = _formatTime(completedAt);
    return '$dayLabel at $timeLabel (${row.source}). '
        'This will shorten your streak by one day.';
  }

  String _formatDay(DateTime d) {
    return '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  }

  String _formatTime(DateTime d) {
    return '${_pad(d.hour)}:${_pad(d.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('completion_log.section'),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.history),
                const SizedBox(width: Spacing.sm),
                Text(
                  'Recent completions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  key: const ValueKey('completion_log.refresh'),
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            FutureBuilder<List<CompletionRow>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(Spacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Text(
                    'Could not load completion log.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                final rows = snap.data ?? <CompletionRow>[];
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(Spacing.sm),
                    child: Text(
                      'No completions yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                final shown = rows.take(kCompletionLogSectionMaxRows).toList();
                final hidden = rows.length - shown.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in shown)
                      _CompletionLogRow(
                        key: ValueKey('completion_log.row.${r.id}'),
                        row: r,
                        dayLabel: _formatDay(
                          DateTime.fromMillisecondsSinceEpoch(r.dayMillis),
                        ),
                        timeLabel: _formatTime(
                          DateTime.fromMillisecondsSinceEpoch(
                            r.completedAtMillis,
                          ),
                        ),
                        onDelete: () => _confirmAndDelete(r),
                      ),
                    if (hidden > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: Spacing.sm),
                        child: Text(
                          '$hidden older entr${hidden == 1 ? 'y is' : 'ies are'} '
                          'hidden.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionLogRow extends StatelessWidget {
  const _CompletionLogRow({
    super.key,
    required this.row,
    required this.dayLabel,
    required this.timeLabel,
    required this.onDelete,
  });

  final CompletionRow row;
  final String dayLabel;
  final String timeLabel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.check_circle_outline),
      title: Text('$dayLabel · $timeLabel'),
      subtitle: Text(row.source),
      trailing: IconButton(
        key: ValueKey('completion_log.delete.${row.id}'),
        tooltip: 'Delete this completion',
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }
}
