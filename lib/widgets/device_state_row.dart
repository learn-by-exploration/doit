// Device-state live dashboard — Settings → Device state.
//
// v1.0 / Phase D PR 2 / ADR-022. A read-only row that
// reflects the current `DeviceStateSnapshot` published by
// the [DeviceStateService]. The row subscribes to the
// service's broadcast stream and re-renders on every
// snapshot, so a freshly-inserted USB cable or a power
// disconnect is visible without a settings-page reload.
//
// The row is intentionally minimal:
//   - "Battery: 80%, charging"
//   - "Headphones: connected" (or "no headphones")
//   - "Screen: on" (or "off")
//   - "Last updated: HH:MM:SS" (the snapshot's `at` field)
//
// No action buttons — the row is diagnostic. Power users
// who want to fire a routine on these states configure
// `TriggerDeviceState` automations on a Do/Event/Person;
// this row is the "is the platform source alive" view.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:doit/services/device_state_probe.dart';

class DeviceStateRow extends StatefulWidget {
  const DeviceStateRow({super.key});

  @override
  State<DeviceStateRow> createState() => _DeviceStateRowState();
}

class _DeviceStateRowState extends State<DeviceStateRow> {
  DeviceStateSnapshot? _latest;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // Best-effort: start the service. If init() is already
    // done by the orchestrator, this is a no-op. If it
    // hasn't been called yet (the user navigated here on a
    // cold start), we don't block on it — the stream will
    // start pushing snapshots as soon as `init()` resolves
    // and the source publishes its baseline.
    unawaited(_bind());
  }

  Future<void> _bind() async {
    try {
      await DeviceStateService.instance.init();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeviceStateSnapshot>(
      stream: DeviceStateService.instance.events,
      initialData: _latest,
      builder: (context, snap) {
        if (_error != null) {
          return ListTile(
            key: const ValueKey('settings.device_state.error'),
            leading: const Icon(Icons.error_outline),
            title: const Text('Device state unavailable'),
            subtitle: Text('$_error'),
          );
        }
        final s = snap.data;
        return ListTile(
          key: const ValueKey('settings.device_state'),
          leading: const Icon(Icons.electrical_services_outlined),
          title: const Text('Device state'),
          subtitle: s == null
              ? const Text('Waiting for first snapshot...')
              : Text(_format(s)),
          trailing: s == null
              ? null
              : Text(
                  _time(s.at),
                  key: const ValueKey('settings.device_state.at'),
                ),
        );
      },
    );
  }

  String _format(DeviceStateSnapshot s) {
    final battery = 'Battery: ${s.batteryPercent}%';
    final charging = s.isCharging ? ', charging' : '';
    final hp = s.headphonesConnected
        ? 'Headphones: connected. '
        : 'No headphones. ';
    final screen = s.screenOn ? 'Screen: on.' : 'Screen: off.';
    return '$battery$charging. $hp$screen';
  }

  String _time(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }
}
