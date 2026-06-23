// Tests for the Type-phrase mission screen.

import 'package:doit/missions/mission.dart';
import 'package:doit/screens/mission_type.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _mission = TypeMission(
  id: 'm1',
  label: 'Type the phrase',
  timeout: Duration(seconds: 30),
  expectedPhrase: 'I did it today',
);

Widget _wrap() => MaterialApp(
  theme: AppTheme.dark,
  home: const MissionTypeScreen(mission: _mission),
);

void main() {
  testWidgets('shows the expected phrase', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byKey(const ValueKey('mission_type.expected')), findsOneWidget);
    expect(find.text('I did it today'), findsOneWidget);
  });

  testWidgets('correct input pops the screen', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.enterText(
      find.byKey(const ValueKey('mission_type.input')),
      'I did it today',
    );
    await tester.tap(find.byKey(const ValueKey('mission_type.submit')));
    await tester.pumpAndSettle();
    expect(find.byType(MissionTypeScreen), findsNothing);
  });

  testWidgets('wrong input shows an error and does not pop', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.enterText(
      find.byKey(const ValueKey('mission_type.input')),
      'oops',
    );
    await tester.tap(find.byKey(const ValueKey('mission_type.submit')));
    await tester.pump();
    // Shared 3-wrong attempts-left copy (WF-030 uniform).
    expect(find.text('Wrong. 2 attempt(s) left.'), findsOneWidget);
    expect(find.byType(MissionTypeScreen), findsOneWidget);
  });

  testWidgets('three wrong answers auto-fail the mission', (tester) async {
    await tester.pumpWidget(_wrap());
    final input = find.byKey(const ValueKey('mission_type.input'));
    final submit = find.byKey(const ValueKey('mission_type.submit'));
    Future<void> submitWrong(String s) async {
      await tester.enterText(input, s);
      await tester.tap(submit);
      await tester.pump();
    }

    await submitWrong('nope 1');
    await submitWrong('nope 2');
    // The 3rd wrong auto-fails — matching the Math
    // mission's behavior (WF-030 uniform, SYS-011).
    await submitWrong('nope 3');
    await tester.pumpAndSettle();
    expect(find.byType(MissionTypeScreen), findsNothing);
  });

  testWidgets('first two wrong answers decrement the attempts-left label', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    final input = find.byKey(const ValueKey('mission_type.input'));
    final submit = find.byKey(const ValueKey('mission_type.submit'));
    await tester.enterText(input, 'nope 1');
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Wrong. 2 attempt(s) left.'), findsOneWidget);
    await tester.enterText(input, 'nope 2');
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Wrong. 1 attempt(s) left.'), findsOneWidget);
  });
}
