// Home widget state — pure-Dart value class.
//
// The Android home widget is rendered from this value
// class (the Kotlin `WidgetRenderer.render` reads the JSON
// produced by `toJson` and applies it to the RemoteViews).
// The widget never directly touches the Drift DB; the Dart
// `WidgetService` computes a fresh [DoitWidgetState] on
// every relevant change (completion-log write, reliability
// change, do-list change) and writes it to the Kotlin
// `WidgetStateCache`.
//
// Layer rules (per .claude/rules/lib-services.md + the
// widget pure-Dart model rules):
//   - No Flutter imports. The model is plain Dart so the
//     unit tests can construct states without a Flutter
//     test harness.
//   - No `DateTime.now()` in the constructor. The caller
//     passes the reference time so the streak + `isCompletedToday`
//     reads stay deterministic across tests.
//   - `==` and `hashCode` are value-based so widget tests
//     can compare snapshots without inspecting JSON.
//
// v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042.

import 'package:meta/meta.dart';

/// The reliability badge shown in the widget. Mirrors
/// [com.doit.reminders.Reliability] (the Kotlin side's
/// enum) — the values match the string tags Dart uses
/// over the MethodChannel so the JSON envelope is
/// stable across both sides.
enum DoitWidgetReliability {
  optimal,
  degraded,
  unknown;

  /// JSON-serializable tag. Matches the Kotlin
  /// `WidgetRenderer.reliabilityIcon` mapping.
  String toJsonTag() {
    switch (this) {
      case DoitWidgetReliability.optimal:
        return 'optimal';
      case DoitWidgetReliability.degraded:
        return 'degraded';
      case DoitWidgetReliability.unknown:
        return 'unknown';
    }
  }

  /// Reverse of [toJsonTag]. Returns [DoitWidgetReliability.unknown]
  /// for any unrecognized tag — defensive so a downgrade
  /// does not crash the widget renderer.
  static DoitWidgetReliability fromJsonTag(String? tag) {
    switch (tag) {
      case 'optimal':
        return DoitWidgetReliability.optimal;
      case 'degraded':
        return DoitWidgetReliability.degraded;
      case 'unknown':
      default:
        return DoitWidgetReliability.unknown;
    }
  }
}

/// A snapshot of what the home widget should display.
///
/// The widget shows a single "first-active do" (oldest by
/// `createdAtMillis`, skipping paused dos). All other
/// fields are derived from the do + completion log +
/// current reliability. The value class is immutable;
/// updates produce a new instance via the constructor.
@immutable
class DoitWidgetState {
  const DoitWidgetState({
    required this.habitId,
    required this.habitName,
    required this.streakNumber,
    required this.isCompletedToday,
    required this.reliability,
    required this.asOf,
  });

  /// The active do's id. Used by the widget's "Done" button
  /// to identify which do to mark complete (the Dart side
  /// reads the cached state and dispatches the
  /// `CompletionLogService.append` call). Empty string
  /// when no active do exists.
  final String habitId;

  /// The active do's display name. Rendered in the top row
  /// of the widget. Empty string when no active do exists
  /// (the Kotlin side renders the empty-state copy).
  final String habitName;

  /// The current consecutive-run for the active do, as of
  /// [asOf]. Always ≥ 0; the `ConsecutiveCounter.compute`
  /// contract guarantees this.
  final int streakNumber;

  /// True iff the active do has a completion row for the
  /// local-day that contains [asOf]. Used by the widget
  /// to gray-out / hide the "Done" button after the user
  /// has already marked today done.
  final bool isCompletedToday;

  /// The current app-wide reliability. The widget shows
  /// the matching badge icon (optimal / degraded / unknown).
  /// Closes `feature.md` §2.8 "B9" — the widget re-arm
  /// indicator that v1.2g explicitly deferred.
  final DoitWidgetReliability reliability;

  /// The frozen reference time the state was computed at.
  /// Stored so the Kotlin renderer can apply time-of-day-
  /// aware fallbacks (e.g., suppress a "Done" tap that
  /// arrived after midnight) without re-running the
  /// Dart compute.
  final DateTime asOf;

  /// Returns a copy with selected fields replaced. Used by
  /// tests + the `WidgetService` to derive small variations
  /// (e.g., after a single completion write) without
  /// re-running the full builder.
  DoitWidgetState copyWith({
    String? habitId,
    String? habitName,
    int? streakNumber,
    bool? isCompletedToday,
    DoitWidgetReliability? reliability,
    DateTime? asOf,
  }) {
    return DoitWidgetState(
      habitId: habitId ?? this.habitId,
      habitName: habitName ?? this.habitName,
      streakNumber: streakNumber ?? this.streakNumber,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      reliability: reliability ?? this.reliability,
      asOf: asOf ?? this.asOf,
    );
  }

  /// JSON envelope. Used by the MethodChannel and the
  /// SharedPreferences cache. The shape is the contract
  /// between the Dart side and `WidgetRenderer.render`.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'habitId': habitId,
      'habitName': habitName,
      'streakNumber': streakNumber,
      'isCompletedToday': isCompletedToday,
      'reliability': reliability.toJsonTag(),
      'asOfIso': asOf.toIso8601String(),
    };
  }

  /// Reverse of [toJson]. Defensive against missing /
  /// malformed fields — a corrupt cache surfaces as the
  /// empty-state copy rather than a crash.
  factory DoitWidgetState.fromJson(Map<String, Object?> json) {
    final asOfIso = json['asOfIso'] as String?;
    final asOf = asOfIso != null
        ? DateTime.tryParse(asOfIso) ?? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.fromMillisecondsSinceEpoch(0);
    return DoitWidgetState(
      habitId: (json['habitId'] as String?) ?? '',
      habitName: (json['habitName'] as String?) ?? '',
      streakNumber: (json['streakNumber'] as num?)?.toInt() ?? 0,
      isCompletedToday: (json['isCompletedToday'] as bool?) ?? false,
      reliability: DoitWidgetReliability.fromJsonTag(
        json['reliability'] as String?,
      ),
      asOf: asOf,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DoitWidgetState &&
        other.habitId == habitId &&
        other.habitName == habitName &&
        other.streakNumber == streakNumber &&
        other.isCompletedToday == isCompletedToday &&
        other.reliability == reliability &&
        other.asOf == asOf;
  }

  @override
  int get hashCode => Object.hash(
    habitId,
    habitName,
    streakNumber,
    isCompletedToday,
    reliability,
    asOf,
  );

  @override
  String toString() =>
      'DoitWidgetState(habitId: $habitId, habitName: $habitName, '
      'streakNumber: $streakNumber, isCompletedToday: $isCompletedToday, '
      'reliability: ${reliability.toJsonTag()}, asOf: $asOf)';
}
