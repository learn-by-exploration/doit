// RoutineApplyScreen — generic apply UX for the five
// template-driven routines (templates #17..#21, v1.1 /
// SYS-083).
//
// Per the v1.0 sign-off's "out of scope" list, only the
// Japan template (#16) had a real apply screen; the other
// five routines showed a "Coming in v1.1" badge. v1.1d
// lands the generic screen that:
//
//   1. Decodes the template's `payloadJson` envelope via
//      [RoutineTemplatePayload.fromTemplate] (fail-soft — a
//      malformed envelope surfaces a "could not load" view
//      instead of crashing).
//   2. Shows the template's name + description + decoded
//      trigger / condition / action placeholders as
//      read-only chips. v1.1e replaces the chips with real
//      per-template picker UIs; v1.1d is the scaffolding
//      that makes "Save" persist a [RoutineConfig] under
//      `doit.routine.<templateId>`.
//   3. Has an enable toggle. The toggle's value seeds
//      [RoutineConfig.enabled] on Save.
//   4. On Save, calls [SettingsService.setRoutine] and pops.
//   5. If a saved config already exists for this template,
//      the screen is edit-friendly: the toggle seeds from
//      the saved value, and a "Delete" button removes the
//      config via [SettingsService.deleteRoutine].
//
// The screen does NOT register the routine with the
// [RoutineExecutor] directly — the executor is the
// non-Flutter singleton (per `.claude/rules/lib-routines.md`)
// and consumes [SettingsService.routines] reactively in a
// future PR. v1.1d's scope is the persistence path.

import 'package:flutter/material.dart';

import 'package:doit/routines/routine_template_payload.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/templates/template.dart';
import 'package:doit/theme/app_theme.dart';

class RoutineApplyScreen extends StatefulWidget {
  const RoutineApplyScreen({super.key, required this.template});

  final Template template;

  @override
  State<RoutineApplyScreen> createState() => _RoutineApplyScreenState();
}

class _RoutineApplyScreenState extends State<RoutineApplyScreen> {
  late bool _enabled;
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Seed the enable toggle from any prior save. The screen
    // is edit-friendly on second-and-later visits: the user
    // can flip the toggle, replace the config (Save), or
    // wipe it (Delete).
    final existing =
        SettingsService.instance.routines.value[widget.template.id];
    _enabled = existing?.enabled ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final payload = RoutineTemplatePayload.fromTemplate(widget.template);
    final existing =
        SettingsService.instance.routines.value[widget.template.id];
    return Scaffold(
      appBar: AppBar(title: Text(widget.template.name)),
      body: SafeArea(
        child: payload == null
            ? _MalformedView(templateId: widget.template.id)
            : ListView(
                padding: const EdgeInsets.all(Spacing.md),
                children: [
                  Text(
                    widget.template.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Spacing.md),
                  SwitchListTile.adaptive(
                    key: ValueKey(
                      'routine_apply.${widget.template.id}.enabled',
                    ),
                    title: const Text('Enable routine'),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Configuration',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: Spacing.sm),
                  _Chip(label: 'Trigger', value: payload.trigger),
                  const SizedBox(height: Spacing.xs),
                  _Chip(
                    label: 'Condition',
                    value: payload.condition.isEmpty
                        ? '(no condition)'
                        : payload.condition,
                  ),
                  const SizedBox(height: Spacing.xs),
                  _Chip(label: 'Action', value: payload.action),
                  if (payload.note.isNotEmpty) ...[
                    const SizedBox(height: Spacing.md),
                    Text(
                      payload.note,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: Spacing.lg),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: Text(
                        _error!,
                        key: ValueKey(
                          'routine_apply.${widget.template.id}.error',
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton(
                    key: ValueKey('routine_apply.${widget.template.id}.save'),
                    onPressed: _saving ? null : _save,
                    child: Text(existing == null ? 'Save' : 'Update'),
                  ),
                  if (existing != null) ...[
                    const SizedBox(height: Spacing.sm),
                    FilledButton.tonal(
                      key: ValueKey(
                        'routine_apply.${widget.template.id}.delete',
                      ),
                      onPressed: _deleting ? null : _delete,
                      child: const Text('Delete'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Future<void> _save() async {
    final payload = RoutineTemplatePayload.fromTemplate(widget.template);
    if (payload == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SettingsService.instance.setRoutine(
        payload.toRoutineConfig(enabled: _enabled),
      );
      if (!mounted) return;
      // `canPop` guards against the screen being mounted at
      // the navigator root (e.g. in tests that place it as
      // `MaterialApp.home`); in production the templates
      // catalog always pushes us, so `canPop` is true.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Save failed: $e';
      });
    }
  }

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await SettingsService.instance.deleteRoutine(widget.template.id);
      if (!mounted) return;
      // See `_save` — `canPop` guards the root-mounted case.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = 'Delete failed: $e';
      });
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('routine_apply.chip.$label'),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _MalformedView extends StatelessWidget {
  const _MalformedView({required this.templateId});
  final String templateId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: Sizing.huge,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'Could not load routine template $templateId.',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'The template payload is malformed. Re-install the app or '
              'pick a different template.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
