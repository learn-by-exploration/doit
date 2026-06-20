// CalendarPicker — modal bottom sheet that builds an
// [Automation] with one of the four `TriggerCalendarEvent`
// leaves (`TriggerCalendarEventStart` / `End` / `Reminder` /
// `TriggerFreeBusy`) and a default [ActionNotify] for the
// entity the user is editing.
//
// Per v1.0 Phase E PR 2 / ADR-023 / SYS-074:
//   - Read-only calendar access (`READ_CALENDAR` only; no
//     event write). The picker never creates events; it just
//     watches the user's existing ones.
//   - The four leaves are exposed as a radio group:
//     "Event start" (default), "Event end", "Reminder",
//     "Free/busy change".
//   - The user picks a calendar account from the dropdown
//     populated by `CalendarService.listAccounts()`. An
//     "Any calendar" option maps to an empty `calendarId`
//     (the executor's `_calendarMatches` predicate treats an
//     empty `trigger.calendarId` as "match any calendar").
//   - Optional `eventTitle` filter — exact match. Empty = any
//     title.
//   - The sheet gates on `Permission.calendar` via the
//     shared `PermissionSheet` (SYS-067 / ADR-014) before
//     any platform call.
//
// The returned [Automation] has:
//   - `trigger`: One of the four `TriggerCalendarEvent`
//     leaves, carrying the picked `calendarId` (or '' for
//     any) and the optional `eventTitle` filter.
//   - `action`:  ActionNotify(title, body) — the title is
//     derived from the trigger label by the caller; this
//     widget does not know the entity name, so it uses the
//     label as both the trigger label and the notification
//     body. Same convention as `LocationPicker`.
//   - `enabled`: true
//
// Pure-Dart validation: label non-empty, calendar account
// selected (or "Any" explicit). Validation errors surface
// inline; the "Save" button is gated on a clean form.

import 'package:flutter/material.dart';

import 'package:doit/routines/routine.dart';
import 'package:doit/services/calendar_service.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:doit/widgets/permission_sheet.dart';

/// The four calendar trigger kinds the picker can build.
/// Mirrors the four `TriggerCalendarEvent` leaves.
enum _CalendarEventKind {
  start,
  end,
  reminder,
  freeBusy;

  String get label => switch (this) {
    _CalendarEventKind.start => 'Event start',
    _CalendarEventKind.end => 'Event end',
    _CalendarEventKind.reminder => 'Reminder',
    _CalendarEventKind.freeBusy => 'Free/busy change',
  };
}

/// Static facade. Mirrors the `PermissionSheet.show(...)`
/// pattern (lib/widgets/permission_sheet.dart) and the
/// `LocationPicker.show(...)` pattern
/// (lib/widgets/location_picker.dart). Callers do:
/// ```
/// final auto = await CalendarPicker.show(context);
/// if (auto != null) setState(() => _automations.add(auto));
/// ```
class CalendarPicker {
  const CalendarPicker._();

  /// Show the sheet. Returns:
  ///   - `Automation` on a successful save.
  ///   - `null` if the user cancels, dismisses the sheet,
  ///     denies the permission gate, or fails validation
  ///     after re-entry.
  static Future<Automation?> show(BuildContext context) async {
    // Gate on `READ_CALENDAR`. The on-demand sheet is the
    // only seam for runtime permission requests in v1.0
    // (lib-screens.md / ADR-014). We do NOT call
    // `Permission.calendarFullAccess.request()` directly —
    // the gate is the single place where the rationale +
    // system dialog surface.
    final granted = await PermissionSheet.show(
      context,
      PermissionKind.calendar,
    );
    if (!granted) return null;
    if (!context.mounted) return null;
    return showModalBottomSheet<Automation>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _CalendarPickerSheet(),
    );
  }
}

class _CalendarPickerSheet extends StatefulWidget {
  const _CalendarPickerSheet();

  @override
  State<_CalendarPickerSheet> createState() => _CalendarPickerSheetState();
}

class _CalendarPickerSheetState extends State<_CalendarPickerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  _CalendarEventKind _kind = _CalendarEventKind.start;

  /// Sentinel: an empty account id = "Any calendar". This
  /// matches the executor's `_calendarMatches` predicate.
  String? _accountId;

  /// Cached list of installed calendar accounts. `null` =
  /// "not yet loaded" (the user has not tapped "Refresh").
  List<CalendarAccount>? _accounts;
  bool _busyAccounts = false;
  String? _accountsError;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshAccounts() async {
    setState(() {
      _busyAccounts = true;
      _accountsError = null;
    });
    try {
      final accounts = await CalendarService.instance.listAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _busyAccounts = false;
        // Default to "any" if the user has no preference yet
        // and there is at least one account; leave as "any"
        // otherwise (an empty account list lets the user
        // still save a "match any calendar" trigger).
        if (_accountId == null && accounts.isNotEmpty) {
          _accountId = '';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accountsError = 'Could not load calendars: $e';
        _busyAccounts = false;
      });
    }
  }

  void _save() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final label = _labelCtrl.text.trim();
    final title = _titleCtrl.text.trim();
    final calId = _accountId ?? '';
    final trigger = switch (_kind) {
      _CalendarEventKind.start => TriggerCalendarEventStart(
        calendarId: calId,
        eventTitle: title,
      ),
      _CalendarEventKind.end => TriggerCalendarEventEnd(
        calendarId: calId,
        eventTitle: title,
      ),
      _CalendarEventKind.reminder => TriggerCalendarReminder(
        calendarId: calId,
        eventTitle: title,
      ),
      _CalendarEventKind.freeBusy => TriggerFreeBusy(
        calendarId: calId,
        eventTitle: title,
      ),
    };
    final automation = Automation(
      trigger: trigger,
      action: ActionNotify(title: label, body: 'Routine fired: $label'),
    );
    Navigator.of(context).pop(automation);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;
    final accounts = _accounts ?? const <CalendarAccount>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.md,
        Spacing.md + viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Calendar trigger', style: theme.textTheme.titleLarge),
              const SizedBox(height: Spacing.xs),
              Text(
                'Fire when a calendar event on this account starts, '
                'ends, hits its reminder, or changes your busy '
                'status. Read-only — your calendar is never modified.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: Spacing.md),
              TextFormField(
                key: const ValueKey('calendar_picker.label'),
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'Work, Personal, Family…',
                ),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: Spacing.sm),
              TextFormField(
                key: const ValueKey('calendar_picker.title_filter'),
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Event title filter (optional)',
                  hintText: 'Leave blank to match any title',
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: Spacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Calendar account',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('calendar_picker.refresh'),
                    onPressed: _busyAccounts ? null : _refreshAccounts,
                    icon: _busyAccounts
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.xs),
              if (_accounts == null)
                Text(
                  'Tap Refresh to load your installed calendars.',
                  style: theme.textTheme.bodySmall,
                )
              else if (accounts.isEmpty)
                Text(
                  'No calendar accounts found on this device.',
                  style: theme.textTheme.bodySmall,
                )
              else
                DropdownButtonFormField<String>(
                  key: const ValueKey('calendar_picker.account'),
                  initialValue: _accountId ?? '',
                  decoration: const InputDecoration(labelText: 'Account'),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Any calendar'),
                    ),
                    for (final a in accounts)
                      DropdownMenuItem<String>(
                        value: a.accountId,
                        child: Text(a.displayName),
                      ),
                  ],
                  onChanged: (v) => setState(() => _accountId = v),
                ),
              if (_accountsError != null) ...[
                const SizedBox(height: Spacing.xs),
                Text(
                  _accountsError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: Spacing.md),
              Text('Event', style: theme.textTheme.bodyMedium),
              RadioGroup<_CalendarEventKind>(
                groupValue: _kind,
                onChanged: (v) {
                  if (v != null) setState(() => _kind = v);
                },
                child: const Column(
                  children: [
                    RadioListTile<_CalendarEventKind>(
                      key: ValueKey('calendar_picker.kind_start'),
                      title: Text('Event start'),
                      value: _CalendarEventKind.start,
                    ),
                    RadioListTile<_CalendarEventKind>(
                      key: ValueKey('calendar_picker.kind_end'),
                      title: Text('Event end'),
                      value: _CalendarEventKind.end,
                    ),
                    RadioListTile<_CalendarEventKind>(
                      key: ValueKey('calendar_picker.kind_reminder'),
                      title: Text('Reminder'),
                      value: _CalendarEventKind.reminder,
                    ),
                    RadioListTile<_CalendarEventKind>(
                      key: ValueKey('calendar_picker.kind_freebusy'),
                      title: Text('Free/busy change'),
                      value: _CalendarEventKind.freeBusy,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const ValueKey('calendar_picker.cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Spacing.sm),
                  FilledButton(
                    key: const ValueKey('calendar_picker.save'),
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
