// Restore-from-backup screen. The user picks a JSON file via
// the platform file picker (Android SAF), confirms a destructive
// restore, and the [BackupService] replaces the local DB with
// the file's contents.
//
// Per the security model: this app never makes a network call.
// Restore is strictly local — the user picks a file that lives
// in their device storage (or a file the user previously
// exported from this app and shared to the system).

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:doit/services/backup_service.dart';
import 'package:doit/theme/app_theme.dart';

class SettingsRestoreScreen extends StatefulWidget {
  const SettingsRestoreScreen({super.key});

  @override
  State<SettingsRestoreScreen> createState() => _SettingsRestoreScreenState();
}

class _SettingsRestoreScreenState extends State<SettingsRestoreScreen> {
  _Status _status = _Status.idle;
  String? _pickedPath;
  String? _error;
  int? _restoredRowCount;

  // v1.8-pr-c / SYS-192 / ADR-123 / WF-119:
  // passphrase input. Held in a controller (not stored) — cleared
  // in `dispose`. The controller is reset on each successful pick
  // (a new backup may not share the passphrase with the old one).
  final TextEditingController _passphraseController = TextEditingController();
  bool _obscurePassphrase = true;

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _status = _Status.picking;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) {
        setState(() => _status = _Status.idle);
        return;
      }
      final path = result.files.first.path;
      if (path == null) {
        setState(() {
          _status = _Status.idle;
          _error = 'Could not read the picked file.';
        });
        return;
      }
      setState(() {
        _pickedPath = path;
        _status = _Status.picked;
        // v1.8-pr-c / SYS-192 / ADR-123 / WF-119:
        // reset the passphrase context — a different file may
        // have been exported with a different passphrase (or no
        // passphrase at all). Forgetting a typed passphrase on
        // re-pick prevents cross-file confusion.
        _passphraseController.clear();
        _obscurePassphrase = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.idle;
        _error = 'Picker failed: $e';
      });
    }
  }

  Future<void> _restore() async {
    final path = _pickedPath;
    if (path == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace all local data?'),
        content: const Text(
          'Restoring from a backup will overwrite every do, '
          'completion, person, and setting currently on this '
          'device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('settings_restore.confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() {
      _status = _Status.restoring;
      _error = null;
    });
    try {
      // v1.8-pr-c / SYS-192 / ADR-123 / WF-119: forward the
      // passphrase the user typed (may be empty for v1 plain-JSON
      // backups; service treats null/empty as "no passphrase").
      final typed = _passphraseController.text;
      final passphrase = typed.isEmpty ? null : typed;
      final count = await BackupService.instance.importFrom(
        File(path),
        passphrase: passphrase,
      );
      if (!mounted) return;
      setState(() {
        _status = _Status.restored;
        _restoredRowCount = count;
      });
    } on BackupFormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.picked;
        // v1.8-pr-c / SYS-192 / ADR-123 / WF-119: map the
        // service's "Decryption failed" / "Backup is encrypted"
        // messages to the localized error string. The service
        // throws a single BackupFormatException per failure
        // (ADR-123 records a future exception-code taxonomy).
        _error = e.message.contains('Decryption failed')
            ? AppLocalizations.of(context).settingsRestoreWrongPassphraseError
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.picked;
        _error = 'Restore failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restore from backup')),
      body: SafeArea(
        // v1.8-pr-c / SYS-192 / ADR-123 / WF-119:
        // wrapped the Column in a SingleChildScrollView. The
        // passphrase card pushes the screen beyond the default
        // 800px test viewport (the `_Status.restored` + error
        // + progress paths add even more widgets). Pinning
        // `physics: const ClampingScrollPhysics()` matches the
        // Android platform scroll feel.
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(Spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pick a do it backup (.json). The file must have '
                          'been produced by this app — restoring overwrites '
                          'every do and completion currently on the '
                          'device.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                FilledButton.icon(
                  key: const ValueKey('settings_restore.pick'),
                  onPressed:
                      _status == _Status.picking || _status == _Status.restoring
                      ? null
                      : _pick,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Pick a backup file'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: Spacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: Spacing.sm),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_pickedPath != null) ...[
                  const SizedBox(height: Spacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected:',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(_pickedPath!),
                        ],
                      ),
                    ),
                  ),
                  // v1.8-pr-c / SYS-192 / ADR-123 / WF-119:
                  // passphrase TextField. Only meaningful for v2 / v3
                  // encrypted backups — a plain-JSON v1 backup ignores
                  // the field (the service treats null/empty as "no
                  // passphrase"). Shown after a backup is picked.
                  const SizedBox(height: Spacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(
                              context,
                            ).settingsRestorePassphraseLabel,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: Spacing.sm),
                          TextField(
                            key: const ValueKey('settings_restore.passphrase'),
                            controller: _passphraseController,
                            obscureText: _obscurePassphrase,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(
                                context,
                              ).settingsRestorePassphraseHint,
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                key: const ValueKey(
                                  'settings_restore.passphrase.toggle',
                                ),
                                tooltip: _obscurePassphrase
                                    ? AppLocalizations.of(
                                        context,
                                      ).settingsRestorePassphraseShowCta
                                    : AppLocalizations.of(
                                        context,
                                      ).settingsRestorePassphraseHideCta,
                                icon: Icon(
                                  _obscurePassphrase
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(() {
                                  _obscurePassphrase = !_obscurePassphrase;
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            AppLocalizations.of(
                              context,
                            ).settingsRestoreEncryptedBackupHint,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  FilledButton.icon(
                    key: const ValueKey('settings_restore.run'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _status == _Status.restoring ? null : _restore,
                    icon: const Icon(Icons.warning_amber),
                    label: const Text('Replace local data with this backup'),
                  ),
                ],
                if (_status == _Status.restoring)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: Spacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_status == _Status.restored) ...[
                  const SizedBox(height: Spacing.md),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.md),
                      child: Text(
                        'Restored $_restoredRowCount rows.',
                        key: const ValueKey('settings_restore.success'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Status { idle, picking, picked, restoring, restored }
