// v0.4a.3 firstLaunch persisted flag (SYS-059).
//
// Asserts that the `firstLaunchCompleted` flag in
// `SettingsService` is backed by `SharedPreferences` and
// survives an "app restart" — which in the test is modelled as
// resetting the singleton and re-running `init()` against a
// fresh `SharedPreferences` mock. The test also asserts the
// flag is `false` on a wiped install.

import 'package:doit/services/settings_service.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simulate a "wiped install": clears the persisted backing
/// store AND the in-memory state, then re-creates the gate.
Future<void> _wipedRestart() async {
  // Re-seed the mock with an empty store BEFORE the next init
  // reads it. This is the same call sites in `setUp` use.
  SharedPreferences.setMockInitialValues({});
  SettingsService.instance.resetForTesting();
}

/// Simulate an "app restart" without wiping the persisted
/// backing store. The in-memory singleton is reset (gate +
/// notifier go back to their defaults), but the next `init()`
/// reads the same `SharedPreferences` mock that the previous
/// `init()` wrote to. This is the canonical "survives a
/// restart" assertion: the data is on disk; the in-process
/// state is reconstructed from it.
Future<void> _appRestart() async {
  // We need the gate to be re-entrant so `init()` can run a
  // second time. `resetForTesting` re-creates the Completer
  // and resets the notifier, but does NOT touch the
  // SharedPreferences mock — the next `init()` will re-read
  // the same store the previous write hit.
  SettingsService.instance.resetForTesting();
}

void main() {
  group('SettingsService.firstLaunchCompleted (SYS-059)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('is false on a wiped install (default)', () async {
      await SettingsService.instance.init();
      expect(
        SettingsService.instance.firstLaunchCompleted.value,
        isFalse,
        reason:
            'A wiped install must report the onboarding flow as not-yet-completed',
      );
    });

    test('markFirstLaunchCompleted flips the notifier and persists', () async {
      await SettingsService.instance.init();
      // Step out of the fake-async zone for the real
      // SharedPreferences write.
      await Future<void>.delayed(Duration.zero);
      await SettingsService.instance.markFirstLaunchCompleted();
      await Future<void>.delayed(Duration.zero);
      expect(
        SettingsService.instance.firstLaunchCompleted.value,
        isTrue,
        reason:
            '`markFirstLaunchCompleted` must update the in-memory notifier synchronously',
      );

      // Survive a "restart" — same on-disk prefs, fresh
      // in-memory state. The flag should still be `true` after
      // the next init().
      await _appRestart();
      await SettingsService.instance.init();
      await Future<void>.delayed(Duration.zero);
      expect(
        SettingsService.instance.firstLaunchCompleted.value,
        isTrue,
        reason: 'The flag must persist across an app restart (reset + re-init)',
      );
    });

    test(
      'wiped install: re-seed empty prefs brings the flag back to false',
      () async {
        // Set the flag, then simulate a wiped install (empty
        // prefs + reset), then re-init: flag is back to false.
        // This is the contract the fresh-install widget test
        // relies on.
        await SettingsService.instance.init();
        await Future<void>.delayed(Duration.zero);
        await SettingsService.instance.markFirstLaunchCompleted();
        await Future<void>.delayed(Duration.zero);
        expect(SettingsService.instance.firstLaunchCompleted.value, isTrue);

        await _wipedRestart();
        await SettingsService.instance.init();
        await Future<void>.delayed(Duration.zero);
        expect(
          SettingsService.instance.firstLaunchCompleted.value,
          isFalse,
          reason:
              'A wiped install (empty prefs) must report the flag as not-yet-completed',
        );
      },
    );

    test('init is idempotent across repeated calls', () async {
      await SettingsService.instance.init();
      await Future<void>.delayed(Duration.zero);
      await SettingsService.instance.init();
      // The init is a no-op the second time; the flag stays at
      // its loaded value.
      expect(SettingsService.instance.firstLaunchCompleted.value, isFalse);
    });

    test('ready gate resolves after init', () async {
      // `ready` must complete once `init()` returns.
      final future = SettingsService.instance.ready;
      await SettingsService.instance.init();
      await expectLater(future, completes);
    });

    test('markFirstLaunchCompleted waits for the gate', () async {
      // A widget that calls `markFirstLaunchCompleted` before
      // `init()` must still get the right value — the gate
      // ensures the read-modify-write happens against the
      // loaded prefs, not a fresh empty store.
      final future = SettingsService.instance.markFirstLaunchCompleted();
      await SettingsService.instance.init();
      await future;
      expect(SettingsService.instance.firstLaunchCompleted.value, isTrue);
    });
  });

  group('SettingsService — untouched v0.1 behavior', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('themeMode defaults to dark', () {
      expect(
        SettingsService.instance.themeMode.value,
        ThemeMode.dark,
        reason: 'v0.1 dark-default must be preserved',
      );
    });
  });
}
