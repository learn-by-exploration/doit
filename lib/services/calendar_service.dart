// CalendarService — singleton that turns the device's
// calendar event stream into edge events for the
// `TriggerCalendarEvent` leaves in `lib/triggers/trigger.dart`.
//
// Per the v1.0 / Phase E PR 1 / ADR-023 design:
//   - The platform side is a thin `doit/calendar` method
//     channel (`android/.../CalendarChannel.kt`). The
//     Kotlin side reads `CalendarContract.Instances` for the
//     active calendars and pushes events to Dart on each
//     transition (event-start, event-end, reminder, busy
//     change). The Dart side is a pure publisher; the
//     matching engine in `RoutineExecutor` decides whether
//     each event is a trigger edge for any registered
//     automation.
//   - The `CalendarSource` abstract class is the seam for
//     tests; production wires a
//     `_MethodChannelCalendarSource` that talks to the
//     Kotlin side, tests wire a `ScriptedCalendarSource`.
//   - Library choice: native `CalendarContract` over the
//     `device_calendar` / `add_2_calendar` Flutter packages.
//     See ADR-023 for the full rationale. The native
//     surface is sufficient (read-only access, no event
//     creation), avoids the package dependency churn, and
//     gives us direct access to reminder metadata
//     (`MIN_REMINDER` / `MAX_REMINDER`).
//
// Layer rules (per `.claude/rules/lib-services.md`):
//   - Singleton with `Completer<void> _ready`.
//   - `init()` is idempotent.
//   - All public reads/writes `await _ready.future` first.
//   - No UI imports.

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

// ---------------------------------------------------------------------------
// Event surface
// ---------------------------------------------------------------------------

/// Sealed event emitted by [CalendarService] on each calendar
/// transition. The four leaves map to the four
/// `TriggerCalendarEvent` shapes: `event-start`, `event-end`,
/// `event-reminder`, `free-busy`.
@immutable
sealed class CalendarEvent {
  const CalendarEvent({
    required this.eventId,
    required this.calendarId,
    required this.title,
    required this.at,
  });

  /// Stable id of the calendar event
  /// (`CalendarContract.Instances.EVENT_ID`).
  final String eventId;

  /// Stable id of the calendar
  /// (`CalendarContract.Calendars._ID`).
  final String calendarId;

  /// Display title of the event. Empty string = no title.
  final String title;

  /// Wall-clock time at which the platform pushed the event.
  final DateTime at;
}

/// Fires the moment an event transitions from "upcoming" to
/// "in progress". Matches `TriggerCalendarEventStart`.
@immutable
final class CalendarEventStarted extends CalendarEvent {
  const CalendarEventStarted({
    required super.eventId,
    required super.calendarId,
    required super.title,
    required super.at,
  });
}

/// Fires the moment an event transitions from "in progress"
/// to "ended". Matches `TriggerCalendarEventEnd`.
@immutable
final class CalendarEventEnded extends CalendarEvent {
  const CalendarEventEnded({
    required super.eventId,
    required super.calendarId,
    required super.title,
    required super.at,
  });
}

/// Fires at the event's reminder offset (e.g. 5 minutes
/// before the start, the default Android Calendar
/// notification time). Matches `TriggerCalendarReminder`.
@immutable
final class CalendarEventReminder extends CalendarEvent {
  const CalendarEventReminder({
    required super.eventId,
    required super.calendarId,
    required super.title,
    required super.at,
  });
}

/// Fires when the user's "free / busy" status changes.
/// Matches `TriggerFreeBusy`. The [isBusy] flag is true when
/// the user is now in a busy event; false when the most
/// recent busy event has ended.
@immutable
final class CalendarBusyChange extends CalendarEvent {
  const CalendarBusyChange({
    required super.eventId,
    required super.calendarId,
    required super.title,
    required super.at,
    required this.isBusy,
  });

  final bool isBusy;
}

// ---------------------------------------------------------------------------
// Source seam
// ---------------------------------------------------------------------------

/// Abstract source the [CalendarService] reads events from.
/// Production wires [_MethodChannelCalendarSource]; tests
/// wire [ScriptedCalendarSource].
abstract class CalendarSource {
  /// Start the source. After this future resolves the
  /// service may subscribe to [events].
  Future<void> start();

  /// Stop the source. Idempotent.
  Future<void> stop();

  /// Broadcast stream of events. The service is the only
  /// listener; multiple subscribers in app code listen to
  /// [CalendarService.events] instead.
  Stream<CalendarEvent> get events;

  /// One-shot read of the currently-installed calendar
  /// accounts. The user picks one in the on-demand
  /// permission sheet. Returns an empty list when no
  /// accounts are available.
  Future<List<CalendarAccount>> listAccounts();
}

/// Plain value class for a calendar account. The
/// `accountId` is the Android
/// `CalendarContract.Calendars.ACCOUNT_NAME`; `displayName`
/// is the user-facing label.
@immutable
class CalendarAccount {
  const CalendarAccount({required this.accountId, required this.displayName});

  final String accountId;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is CalendarAccount &&
      other.accountId == accountId &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(accountId, displayName);
}

/// Production source: talks to the `doit/calendar` method
/// channel. The Kotlin side pushes events via
/// `invokeMethod("onCalendarEvent", map)`.
class _MethodChannelCalendarSource implements CalendarSource {
  _MethodChannelCalendarSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('doit/calendar');

  final MethodChannel _channel;
  final StreamController<CalendarEvent> _controller =
      StreamController<CalendarEvent>.broadcast();
  bool _handlerInstalled = false;

  Future<void> _installHandler() async {
    if (_handlerInstalled) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCalendarEvent') {
        final args = call.arguments;
        if (args is Map) {
          final ev = _decode(args);
          if (ev != null) _controller.add(ev);
        }
      }
      return null;
    });
    _handlerInstalled = true;
  }

  static CalendarEvent? _decode(Map<Object?, Object?> m) {
    final kind = m['kind'] as String?;
    final eventId = (m['eventId'] as String?) ?? '';
    final calendarId = (m['calendarId'] as String?) ?? '';
    final title = (m['title'] as String?) ?? '';
    final atMs = (m['atMs'] as int?) ?? 0;
    final at = DateTime.fromMillisecondsSinceEpoch(atMs);
    switch (kind) {
      case 'start':
        return CalendarEventStarted(
          eventId: eventId,
          calendarId: calendarId,
          title: title,
          at: at,
        );
      case 'end':
        return CalendarEventEnded(
          eventId: eventId,
          calendarId: calendarId,
          title: title,
          at: at,
        );
      case 'reminder':
        return CalendarEventReminder(
          eventId: eventId,
          calendarId: calendarId,
          title: title,
          at: at,
        );
      case 'busy':
        final isBusy = (m['isBusy'] as bool?) ?? false;
        return CalendarBusyChange(
          eventId: eventId,
          calendarId: calendarId,
          title: title,
          at: at,
          isBusy: isBusy,
        );
      default:
        return null;
    }
  }

  @override
  Future<void> start() async {
    await _installHandler();
    await _channel.invokeMethod<void>('startStream');
  }

  @override
  Future<void> stop() async {
    if (!_handlerInstalled) return;
    try {
      await _channel.invokeMethod<void>('stopStream');
    } on MissingPluginException catch (e) {
      if (kDebugMode) debugPrint('CalendarSource.stop: $e');
    }
  }

  @override
  Stream<CalendarEvent> get events => _controller.stream;

  @override
  Future<List<CalendarAccount>> listAccounts() async {
    final result = await _channel.invokeMethod<List<Object?>>('listAccounts');
    if (result == null) return const <CalendarAccount>[];
    return result
        .whereType<Map<Object?, Object?>>()
        .map(
          (m) => CalendarAccount(
            accountId: (m['accountId'] as String?) ?? '',
            displayName: (m['displayName'] as String?) ?? '',
          ),
        )
        .where((a) => a.accountId.isNotEmpty)
        .toList(growable: false);
  }
}

/// Test source: a hand-driven [StreamController] the unit
/// test can push scripted events through.
@visibleForTesting
class ScriptedCalendarSource implements CalendarSource {
  ScriptedCalendarSource({
    StreamController<CalendarEvent>? controller,
    List<CalendarAccount> accounts = const <CalendarAccount>[],
  }) : _controller = controller ?? StreamController<CalendarEvent>.broadcast(),
       _accounts = List<CalendarAccount>.unmodifiable(accounts);

  final StreamController<CalendarEvent> _controller;
  final List<CalendarAccount> _accounts;
  int startCalls = 0;
  int stopCalls = 0;
  Object? startError;

  /// Push an event to listeners. Mirrors the Kotlin
  /// `pushCalendarEvent` path.
  void push(CalendarEvent ev) => _controller.add(ev);

  /// Fail the next `start()` call.
  @override
  Future<void> start() async {
    startCalls++;
    final e = startError;
    if (e != null) {
      startError = null;
      throw e;
    }
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Stream<CalendarEvent> get events => _controller.stream;

  @override
  Future<List<CalendarAccount>> listAccounts() async => _accounts;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Singleton. Owns the source subscription, the broadcast
/// `events` stream the rest of the app listens to, and the
/// most-recent busy state (cached for the matching engine).
class CalendarService {
  CalendarService._();

  /// The single global instance.
  static final CalendarService instance = CalendarService._();

  Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  final StreamController<CalendarEvent> _controller =
      StreamController<CalendarEvent>.broadcast();

  /// Subscribe to receive every [CalendarEvent] (start /
  /// end / reminder / busy-change). The stream is broadcast;
  /// multiple listeners (RoutineExecutor, future debug
  /// screen) are allowed.
  Stream<CalendarEvent> get events => _controller.stream;

  CalendarSource? _source;
  StreamSubscription<CalendarEvent>? _sub;

  /// Most recent "is busy" state. The matching engine reads
  /// this to detect the `false → true` and `true → false`
  /// transitions for `TriggerFreeBusy`.
  @visibleForTesting
  bool? lastIsBusy;

  /// Initialize the service. Idempotent. Starts the source
  /// and arms the broadcast subscription.
  Future<void> init() async {
    if (_ready.isCompleted) return;
    _source ??= _MethodChannelCalendarSource();
    await _source!.start();
    _sub = _source!.events.listen(_onEvent, onError: _onError);
    _ready.complete();
  }

  /// List the currently-installed calendar accounts. Used
  /// by the on-demand permission sheet to drive the account
  /// picker.
  Future<List<CalendarAccount>> listAccounts() async {
    await ready;
    return _source!.listAccounts();
  }

  /// Inject a source for tests. The default constructor
  /// wires the real method channel; tests pass a
  /// [ScriptedCalendarSource] so they can drive the stream
  /// deterministically.
  @visibleForTesting
  void debugSetSource(CalendarSource source) {
    _source = source;
  }

  /// Reset for tests. Re-creates the `_ready` Completer,
  /// the broadcast controller, cancels the source
  /// subscription, stops the source, and clears the busy
  /// cache.
  void resetForTesting() {
    if (!_ready.isCompleted) _ready.complete();
    _ready = Completer<void>();
    _sub?.cancel();
    _sub = null;
    final src = _source;
    _source = null;
    lastIsBusy = null;
    if (src != null) {
      unawaited(src.stop());
    }
  }

  // --- internal ----------------------------------------------------

  void _onEvent(CalendarEvent ev) {
    if (ev is CalendarBusyChange) {
      lastIsBusy = ev.isBusy;
    }
    _controller.add(ev);
  }

  void _onError(Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('CalendarService source error: $error');
    }
  }
}
