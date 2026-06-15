// Drift guard: the constants in `lib/build_info.dart` must mirror the
// `version:` field in `pubspec.yaml`. Flutter does not expose the
// pubspec version to runtime Dart without `--dart-define`; the
// constants in `build_info.dart` are the in-app source of truth, and
// this test fails the 3-gate if the two drift apart.

import 'dart:io';

import 'package:doit/build_info.dart';
import 'package:flutter_test/flutter_test.dart';

({String version, int code}) _readPubspecVersion() {
  final pubspec = File(
    '${Directory.current.path.replaceFirst('/test', '')}/pubspec.yaml',
  );
  final text = pubspec.readAsStringSync();
  final match = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(text);
  if (match == null) {
    throw StateError('pubspec.yaml is missing a `version:` line');
  }
  final raw = match.group(1)!;
  // Pubspec version is `<semver>+<code>`, e.g., `0.3.0+3`.
  final parts = raw.split('+');
  if (parts.length != 2) {
    throw StateError(
      'pubspec.yaml version is not in `<semver>+<code>` form: "$raw"',
    );
  }
  return (version: parts[0], code: int.parse(parts[1]));
}

void main() {
  test('kAppVersion mirrors pubspec.yaml semver', () {
    final pubspec = _readPubspecVersion();
    expect(kAppVersion, pubspec.version);
  });

  test('kAppVersionCode mirrors pubspec.yaml build code', () {
    final pubspec = _readPubspecVersion();
    expect(kAppVersionCode, pubspec.code);
  });

  test('kAppVersion is non-empty and follows semver major.minor.patch', () {
    expect(kAppVersion, isNotEmpty);
    expect(
      RegExp(r'^\d+\.\d+\.\d+(-[A-Za-z0-9.-]+)?$').hasMatch(kAppVersion),
      isTrue,
      reason: 'kAppVersion must look like a semver, got "$kAppVersion"',
    );
  });

  test('kAppVersionCode is a positive integer', () {
    expect(kAppVersionCode, greaterThan(0));
  });
}
