// Tests for the Hold-tap mission screen.

import 'package:doit/missions/mission.dart';
import 'package:doit/screens/mission_hold.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _mission = HoldMission(
  id: 'm1',
  label: 'Hold to confirm',
  timeout: Duration(seconds: 30),
  holdDuration: Duration(milliseconds: 200),
);

Widget _wrap() => MaterialApp(
  theme: AppTheme.dark,
  home: const MissionHoldScreen(mission: _mission),
);

void main() {
  testWidgets('renders the hold target duration', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.textContaining('Hold for 0 seconds'), findsOneWidget);
  });

  testWidgets('holding for the full duration pops the screen', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final press = find.byKey(const ValueKey('mission_hold.press'));
    // Start the hold.
    final gesture = await tester.startGesture(tester.getCenter(press));
    // Let the GestureDetector register onTapDown.
    await tester.pump();
    // Advance fake clock past the 200ms holdDuration in 50ms
    // increments so the periodic poll timer fires.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // The screen should have called Navigator.pop with HoldInput.
    await tester.pumpAndSettle();
    await gesture.up();
    // No way to read the popped value here; we assert the screen
    // is gone.
    expect(find.byType(MissionHoldScreen), findsNothing);
  });

  testWidgets('releasing early does NOT pop', (tester) async {
    await tester.pumpWidget(_wrap());
    final press = find.byKey(const ValueKey('mission_hold.press'));
    final gesture = await tester.startGesture(tester.getCenter(press));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump();
    // Screen still present.
    expect(find.byType(MissionHoldScreen), findsOneWidget);
  });
}
