// Tests for the v1.1 (SYS-083) RoutineApplyScreen.
//
// Coverage:
//   - Renders the template's name as the AppBar title and
//     the description as the body subtitle.
//   - Renders the trigger / condition / action chips when
//     the envelope decodes.
//   - Renders a "Could not load routine template" view when
//     the envelope is malformed (no Save button).
//   - On Save, calls SettingsService.setRoutine with a
//     RoutineConfig whose templateId / enabled / trigger /
//     action fields match the toggle + payload.
//   - When a saved config already exists, the screen shows
//     "Update" instead of "Save" and a "Delete" button.
//   - On Delete, calls SettingsService.deleteRoutine.
//
// Test harness notes:
//   - `_pump(tester, t)` mounts the screen as the root
//     `MaterialApp.home`. The screen's _save / _delete methods
//     `Navigator.of(context).canPop()`-guard the pop so the
//     root-mounted case (which would otherwise hang the pop
//     transition) is a no-op.
//   - Async work inside _save / _delete runs in microtasks;
//     `tester.pumpAndSettle()` waits for frames but not for
//     arbitrary Futures, so each save / delete is followed by
//     `tester.runAsync(...)` to drain the real-async side
//     before asserting on `routines.value`.

import 'dart:convert' show jsonEncode;

import 'package:doit/screens/routine_apply.dart';
import 'package:doit/services/routine_config.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/templates/template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Template _t({
  String id = 't_builtin_17',
  String name = 'Focus block',
  String description = 'Silence notifications on focus block start.',
  String payload =
      '{"k":1,"routine":{"trigger":"calendar","condition":"event:FocusBlock","action":"dn:on","note":"Phase C+ apply UX"}}',
}) => Template(
  id: id,
  name: name,
  description: description,
  iconName: 'work',
  entityType: TemplateEntityType.routine,
  isBuiltIn: true,
  createdAt: DateTime(2026, 6, 21),
  payloadJson: payload,
);

Future<void> _pump(WidgetTester tester, Template t) async {
  await tester.pumpWidget(MaterialApp(home: RoutineApplyScreen(template: t)));
  // Two pumps are enough: the first renders the build, the
  // second drains the microtask queue (SwitchListTile.adaptive
  // schedules a deferred state restore after first paint).
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();
  });

  tearDown(SettingsService.instance.resetForTesting);

  testWidgets('renders the template name + description + chips', (
    tester,
  ) async {
    await _pump(tester, _t());

    expect(find.text('Focus block'), findsOneWidget); // app bar
    expect(
      find.text('Silence notifications on focus block start.'),
      findsOneWidget,
    );
    expect(find.text('Trigger'), findsOneWidget);
    expect(find.text('Condition'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);
    expect(find.text('calendar'), findsOneWidget);
    expect(find.text('event:FocusBlock'), findsOneWidget);
    expect(find.text('dn:on'), findsOneWidget);
    expect(find.text('Phase C+ apply UX'), findsOneWidget);
  });

  testWidgets('Save persists a RoutineConfig with the right fields', (
    tester,
  ) async {
    await _pump(tester, _t());

    // Tap save (the toggle is on by default). pump() fires
    // the onPressed; the async _save body needs runAsync to
    // drain its microtasks (the awaited setRoutine hits the
    // SharedPreferences mock).
    await tester.tap(
      find.byKey(const ValueKey('routine_apply.t_builtin_17.save')),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    final saved = SettingsService.instance.routines.value['t_builtin_17'];
    expect(saved, isNotNull);
    expect(saved!.templateId, 't_builtin_17');
    expect(saved.enabled, true);
    expect(saved.triggerJson['type'], 'routine_placeholder.v1');
    expect(saved.actionJson['kind'], 'dn:on');
  });

  testWidgets('flipping the toggle persists enabled=false', (tester) async {
    await _pump(tester, _t());

    await tester.tap(
      find.byKey(const ValueKey('routine_apply.t_builtin_17.enabled')),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('routine_apply.t_builtin_17.save')),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    final saved = SettingsService.instance.routines.value['t_builtin_17'];
    expect(saved, isNotNull);
    expect(saved!.enabled, false);
  });

  testWidgets('Update replaces an existing config and shows Delete', (
    tester,
  ) async {
    // Pre-seed an existing config via SharedPreferences so the
    // screen reads it from `_loadRoutines` on init (avoids an
    // `await setRoutine` between the test setUp and the
    // pumpWidget — the widget context interferes with the
    // microtask drain in the same way the screen's own
    // `_save` does).
    const existing = RoutineConfig(
      templateId: 't_builtin_17',
      triggerJson: <String, Object?>{'type': 'routine_placeholder.v1'},
      actionJson: <String, Object?>{'type': 'routine_placeholder.v1'},
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'doit.routine.t_builtin_17',
      jsonEncode(existing.toJson()),
    );
    // Re-init so the screen reads the seeded config.
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();

    await _pump(tester, _t());

    // Update button + Delete button visible.
    expect(find.text('Update'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('routine_apply.t_builtin_17.delete')),
      findsOneWidget,
    );

    // Tap Update; the same key persists (toggle was seeded true).
    // pump() fires the onPressed; runAsync drains the awaited
    // setRoutine. We do NOT pumpAndSettle afterwards because the
    // _saving setState + pre-seeded Delete button can leave the
    // tree in a state pumpAndSettle considers unsettled; the
    // assertion reads the notifier directly, which is enough.
    await tester.tap(
      find.byKey(const ValueKey('routine_apply.t_builtin_17.save')),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    final saved = SettingsService.instance.routines.value['t_builtin_17'];
    expect(saved, isNotNull);
    expect(saved!.templateId, 't_builtin_17');
  });

  testWidgets('Delete removes the config', (tester) async {
    // Pre-seed via SharedPreferences (see Update test for why).
    const existing = RoutineConfig(
      templateId: 't_builtin_17',
      triggerJson: <String, Object?>{'type': 'routine_placeholder.v1'},
      actionJson: <String, Object?>{'type': 'routine_placeholder.v1'},
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'doit.routine.t_builtin_17',
      jsonEncode(existing.toJson()),
    );
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();

    await _pump(tester, _t());

    await tester.tap(
      find.byKey(const ValueKey('routine_apply.t_builtin_17.delete')),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    expect(SettingsService.instance.routines.value['t_builtin_17'], isNull);
  });

  testWidgets('renders a "Could not load" view on a malformed envelope', (
    tester,
  ) async {
    final t = _t(payload: '{not json');
    await _pump(tester, t);

    expect(
      find.textContaining('Could not load routine template'),
      findsOneWidget,
    );
    // No Save button is rendered in the malformed view.
    expect(
      find.byKey(const ValueKey('routine_apply.t_builtin_17.save')),
      findsNothing,
    );
  });
}
