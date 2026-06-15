// Static-analysis guard for the v0.3 release signingConfig (SYS-053).
// The build script is parsed with a lightweight regex; we do not run
// Gradle. The real verification is a `flutter build appbundle --release`
// succeeding with the user's env vars set, which is the user's
// hands-on v0.3e step.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String relative) {
  return File(relative).readAsStringSync();
}

void main() {
  test('android/app/build.gradle.kts declares a release signingConfig', () {
    final build = _read('android/app/build.gradle.kts');
    expect(
      build,
      contains('signingConfigs'),
      reason: 'build.gradle.kts must declare a signingConfigs block',
    );
    expect(
      build,
      contains('create("release")'),
      reason: 'signingConfigs must include a `release` entry',
    );
  });

  test('build.gradle.kts reads android/key.properties defensively', () {
    final build = _read('android/app/build.gradle.kts');
    expect(build, contains('key.properties'));
    expect(
      build,
      contains('keystorePropertiesFile.exists()'),
      reason:
          'build.gradle.kts must guard the key.properties read with an '
          'exists() check so dev builds keep working without the file',
    );
  });

  test('buildTypes.release points at signingConfigs.release', () {
    final build = _read('android/app/build.gradle.kts');
    expect(
      build,
      contains('signingConfigs.getByName("release")'),
      reason:
          'buildTypes.release must reference signingConfigs.getByName("release")',
    );
  });

  test('buildTypes.release falls back to debug signing when key.properties '
      'is absent', () {
    final build = _read('android/app/build.gradle.kts');
    expect(
      build,
      contains('signingConfigs.getByName("debug")'),
      reason: 'buildTypes.release must fall back to debug signing',
    );
  });

  test('isMinifyEnabled is NOT set in buildTypes.release (v0.3 decision)', () {
    final build = _read('android/app/build.gradle.kts');
    expect(
      build,
      isNot(contains('isMinifyEnabled = true')),
      reason: 'R8 / minify is OFF for v0.3 (see decision_record.md)',
    );
  });

  test('isMinifyEnabled = false is pinned in buildTypes.release '
      '(v0.4b-release-fix-2 / ADR-013 follow-up)', () {
    // The v0.3 decision says "R8 / minify is OFF" but the
    // build config was relying on the AGP default. In AGP
    // 9.x the default for `isMinifyEnabled` is `false` for
    // release, but a future AGP could flip the default and
    // break us silently. Pin the value explicitly so a
    // stray AGP upgrade cannot re-enable R8 and re-introduce
    // the workmanager WorkDatabase_Impl class-stripping
    // crash. See `docs/v_model/decision_record.md` ADR-013.
    final build = _read('android/app/build.gradle.kts');
    expect(
      build,
      contains('isMinifyEnabled = false'),
      reason: 'isMinifyEnabled = false must be set explicitly',
    );
    expect(
      build,
      contains('isShrinkResources = false'),
      reason: 'isShrinkResources = false must be set explicitly',
    );
  });

  test('android/key.properties is gitignored', () {
    final gitignore = _read('.gitignore');
    expect(
      gitignore,
      contains('key.properties'),
      reason: 'real key.properties must be in .gitignore',
    );
  });

  test('android/*.jks and android/*.der patterns are gitignored', () {
    final gitignore = _read('.gitignore');
    // The root .gitignore has `*.jks` and `*.der` patterns; the
    // android/-scoped line `/android/streak-release-key.jks` is
    // belt-and-braces. We assert the root patterns are present.
    expect(
      gitignore,
      contains('*.jks'),
      reason: 'root .gitignore must include the *.jks pattern',
    );
    expect(
      gitignore,
      contains('*.der'),
      reason: 'root .gitignore must include the *.der pattern',
    );
  });

  test('android/key.properties.example exists and is a template', () {
    final example = _read('android/key.properties.example');
    expect(
      example,
      contains('storeFile'),
      reason: 'key.properties.example must show the storeFile key',
    );
    expect(
      example,
      contains('storePassword'),
      reason: 'key.properties.example must show the storePassword key',
    );
    expect(
      example,
      contains('keyAlias'),
      reason: 'key.properties.example must show the keyAlias key',
    );
    expect(
      example,
      contains('keyPassword'),
      reason: 'key.properties.example must show the keyPassword key',
    );
  });

  test('AndroidManifest disables workmanager WorkManagerInitializer auto-init '
      '(v0.4b-release-fix-2 / ADR-013 follow-up)', () {
    // The workmanager 0.6.0 plugin auto-registers
    // `androidx.work.WorkManagerInitializer` via the
    // `androidx.startup` library. The auto-initializer runs
    // at process start (before `MainActivity.onCreate`),
    // constructs the WorkManager singleton, and instantiates
    // the Room-generated `WorkDatabase_Impl` class. On a
    // release build where R8 has stripped that class, the
    // `Class.forName(...)` lookup throws and the process
    // crashes before any Dart code can run. Streak owns the
    // WorkManager init order itself (see
    // `lib/services/backup_scheduler.dart`); the OS does not
    // need to pre-create the singleton. The manifest must
    // remove the WorkManagerInitializer meta-data from the
    // merged InitializationProvider. See
    // `docs/v_model/decision_record.md` ADR-013.
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    expect(
      manifest,
      contains('xmlns:tools='),
      reason:
          'manifest must declare the tools namespace to use tools:node="remove"',
    );
    expect(
      manifest,
      contains('androidx.work.WorkManagerInitializer'),
      reason: 'manifest must reference the WorkManagerInitializer meta-data',
    );
    expect(
      manifest,
      contains('tools:node="remove"'),
      reason: 'manifest must remove the WorkManagerInitializer auto-init entry',
    );
  });
}
