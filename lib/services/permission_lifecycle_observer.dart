// App-lifecycle observer that re-probes permissions when the
// app resumes.
//
// v1.2i / Phase 9 / SYS-104: ADR-030's lesson is that the
// fire-and-forget probe from `PermissionService.init()` is
// stale by the time the user toggles a permission in
// Settings → Special access → Usage access (or grants
// `ROLE_CALL_SCREENING` via the OS dialog). The `resumed`
// lifecycle event is the cheapest signal that the user
// came back to the app; a single re-probe is cheap; and the
// Settings → Permissions tile + the per-automation
// reliability badge both rebuild from the
// `PermissionService.statuses` ValueNotifier, so the
// visible state updates without a relaunch.
//
// Wiring (see `lib/main.dart`):
//
// ```dart
// WidgetsBinding.instance.addObserver(
//   PermissionLifecycleReProbe(),
// );
// ```
//
// The observer is stateless and not added to the widget
// tree — it lives in `WidgetsBinding`'s observer list for
// the lifetime of the process. There is no `dispose` path:
// the observer is intentionally process-scoped; a hot
// restart replaces it via Flutter's framework reset.
//
// `refresh()` itself is the entry point on
// `PermissionService` that re-probes every kind in
// parallel and merges the result into the ValueNotifier.

import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/widgets.dart';

import 'package:doit/services/permission_service.dart';

/// v1.2i / Phase 9. Registered with [WidgetsBinding] in
/// `main.dart` after `PermissionService.init()` completes.
/// Stateless; no `dispose`.
class PermissionLifecycleReProbe with WidgetsBindingObserver {
  /// Whether the observer has already processed the first
  /// `resumed` event after registration. The first event is
  /// the OS bringing the app to the foreground after a cold
  /// launch — `PermissionService.init()` has already probed
  /// at that point, so re-probing would be a redundant
  /// round-trip. Subsequent `resumed` events come from the
  /// app returning from background (Settings toggles,
  /// permission dialogs, etc.) and SHOULD re-probe.
  bool _coldStartSeen = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_coldStartSeen) {
      _coldStartSeen = true;
      return;
    }
    // Fire-and-forget: the resume event must not block on
    // the probe round-trip. The probe itself awaits the
    // `_ready` gate, so a resume during a still-in-progress
    // `init()` just queues the probe behind it.
    unawaited(_safeRefresh());
  }

  Future<void> _safeRefresh() async {
    try {
      await PermissionService.instance.refresh();
    } catch (e, st) {
      // ADR-013 follow-up: a platform-channel error during
      // the resume probe MUST NOT crash the app or leave a
      // dangling future. The statuses map keeps its prior
      // value when a probe fails; the user can pull-to-
      // refresh or reopen Settings → Permissions to retry.
      if (kDebugMode) {
        debugPrint('PermissionLifecycleReProbe.refresh failed: $e\n$st');
      }
    }
  }
}
