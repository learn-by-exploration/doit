// Tests for `DstTransitionBanner` — the one-shot card
// shown when a DST transition silently reschedules one or
// more habit times (v1.2j / Phase 10 / SYS-105).

import 'package:doit/widgets/dst_transition_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

Widget _host(Widget child) => localizedApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders SizedBox.shrink() when drops is empty', (tester) async {
    await tester.pumpWidget(
      _host(const DstTransitionBanner(drops: <DstDroppedTime>[])),
    );
    expect(find.byType(DstTransitionBanner), findsOneWidget);
    // The banner should render a SizedBox.shrink(), which
    // shows up as a zero-size widget. Verify the banner
    // subtree contains no Text (no card copy rendered).
    expect(
      find.descendant(
        of: find.byType(DstTransitionBanner),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });

  testWidgets('renders a card with one dropped time (singular copy)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        DstTransitionBanner(
          drops: const [
            DstDroppedTime(
              habitId: 'h1',
              label: '02:30 AM',
              rescheduledTo: '03:30 AM',
            ),
          ],
          onDismiss: () {},
        ),
      ),
    );
    expect(find.text('Daylight saving changed'), findsOneWidget);
    expect(
      find.text('Your "02:30 AM" habit was rescheduled to 03:30 AM.'),
      findsOneWidget,
    );
    expect(find.text('• 02:30 AM → 03:30 AM'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dst_transition_banner.dismiss')),
      findsOneWidget,
    );
  });

  testWidgets('renders plural copy for multiple dropped times', (tester) async {
    await tester.pumpWidget(
      _host(
        const DstTransitionBanner(
          drops: [
            DstDroppedTime(
              habitId: 'h1',
              label: '02:30 AM',
              rescheduledTo: '03:30 AM',
            ),
            DstDroppedTime(
              habitId: 'h2',
              label: '02:45 AM',
              rescheduledTo: '03:45 AM',
            ),
          ],
        ),
      ),
    );
    expect(
      find.textContaining('2 habit times were silently rescheduled'),
      findsOneWidget,
    );
  });

  testWidgets('Dismiss icon invokes onDismiss', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      _host(
        DstTransitionBanner(
          drops: const [
            DstDroppedTime(
              habitId: 'h1',
              label: '02:30 AM',
              rescheduledTo: '03:30 AM',
            ),
          ],
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('dst_transition_banner.dismiss')),
    );
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });

  testWidgets('Reschedule now button is rendered when onRescheduleNow set', (
    tester,
  ) async {
    var rescheduled = false;
    await tester.pumpWidget(
      _host(
        DstTransitionBanner(
          drops: const [
            DstDroppedTime(
              habitId: 'h1',
              label: '02:30 AM',
              rescheduledTo: '03:30 AM',
            ),
          ],
          onRescheduleNow: () => rescheduled = true,
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('dst_transition_banner.reschedule_now')),
    );
    await tester.pumpAndSettle();
    expect(rescheduled, isTrue);
  });
}
