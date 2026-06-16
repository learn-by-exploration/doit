// Permission service — the single seam between the widget
// layer and `permission_handler` ^11.3.1 + `file_picker`
// ^8.1.2.
//
// Per .claude/rules/lib-screens.md: "No platform calls in
// widgets." The v0.1 onboarding screen was shipped as a
// visual walkthrough; v0.5 (ADR-016) wires the four runtime
// permission requests to this service. The service is also
// the seam the Settings → Permissions tile (v0.5d) reads
// from to render "Granted" / "Not granted" status text and
// the deep-link to the Android system settings.
//
// Layer rules (per .claude/rules/lib-services.md):
// - Singleton with `Completer<void> _ready`.
// - `init()` is idempotent.
// - All public methods are async.
//
// The service depends on `package:permission_handler` (for
// `Permission.notification`, `Permission.contacts`,
// `Permission.scheduleExactAlarm`) and
// `package:file_picker` (for `FilePicker.platform.getDirectoryPath`
// which uses `ACTION_OPEN_DOCUMENT_TREE` on Android). It
// returns a sealed [PermissionResult] / [BackupFolderResult]
// so the widget layer never sees `PermissionStatus` directly.

import 'dart:async' show Completer;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:meta/meta.dart';
import 'package:permission_handler/permission_handler.dart';
// `permission_handler` re-exports `Permission`,
// `PermissionStatus`, etc. but NOT the
// `PermissionHandlerPlatform` interface. The platform
// interface is the only public way to reach the underlying
// `openAppSettings` MethodChannel from a non-widget caller
// (the top-level `openAppSettings()` from `permission_handler`
// is shadowed by this service's own `openAppSettings`
// method, so we cannot call it from inside the class body
// without a rename hack).
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

import 'package:doit/services/permission_result.dart';

/// Identifiers for the four runtime permissions / pickers
/// the service manages. Used as keys in [PermissionService.statuses]
/// and as the dispatch key in tests. Mirrors the
/// onboarding-screen step order in
/// [lib/screens/onboarding.dart]: notifications, contacts,
/// exact alarms, backup folder.
enum PermissionKind {
  /// `POST_NOTIFICATIONS`. SYS-063.
  notifications,

  /// `READ_CONTACTS`. SYS-064.
  contacts,

  /// `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`. SYS-065.
  exactAlarm,

  /// The SAF folder picker. SYS-066. The runtime status
  /// is `null` (the picker is not a permission; the picked
  /// path lives in `SettingsService.backupFolderUri`).
  backupFolder,
}

/// Singleton holder for the permission / SAF seam. The
/// public methods ([requestNotifications], [requestContacts],
/// [requestExactAlarm], [requestBackupFolder],
/// [openAppSettings]) all `await ready` before touching the
/// underlying plugins.
class PermissionService {
  PermissionService._();

  /// The single global instance.
  static final PermissionService instance = PermissionService._();

  /// Init gate (`Completer<void> _ready`). Public reads wait
  /// on this before touching the underlying plugins. The
  /// pattern matches `lib-services.md` § Singleton lifecycle.
  Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  /// Current status of the three runtime permissions
  /// (notifications, contacts, exact alarms). Populated by
  /// [init] and refreshed by every `requestX` call. The
  /// `backupFolder` entry is always `null` — the SAF picker
  /// is not a permission; the picked path lives in
  /// `SettingsService.backupFolderUri`.
  ///
  /// The Settings → Permissions tile (v0.5d) binds to this
  /// via `ValueListenableBuilder` so changes propagate
  /// without a full Provider rebuild.
  final ValueNotifier<Map<PermissionKind, PermissionResult?>> statuses =
      ValueNotifier<Map<PermissionKind, PermissionResult?>>({
        PermissionKind.notifications: const PermissionResultDenied(
          canOpenSettings: true,
        ),
        PermissionKind.contacts: const PermissionResultDenied(
          canOpenSettings: true,
        ),
        PermissionKind.exactAlarm: const PermissionResultDenied(
          canOpenSettings: true,
        ),
        PermissionKind.backupFolder: null,
      });

  /// Idempotent. Probes the three runtime permissions and
  /// stores the mapped [PermissionResult] in [statuses].
  /// A platform-channel error (missing plugin, restricted
  /// device, etc.) is swallowed — the v0.4b-release-fix
  /// lesson is that `main()` must not crash if a plugin is
  /// absent. The service is left in a state where the
  /// default `denied(canOpenSettings: true)` is reported.
  Future<void> init() async {
    if (_ready.isCompleted) return;
    final next = <PermissionKind, PermissionResult?>{
      PermissionKind.notifications: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.contacts: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.exactAlarm: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.backupFolder: null,
    };
    try {
      next[PermissionKind.notifications] = _mapStatus(
        await Permission.notification.status,
      );
      next[PermissionKind.contacts] = _mapStatus(
        await Permission.contacts.status,
      );
      next[PermissionKind.exactAlarm] = _mapStatus(
        await Permission.scheduleExactAlarm.status,
      );
    } catch (_) {
      // v0.4b-release-fix / ADR-013 follow-up: a thrown
      // platform-channel error must not crash `main()`. The
      // service still completes `_ready` so the rest of the
      // app proceeds; the statuses remain the default
      // `denied(canOpenSettings: true)` so the Settings →
      // Permissions tile can render a "try again" affordance.
    }
    statuses.value = next;
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Request `POST_NOTIFICATIONS` (Android 13+). On
  /// Android < 13 the runtime grant is automatic and this
  /// returns [PermissionResultGranted] without a system
  /// dialog.
  Future<PermissionResult> requestNotifications() async {
    await ready;
    final raw = await Permission.notification.request();
    return _recordAndReturn(PermissionKind.notifications, raw);
  }

  /// Request `READ_CONTACTS`. Returns
  /// [PermissionResultPermanentlyDenied] on the second
  /// denial (Android 11+ semantics) and
  /// [PermissionResultDenied] on the first.
  Future<PermissionResult> requestContacts() async {
    await ready;
    final raw = await Permission.contacts.request();
    return _recordAndReturn(PermissionKind.contacts, raw);
  }

  /// Request `SCHEDULE_EXACT_ALARM` /
  /// `USE_EXACT_ALARM`. On Android 12+ this is a policy
  /// permission — the system "Allow" dialog does not
  /// appear; the user grants the policy in
  /// Settings → Apps → Special access → Alarms &
  /// reminders. The runtime call returns
  /// [PermissionStatus.denied] until the user has granted
  /// the policy, in which case it returns
  /// [PermissionStatus.granted]. The widget layer surfaces
  /// the deep-link as the primary affordance on `denied`.
  Future<PermissionResult> requestExactAlarm() async {
    await ready;
    final raw = await Permission.scheduleExactAlarm.request();
    return _recordAndReturn(PermissionKind.exactAlarm, raw);
  }

  /// Open the Android SAF folder picker
  /// (`ACTION_OPEN_DOCUMENT_TREE`). Returns
  /// [BackupFolderPicked] with the SAF tree URI on
  /// success, [BackupFolderCancelled] on user cancel, and
  /// [BackupFolderError] on a thrown exception. The widget
  /// layer is responsible for persisting [BackupFolderPicked.path]
  /// to `SettingsService.backupFolderUri`.
  Future<BackupFolderResult> requestBackupFolder() async {
    await ready;
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null) {
        return const BackupFolderCancelled();
      }
      return BackupFolderPicked(path);
    } catch (e) {
      return BackupFolderError(e.toString());
    }
  }

  /// Open the app's settings page (deep-link to Android
  /// system settings). Returns `true` if the page could be
  /// opened, `false` otherwise. The widget layer uses this
  /// as the recovery affordance for
  /// [PermissionResultPermanentlyDenied] and for
  /// [PermissionResultDenied] where `canOpenSettings` is
  /// `true`.
  Future<bool> openAppSettings() async {
    await ready;
    // The top-level `openAppSettings` from
    // `package:permission_handler` is a thin wrapper over
    // this same call; we go to the platform interface
    // directly to avoid an import-name shadow with this
    // method.
    return PermissionHandlerPlatform.instance.openAppSettings();
  }

  // --- internal ----------------------------------------------------

  /// Maps a [PermissionStatus] to the sealed
  /// [PermissionResult] the widget layer sees. See
  /// `lib/services/permission_result.dart` for the fold
  /// rules.
  @visibleForTesting
  static PermissionResult mapStatus(PermissionStatus s) => _mapStatus(s);

  static PermissionResult _mapStatus(PermissionStatus s) {
    switch (s) {
      case PermissionStatus.granted:
        return const PermissionResultGranted();
      case PermissionStatus.denied:
        // One-shot denial — the user can be re-asked.
        return const PermissionResultDenied(canOpenSettings: true);
      case PermissionStatus.permanentlyDenied:
        return const PermissionResultPermanentlyDenied();
      case PermissionStatus.restricted:
        // iOS only (parental controls, etc.). The user
        // cannot recover from inside the app. The deep-link
        // would not help, so the widget hides it.
        return const PermissionResultDenied(canOpenSettings: false);
      case PermissionStatus.limited:
        // Partial access; the user can be re-asked for full.
        return const PermissionResultDenied(canOpenSettings: true);
      case PermissionStatus.provisional:
        // iOS only; treat as granted for our use case
        // (do it does not need full notification access).
        return const PermissionResultGranted();
    }
  }

  /// Records the mapped result into [statuses] and returns
  /// it. The record is what the v0.5d Settings → Permissions
  /// tile reads; the return value is what the v0.5c
  /// onboarding CTA dispatches on.
  PermissionResult _recordAndReturn(PermissionKind kind, PermissionStatus raw) {
    final mapped = _mapStatus(raw);
    final next = Map<PermissionKind, PermissionResult?>.from(statuses.value);
    next[kind] = mapped;
    statuses.value = next;
    return mapped;
  }

  /// Test helper. Resets the singleton's in-memory state
  /// (the `_ready` gate, the [statuses] map) so the next
  /// [init] re-probes. The platform plugin is not touched
  /// — tests that want to script platform responses use
  /// `TestDefaultBinaryMessengerBinding.setMockMethodCallHandler`
  /// on the `flutter.baseflow.com/permissions/methods`
  /// channel.
  // ignore: use_setters_to_change_properties
  void resetForTesting() {
    _ready = Completer<void>();
    statuses.value = {
      PermissionKind.notifications: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.contacts: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.exactAlarm: const PermissionResultDenied(
        canOpenSettings: true,
      ),
      PermissionKind.backupFolder: null,
    };
  }
}

// (No top-level helper needed; the platform-interface call
// inside `openAppSettings()` above is the single source of
// truth for the deep-link.)
