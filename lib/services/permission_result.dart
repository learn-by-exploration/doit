// Sealed result for [PermissionService.requestX] methods.
//
// v0.5 / ADR-016. The widget layer never sees
// `PermissionStatus` from `permission_handler` directly; the
// service maps the platform's six-state enum onto this
// three-case sealed type. The fold rules are:
//
//   - `PermissionStatus.granted`           → `PermissionResultGranted`
//   - `PermissionStatus.denied`            →
//       `PermissionResultDenied(canOpenSettings: true)` — the
//       user can be re-asked, so the widget keeps the
//       primary CTA enabled.
//   - `PermissionStatus.permanentlyDenied` →
//       `PermissionResultPermanentlyDenied` — the user has
//       said "Don't ask again" (or, for `SCHEDULE_EXACT_ALARM`
//       on Android 12+, the OS policy requires the user to
//       grant via system Settings). The widget renders a
//       "Go to Android Settings" deep-link as the only
//       recovery affordance.
//   - `PermissionStatus.restricted`        →
//       `PermissionResultDenied(canOpenSettings: false)` —
//       iOS only (parental controls). The widget cannot
//       recover; the user has to lift the restriction out of
//       band. `canOpenSettings: false` hides the deep-link.
//   - `PermissionStatus.limited`           →
//       `PermissionResultDenied(canOpenSettings: true)` —
//       partial access; the user can be re-asked for full.
//   - `PermissionStatus.provisional`       →
//       `PermissionResultGranted` — iOS only; do it's
//       notification usage is compatible with provisional
//       authorization.
//
// The `denied(canOpenSettings: ...)` flag is the
// `PermissionResult.denied` payload. The widget layer
// destructures it via pattern matching to decide whether to
// render the "Go to Settings" button.
//
// See docs/v_model/requirements.md § SYS-063..066 and
// docs/v_model/decision_record.md ADR-016.

import 'package:meta/meta.dart';

/// Sealed permission result. Three concrete subclasses.
@immutable
sealed class PermissionResult {
  const PermissionResult();
}

/// The user granted the permission. The feature is available.
final class PermissionResultGranted extends PermissionResult {
  const PermissionResultGranted();
}

/// The user denied the permission. The widget layer can
/// re-ask the user (the primary CTA stays enabled) only if
/// [canOpenSettings] is `true`. When `false`, the only
/// recovery is out-of-band (e.g., lifting a parental control).
final class PermissionResultDenied extends PermissionResult {
  const PermissionResultDenied({required this.canOpenSettings});

  /// `true` if the widget should render a "Go to Settings"
  /// deep-link to `PermissionService.openAppSettings()`.
  /// `false` for OS-level restrictions (iOS restricted, etc.)
  /// where settings would not help.
  final bool canOpenSettings;

  @override
  bool operator ==(Object other) =>
      other is PermissionResultDenied &&
      other.canOpenSettings == canOpenSettings;

  @override
  int get hashCode => canOpenSettings.hashCode;

  @override
  String toString() =>
      'PermissionResult.denied(canOpenSettings: $canOpenSettings)';
}

/// The user has permanently denied the permission, OR the
/// OS policy requires an out-of-app grant (e.g.,
/// `SCHEDULE_EXACT_ALARM` on Android 12+). The only
/// recovery is the Settings deep-link; the runtime request
/// will never re-prompt.
final class PermissionResultPermanentlyDenied extends PermissionResult {
  const PermissionResultPermanentlyDenied();

  @override
  bool operator ==(Object other) => other is PermissionResultPermanentlyDenied;

  @override
  int get hashCode => (PermissionResultPermanentlyDenied).hashCode;

  @override
  String toString() => 'PermissionResult.permanentlyDenied()';
}

/// Sealed result of [PermissionService.requestBackupFolder].
///
/// The v0.5 onboarding's step 3 (SYS-066) hands the user the
/// Android SAF folder picker. The picker has three terminal
/// outcomes:
///
///   - The user picked a folder. The path is returned as a
///     non-null `String` (the Android SAF tree URI on
///     Android; the filesystem path on desktop, which is
///     unused in v0.5). The widget layer persists the
///     path to [SettingsService.backupFolderUri].
///   - The user cancelled the dialog. The widget layer
///     advances the onboarding step anyway (per ADR-014
///     step 6: the backup folder is skippable).
///   - The picker threw. The widget layer shows an error
///     affordance; the user can retry.
@immutable
sealed class BackupFolderResult {
  const BackupFolderResult();
}

/// The user picked a folder. [path] is the Android SAF tree
/// URI on Android (and a filesystem path on desktop, which
/// v0.5 never reaches because the app is Android-only).
final class BackupFolderPicked extends BackupFolderResult {
  const BackupFolderPicked(this.path);
  final String path;

  @override
  bool operator ==(Object other) =>
      other is BackupFolderPicked && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'BackupFolderPicked($path)';
}

/// The user cancelled the SAF dialog.
final class BackupFolderCancelled extends BackupFolderResult {
  const BackupFolderCancelled();

  @override
  bool operator ==(Object other) => other is BackupFolderCancelled;

  @override
  int get hashCode => (BackupFolderCancelled).hashCode;

  @override
  String toString() => 'BackupFolderCancelled()';
}

/// The SAF picker threw. [message] is the exception's
/// `toString()`; the widget layer surfaces it.
final class BackupFolderError extends BackupFolderResult {
  const BackupFolderError(this.message);
  final String message;

  @override
  bool operator ==(Object other) =>
      other is BackupFolderError && other.message == message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'BackupFolderError($message)';
}
