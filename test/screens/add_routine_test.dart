// Tests for AddRoutineScreen (v1.0 / Phase F PR 2 /
// SYS-075 / ADR-019 follow-up).
//
// Coverage:
//   - The form is pre-filled with the persisted
//     JapanRoutineConfig (when the config has contacts and a
//     non-default target mode).
//   - The Enable toggle updates widget state.
//   - The target-mode radio updates widget state.
//   - Tapping a contact row's remove IconButton drops it
//     from the picked list (regression-tested separately so
//     the onRemove callback path stays covered).
//   - Save (a) persists via `SettingsService.setJapanRoutine`,
//     (b) pushes the contact list to
//     `CallInterceptorService.configure(...)`, and (c) pops
//     the screen.
//   - When `CallInterceptorService.configure` throws, the
//     screen surfaces an inline error and does NOT pop. The
//     user can retry.
//
// The target-mode radio's `groupValue` is read here through
// the persisted config after Save (a behavioral check) rather
// than via the deprecated `RadioListTile.groupValue` field
// (deprecated in Flutter 3.32 in favor of the `RadioGroup`
// ancestor). The contact-picker path is exercised by
// `add_person_test.dart`; AddRoutineScreen reuses the same
// `flutter_contacts` + `PermissionSheet.show` seam.

import 'package:doit/screens/add_routine.dart';
import 'package:doit/services/call_interceptor.dart';
import 'package:doit/services/japan_routine_config.dart';
import 'package:doit/services/settings_service.dart';
import 'package:doit/triggers/trigger.dart' show SilentMode;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ScriptedCallSource> _setUpAppState({
  JapanRoutineConfig? initial,
  ScriptedCallSource? source,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  SettingsService.instance.resetForTesting();
  await SettingsService.instance.init();
  if (initial != null) {
    await SettingsService.instance.setJapanRoutine(initial);
  }
  // Reset the call interceptor between tests so each test
  // gets a fresh ScriptedCallSource. Always wire a
  // ScriptedCallSource (default) — using the production
  // `_MethodChannelCallSource` keeps the broadcast
  // `events` stream subscription alive and the test
  // framework hangs awaiting it.
  CallInterceptorService.instance.resetForTesting();
  final src = source ?? ScriptedCallSource();
  CallInterceptorService.instance.debugSetSource(src);
  await CallInterceptorService.instance.init();
  return src;
}

/// Use a phone-sized viewport so the screen's content
/// (long ListView with the Save button at the bottom) fits
/// without needing to scroll.
void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    SettingsService.instance.resetForTesting();
    CallInterceptorService.instance.resetForTesting();
  });

  testWidgets(
    'the screen renders the persisted contact + Enable switch pre-filled',
    (tester) async {
      _setPhoneSize(tester);
      await _setUpAppState(
        initial: const JapanRoutineConfig(
          enabled: true,
          contactIds: <String>['+15551112222'],
          targetMode: SilentMode.vibrate,
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: AddRoutineScreen()));
      await tester.pump();

      // The persisted contact is rendered as a row
      // (name + subtitle both carry the same phone number
      // when the contact was seeded without a display
      // name; we use `findsNWidgets(2)` rather than
      // `findsOneWidget` to match that behavior).
      expect(find.text('+15551112222'), findsNWidgets(2));

      // The Enable switch is on.
      final enableSwitch = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('add_routine.enabled')),
      );
      expect(enableSwitch.value, true);

      // The three target-mode radio tiles are present (one
      // per SilentMode). The selected one is the
      // persisted `vibrate` — we exercise the behavioral
      // path in the next test instead of reading the
      // deprecated `groupValue` field directly.
      expect(
        find.byKey(const ValueKey('add_routine.target_mode.normal')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('add_routine.target_mode.vibrate')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('add_routine.target_mode.silent')),
        findsOneWidget,
      );
    },
  );

  testWidgets('tapping Enable flips the switch state', (tester) async {
    _setPhoneSize(tester);
    await _setUpAppState();
    await tester.pumpWidget(const MaterialApp(home: AddRoutineScreen()));
    await tester.pump();

    final before = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('add_routine.enabled')),
    );
    expect(before.value, false);

    await tester.tap(find.byKey(const ValueKey('add_routine.enabled')));
    await tester.pump();

    final after = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('add_routine.enabled')),
    );
    expect(after.value, true);
  });

  testWidgets(
    'selecting a different target mode updates the persisted config',
    (tester) async {
      _setPhoneSize(tester);
      await _setUpAppState();
      await tester.pumpWidget(const MaterialApp(home: AddRoutineScreen()));
      await tester.pump();

      // Default is `normal`; tap `silent` then save to verify
      // the radio's onChanged path is wired and the new
      // mode is persisted to SettingsService.
      await tester.tap(
        find.byKey(const ValueKey('add_routine.target_mode.silent')),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('add_routine.save')));
      await tester.pumpAndSettle();

      // The persisted notifier reflects the new target mode.
      final saved = SettingsService.instance.japanRoutine.value;
      expect(saved.targetMode, SilentMode.silent);
      // The screen popped.
      expect(find.byType(AddRoutineScreen), findsNothing);
    },
  );

  testWidgets('Save persists the config and pushes to CallInterceptorService', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final source = await _setUpAppState();
    await tester.pumpWidget(const MaterialApp(home: AddRoutineScreen()));
    await tester.pump();

    // Toggle Enable on.
    await tester.tap(find.byKey(const ValueKey('add_routine.enabled')));
    await tester.pump();

    // Pick vibrate target mode.
    await tester.tap(
      find.byKey(const ValueKey('add_routine.target_mode.vibrate')),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('add_routine.save')));
    await tester.pumpAndSettle();

    // Persistence — in-memory notifier.
    final saved = SettingsService.instance.japanRoutine.value;
    expect(saved.enabled, true);
    expect(saved.targetMode, SilentMode.vibrate);
    expect(saved.contactIds, isEmpty);

    // The contact list (empty in this test) is pushed to
    // the call interceptor with the new `enabled` value.
    expect(source.lastEnabled, true);
    expect(source.lastContactIds, <String>[]);

    // The screen pops on success.
    expect(find.byType(AddRoutineScreen), findsNothing);
  });

  testWidgets(
    'tapping a contact row\'s remove IconButton drops it from the picked '
    'list',
    (tester) async {
      _setPhoneSize(tester);
      // Seed the screen with TWO contacts so we can drop
      // the first one and assert the second survives.
      await _setUpAppState(
        initial: const JapanRoutineConfig(
          enabled: true,
          contactIds: <String>['+15551112222', '+15553334444'],
          targetMode: SilentMode.vibrate,
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: AddRoutineScreen()));
      await tester.pump();

      // Both contacts are rendered.
      expect(
        find.byKey(const ValueKey('add_routine.contact.0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('add_routine.contact.1')),
        findsOneWidget,
      );

      // Tap the remove IconButton on the first contact.
      await tester.tap(
        find.byKey(const ValueKey('add_routine.contact.0.remove')),
      );
      await tester.pump();

      // The first row is gone; the second row has shifted
      // to index 0 (the list rebuilt around the removal).
      expect(
        find.byKey(const ValueKey('add_routine.contact.0')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('add_routine.contact.1')), findsNothing);
      // The surviving contact's number is now on the
      // (single) remaining row.
      expect(find.text('+15553334444'), findsWidgets);

      // Save + verify the persisted config reflects the
      // trimmed contact list (the regression-tested branch
      // is `_picked.map((c) => c.phone)` in `_save`).
      await tester.tap(find.byKey(const ValueKey('add_routine.save')));
      await tester.pumpAndSettle();

      final saved = SettingsService.instance.japanRoutine.value;
      expect(saved.contactIds, <String>['+15553334444']);
    },
  );

  testWidgets(
    'a failure in CallInterceptorService.configure surfaces an inline error '
    'and the screen does NOT pop',
    (tester) async {
      _setPhoneSize(tester);
      // Use a source that throws on setEnabled so the
      // catch block in `_save` triggers and the inline
      // error is rendered. The screen should NOT pop on
      // failure — the user must be able to retry.
      final throwing = _ThrowingScriptedCallSource();
      await _setUpAppState(source: throwing);
      await tester.pumpWidget(const MaterialApp(home: AddRoutineScreen()));
      await tester.pump();

      // Toggle Enable on so configure() fires.
      await tester.tap(find.byKey(const ValueKey('add_routine.enabled')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('add_routine.save')));
      // Allow the awaited configure() call to fail and the
      // setState in the catch block to land.
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();

      // The error is shown.
      expect(find.byKey(const ValueKey('add_routine.error')), findsOneWidget);
      // The screen did NOT pop — the user can retry.
      expect(find.byType(AddRoutineScreen), findsOneWidget);
    },
  );
}

/// `ScriptedCallSource` that throws from `setEnabled` so
/// the catch path in `AddRoutineScreen._save` is exercised
/// without spinning up the production method-channel source.
class _ThrowingScriptedCallSource extends ScriptedCallSource {
  _ThrowingScriptedCallSource();

  @override
  Future<void> setEnabled(bool enabled) async {
    throw StateError('simulated platform-channel failure');
  }
}
