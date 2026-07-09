// CRUD + queries for scheduled messages (one-shot
// "remind me to message this person at this exact time"
// reminders). Mirror of `person_repository.dart`.
//
// v1.8-pr-e2 / SYS-196 / ADR-126: the data-layer half
// (Drift table) shipped in PR-E1 (#104 `6c08d0c`). This
// file is the service-layer half: a singleton that wraps
// the Drift rows behind a small pure-Dart `ScheduledMessage`
// model so the screen layer does not touch Drift directly.
//
// Layer rules (per .claude/rules/lib-services.md):
// - Singleton with `Completer<void> _ready`.
// - `init()` is idempotent (no-op here — the underlying
//   `AppDatabaseService` owns the ready gate).
// - All public methods `await _ready` first.
//
// The status column is the source of truth for "is this
// still pending?" — see `kScheduledMessageStatusPending` /
// `kScheduledMessageStatusFired` / `kScheduledMessageStatusCancelled`.
// A new row defaults to `'pending'` via the SQL
// `withDefault('pending')` clause on the table (see
// `lib/services/db/tables.dart:345`). Repository callers
// can omit `status:` from the `Companion.insert` to
// exercise the SQL default (drift docs §3.2).

import 'dart:async';

import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:meta/meta.dart';

/// Status values for the `ScheduledMessages.status` column.
/// Persisted as TEXT (lowercase). Mirrored in `tables.dart`
/// (the SQL column is open-varchar; the API surface is the
/// enum below). New statuses (e.g. `'snoozed'` for a future
/// MINOR 3 quick-reply action) add a value here AND a test
/// asserting the round-trip survives a save → re-read.
enum ScheduledMessageStatus {
  pending('pending'),
  fired('fired'),
  cancelled('cancelled');

  const ScheduledMessageStatus(this.wire);
  final String wire;

  static ScheduledMessageStatus fromWire(String s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    // Forward-compat: an unknown wire value falls back to
    // pending (we never drop a row on a schema we don't
    // recognize). The screen layer surfaces the row with a
    // "stale status" tag if the wire doesn't match a known
    // value.
    return pending;
  }
}

const String kScheduledMessageStatusPending = 'pending';
const String kScheduledMessageStatusFired = 'fired';
const String kScheduledMessageStatusCancelled = 'cancelled';

/// A scheduled one-shot message reminder. Pure-Dart value
/// object — Drift is the persistence layer; this is what
/// the rest of the app sees.
///
/// Layer rules (per .claude/rules/lib-services.md): no
/// Flutter imports, no `DateTime.now()` (callers pass the
/// reference time when they need it).
@immutable
class ScheduledMessage {
  const ScheduledMessage({
    required this.id,
    required this.personId,
    required this.channelTag,
    required this.channelHandle,
    required this.messageBody,
    required this.fireAt,
    required this.status,
    required this.createdAt,
    this.firedAt,
  });

  /// Stable, opaque id (UUID v4 in the screen layer; the
  /// service does not validate the format — it's a plain
  /// String).
  final String id;

  /// `People.id` of the person being messaged. Nullable so
  /// a one-off "message this number I haven't added yet"
  /// schedule (a future v2.1 affordance) can skip the join.
  final String? personId;

  /// Channel discriminator — matches `PersonChannel.tag`
  /// for the 5 v0.1 channels (`dialer` / `whatsapp` /
  /// `telegram` / `signal` / `sms`). The repository does
  /// NOT validate that the tag is one of the known set;
  /// that responsibility lives in the screen layer (where
  /// the user picks from a known set) and the platform
  /// layer (which builds the URI).
  final String channelTag;

  /// The recipient's handle — phone number, Telegram
  /// username, etc. The repository persists this verbatim;
  /// the channel's `launch({body: messageBody})` is what
  /// does the E.164 normalization at fire time.
  final String channelHandle;

  /// Optional pre-fill body. Null / empty → the channel
  /// launches with no body (dialer always; Signal always;
  /// WhatsApp / Telegram / SMS conditionally).
  final String? messageBody;

  /// Wall-clock fire time (local zone).
  final DateTime fireAt;

  /// Status — see [ScheduledMessageStatus].
  final ScheduledMessageStatus status;

  /// Row creation time.
  final DateTime createdAt;

  /// Wall-clock time the row was marked fired. Null while
  /// pending.
  final DateTime? firedAt;

  /// True when this row still needs a fire. The screen
  /// layer calls this on every rebuild to filter the
  /// "Pending" vs "History" lists.
  bool get isPending => status == ScheduledMessageStatus.pending;

  /// True when the row is in a terminal state. A cancelled
  /// row is NOT re-armed on boot — the [rescheduleAll]
  /// path skips non-pending rows.
  bool get isTerminal =>
      status == ScheduledMessageStatus.fired ||
      status == ScheduledMessageStatus.cancelled;
}

class ScheduledMessageRepository {
  ScheduledMessageRepository._();

  static final ScheduledMessageRepository instance =
      ScheduledMessageRepository._();

  Future<void> get _ready => AppDatabaseService.instance.ready;
  AppDatabase get _db => AppDatabaseService.instance.db;

  // --- mutations --------------------------------------------------

  /// Insert or replace a row. The caller supplies a
  /// complete [ScheduledMessage]; the repository writes
  /// every column (including the status). For a new row
  /// the caller should pass `status: pending` (or omit
  /// the status entirely and let the SQL default take
  /// effect — see [insert]).
  Future<void> save(ScheduledMessage m) async {
    await _ready;
    await _db
        .into(_db.scheduledMessages)
        .insertOnConflictUpdate(_toCompanion(m));
  }

  /// Insert a new row. Returns the saved [ScheduledMessage].
  ///
  /// If [status] is omitted, the SQL `withDefault('pending')`
  /// clause applies (drift docs §3.2). Tests cover both
  /// paths.
  Future<ScheduledMessage> insert({
    required String id,
    required String? personId,
    required String channelTag,
    required String channelHandle,
    required String? messageBody,
    required DateTime fireAt,
    required DateTime createdAt,
    ScheduledMessageStatus? status,
    DateTime? firedAt,
  }) async {
    await _ready;
    await _db
        .into(_db.scheduledMessages)
        .insert(
          ScheduledMessagesCompanion.insert(
            id: id,
            personId: Value(personId),
            channelTag: channelTag,
            channelHandle: channelHandle,
            messageBody: Value(messageBody),
            fireAtMillis: fireAt.millisecondsSinceEpoch,
            status: Value(status?.wire ?? kScheduledMessageStatusPending),
            createdAtMillis: createdAt.millisecondsSinceEpoch,
            firedAtMillis: Value(firedAt?.millisecondsSinceEpoch),
          ),
        );
    final saved = await getById(id);
    if (saved == null) {
      throw StateError('insert vanished: $id');
    }
    return saved;
  }

  /// Mark [id] as fired at [firedAt]. No-op if the row
  /// does not exist (the inbound `onFireAlarm` path may
  /// race a cancel; in that case the cancel wins).
  Future<void> markFired(String id, DateTime firedAt) async {
    await _ready;
    await (_db.update(
      _db.scheduledMessages,
    )..where((t) => t.id.equals(id))).write(
      ScheduledMessagesCompanion(
        // ignore: prefer_const_constructors
        status: Value(kScheduledMessageStatusFired),
        firedAtMillis: Value(firedAt.millisecondsSinceEpoch),
      ),
    );
  }

  /// Mark [id] as cancelled. No-op if the row does not
  /// exist.
  Future<void> cancel(String id) async {
    await _ready;
    await (_db.update(
      _db.scheduledMessages,
    )..where((t) => t.id.equals(id))).write(
      const ScheduledMessagesCompanion(
        status: Value(kScheduledMessageStatusCancelled),
      ),
    );
  }

  /// Hard-delete a row. Used by the "Remove from history"
  /// affordance (a future minor). Today's cancel flow
  /// calls [cancel] instead, which preserves the row for
  /// audit.
  Future<void> deleteById(String id) async {
    await _ready;
    await (_db.delete(
      _db.scheduledMessages,
    )..where((t) => t.id.equals(id))).go();
  }

  /// Delete every row whose [personId] column equals
  /// [personId]. Used when the user archives the person.
  Future<void> deleteForPerson(String personId) async {
    await _ready;
    await (_db.delete(
      _db.scheduledMessages,
    )..where((t) => t.personId.equals(personId))).go();
  }

  // --- queries ----------------------------------------------------

  /// Look up a row by [id]. Returns `null` if not found.
  Future<ScheduledMessage?> getById(String id) async {
    await _ready;
    final row = await (_db.select(
      _db.scheduledMessages,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Every row, ordered by `fireAtMillis` ascending. The
  /// screen layer filters by status client-side (cheap
  /// because the table is small — typical user has <10
  /// pending scheduled messages).
  Future<List<ScheduledMessage>> listAll() async {
    await _ready;
    final rows = await (_db.select(
      _db.scheduledMessages,
    )..orderBy([(t) => OrderingTerm.asc(t.fireAtMillis)])).get();
    return rows.map(_fromRow).toList(growable: false);
  }

  /// Every pending row, ordered by `fireAtMillis` ascending.
  /// Used by [rescheduleAll] on the Kotlin `BootReceiver`
  /// path to rebuild the alarm table.
  Future<List<ScheduledMessage>> listPending() async {
    await _ready;
    final rows =
        await (_db.select(_db.scheduledMessages)
              ..where((t) => t.status.equals(kScheduledMessageStatusPending))
              ..orderBy([(t) => OrderingTerm.asc(t.fireAtMillis)]))
            .get();
    return rows.map(_fromRow).toList(growable: false);
  }

  /// Every pending row for a given person. The Person-tile
  /// "Schedule a message" CTA uses this to show a "+1
  /// scheduled" badge (a future minor — not in this PR).
  Future<List<ScheduledMessage>> pendingFor(String personId) async {
    await _ready;
    final rows =
        await (_db.select(_db.scheduledMessages)
              ..where(
                (t) =>
                    t.personId.equals(personId) &
                    t.status.equals(kScheduledMessageStatusPending),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.fireAtMillis)]))
            .get();
    return rows.map(_fromRow).toList(growable: false);
  }

  // --- mapping ----------------------------------------------------

  ScheduledMessagesCompanion _toCompanion(ScheduledMessage m) {
    return ScheduledMessagesCompanion(
      id: Value(m.id),
      personId: Value(m.personId),
      channelTag: Value(m.channelTag),
      channelHandle: Value(m.channelHandle),
      messageBody: Value(m.messageBody),
      fireAtMillis: Value(m.fireAt.millisecondsSinceEpoch),
      status: Value(m.status.wire),
      createdAtMillis: Value(m.createdAt.millisecondsSinceEpoch),
      firedAtMillis: Value(m.firedAt?.millisecondsSinceEpoch),
    );
  }

  ScheduledMessage _fromRow(ScheduledMessageRow r) {
    return ScheduledMessage(
      id: r.id,
      personId: r.personId,
      channelTag: r.channelTag,
      channelHandle: r.channelHandle,
      messageBody: r.messageBody,
      fireAt: DateTime.fromMillisecondsSinceEpoch(r.fireAtMillis),
      status: ScheduledMessageStatus.fromWire(r.status),
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAtMillis),
      firedAt: r.firedAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r.firedAtMillis!),
    );
  }
}
