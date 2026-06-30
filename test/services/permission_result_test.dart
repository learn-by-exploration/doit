// Direct unit tests for the sealed `PermissionResult` and
// `BackupFolderResult` hierarchies (`lib/services/permission_result.dart`).
//
// v1.4-stab-D / Phase 44 / SYS-131: lifts coverage from
// 18.9% → 100% by exercising every sealed subclass + the
// v0.5 onboarding's `requestBackupFolder` result variants.
//
// No platform channels; pure Dart.

import 'package:doit/services/permission_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionResult sealed hierarchy (SYS-131)', () {
    test('PermissionResultGranted is the singleton grant token', () {
      const a = PermissionResultGranted();
      const b = PermissionResultGranted();
      expect(a, b, reason: 'no payload; identity-equality is fine');
      expect(
        a.toString(),
        contains('PermissionResultGranted'),
        reason: 'default Object.toString falls through to the type name',
      );
    });

    test('PermissionResultDenied equality depends on canOpenSettings', () {
      const a = PermissionResultDenied(canOpenSettings: true);
      const b = PermissionResultDenied(canOpenSettings: true);
      const c = PermissionResultDenied(canOpenSettings: false);
      expect(a, b);
      expect(a, isNot(c));
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('canOpenSettings: true'));
    });

    test('PermissionResultPermanentlyDenied is the singleton permanent-deny '
        'token (no payload, identity-equality)', () {
      const a = PermissionResultPermanentlyDenied();
      const b = PermissionResultPermanentlyDenied();
      expect(a, b);
      expect(a.toString(), contains('permanentlyDenied'));
    });

    test('All three sealed subclasses are exhaustively matched by '
        'pattern-matching', () {
      // Cycle D's regression protector: if a new sealed
      // subclass is added without updating this test, the
      // exhaustive switch fails to compile.
      String describe(PermissionResult r) => switch (r) {
        PermissionResultGranted() => 'granted',
        PermissionResultDenied(:final canOpenSettings) =>
          'denied(settings=$canOpenSettings)',
        PermissionResultPermanentlyDenied() => 'permanent',
      };

      expect(describe(const PermissionResultGranted()), 'granted');
      expect(
        describe(const PermissionResultDenied(canOpenSettings: true)),
        'denied(settings=true)',
      );
      expect(
        describe(const PermissionResultDenied(canOpenSettings: false)),
        'denied(settings=false)',
      );
      expect(describe(const PermissionResultPermanentlyDenied()), 'permanent');
    });
  });

  group('BackupFolderResult sealed hierarchy (SYS-131)', () {
    test('BackupFolderPicked equality depends on the picked path', () {
      const a = BackupFolderPicked('/tree/primary:Documents');
      const b = BackupFolderPicked('/tree/primary:Documents');
      const c = BackupFolderPicked('/tree/primary:Downloads');
      expect(a, b);
      expect(a, isNot(c));
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('/tree/primary:Documents'));
    });

    test('BackupFolderCancelled is the singleton cancel token', () {
      const a = BackupFolderCancelled();
      const b = BackupFolderCancelled();
      expect(a, b);
      expect(a.toString(), contains('BackupFolderCancelled'));
    });

    test('BackupFolderError equality depends on the error message', () {
      const a = BackupFolderError(
        'SecurityException: caller has no '
        'access to uri',
      );
      const b = BackupFolderError(
        'SecurityException: caller has no '
        'access to uri',
      );
      const c = BackupFolderError('IllegalStateException');
      expect(a, b);
      expect(a, isNot(c));
      expect(a.toString(), contains('SecurityException'));
    });
  });
}
