// Widget tests for `AutomationReliabilityBadge` (v1.1f /
// SYS-085).
//
// The badge has three observable behaviors:
//   1. `optimal` → renders nothing (`SizedBox.shrink`); the
//      common case must NOT clutter the trailing slot.
//   2. `degraded` / `unknown` → renders a 40 × 40 `IconButton`
//      with the right icon + semantics label.
//   3. Tapping the badge fires the [onTap] callback.
//
// These tests do not exercise the deep-link wiring in the
// three `_RoutineRow`s; that's covered by the parent screen
// widget tests (add_habit_test, add_person_test,
// add_event_test). The tests here focus on the badge itself.

import 'package:doit/routines/routine.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:doit/widgets/automation_reliability_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: child),
  );
}

final _locationAutomation = Automation(
  trigger: const TriggerLocationEnter(
    geofenceId: 'g1',
    label: 'Home',
    latitude: 37.7749,
    longitude: -122.4194,
    radiusMeters: 100,
  ),
  action: const ActionNotify(title: 't', body: 'b'),
);

final _deviceStateAutomation = Automation(
  trigger: const TriggerChargingStarted(),
  action: const ActionNotify(title: 't', body: 'b'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();
  });

  group('optimal state', () {
    testWidgets('renders nothing for a trigger with no runtime gate '
        '(device-state)', (tester) async {
      // TriggerChargingStarted has no runtime gate; the
      // service defaults every status to
      // `denied(canOpenSettings: true)` so the device-state
      // trigger is `optimal` from the start.
      await tester.pumpWidget(
        _wrap(AutomationReliabilityBadge(automation: _deviceStateAutomation)),
      );
      expect(find.byKey(AutomationReliabilityBadge.widgetKey), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('renders nothing for a granted-permission trigger', (
      tester,
    ) async {
      // After init() every status is `denied`. Manually
      // promote location to `granted` to flip the
      // location-trigger to `optimal`.
      PermissionService.instance.statuses.value = {
        ...PermissionService.instance.statuses.value,
        PermissionKind.location: const PermissionResultGranted(),
      };
      await tester.pumpWidget(
        _wrap(AutomationReliabilityBadge(automation: _locationAutomation)),
      );
      expect(find.byKey(AutomationReliabilityBadge.widgetKey), findsNothing);
    });
  });

  group('degraded state', () {
    testWidgets('renders the warning icon button when the runtime '
        'permission is denied', (tester) async {
      // After init() location is `denied(canOpenSettings:
      // true)`. The location trigger should report degraded.
      await tester.pumpWidget(
        _wrap(AutomationReliabilityBadge(automation: _locationAutomation)),
      );
      final iconBtn = find.byKey(AutomationReliabilityBadge.widgetKey);
      expect(iconBtn, findsOneWidget);
      final widget = tester.widget<IconButton>(iconBtn);
      expect(widget.icon, isA<Icon>());
      expect((widget.icon as Icon).icon, Icons.warning_amber_rounded);
    });

    testWidgets('renders the warning icon button when the runtime '
        'permission is permanentlyDenied', (tester) async {
      PermissionService.instance.statuses.value = {
        ...PermissionService.instance.statuses.value,
        PermissionKind.location: const PermissionResultPermanentlyDenied(),
      };
      await tester.pumpWidget(
        _wrap(AutomationReliabilityBadge(automation: _locationAutomation)),
      );
      final iconBtn = find.byKey(AutomationReliabilityBadge.widgetKey);
      expect(iconBtn, findsOneWidget);
      final widget = tester.widget<IconButton>(iconBtn);
      expect((widget.icon as Icon).icon, Icons.warning_amber_rounded);
    });

    testWidgets('Semantics label matches the degraded copy', (tester) async {
      await tester.pumpWidget(
        _wrap(AutomationReliabilityBadge(automation: _locationAutomation)),
      );
      expect(
        find.bySemanticsLabel('Routine reliability degraded; tap to fix'),
        findsOneWidget,
      );
    });
  });

  group('unknown state', () {
    testWidgets('renders the info icon button when the runtime '
        'permission is unprobed (null)', (tester) async {
      // The default init() leaves every status as
      // `denied(canOpenSettings: true)` EXCEPT
      // `backupFolder` which is null. The location trigger
      // never sees null in normal flow, so we manually
      // null it out.
      PermissionService.instance.statuses.value = {
        ...PermissionService.instance.statuses.value,
        PermissionKind.location: null,
      };
      await tester.pumpWidget(
        _wrap(AutomationReliabilityBadge(automation: _locationAutomation)),
      );
      final iconBtn = find.byKey(AutomationReliabilityBadge.widgetKey);
      expect(iconBtn, findsOneWidget);
      final widget = tester.widget<IconButton>(iconBtn);
      expect((widget.icon as Icon).icon, Icons.info_outline);
    });

    testWidgets('Semantics label matches the unknown copy', (tester) async {
      PermissionService.instance.statuses.value = {
        ...PermissionService.instance.statuses.value,
        PermissionKind.location: null,
      };
      await tester.pumpWidget(
        _wrap(AutomationReliabilityBadge(automation: _locationAutomation)),
      );
      expect(
        find.bySemanticsLabel('Routine reliability unknown; tap to learn more'),
        findsOneWidget,
      );
    });
  });

  group('onTap callback', () {
    testWidgets('fires when the badge is tapped', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        _wrap(
          AutomationReliabilityBadge(
            automation: _locationAutomation,
            onTap: () => tapCount++,
          ),
        ),
      );
      await tester.tap(find.byKey(AutomationReliabilityBadge.widgetKey));
      expect(tapCount, 1);
    });

    testWidgets('omits the callback → IconButton onPressed is null '
        '(non-interactive but still rendered)', (tester) async {
      await tester.pumpWidget(
        _wrap(AutomationReliabilityBadge(automation: _locationAutomation)),
      );
      final widget = tester.widget<IconButton>(
        find.byKey(AutomationReliabilityBadge.widgetKey),
      );
      expect(widget.onPressed, isNull);
    });
  });

  group('reactivity', () {
    testWidgets('rebuilds from `denied` → `granted` when the '
        'PermissionService.statuses ValueNotifier updates', (tester) async {
      await tester.pumpWidget(
        _wrap(AutomationReliabilityBadge(automation: _locationAutomation)),
      );
      // Pre-condition: badge visible (degraded).
      expect(find.byKey(AutomationReliabilityBadge.widgetKey), findsOneWidget);

      // User grants the location permission; the
      // ValueNotifier fires; the badge hides itself.
      PermissionService.instance.statuses.value = {
        ...PermissionService.instance.statuses.value,
        PermissionKind.location: const PermissionResultGranted(),
      };
      await tester.pump();

      expect(find.byKey(AutomationReliabilityBadge.widgetKey), findsNothing);
    });

    testWidgets('rebuilds from `granted` → `denied` when the '
        'PermissionService.statuses ValueNotifier updates', (tester) async {
      PermissionService.instance.statuses.value = {
        ...PermissionService.instance.statuses.value,
        PermissionKind.location: const PermissionResultGranted(),
      };
      await tester.pumpWidget(
        _wrap(AutomationReliabilityBadge(automation: _locationAutomation)),
      );
      expect(find.byKey(AutomationReliabilityBadge.widgetKey), findsNothing);

      // User revokes the permission (e.g., system Settings).
      PermissionService.instance.statuses.value = {
        ...PermissionService.instance.statuses.value,
        PermissionKind.location: const PermissionResultDenied(
          canOpenSettings: true,
        ),
      };
      await tester.pump();

      expect(find.byKey(AutomationReliabilityBadge.widgetKey), findsOneWidget);
    });
  });
}
