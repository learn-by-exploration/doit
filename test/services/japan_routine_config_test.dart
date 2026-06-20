// Tests for JapanRoutineConfig (v1.0 / Phase F PR 2 / SYS-075 /
// ADR-019 follow-up).
//
// Coverage:
//   - Defaults: disabled, empty contactIds, normal target mode.
//   - `==` and `hashCode` are structural across the three fields.
//   - `copyWith` replaces only the named fields; omitted fields
//     preserve the prior value (including the contactIds list
//     identity).
//   - `copyWith` captures the new contactIds list as unmodifiable.
//   - `isConfigured` reflects `enabled` (NOT the contact-list
//     emptiness).
//   - `toString` carries the field values for debug printing.

import 'package:doit/services/japan_routine_config.dart';
import 'package:doit/triggers/trigger.dart' show SilentMode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JapanRoutineConfig.defaults', () {
    test('is disabled, has no contacts, and target mode is normal', () {
      expect(JapanRoutineConfig.defaults.enabled, false);
      expect(JapanRoutineConfig.defaults.contactIds, isEmpty);
      expect(JapanRoutineConfig.defaults.targetMode, SilentMode.normal);
      expect(JapanRoutineConfig.defaults.isConfigured, false);
    });
  });

  group('equality + hashCode', () {
    test('two configs with the same fields are equal', () {
      const a = JapanRoutineConfig(
        enabled: true,
        contactIds: <String>['+15551234567'],
        targetMode: SilentMode.vibrate,
      );
      const b = JapanRoutineConfig(
        enabled: true,
        contactIds: <String>['+15551234567'],
        targetMode: SilentMode.vibrate,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('two configs that differ on enabled are not equal', () {
      const a = JapanRoutineConfig(
        enabled: true,
        contactIds: <String>[],
        targetMode: SilentMode.normal,
      );
      const b = JapanRoutineConfig(
        enabled: false,
        contactIds: <String>[],
        targetMode: SilentMode.normal,
      );
      expect(a, isNot(equals(b)));
    });

    test('two configs that differ on targetMode are not equal', () {
      const a = JapanRoutineConfig(
        enabled: true,
        contactIds: <String>[],
        targetMode: SilentMode.vibrate,
      );
      const b = JapanRoutineConfig(
        enabled: true,
        contactIds: <String>[],
        targetMode: SilentMode.silent,
      );
      expect(a, isNot(equals(b)));
    });

    test('two configs that differ on contactIds are not equal', () {
      const a = JapanRoutineConfig(
        enabled: true,
        contactIds: <String>['+1'],
        targetMode: SilentMode.normal,
      );
      const b = JapanRoutineConfig(
        enabled: true,
        contactIds: <String>['+2'],
        targetMode: SilentMode.normal,
      );
      expect(a, isNot(equals(b)));
    });

    test('contactId order matters for equality', () {
      const a = JapanRoutineConfig(
        enabled: true,
        contactIds: <String>['+1', '+2'],
        targetMode: SilentMode.normal,
      );
      const b = JapanRoutineConfig(
        enabled: true,
        contactIds: <String>['+2', '+1'],
        targetMode: SilentMode.normal,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('copyWith', () {
    test('omitting every field returns a structurally-equal config', () {
      const original = JapanRoutineConfig(
        enabled: true,
        contactIds: <String>['+1', '+2'],
        targetMode: SilentMode.vibrate,
      );
      final copy = original.copyWith();
      expect(copy, equals(original));
    });

    test('replaces only the named field', () {
      const original = JapanRoutineConfig(
        enabled: true,
        contactIds: <String>['+1'],
        targetMode: SilentMode.vibrate,
      );
      final copy = original.copyWith(enabled: false);
      expect(copy.enabled, false);
      expect(copy.contactIds, original.contactIds);
      expect(copy.targetMode, original.targetMode);
    });

    test('replaces contactIds and wraps them as unmodifiable', () {
      const original = JapanRoutineConfig(
        enabled: true,
        contactIds: <String>['+1'],
        targetMode: SilentMode.normal,
      );
      final copy = original.copyWith(contactIds: <String>['+1', '+2', '+3']);
      expect(copy.contactIds, <String>['+1', '+2', '+3']);
      expect(() => copy.contactIds.add('+4'), throwsUnsupportedError);
    });

    test('replaces targetMode', () {
      const original = JapanRoutineConfig(
        enabled: true,
        contactIds: <String>[],
        targetMode: SilentMode.normal,
      );
      final copy = original.copyWith(targetMode: SilentMode.silent);
      expect(copy.targetMode, SilentMode.silent);
      expect(copy.enabled, original.enabled);
    });
  });

  group('isConfigured', () {
    test('is true when enabled is true (regardless of contactIds)', () {
      const c = JapanRoutineConfig(
        enabled: true,
        contactIds: <String>[],
        targetMode: SilentMode.normal,
      );
      expect(c.isConfigured, true);
    });

    test('is false when enabled is false', () {
      const c = JapanRoutineConfig(
        enabled: false,
        contactIds: <String>['+1', '+2'],
        targetMode: SilentMode.normal,
      );
      expect(c.isConfigured, false);
    });
  });

  group('toString', () {
    test('carries enabled, contactIds length, and targetMode name', () {
      const c = JapanRoutineConfig(
        enabled: true,
        contactIds: <String>['+1', '+2'],
        targetMode: SilentMode.vibrate,
      );
      final s = c.toString();
      expect(s, contains('enabled: true'));
      expect(s, contains('contactIds: 2'));
      expect(s, contains('vibrate'));
    });
  });
}
