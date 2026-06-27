// Shared rest-day budget picker dialog (v1.4j / Phase 37 / SYS-124 /
// ADR-054 / WF-051).
//
// `showRestDayPicker(...)` is the single source of truth for picking
// `restDaysPerMonth` (0..31). Used from two surfaces:
//
// 1. The in-app home tile — tapping the budget caption under the
//    streak badge opens this dialog and writes the picked value to
//    `DoRepository` via `_HabitTileState._onBudgetCaptionTapped`
//    in `lib/screens/home.dart`.
// 2. The AddHabitScreen — tapping the "Rest days per month: N" form
//    row opens this dialog and updates `_restDaysPerMonth` state
//    field via `AddHabitScreenState._pickRestDaysPerMonth()` in
//    `lib/screens/add_habit.dart`. Closes the v1.0 silent-reset bug
//    where the value was hardcoded to 2 in all 5 switch branches of
//    `_save()` and never exposed as a form input.
//
// Range: 0..31 (matches the month day count; a month has at most 31
// days so the upper bound 31 covers "every day is a rest day" without
// the off-by-one error of letting the user pick 32).
//
// `Do.validate()` at `lib/do/do.dart:280-308` is the second-line
// defensive check (it also enforces `restDaysPerMonth <= 31`) — the
// slider clamps inline, but validate is the single source of truth
// for invariants and is what would catch a programmatic write.

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// The integer range of valid rest-day budgets. Exposed as a constant
/// so callers (tests, models) can reference the same upper bound that
/// the slider enforces.
const int kRestDaysPerMonthMin = 0;
const int kRestDaysPerMonthMax = 31;

/// Opens the shared rest-day budget picker dialog.
///
/// Returns the picked integer (`kRestDaysPerMonthMin..kRestDaysPerMonthMax`)
/// on Save, or `null` on Cancel/dismiss. `initial` is clamped to the
/// valid range before the dialog opens so an out-of-range value from
/// a stale row does not crash the slider.
Future<int?> showRestDayPicker(BuildContext context, {required int initial}) {
  return showDialog<int>(
    context: context,
    builder: (_) => RestDayPickerDialog(initial: initial),
  );
}

/// `StatefulWidget` so the slider's local value (`_value`) is mutable
/// during drag without rebuilding the parent. The dialog is an
/// `AlertDialog` with the standard Material slider + Save/Cancel
/// action row.
class RestDayPickerDialog extends StatefulWidget {
  const RestDayPickerDialog({super.key, required this.initial});

  /// Clamped to `[kRestDaysPerMonthMin, kRestDaysPerMonthMax]` before
  /// the dialog renders.
  final int initial;

  @override
  State<RestDayPickerDialog> createState() => _RestDayPickerDialogState();
}

class _RestDayPickerDialogState extends State<RestDayPickerDialog> {
  late int _value;

  @override
  void initState() {
    super.initState();
    // Clamp the initial value so a stale DB row (e.g. a future
    // migration bump that lowers the upper bound) cannot crash the
    // slider.
    _value = widget.initial.clamp(kRestDaysPerMonthMin, kRestDaysPerMonthMax);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.homeTileBudgetEditTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.homeTileBudgetEditDescription),
          const SizedBox(height: 16),
          // The label reads "$_value" so the user sees the live
          // integer above the slider. divisions: 31 snaps the slider
          // to integer values (no fractional positions).
          Text(
            '$_value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          Slider(
            min: kRestDaysPerMonthMin.toDouble(),
            max: kRestDaysPerMonthMax.toDouble(),
            divisions: kRestDaysPerMonthMax - kRestDaysPerMonthMin,
            value: _value.toDouble(),
            label: '$_value',
            onChanged: (v) => setState(() => _value = v.round()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.homeTileBudgetEditCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_value),
          child: Text(l.homeTileBudgetEditOk),
        ),
      ],
    );
  }
}
