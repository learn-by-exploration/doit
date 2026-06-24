// Anchor detection — two modes (manual, first-unlock) plus a
// "either" hybrid, with a 4-hour debounce.
//
// The wake-up anchor is the moment the user says "I'm up". A
// habit scheduled `Anchor(at: ...)` fires relative to this
// moment.
//
// Per SYS-015:
// - Manual: a "mark now" button in the home screen.
// - First-unlock: a `BroadcastReceiver` listens for
//   `Intent.ACTION_USER_PRESENT`.
// - Either with confirmation: whichever fires first, with a
//   confirmation toast.
// - 4-hour debounce: a second anchor event within 4 hours of
//   the first is silently dropped.
//
// WF-026 (Phase 11e): an evening anchor ("I'm winding
// down") is a parallel concept. The morning and evening
// debounce counters are independent — a morning "I'm up"
// does not block the evening "I'm winding down", and vice
// versa. First-unlock mode only fires the morning anchor;
// the evening anchor is manual-only by design (Android does
// not expose a stable "winding down" event).
//
// This file is a pure-Dart model. The platform-side listener
// (Kotlin) writes into the detector via a method channel.

import 'dart:async';

import 'package:meta/meta.dart';

/// Detection mode for the wake-up anchor. Selectable in
/// settings.
enum AnchorMode { manual, firstUnlock, either }

@immutable
class AnchorEvent {
  const AnchorEvent(this.at);
  final DateTime at;
}

/// Public surface for anchor detection.
abstract class AnchorDetector {
  /// Start listening in the given mode. Calling [start] with
  /// a different mode replaces the prior listener.
  void start({required AnchorMode mode});

  /// Stop listening. [lastAnchor] remains.
  void stop();

  /// The most recent morning-anchor event. Null if none has
  /// fired in this session or since the last [reset].
  DateTime? get lastAnchor;

  /// The most recent evening-anchor event. Null if none has
  /// fired since the last [reset]. WF-026 (Phase 11e).
  DateTime? get lastEveningAnchor;

  /// Mark "now" as the morning anchor (manual mode). Returns
  /// the new anchor time, or null if the 4-hour debounce is
  /// in effect.
  DateTime? markNow();

  /// Mark "now" as the evening anchor (manual mode). Returns
  /// the new anchor time, or null if the 4-hour evening
  /// debounce is in effect. WF-026 (Phase 11e).
  DateTime? markEveningNow();

  /// Reset the detector (used in tests and on settings change).
  void reset();

  /// The current mode.
  AnchorMode get mode;

  /// Stream of new anchor events. The first event in any 4-hour
  /// window is emitted; subsequent events are debounced.
  Stream<AnchorEvent> get events;
}

/// In-memory implementation used by tests.
class FakeAnchorDetector implements AnchorDetector {
  AnchorMode _mode = AnchorMode.manual;
  DateTime? _lastAnchor;
  DateTime? _lastEveningAnchor;
  final StreamController<AnchorEvent> _ctrl =
      StreamController<AnchorEvent>.broadcast();

  /// For tests: the debounce window. Defaults to 4 hours per
  /// SYS-015.
  Duration debounceWindow;

  FakeAnchorDetector({this.debounceWindow = const Duration(hours: 4)});

  @override
  void start({required AnchorMode mode}) {
    _mode = mode;
  }

  @override
  void stop() {
    // No-op for the fake.
  }

  @override
  DateTime? get lastAnchor => _lastAnchor;

  @override
  DateTime? get lastEveningAnchor => _lastEveningAnchor;

  @override
  DateTime? markNow() {
    final now = DateTime.now();
    if (_lastAnchor != null && now.difference(_lastAnchor!) < debounceWindow) {
      return null;
    }
    _lastAnchor = now;
    _ctrl.add(AnchorEvent(now));
    return now;
  }

  @override
  DateTime? markEveningNow() {
    // WF-026 (Phase 11e). Independent debounce counter from
    // the morning anchor — a morning "I'm up" does not
    // block the evening "I'm winding down", and vice versa.
    final now = DateTime.now();
    if (_lastEveningAnchor != null &&
        now.difference(_lastEveningAnchor!) < debounceWindow) {
      return null;
    }
    _lastEveningAnchor = now;
    _ctrl.add(AnchorEvent(now));
    return now;
  }

  @override
  void reset() {
    _lastAnchor = null;
    _lastEveningAnchor = null;
  }

  @override
  AnchorMode get mode => _mode;

  @override
  Stream<AnchorEvent> get events => _ctrl.stream;
}
