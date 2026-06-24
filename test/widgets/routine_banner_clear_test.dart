// Phase 12 (SYS-116) test pin for the RoutineBanner's
// auto-clear behavior. The banner is a passive listener that
// drains `RoutineExecutor.pendingOpenApp` via a post-frame
// callback. These tests pin the user-observable behavior:
//
//   1. Empty queue → SizedBox.shrink (no banner copy visible).
//   2. Non-empty queue → the "Opening …" copy is visible for
//      exactly one frame, then the post-frame callback fires
//      and the queue is drained.
//   3. After `clearPendingOpenApp()` is called (either by the
//      banner itself or by some upstream), the banner collapses
//      back to a zero-size box on the next build.
//
// The deeper drain mechanics (route push, FIFO ordering,
// catch-all) live in `test/widgets/routine_banner_test.dart`
// — this file is the Phase-12 behavior pin, not a duplicate
// of that coverage.

import 'package:doit/routines/routine.dart';
import 'package:doit/routines/routine_executor.dart';
import 'package:doit/widgets/routine_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoutineBanner auto-clear (Phase 12 pin)', () {
    setUp(RoutineExecutor.instance.clearPendingOpenApp);

    tearDown(RoutineExecutor.instance.clearPendingOpenApp);

    testWidgets('empty queue renders SizedBox.shrink — no banner copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RoutineBanner())),
      );
      // No drain happens; the banner stays collapsed.
      expect(find.byType(RoutineBanner), findsOneWidget);
      expect(find.textContaining('Opening'), findsNothing);
    });

    testWidgets('non-empty queue renders the "Opening …" copy for one '
        'frame, then drains to empty', (tester) async {
      // Seed the queue before mount so the first build sees a
      // non-empty queue. The "Opening routine destination…"
      // copy renders for exactly one frame before the
      // post-frame callback drains it.
      RoutineExecutor.instance.appendOpenApp(
        RoutineOpenAppRequest(route: '/x', at: DateTime(2026, 6, 21)),
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RoutineBanner())),
      );

      expect(find.textContaining('Opening'), findsOneWidget);

      // Pump to flush the post-frame callback that calls
      // clearPendingOpenApp(). The next build sees an empty
      // queue and the banner collapses back to SizedBox.shrink.
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Opening'), findsNothing);
      expect(RoutineExecutor.instance.pendingOpenApp.value, isEmpty);
    });

    testWidgets('clearPendingOpenApp collapses the banner back to zero size', (
      tester,
    ) async {
      // Seed the queue, mount, observe the banner copy. Then
      // clear the queue out-of-band (no drain via the banner's
      // own callback) and pump again. The banner must collapse
      // because `ValueListenableBuilder` rebuilds on the empty
      // queue.
      RoutineExecutor.instance.appendOpenApp(
        RoutineOpenAppRequest(route: '/y', at: DateTime(2026, 6, 21)),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RoutineBanner())),
      );
      expect(find.textContaining('Opening'), findsOneWidget);

      // Clear out-of-band — e.g., the executor reset path. No
      // routes get pushed because we're past the drain frame.
      RoutineExecutor.instance.clearPendingOpenApp();
      await tester.pump();

      expect(find.textContaining('Opening'), findsNothing);
      expect(RoutineExecutor.instance.pendingOpenApp.value, isEmpty);
    });
  });
}
