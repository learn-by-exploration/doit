// Inbound `doit/widget` MethodChannel handler that lets the
// Kotlin side invoke Dart's `WidgetService.markDone` / `.skip`
// / `.undo` methods (v1.4g / Phase 34 / SYS-121 / ADR-051 /
// WF-048).
//
// v1.4a + v1.4f shipped the widget surface with three
// `ImageButton`s — "Done", "Skip today", "Undo today" — but
// the buttons never actually wrote to the completion log.
// `DoitWidgetProvider.onReceive` fired `ACTION_MARK_DONE` /
// `ACTION_WIDGET_SKIP` / `ACTION_WIDGET_UNDO`, which routed
// through `WidgetUpdater.refreshAll(ctx)` (a repaint-only
// call). The widget surface appeared to work but the
// completion rows were NEVER written — the user could tap
// the widget "Done" button all day and the in-app home
// tile's streak would not move. v1.4g closes this latent gap.
//
// Architecture:
//   - The widget `ImageButton` fires a `PendingIntent`
//     targeting `DoitWidgetProvider` with `ACTION_MARK_DONE`
//     (or `_SKIP` / `_UNDO`) + `EXTRA_HABIT_ID`.
//   - `DoitWidgetProvider.onReceive` dispatches to
//     `WidgetChannel.invokeAction(ctx, "markDone", habitId)`
//     (etc.). `invokeAction` ensures the FlutterEngine is
//     alive, then sends an INBOUND `MethodChannel` call to
//     Dart (`markDone` / `skip` / `undo` arm).
//   - This invoker is the inbound arm on the Dart side. It
//     routes the call to `WidgetService.instance.markDone`
//     (or `.skip` / `.undo`) and returns the `bool` result
//     over the channel.
//   - The Dart-side `WidgetService.markDone` (or `.skip` /
//     `.undo`) appends to the completion log + re-derives +
//     caches + asks the platform to repaint via
//     `bridge.cacheSnapshot` + `bridge.requestRefresh`. The
//     repaint is the widget surface's visible feedback.
//
// Lifecycle:
//   - `attach()` is idempotent: a second call is a no-op.
//   - `detach()` removes the handler (for tests).
//   - `resetForTesting()` clears the singleton + handler.
//   - `WidgetService.init(...)` calls `attach()` after the
//     singleton is initialized so the channel is live
//     before `WidgetChannel.invokeAction` can be called.
//
// Failure modes:
//   - The Dart side is not initialized (`WidgetService.init`
//     was not called) → the invoker returns `false`. The
//     Kotlin side surfaces a `false` and the widget repaints
//     with the cached state.
//   - The Dart-side method throws → the invoker returns
//     `false` (logs via `debugPrint` behind `kDebugMode`).
//     The Kotlin side surfaces a `false`.
//   - The invoker is detached → the channel has no handler
//     and the Kotlin-side call surfaces
//     `MissingPluginException` (caught by
//     `WidgetChannel.invokeAction` and returned as `false`).
//
// Test surface:
//   - `widgetActionDispatch(MethodCall)` is a top-level
//     function that exposes the same dispatch logic without
//     going through a real `MethodChannel`. Tests can call
//     it with a synthetic `MethodCall('markDone', {'habitId':
//     'h1'})` and assert the return value + the side
//     effects on the (fake) `WidgetService.instance`.

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';

import 'package:doit/services/widget_service.dart';

/// Singleton inbound handler for `doit/widget` MethodChannel
/// actions that originate from the Kotlin-side widget taps
/// (v1.4g / SYS-121).
class WidgetActionInvoker {
  WidgetActionInvoker._({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('doit/widget');

  /// Initialize gate. Reads may `await ready` before
  /// [invoke] to ensure the channel handler is wired.
  static Completer<void> _ready = Completer<void>();

  /// The current handler instance (or `null` after
  /// [resetForTesting]).
  static WidgetActionInvoker? _instance;

  /// The MethodChannel that backs this invoker. Same channel
  /// as `PlatformWidgetBridge` (`doit/widget`) — the
  /// channel is bidirectional; this invoker handles the
  /// Kotlin → Dart direction while `PlatformWidgetBridge`
  /// handles the Dart → Kotlin direction.
  final MethodChannel _channel;

  /// Attach the inbound channel handler. Idempotent:
  /// subsequent calls resolve immediately. Safe to call
  /// before or after `WidgetService.init` — the handler
  /// defers calls to `WidgetService.instance` lazily so
  /// out-of-order init is tolerated (the call returns
  /// `false` if `WidgetService` is not yet initialized).
  ///
  /// `WidgetService.init(...)` calls this automatically
  /// after the singleton is initialized; production code
  /// rarely needs to call this directly. Tests that want to
  /// exercise the invoker in isolation can call
  /// `attach({channel: fakeChannel})` then
  /// `widgetActionDispatch(MethodCall(...))` to bypass the
  /// real `MethodChannel` plumbing.
  static Future<void> attach({MethodChannel? channel}) async {
    if (_instance != null) {
      await _ready.future;
      return;
    }
    final invoker = WidgetActionInvoker._(channel: channel);
    _instance = invoker;
    invoker._wire();
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Future that completes after [attach] has wired the
  /// channel handler. Public reads may `await ready` to
  /// ensure the inbound channel is live.
  static Future<void> get ready => _ready.future;

  /// Reset for tests. Removes the channel handler and
  /// clears the singleton.
  static void resetForTesting() {
    final invoker = _instance;
    if (invoker != null) {
      invoker._channel.setMethodCallHandler(null);
    }
    _instance = null;
    if (!_ready.isCompleted) {
      _ready = Completer<void>();
    }
  }

  /// True when [attach] has been called and [resetForTesting]
  /// has not been called since. Useful for tests that want
  /// to assert the singleton's state.
  static bool get isAttached => _instance != null;

  void _wire() {
    _channel.setMethodCallHandler((MethodCall call) async {
      // Only the action arms are handled here. Outbound
      // methods (`cacheSnapshot`, `requestRefresh`, the
      // legacy outbound `markDone` / `skip` / `undo` arms
      // added in v1.4f) are routed through
      // `PlatformWidgetBridge` and have no inbound
      // counterpart in v1.4g — they fall through and
      // return `null` (which the platform side interprets
      // as a no-op for the action, harmless for the
      // outbound calls).
      switch (call.method) {
        case 'markDone':
        case 'skip':
        case 'undo':
          return widgetActionDispatch(call);
        default:
          return null;
      }
    });
  }

  /// Dispatch a Kotlin-originated action to the Dart-side
  /// `WidgetService` singleton. Returns the service's
  /// `Future<bool>` result. Returns `false` if the service
  /// is not initialized (the caller — the channel handler —
  /// relays the `false` to the platform side).
  Future<bool> dispatch(MethodCall call) async {
    final args = call.arguments;
    String? habitId;
    if (args is Map) {
      final raw = args['habitId'];
      if (raw is String) habitId = raw;
    }
    if (habitId == null || habitId.isEmpty) {
      if (kDebugMode) {
        debugPrint('WidgetActionInvoker: ${call.method} missing habitId arg');
      }
      return false;
    }
    final WidgetService service;
    try {
      service = WidgetService.instance;
    } on StateError catch (e) {
      if (kDebugMode) {
        debugPrint('WidgetActionInvoker: WidgetService not initialized — $e');
      }
      return false;
    }
    try {
      switch (call.method) {
        case 'markDone':
          return await service.markDone(habitId);
        case 'skip':
          return await service.skip(habitId);
        case 'undo':
          return await service.undo(habitId);
        default:
          return false;
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('WidgetActionInvoker.${call.method}: $e\n$st');
      }
      return false;
    }
  }
}

/// Top-level dispatcher used as the
/// `setMethodCallHandler` callback and by tests that want
/// to exercise the dispatch logic without a real
/// `MethodChannel`. The function shape is
/// `Future<dynamic> Function(MethodCall)`; the channel
/// adapter translates the return value into a
/// `MethodChannel.Result.success(...)` on the platform
/// side. Returns `false` on any failure path (service not
/// initialized, missing habitId, dispatch throws) so the
/// Kotlin caller can treat `false` as "action didn't work"
/// and fall back to a repaint with the cached state.
Future<bool> widgetActionDispatch(MethodCall call) async {
  final invoker = WidgetActionInvoker._instance;
  if (invoker == null) return false;
  return invoker.dispatch(call);
}
