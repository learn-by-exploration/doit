// Tests for `StreakRecoveryCard` — the one-shot card
// shown when the consecutive-counter reports 3+ missed
// days on a habit (v1.2j / Phase 10 / SYS-106).

import 'package:doit/widgets/streak_recovery_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

Widget _host(Widget child) => localizedApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders SizedBox.shrink() when state is null', (tester) async {
    await tester.pumpWidget(_host(const StreakRecoveryCard(state: null)));
    expect(
      find.descendant(
        of: find.byType(StreakRecoveryCard),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });

  testWidgets('renders header + body + "I\'m back" button when state is set', (
    tester,
  ) async {
    var resumed = false;
    var dismissed = false;
    await tester.pumpWidget(
      _host(
        StreakRecoveryCard(
          state: const StreakRecoveryState(
            habitId: 'h1',
            habitLabel: 'Drink water',
            missedDays: 4,
            nextSlotLabel: 'tomorrow 9:00 AM',
          ),
          onResume: () => resumed = true,
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    expect(find.text('Streak broken on Drink water'), findsOneWidget);
    expect(find.textContaining('4 days missed'), findsOneWidget);
    expect(find.text("I'm back"), findsOneWidget);
    await tester.tap(find.text("I'm back"));
    await tester.pumpAndSettle();
    expect(resumed, isTrue);
    await tester.tap(
      find.byKey(const ValueKey('streak_recovery_card.dismiss.h1')),
    );
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });
}
