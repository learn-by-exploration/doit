// Tests for the LocationPicker sheet (v1.0 / Phase C PR 2 /
// ADR-021 / SYS-076).
//
// Coverage:
//   - The picker renders its form when the permission gate
//     short-circuits to "granted" (the `PermissionSheet`
//     path is tested in `permission_sheet_test.dart`).
//   - `Cancel` returns null.
//   - Form validation: empty label / out-of-range lat / lng
//     render inline errors and gate the "Save" button.
//   - A clean save with the default "On enter" radio pops
//     an [Automation] with a [TriggerLocationEnter] and
//     an [ActionNotify] whose title is the trigger label.
//   - The "On exit" radio yields a [TriggerLocationExit].
//   - "Use current location" fills the lat/lng fields from
//     a mocked `Geolocator.getCurrentPosition`.
//
// The picker is gated by [PermissionSheet.show] for
// `PermissionKind.location`. The test scripts the
// `permission_handler` MethodChannel so the sheet's
// `checkPermissionStatus` probe returns `granted` and the
// gate short-circuits.
//
// Async-pump caveat (same as `permission_sheet_test.dart`):
// `LocationPicker.show(...)` is `async`; its first
// `await PermissionSheet.show(...)` suspends on the cached
// permission probe. The fake-async zone in `tester.pump`
// does NOT process microtasks scheduled outside the pump
// frame, so `pump(Duration)` alone never advances past the
// `await PermissionSheet.show(...)` to the
// `showModalBottomSheet` call. The test drives the async
// setup under `tester.runAsync` (real time) and only uses
// `pump` to advance the modal's 250 ms slide-up transition.
// `pumpAndSettle` is avoided because the drag-handle spring
// animation does not settle in a finite number of frames.
//
// Viewport caveat: the form is taller than the 800x600
// default test viewport (slider + radio + buttons). It is
// wrapped in a `SingleChildScrollView` so widget tests can
// `ensureVisible` the Cancel / Save buttons before tapping.
//
// Helper caveat: every helper that wraps `tester.runAsync` /
// `tester.pump` in an `async` function hangs when called
// from inside `testWidgets`. The fix is to inline the
// `runAsync` / `pump` calls in every test instead of
// abstracting them into a helper. (Verified empirically —
// inlining the same code works, the helper does not.)

import 'package:doit/routines/routine.dart';
import 'package:doit/services/permission_service.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/triggers/action.dart';
import 'package:doit/triggers/trigger.dart';
import 'package:doit/widgets/location_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

Widget _wrap() => MaterialApp(theme: AppTheme.dark, home: const _Host());

class _Host extends StatelessWidget {
  const _Host();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => LocationPicker.show(ctx),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  // `geolocator` ^13.0.1's `getCurrentPosition` MethodChannel
  // is `flutter.baseflow.com/geolocator` with method
  // `getCurrentPosition`. Mocking it lets the
  // "Use current location" button populate the lat/lng
  // fields without a real device fix.
  const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');

  final probeScriptedStatuses = <int, PermissionStatus>{};
  final requestScriptedStatuses = <int, PermissionStatus>{};
  Position? scriptedCurrentPosition;

  setUp(() {
    probeScriptedStatuses.clear();
    requestScriptedStatuses.clear();
    scriptedCurrentPosition = null;
    probeScriptedStatuses[Permission.location.value] = PermissionStatus.granted;
    requestScriptedStatuses[Permission.location.value] =
        PermissionStatus.granted;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          final v = call.arguments as int;
          return (probeScriptedStatuses[v] ?? PermissionStatus.denied).value;
        case 'requestPermissions':
          final List<int> requested = (call.arguments as List).cast<int>();
          var response = PermissionStatus.denied;
          for (final v in requested) {
            final scripted = requestScriptedStatuses[v];
            if (scripted != null) {
              response = scripted;
              break;
            }
          }
          return <int, int>{for (final v in requested) v: response.value};
        case 'openAppSettings':
          return true;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(geolocatorChannel, (call) async {
      switch (call.method) {
        case 'checkPermission':
          // geolocator's LocationPermission enum:
          //   denied = 0, deniedForever = 1,
          //   whileInUse = 2, always = 3,
          //   unableToDetermine = 4.
          // Return whileInUse so the picker proceeds to
          // `getCurrentPosition`.
          return 2;
        case 'requestPermission':
          return 2;
        case 'getCurrentPosition':
          final p = scriptedCurrentPosition;
          if (p == null) {
            throw PlatformException(
              code: 'LOCATION_UNAVAILABLE',
              message: 'no fix',
            );
          }
          return <String, Object?>{
            'latitude': p.latitude,
            'longitude': p.longitude,
            'timestamp': p.timestamp.millisecondsSinceEpoch,
            'accuracy': p.accuracy,
            'altitude': p.altitude,
            'altitudeAccuracy': p.altitudeAccuracy,
            'heading': p.heading,
            'headingAccuracy': p.headingAccuracy,
            'speed': p.speed,
            'speedAccuracy': p.speedAccuracy,
            'isMocked': false,
          };
        default:
          return null;
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(permissionsChannel, null);
      messenger.setMockMethodCallHandler(geolocatorChannel, null);
    });
    PermissionService.instance.resetForTesting();
  });

  testWidgets('renders the form with default state (SYS-076)', (tester) async {
    await PermissionService.instance.init();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    // Open picker, flush microtasks, advance slide-up.
    final ctx = tester.element(find.text('open'));
    final future = LocationPicker.show(ctx);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Location trigger'), findsOneWidget);
    expect(find.text('Use current location'), findsOneWidget);
    // Cancel: ensureVisible + pump + tap + drain.
    await tester.ensureVisible(
      find.byKey(const ValueKey('location_picker.cancel')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('location_picker.cancel')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(await future, isNull);
  });

  testWidgets('Cancel button returns null (SYS-076)', (tester) async {
    await PermissionService.instance.init();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final ctx = tester.element(find.text('open'));
    final future = LocationPicker.show(ctx);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(
      find.byKey(const ValueKey('location_picker.cancel')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('location_picker.cancel')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(await future, isNull);
  });

  testWidgets('Save with empty label shows "Required" error and does not pop '
      '(SYS-076)', (tester) async {
    await PermissionService.instance.init();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final ctx = tester.element(find.text('open'));
    final future = LocationPicker.show(ctx);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.byKey(const ValueKey('location_picker.latitude')),
      '37.7749',
    );
    await tester.enterText(
      find.byKey(const ValueKey('location_picker.longitude')),
      '-122.4194',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('location_picker.save')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('location_picker.save')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Location trigger'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('location_picker.cancel')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('location_picker.cancel')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(await future, isNull);
  });

  testWidgets('Save with out-of-range latitude shows inline error '
      '(SYS-076)', (tester) async {
    await PermissionService.instance.init();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final ctx = tester.element(find.text('open'));
    final future = LocationPicker.show(ctx);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.byKey(const ValueKey('location_picker.label')),
      'Home',
    );
    await tester.enterText(
      find.byKey(const ValueKey('location_picker.latitude')),
      '999', // > 90
    );
    await tester.enterText(
      find.byKey(const ValueKey('location_picker.longitude')),
      '0',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('location_picker.save')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('location_picker.save')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('−90..90 only'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('location_picker.cancel')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('location_picker.cancel')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(await future, isNull);
  });

  testWidgets(
    'a clean save with default "On enter" pops a TriggerLocationEnter '
    'automation (SYS-076 / ADR-021)',
    (tester) async {
      await PermissionService.instance.init();
      await tester.pumpWidget(_wrap());
      await tester.pump();
      final ctx = tester.element(find.text('open'));
      final future = LocationPicker.show(ctx);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(
        find.byKey(const ValueKey('location_picker.label')),
        'Home',
      );
      await tester.enterText(
        find.byKey(const ValueKey('location_picker.latitude')),
        '37.7749',
      );
      await tester.enterText(
        find.byKey(const ValueKey('location_picker.longitude')),
        '-122.4194',
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('location_picker.save')),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byKey(const ValueKey('location_picker.save')));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 500));
      final auto = await future;
      expect(auto, isA<Automation>());
      final trigger = auto!.trigger;
      expect(trigger, isA<TriggerLocationEnter>());
      final t = trigger as TriggerLocationEnter;
      expect(t.label, 'Home');
      expect(t.latitude, 37.7749);
      expect(t.longitude, -122.4194);
      expect(t.radiusMeters, 100);
      expect(auto.action, isA<ActionNotify>());
      expect((auto.action as ActionNotify).title, 'Home');
    },
  );

  testWidgets('"On exit" radio yields a TriggerLocationExit (SYS-076)', (
    tester,
  ) async {
    await PermissionService.instance.init();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final ctx = tester.element(find.text('open'));
    final future = LocationPicker.show(ctx);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(
      find.byKey(const ValueKey('location_picker.event_exit')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('location_picker.event_exit')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('location_picker.label')),
      'Office',
    );
    await tester.enterText(
      find.byKey(const ValueKey('location_picker.latitude')),
      '37.7849',
    );
    await tester.enterText(
      find.byKey(const ValueKey('location_picker.longitude')),
      '-122.4094',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('location_picker.save')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('location_picker.save')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    final auto = await future;
    expect(auto!.trigger, isA<TriggerLocationExit>());
  });

  testWidgets('"Use current location" fills lat/lng from a mocked '
      'geolocator fix (SYS-076)', (tester) async {
    scriptedCurrentPosition = Position(
      latitude: 12.34,
      longitude: 56.78,
      timestamp: DateTime(2026, 6, 20),
      accuracy: 25,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    await PermissionService.instance.init();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    final ctx = tester.element(find.text('open'));
    final future = LocationPicker.show(ctx);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(
      find.byKey(const ValueKey('location_picker.use_current')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('location_picker.use_current')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 500));
    // Verify the controller text directly (more reliable
    // than matching the rendered TextFormField widget — the
    // render-tree view of a TextFormField with a controller
    // does not always expose the underlying string in a way
    // `find.text(...)` can match).
    final latCtrl = tester
        .widget<TextFormField>(
          find.byKey(const ValueKey('location_picker.latitude')),
        )
        .controller;
    final lonCtrl = tester
        .widget<TextFormField>(
          find.byKey(const ValueKey('location_picker.longitude')),
        )
        .controller;
    expect(latCtrl!.text, '12.340000');
    expect(lonCtrl!.text, '56.780000');
    await tester.ensureVisible(
      find.byKey(const ValueKey('location_picker.cancel')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('location_picker.cancel')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 500));
    await future;
  });
}
