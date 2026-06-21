// RoutineBanner — a passive listener that drains the
// `RoutineExecutor.pendingOpenApp` queue and pushes the
// requested routes via `Navigator.pushNamed`.
//
// Why a dedicated widget (and not a side-effect in
// `RoutineExecutor` or `HomeScreen.initState`):
//
//   - The executor is a non-Flutter singleton; it
//     cannot depend on `Navigator` (it would pull
//     `package:flutter/material.dart` into
//     `lib/routines/`, which is the wrong layer
//     boundary per `.claude/rules/lib-routines.md`).
//   - The home screen is one of several consumers
//     (settings debug screen, future widget-host
//     activity, etc.); keeping the drain logic in a
//     single widget avoids duplicating it.
//   - The widget is "passive" — when the queue is
//     empty, it renders nothing. No layout cost in
//     the steady state.
//
// v1.1 (SYS-082) wires `ActionOpenApp` end-to-end:
// the executor appends a `RoutineOpenAppRequest`,
// the banner pops the first request, pushes the
// route via the nearest `Navigator`, and clears
// the queue. The banner does not pop the back stack
// on its own; the pushed route is responsible for
// returning (and `WillPopScope` / `PopScope` on the
// pushed route is the caller's responsibility).
//
// Threading: the executor's pendingOpenApp is a
// `ValueListenable` on the root isolate; the banner
// reads it on the UI thread via `ValueListenableBuilder`.
// No streams, no `StreamSubscription` lifecycle to
// manage.

import 'package:flutter/material.dart';

import 'package:doit/routines/routine.dart';
import 'package:doit/routines/routine_executor.dart';
import 'package:doit/theme/app_theme.dart';

/// Drains [RoutineExecutor.pendingOpenApp] and pushes the
/// requested route via the nearest [Navigator]. Renders
/// `SizedBox.shrink()` when the queue is empty.
class RoutineBanner extends StatelessWidget {
  const RoutineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final executor = RoutineExecutor.instance;
    return ValueListenableBuilder<List<RoutineOpenAppRequest>>(
      valueListenable: executor.pendingOpenApp,
      builder: (context, queue, _) {
        if (queue.isEmpty) return const SizedBox.shrink();
        // Capture the [NavigatorState] synchronously,
        // inside the build pass. The post-frame callback
        // below runs after the frame has settled; if we
        // called `Navigator.of(context, ...)` there, a
        // teardown between build and post-frame would
        // throw "Looking up a deactivated widget's
        // ancestor is unsafe." [NavigatorState] is a
        // stable Element handle, so it remains valid for
        // the push even if this widget's element is no
        // longer mounted.
        final navigator = Navigator.of(context);
        // Drain synchronously after the build so we do
        // not call setState during build. The widget is
        // a StatelessWidget — the `pendingOpenApp`
        // ValueNotifier triggers the rebuild, and the
        // drain below mutates the same notifier.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Re-read inside the post-frame callback:
          // the queue may have changed again between
          // build and post-frame.
          final current = executor.pendingOpenApp.value;
          if (current.isEmpty) return;
          // Push each request in order. If a push
          // fails (no Navigator above us, e.g. during
          // teardown), swallow and continue.
          for (final req in current) {
            try {
              navigator.pushNamed(req.route);
            } on Object catch (_) {
              // No-op: the next consumer will re-drain
              // on the next frame.
            }
          }
          executor.clearPendingOpenApp();
        });
        // Render a thin informational banner. The
        // route is about to push; this gives the user
        // a moment of feedback that something is
        // happening.
        return Material(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.open_in_new,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    queue.length == 1
                        ? 'Opening routine destination…'
                        : 'Opening ${queue.length} routine destinations…',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
