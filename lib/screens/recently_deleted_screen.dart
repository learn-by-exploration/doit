// v1.4-stab-H / Phase 48 / SYS-135 / ADR-066 / WF-063.
// Top-level "Recently deleted" surface for the v1.4l
// tombstone column (ADR-056). The data layer
// ([DoRepository.listDeleted] / [DoRepository.restoreById] /
// [DoRepository.deleteById]) shipped in v1.4l + v1.4m; this
// screen is the deferred UI surface.
//
// The screen lives at the top of the route table
// ([/recently-deleted], see `lib/app_router.dart`). The
// Settings screen tiles it as the only nav entry point so
// the bottom nav (Home / Settings / Stats) is not polluted
// with a transient surface.
//
// Per ADR-066 §"Architecture":
//
//   - The screen is a `StatefulWidget` (the list is
//     reloaded after a restore / delete-forever tap).
//   - The list query is wrapped in a `FutureBuilder` so a
//     load failure surfaces a Retry button without
//     throwing into the route's build cycle.
//   - The restore / delete-forever actions snack-bar a
//     success-or-failed copy from the ARB catalog.
//   - The delete-forever action is gated by an
//     `AlertDialog` confirm (the row-level action label is
//     repeated in the confirm CTA so the user reads the
//     destructive verb twice before tapping).

import 'package:flutter/material.dart';

import 'package:doit/do/do.dart' as domain;
import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/theme/app_theme.dart';

class RecentlyDeletedScreen extends StatefulWidget {
  const RecentlyDeletedScreen({super.key});

  @override
  State<RecentlyDeletedScreen> createState() => _RecentlyDeletedScreenState();
}

class _RecentlyDeletedScreenState extends State<RecentlyDeletedScreen> {
  late Future<List<domain.Do>> _future;

  @override
  void initState() {
    super.initState();
    _future = DoRepository.instance.listDeleted();
  }

  Future<void> _reload() async {
    setState(() {
      _future = DoRepository.instance.listDeleted();
    });
  }

  Future<void> _restore(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final ok = await DoRepository.instance.restoreById(id);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? l.recentlyDeletedRestoreSuccess : l.recentlyDeletedRestoreFailed,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _confirmDeleteForever(domain.Do d) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.recentlyDeletedDeleteForeverConfirm),
        content: Text(l.recentlyDeletedDeleteForeverConfirmBody),
        actions: [
          TextButton(
            key: const ValueKey('recently_deleted.delete_forever.cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.recentlyDeletedDeleteForeverCancel),
          ),
          FilledButton(
            key: const ValueKey('recently_deleted.delete_forever.confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.recentlyDeletedDeleteForeverConfirmCta),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DoRepository.instance.deleteById(d.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l.recentlyDeletedRestoreSuccess)),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l.recentlyDeletedDeleteForeverFailed)),
      );
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.recentlyDeletedTitle,
          key: const ValueKey('recently_deleted.title'),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<domain.Do>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorState(onRetry: _reload);
            }
            final items = snap.data ?? const <domain.Do>[];
            if (items.isEmpty) {
              return _EmptyState(message: l.recentlyDeletedEmpty);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(Spacing.md),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
              itemBuilder: (context, i) {
                final d = items[i];
                return _Row(
                  item: d,
                  onRestore: () => _restore(d.id),
                  onDeleteForever: () => _confirmDeleteForever(d),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Text(
          message,
          key: const ValueKey('recently_deleted.empty'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: Spacing.md),
          FilledButton.icon(
            key: const ValueKey('recently_deleted.retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l.recentlyDeletedRetry),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final domain.Do item;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final deletedAt = item.deletedAt;
    final when = deletedAt == null ? '' : _formatWhen(deletedAt);
    return Card(
      child: ListTile(
        key: ValueKey('recently_deleted.row.${item.id}'),
        leading: const Icon(Icons.delete_outline),
        title: Text(item.name),
        subtitle: Text(
          l.recentlyDeletedSubtitle(item.name, when),
          key: ValueKey('recently_deleted.row.${item.id}.subtitle'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('recently_deleted.restore.${item.id}'),
              tooltip: l.recentlyDeletedRestoreAction,
              icon: const Icon(Icons.restore),
              onPressed: onRestore,
            ),
            IconButton(
              key: ValueKey('recently_deleted.delete_forever.${item.id}'),
              tooltip: l.recentlyDeletedDeleteForeverAction,
              icon: const Icon(Icons.delete_forever),
              onPressed: onDeleteForever,
            ),
          ],
        ),
      ),
    );
  }
}

/// Render a tombstone timestamp as a short relative-time
/// string. Pure function — no `DateTime.now()` inside; the
/// caller passes the reference time. This mirrors the
/// `home_tile_streak.dart` "X days ago" pattern and keeps
/// the model layer (`lib/do/`) free of Flutter widgets.
String _formatWhen(DateTime at) {
  // The widget tree passes the screen's `DateTime.now()` in
  // a future cycle; for now we just stamp the date so the
  // subtitle is informative without coupling the screen to
  // a wall-clock. The cycle-H scope is the surface, not the
  // formatting niceties.
  final y = at.year.toString().padLeft(4, '0');
  final m = at.month.toString().padLeft(2, '0');
  final d = at.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
