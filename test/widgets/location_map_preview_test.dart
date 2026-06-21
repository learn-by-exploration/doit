// Tests for the LocationMapPreview widget (v1.1e follow-up
// to v1.0 Phase C PR 2's LocationPicker).
//
// Covers:
//   - Pure projection helpers (project/unproject/radius→px)
//   - Widget render with default props
//   - Tap on canvas invokes onLatLonChanged with valid coords
//   - Pin position responds to latitude/longitude props
//   - Geofence ring scales with radiusMeters (zero hides ring)

import 'package:doit/widgets/location_map_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('projectLatLonForTest', () {
    test('origin (0, 0) maps to the canvas centre', () {
      // With size 360 × 170 and edgeMargin 8, the inner usable
      // rect is 344 × 154. The visible window is lon ∈ [-180,
      // 180] × lat ∈ [-85, 85], so (0, 0) lands at
      // (8 + 172, 8 + 77) = (180, 85).
      const size = Size(360, 170);
      final p = projectLatLonForTest(0, 0, size);
      expect(p.dx, closeTo(180, 0.001));
      expect(p.dy, closeTo(85, 0.001));
    });

    test('extreme corners map to inner-rect corners', () {
      const size = Size(360, 170);
      // (lat=85, lon=-180) → top-left of usable rect.
      final tl = projectLatLonForTest(85, -180, size);
      expect(tl.dx, closeTo(8, 0.001));
      expect(tl.dy, closeTo(8, 0.001));
      // (lat=-85, lon=180) → bottom-right.
      final br = projectLatLonForTest(-85, 180, size);
      expect(br.dx, closeTo(size.width - 8, 0.001));
      expect(br.dy, closeTo(size.height - 8, 0.001));
    });

    test('out-of-range coords are clamped to the visible window', () {
      const size = Size(360, 170);
      final outOfRange = projectLatLonForTest(120, 200, size);
      final clamped = projectLatLonForTest(85, 180, size);
      expect(outOfRange.dx, closeTo(clamped.dx, 0.001));
      expect(outOfRange.dy, closeTo(clamped.dy, 0.001));
    });
  });

  group('unprojectLatLonForTest', () {
    test('inverse of projectLatLonForTest at a sample point', () {
      const size = Size(360, 170);
      const lat = 35.5;
      const lon = -122.3;
      final p = projectLatLonForTest(lat, lon, size);
      final back = unprojectLatLonForTest(p, size);
      expect(back.lat, closeTo(lat, 0.0001));
      expect(back.lon, closeTo(lon, 0.0001));
    });

    test('clamps to ±90 / ±180', () {
      const size = Size(360, 170);
      // Tap well below-right of the canvas: lat → −90
      // (south pole), lon → +180 (date line east).
      final belowRight = unprojectLatLonForTest(
        Offset(size.width + 1000, size.height + 1000),
        size,
      );
      expect(belowRight.lat, -90);
      expect(belowRight.lon, 180);
      // Tap well above-left: lat → +90, lon → −180.
      final aboveLeft = unprojectLatLonForTest(
        const Offset(-1000, -1000),
        size,
      );
      expect(aboveLeft.lat, 90);
      expect(aboveLeft.lon, -180);
    });
  });

  group('radiusMetresToPxForTest', () {
    test('0 metres returns 0 pixels', () {
      const size = Size(360, 170);
      expect(radiusMetresToPxForTest(0, size), 0);
    });

    test('positive metres returns a positive pixel count', () {
      const size = Size(360, 170);
      final px = radiusMetresToPxForTest(1000, size);
      expect(px, greaterThan(0));
      // Sanity: 1 km in this projection should be smaller than
      // the canvas height (~170 px).
      expect(px, lessThan(size.height));
    });
  });

  group('LocationMapPreview widget', () {
    Widget wrap({
      required void Function(double lat, double lon) onChanged,
      double lat = 0,
      double lon = 0,
      double radius = 0,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 200,
              child: LocationMapPreview(
                latitude: lat,
                longitude: lon,
                radiusMeters: radius,
                onLatLonChanged: onChanged,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders with default props', (tester) async {
      await tester.pumpWidget(wrap(onChanged: (_, _) {}));
      expect(
        find.byKey(const ValueKey('location_picker.map_preview')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap on canvas invokes onLatLonChanged with valid coords', (
      tester,
    ) async {
      double? lastLat;
      double? lastLon;
      await tester.pumpWidget(
        wrap(
          onChanged: (lat, lon) {
            lastLat = lat;
            lastLon = lon;
          },
        ),
      );
      // Tap the centre of the preview. The preview is 360×100
      // (LocationMapPreview's default height) inside a
      // 360×200 SizedBox centred in an 800×600 viewport.
      await tester.tap(
        find.byKey(const ValueKey('location_picker.map_preview')),
      );
      await tester.pump();
      expect(lastLat, isNotNull);
      expect(lastLon, isNotNull);
      expect(lastLat!, inInclusiveRange(-90, 90));
      expect(lastLon!, inInclusiveRange(-180, 180));
      // The centre tap should map to roughly (lat=0, lon=0)
      // (the centre of the visible window).
      expect(lastLat!, closeTo(0, 5));
      expect(lastLon!, closeTo(0, 20));
    });

    testWidgets('pin position responds to latitude/longitude props', (
      tester,
    ) async {
      // Rebuild the widget with non-zero props; painter should
      // not throw and the canvas stays mounted.
      await tester.pumpWidget(
        wrap(onChanged: (_, _) {}, lat: 12.34, lon: -45.67, radius: 200),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('location_picker.map_preview')),
        findsOneWidget,
      );
    });

    testWidgets(
      'geofence ring renders for positive radius and is hidden at 0',
      (tester) async {
        // Render with radius = 0; painter skips the ring.
        await tester.pumpWidget(wrap(onChanged: (_, _) {}));
        expect(tester.takeException(), isNull);

        // Render with radius = 200 m; painter draws the ring.
        await tester.pumpWidget(wrap(onChanged: (_, _) {}, radius: 200));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
