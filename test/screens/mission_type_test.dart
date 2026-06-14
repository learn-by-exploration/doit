// Tests for the Type-phrase mission screen.

import 'package:common_games/missions/mission.dart';
import 'package:common_games/screens/mission_type.dart';
import 'package:common_games/theme/app_theme.dart';
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
    expect(find.text('Phrase does not match. Try again.'), findsOneWidget);
    expect(find.byType(MissionTypeScreen), findsOneWidget);
  });
}
