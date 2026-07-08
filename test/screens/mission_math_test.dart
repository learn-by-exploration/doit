// Tests for the Math mission screen.

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/missions/mission.dart';
import 'package:doit/screens/mission_math.dart';
import 'package:doit/theme/app_theme.dart';
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
  // v1.8-11 / SYS-186: the 3rd-wrong flow shows a
  // MissionFailedView dialog that reads AppLocalizations.
  // Wire the delegate so the dialog renders in tests too.
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
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
    // The third tap triggers auto-fail. v1.8-11 / SYS-186
    // now shows a MissionFailedView dialog before popping;
    // dismiss it before the pop completes.
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mission_failed.dismiss')));
    await tester.pumpAndSettle();
    expect(find.byType(MissionMathScreen), findsNothing);
  });
}
