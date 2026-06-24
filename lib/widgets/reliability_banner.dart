// Reliability banner — a small widget that shows the current
// alarm-system reliability state. Used on the home screen
// and the settings page.
//
// The banner is hidden when reliability is `optimal`. It
// shows a calm, brand-voice line ("Reminders may be late")
// when degraded, with an optional tap-to-fix deep link to
// the settings page.
//
// v1.3b / Phase 13 / SYS-112 / ADR-042: the banner now
// has two factories:
//
//   - `fromStream` — the recommended path; the banner
//     subscribes to the unified `ReliabilityService`
//     notifier and rebuilds on every state change. The
//     home screen and the settings page both use this
//     factory today.
//   - `fromService` — deprecated; kept for one cycle as a
//     thin shim so widget tests that constructed a banner
//     via the previous factory still work. Returns the
//     service's current value at build time and does NOT
//     rebuild on change. New code MUST use `fromStream`.

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/services/reliability_service.dart';
import 'package:doit/services/reminder_service.dart';
import 'package:doit/theme/app_theme.dart';

/// The visual surface for the reliability banner. Tap
/// behavior is configurable via [onTap]; if null, the
/// banner is non-interactive.
class ReliabilityBanner extends StatelessWidget {
  const ReliabilityBanner({super.key, required this.reliability, this.onTap});

  final Reliability reliability;
  final VoidCallback? onTap;

  /// v1.3b / Phase 13: the recommended entry point. Wraps a
  /// [ValueListenableBuilder] around
  /// [ReliabilityService.instance.notifier] so the banner
  /// rebuilds on every reliability change. The home screen
  /// and the settings page both use this entry point.
  ///
  /// Returns a [Widget] rather than a [ReliabilityBanner]
  /// because the subscription is owned by an internal
  /// [_StreamReliabilityBanner]; the rendered subtree is a
  /// [ReliabilityBanner] either way.
  static Widget fromStream({Key? key, VoidCallback? onTap}) {
    return _StreamReliabilityBanner(key: key, onTap: onTap);
  }

  /// Deprecated: reads the current reliability from the
  /// initialized [ReminderService] and rebuilds when the
  /// user changes a setting that affects it.
  ///
  /// `fromService` was the v1.3a entry point; it returned a
  /// `ReliabilityBanner` widget (not a builder), so a
  /// change to `scheduler.reliability` would not trigger a
  /// rebuild — the banner could be stale after a permission
  /// grant until something else caused a parent rebuild.
  /// The v1.3b banner uses [fromStream] instead.
  ///
  /// The factory is kept as a thin shim that returns a
  /// one-shot banner with the service's current value. New
  /// code MUST use [fromStream]; this entry point will be
  /// removed in v1.4.
  @Deprecated('Use ReliabilityBanner.fromStream instead.')
  factory ReliabilityBanner.fromService({Key? key, VoidCallback? onTap}) {
    return ReliabilityBanner(
      key: key,
      reliability: ReminderService.instance.scheduler.reliability,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (reliability == Reliability.optimal) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Reminder reliability degraded',
      button: onTap != null,
      child: Material(
        color: scheme.errorContainer,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    'Reminders may be late. Tap to fix.',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, color: scheme.onErrorContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// v1.3b / Phase 13: subscribes to
/// [ReliabilityService.instance.notifier] and rebuilds on
/// every reliability change. Used by [ReliabilityBanner.fromStream].
///
/// Defensive: if the service has not been initialized (a
/// widget test that exercises the settings screen without
/// wiring `ReliabilityService.init`), the banner renders
/// `optimal` (i.e. nothing) rather than throwing. This
/// matches the production first-read behavior — a missing
/// service is treated the same as a brand-new install.
class _StreamReliabilityBanner extends StatelessWidget {
  const _StreamReliabilityBanner({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    ValueListenable<Reliability> listenable;
    try {
      listenable = ReliabilityService.instance.notifier;
    } on StateError {
      return const ReliabilityBanner(reliability: Reliability.optimal);
    }
    return ValueListenableBuilder<Reliability>(
      valueListenable: listenable,
      builder: (_, reliability, _) {
        return ReliabilityBanner(reliability: reliability, onTap: onTap);
      },
    );
  }
}
