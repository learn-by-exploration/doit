// v0.5c / SYS-066: `SettingsService.backupFolderUri`.
//
// The v0.5 onboarding's step 3 (SYS-066) hands the user the
// Android SAF folder picker. On a non-null `treeUri` the
// widget layer persists the URI to
// `SettingsService.backupFolderUri` (a `ValueNotifier<String?>`)
// so the BackupService can read it at backup dispatch.
//
// The notifier is in-memory only for v0.5c; persistence to
// `SharedPreferences` lands with the v0.5d Settings tile that
// reads the URI at backup time. The 3 tests pin:
//   1. The default value is `null` (no folder picked yet).
//   2. `setBackupFolderUri(uri)` updates the notifier to
//      the supplied URI (the picked path).
//   3. A listener on the notifier fires on a change.

import 'package:doit/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(SettingsService.instance.resetForTesting);

  test('backupFolderUri defaults to null (SYS-066)', () {
    expect(
      SettingsService.instance.backupFolderUri.value,
      isNull,
      reason:
          'A fresh SettingsService must report no backup folder picked yet. '
          'The widget layer (v0.5c) reads this notifier to decide whether '
          'to show the onboarding step 3 CTA or the "Pick folder" affordance '
          'on Settings.',
    );
  });

  test('setBackupFolderUri updates the notifier (SYS-066)', () {
    const picked = '/tree/primary:Documents';
    SettingsService.instance.setBackupFolderUri(picked);
    expect(
      SettingsService.instance.backupFolderUri.value,
      picked,
      reason:
          'setBackupFolderUri must update the in-memory notifier synchronously '
          'so the BackupService (and the v0.5d Settings tile) see the new '
          'URI on the next read.',
    );
  });

  test('backupFolderUri listener fires on change (SYS-066)', () {
    final events = <String?>[];
    void listener() {
      events.add(SettingsService.instance.backupFolderUri.value);
    }

    SettingsService.instance.backupFolderUri.addListener(listener);
    addTearDown(() {
      SettingsService.instance.backupFolderUri.removeListener(listener);
    });

    SettingsService.instance.setBackupFolderUri('/tree/primary:Documents');
    SettingsService.instance.setBackupFolderUri(
      '/tree/primary:Documents%2FBackup',
    );
    // A write of the same value is a no-op for
    // `ValueNotifier` (no event fires); the listener
    // should have seen exactly the two distinct writes.
    expect(
      events,
      ['/tree/primary:Documents', '/tree/primary:Documents%2FBackup'],
      reason:
          'A listener on backupFolderUri must see every distinct value '
          'the notifier transitions to. The Settings → Restore screen '
          '(v0.5d) and the BackupService (future commit) both rely on '
          'this notification to react to revocation / re-pick events.',
    );
  });
}
