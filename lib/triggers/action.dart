// Action sealed hierarchy — the "then" half of the
// Trigger / Condition / Action spine.
//
// Per the Phase C PR 1 spec, there are five concrete leaves:
//
//   - ActionNotify           — show a local notification.
//   - ActionFullscreen       — wake the screen with the
//                              full-screen-intent activity.
//   - ActionCallIntercept    — answer / dismiss an incoming
//                              call (Phase F).
//   - ActionOverrideSilent   — toggle the device's silent
//                              mode (Phase F).
//   - ActionOpenApp          — open a route in the app
//                              (Phase D+).
//
// Layer rules (per .claude/rules/):
//   - No Flutter imports. Models are pure Dart.
//   - The `RoutineExecutor` (lib/routines/) is the only
//     consumer of the exhaustive `switch (action)` form.

import 'package:doit/triggers/trigger.dart' show SilentMode;
import 'package:meta/meta.dart';

/// Sealed base for the five action kinds. Add a new action
/// by adding a new subclass here (and a corresponding case in
/// `RoutineExecutor.dispatch`).
@immutable
sealed class Action {
  const Action();

  /// Validates the action's invariants. Pure.
  Action validate();
}

/// Show a local notification with [title] and [body]. Routes
/// to `NotificationService.instance.show(...)` in the
/// executor.
@immutable
final class ActionNotify extends Action {
  const ActionNotify({required this.title, required this.body});

  final String title;
  final String body;

  @override
  ActionNotify validate() {
    if (title.trim().isEmpty) throw const ActionNotifyEmptyTitle();
    if (body.trim().isEmpty) throw const ActionNotifyEmptyBody();
    return this;
  }

  @override
  bool operator ==(Object other) =>
      other is ActionNotify && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(title, body);
}

/// Wake the screen with the full-screen-intent activity.
/// Wires to `lib/reminders/full_screen_intent.dart` in PR C2.
@immutable
final class ActionFullscreen extends Action {
  const ActionFullscreen();

  @override
  ActionFullscreen validate() => this;
}

/// Answer or dismiss an incoming call (Phase F). PR C1 ships
/// the shape; the executor arm throws `UnimplementedError`.
@immutable
final class ActionCallIntercept extends Action {
  const ActionCallIntercept({required this.decision});

  /// What the executor should do with the call.
  final CallInterceptDecision decision;

  @override
  ActionCallIntercept validate() => this;

  @override
  bool operator ==(Object other) =>
      other is ActionCallIntercept && other.decision == decision;

  @override
  int get hashCode => decision.hashCode;
}

/// Override the device's silent mode for the matched contact.
/// Phase F. PR C1 ships the shape.
@immutable
final class ActionOverrideSilent extends Action {
  const ActionOverrideSilent({required this.targetMode});

  final SilentMode targetMode;

  @override
  ActionOverrideSilent validate() => this;

  @override
  bool operator ==(Object other) =>
      other is ActionOverrideSilent && other.targetMode == targetMode;

  @override
  int get hashCode => targetMode.hashCode;
}

/// Open the app to a specific route (e.g., `/do/<id>`).
/// Phase D+. PR C1 ships the shape.
@immutable
final class ActionOpenApp extends Action {
  const ActionOpenApp({required this.route});

  /// Route path (without leading slash). Examples:
  ///   - `do/<id>`       — open a do detail
  ///   - `event/<id>`    — open an event detail
  ///   - `person/<id>`   — open a person detail
  final String route;

  @override
  ActionOpenApp validate() {
    if (route.trim().isEmpty) throw const ActionOpenAppEmptyRoute();
    return this;
  }

  @override
  bool operator ==(Object other) =>
      other is ActionOpenApp && other.route == route;

  @override
  int get hashCode => route.hashCode;
}

/// What `ActionCallIntercept` does to the incoming call.
enum CallInterceptDecision {
  /// Decline (REJECT) the call without ringing.
  decline,

  /// Decline and send a pre-defined SMS reply ("Busy, will
  /// call back"). Phase F only.
  declineWithAutoReply,

  /// Silence the ring (mute) but leave the call incoming.
  mute,
}

// ---------------------------------------------------------------------------
// Validation exceptions.
// ---------------------------------------------------------------------------

@immutable
sealed class ActionValidationException implements Exception {
  const ActionValidationException(this.message);
  final String message;

  @override
  String toString() => 'ActionValidationException: $message';
}

final class ActionNotifyEmptyTitle extends ActionValidationException {
  const ActionNotifyEmptyTitle() : super('title must be non-empty (trimmed).');
}

final class ActionNotifyEmptyBody extends ActionValidationException {
  const ActionNotifyEmptyBody() : super('body must be non-empty (trimmed).');
}

final class ActionOpenAppEmptyRoute extends ActionValidationException {
  const ActionOpenAppEmptyRoute() : super('route must be non-empty.');
}
