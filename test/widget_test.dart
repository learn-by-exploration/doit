// Phase 0 widget test. Pumps the Streak entry and verifies the
// placeholder renders. Replaced by per-screen widget tests in
// Phase 5 (see docs/v_model/implementation_status.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:common_games/main.dart';

void main() {
  testWidgets('streak scaffold renders the placeholder', (tester) async {
    await tester.pumpWidget(const StreakApp());

    expect(find.text('Streak — scaffold'), findsOneWidget);
    expect(find.text('Streak is loading.'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
