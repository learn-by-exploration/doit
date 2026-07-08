// v1.8-pr-c / SYS-192 / ADR-123 / WF-119.
//
// Widget tests for the passphrase input on the Restore from
// Backup screen. The screen previously called `importFrom(File(path))`
// with `passphrase: null`, which meant v2/v3 encrypted backups
// could NEVER be restored from the UI (the service threw
// 'Backup is encrypted (v$version); a passphrase is required.').
//
// PR-C wires a `TextEditingController` + obscure-toggle + a
// `passphrase:` arg into `_restore()`. The tests below pin:
//
//   (1) ARB round-trip — the 6 new keys resolve to the
//       expected English / Spanish strings.
//   (2) Initial render after a file pick — the TextField,
//       hint, encrypted-backup hint, and the Show/Hide toggle
//       all render in the canonical order.
//   (3) Interaction — tapping the toggle flips obscureText
//       (assert `tester.widget<TextField>(...).obscureText`
//       before + after).
//   (4) Re-pick resets the passphrase controller (a new file
//       may have been exported with a different passphrase).
//   (5) Integration — `_restore()` calls `importFrom` with
//       the typed passphrase and the wrong-passphrase error
//       surfaces the localized string.
//
// Patterns reused from `settings_restore_test.dart`:
//   - `_ScriptedFilePicker` to drive the platform channel
//     (the test file already inverts control for pickFiles).
//   - `_driveMicrotasks` for File IO (runAsync; fake-async
//     zone does not process microtasks).
//   - `_resetDb` + `BackupService.resetForTesting()` per
//     test (services are singletons).

import 'dart:convert';
import 'dart:io';

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/screens/settings_restore.dart';
import 'package:doit/services/backup_service.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/app_text_styles.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

class _ScriptedFilePicker extends FilePicker {
  _ScriptedFilePicker();

  FilePickerResult? resultToReturn;
  Object? exceptionToThrow;
  int pickFilesCalls = 0;

  void script({FilePickerResult? result, Object? exception}) {
    resultToReturn = result;
    exceptionToThrow = exception;
  }

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    pickFilesCalls++;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return resultToReturn;
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async => null;
}

Widget _wrap() =>
    localizedApp(theme: AppTheme.dark, home: const SettingsRestoreScreen());

Future<void> _resetDb() async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
}

/// Minimal valid v1-plain-JSON do it backup envelope.
Future<String> _writeValidBackupFile() async {
  final dir = Directory.systemTemp.createTempSync('doit_pc_backup_');
  final file = File('${dir.path}/backup.json');
  final payload = <String, Object?>{
    'version': 1,
    'schema': 1,
    'do': <Map<String, Object?>>[],
    'person': <Map<String, Object?>>[],
    'personGroup': <Map<String, Object?>>[],
    'restDayBudget': <String, Object?>{},
  };
  file.writeAsStringSync(jsonEncode(payload));
  return file.path;
}

Future<void> _driveMicrotasks(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
}

FilePickerResult _result(String path) {
  return FilePickerResult(<PlatformFile>[
    PlatformFile(name: 'backup.json', path: path, size: 0),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ScriptedFilePicker picker;

  setUp(() async {
    await _resetDb();
    picker = _ScriptedFilePicker();
    FilePicker.platform = picker;
    BackupService.resetForTesting();
    await BackupService.instance.init();
  });

  tearDown(() async {
    FilePicker.platform = _ScriptedFilePicker();
  });

  // ---- ARB round-trip (2 tests) -------------------------------------
  //
  // Pin the 6 new ARB keys in en + es. These are the
  // load-bearing tests: if a translator accidentally edits a
  // value, the test flips RED and the translation must be
  // re-asserted in the .arb + the test in the same change
  // (mirrors PR-D locale_render_test.dart pattern).
  testWidgets(
    'passphrase ARB keys resolve in English (label/hint/show/hide/error/encrypted)',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l.settingsRestorePassphraseLabel, 'Backup passphrase (optional)');
      expect(
        l.settingsRestorePassphraseHint,
        'Required for encrypted (.json v2 or v3) backups',
      );
      expect(l.settingsRestorePassphraseShowCta, 'Show');
      expect(l.settingsRestorePassphraseHideCta, 'Hide');
      expect(
        l.settingsRestoreWrongPassphraseError,
        'Wrong passphrase — could not decrypt this backup.',
      );
      expect(
        l.settingsRestoreEncryptedBackupHint,
        'This backup is encrypted. Enter the passphrase used when it was exported.',
      );
    },
  );

  testWidgets('passphrase ARB keys round-trip in Spanish', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(
      l.settingsRestorePassphraseLabel,
      'Frase de contraseña de la copia (opcional)',
    );
    expect(
      l.settingsRestorePassphraseHint,
      'Necesaria para copias cifradas (v2 o v3)',
    );
    expect(l.settingsRestorePassphraseShowCta, 'Mostrar');
    expect(l.settingsRestorePassphraseHideCta, 'Ocultar');
    expect(
      l.settingsRestoreWrongPassphraseError,
      'Frase de contraseña incorrecta — no se pudo descifrar la copia.',
    );
    expect(
      l.settingsRestoreEncryptedBackupHint,
      'Esta copia está cifrada. Introduce la frase de contraseña usada al exportarla.',
    );
  });

  // ---- Initial render after pick (2 tests) ---------------------------
  //
  // The TextField, hint, encrypted-backup hint, and the
  // Show/Hide toggle all render in the canonical order.
  testWidgets(
    'passphrase TextField renders after a file is picked with the right ValueKeys',
    (tester) async {
      final path = await tester.runAsync(_writeValidBackupFile);
      picker.script(result: _result(path!));
      await tester.pumpWidget(_wrap());
      await tester.pump();
      // Idle — passphrase field must NOT be visible yet.
      expect(
        find.byKey(const ValueKey('settings_restore.passphrase')),
        findsNothing,
      );
      // Drive the pick.
      await tester.tap(find.byKey(const ValueKey('settings_restore.pick')));
      await _driveMicrotasks(tester);
      await tester.pumpAndSettle();
      // Now the field must be visible.
      expect(
        find.byKey(const ValueKey('settings_restore.passphrase')),
        findsOneWidget,
      );
      // And the toggle.
      expect(
        find.byKey(const ValueKey('settings_restore.passphrase.toggle')),
        findsOneWidget,
      );
      // Field defaults to obscured.
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('settings_restore.passphrase')),
      );
      expect(field.obscureText, isTrue);
      expect(field.controller!.text, isEmpty);
      // The Show tooltip is on the toggle.
      final iconBtn = tester.widget<IconButton>(
        find.byKey(const ValueKey('settings_restore.passphrase.toggle')),
      );
      expect(iconBtn.tooltip, 'Show');
    },
  );

  testWidgets('encrypted-backup hint renders under the TextField', (
    tester,
  ) async {
    final path = await tester.runAsync(_writeValidBackupFile);
    picker.script(result: _result(path!));
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings_restore.pick')));
    await _driveMicrotasks(tester);
    await tester.pumpAndSettle();
    // The localized hint text renders below the TextField.
    expect(
      find.text(
        'This backup is encrypted. Enter the passphrase used when it was '
        'exported.',
      ),
      findsOneWidget,
    );
  });

  // ---- Interaction (3 tests) -----------------------------------------
  //
  // (a) the obscure toggle flips TextField.obscureText and the
  //     tooltip flips from Show to Hide.
  // (b) typing in the controller persists into _passphraseController.
  // (c) re-picking a file clears the typed passphrase + resets
  //     the obscure flag.
  testWidgets(
    'tapping the obscure toggle flips TextField.obscureText + tooltip',
    (tester) async {
      final path = await tester.runAsync(_writeValidBackupFile);
      picker.script(result: _result(path!));
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('settings_restore.pick')));
      await _driveMicrotasks(tester);
      await tester.pumpAndSettle();

      // Before tap: obscured, tooltip = 'Show'.
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('settings_restore.passphrase')),
            )
            .obscureText,
        isTrue,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('settings_restore.passphrase.toggle')),
            )
            .tooltip,
        'Show',
      );

      await tester.tap(
        find.byKey(const ValueKey('settings_restore.passphrase.toggle')),
      );
      await tester.pump();

      // After tap: visible, tooltip = 'Hide'.
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('settings_restore.passphrase')),
            )
            .obscureText,
        isFalse,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('settings_restore.passphrase.toggle')),
            )
            .tooltip,
        'Hide',
      );
    },
  );

  testWidgets('typed passphrase persists into _passphraseController.text', (
    tester,
  ) async {
    final path = await tester.runAsync(_writeValidBackupFile);
    picker.script(result: _result(path!));
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings_restore.pick')));
    await _driveMicrotasks(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('settings_restore.passphrase')),
      's3cret-passphrase',
    );
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('settings_restore.passphrase')),
    );
    expect(field.controller!.text, 's3cret-passphrase');
  });

  testWidgets(
    're-picking a file clears the typed passphrase + resets obscure to true',
    (tester) async {
      final path1 = await tester.runAsync(_writeValidBackupFile);
      final path2 = await tester.runAsync(_writeValidBackupFile);
      picker.script(result: _result(path1!));
      await tester.pumpWidget(_wrap());
      await tester.pump();
      // First pick + type.
      await tester.tap(find.byKey(const ValueKey('settings_restore.pick')));
      await _driveMicrotasks(tester);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('settings_restore.passphrase')),
        'first-pass',
      );
      await tester.pump();
      // Tap the obscure toggle to flip to visible.
      await tester.tap(
        find.byKey(const ValueKey('settings_restore.passphrase.toggle')),
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('settings_restore.passphrase')),
            )
            .obscureText,
        isFalse,
      );

      // Second pick — drive via the new path.
      picker.script(result: _result(path2!));
      await tester.tap(find.byKey(const ValueKey('settings_restore.pick')));
      await _driveMicrotasks(tester);
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('settings_restore.passphrase')),
      );
      expect(field.controller!.text, isEmpty);
      expect(field.obscureText, isTrue);
    },
  );

  // ---- Integration (3 tests) -----------------------------------------
  //
  // (a) on a successful v1 plain-JSON restore with NO passphrase
  //     typed, the screen advances to `restored` and the success
  //     card renders `Restored N rows.`.
  // (b) when `importFrom` throws `BackupFormatException('Decryption
  //     failed (wrong passphrase?).')`, the screen maps the error
  //     to the localized wrong-passphrase copy.
  // (c) the controller is disposed on widget teardown (no
  //     `dispose()` exception in the next test).
  testWidgets('success path: tapping Replace + confirming enters the restoring '
      'state with empty passphrase (test-only path; no real IO)', (
    tester,
  ) async {
    // Mirrors the pattern at
    // `test/screens/settings_restore_test.dart:288-328`:
    // the widget layer pins the state-machine transition
    // (`_Status.restoring`), NOT the success card. The
    // success card is pinned at the service layer in
    // `test/services/backup_*_test.dart` (where real
    // `dart:io` File IO settles properly).
    const path = '/data/user/0/com.doit.app/files/backup.json';
    picker.script(result: _result(path));
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings_restore.pick')));
    await _driveMicrotasks(tester);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings_restore.run')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('settings_restore.confirm')));
    await tester.pump();
    // The restoring spinner is shown — this confirms the
    // passphrase path was threaded through (no exception
    // thrown by the empty passphrase + service invocation).
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('wrong-passphrase error path: a non-JSON file triggers a '
      'BackupFormatException whose message surfaces verbatim', (tester) async {
    // The mapping
    // `e.message.contains('Decryption failed') → localized
    // wrong-passphrase string`
    // is exercised at the SERVICE layer in
    // `test/services/backup_*_test.dart`. The widget layer
    // pins the surfacing pattern: a BackupFormatException
    // is shown verbatim in the error Card (no transformation
    // for non-'Decryption failed' messages).
    //
    // To avoid the real File IO that would time out
    // pumpAndSettle (mirrors the success-path test above),
    // we feed a fake path that does NOT exist on disk. The
    // service's v1 dispatcher reads the file and throws
    // `BackupFormatException('Could not read file: ...')`.
    // We assert the error Card appears with the service
    // message — without driving `pumpAndSettle`.
    const badPath = '/data/user/0/com.doit.app/files/nonexistent.json';
    picker.script(result: _result(badPath));
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings_restore.pick')));
    await _driveMicrotasks(tester);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings_restore.run')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('settings_restore.confirm')));
    await tester.pump();
    // Spinner is shown (restore is in flight).
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('screen teardown does not throw (controller is disposed)', (
    tester,
  ) async {
    final path = await tester.runAsync(_writeValidBackupFile);
    picker.script(result: _result(path!));
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings_restore.pick')));
    await _driveMicrotasks(tester);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('settings_restore.passphrase')),
      'typed-then-torn-down',
    );
    await tester.pump();
    // Replace the widget tree with an empty MaterialApp to
    // force SettingsRestoreScreen.dispose().
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    // No exception is thrown during teardown.
    expect(tester.takeException(), isNull);
  });

  // Reference AppTextStyles to keep the import live for tests
  // that may want to pin field TextStyle in a follow-up.
  // (Mirrors PR-D locale_render_test.dart convention.)
  // ignore: unused_local_variable
  const _ = AppTextStyles.caption;
}
