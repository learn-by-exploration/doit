// Tests for the Shake-N mission screen.

import 'dart:async';

import 'package:doit/missions/mission.dart';
import 'package:doit/missions/mission_input.dart';
import 'package:doit/screens/mission_shake.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _mission = ShakeMission(
  id: 'm1',
  label: 'Shake',
  timeout: Duration(seconds: 30),
  targetCount: 2,
);

Widget _wrap({Stream<ShakeSample>? samples}) => MaterialApp(
  theme: AppTheme.dark,
  home: MissionShakeScreen(mission: _mission, samples: samples),
);

void main() {
  testWidgets('renders the shake count and target', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('0 / 2'), findsOneWidget);
  });

  testWidgets('debug-simulate button advances the count', (tester) async {
    await tester.pumpWidget(_wrap());
    // samples is null → debug-simulate button is shown.
    final btn = find.byKey(const ValueKey('mission_shake.debug_simulate'));
    await tester.tap(btn);
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('synthetic shake samples pop the screen at target', (
    tester,
  ) async {
    final controller = StreamController<ShakeSample>();
    addTearDown(controller.close);
    await tester.pumpWidget(_wrap(samples: controller.stream));
    // Push two high-magnitude samples spaced by 400 ms (within
    // the default 250-1500 ms window).
    final t0 = DateTime(2026, 6, 14, 9);
    controller.add(ShakeSample(x: 0, y: 0, z: 30, at: t0));
    controller.add(
      ShakeSample(
        x: 0,
        y: 0,
        z: 30,
        at: t0.add(const Duration(milliseconds: 400)),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(MissionShakeScreen), findsNothing);
  });
}
