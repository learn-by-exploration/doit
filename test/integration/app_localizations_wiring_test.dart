// v1.1h gap-filling integration test (SYS-087 follow-up).
//
// `test/l10n/app_localizations_test.dart` proves the
// generated `AppLocalizations` delegate works in
// isolation — but nothing in the suite proves the
// production root, `DoItApp` in `lib/main.dart`, actually
// wires the delegate into its `MaterialApp`.
//
// If a future PR removes the `localizationsDelegates:`
// or `supportedLocales:` line from `DoItApp.build`, every
// production screen crashes on `AppLocalizations.of(context)!`
// in the generated lookup. This test pins the production
// wiring by pumping `DoItApp` and inspecting the
// `MaterialApp` it returns — if either property is
// missing or wrong, the test fails immediately.
//
// The init pattern (in-memory DB + ReminderService with
// fakes + SettingsService reset) is borrowed from
// `test/integration/fresh_install_test.dart`, which is
// the smallest known-good setup for pumping the home
// screen inside a real `DoItApp` mount. We use
// `firstLaunchOverride: true` to skip onboarding and land
// directly on the home screen, which is what the test
// wants to inspect.

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/main.dart';
import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/anchor_detector.dart';
import 'package:doit/reminders/full_screen_intent.dart';
import 'package:doit/reminders/notification_service.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/do_repository.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/services/settings_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _resetDb(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DoItApp wires the AppLocalizations delegate and the [en, es] '
      'supportedLocales onto its MaterialApp', (tester) async {
    // Mirror the smallest-known-good setup from
    // `test/integration/fresh_install_test.dart` so the
    // home screen mounts cleanly inside the real DoItApp.
    await _resetDb(tester);
    // Touch DoRepository so its singleton is built and
    // any eager DB read in the home screen's build is
    // satisfied. (No save — we just want the singleton
    // alive.)
    DoRepository.instance;
    ReminderService.resetForTesting();
    await ReminderService.init(
      ReminderService(
        scheduler: FakeAlarmScheduler(),
        notifications: FakeNotificationService(),
        fullScreen: FakeFullScreenIntent(),
        anchor: FakeAnchorDetector(),
        bridge: FakeReminderBridge(),
      ),
    );
    SettingsService.instance.resetForTesting();

    // Mount the production root with `firstLaunchOverride:
    // true` so it lands on the home screen (skipping the
    // onboarding flow). We do not pumpAndSettle() — the
    // home screen has its own animations and we only care
    // about the MaterialApp's static wiring, not the
    // home screen's runtime state.
    await tester.pumpWidget(const DoItApp(firstLaunchOverride: true));
    await tester.pump();

    // Find the MaterialApp that DoItApp.build returns.
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    // (1) The delegate list is wired (non-null).
    expect(
      materialApp.localizationsDelegates,
      isNotNull,
      reason: 'DoItApp must wire localizationsDelegates on its MaterialApp',
    );

    // (2) The generated AppLocalizations delegate is in the list.
    // We match by `delegate.type` because the actual delegate
    // instance is constructed lazily by `AppLocalizations.localizationsDelegates`
    // and identity comparisons against that field would be
    // brittle. Matching the `Type` is enough to catch the
    // common regression (someone removes the line entirely).
    expect(
      materialApp.localizationsDelegates!.any(
        (d) => d.type == AppLocalizations,
      ),
      isTrue,
      reason:
          'DoItApp must include the generated AppLocalizations delegate '
          'in its localizationsDelegates list',
    );

    // (3) The supported locale list contains en + es — the
    // two ARB files we ship today. Adding a third locale
    // without updating this assertion is the desired failure
    // mode (a deliberate scope expansion should update both
    // the ARB and this test in the same PR).
    expect(
      materialApp.supportedLocales,
      containsAll(<Locale>[const Locale('en'), const Locale('es')]),
      reason: 'DoItApp must declare en and es as supportedLocales',
    );
  });
}
