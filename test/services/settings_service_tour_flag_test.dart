// Tests for the post-onboarding coach-mark tour flag in
// SettingsService (v1.8-pr-b / SYS-191 / ADR-122 / WF-118).
//
// The `tourSeen` flag is a per-install boolean that suppresses
// the "Show me around" CTA on the home empty state once the
// user has completed the tour at least once. The flag is
// persisted under `doit.tour.seen` and survives
// `resetForTesting()` + re-`init()` (an app restart).
//
// These tests pin:
//   1. The default value is `false` (a fresh install has not
//      seen the tour yet, so the CTA renders).
//   2. `markTourSeen()` updates the in-memory notifier AND
//      persists the boolean to SharedPreferences.
//   3. A subsequent `resetForTesting()` + re-`init()` re-loads
//      the persisted flag — i.e. persistence survives a
//      restart.
//   4. `resetForTesting()` clears the notifier back to `false`.

import 'package:doit/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();
  });

  tearDown(SettingsService.instance.resetForTesting);

  test('tourSeen defaults to false on a fresh install', () {
    expect(
      SettingsService.instance.tourSeen.value,
      false,
      reason:
          'A fresh SettingsService must report tourSeen=false so the home '
          'empty state surfaces the "Show me around" CTA. The flag flips '
          'to true the first time the user finishes (or skips) the tour.',
    );
  });

  test('markTourSeen updates the notifier AND persists to '
      'SharedPreferences', () async {
    await SettingsService.instance.markTourSeen();

    // In-memory notifier reflects the new value.
    expect(SettingsService.instance.tourSeen.value, isTrue);

    // SharedPreferences has the key.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('doit.tour.seen'), isTrue);
  });

  test('persistence survives a resetForTesting + re-init', () async {
    await SettingsService.instance.markTourSeen();

    // Simulate an app restart: reset state, then re-init
    // from the SharedPreferences backing store. The flag
    // must reload as `true`.
    SettingsService.instance.resetForTesting();
    expect(SettingsService.instance.tourSeen.value, isFalse);
    await SettingsService.instance.init();
    expect(
      SettingsService.instance.tourSeen.value,
      isTrue,
      reason:
          'Persisting tourSeen across an app restart is the core '
          'behavior — a user who finished the tour on Monday must '
          'not see the "Show me around" CTA again on Tuesday.',
    );
  });

  test('resetForTesting() clears the notifier back to false', () async {
    await SettingsService.instance.markTourSeen();
    expect(SettingsService.instance.tourSeen.value, isTrue);
    SettingsService.instance.resetForTesting();
    expect(
      SettingsService.instance.tourSeen.value,
      false,
      reason:
          'resetForTesting() must mirror the pattern set by '
          'firstLaunchCompleted and japanRoutine: the next init() '
          're-reads from SharedPreferences, so the in-memory '
          'notifier must be cleared before that read.',
    );
  });
}
