// Phase 0 widget test. Pumps the Streak entry and verifies the
// placeholder renders. Replaced by per-screen widget tests in
// Phase 5 (see docs/v_model/implementation_status.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:common_games/main.dart';

void main() {
  testWidgets('Streak app boots into onboarding on first launch', (
    tester,
  ) async {
    await tester.pumpWidget(const StreakApp());
    await tester.pump();

    // Onboarding is the initial route in v0.1.
    expect(find.text('Welcome to Streak'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
