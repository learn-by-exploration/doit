// LocationPicker — modal bottom sheet that builds an
// [Automation] with a `TriggerLocationEnter` (or Exit) and a
// default [ActionNotify] for the entity the user is editing.
//
// Per v1.0 Phase C PR 2 (ADR-021, SYS-076):
//   - Coarse location only (no FINE; we don't store or send
//     the user's position).
//   - "Use current location" button calls
//     `Geolocator.getCurrentPosition()` only when the
//     permission is granted.
//   - No map widget — the user pastes coordinates (looked up
//     on a third-party map) or uses the device's current
//     position. A real map lands in a v1.1 follow-up.
//   - The sheet gates on `Permission.location` via the
//     shared `PermissionSheet` (SYS-067 / ADR-014) before
//     any platform call.
//
// The returned [Automation] has:
//   - `trigger`: TriggerLocationEnter or TriggerLocationExit
//     (user choice via radio)
//   - `action`:  ActionNotify(title, body) — the title is
//     derived from the entity name by the caller (this
//     widget does not know the entity name; it uses the
//     label as both the trigger label and the notification
//     body so the test surface is self-contained).
//   - `enabled`: true
//
// Pure-Dart validation: lat ∈ [-90, 90], lon ∈ [-180, 180],
// radius ∈ [50, 5000]. Validation errors surface inline;
// the "Save" button is gated on a clean form.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'package:doit/routines/routine.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:doit/widgets/location_map_preview.dart';
import 'package:doit/widgets/permission_sheet.dart';

/// Static facade. Mirrors the `PermissionSheet.show(...)`
/// pattern (lib/widgets/permission_sheet.dart). Callers do:
/// ```
/// final auto = await LocationPicker.show(context);
/// if (auto != null) setState(() => _automations.add(auto));
/// ```
class LocationPicker {
  const LocationPicker._();

  /// Show the sheet. Returns:
  ///   - `Automation` on a successful save.
  ///   - `null` if the user cancels, dismisses the sheet,
  ///     denies the permission gate, or fails validation
  ///     after re-entry.
  static Future<Automation?> show(BuildContext context) async {
    // Gate on ACCESS_COARSE_LOCATION. The on-demand sheet
    // is the only seam for runtime permission requests in
    // v1.0 (lib-screens.md / ADR-014). We do NOT call
    // Geolocator.requestPermission directly — the gate is
    // the single place where the rationale + system dialog
    // surface.
    final granted = await PermissionSheet.show(
      context,
      PermissionKind.location,
    );
    if (!granted) return null;
    if (!context.mounted) return null;
    return showModalBottomSheet<Automation>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _LocationPickerSheet(),
    );
  }
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet();

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();
  double _radiusMeters = 100;
  bool _enter = true; // true = TriggerLocationEnter, false = Exit
  bool _busyCurrent = false;
  String? _currentError;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _busyCurrent = true;
      _currentError = null;
    });
    try {
      // The permission was already granted at the sheet
      // gate; we still re-check defensively because the
      // user can revoke between the gate and this tap.
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _currentError = 'Location permission was denied.';
          _busyCurrent = false;
        });
        return;
      }
      // bestForNavigation is the closest match to
      // "give me a fresh fix". Coarse accuracy is
      // sufficient — the trigger model bounds the radius
      // at 50 m, well above the coarse accuracy floor
      // (~2 km on Android).
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lonCtrl.text = pos.longitude.toStringAsFixed(6);
        _busyCurrent = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentError = 'Could not read location: $e';
        _busyCurrent = false;
      });
    }
  }

  void _save() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final lat = double.parse(_latCtrl.text.trim());
    final lon = double.parse(_lonCtrl.text.trim());
    final radius = _radiusMeters.round();
    final label = _labelCtrl.text.trim();
    final geofenceId = 'g_${DateTime.now().microsecondsSinceEpoch}';
    final trigger = _enter
        ? TriggerLocationEnter(
            geofenceId: geofenceId,
            label: label,
            latitude: lat,
            longitude: lon,
            radiusMeters: radius,
          )
        : TriggerLocationExit(
            geofenceId: geofenceId,
            label: label,
            latitude: lat,
            longitude: lon,
            radiusMeters: radius,
          );
    final automation = Automation(
      trigger: trigger,
      action: ActionNotify(
        // The notification title is the trigger label so
        // "arrive at Home" → notification "Home". The body
        // is a static "Routine fired" copy; the caller
        // (add-habit / add-event / add-person) can re-save
        // the automation to override the copy later.
        title: label,
        body: 'Routine fired: $label',
      ),
    );
    Navigator.of(context).pop(automation);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.md,
        Spacing.md + viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        // The form can be taller than the bottom sheet's
        // intrinsic height on small phones (the radius
        // slider + radio group + buttons add up). Wrap in
        // a SingleChildScrollView so the user can scroll
        // down to Cancel / Save, and so widget tests with a
        // small viewport can `ensureVisible` the buttons.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Location trigger', style: theme.textTheme.titleLarge),
              const SizedBox(height: Spacing.xs),
              Text(
                'Fire when you enter or leave a place. Coarse accuracy '
                'only — your exact location is never stored or sent.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: Spacing.md),
              TextFormField(
                key: const ValueKey('location_picker.label'),
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'Home, Office, Gym…',
                ),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('location_picker.latitude'),
                      controller: _latCtrl,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
                      ],
                      // Re-render so the v1.1e map preview pin
                      // follows the typed coordinates.
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final d = double.tryParse(v.trim());
                        if (d == null) return 'Not a number';
                        if (d < -90 || d > 90) return '−90..90 only';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('location_picker.longitude'),
                      controller: _lonCtrl,
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
                      ],
                      // Re-render so the v1.1e map preview pin
                      // follows the typed coordinates.
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final d = double.tryParse(v.trim());
                        if (d == null) return 'Not a number';
                        if (d < -180 || d > 180) return '−180..180 only';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              // v1.1e (SYS-084 / ADR-028): offline map preview.
              // Renders the picked (lat, lon) as a pin on a
              // stylised world canvas. Tapping the canvas
              // moves the pin and writes back to the lat / lon
              // controllers, so the picker form and the preview
              // stay in sync without a network tile fetch (the
              // no-network baseline from `lib-services.md`).
              LocationMapPreview(
                latitude: double.tryParse(_latCtrl.text.trim()) ?? 0,
                longitude: double.tryParse(_lonCtrl.text.trim()) ?? 0,
                radiusMeters: _radiusMeters,
                onLatLonChanged: (lat, lon) {
                  _latCtrl.text = lat.toStringAsFixed(6);
                  _lonCtrl.text = lon.toStringAsFixed(6);
                  setState(() {});
                },
              ),
              const SizedBox(height: Spacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('location_picker.use_current'),
                  onPressed: _busyCurrent ? null : _useCurrentLocation,
                  icon: _busyCurrent
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: const Text('Use current location'),
                ),
              ),
              if (_currentError != null) ...[
                const SizedBox(height: Spacing.xs),
                Text(
                  _currentError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: Spacing.sm),
              Text(
                'Radius: ${_radiusMeters.round()} m',
                style: theme.textTheme.bodyMedium,
              ),
              Slider(
                key: const ValueKey('location_picker.radius'),
                min: 50,
                max: 500,
                divisions: 9,
                value: _radiusMeters,
                label: '${_radiusMeters.round()} m',
                onChanged: (v) => setState(() => _radiusMeters = v),
              ),
              const SizedBox(height: Spacing.sm),
              Text('Event', style: theme.textTheme.bodyMedium),
              RadioGroup<bool>(
                groupValue: _enter,
                onChanged: (v) {
                  if (v != null) setState(() => _enter = v);
                },
                child: const Column(
                  children: [
                    RadioListTile<bool>(
                      key: ValueKey('location_picker.event_enter'),
                      title: Text('On enter'),
                      value: true,
                    ),
                    RadioListTile<bool>(
                      key: ValueKey('location_picker.event_exit'),
                      title: Text('On exit'),
                      value: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const ValueKey('location_picker.cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Spacing.sm),
                  FilledButton(
                    key: const ValueKey('location_picker.save'),
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
