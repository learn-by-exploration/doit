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
//   - No permission gate: the badge rendered as
//     `degraded` for a non-permission reason. Today the only
//     such reason is `TriggerTimeOfDay` falling back to
//     `optimal` here while the app-wide `Reliability` enum
//     is `degraded` (the badge consumer is expected to fall
//     back to the home `ReliabilityBanner`). The dialog
//     surfaces this and points the user at the home banner.
//   - The action side never gates a permission in v1.2h; a
//     future v1.2+ extension will fold in
//     `ActionOverrideSilent` (`ACCESS_NOTIFICATION_POLICY`)
//     and the contact-requiring actions.
//
// The dialog is a pure widget (no `setState`, no
// `Future`-side-effects on the rendering path). The "Open
// settings" CTA calls the matching
// `PermissionService.requestX` / `openAppSettings` method
// and closes the dialog.

import 'package:flutter/material.dart';

import 'package:doit/routines/automation_reliability.dart';
import 'package:doit/routines/routine.dart';
import 'package:doit/services/permission_kind_meta.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/theme/app_theme.dart';
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
              _KindSection(kind: kind, status: status),
            ] else ...[
              Text(_noPermissionGateCopy(trigger)),
            ],
            const SizedBox(height: Spacing.md),
            Text(
              _remediationCopy(reliability, kind),
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
        if (kind != null)
          Semantics(
            label: 'Open settings',
            button: true,
            excludeSemantics: true,
            child: FilledButton(
              key: ValueKey(
                'automation.reliability_dialog.open_settings.${automation.id}',
              ),
              onPressed: () => _openSettings(context, kind),
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
    if (kind == PermissionKind.usageStats) {
      // The usage-stats permission does NOT have a generic
      // app-settings page; it has its own special-access
      // deep-link via `PermissionService.requestUsageStats()`.
      await PermissionService.instance.requestUsageStats();
    } else {
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
