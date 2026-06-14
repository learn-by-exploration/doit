// Tests for the Math mission screen.

import 'package:common_games/missions/mission.dart';
import 'package:common_games/screens/mission_math.dart';
import 'package:common_games/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _mission = MathMission(
  id: 'm1',
  label: 'Math',
  timeout: Duration(seconds: 30),
  difficulty: MathDifficulty.easy,
);

Widget _wrap() => MaterialApp(
  theme: AppTheme.dark,
  home: const MissionMathScreen(mission: _mission),
);

void main() {
  testWidgets('shows a problem', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byKey(const ValueKey('mission_math.problem')), findsOneWidget);
  });

  testWidgets('correct answer pops the screen', (tester) async {
    await tester.pumpWidget(_wrap());
    // Read the problem, then submit the computed answer.
    final problemFinder = find.byKey(const ValueKey('mission_math.problem'));
    final problemText = (tester.widget<Text>(problemFinder)).data!;
    // Parse "a + b = ?" or "a − b = ?" or "a × b = ?".
    final match = RegExp(r'(\d+)\s*([+−×])\s*(\d+)').firstMatch(problemText)!;
    final a = int.parse(match.group(1)!);
    final op = match.group(2)!;
    final b = int.parse(match.group(3)!);
    final answer = switch (op) {
      '+' => a + b,
      '−' => a - b,
      '×' => a * b,
      _ => throw StateError('unexpected op $op'),
    };
    await tester.enterText(
      find.byKey(const ValueKey('mission_math.input')),
      '$answer',
    );
    await tester.tap(find.byKey(const ValueKey('mission_math.submit')));
    await tester.pumpAndSettle();
    expect(find.byType(MissionMathScreen), findsNothing);
  });

  testWidgets('three wrong answers auto-fails the mission', (tester) async {
    await tester.pumpWidget(_wrap());
    final input = find.byKey(const ValueKey('mission_math.input'));
    final submit = find.byKey(const ValueKey('mission_math.submit'));
    await tester.enterText(input, '0');
    await tester.tap(submit);
    await tester.pump();
    await tester.enterText(input, '0');
    await tester.tap(submit);
    await tester.pump();
    await tester.enterText(input, '0');
    await tester.tap(submit);
    // The third tap triggers auto-fail (no fourth).
    await tester.pumpAndSettle();
    expect(find.byType(MissionMathScreen), findsNothing);
  });
}
