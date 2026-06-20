// Person model — sealed hierarchy of [PersonChannel]s.
//
// A Person is the smallest amount of state needed to nudge
// the user about a contact on a cadence. The app does NOT
// store the contact's full vCard; it stores the lookup key
// (a stable hash of the contact URI), the display name
// (cached at first resolution), and the channel handle.
//
// Layer rules (per .claude/rules/lib-people.md):
//   - No Flutter imports.
//   - The model is immutable; mutations go through
//     [Person.copyWith].
//
// v1.0 (Phase C, SYS-072): adds `automations` for non-default
// routine rules. Default is an empty list (the `ActionNotify`
// synthesized at dispatch time).

import 'package:doit/people/cadence.dart';
import 'package:doit/routines/routine.dart';
import 'package:meta/meta.dart';

/// Stable, opaque person identifier. Same shape as [HabitId]:
/// a String alias for now, ready to be promoted to a typed
/// value-class in v0.2.
typedef PersonId = String;

/// A sealed channel. The 5 v0.1 channels are exhaustive; add a
/// v0.2 channel (e.g., `ChannelEmail`) by adding a subclass.
@immutable
sealed class PersonChannel {
  const PersonChannel();
}

/// Open the system dialer with the contact's number. No
/// `CALL_PHONE` permission is used; the user must press
/// the call button themselves. See doit-non-negotiables.
final class ChannelDialer extends PersonChannel {
  const ChannelDialer(this.phoneNumber);
  final String phoneNumber;

  @override
  bool operator ==(Object other) =>
      other is ChannelDialer && other.phoneNumber == phoneNumber;

  @override
  int get hashCode => phoneNumber.hashCode;
}

/// Open WhatsApp with a deep link to the given number.
final class ChannelWhatsApp extends PersonChannel {
  const ChannelWhatsApp(this.phoneNumber);
  final String phoneNumber;

  @override
  bool operator ==(Object other) =>
      other is ChannelWhatsApp && other.phoneNumber == phoneNumber;

  @override
  int get hashCode => phoneNumber.hashCode;
}

/// Open Telegram with a deep link to the given username.
final class ChannelTelegram extends PersonChannel {
  const ChannelTelegram(this.username);
  final String username;

  @override
  bool operator ==(Object other) =>
      other is ChannelTelegram && other.username == username;

  @override
  int get hashCode => username.hashCode;
}

/// Open Signal with a deep link to the given number.
final class ChannelSignal extends PersonChannel {
  const ChannelSignal(this.phoneNumber);
  final String phoneNumber;

  @override
  bool operator ==(Object other) =>
      other is ChannelSignal && other.phoneNumber == phoneNumber;

  @override
  int get hashCode => phoneNumber.hashCode;
}

/// Pre-fill an SMS to the given number. The system handles
/// actually sending the message.
final class ChannelSms extends PersonChannel {
  const ChannelSms(this.phoneNumber);
  final String phoneNumber;

  @override
  bool operator ==(Object other) =>
      other is ChannelSms && other.phoneNumber == phoneNumber;

  @override
  int get hashCode => phoneNumber.hashCode;
}

/// Snapshot of a person as resolved against the system
/// contacts. Returned by `PersonResolver` (service layer).
@immutable
class PersonSnapshot {
  const PersonSnapshot({
    required this.person,
    required this.displayName,
    required this.resolvable,
  });

  final Person person;
  final String displayName;

  /// `true` if the underlying contact is still resolvable. If
  /// `false`, the cadence habit is paused and the user is
  /// shown a banner.
  final bool resolvable;
}

/// A sealed person. The model carries a channel, a cadence,
/// and a stable lookup key. The display name is a snapshot
/// value (it can change if the user edits their contact) and
/// is not stored on [Person] — it lives in the service-layer
/// cache.
///
/// v0.2 (WF-027): a [Person] may be temporarily paused
/// (vacation, contact-deleted, etc.). The pause state is
/// stored as a `pausedUntil` timestamp. A paused period does
/// not break the cadence streak.
@immutable
sealed class Person {
  const Person({
    required this.id,
    required this.lookupKey,
    required this.channel,
    required this.cadence,
    required this.createdAt,
    this.pausedUntil,
    this.automations = const <Automation>[],
  });

  /// Stable identifier within do it. Different from the
  /// `lookupKey`, which identifies the *contact*; the `id`
  /// identifies the *habit binding* to that contact.
  final PersonId id;

  /// Stable hash of the contact URI. Re-derived from
  /// `ContactsContract.Contacts#LOOKUP_KEY` at first read; the
  /// app never stores the contact's full vCard.
  final String lookupKey;

  /// The channel the user wants to use. Immutable per
  /// Person; to change the channel, archive the person and
  /// create a new one.
  final PersonChannel channel;

  final PersonCadence cadence;
  final DateTime createdAt;

  /// Optional v0.2 pause timestamp. While the wall clock is
  /// before [pausedUntil], the scheduler does not fire
  /// reminders for this person and the cadence does not
  /// consume a missed-period streak break.
  final DateTime? pausedUntil;

  /// v1.0 (Phase C). Non-default automation rules. Empty
  /// list = the default `ActionNotify` (synthesized at
  /// dispatch time, not stored). Stored on the row as
  /// `People.automations_json`.
  final List<Automation> automations;

  /// `true` when the person is currently paused (i.e.,
  /// [pausedUntil] is set and in the future at [now]).
  bool isPausedAt(DateTime now) =>
      pausedUntil != null && pausedUntil!.isAfter(now);

  /// Returns a copy with selected fields replaced. Subclasses
  /// pass through the base args via `super.copyWith` if they
  /// need to preserve them.
  Person copyWith({
    PersonChannel? channel,
    PersonCadence? cadence,
    DateTime? pausedUntil,
    bool clearPausedUntil = false,
    List<Automation>? automations,
  });
}

/// A person bound to a single, named contact. The "real"
/// person for v0.1 — every contact added to a cadence is a
/// [ContactPerson].
@immutable
final class ContactPerson extends Person {
  const ContactPerson({
    required super.id,
    required super.lookupKey,
    required super.channel,
    required super.cadence,
    required super.createdAt,
    super.pausedUntil,
    super.automations,
  });

  @override
  ContactPerson copyWith({
    PersonChannel? channel,
    PersonCadence? cadence,
    DateTime? pausedUntil,
    bool clearPausedUntil = false,
    List<Automation>? automations,
  }) {
    return ContactPerson(
      id: id,
      lookupKey: lookupKey,
      channel: channel ?? this.channel,
      cadence: cadence ?? this.cadence,
      createdAt: createdAt,
      pausedUntil: clearPausedUntil ? null : (pausedUntil ?? this.pausedUntil),
      automations: automations ?? this.automations,
    );
  }

  @override
  bool operator ==(Object other) => other is ContactPerson && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
