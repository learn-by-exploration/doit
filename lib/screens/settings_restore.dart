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
      final count = await BackupService.instance.importFrom(File(path));
      if (!mounted) return;
      setState(() {
        _status = _Status.restored;
        _restoredRowCount = count;
      });
    } on BackupFormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.picked;
        _error = e.message;
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
                        if (_error != null) ...[
                          const SizedBox(height: Spacing.sm),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
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
    );
  }
}

enum _Status { idle, picking, picked, restoring, restored }
