// Canonical snackbar wrapper for the doit design system.
//
// Per UI_ORG_AUDIT.md C4 (form patterns), the screen / widget
// layer SHOULD NOT inline `ScaffoldMessenger.of(context)
// .showSnackBar(SnackBar(content: Text(...)))` — that
// pattern recurs across 8+ screens with no semantic
// distinction between "error" and "info" tones, no consistent
// foreground color, and no canonical duration.
//
// This module exposes two static helpers:
//
//   - [AppSnack.showError] — for user-actionable errors
//     (validation failures, missing input, operation failures).
//     Uses the M3 canonical `errorContainer` background +
//     `onErrorContainer` text — subtle red tint that reads as
//     "something went wrong" without the heavy
//     `colorScheme.error` saturation.
//
//   - [AppSnack.showInfo] — for informational acknowledgments
//     (template saved, "no other dos to anchor on", "marked as
//     up"). Uses the M3 default styling (`inverseSurface`
//     background + `onInverseSurface` text).
//
// Both helpers are `static`; the class is not instantiable.
//
// PR8 of 15 (UI consolidation). See SYS-174 / ADR-105 / WF-102.

import 'package:flutter/material.dart';

/// Canonical snackbar wrapper. Use [showError] for
/// user-actionable errors and [showInfo] for informational
/// acknowledgments.
///
/// **Usage rule (per UI_ORG_AUDIT.md C4):**
/// - **DO** call `AppSnack.showError(context, msg)` /
///   `AppSnack.showInfo(context, msg)` from the screen +
///   widget layer.
/// - **DO NOT** inline
///   `ScaffoldMessenger.of(context).showSnackBar(...)` outside
///   this file. The two helpers are the canonical entry
///   point; the visual treatment (error vs info) is the
///   design-intent signal.
///
/// Both helpers are no-ops on a detached context (the
/// `ScaffoldMessenger.of(context)` call will throw if no
/// `Scaffold` ancestor is in the tree; callers should still
/// perform the standard `if (!mounted) return;` check before
/// invoking, just like the inlined `ScaffoldMessenger` calls
/// they replace).
class AppSnack {
  AppSnack._();

  /// Shows an error-tone snackbar with the M3 canonical
  /// `errorContainer` background + `onErrorContainer` text.
  ///
  /// Use for user-actionable errors: validation failures
  /// (e.g. "Give the event a name first."), missing input
  /// (e.g. "No other dos to anchor on."), operation failures
  /// (e.g. "Delete failed. Please try again.", "Template
  /// validation failed: ...").
  static void showError(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        backgroundColor: scheme.errorContainer,
      ),
    );
  }

  /// Shows an info/success-tone snackbar with the M3 default
  /// styling (`inverseSurface` background + `onInverseSurface`
  /// text).
  ///
  /// Use for informational acknowledgments: "Template saved",
  /// "Marked as up", "Already up — see you in a few hours.",
  /// and any other "the system did a thing, just letting you
  /// know" notification.
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
