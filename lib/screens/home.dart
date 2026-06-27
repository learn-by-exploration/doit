// Home screen — the catalog + due-now strip + "I'm up" anchor.
//
// Per WF-002 (entry) and WF-004..010 / WF-014..016, the home
// screen:
//   - Lists every active habit in alphabetical order, with the
//     category color as the tile's accent.
//   - Shows a "due now" strip at the top (the next
//     occurrence of each habit that is past-due or due
//     within the next hour).
//   - Has a floating add button (FAB) for "Add habit" or
//     "Add person".
//   - Has an "I'm up" button that records the wake-up
//     anchor (manual mode).
//   - Renders the reliability banner when degraded.
//
// v0.2 (WF-022, WF-031, SYS-031): tap a tile to open
// `AddHabitScreen` in edit mode. The tile shows the
// habit's category color (8-swatch palette), icon, and
// pause badge if paused.
//
// State: a `FutureBuilder` reads the habit list once and
// rebuilds when a save / delete is dispatched. v0.1 has no
// stream; the home screen re-fetches on `didChangeAppLifecycleState`
// (resume).

import 'package:flutter/material.dart';

import 'package:doit/do/consecutive_counter.dart';
import 'package:doit/do/do.dart';
import 'package:doit/do/do_description.dart';
import 'package:doit/do/proof_mode.dart';
import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/screens/home_tile_budget.dart';
import 'package:doit/screens/home_tile_completion.dart';
import 'package:doit/screens/home_tile_delete.dart';
import 'package:doit/screens/home_tile_skip.dart';
import 'package:doit/screens/home_tile_sparkline.dart';
import 'package:doit/screens/rest_day_picker_dialog.dart';
import 'package:doit/screens/home_tile_streak.dart';
import 'package:doit/screens/home_tile_undo.dart';
import 'package:doit/screens/mission_launcher.dart';
import 'package:doit/services/completion_log_service.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/widgets/category_chip.dart';
import 'package:doit/widgets/reliability_banner.dart';
import 'package:doit/widgets/routine_banner.dart';
import 'package:doit/screens/add_habit.dart';
import 'package:doit/screens/add_person.dart';
import 'package:doit/screens/settings.dart';
import 'package:doit/screens/stats.dart';
import 'package:doit/screens/templates.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Future<List<Do>>? _habitsFuture;
  final Set<String> _selected = <String>{};
  bool _selectMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    setState(() {
      _habitsFuture = DoRepository.instance.listAll();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      if (_selected.isEmpty) _selectMode = false;
    });
  }

  void _enterSelectMode(String firstId) {
    setState(() {
      _selectMode = true;
      _selected.add(firstId);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  /// Tap handler for a tile in normal (non-select) mode.
  /// Opens the edit screen and, if the screen pops with
  /// `true` (WF-022 hard delete), refreshes the home list
  /// so the deleted tile disappears immediately.
  Future<void> _onTileTap(String habitId) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => AddHabitScreen(habitId: habitId)),
    );
    if (deleted == true) _refresh();
  }

  Future<void> _completeSelected() async {
    final now = DateTime.now();
    for (final id in _selected) {
      await CompletionLogService.instance.append(
        habitId: id,
        day: now,
        source: CompletionSource.manual,
        proofModeAtTime: 'soft',
      );
    }
    if (!mounted) return;
    _exitSelectMode();
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(
            context,
          ).homeSnackbarMarkedCount(_selected.length),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectMode
              ? l.homeSelectionAppBarTitle(_selected.length)
              : l.homeAppBarTitle,
        ),
        leading: _selectMode
            ? IconButton(
                key: const ValueKey('home.cancel_select'),
                tooltip: 'Cancel',
                icon: const Icon(Icons.close),
                onPressed: _exitSelectMode,
              )
            : null,
        actions: [
          if (_selectMode)
            IconButton(
              key: const ValueKey('home.complete_selected'),
              tooltip: 'Mark selected done',
              icon: const Icon(Icons.check_circle),
              onPressed: _selected.isEmpty ? null : _completeSelected,
            )
          else ...[
            IconButton(
              tooltip: 'Stats',
              icon: const Icon(Icons.bar_chart),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const StatsScreen()),
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ReliabilityBanner.fromStream(
              // v1.3c / Phase 14 / SYS-113 / ADR-043: when
              // the unified reliability stream flips to
              // `degraded` (because the user revoked a
              // permission — or any of the 5 gated kinds
              // from the v1.3b service), the banner shows a
              // chevron and is tappable. One tap lands the
              // user on the Settings → Permissions screen
              // where each gated kind has its own tile. The
              // deep-link is the single discoverable
              // affordance; without it the user has no way
              // to recover from a degraded state.
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
            const RoutineBanner(),
            const _AddAnchorButton(),
            Expanded(
              child: FutureBuilder<List<Do>>(
                future: _habitsFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return _ErrorView(
                      message: 'Could not load habits',
                      onRetry: _refresh,
                    );
                  }
                  final habits = snap.data ?? <Do>[];
                  if (habits.isEmpty) {
                    return const _EmptyState();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(Spacing.md),
                    itemCount: habits.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Spacing.sm),
                    itemBuilder: (_, i) => _HabitTile(
                      habit: habits[i],
                      selected: _selected.contains(habits[i].id),
                      selectMode: _selectMode,
                      onLongPress: () => _enterSelectMode(habits[i].id),
                      onTap: _selectMode
                          ? () => _toggleSelect(habits[i].id)
                          : () => _onTileTap(habits[i].id),
                      // v1.4h / SYS-122: per-tile edit/delete
                      // mutates the do set; re-fetch the
                      // habits future so the tile disappears
                      // immediately.
                      onDoChanged: _refresh,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _AddFab(onAdded: _refresh),
    );
  }
}

class _AddAnchorButton extends StatelessWidget {
  const _AddAnchorButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: SizedBox(
        width: double.infinity,
        height: Sizing.tapHome,
        child: FilledButton.icon(
          key: const ValueKey('home.im_up'),
          icon: const Icon(Icons.wb_sunny_outlined),
          label: const Text("I'm up"),
          onPressed: () {
            final t = ReminderService.instance.anchor.markNow();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  t == null
                      ? 'Already up — see you in a few hours.'
                      : 'Marked as up.',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HabitTile extends StatefulWidget {
  const _HabitTile({
    required this.habit,
    this.selected = false,
    this.selectMode = false,
    this.onLongPress,
    this.onTap,
    this.onDoChanged,
  });
  final Do habit;
  final bool selected;
  final bool selectMode;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  // v1.4h / SYS-122: invoked when the tile mutates the
  // do set (delete; or an edit that adds/removes a do).
  // The home screen re-fetches its `_habitsFuture` on
  // this callback so the tile disappears immediately.
  final VoidCallback? onDoChanged;

  @override
  State<_HabitTile> createState() => _HabitTileState();
}

class _HabitTileState extends State<_HabitTile> {
  // v1.4b / Phase 29 / SYS-116: the tile is a
  // StatefulWidget so the per-tile "Done" button can
  // reflect in-flight state and the same-day "already
  // done" hint without round-tripping to the parent.
  bool _busy = false;
  bool _isCompletedToday = false;
  // v1.4c / Phase 30 / SYS-117: a rest-day tap for today
  // resolves the day in the same way as a manual
  // completion (the streak is credited). The tile
  // treats either as "resolved today" — see
  // `_isResolvedToday` below.
  bool _isSkippedToday = false;

  bool get _isResolvedToday => _isCompletedToday || _isSkippedToday;

  Future<void> _onMarkDonePressed() async {
    if (_busy) return;
    if (_isResolvedToday) {
      // Same-day re-tap is a no-op (CompletionLogService
      // dedupes anyway, but we short-circuit here so the
      // SnackBar + busy state don't flicker). The hint
      // copy depends on which surface resolved the day.
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSkippedToday
                ? l.homeTileSkipAlready
                : l.homeTileAlreadyDoneTooltip,
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final habit = widget.habit;
    if (habit.proofMode is StrongProof) {
      // v1.3d / SYS-114 path: push the mission UI. The
      // launcher writes the completion itself on
      // ChainPassed. We mirror the widget's strong-mode
      // contract — the tile does NOT call
      // CompletionLogService.append for strong-mode
      // habits; the mission UI owns that write.
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => MissionLauncherScreen(habitId: habit.id),
        ),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (result == true) _isCompletedToday = true;
      });
      return;
    }
    // Soft / Auto: fire-and-forget manual completion via
    // the shared helper. Mirrors WidgetService.markDone
    // (v1.4a) — same dedupe key, same proofMode tag.
    final now = DateTime.now();
    await markDoDone(
      activeDo: habit,
      asOf: now,
      completionLog: CompletionLogService.instance,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _isCompletedToday = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).homeSnackbarMarkedDone),
      ),
    );
  }

  /// v1.4c / SYS-117 — the tile-level handler for a
  /// "Skip today" tap. Writes a rest-day completion via
  /// `markDoSkipped` and reflects the resolved state in
  /// `_isSkippedToday` so the "Done" button can no-op
  /// (the day is resolved either way).
  ///
  /// Error path: a `NoRestDaysRemaining` from the helper
  /// surfaces as a "no rest days left this month"
  /// snackbar — the busy flag is cleared and the tile
  /// stays in the un-resolved state.
  Future<void> _onSkipTodayPressed() async {
    if (_busy) return;
    if (_isResolvedToday) return; // no-op second tap
    final habit = widget.habit;
    if (habit.restDaysPerMonth <= 0) {
      // The button is hidden when the do has no budget,
      // but defensively reject the tap if it ever leaks
      // through (e.g., a config change mid-frame).
      return;
    }
    setState(() => _busy = true);
    final now = DateTime.now();
    final l = AppLocalizations.of(context);
    try {
      await markDoSkipped(
        activeDo: habit,
        asOf: now,
        completionLog: CompletionLogService.instance,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _isSkippedToday = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.homeTileSkipSuccess)));
    } on NoRestDaysRemaining {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.homeTileSkipBudgetExhausted)));
    }
  }

  /// v1.4d / SYS-118 — the tile-level handler for an
  /// "Undo today" tap. Reverts today's completion (or
  /// rest-day) row via `undoToday` and flips the
  /// `_isCompletedToday` / `_isSkippedToday` flag back to
  /// `false` based on which source was deleted. Mirrors
  /// `CompletionLogSection._confirmAndDelete` (v1.2m /
  /// SYS-108) but at the tile surface with one fewer tap.
  ///
  /// Flow: tap → open `AlertDialog` (gated on the user
  /// tapping "Undo") → confirm → call `undoToday` → on
  /// `UndoResult.removed` flip the matching flag to
  /// `false` + show `homeTileUndoSuccess` snackbar → on
  /// `UndoResult.nothingToUndo` show the defensive
  /// `homeTileUndoNotToday` snackbar (DB-as-truth; the
  /// dialog is gated on `_isResolvedToday` but a
  /// concurrent tile rebuild could leave a dangling
  /// flag).
  Future<void> _onUndoTodayPressed() async {
    if (_busy) return;
    if (!_isResolvedToday) return; // no-op if not resolved
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.homeTileUndoConfirm),
        content: Text(l.homeTileUndoConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.homeTileUndoToday),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    // Capture the messenger BEFORE the async gap so
    // we can surface the snackbar even if the
    // post-undo setState disposes the widget (e.g.,
    // the parent rebuild removes the tile).
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final now = DateTime.now();
    final result = await undoToday(
      activeDo: widget.habit,
      asOf: now,
      completionLog: CompletionLogService.instance,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case UndoResultRemoved(:final source):
        // Flip the flag that matches the deleted source
        // back to false. Manual → completed flag; restDay
        // → skipped flag. Other sources (notification,
        // mission) are possible but the tile only
        // resolves via manual (Done) or restDay (Skip);
        // the flag stays as-is if neither matches.
        setState(() {
          if (source == 'rest_day') {
            _isSkippedToday = false;
          } else if (source == 'manual') {
            _isCompletedToday = false;
          }
        });
        messenger.showSnackBar(SnackBar(content: Text(l.homeTileUndoSuccess)));
      case UndoResultNothingToUndo():
        messenger.showSnackBar(SnackBar(content: Text(l.homeTileUndoNotToday)));
    }
  }

  /// v1.4h / SYS-122 — per-tile "Edit" handler. Mirrors
  /// the home-screen `_onTileTap` (`lib/screens/home.dart:120`)
  /// but invoked from an explicit IconButton on the tile
  /// surface instead of the body-tap. The body-tap is
  /// still the fastest path for power users; the new
  /// IconButton is the discoverable affordance for users
  /// who don't know that tapping the body opens the
  /// editor.
  ///
  /// `AddHabitScreen` already pops `true` on a hard
  /// delete (WF-022); on that signal we trigger the
  /// parent's `_refresh()` via `widget.onDoChanged` so the
  /// tile disappears immediately. A normal save pops
  /// `false` (or `null`) and the tile stays.
  Future<void> _onEditPressed() async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddHabitScreen(habitId: widget.habit.id),
      ),
    );
    if (deleted == true) {
      widget.onDoChanged?.call();
    }
  }

  /// v1.4l / Phase 39 / SYS-126 / ADR-056 / WF-053 — per-
  /// tile "Delete" handler with true Undo. Opens an
  /// `AlertDialog` (gated on the user tapping "Delete" in
  /// the dialog) → calls the pure-Dart `softDeleteDo`
  /// helper → on `true` shows a SnackBar with an "Undo"
  /// action that calls `restoreById` on the captured `Do`
  /// id.
  ///
  /// v1.4l replaces the v1.4h hard-delete + Undo-re-save
  /// path with soft-delete + Undo-restore. The motivation:
  /// the Drift schema declares NO FK constraints (see
  /// `lib/services/db/tables.dart`), so a hard-delete
  /// leaves orphan `Completions` + `RestDayBudgets` rows
  /// in the DB. The v1.4h re-save path on Undo re-inserted
  /// the `Habits` row but the streak counter still started
  /// from 0 (the `insertOnConflictUpdate` semantics + a
  /// latent `_toRow` bug that drops `automationsJson` — see
  /// ADR-056 §"Risks"). v1.4l's soft-delete keeps the
  /// `Habits` row + completion-log rows in the table so
  /// `ConsecutiveCounter.compute` can rebuild the streak
  /// from the log on restore.
  ///
  /// Flow: tap → open `AlertDialog` (gated on
  /// confirm) → capture `messenger = ScaffoldMessenger.of(context)`
  /// BEFORE the async gap → `setState(_busy = true)` →
  /// `softDeleteDo(...)` → on `true` clear `_busy` + flip
  /// `onDoChanged` → show SnackBar with Undo action → on
  /// Undo tap, `restoreDo(...)` flips the parent's
  /// `onDoChanged` again → on `false` (helper returned
  /// false) clear `_busy` and show failure snackbar WITHOUT
  /// removing the tile.
  Future<void> _onDeletePressed() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final habit = widget.habit;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.homeTileDeleteConfirm(habit.name)),
        content: Text(l.homeTileDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.homeTileDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    // Capture the messenger BEFORE the async gap so we
    // can surface the snackbar even if the post-delete
    // setState disposes the widget (e.g., the parent
    // rebuild removes the tile).
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final ok = await softDeleteDo(
      activeDo: habit,
      at: DateTime.now(),
      repository: DoRepository.instance,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.homeSnackbarDoDeleteFailed)),
      );
      return;
    }
    // Happy path: the do is tombstoned (`deletedAtMillis`
    // set, row stays in the table). The captured `habit`
    // reference is still valid in memory — we pass its id
    // to `restoreDo` on Undo. The parent's `_refresh()`
    // re-fetches the list so the tile disappears immediately
    // (the `listAll` filter excludes tombstoned rows).
    widget.onDoChanged?.call();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.homeSnackbarDoDeleted(habit.name)),
        action: SnackBarAction(
          label: l.homeSnackbarDoDeletedUndo,
          onPressed: () async {
            final restored = await restoreDo(
              tombstonedDo: habit,
              repository: DoRepository.instance,
            );
            if (restored) {
              widget.onDoChanged?.call();
            }
            // If `restored` is false (the row was already
            // active — e.g., the user double-tapped Undo),
            // the SnackBar stays in its success state; the
            // DB is the source of truth.
          },
        ),
      ),
    );
  }

  /// v1.4j (SYS-124): tap handler for the budget caption
  /// under the streak badge. Opens the shared
  /// `RestDayPickerDialog` (single source of truth for the
  /// picker UI; the AddHabitScreen form row uses the same
  /// helper) and writes the picked value to
  /// `DoRepository.save(habit.copyWith(restDaysPerMonth: N))`.
  ///
  /// The `_busy` flag is NOT used — the save is fast enough
  /// that a spinner would flicker, and the dialog itself is
  /// the in-flight indicator. On a save throw (defensive —
  /// the picker clamps inline so `Do.validate()`'s upper
  /// bound never fires in practice), the tile stays in
  /// place and the failure snackbar is shown.
  Future<void> _onBudgetCaptionTapped() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showRestDayPicker(
      context,
      initial: widget.habit.restDaysPerMonth,
    );
    if (picked == null) return;
    if (!mounted) return;
    try {
      await DoRepository.instance.save(
        widget.habit.copyWith(restDaysPerMonth: picked),
      );
      widget.onDoChanged?.call();
      messenger.showSnackBar(
        SnackBar(content: Text(l.homeSnackbarBudgetUpdated(picked))),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.homeSnackbarBudgetUpdateFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final selected = widget.selected;
    final selectMode = widget.selectMode;
    final onTap = widget.onTap;
    final onLongPress = widget.onLongPress;
    final visual = CategoryChipResolver.resolveFor(
      category: habit.category,
      colorSeed: habit.colorSeed,
    );
    final color = Color(visual.color);
    final isPaused =
        habit.pausedUntil != null && habit.pausedUntil!.isAfter(DateTime.now());
    final completions = CompletionLogService.instance.listForHabit(habit.id);
    // The frozen `asOf` for the streak compute is the
    // build-time clock. A new completion write triggers a
    // rebuild via the parent's `_refresh()` — see the
    // SnackBar handler. Same as the widget's surface
    // (v1.4a), this avoids `DateTime.now()` calls inside
    // the streak helper.
    final asOf = DateTime.now();
    return Semantics(
      label:
          'Do ${habit.name}'
          '${isPaused ? ', paused' : ''}'
          '${selected ? ', selected' : ''}',
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.30)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('habit_tile.${habit.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                if (selectMode)
                  Padding(
                    padding: const EdgeInsets.only(right: Spacing.sm),
                    child: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: color,
                    ),
                  ),
                _TileIcon(
                  category: habit.category,
                  iconName: habit.iconName,
                  color: color,
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              habit.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          // v1.4b / SYS-116: streak badge.
                          // Renders the run length next to
                          // the name. Mirrors the widget's
                          // middle row. v1.4c / SYS-117
                          // also takes a budget future to
                          // render the rest-day caption
                          // underneath.
                          _DoStreakBadge(
                            completions: completions,
                            activeDo: habit,
                            asOf: asOf,
                            onBudgetCaptionTapped: _onBudgetCaptionTapped,
                            budget: budgetRemainingForDo(
                              activeDo: habit,
                              asOf: asOf,
                              completionLog: CompletionLogService.instance,
                            ),
                          ),
                          if (isPaused)
                            Tooltip(
                              message: 'Paused',
                              child: Icon(
                                Icons.pause_circle,
                                size: 18,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        describeDo(habit),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (habit is DoTimeWindow) _FastingTimer(habit: habit),
                    ],
                  ),
                ),
                if (!selectMode)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // v1.4h / SYS-122: per-tile edit
                      // button. Renders first (leftmost) in
                      // the action row, separated from the
                      // completion buttons (Skip / Undo /
                      // Done) so the destructive-action
                      // cluster (Edit / Delete) is visually
                      // distinct from the completion
                      // cluster.
                      _EditButton(onPressed: _onEditPressed),
                      _DeleteButton(busy: _busy, onPressed: _onDeletePressed),
                      // v1.4c / SYS-117: skip-today button.
                      // Hidden when the do has no rest-day
                      // budget configured (the user opted
                      // out of rest days for this do).
                      // Disabled-look is achieved by not
                      // rendering at all — there's nothing
                      // to skip.
                      if (habit.restDaysPerMonth > 0)
                        _SkipButton(
                          busy: _busy,
                          isSkippedToday: _isSkippedToday,
                          onPressed: _onSkipTodayPressed,
                        ),
                      // v1.4d / SYS-118: undo button.
                      // Visible only when the day is
                      // resolved (Done or Skip recorded).
                      // Tap opens an `AlertDialog` that
                      // calls `undoToday` on confirm.
                      if (_isResolvedToday)
                        _UndoButton(
                          busy: _busy,
                          onPressed: _onUndoTodayPressed,
                        ),
                      _DoneButton(
                        busy: _busy,
                        isCompletedToday: _isCompletedToday,
                        isStrong: habit.proofMode is StrongProof,
                        onPressed: _onMarkDonePressed,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// v1.4b / SYS-116 — the streak number + "day streak"
/// subtitle rendered next to the do name on the home
/// tile. Mirrors the widget's `streak_number` row.
///
/// v1.4c / SYS-117: also renders the budget caption
/// ("X / Y rest days left") under the streak subtitle
/// when the budget is configured AND has been touched.
class _DoStreakBadge extends StatelessWidget {
  const _DoStreakBadge({
    required this.completions,
    required this.activeDo,
    required this.asOf,
    required this.budget,
    required this.onBudgetCaptionTapped,
  });
  final Future<List<CompletionRow>> completions;
  final Do activeDo;
  final DateTime asOf;
  final Future<BudgetRemaining> budget;

  /// v1.4j (SYS-124): forwarded to the `_BudgetCaption`'s
  /// `onTap` so the caption itself is the affordance for
  /// editing `restDaysPerMonth`. Owner is the parent
  /// `_HabitTileState` — the badge is a stateless
  /// presentation widget that has no side effects of its
  /// own.
  final VoidCallback onBudgetCaptionTapped;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<List<CompletionRow>>(
      future: completions,
      builder: (context, snap) {
        final rows = snap.data ?? const <CompletionRow>[];
        // Convert DB rows → pure-Dart log entries. The
        // streak helper takes CompletionLogEntry so it
        // stays Flutter-free. `dayMillis` is local-midnight
        // stored as millis-since-epoch (see
        // CompletionLogService._toDayMillis).
        final entries = rows
            .map(
              (r) => CompletionLogEntry(
                doId: r.habitId,
                date: DateTime.fromMillisecondsSinceEpoch(r.dayMillis),
              ),
            )
            .toList(growable: false);
        final streak = streakForDo(
          activeDo: activeDo,
          completions: entries,
          asOf: asOf,
        );
        return Semantics(
          label: '$streak ${l.homeTileStreakLabel}',
          child: Padding(
            padding: const EdgeInsets.only(left: Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$streak',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  l.homeTileStreakLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                // v1.4c / SYS-117: nested FutureBuilder for
                // the budget caption. Two futures is fine —
                // the parent FutureBuilder's `ConnectionState`
                // already controls the badge skeleton.
                FutureBuilder<BudgetRemaining>(
                  future: budget,
                  builder: (context, bSnap) {
                    final b = bSnap.data;
                    if (b == null) return const SizedBox.shrink();
                    return _BudgetCaption(
                      budget: b,
                      isExhausted: b.isExhausted,
                      onTap: onBudgetCaptionTapped,
                      zeroCaption: l.homeTileBudgetZeroCaption,
                    );
                  },
                ),
                // v1.4e / Phase 32 / SYS-119: 7-day sparkline
                // row. Renders one dot per day for the last
                // week; today is highlighted via a larger
                // filled dot. `completionLog` is the same
                // singleton the streak + budget futures
                // already use — re-using it keeps the
                // round-trip count to one Drift read per
                // tile rebuild.
                //
                // v1.4i / Phase 36 / SYS-123: extended the
                // default window to 14 days + colored
                // rest-day fills with `colorScheme.tertiary`
                // + added a legend row below the dots so the
                // user can see at a glance which days were
                // intentionally skipped (rest days) vs
                // manually completed vs missed.
                _Sparkline(
                  activeDo: activeDo,
                  asOf: asOf,
                  completionLog: CompletionLogService.instance,
                  resolvedToday: rows.any(
                    (r) =>
                        r.dayMillis ==
                        DateTime(
                          asOf.year,
                          asOf.month,
                          asOf.day,
                        ).millisecondsSinceEpoch,
                  ),
                  restDayColor: Theme.of(context).colorScheme.tertiary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// v1.4b / SYS-116 — the per-tile "Done" button. Renders
/// a spinner while the completion write is in flight; a
/// filled check after a same-day completion.
class _DoneButton extends StatelessWidget {
  const _DoneButton({
    required this.busy,
    required this.isCompletedToday,
    required this.isStrong,
    required this.onPressed,
  });
  final bool busy;
  final bool isCompletedToday;
  final bool isStrong;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tooltip = isCompletedToday
        ? l.homeTileAlreadyDoneTooltip
        : isStrong
        ? l.homeTileStrongModeHint
        : l.homeTileMarkDone;
    final icon = isCompletedToday
        ? Icons.check_circle
        : Icons.check_circle_outline;
    return IconButton(
      tooltip: tooltip,
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      iconSize: Sizing.tapHome / 2,
      onPressed: busy ? null : onPressed,
    );
  }
}

/// v1.4h / SYS-122 — the per-tile "Edit" button. Opens
/// `AddHabitScreen` in edit mode for this do. Mirrors the
/// body-tap affordance (the existing path that opens the
/// editor from the home screen, see
/// `_HomeScreenState._onTileTap`) but as an explicit,
/// discoverable IconButton so the affordance is visible
/// without knowing the body-tap gesture.
///
/// No busy state — the edit screen is a navigation push,
/// not an in-flight write. The IconButton is always
/// tappable; the tile's `_busy` flag (which gates the
/// completion buttons) does not apply here.
class _EditButton extends StatelessWidget {
  const _EditButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return IconButton(
      tooltip: l.homeTileEdit,
      icon: const Icon(Icons.edit_outlined),
      iconSize: Sizing.tapHome / 2,
      onPressed: onPressed,
    );
  }
}

/// v1.4h / SYS-122 — the per-tile "Delete" button. Opens
/// an `AlertDialog` (the parent `_HabitTileState._onDeletePressed`
/// pops `true` on confirm) that calls
/// `DoRepository.deleteById` and shows a SnackBar with an
/// "Undo" action that re-saves the captured do.
///
/// Visual states mirror `_SkipButton`:
///   - busy → spinner (in-flight `deleteById` call)
///   - otherwise → outlined trash icon
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.busy, required this.onPressed});
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return IconButton(
      tooltip: l.homeTileDelete,
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.delete_outline),
      iconSize: Sizing.tapHome / 2,
      onPressed: busy ? null : onPressed,
    );
  }
}

/// Live-updating fasting timer shown on DoTimeWindow tiles.
/// Ticks every second; shows the time until the window closes
/// (or "starts in HH:MM" if the window hasn't opened yet).
class _FastingTimer extends StatefulWidget {
  const _FastingTimer({required this.habit});
  final DoTimeWindow habit;

  @override
  State<_FastingTimer> createState() => _FastingTimerState();
}

class _FastingTimerState extends State<_FastingTimer> {
  late Stream<DateTime> _tick;

  @override
  void initState() {
    super.initState();
    _tick = Stream<DateTime>.periodic(
      const Duration(seconds: 1),
      (_) => DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: _tick,
      builder: (context, snap) {
        final now = snap.data ?? DateTime.now();
        final label = _windowLabel(widget.habit, now);
        if (label == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: Spacing.xs),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16),
              const SizedBox(width: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }

  /// "Closes in 02:30" / "Opens in 12:00" / null if today is
  /// not a fasting weekday.
  String? _windowLabel(DoTimeWindow h, DateTime now) {
    if (!h.weekdays.contains(now.weekday)) return null;
    final open = DateTime(
      now.year,
      now.month,
      now.day,
      h.start.hour,
      h.start.minute,
    );
    final close = DateTime(
      now.year,
      now.month,
      now.day,
      h.end.hour,
      h.end.minute,
    );
    if (now.isBefore(open)) {
      return 'Opens in ${_fmt(open.difference(now))}';
    }
    if (now.isBefore(close)) {
      final remaining = close.difference(now);
      final target = h.targetHours;
      if (target != null) {
        return 'Fasting — ${_fmt(remaining)} left (target ${target}h)';
      }
      return 'Window closes in ${_fmt(remaining)}';
    }
    return null;
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({
    required this.category,
    required this.iconName,
    required this.color,
  });

  final DoCategory category;
  final String? iconName;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        shape: BoxShape.circle,
      ),
      child: Icon(_iconFor(category, iconName), color: color, size: 24),
    );
  }

  IconData _iconFor(DoCategory c, String? name) {
    final key = DoIcons.resolveFor(category: c, iconName: name);
    return _iconMap[key] ?? Icons.check;
  }

  static const Map<String, IconData> _iconMap = <String, IconData>{
    'local_drink': Icons.local_drink,
    'directions_run': Icons.directions_run,
    'fitness_center': Icons.fitness_center,
    'self_improvement': Icons.self_improvement,
    'bedtime': Icons.bedtime,
    'wb_sunny': Icons.wb_sunny,
    'restaurant': Icons.restaurant,
    'local_fire_department': Icons.local_fire_department,
    'spa': Icons.spa,
    'air': Icons.air,
    'menu_book': Icons.menu_book,
    'edit_note': Icons.edit_note,
    'psychology_alt': Icons.psychology_alt,
    'lightbulb': Icons.lightbulb,
    'auto_stories': Icons.auto_stories,
    'call': Icons.call,
    'chat': Icons.chat,
    'mail': Icons.mail,
    'group': Icons.group,
    'favorite': Icons.favorite,
    'pets': Icons.pets,
    'volunteer_activism': Icons.volunteer_activism,
    'diversity_3': Icons.diversity_3,
    'check_circle': Icons.check_circle,
    'task_alt': Icons.task_alt,
    'pending_actions': Icons.pending_actions,
    'event': Icons.event,
    'today': Icons.today,
    'schedule': Icons.schedule,
    'work': Icons.work,
    'school': Icons.school,
    'home': Icons.home,
    'cleaning_services': Icons.cleaning_services,
    'kitchen': Icons.kitchen,
    'local_laundry_service': Icons.local_laundry_service,
    'yard': Icons.yard,
    'shopping_cart': Icons.shopping_cart,
    'receipt_long': Icons.receipt_long,
    'savings': Icons.savings,
    'block': Icons.block,
    'do_not_disturb': Icons.do_not_disturb,
    'pause_circle': Icons.pause_circle,
    'repeat': Icons.repeat,
    'restore': Icons.restore,
    'undo': Icons.undo,
    'check': Icons.check,
    'restaurant_menu': Icons.restaurant_menu,
    'lunch_dining': Icons.lunch_dining,
    'local_pizza': Icons.local_pizza,
    'cake': Icons.cake,
    'coffee': Icons.coffee,
    'liquor': Icons.liquor,
    'set_meal': Icons.set_meal,
    'directions_walk': Icons.directions_walk,
    'directions_bike': Icons.directions_bike,
    'pool': Icons.pool,
    'sports_gymnastics': Icons.sports_gymnastics,
    'sports_tennis': Icons.sports_tennis,
    'sports_basketball': Icons.sports_basketball,
    'sports_soccer': Icons.sports_soccer,
    'hiking': Icons.hiking,
  };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt_outlined,
              size: Sizing.huge,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              AppLocalizations.of(context).homeEmptyTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Tap the + to add a do or a person.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: Spacing.md),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).homeRetryButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFab extends StatelessWidget {
  const _AddFab({required this.onAdded});
  final VoidCallback onAdded;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      key: const ValueKey('home.fab'),
      onPressed: () async {
        final choice = await showModalBottomSheet<_AddChoice>(
          context: context,
          builder: (_) => const _AddSheet(),
        );
        if (choice == null) return;
        if (!context.mounted) return;
        switch (choice) {
          case _AddChoice.habit:
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AddHabitScreen()),
            );
            onAdded();
          case _AddChoice.person:
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AddPersonScreen()),
            );
            onAdded();
          case _AddChoice.template:
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TemplatesScreen()),
            );
        }
      },
      child: const Icon(Icons.add),
    );
  }
}

enum _AddChoice { habit, person, template }

class _AddSheet extends StatelessWidget {
  const _AddSheet();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('home.fab.habit'),
            leading: const Icon(Icons.checklist),
            title: Text(l.homeAddSheetNewDo),
            onTap: () => Navigator.of(context).pop(_AddChoice.habit),
          ),
          ListTile(
            key: const ValueKey('home.fab.person'),
            leading: const Icon(Icons.person_add_alt_1),
            title: Text(l.homeAddSheetNewPerson),
            onTap: () => Navigator.of(context).pop(_AddChoice.person),
          ),
          ListTile(
            key: const ValueKey('home.fab.template'),
            leading: const Icon(Icons.dashboard_customize),
            title: Text(l.homeAddSheetFromTemplate),
            onTap: () => Navigator.of(context).pop(_AddChoice.template),
          ),
          const SizedBox(height: Spacing.md),
        ],
      ),
    );
  }
}

/// v1.4c / SYS-117 — the per-tile "Skip today" button.
/// Renders next to the `_DoneButton` on the right edge
/// of the tile, only when:
///   - the do has a non-zero rest-day budget
///   - the day is not already resolved (neither done
///     nor skipped)
///   - the tile is not in select-mode (long-press
///     surfaces a different action set there)
///
/// Visual states mirror the `_DoneButton`:
///   - busy → spinner
///   - skipped today → filled moon icon (gray-out)
///   - otherwise → outline moon icon
class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.busy,
    required this.isSkippedToday,
    required this.onPressed,
  });
  final bool busy;
  final bool isSkippedToday;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tooltip = isSkippedToday
        ? l.homeTileSkipAlready
        : l.homeTileSkipToday;
    final icon = isSkippedToday ? Icons.bedtime : Icons.bedtime_outlined;
    return IconButton(
      tooltip: tooltip,
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      iconSize: Sizing.tapHome / 2,
      onPressed: busy ? null : onPressed,
    );
  }
}

/// v1.4d / SYS-118 — undo today's completion button.
/// Renders between `_SkipButton` and `_DoneButton` on
/// the right edge of the tile, only when:
///   - the day is already resolved (`_isResolvedToday
///     == true`, i.e., Done or Skip recorded)
///   - the tile is not in select-mode
///
/// Tap opens an `AlertDialog` that calls `undoToday` on
/// confirm. On the happy path the tile flips
/// `_isCompletedToday` / `_isSkippedToday` (whichever
/// was true) back to `false` and shows the
/// `homeTileUndoSuccess` SnackBar. The button itself
/// does not carry a "completed" / "skipped" visual
/// state — once resolved, the undo affordance is always
/// available; the day-state icons on the other buttons
/// already convey what kind of completion is on file.
///
/// Visual states:
///   - busy → spinner (in-flight `undoToday` call)
///   - otherwise → outlined undo icon (`Icons.undo`)
class _UndoButton extends StatelessWidget {
  const _UndoButton({required this.busy, required this.onPressed});
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return IconButton(
      tooltip: l.homeTileUndoToday,
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.undo),
      iconSize: Sizing.tapHome / 2,
      onPressed: busy ? null : onPressed,
    );
  }
}

/// v1.4c / SYS-117 / v1.4j / SYS-124 — small caption
/// rendered under the streak badge showing "X / Y rest days
/// left this month". Also serves as the affordance for
/// editing `restDaysPerMonth` — tapping the caption opens
/// the shared `RestDayPickerDialog` (see
/// `lib/screens/rest_day_picker_dialog.dart`).
///
/// v1.4j drops the two early-returns that previously hid
/// the caption when:
///   - the do has no rest-day budget configured (`limit <= 0`)
///   - the budget hasn't been touched yet (`used == 0`)
///
/// Hiding the affordance in those states was the v1.4c
/// design, but the v1.4i sprint review surfaced the gap:
/// users with no budget (or no rest days used yet) had no
/// way to discover that the budget feature existed at all.
/// v1.4j surfaces `homeTileBudgetZeroCaption`
/// ("No rest days configured") in the `limit <= 0` case so
/// the affordance is always visible.
class _BudgetCaption extends StatelessWidget {
  const _BudgetCaption({
    required this.budget,
    required this.isExhausted,
    required this.onTap,
    required this.zeroCaption,
  });
  final BudgetRemaining budget;
  final bool isExhausted;

  /// v1.4j (SYS-124): tap handler that opens the
  /// `RestDayPickerDialog` and writes the picked value via
  /// `DoRepository.save(...)`. Captured by `_HabitTileState`
  /// so the dialog's async gap cannot leak a stale
  /// `BuildContext` into the SnackBar call.
  final VoidCallback onTap;

  /// Localized "No rest days configured" string. Becomes
  /// the Semantics label for the tap target when the budget
  /// is zero so TalkBack announces a discoverable button.
  final String zeroCaption;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final String text;
    final TextStyle? style;
    if (budget.limit <= 0) {
      // Surface the affordance to users who haven't
      // configured a budget yet — the previous
      // SizedBox.shrink() hid the feature entirely.
      text = zeroCaption;
      style = Theme.of(context).textTheme.bodySmall;
    } else if (isExhausted) {
      text = l.homeTileBudgetNoRemaining;
      style = Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
      );
    } else {
      text = l.homeTileBudgetRemaining(budget.remaining, budget.limit);
      style = Theme.of(context).textTheme.bodySmall;
    }
    // v1.4j: wrap the caption in a tap target + Semantics
    // button so TalkBack announces "No rest days configured,
    // button" / "2/3 rest days left, button". The
    // GestureDetector is INSIDE the tile body, so the tile's
    // outer InkWell.onLongPress (select mode, v1.4b) is
    // unaffected — tap and long-press are different gestures.
    return Semantics(
      button: true,
      label: text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(text, style: style),
        ),
      ),
    );
  }
}

/// v1.4e / Phase 32 / SYS-119 / ADR-049 / WF-046 — the
/// sparkline rendered under the streak badge on the in-app
/// home tile. Originally a 7-day row (v1.4e); v1.4i /
/// SYS-123 / ADR-053 / WF-050 extended the default window
/// to **14 days** so the rest-day color distinction has
/// enough context to be useful, and added an optional
/// legend below the row.
///
/// Wraps `extendedSparklineForDo` (the pure-Dart helper)
/// in a `FutureBuilder` and renders a row of [days] dots:
///   - filled (primary): at least one completion row exists
///     for that day with `source` in `manual`,
///     `notification`, or `mission`;
///   - filled ([restDayColor]): the only completion row for
///     that day has `source = 'rest_day'` (the user took a
///     rest day instead of completing the do);
///   - outlined: no completion row for that day;
///   - the rightmost dot (today) is larger + filled when
///     the user has resolved today.
///
/// `resolvedToday` is a sync hint from the parent
/// `_DoStreakBadge` so the sparkline does not have to
/// re-walk the rows; the hint is `true` when at least one
/// row in `completions` matches today's local-midnight.
class _Sparkline extends StatelessWidget {
  // The `days` and `showLegend` optional parameters are
  // intentionally unused by the production call site —
  // they exist for future variants (e.g., a "compact"
  // sparkline without legend for a denser layout, or a
  // 30-day window for the stats screen). The defaults are
  // what the in-app tile uses.
  const _Sparkline({
    required this.activeDo,
    required this.asOf,
    required this.completionLog,
    required this.resolvedToday,
    // ignore: unused_element_parameter
    this.days = 14,
    this.restDayColor,
    // ignore: unused_element_parameter
    this.showLegend = true,
  });

  final Do activeDo;
  final DateTime asOf;
  final CompletionLogService completionLog;
  final bool resolvedToday;

  /// The number of days to render. Defaults to 14 (v1.4i
  /// / SYS-123) — a fortnight, half a calendar month, the
  /// smallest window that gives the rest-day color
  /// distinction enough context to be meaningful. The
  /// v1.4e default of 7 is preserved for any caller that
  /// explicitly opts in.
  final int days;

  /// Color used to fill dots whose underlying row has
  /// `source = 'rest_day'`. When `null` (the default), the
  /// rest-day dot falls back to `colorScheme.primary`
  /// (the same color as a manual completion), preserving
  /// the v1.4e "all fills are equal" semantic. Pass the
  /// in-app tile's `colorScheme.tertiary` to enable the
  /// rest-day color distinction (v1.4i / SYS-123).
  final Color? restDayColor;

  /// When `true` (the v1.4i default), render a small
  /// legend row below the dot row showing what each color
  /// means. Set to `false` for a denser compact view.
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Semantics(
      label: l.homeTileSparklineSemantics,
      readOnly: true,
      child: FutureBuilder<List<SparklineDot>>(
        future: extendedSparklineForDo(
          activeDo: activeDo,
          asOf: asOf,
          completionLog: completionLog,
          days: days,
        ),
        builder: (context, snap) {
          final dots = snap.data;
          if (dots == null) {
            // Skeleton: 14 outlined tiny dots so the row
            // reserves its space while the DB read
            // resolves.
            return _SparklineSkeleton(days: days);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < dots.length; i++)
                      _SparklineDot(
                        dot: dots[i],
                        isToday: i == dots.length - 1,
                        isResolvedToday: resolvedToday,
                        filledColor: colorScheme.primary,
                        restDayColor: restDayColor ?? colorScheme.primary,
                        emptyColor: colorScheme.outline,
                        futureColor: colorScheme.outlineVariant,
                      ),
                  ],
                ),
              ),
              if (showLegend) ...[
                const SizedBox(height: 2),
                _SparklineLegend(
                  doneColor: colorScheme.primary,
                  restDayColor: restDayColor ?? colorScheme.primary,
                  emptyColor: colorScheme.outline,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A single 6dp dot in the sparkline. Filled when the
/// underlying day has at least one completion row,
/// outlined otherwise. Rest-day fills use [restDayColor]
/// (a visually distinct accent so the user can spot the
/// rest-day pattern at a glance). The today dot (last in
/// the row) bumps to 8dp + the resolved color when the
/// user has resolved today; otherwise it stays outlined
/// like any other day.
class _SparklineDot extends StatelessWidget {
  const _SparklineDot({
    required this.dot,
    required this.isToday,
    required this.isResolvedToday,
    required this.filledColor,
    required this.restDayColor,
    required this.emptyColor,
    required this.futureColor,
  });

  final SparklineDot dot;
  final bool isToday;
  final bool isResolvedToday;
  final Color filledColor;
  final Color restDayColor;
  final Color emptyColor;
  final Color futureColor;

  @override
  Widget build(BuildContext context) {
    final isFilled = dot is SparklineDotFilled;
    final isRestDay =
        isFilled && (dot as SparklineDotFilled).source == 'rest_day';
    final isFuture = dot is SparklineDotFuture;
    final Color color;
    if (isRestDay) {
      color = restDayColor;
    } else if (isFilled) {
      color = filledColor;
    } else if (isFuture) {
      color = futureColor;
    } else {
      color = emptyColor;
    }
    final todayFilled = isToday && isResolvedToday;
    final size = todayFilled ? 8.0 : 6.0;
    // The dot's *semantic* role (rest day / done / missed)
    // is announced by the parent sparkline `Semantics` node
    // + the legend row below. We intentionally do NOT wrap
    // each dot in a `Tooltip` widget because:
    //   1. 14 small dots × 3 localized messages = 42
    //      tooltip triggers competing for the user's
    //      pointer; this is worse than no tooltip.
    //   2. `Tooltip` installs an internal `GestureDetector`
    //      that intercepts long-press, which breaks the
    //      parent tile's onLongPress → select-mode entry
    //      (caught by the v1.4i widget test on main).
    // The legend row below provides the discoverability
    // for sighted users; the Semantics label carries the
    // a11y affordance for screen readers.
    return Semantics(
      label: isRestDay
          ? 'Rest day'
          : isFilled
          ? 'Done'
          : isFuture
          ? 'Future'
          : 'Missed',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: todayFilled || isFilled ? color : null,
            border: todayFilled || isFilled
                ? null
                : Border.all(color: color, width: 1.2),
          ),
        ),
      ),
    );
  }
}

/// The 14-day sparkline's legend row (v1.4i / SYS-123 /
/// ADR-053 / WF-050). Two colored swatches + a label,
/// rendered under the dot row so the user knows what each
/// color means.
///
/// "● done · ◐ rest day · ○ missed" — the three states the
/// dot can be in. The legend is semantic-only (no
/// interaction); the dots' tooltips carry the
/// per-dot affordance.
class _SparklineLegend extends StatelessWidget {
  const _SparklineLegend({
    required this.doneColor,
    required this.restDayColor,
    required this.emptyColor,
  });

  final Color doneColor;
  final Color restDayColor;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendSwatch(color: doneColor, filled: true),
        const SizedBox(width: 3),
        Text(l.homeTileSparklineLegendDone, style: textStyle),
        const SizedBox(width: 8),
        _LegendSwatch(color: restDayColor, filled: true),
        const SizedBox(width: 3),
        Text(l.homeTileSparklineLegendRestDay, style: textStyle),
        const SizedBox(width: 8),
        _LegendSwatch(color: emptyColor, filled: false),
        const SizedBox(width: 3),
        Text(l.homeTileSparklineLegendMissed, style: textStyle),
      ],
    );
  }
}

/// A 6dp circular swatch matching the dot vocabulary:
/// filled (matches the "done" or "rest day" look) or
/// outlined (matches the "missed" look).
class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color, required this.filled});
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : null,
        border: filled ? null : Border.all(color: color, width: 1.2),
      ),
    );
  }
}

/// Skeleton placeholder for the sparkline row while the
/// Drift read is in flight. Renders [days] outlined dots
/// so the row reserves its space and the layout does not
/// jump on resolve.
class _SparklineSkeleton extends StatelessWidget {
  const _SparklineSkeleton({this.days = 14});
  final int days;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < days; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: outline, width: 1.2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
