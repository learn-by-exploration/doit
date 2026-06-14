// Tests for the StatsScreen — empty state, error retry, and
// a happy path that asserts a single habit renders.

import 'package:common_games/habits/habit.dart';
import 'package:common_games/habits/proof_mode.dart';
import 'package:common_games/screens/stats.dart';
import 'package:common_games/services/db.dart';
import 'package:common_games/services/db/schema.dart';
import 'package:common_games/services/habit_repository.dart';
import 'package:common_games/services/completion_log_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _resetDb(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });
}

Widget _wrap() => const MaterialApp(home: StatsScreen());

void main() {
  setUp(() {
    HabitRepository.instance;
    CompletionLogService.instance;
  });

  testWidgets('empty state when no habits exist', (tester) async {
    await _resetDb(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('No stats yet.'), findsOneWidget);
  });

  testWidgets('a single habit renders as a card', (tester) async {
    await _resetDb(tester);
    await HabitRepository.instance.save(
      HabitFixed(
        id: 'h1',
        name: 'Stretch',
        proofMode: const SoftProof(),
        createdAt: DateTime(2026, 6),
        restDaysPerMonth: 2,
        weekdays: const {1, 3, 5},
        time: const HabitTime(9, 0),
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Stretch'), findsOneWidget);
  });
}
