// Unit tests for the `DoitWidgetState.selectedHabitId` field
// (v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052).
//
// Coverage:
//   - selectedHabitId round-trips through toJson / fromJson
//   - selectedHabitId defaults to null when absent in JSON
//     (backwards compatibility with v1.4a..v1.4j caches)
//   - selectedHabitId "" is treated as null on fromJson
//     (defensive against a downgrade that writes a
//     Kotlin `optString(..., "")` empty value)
//   - copyWith selectedHabitId: 'x' produces a new
//     instance with the field replaced; ==/hashCode differ
//   - copyWith without selectedHabitId preserves the prior
//     value (v1.4f restDaysPerMonth precedent)

import 'package:doit/widget/doit_widget_state.dart';
import 'package:flutter_test/flutter_test.dart';

DoitWidgetState _state({
  String habitId = 'h1',
  String? selectedHabitId,
  int restDaysPerMonth = 2,
}) {
  return DoitWidgetState(
    habitId: habitId,
    habitName: 'Read',
    streakNumber: 5,
    isCompletedToday: false,
    reliability: DoitWidgetReliability.optimal,
    asOf: DateTime(2026, 6, 15, 10),
    restDaysPerMonth: restDaysPerMonth,
    selectedHabitId: selectedHabitId,
  );
}

void main() {
  group('DoitWidgetState.selectedHabitId (v1.4k / SYS-125)', () {
    test('round-trips through toJson / fromJson', () {
      final state = _state(selectedHabitId: 'h-pick');
      final json = state.toJson();
      expect(json['selectedHabitId'], 'h-pick');
      final restored = DoitWidgetState.fromJson(json);
      expect(restored.selectedHabitId, 'h-pick');
      expect(restored, equals(state));
    });

    test('defaults to null when absent in JSON (v1.4a..v1.4j cache)', () {
      final json = _state().toJson()..remove('selectedHabitId');
      final restored = DoitWidgetState.fromJson(json);
      expect(restored.selectedHabitId, isNull);
    });

    test('empty string treated as null on fromJson', () {
      // Simulates a downgrade where the Kotlin
      // `WidgetRenderer.openAppIntent` wrote a stale
      // `optString(..., "")` to the cache.
      final json = _state().toJson()..['selectedHabitId'] = '';
      final restored = DoitWidgetState.fromJson(json);
      expect(restored.selectedHabitId, isNull);
    });

    test('null in JSON round-trips to null', () {
      final state = _state();
      final json = state.toJson();
      expect(json['selectedHabitId'], isNull);
      final restored = DoitWidgetState.fromJson(json);
      expect(restored.selectedHabitId, isNull);
    });

    test('copyWith selectedHabitId replaces the field', () {
      final original = _state(selectedHabitId: 'h1');
      final updated = original.copyWith(selectedHabitId: 'h2');
      expect(updated.selectedHabitId, 'h2');
      expect(original.selectedHabitId, 'h1');
      expect(updated, isNot(equals(original)));
    });

    test('copyWith without selectedHabitId preserves the prior value', () {
      final original = _state(selectedHabitId: 'h1');
      final copy = original.copyWith(streakNumber: 7);
      expect(copy.selectedHabitId, 'h1');
      expect(copy.streakNumber, 7);
      // Streak differs but selectedHabitId is preserved.
      expect(copy, isNot(equals(original)));
    });

    test('== / hashCode include selectedHabitId', () {
      final a = _state(selectedHabitId: 'h1');
      final b = _state(selectedHabitId: 'h2');
      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('toString includes selectedHabitId', () {
      final s = _state(selectedHabitId: 'h-pick').toString();
      expect(s, contains('selectedHabitId: h-pick'));
    });
  });
}
