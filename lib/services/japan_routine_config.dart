// JapanRoutineConfig — persisted configuration for the
// Japan silent-mode routine (template #16).
//
// Per Phase F PR 2 (SYS-075 / SYS-079 / ADR-019):
//
//   - `enabled` flips the routine on or off. When `false`,
//     the `CallScreeningService` is configured with
//     `setEnabled(false)` and no contacts are matched — the
//     service passes every call through.
//   - `contactIds` are the E.164 phone numbers the screening
//     service should treat as "known contact" for the
//     `TriggerCallIncomingKnownContact` matching predicate.
//     An empty list means no contacts are matched; the
//     routine is effectively a no-op until the user picks
//     at least one.
//   - `targetMode` is the `SilentMode` the routine snaps the
//     ringer to when a contact calls while silent. Maps
//     1-to-1 to `CallInterceptorService.RingerMode`.
//
// Persistence: three keys under
// `doit.japan_routine.{enabled,contact_ids,target_mode}` in
// `SharedPreferences`. See `SettingsService.setJapanRoutine`.

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

import 'package:doit/triggers/trigger.dart' show SilentMode;

/// Immutable value class. Equality is structural so a fresh
/// `copyWith` round-trips through `==` cleanly.
@immutable
class JapanRoutineConfig {
  const JapanRoutineConfig({
    required this.enabled,
    required this.contactIds,
    required this.targetMode,
  });

  /// `true` to enable the routine. The screening service is
  /// configured `setEnabled(enabled)`; when `false`, no calls
  /// are intercepted.
  final bool enabled;

  /// The E.164 phone numbers the routine matches. Order is
  /// not significant. Empty = no matches.
  final List<String> contactIds;

  /// The ringer mode the routine snaps the device to when a
  /// matched contact calls while silent.
  final SilentMode targetMode;

  /// Default "off" config used at first launch.
  static const JapanRoutineConfig defaults = JapanRoutineConfig(
    enabled: false,
    contactIds: <String>[],
    targetMode: SilentMode.normal,
  );

  /// True if the user has at least enabled the toggle. The
  /// contact-list emptiness is treated separately — a
  /// routine with `enabled == true` and `contactIds == []` is
  /// valid but fires nothing.
  bool get isConfigured => enabled;

  /// Return a copy of this config with the given fields
  /// replaced. `contactIds` is captured as an unmodifiable
  /// list to match the persistence round-trip.
  JapanRoutineConfig copyWith({
    bool? enabled,
    List<String>? contactIds,
    SilentMode? targetMode,
  }) {
    return JapanRoutineConfig(
      enabled: enabled ?? this.enabled,
      contactIds: contactIds == null
          ? this.contactIds
          : List<String>.unmodifiable(contactIds),
      targetMode: targetMode ?? this.targetMode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! JapanRoutineConfig) return false;
    if (other.enabled != enabled) return false;
    if (other.targetMode != targetMode) return false;
    if (other.contactIds.length != contactIds.length) return false;
    for (var i = 0; i < contactIds.length; i++) {
      if (other.contactIds[i] != contactIds[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(enabled, Object.hashAll(contactIds), targetMode);

  @override
  String toString() =>
      'JapanRoutineConfig('
      'enabled: $enabled, '
      'contactIds: ${contactIds.length}, '
      'targetMode: ${targetMode.name}'
      ')';
}
