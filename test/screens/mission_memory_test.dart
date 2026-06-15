// Tests for the Memory mission screen.
//
// The memory game uses a fixed seed for deterministic tests; the
// generated deck order is known in advance. These tests exercise
// the happy path by clicking pairs derived from a fresh
// generation; the assertion is that the screen pops with the
// expected matchedPairs length.

import 'package:doit/missions/mission.dart';
import 'package:doit/missions/mission_input.dart';
import 'package:doit/screens/mission_memory.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _mission = MemoryMission(
  id: 'm1',
  label: 'Memory',
  timeout: Duration(seconds: 30),
  rows: 2,
  cols: 2,
  theme: 'shapes',
  timeLimit: Duration(seconds: 30),
);

Widget _wrap() => MaterialApp(
  theme: AppTheme.dark,
  home: const MissionMemoryScreen(mission: _mission, seed: 42),
);

void main() {
  setUp(() {
    // 2x2 grid is taller than the default 800x600 test viewport;
    // grow it so all cards are on-screen.
  });

  testWidgets('renders the initial score', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('0 / 2'), findsOneWidget);
  });

  testWidgets('flipping a non-matching pair keeps the score at 0', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    final deck = MemoryGame.generate(
      rows: _mission.rows,
      cols: _mission.cols,
      theme: _mission.theme,
      seed: 42,
    );
    // Find two cards that do NOT share a pairId.
    var i = 0, j = 1;
    while (i < deck.length && (deck[i].pairId == deck[j].pairId)) {
      j++;
      if (j >= deck.length) {
        i++;
        j = i + 1;
      }
    }
    await tester.tap(find.byKey(ValueKey('mission_memory.card.$i')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('mission_memory.card.$j')));
    await tester.pump();
    expect(find.text('0 / 2'), findsOneWidget);
  });

  testWidgets('matching all pairs pops the screen', (tester) async {
    await tester.pumpWidget(_wrap());
    final deck = MemoryGame.generate(
      rows: _mission.rows,
      cols: _mission.cols,
      theme: _mission.theme,
      seed: 42,
    );
    // Group by pairId and tap each pair.
    final pairs = <int, List<int>>{};
    for (var idx = 0; idx < deck.length; idx++) {
      pairs.putIfAbsent(deck[idx].pairId, () => []).add(idx);
    }
    for (final entry in pairs.entries) {
      for (final idx in entry.value) {
        await tester.tap(find.byKey(ValueKey('mission_memory.card.$idx')));
        await tester.pump();
      }
    }
    await tester.pumpAndSettle();
    expect(find.byType(MissionMemoryScreen), findsNothing);
  });
}
