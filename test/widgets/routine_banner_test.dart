// Tests for the v1.1 (SYS-082) RoutineBanner widget.
//
// Coverage:
//   - Renders SizedBox.shrink() when the executor's
//     pendingOpenApp queue is empty.
//   - On append, drains the queue and pushes the requested
//     route via Navigator.pushNamed.
//   - On drain, calls RoutineExecutor.clearPendingOpenApp()
//     so the queue is reset for the next fire.
//   - Drains every request in FIFO order when multiple are
//     appended before the home screen rebuilds.

import 'package:doit/routines/routine.dart';
import 'package:doit/routines/routine_executor.dart';
import 'package:doit/widgets/routine_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoutineBanner', () {
    setUp(RoutineExecutor.instance.clearPendingOpenApp);

    tearDown(RoutineExecutor.instance.clearPendingOpenApp);

    testWidgets('renders SizedBox.shrink() when the queue is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RoutineBanner())),
      );
      expect(find.byType(RoutineBanner), findsOneWidget);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('pushes the requested route when the queue is non-empty', (
      tester,
    ) async {
      final pushedRoutes = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  const RoutineBanner(),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushNamed('/home'),
                    child: const Text('go'),
                  ),
                ],
              ),
            ),
          ),
          onGenerateRoute: (settings) {
            pushedRoutes.add(settings.name ?? '');
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('home route landed')),
            );
          },
        ),
      );

      // Append a request; the banner rebuilds on the next
      // frame, the post-frame callback runs at the end of
      // the frame, and the route is pushed.
      RoutineExecutor.instance.appendOpenApp(
        RoutineOpenAppRequest(route: '/home', at: DateTime(2026, 6, 21)),
      );
      await tester.pump();
      await tester.pump();

      expect(pushedRoutes, <String>['/home']);
      // The queue was cleared after the drain.
      expect(RoutineExecutor.instance.pendingOpenApp.value, isEmpty);
    });

    testWidgets('drains every request in FIFO order when multiple are '
        'appended', (tester) async {
      final pushedRoutes = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  const RoutineBanner(),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Text('reset'),
                  ),
                ],
              ),
            ),
          ),
          onGenerateRoute: (settings) {
            pushedRoutes.add(settings.name ?? '');
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(body: Text('landed: ${settings.name}')),
            );
          },
        ),
      );

      // Append two requests before any frame is pumped. Both
      // should drain in order on the next post-frame callback.
      RoutineExecutor.instance.appendOpenApp(
        RoutineOpenAppRequest(route: '/first', at: DateTime(2026, 6, 21)),
      );
      RoutineExecutor.instance.appendOpenApp(
        RoutineOpenAppRequest(route: '/second', at: DateTime(2026, 6, 21)),
      );
      await tester.pump();
      await tester.pump();

      expect(pushedRoutes, <String>['/first', '/second']);
      expect(RoutineExecutor.instance.pendingOpenApp.value, isEmpty);
    });

    testWidgets('renders a one-line "opening" banner while the queue '
        'has requests', (tester) async {
      // Append BEFORE mounting so the first build sees a
      // non-empty queue.
      RoutineExecutor.instance.appendOpenApp(
        RoutineOpenAppRequest(route: '/x', at: DateTime(2026, 6, 21)),
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RoutineBanner())),
      );

      // The banner is rendered for one frame before the
      // post-frame callback drains the queue.
      expect(find.textContaining('Opening'), findsOneWidget);

      await tester.pump();
      await tester.pump();

      // After the drain, the queue is empty and the banner
      // shrinks away.
      expect(find.textContaining('Opening'), findsNothing);
    });
  });
}
