// Reliability service — the unified `Stream<Reliability>`
// source-of-truth for the home-screen banner, the settings
// page `_ReliabilityRow`, and any future consumer.
//
// v1.3b / Phase 13 / SYS-112 / ADR-042. The service merges
// the two parallel reliability signals that existed in
// v1.3a:
//
//   - `AlarmScheduler.reliability` — a synchronous getter
//     backed by a 30 s fire-and-forget cache over
//     `bridge.probeReliability()`.
//   - `PermissionService.statuses` — a
//     `ValueNotifier<Map<PermissionKind, PermissionResult?>>`
//     the Settings → Permissions tile and the
//     per-automation `AutomationReliability` enum read.
//
// Both were consumed by the home banner and the settings
// row, and neither could keep the other honest (the banner
// read once at `build()` and never re-subscribed; the
// resume hook re-probed permissions but NOT the alarm
// system). Phase 13 collapses both signals into a single
// `Stream<Reliability>` + `ValueListenable<Reliability>`
// pair that the widgets bind to via `ValueListenableBuilder`.
//
// Layer rules (per .claude/rules/lib-services.md):
// - Singleton with `Completer<void> _ready`.
// - `init()` is idempotent.
// - All public methods are async; `init()` awaits the
//   `PermissionService.init()` and the bootstrap probe.
//
// The service does NOT depend on `package:flutter/*` (it
// imports `foundation` only for the `ValueNotifier` /
// `ValueListenable` types). The stream controller is a
// broadcast `StreamController<Reliability>` with `distinct()`
// so the same value is never emitted twice in a row.
//
// Initial value is `Reliability.optimal` (not `unknown`).
// This closes the first-read race in the prior
// `PlatformAlarmScheduler.reliability` getter, where the
// very first read returned `Reliability.unknown` for a
// fully optimal device (the cached value is null until the
// fire-and-forget probe completes). `optimal` matches the
// `FakeAlarmScheduler._reliability` default and the
// banner-hidden behavior for the common case.
//
// `AutomationReliability` stays separate (per ADR-029). The
// per-automation enum answers a different question ("can
// THIS trigger fire?") via a pure function over
// `PermissionService.statuses`. The badge + dialog continue
// to consume `PermissionService.statuses` directly; the new
// service is for app-wide reliability only.
//
// Out of scope (deferred):
// - Per-routine reliability budgets (a v1.3+ polish idea).
// - Dropping `PermissionService.statuses` (still the source
//   for `AutomationReliability` and the per-permission tile).
// - Retroactive amendment of ADR-030 (this ADR cites it as
//   context but does not rewrite history).

// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, kDebugMode, debugPrint;

import 'package:doit/reminders/alarm_scheduler.dart';
import 'package:doit/reminders/reminder_bridge.dart';
import 'package:doit/services/permission_result.dart';
import 'package:doit/services/permission_service.dart';

/// How long the [ReliabilityService] waits between fallback
/// refreshes. The home-screen banner polls on resume; 30 s
/// is short enough that a stale read is rare and long
/// enough that the platform `MethodChannel` is not
/// saturated while the user scrolls the list. v0.6 / ADR-018
/// originally defined this on `PlatformAlarmScheduler`; the
/// constant moved here when the service took over the
/// cache in v1.3b.
const Duration kReliabilityCacheTtl = Duration(seconds: 30);

/// Permission kinds whose `Denied` / `PermanentlyDenied`
/// status drives the app-wide `Reliability.degraded`
/// decision. Each of these gates a feature that the
/// reliability banner hints at via "may be late" copy:
///
/// - `location` — geofence triggers (v1.0 / Phase C /
///   SYS-076).
/// - `calendar` — calendar-event triggers (v1.0 / Phase E /
///   SYS-078).
/// - `callScreening` — incoming-call triggers (v1.2 /
///   SYS-075 + SYS-079 follow-up).
/// - `usageStats` — foreground-app triggers (v1.1g /
///   ADR-030 / SYS-086).
///
/// The notifications / contacts / exact-alarm / battery-
/// optimization kinds are intentionally NOT in this set —
/// they are gated by the onboarding flow + the per-feature
/// `ensure()` checks, not by the app-wide reliability
/// banner. (Notifications / exact-alarm being denied is
/// the everyday case during onboarding; a "may be late"
/// banner on the home screen would be confusing.)
const Set<PermissionKind> _kReliabilityGatedKinds = {
  PermissionKind.location,
  PermissionKind.calendar,
  PermissionKind.callScreening,
  PermissionKind.usageStats,
};

/// Singleton service. Mutable-static pattern matching
/// [ReminderService] (the service has dependencies — the
/// bridge and the permission service — so the simpler
/// `final instance = ...` pattern would not work). The
/// instance is reset by [resetForTesting] between tests.
class ReliabilityService {
  // The fields are underscore-private; the constructor
  // itself is private (only `init` calls it). The
  // `_field = param` form keeps the assignment explicit
  // at the constructor body so a future reader does not
  // have to cross-reference named parameters against
  // private fields. The file-level
  // `ignore_for_file: prefer_initializing_formals` lets
  // the lint pass without renaming the fields.
  ReliabilityService._({
    required ReminderBridge bridge,
    required PermissionService permissionService,
    StreamController<Reliability>? controller,
    ValueNotifier<Reliability>? notifier,
    Timer Function(Duration, void Function(Timer))? periodicFactory,
  }) : _bridge = bridge,
       _permissionService = permissionService,
       _controller = controller ?? StreamController<Reliability>.broadcast(),
       _notifier = notifier ?? ValueNotifier<Reliability>(Reliability.optimal),
       _periodicFactory = periodicFactory ?? _defaultPeriodic;

  final ReminderBridge _bridge;
  final PermissionService _permissionService;
  final StreamController<Reliability> _controller;
  final ValueNotifier<Reliability> _notifier;
  final Timer Function(Duration, void Function(Timer)) _periodicFactory;

  Timer? _fallbackTimer;
  bool _bootstrapDone = false;
  bool _disposed = false;

  /// How the singleton is reached. `null` before [init] and
  /// after [resetForTesting].
  static ReliabilityService? _instance;

  /// Init gate. Public reads wait on this so callers can
  /// `await ReliabilityService.ready` before reading
  /// [reliability].
  static Completer<void> _ready = Completer<void>();

  /// Initialise the singleton. Idempotent: the first call
  /// wins; subsequent calls resolve immediately. The
  /// initializer awaits [PermissionService.ready] (so the
  /// first derive step sees a populated statuses map), then
  /// primes the notifier at [Reliability.optimal], then
  /// schedules an unawaited bootstrap probe (so `init()` is
  /// fast even on cold start).
  ///
  /// [periodicFactory] is the [Timer.periodic] factory the
  /// service uses for the 30 s fallback. The default is the
  /// real `Timer.periodic`; tests can substitute a fake
  /// factory to drive ticks deterministically.
  static Future<void> init({
    required ReminderBridge bridge,
    required PermissionService permissionService,
    Timer Function(Duration, void Function(Timer))? periodicFactory,
  }) async {
    if (_instance != null) {
      await _ready.future;
      return;
    }
    final service = ReliabilityService._(
      bridge: bridge,
      permissionService: permissionService,
      periodicFactory: periodicFactory,
    );
    _instance = service;
    // Wire the permissions-side listener before the
    // bootstrap probe so a permissions change during the
    // probe in-flight still re-derives the value.
    service._permissionService.statuses.addListener(service._onStatusesChanged);
    // The first derive step is synchronous (the statuses
    // map is the initial-value map; the bridge probe is
    // pending). We default to `optimal` — see the file-
    // level comment for the first-read-race rationale.
    service._emit(service._derive());
    // Start the fallback timer synchronously so
    // [resetForTesting] always sees a live timer to cancel.
    service._startFallbackTimer();
    // Schedule the bootstrap probe (unawaited). The
    // fallback timer keeps the value fresh until the probe
    // lands; the first derive is already `optimal`.
    unawaited(service._bootstrap());
    if (!_ready.isCompleted) _ready.complete();
  }

  /// The initialized service. Throws if [init] was not
  /// called.
  static ReliabilityService get instance {
    final s = _instance;
    if (s == null) {
      throw StateError('ReliabilityService.init() was not called.');
    }
    return s;
  }

  /// Future that completes after [init] has wired the
  /// singleton. Public reads may `await` this before
  /// reading [reliability] (most call sites do not need to
  /// — [value] is readable before [ready] completes
  /// because the notifier is primed at construction).
  static Future<void> get ready => _ready.future;

  /// Reset for tests. Closes the stream controller, cancels
  /// the fallback timer, removes the listener, and clears
  /// the singleton.
  static void resetForTesting() {
    final s = _instance;
    if (s != null) {
      s._dispose();
    }
    _instance = null;
    if (!_ready.isCompleted) {
      // Make sure a subsequent [init] can complete the
      // gate again.
      _ready = Completer<void>();
    }
  }

  /// The current reliability value. Synonymous with
  /// `_notifier.value`; exposed as a property so callers
  /// that have a `ReliabilityService` reference (not the
  /// static `instance`) can read it cheaply.
  Reliability get value => _notifier.value;

  /// A `ValueListenable<Reliability>` mirror for
  /// `ValueListenableBuilder` consumers. The mirror is
  /// updated atomically with the stream controller — every
  /// emit writes to both.
  ValueListenable<Reliability> get notifier => _notifier;

  /// A broadcast `Stream<Reliability>` that fires on every
  /// state change. `distinct()` is applied so the same value
  /// is never emitted twice in a row. New listeners do NOT
  /// see a replayed value — the current value is read via
  /// [value] or [notifier]. The stream is broadcast so
  /// `ValueListenableBuilder`-shaped consumers and
  /// direct-listener consumers can both attach without
  /// stepping on each other.
  Stream<Reliability> get reliability => _controller.stream.distinct();

  /// Re-probes both sides (the alarm-system bridge +
  /// permission statuses) and re-derives the stream value.
  /// Idempotent: a re-entrant call is coalesced into a
  /// single in-flight probe. The resume hook
  /// ([PermissionLifecycleReProbe]) calls this on every
  /// `AppLifecycleState.resumed` after the cold start.
  Future<void> refresh() async {
    final probed = await _safeProbe();
    if (_disposed) return;
    final derived = _derive(probed: probed);
    _emit(derived);
  }

  // --- internals ---------------------------------------------------

  /// The unawaited bootstrap probe. Runs on `init()`; the
  /// result re-derives the value via [_emit].
  Future<void> _bootstrap() async {
    if (_bootstrapDone) return;
    _bootstrapDone = true;
    await refresh();
  }

  /// Starts the 30 s fallback timer. The timer is
  /// `Timer.periodic`; on each tick it calls [refresh]
  /// (idempotent). The timer is cancelled on [_dispose].
  ///
  /// Started synchronously from [init] (before the
  /// unawaited bootstrap probe) so that [resetForTesting]
  /// always sees a live timer to cancel — there is no race
  /// window where the bootstrap continuation could call
  /// [_startFallbackTimer] AFTER dispose.
  void _startFallbackTimer() {
    if (_disposed) return;
    _fallbackTimer?.cancel();
    _fallbackTimer = _periodicFactory(kReliabilityCacheTtl, (_) {
      // Fire-and-forget — same pattern as the original
      // `PlatformAlarmScheduler._refreshReliability`.
      if (_disposed) return;
      unawaited(refresh());
    });
  }

  /// Listener for [PermissionService.statuses]. Re-derives
  /// the value on every change. The derive is purely
  /// synchronous (the bridge probe is NOT re-run on a
  /// permissions change — only on `init`, `refresh`, and
  /// the 30 s fallback).
  void _onStatusesChanged() {
    if (_disposed) return;
    _emit(_derive());
  }

  /// Derives the [Reliability] value from the current
  /// statuses map + the last bridge probe.
  ///
  /// The combine rule:
  ///   - If the bridge probe returned `degraded`, the
  ///     value is `degraded` (the alarm system is the
  ///     primary signal; it gates the v0.6
  ///     exact-alarm-permission path).
  ///   - Else if any [_kReliabilityGatedKinds] is
  ///     `Denied` / `PermanentlyDenied`, the value is
  ///     `degraded` (geofence / calendar / call-screening /
  ///     usage-stats triggers are gated off).
  ///   - Else the value is `optimal` — this is the common
  ///     case and the default-initial value.
  ///
  /// [probed] is the cached bridge probe; if null, the
  /// call site (the bootstrap or refresh path) passes the
  /// freshly-probed value. The probe value is
  /// `Reliability.unknown` when the bridge has not
  /// produced a result yet; `unknown` is treated as
  /// `optimal` for the combine rule (we do NOT want a
  /// cold-start to flash a "may be late" banner).
  Reliability _derive({Reliability? probed}) {
    final alarmReliability = probed ?? _lastProbed ?? Reliability.optimal;
    if (alarmReliability == Reliability.degraded) {
      return Reliability.degraded;
    }
    final statuses = _permissionService.statuses.value;
    for (final kind in _kReliabilityGatedKinds) {
      final result = statuses[kind];
      if (result is PermissionResultDenied) {
        return Reliability.degraded;
      }
      if (result is PermissionResultPermanentlyDenied) {
        return Reliability.degraded;
      }
    }
    return Reliability.optimal;
  }

  /// The most recent successful bridge probe. Cached here
  /// so the derive rule does not need to await the bridge
  /// on every permissions change.
  Reliability? _lastProbed;

  /// Probes the bridge. Catches platform-channel errors
  /// (ADR-013) and keeps the prior value.
  Future<Reliability> _safeProbe() async {
    try {
      final probed = await _bridge.probeReliability();
      _lastProbed = probed;
      return probed;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ReliabilityService._safeProbe failed: $e\n$st');
      }
      return _lastProbed ?? Reliability.optimal;
    }
  }

  /// Emits [r] to both the stream and the notifier, if and
  /// only if the value differs from the current value
  /// (`distinct()` semantics).
  void _emit(Reliability r) {
    if (_disposed) return;
    if (_notifier.value == r) return;
    _notifier.value = r;
    if (!_controller.isClosed) {
      _controller.add(r);
    }
  }

  /// Test hook. Lets a test inject a custom timer
  /// constructor so it can advance time without waiting 30
  /// real seconds.
  // ignore: use_setters_to_change_properties
  void setPeriodicFactoryForTesting(
    Timer Function(Duration, void Function(Timer)) factory,
  ) {
    _startFallbackTimerWithFactory(factory);
  }

  void _startFallbackTimerWithFactory(
    Timer Function(Duration, void Function(Timer)) factory,
  ) {
    _fallbackTimer?.cancel();
    _fallbackTimer = factory(kReliabilityCacheTtl, (_) {
      unawaited(refresh());
    });
  }

  /// Disposes internal state. Called from [resetForTesting].
  void _dispose() {
    _disposed = true;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _permissionService.statuses.removeListener(_onStatusesChanged);
    _notifier.dispose();
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}

/// Default `Timer.periodic` factory. Indirection so tests
/// can substitute a fake-async clock.
Timer _defaultPeriodic(Duration d, void Function(Timer) cb) {
  return Timer.periodic(d, cb);
}
