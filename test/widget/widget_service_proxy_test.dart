// Tests for the WidgetServiceProxy indirection layer
// (v1.5-cyc-α / Phase 53 / SYS-140 / ADR-071 / WF-068).
//
// `lib/widget/widget_service_proxy.dart` is a 3-line class
// (a const constructor + a single async method that forwards
// to `WidgetService.instance.setSelectedHabitId`). The proxy
// is the seam that lets widget tests inject a fake without
// touching the live singleton — `WidgetConfigScreen`
// (lib/widget/widget_config_screen.dart) takes a
// `WidgetServiceProxy` as a constructor parameter (line 49).
//
// These tests cover the seam's API contract:
//
//   - `setSelectedHabitId(habitId)` forwards to whatever the
//     subclass override implements (the default forwards to
//     `WidgetService.instance.setSelectedHabitId`, which we
//     do not exercise here — `test/widget/widget_service_test.dart`
//     owns the service-level contract).
//   - The `null` habitId path is preserved through the seam
//     (used by the picker when the user wants to unbind a
//     widget).
//   - The const constructor is stable (the screen relies on
//     `const WidgetServiceProxy()` as a default parameter
//     value at lib/widget/widget_config_screen.dart:49).
//
// Pushing a fake subclass is the documented intent at
// lib/widget/widget_service_proxy.dart:13-21 ("tests pass a
// subclass that records the call").

import 'package:doit/widget/widget_service_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingProxy extends WidgetServiceProxy {
  final List<String?> calls = <String?>[];

  @override
  Future<bool> setSelectedHabitId(String? habitId) async {
    calls.add(habitId);
    return true;
  }
}

void main() {
  group('WidgetServiceProxy', () {
    test(
      'setSelectedHabitId forwards a non-null habitId to the override',
      () async {
        final fake = _RecordingProxy();
        final ok = await fake.setSelectedHabitId('h-42');

        expect(ok, isTrue);
        expect(fake.calls, hasLength(1));
        expect(fake.calls.single, 'h-42');
      },
    );

    test('setSelectedHabitId forwards null without throwing', () async {
      final fake = _RecordingProxy();
      final ok = await fake.setSelectedHabitId(null);

      expect(ok, isTrue);
      expect(fake.calls, hasLength(1));
      expect(fake.calls.single, isNull);
    });

    test(
      'const constructor is stable for the screen default-parameter seam',
      () {
        // The screen relies on `const WidgetServiceProxy()` as a
        // default parameter value
        // (lib/widget/widget_config_screen.dart:49). If a future
        // refactor makes the constructor non-const, the screen
        // default breaks — pin the const-ness here.
        const a = WidgetServiceProxy();
        const b = WidgetServiceProxy();
        expect(
          identical(a, b),
          isTrue,
          reason:
              'const WidgetServiceProxy() must canonicalize so '
              'WidgetConfigScreen\'s default-parameter seam compiles.',
        );
      },
    );
  });
}
