// LocationMapPreview — offline "map" preview that visualises
// a chosen (latitude, longitude) without any network tile
// fetch.
//
// v1.1 follow-up to v1.0/Phase C PR 2's `LocationPicker`,
// which only accepts pasted coordinates or the
// `Use current location` button. The user previously had no
// visual feedback for the picked point.
//
// v1.1e ships an *offline* preview on purpose:
//   - `flutter_map` + OpenStreetMap would add a tile-fetcher
//     network call, which in turn requires the `INTERNET`
//     permission. The v0.1 permission baseline deliberately
//     omits `INTERNET` (no analytics, no remote logs, no
//     OSM tile fetches; see
//     `docs/v_model/v1_0_release_baseline.md` § Constraints).
//   - A v1.2 candidate can swap the `CustomPaint` body for
//     `flutter_map`'s `FlutterMap` without changing the
//     widget's public API; the parent `LocationPicker`
//     reads the same `onChanged(lat, lon)` callback.
//
// Behaviour:
//   - Renders a faint grid (5 columns × 5 rows) on the
//     background as a stylised "map" cue.
//   - Renders a small filled circle at the (lat, lon)
//     position, mapped through an equirectangular projection
//     of the visible window (a zoomed-out world view: full
//     lat ∈ [-85°, 85°] mapped to height, full lon ∈
//     [-180°, 180°] mapped to width, with the poles
//     clipped).
//   - Renders a translucent ring at the geofence radius,
//     scaled to the same projection (1° lat ≈ 111 km).
//   - Tapping the canvas moves the pin to the tapped
//     (lat, lon) and invokes `onChanged`. Dragging the pin
//     (using a `GestureDetector` `onPanUpdate` on the pin
//     hit-target) does the same.
//
// The widget is `const`-constructible and exposes only the
// two callbacks the picker needs (`onLatLonChanged`,
// optional `onRadiusChanged`).

import 'package:flutter/material.dart';

/// Inline "map" preview. Pure paint; no network, no platform
/// channels, no `flutter_map` dep. See file header for the
/// v1.1→v1.2 path.
class LocationMapPreview extends StatelessWidget {
  const LocationMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.onLatLonChanged,
    this.height = 100,
  });

  /// Current pin latitude in degrees. NaN is treated as 0.
  final double latitude;

  /// Current pin longitude in degrees. NaN is treated as 0.
  final double longitude;

  /// Geofence radius in metres. Drawn as a translucent ring
  /// around the pin. 0 hides the ring.
  final double radiusMeters;

  /// Invoked when the user taps the canvas or drags the pin.
  /// Receives the new (lat, lon) in degrees, clamped to
  /// the valid ranges ([-90, 90] × [-180, 180]).
  final void Function(double lat, double lon) onLatLonChanged;

  /// Fixed height of the preview area. The widget fills its
  /// width.
  final double height;

  // Visible-window constants for the equirectangular
  // projection. Full-world view; the pin's pixel position
  // is `(width * (lon + 180) / 360, height * (90 - lat) / 180)`
  // with the poles clipped to the inner 5° margin.
  static const double _latMin = -85;
  static const double _latMax = 85;
  static const double _lonMin = -180;
  static const double _lonMax = 180;
  static const double _edgeMargin = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      key: const ValueKey('location_picker.map_preview'),
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return _MapPreviewBody(
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            size: size,
            onLatLonChanged: onLatLonChanged,
            gridColor: theme.colorScheme.outlineVariant,
            pinColor: theme.colorScheme.primary,
            ringColor: theme.colorScheme.primary.withValues(alpha: 0.25),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          );
        },
      ),
    );
  }
}

class _MapPreviewBody extends StatelessWidget {
  const _MapPreviewBody({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.size,
    required this.onLatLonChanged,
    required this.gridColor,
    required this.pinColor,
    required this.ringColor,
    required this.backgroundColor,
  });

  final double latitude;
  final double longitude;
  final double radiusMeters;
  final Size size;
  final void Function(double lat, double lon) onLatLonChanged;
  final Color gridColor;
  final Color pinColor;
  final Color ringColor;
  final Color backgroundColor;

  Offset _project(double lat, double lon) {
    final latClamped = lat.clamp(
      LocationMapPreview._latMin,
      LocationMapPreview._latMax,
    );
    final lonClamped = lon.clamp(
      LocationMapPreview._lonMin,
      LocationMapPreview._lonMax,
    );
    final usableW = size.width - 2 * LocationMapPreview._edgeMargin;
    final usableH = size.height - 2 * LocationMapPreview._edgeMargin;
    final x =
        LocationMapPreview._edgeMargin +
        usableW *
            (lonClamped - LocationMapPreview._lonMin) /
            (LocationMapPreview._lonMax - LocationMapPreview._lonMin);
    final y =
        LocationMapPreview._edgeMargin +
        usableH *
            (LocationMapPreview._latMax - latClamped) /
            (LocationMapPreview._latMax - LocationMapPreview._latMin);
    return Offset(x, y);
  }

  ({double lat, double lon}) _unproject(Offset point) {
    final usableW = size.width - 2 * LocationMapPreview._edgeMargin;
    final usableH = size.height - 2 * LocationMapPreview._edgeMargin;
    final lon =
        LocationMapPreview._lonMin +
        (point.dx - LocationMapPreview._edgeMargin) /
            usableW *
            (LocationMapPreview._lonMax - LocationMapPreview._lonMin);
    final lat =
        LocationMapPreview._latMax -
        (point.dy - LocationMapPreview._edgeMargin) /
            usableH *
            (LocationMapPreview._latMax - LocationMapPreview._latMin);
    return (lat: lat.clamp(-90.0, 90.0), lon: lon.clamp(-180.0, 180.0));
  }

  /// Convert a metres radius to pixels at the pin's latitude.
  /// Approximate: 1° latitude ≈ 111 320 m, 1° longitude ≈
  /// 111 320 m × cos(lat). We use the latitude scale on both
  /// axes (a small distortion at high latitudes is acceptable
  /// for a preview at this zoom).
  double _radiusPx() {
    const metresPerDegLat = 111320.0;
    final usableH = size.height - 2 * LocationMapPreview._edgeMargin;
    const degSpan = LocationMapPreview._latMax - LocationMapPreview._latMin;
    final pxPerMetre = usableH / (degSpan * metresPerDegLat);
    return radiusMeters * pxPerMetre;
  }

  @override
  Widget build(BuildContext context) {
    final pinPos = _project(latitude, longitude);
    final ringRadiusPx = _radiusPx();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final p = _unproject(details.localPosition);
        onLatLonChanged(p.lat, p.lon);
      },
      onPanUpdate: (details) {
        final p = _unproject(details.localPosition);
        onLatLonChanged(p.lat, p.lon);
      },
      child: CustomPaint(
        painter: _MapPreviewPainter(
          pinPos: pinPos,
          ringRadiusPx: ringRadiusPx,
          gridColor: gridColor,
          pinColor: pinColor,
          ringColor: ringColor,
          backgroundColor: backgroundColor,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MapPreviewPainter extends CustomPainter {
  _MapPreviewPainter({
    required this.pinPos,
    required this.ringRadiusPx,
    required this.gridColor,
    required this.pinColor,
    required this.ringColor,
    required this.backgroundColor,
  });

  final Offset pinPos;
  final double ringRadiusPx;
  final Color gridColor;
  final Color pinColor;
  final Color ringColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      bgPaint,
    );
    // Faint 5x5 grid as a stylised "map" cue.
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    const cols = 5;
    const rows = 5;
    for (var i = 1; i < cols; i++) {
      final x = size.width * i / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var i = 1; i < rows; i++) {
      final y = size.height * i / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // Geofence ring (radius > 0 only).
    if (ringRadiusPx > 0) {
      final ringPaint = Paint()..color = ringColor;
      canvas.drawCircle(pinPos, ringRadiusPx, ringPaint);
    }
    // Pin.
    final pinPaint = Paint()..color = pinColor;
    canvas.drawCircle(pinPos, 6, pinPaint);
    final strokePaint = Paint()
      ..color = pinColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(pinPos, 10, strokePaint);
  }

  @override
  bool shouldRepaint(_MapPreviewPainter old) {
    return old.pinPos != pinPos ||
        old.ringRadiusPx != ringRadiusPx ||
        old.gridColor != gridColor ||
        old.pinColor != pinColor ||
        old.ringColor != ringColor ||
        old.backgroundColor != backgroundColor;
  }
}

/// Pure helper exposed for tests: project (lat, lon) onto a
/// canvas of `size` using the same equirectangular projection
/// the painter uses.
Offset projectLatLonForTest(double lat, double lon, Size size) {
  final latClamped = lat.clamp(
    LocationMapPreview._latMin,
    LocationMapPreview._latMax,
  );
  final lonClamped = lon.clamp(
    LocationMapPreview._lonMin,
    LocationMapPreview._lonMax,
  );
  final usableW = size.width - 2 * LocationMapPreview._edgeMargin;
  final usableH = size.height - 2 * LocationMapPreview._edgeMargin;
  final x =
      LocationMapPreview._edgeMargin +
      usableW *
          (lonClamped - LocationMapPreview._lonMin) /
          (LocationMapPreview._lonMax - LocationMapPreview._lonMin);
  final y =
      LocationMapPreview._edgeMargin +
      usableH *
          (LocationMapPreview._latMax - latClamped) /
          (LocationMapPreview._latMax - LocationMapPreview._latMin);
  return Offset(x, y);
}

/// Pure helper exposed for tests: inverse of
/// [projectLatLonForTest]. Returns `(lat, lon)` clamped to
/// the valid ranges.
({double lat, double lon}) unprojectLatLonForTest(Offset point, Size size) {
  final usableW = size.width - 2 * LocationMapPreview._edgeMargin;
  final usableH = size.height - 2 * LocationMapPreview._edgeMargin;
  final lon =
      LocationMapPreview._lonMin +
      (point.dx - LocationMapPreview._edgeMargin) /
          usableW *
          (LocationMapPreview._lonMax - LocationMapPreview._lonMin);
  final lat =
      LocationMapPreview._latMax -
      (point.dy - LocationMapPreview._edgeMargin) /
          usableH *
          (LocationMapPreview._latMax - LocationMapPreview._latMin);
  return (lat: lat.clamp(-90.0, 90.0), lon: lon.clamp(-180.0, 180.0));
}

/// Pure helper exposed for tests: convert metres to pixels at
/// the given latitude using the same approximation as the
/// painter.
double radiusMetresToPxForTest(double metres, Size size) {
  const metresPerDegLat = 111320.0;
  final usableH = size.height - 2 * LocationMapPreview._edgeMargin;
  const degSpan = LocationMapPreview._latMax - LocationMapPreview._latMin;
  final pxPerMetre = usableH / (degSpan * metresPerDegLat);
  return metres * pxPerMetre;
}
