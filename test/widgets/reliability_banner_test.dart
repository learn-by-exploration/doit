// Tests for the ReliabilityBanner widget.

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/widgets/reliability_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
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
}
