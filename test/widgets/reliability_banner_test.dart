// Tests for the ReliabilityBanner widget.

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/services/reliability_service.dart';
import 'package:doit/widgets/reliability_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // v1.3b / Phase 13: tests that drive the
  // `fromStream` factory need the unified
  // `ReliabilityService` initialized against a
  // `FakeReminderBridge` and the live
  // `PermissionService`. We reset both singletons in
  // `setUp` and again in `tearDown` so the stream-bound
  // tests do not leak state into other files in the
  // suite.
  late FakeReminderBridge bridge;
  setUp(() async {
    ReliabilityService.resetForTesting();
    PermissionService.instance.resetForTesting();
    await PermissionService.instance.init();
    // v1.3b / Phase 13 / SYS-112: grant every kind so the
    // bootstrap derive step lands on `optimal`. The
    // `FakeReminderBridge` defaults to `optimal`; the
    // permissions map is the only thing that could flip
    // the value to `degraded` for tests that don't intend
    // it.
    PermissionService.instance.statuses.value = {
      for (final k in PermissionKind.values) k: const PermissionResultGranted(),
    };
    bridge = FakeReminderBridge();
    await ReliabilityService.init(
      bridge: bridge,
      permissionService: PermissionService.instance,
    );
  });

  tearDown(() {
    ReliabilityService.resetForTesting();
    PermissionService.instance.resetForTesting();
  });

  testWidgets('reliability=optimal renders nothing', (tester) async {
    await tester.pumpWidget(
      _wrap(const ReliabilityBanner(reliability: Reliability.optimal)),
    );
    expect(find.byType(SizedBox), findsOneWidget);
    expect(find.textContaining('Reminders may be late'), findsNothing);
  });

  testWidgets('reliability=degraded shows the warning copy', (tester) async {
    await tester.pumpWidget(
      _wrap(const ReliabilityBanner(reliability: Reliability.degraded)),
    );
    expect(find.text('Reminders may be late. Tap to fix.'), findsOneWidget);
  });

  testWidgets('reliability=unknown shows the warning copy', (tester) async {
    await tester.pumpWidget(
      _wrap(const ReliabilityBanner(reliability: Reliability.unknown)),
    );
    expect(find.text('Reminders may be late. Tap to fix.'), findsOneWidget);
  });

  testWidgets('onTap fires when banner is tapped', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _wrap(
        ReliabilityBanner(
          reliability: Reliability.degraded,
          onTap: () => tapped++,
        ),
      ),
    );
    await tester.tap(find.text('Reminders may be late. Tap to fix.'));
    expect(tapped, 1);
  });

  // v1.3b / Phase 13 / SYS-112: the `fromStream` factory
  // wraps the service notifier in a `ValueListenableBuilder`
  // and rebuilds on every state change. The two
  // `fromStream` tests below pin the rebuild path — a
  // regression that fell back to a one-shot read would
  // fail them.

  testWidgets('fromStream renders nothing when the service is optimal', (
    tester,
  ) async {
    // The default ReliabilityService value is `optimal`,
    // so the banner collapses to a SizedBox.
    await tester.pumpWidget(_wrap(ReliabilityBanner.fromStream()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Reminders may be late'), findsNothing);
  });

  testWidgets('fromStream rebuilds when the service value flips to degraded', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(ReliabilityBanner.fromStream()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Reminders may be late'), findsNothing);

    // Flip the bridge probe to `degraded` and ask the
    // service to re-probe. The banner's
    // `ValueListenableBuilder` should rebuild on the
    // next frame and show the warning copy.
    bridge.reliability = Reliability.degraded;
    await ReliabilityService.instance.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Reminders may be late. Tap to fix.'), findsOneWidget);
  });

  // v1.3c / Phase 14 / SYS-113 / ADR-043: the home screen
  // passes an `onTap` callback to `fromStream` so the user
  // is one tap away from the Settings → Permissions screen.
  // The test pins the wiring so a regression that drops
  // the callback (or wraps the tap in an InkWell that does
  // not fire) is caught.
  testWidgets('fromStream wires onTap when the service is degraded', (
    tester,
  ) async {
    // Start degraded so the banner actually renders the
    // warning row (the `optimal` branch returns a
    // SizedBox, which is not tappable).
    bridge.reliability = Reliability.degraded;
    await ReliabilityService.instance.refresh();
    var tapped = 0;
    await tester.pumpWidget(
      _wrap(ReliabilityBanner.fromStream(onTap: () => tapped++)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reminders may be late. Tap to fix.'), findsOneWidget);
    await tester.tap(find.text('Reminders may be late. Tap to fix.'));
    expect(tapped, 1, reason: 'fromStream onTap must fire on tap.');
  });
}
