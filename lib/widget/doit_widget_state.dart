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
// v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047: restDaysPerMonth.
// v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052: selectedHabitId —
// the user-picked do for this widget instance. Persisted in the
// same DoitWidgetState JSON envelope; surviving cold-start
// fallback via the Kotlin `WidgetStateCache` SharedPreferences.

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
    this.restDaysPerMonth = 0,
    this.selectedHabitId,
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

  /// v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047. The
  /// active do's configured rest-day budget. The Kotlin
  /// `WidgetRenderer` hides the "Skip today" ImageButton
  /// when this is 0 (mirrors the in-app tile's
  /// `_SkipButton` conditional render). Defaults to 0
  /// for backwards compatibility with v1.4a caches (the
  /// `fromJson` factory reads the field defensively; a
  /// missing field is treated as 0).
  final int restDaysPerMonth;

  /// v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052. The
  /// user-picked habit id for this widget instance. When
  /// non-null, `WidgetService.handleRefreshRequest`
  /// resolves the active do via `_doRepository.getById`
  /// (falling back to `firstActiveDo` if the id is empty
  /// or no longer maps to a do). When `null`, the
  /// v1.4a-first-active behavior is preserved.
  ///
  /// Distinct from [habitId] (which is always the
  /// currently-displayed do on the widget face). The
  /// widget shows the selected do after every
  /// handleRefreshRequest; the selection survives a
  /// cold-start fallback because the Kotlin
  /// `WidgetStateCache.cachedFromPrefs` JSON shape grows
  /// by one optional key. `fromJson` reads it
  /// defensively — a missing field is treated as `null`
  /// for backwards compatibility with v1.4a..v1.4j caches.
  final String? selectedHabitId;

  /// Returns a copy with selected fields replaced. Used by
  /// tests + the `WidgetService` to derive small variations
  /// (e.g., after a single completion write) without
  /// re-running the full builder.
  ///
  /// v1.4k / SYS-125 / ADR-055 / WF-052: `selectedHabitId`
  /// is opt-in. `copyWith` with no `selectedHabitId` arg
  /// preserves the prior value (matching the v1.4f
  /// `restDaysPerMonth` precedent). Tests that want to
  /// CLEAR the selection pass `selectedHabitId: null`
  /// explicitly — `copyWith` cannot distinguish "not
  /// passed" from "passed null" without a sentinel, so
  /// the canonical clear path is
  /// `state.copyWith(habitId: ...).copyWith(habitName: ...)`
  /// followed by an explicit `DoitWidgetState(...)`
  /// construction. For test brevity, callers that need to
  /// clear the selection should construct a fresh
  /// [DoitWidgetState] with `selectedHabitId: null` rather
  /// than routing through `copyWith`.
  DoitWidgetState copyWith({
    String? habitId,
    String? habitName,
    int? streakNumber,
    bool? isCompletedToday,
    DoitWidgetReliability? reliability,
    DateTime? asOf,
    int? restDaysPerMonth,
    String? selectedHabitId,
  }) {
    return DoitWidgetState(
      habitId: habitId ?? this.habitId,
      habitName: habitName ?? this.habitName,
      streakNumber: streakNumber ?? this.streakNumber,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      reliability: reliability ?? this.reliability,
      asOf: asOf ?? this.asOf,
      restDaysPerMonth: restDaysPerMonth ?? this.restDaysPerMonth,
      selectedHabitId: selectedHabitId ?? this.selectedHabitId,
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
      'restDaysPerMonth': restDaysPerMonth,
      'selectedHabitId': selectedHabitId,
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
      restDaysPerMonth: (json['restDaysPerMonth'] as num?)?.toInt() ?? 0,
      // v1.4k / SYS-125 / ADR-055 / WF-052. Defensive
      // read: a missing key (downgrade from a v1.4a..v1.4j
      // cache) is `null`, which preserves the v1.4a
      // "first-active do" behavior. An empty string is
      // ALSO treated as `null` because the Kotlin
      // `WidgetRenderer` uses `optString(..., "")` and
      // would otherwise carry a bogus empty selection
      // through to `WidgetService.handleRefreshRequest`.
      selectedHabitId: (json['selectedHabitId'] as String?)?.isEmpty == true
          ? null
          : json['selectedHabitId'] as String?,
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
        other.asOf == asOf &&
        other.restDaysPerMonth == restDaysPerMonth &&
        other.selectedHabitId == selectedHabitId;
  }

  @override
  int get hashCode => Object.hash(
    habitId,
    habitName,
    streakNumber,
    isCompletedToday,
    reliability,
    asOf,
    restDaysPerMonth,
    selectedHabitId,
  );

  @override
  String toString() =>
      'DoitWidgetState(habitId: $habitId, habitName: $habitName, '
      'streakNumber: $streakNumber, isCompletedToday: $isCompletedToday, '
      'reliability: ${reliability.toJsonTag()}, '
      'restDaysPerMonth: $restDaysPerMonth, '
      'selectedHabitId: $selectedHabitId, asOf: $asOf)';
}
