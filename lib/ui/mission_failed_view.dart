// Mission-failed post-mortem dialog primitive.
//
// Shown after a mission does not complete (3rd wrong attempt
// for math/type missions, or a chain-abort from the launcher).
// Confirms to the user that their streak is intact (the user
// is NOT penalized for a mission fail) and provides a single
// "OK" CTA to dismiss.
//
// Per lib/ui/ invariants (see `.claude/rules/lib-services.md`
// and the design-system PRD):
//   - StatelessWidget, takes required `onDismiss` callback
//     so the caller controls how the dialog closes.
//   - Reads `AppLocalizations.of(context)` for the 3 strings
//     (missionFailedTitle / missionFailedBody / missionFailedDismiss).
//   - All colors from `Theme.of(context).colorScheme`.
//   - Wraps the dialog body in `Semantics(liveRegion: true,
//     label: ...)` so TalkBack announces the failure as soon
//     as the dialog opens (the C9-1 a11y gap that math/type
//     had pre-PR11).
//
// Test surface (see `test/ui/mission_failed_view_test.dart`):
//   - renders the localized title + body verbatim
//   - renders the localized dismiss CTA
//   - tapping the CTA fires onDismiss
//   - liveRegion Semantics wraps the body so TalkBack speaks
//   - theme integration (works under light theme too)
//   - the dialog is `AlertDialog` type (M3 canonical modal)

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// The post-mortem dialog shown when a mission does not
/// complete. Render via `showDialog` with a `void` return
/// type, with a builder that constructs a `MissionFailedView`
/// passing `onDismiss`.
///
/// The dialog confirms the streak is intact and gives the
/// user a single "OK" CTA to dismiss.
class MissionFailedView extends StatelessWidget {
  const MissionFailedView({super.key, required this.onDismiss});

  /// Callback invoked when the user taps the dismiss CTA.
  /// Typically closes the dialog via `Navigator.of(context).pop()`.
  /// Required so the caller controls the dialog lifecycle.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      // The canonical M3 modal shape — works on every screen
      // size and is the expected visual treatment for
      // "your action did not succeed" alerts.
      title: Text(l.missionFailedTitle),
      content: Semantics(
        // liveRegion so TalkBack announces the body when the
        // dialog opens. Without this, the user on a screen
        // reader would only hear the dialog chrome — not the
        // critical "your streak is intact" reassurance.
        liveRegion: true,
        label: '${l.missionFailedTitle}. ${l.missionFailedBody}',
        child: Text(l.missionFailedBody),
      ),
      actions: [
        FilledButton(
          // Canonical primary CTA. The mission-failed dialog
          // has exactly one action so we skip the secondary
          // `TextButton` and use FilledButton directly.
          key: const ValueKey('mission_failed.dismiss'),
          onPressed: onDismiss,
          child: Text(l.missionFailedDismiss),
        ),
      ],
    );
  }
}
