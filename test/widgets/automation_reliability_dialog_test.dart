// Tests for `AutomationReliabilityDialog` — the `AlertDialog`
// opened when a user taps a `degraded` or `unknown`
// `AutomationReliabilityBadge` in the three add screens
// (add_habit / add_person / add_event).
//
// v1.2h / Phase 8 / SYS-103: the prior version had the badge
// non-interactive. This release wires the badge's `onTap`
// callback (in all three add screens) to
// `showAutomationReliabilityDialog(...)` and ships the
// dialog widget with rationale copy + a deep-link to the
// system Settings page.

import 'package:doit/routines/routine.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:doit/widgets/automation_reliability_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

Automation _automation(Trigger trigger) {
  return Automation(
    id: 'a1',
    trigger: trigger,
    action: const ActionNotify(title: 't', body: 'b'),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Automation automation,
}) async {
  await tester.pumpWidget(
    localizedApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () =>
                  showAutomationReliabilityDialog(ctx, automation: automation),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(PermissionService.instance.resetForTesting);

  testWidgets(
    'location trigger: title + status + rationale + Open settings CTA',
    (tester) async {
      await _pump(
        tester,
        automation: _automation(
          const TriggerLocationEnter(
            geofenceId: 'g1',
            label: 'Home',
            latitude: 0,
            longitude: 0,
            radiusMeters: 100,
          ),
        ),
      );
      expect(find.text('This routine may not fire'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      // The status label is "Denied" — that's the default in
      // PermissionService after resetForTesting.
      expect(find.text('Status: Denied'), findsOneWidget);
      // The rationale mentions "approximate location".
      expect(find.textContaining('approximate location'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    },
  );

  testWidgets('calendar trigger renders Calendar title and rationale', (
    tester,
  ) async {
    await _pump(
      tester,
      automation: _automation(
        const TriggerCalendarEventStart(
          calendarId: 'primary',
          eventTitle: 'Standup',
        ),
      ),
    );
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.textContaining('calendar event'), findsOneWidget);
  });

  testWidgets('usage-stats trigger deep-links via requestUsageStats', (
    tester,
  ) async {
    await _pump(
      tester,
      automation: _automation(
        const TriggerForegroundApp(packageName: 'com.example'),
      ),
    );
    expect(find.text('Usage access'), findsOneWidget);
    // The "Open settings" button is present; we don't
    // exercise the platform channel in widget tests.
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('time-of-day trigger renders the no-permission-gate copy', (
    tester,
  ) async {
    await _pump(
      tester,
      automation: _automation(const TriggerTimeOfDay(hour: 9, minute: 0)),
    );
    expect(find.textContaining('alarm system'), findsOneWidget);
    // No Open settings CTA when the trigger has no permission
    // gate.
    expect(find.text('Open settings'), findsNothing);
  });

  // v1.5b / Phase 25: the dialog now grows an Action section
  // for action leaves with a permission gate
  // (`ActionFullscreen`, `ActionCallIntercept`,
  // `ActionOverrideSilent`). The "Trigger" section renders
  // above (when applicable); the "Action" section renders
  // below with one `_KindSection` per required kind.
  group('v1.5b action-side section', () {
    testWidgets(
      'ActionFullscreen renders "Action" section + fullScreenIntent kind',
      (tester) async {
        await _pump(
          tester,
          automation: Automation(
            id: 'a-fullscreen',
            trigger: const TriggerTimeOfDay(hour: 9, minute: 0),
            action: const ActionFullscreen(),
          ),
        );
        // The Trigger side has no permission gate for
        // time-of-day, so it falls through to the
        // "alarm system" copy.
        expect(find.textContaining('alarm system'), findsOneWidget);
        // The Action section is rendered (header + kind).
        expect(find.text('Action'), findsOneWidget);
        expect(find.text('Full-screen access'), findsOneWidget);
        // The kind section shows the default "Denied" status
        // (the permission is opt-in and starts denied).
        expect(find.text('Status: Denied'), findsOneWidget);
        // The CTA appears because at least one action kind is
        // degraded.
        expect(find.text('Open settings'), findsOneWidget);
      },
    );

    testWidgets(
      'ActionCallIntercept renders "Action" section + callScreening kind',
      (tester) async {
        await _pump(
          tester,
          automation: Automation(
            id: 'a-callintercept',
            trigger: const TriggerTimeOfDay(hour: 9, minute: 0),
            action: const ActionCallIntercept(
              decision: CallInterceptDecision.mute,
            ),
          ),
        );
        expect(find.text('Action'), findsOneWidget);
        expect(find.text('Call screening'), findsOneWidget);
        expect(find.text('Open settings'), findsOneWidget);
      },
    );

    testWidgets(
      'ActionOverrideSilent renders "Action" section + Do Not Disturb kind',
      (tester) async {
        await _pump(
          tester,
          automation: Automation(
            id: 'a-override',
            trigger: const TriggerTimeOfDay(hour: 9, minute: 0),
            action: const ActionOverrideSilent(targetMode: SilentMode.silent),
          ),
        );
        expect(find.text('Action'), findsOneWidget);
        expect(find.text('Do Not Disturb access'), findsOneWidget);
        expect(find.text('Open settings'), findsOneWidget);
      },
    );

    testWidgets(
      'ActionNotify does NOT render an Action section (no permission gate)',
      (tester) async {
        await _pump(
          tester,
          automation: Automation(
            id: 'a-notify',
            trigger: const TriggerTimeOfDay(hour: 9, minute: 0),
            action: const ActionNotify(title: 't', body: 'b'),
          ),
        );
        // ActionNotify gates no permission, so no Action
        // section is rendered (the dialog would only show the
        // "alarm system" trigger-side copy).
        expect(find.text('Action'), findsNothing);
        expect(find.text('Open settings'), findsNothing);
      },
    );

    testWidgets(
      'ActionOpenApp does NOT render an Action section (no permission gate)',
      (tester) async {
        await _pump(
          tester,
          automation: Automation(
            id: 'a-openapp',
            trigger: const TriggerTimeOfDay(hour: 9, minute: 0),
            action: const ActionOpenApp(route: '/home'),
          ),
        );
        expect(find.text('Action'), findsNothing);
        expect(find.text('Open settings'), findsNothing);
      },
    );

    testWidgets(
      'trigger side degraded + action side degraded → both sections render '
      'with CTA targeting the trigger kind',
      (tester) async {
        await _pump(
          tester,
          automation: Automation(
            id: 'a-both-degraded',
            trigger: const TriggerLocationEnter(
              geofenceId: 'g1',
              label: 'Home',
              latitude: 0,
              longitude: 0,
              radiusMeters: 100,
            ),
            action: const ActionFullscreen(),
          ),
        );
        // Trigger side: Location (location permission gate).
        expect(find.text('Trigger'), findsOneWidget);
        expect(find.text('Location'), findsOneWidget);
        // Action side: fullScreenIntent kind.
        expect(find.text('Action'), findsOneWidget);
        expect(find.text('Full-screen access'), findsOneWidget);
        // The CTA targets the trigger side (it wins on
        // "both sides degraded"); the trigger's kind is
        // `location`, so the dialog's "Open settings"
        // button calls `openAppSettings()` (the generic
        // deep-link for `location`).
        expect(find.text('Open settings'), findsOneWidget);
      },
    );
  });
}
