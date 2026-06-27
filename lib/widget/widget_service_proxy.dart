// Indirection layer for the `WidgetService` singleton (v1.4k /
// Phase 38 / SYS-125 / ADR-055 / WF-052).
//
// The Android `DoitWidgetConfigureActivity` is a separate
// `FlutterActivity` from `MainActivity` (it has its own
// `FlutterEngine` per the v1.3d `FullScreenActivity` thin-shell
// precedent; see `FullScreenActivity.kt` KDoc). `WidgetService`
// itself is a process-scoped singleton initialized in
// `main.dart` — when the activity launches, the singleton is
// already alive (the same process) and the picker can write the
// selection without a round-trip through a method channel.
//
// The proxy is the seam that lets widget tests inject a fake
// without touching the live singleton. The default constructor
// forwards to `WidgetService.instance.setSelectedHabitId(...)`;
// tests pass a subclass that records the call.
//
// Why a class (not a top-level function): subclasses give tests
// a typed handle for assertions (`fakeProxy.calls`), matching
// the v1.4h `home_tile_delete.dart` callback-handler seam.

import 'package:doit/services/widget_service.dart';

class WidgetServiceProxy {
  const WidgetServiceProxy();

  /// Default: forward to the live service. The
  /// `WidgetService.init` has already completed by the
  /// time the configurator activity is reachable (the
  /// configurator is launched from the launcher, not
  /// from `main.dart`; but the cold-start path is the
  /// process-singleton — by the time Flutter renders
  /// the first frame, `main.dart` has run and
  /// `WidgetService.ready` has resolved). If
  /// `WidgetService.init` was not called for some
  /// reason, the singleton throws `StateError` and the
  /// picker surfaces a silent no-op (no widget to
  /// configure).
  Future<bool> setSelectedHabitId(String? habitId) async {
    return WidgetService.instance.setSelectedHabitId(habitId);
  }
}
