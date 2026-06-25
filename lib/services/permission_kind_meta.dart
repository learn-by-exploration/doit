// Per-PermissionKind metadata (title + icon + rationale).
//
// v1.2h / Phase 8: extracted from `permission_sheet.dart` so
// the per-automation reliability badge's
// `AlertDialog` (v1.2h) and `PermissionSheet` (v0.6) share
// one source of truth. Before this split the map was a
// private `_meta` constant inside the widget file; promoting
// it lets a non-widget caller (the dialog builder) render
// the same rationale copy the sheet does.
//
// v1.3c / Phase 14 / SYS-113 / ADR-043: adds the
// `fullScreenIntent` entry (the Android 14+ full-screen
// intent suppression permission). The rationale text is
// the user-facing explanation of why
// do it needs the permission. Keep it in sync with the
// onboarding step bodies in `lib/screens/onboarding.dart` —
// both should answer "what is this permission for?" in
// roughly the same words.

import 'package:flutter/material.dart';

import 'package:doit/services/permission_service.dart';

/// Title, icon, and rationale for a [PermissionKind]. Used
/// by both the on-demand `PermissionSheet` modal and the
/// per-automation reliability badge dialog.
@immutable
class PermissionKindMeta {
  const PermissionKindMeta({
    required this.title,
    required this.icon,
    required this.rationale,
  });

  /// Human-readable title shown in dialog headers and
  /// settings tile labels.
  final String title;

  /// Icon shown next to the title. Uses the same icon family
  /// as the rest of the app (Material Symbols outlined).
  final IconData icon;

  /// One-sentence user-facing explanation of why do it needs
  /// this permission. Shown verbatim in both the sheet and
  /// the badge dialog.
  final String rationale;
}

/// The canonical metadata for every [PermissionKind].
///
/// Source-of-truth — keep rationale text in sync with the
/// onboarding step bodies in `lib/screens/onboarding.dart`.
const Map<PermissionKind, PermissionKindMeta> permissionKindMeta =
    <PermissionKind, PermissionKindMeta>{
      PermissionKind.notifications: PermissionKindMeta(
        title: 'Notifications',
        icon: Icons.notifications_outlined,
        rationale:
            'do it sends a daily reminder for each do. Android asks for '
            'the notification permission once.',
      ),
      PermissionKind.contacts: PermissionKindMeta(
        title: 'Contacts',
        icon: Icons.contacts_outlined,
        rationale:
            'If you add a "cadence" do — call Mom every Sunday — do it '
            'reads the contact you pick. It never imports the whole address '
            'book.',
      ),
      PermissionKind.exactAlarm: PermissionKindMeta(
        title: 'Exact alarms',
        icon: Icons.alarm_outlined,
        rationale:
            'Exact alarms fire reminders on the minute, not up to 15 '
            'minutes late. If you decline, do it falls back to a '
            'best-effort schedule.',
      ),
      PermissionKind.batteryOptimization: PermissionKindMeta(
        title: 'Battery optimization',
        icon: Icons.battery_saver_outlined,
        rationale:
            'Allowing do it to run in the background ensures your '
            'reminders fire on time, even when your phone is in Doze mode.',
      ),
      PermissionKind.location: PermissionKindMeta(
        title: 'Location',
        icon: Icons.location_on_outlined,
        rationale:
            'do it uses your approximate location to fire "do X when I '
            'arrive at Y" routines. City-block accuracy is enough — '
            'your location is never stored or sent off the device.',
      ),
      PermissionKind.calendar: PermissionKindMeta(
        title: 'Calendar',
        icon: Icons.event_outlined,
        rationale:
            'do it reads your calendar event transitions so it can fire '
            '"do X when my meeting starts" routines. Read-only — do it '
            'never writes to your calendar.',
      ),
      PermissionKind.usageStats: PermissionKindMeta(
        title: 'Usage access',
        icon: Icons.query_stats_outlined,
        rationale:
            'Allows do it to fire "do X when I open app Y" routines. '
            'Android does not show a popup for this — you will need to '
            'toggle do it on in the next screen.',
      ),
      PermissionKind.callScreening: PermissionKindMeta(
        title: 'Call screening',
        icon: Icons.call_outlined,
        rationale:
            'Lets do it intercept incoming calls so it can silence the '
            'ringer on contacts you choose. Android will ask you to '
            'confirm do it as the call-screening app.',
      ),
      // v1.3c / Phase 14 / SYS-113 / ADR-043: Android 14+
      // suppresses full-screen launches from background
      // apps unless this permission is on. Without it, do
      // it shows a notification instead of the full-screen
      // mission screen. Mirrors the `PACKAGE_USAGE_STATS`
      // opt-in pattern (the user is never blocked from
      // using do it for declining).
      PermissionKind.fullScreenIntent: PermissionKindMeta(
        title: 'Full-screen access',
        icon: Icons.open_in_full,
        rationale:
            'On Android 14+, do it needs this permission to launch the '
            'full-screen mission screen when a strong-mode habit fires. '
            'Without it, you\'ll see a notification instead.',
      ),
    };
