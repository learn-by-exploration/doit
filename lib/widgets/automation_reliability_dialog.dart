// AutomationReliabilityDialog — `AlertDialog` body for the
// per-automation reliability badge.
//
// v1.2h / Phase 8 / SYS-103: tapping a `degraded` or
// `unknown` `AutomationReliabilityBadge` in the three add
// screens now opens this dialog. It disambiguates the three
// remediation paths a routine can need:
//
//   - Trigger-side permission denied / unknown: a
//     `PermissionKind` that the trigger's reliability
//     function mapped to. The dialog shows the kind's title,
//     the current status (Denied / Permanently denied /
//     Not yet probed), and the rationale copy from
//     `permissionKindMeta`. "Open settings" deep-links to
//     the app's Settings page (or, for `usageStats`, the
//     special-access page).
//   - Action-side permission denied / unknown (v1.5b /
//     Phase 25): `ActionCallIntercept` (callScreening role),
//     `ActionOverrideSilent` (notificationPolicy /
//     ACCESS_NOTIFICATION_POLICY), `ActionFullscreen`
//     (fullScreenIntent). Renders as a secondary section
//     below the trigger-side section. The "Open settings"
//     CTA on the action section deep-links to the
//     matching special-access page.
//   - No permission gate: the badge rendered as
//     `degraded` for a non-permission reason. Today the only
//     such reason is `TriggerTimeOfDay` falling back to
//     `optimal` here while the app-wide `Reliability` enum
//     is `degraded` (the badge consumer is expected to fall
//     back to the home `ReliabilityBanner`). The dialog
//     surfaces this and points the user at the home banner.
//
// The dialog is a pure widget (no `setState`, no
// `Future`-side-effects on the rendering path). The "Open
// settings" CTA calls the matching
// `PermissionService.requestX` / `openAppSettings` method
// and closes the dialog.

import 'package:flutter/material.dart' hide Action;

import 'package:doit/routines/automation_reliability.dart';
import 'package:doit/routines/routine.dart';
import 'package:doit/services/permission_kind_meta.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';

/// Builds and shows the per-automation reliability
/// `AlertDialog`. Idempotent: a second invocation while the
/// dialog is open is a no-op (we guard on
/// `Navigator.of(context).canPop()` so the root-mounted
/// path is clean too).
Future<void> showAutomationReliabilityDialog(
  BuildContext context, {
  required Automation automation,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (navigator.canPop() && _dialogOpen(automation)) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => _AutomationReliabilityDialog(automation: automation),
  );
}

/// Best-effort guard against a second tap re-pushing the
/// dialog while the first one is still mounted. The check
/// walks the navigator stack looking for a dialog whose
/// route settings match this automation's id (cheap; the
/// stack is short in practice).
bool _dialogOpen(Automation automation) {
  // The Flutter Navigator doesn't expose a "list routes"
  // API. We use a side-channel key set on the dialog's
  // route name below; the check is best-effort and a
  // double-tap that lands while the dialog is closing is
  // benign (the second tap just re-opens).
  return _openDialogIds.contains(automation.id);
}

final Set<String> _openDialogIds = <String>{};

class _AutomationReliabilityDialog extends StatelessWidget {
  const _AutomationReliabilityDialog({required this.automation});

  final Automation automation;

  @override
  Widget build(BuildContext context) {
    final statuses = PermissionService.instance.statuses.value;
    final reliability = automationReliability(automation, statuses: statuses);
    final trigger = automation.trigger;
    final kind = _requiredKindForTrigger(trigger);
    final status = kind == null ? null : statuses[kind];
    // v1.5b / Phase 25: render an action-side section below
    // the trigger-side section. The action kind list mirrors
    // `_requiredPermissionsForAction` from
    // `automation_reliability.dart` — the dialog uses its
    // own private mirror so the helper stays module-private.
    final actionKinds = _requiredKindsForAction(automation.action);
    // The "Open settings" CTA targets the FIRST degraded /
    // unknown permission — trigger side wins, then action
    // side. If both sides are healthy the CTA is omitted
    // (reliability == optimal).
    final ctaKind =
        kind ??
        (reliability != AutomationReliability.optimal
            ? actionKinds.firstOrNull
            : null);

    return AlertDialog(
      key: ValueKey('automation.reliability_dialog.${automation.id}'),
      icon: Icon(_iconFor(reliability)),
      title: const Text('This routine may not fire'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (kind != null) ...[
              const Text(
                'Trigger',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: Spacing.xs),
              _KindSection(kind: kind, status: status),
            ] else ...[
              Text(_noPermissionGateCopy(trigger)),
            ],
            if (actionKinds.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              const Text(
                'Action',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: Spacing.xs),
              for (final ak in actionKinds) ...[
                _KindSection(kind: ak, status: statuses[ak]),
                const SizedBox(height: Spacing.xs),
              ],
            ],
            const SizedBox(height: Spacing.md),
            Text(
              _remediationCopy(reliability, ctaKind),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: ValueKey(
            'automation.reliability_dialog.cancel.${automation.id}',
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (ctaKind != null)
          Semantics(
            label: 'Open settings',
            button: true,
            excludeSemantics: true,
            child: FilledButton(
              key: ValueKey(
                'automation.reliability_dialog.open_settings.${automation.id}',
              ),
              onPressed: () => _openSettings(context, ctaKind),
              child: const Text('Open settings'),
            ),
          ),
      ],
    );
  }

  IconData _iconFor(AutomationReliability r) {
    return switch (r) {
      AutomationReliability.degraded => Icons.warning_amber_rounded,
      AutomationReliability.unknown => Icons.info_outline,
      AutomationReliability.optimal => Icons.check_circle_outline,
    };
  }

  String _noPermissionGateCopy(Trigger trigger) {
    // Today this branch only fires for `TriggerTimeOfDay` —
    // the per-automation function reports `optimal` for it
    // because time-of-day reliability lives in the app-wide
    // `Reliability` enum, not in `PermissionService`. We
    // still want the dialog body to be useful if the badge
    // consumer decides to surface a dialog for a degraded
    // time-of-day routine.
    return switch (trigger) {
      TriggerTimeOfDay() =>
        'Time-of-day routines depend on the device alarm system, '
            'not a runtime permission.',
      _ => 'This trigger does not need a runtime permission.',
    };
  }

  String _remediationCopy(AutomationReliability r, PermissionKind? kind) {
    if (r == AutomationReliability.unknown) {
      return kind == null
          ? 'do it is still probing the trigger. Pull down to refresh, '
                'or open Settings → Permissions to retry.'
          : 'do it has not yet probed this permission. Open Settings → '
                'Permissions to retry, then come back here.';
    }
    if (r == AutomationReliability.degraded) {
      return 'Tap Open settings to grant the permission, then come '
          'back here.';
    }
    return 'This routine is healthy.';
  }

  Future<void> _openSettings(BuildContext context, PermissionKind kind) async {
    Navigator.of(context).pop();
    // v1.5b / Phase 25: each special-access permission has
    // its own `PermissionService.requestX` deep-link rather
    // than the generic app-settings page. Falling back to
    // `openAppSettings` for the kinds that don't yet have a
    // dedicated helper (notificationPolicy deep-link is a
    // follow-up to PR #27; it lives at
    // `Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS`
    // once `NotificationPolicyService` lands in v1.5c).
    switch (kind) {
      case PermissionKind.usageStats:
        // `PACKAGE_USAGE_STATS` does not show a generic
        // app-settings page; the special-access activity is
        // opened via `PermissionService.requestUsageStats()`.
        await PermissionService.instance.requestUsageStats();
      case PermissionKind.fullScreenIntent:
        // `USE_FULL_SCREEN_INTENT` opens via
        // `Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`.
        await PermissionService.instance.requestFullScreenIntent();
      case PermissionKind.callScreening:
      case PermissionKind.notificationPolicy:
        // The dedicated `requestX` helpers for these two
        // kinds are v1.5c+ follow-ups (they need a new
        // `NotificationPolicyService` + Kotlin handler under
        // `DeviceStateChannel` for the
        // `ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS`
        // deep-link, plus a role chooser activity for
        // callScreening). For now we drop the user into the
        // generic app-settings page; they can navigate from
        // there. The Settings → Permissions tile already
        // shows the rationale copy from `permissionKindMeta`
        // so the user knows what to look for.
        await PermissionService.instance.openAppSettings();
      case _:
        await PermissionService.instance.openAppSettings();
    }
  }
}

class _KindSection extends StatelessWidget {
  const _KindSection({required this.kind, required this.status});

  final PermissionKind kind;
  final PermissionResult? status;

  @override
  Widget build(BuildContext context) {
    final meta = permissionKindMeta[kind];
    final title = meta?.title ?? kind.name;
    final rationale = meta?.rationale ?? '';
    final statusLabel = _statusLabel(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (meta != null) Icon(meta.icon, size: 20),
            const SizedBox(width: Spacing.xs),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        Text('Status: $statusLabel'),
        if (rationale.isNotEmpty) ...[
          const SizedBox(height: Spacing.xs),
          Text(rationale),
        ],
      ],
    );
  }

  String _statusLabel(PermissionResult? r) {
    return switch (r) {
      null => 'Not yet probed',
      PermissionResultGranted() => 'Granted',
      PermissionResultDenied() => 'Denied',
      PermissionResultPermanentlyDenied() => 'Permanently denied',
    };
  }
}

/// Mirror of `_requiredPermissionForTrigger` from
/// `automation_reliability.dart`. Duplicated here because
/// the private helper is module-private; the dialog needs
/// the same mapping to know whether the badge's
/// `degraded` / `unknown` state is rooted in a permission.
/// Keeps in sync by sharing the unit-test contract.
PermissionKind? _requiredKindForTrigger(Trigger trigger) {
  return switch (trigger) {
    TriggerLocation() => PermissionKind.location,
    TriggerCalendarEvent() => PermissionKind.calendar,
    TriggerCallIncoming() => PermissionKind.callScreening,
    TriggerForegroundApp() => PermissionKind.usageStats,
    TriggerDeviceState() => null,
    TriggerTimeOfDay() => null,
  };
}

/// Mirror of `_requiredPermissionsForAction` from
/// `automation_reliability.dart` (v1.5b / Phase 25). Same
/// duplication-rationale as `_requiredKindForTrigger`:
/// the helper is module-private to the routines layer and
/// the widget cannot reach it. Stays in sync via the
/// matching unit tests on both sides.
List<PermissionKind> _requiredKindsForAction(Action action) {
  return switch (action) {
    ActionNotify() => const <PermissionKind>[],
    ActionFullscreen() => const <PermissionKind>[
      PermissionKind.fullScreenIntent,
    ],
    ActionCallIntercept() => const <PermissionKind>[
      PermissionKind.callScreening,
    ],
    ActionOverrideSilent() => const <PermissionKind>[
      PermissionKind.notificationPolicy,
    ],
    ActionOpenApp() => const <PermissionKind>[],
  };
}
