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
    // android/-scoped line `/android/doit-release-key.jks` is
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
    // crashes before any Dart code can run. do it owns the
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

  // ── v0.5a rename pins ────────────────────────────────────────────
  // The app's identity moved from "Streak" / `com.common_games.streak`
  // to "do it" / `com.doit`. These tests pin the v0.5a
  // invariants so a future accidental revert fails CI.
  //
  // v0.5e-fix: the original `com.doit.package` namespace was invalid
  // because `package` is a Java reserved keyword (AGP rejected it at
  // build time). The actual package id is `com.doit`.

  test('build.gradle.kts pins applicationId to com.doit (v0.5a)', () {
    final build = _read('android/app/build.gradle.kts');
    expect(
      build,
      contains('applicationId = "com.doit"'),
      reason:
          'v0.5a pinned applicationId to com.doit. A revert to '
          'com.common_games.streak would break the on-device install '
          '(the user already uninstalled the v0.4b build).',
    );
    expect(
      build,
      contains('namespace = "com.doit"'),
      reason:
          'v0.5a pinned namespace to com.doit (must match '
          'applicationId for Android resource lookup).',
    );
    expect(
      build,
      isNot(contains('com.common_games.streak')),
      reason:
          'v0.5a rename is full-scope — no com.common_games.streak '
          'remnants in build.gradle.kts.',
    );
    expect(
      build,
      isNot(contains('com.doit.package')),
      reason:
          'v0.5e-fix: `com.doit.package` is an invalid Java namespace '
          '(`package` is a reserved keyword). The applicationId and '
          'namespace must be `com.doit`, not `com.doit.package`.',
    );
  });

  test('pubspec.yaml name is "doit" and version is 1.2.0+9 (v1.2)', () {
    final pubspec = _read('pubspec.yaml');
    expect(
      pubspec,
      contains('name: doit'),
      reason:
          'v0.5a renamed the Dart package from common_games to doit. '
          'Every `package:doit/...` import depends on this.',
    );
    expect(
      pubspec,
      contains('version: 1.2.0+9'),
      reason:
          'v1.2 bumped the version from 1.1.0+8 to 1.2.0+9 to mark '
          'the code-TODO closure milestone (13 sub-entries v1.2a..m). '
          'A drift back to 1.1.0+8 would indicate a forgotten version '
          'bump on a future v1.x change.',
    );
    expect(
      pubspec,
      isNot(contains('name: common_games')),
      reason: 'pubspec.yaml must not reference the old common_games name.',
    );
  });

  test('lib/build_info.dart mirrors pubspec 1.2.0+9 (v1.2)', () {
    final info = _read('lib/build_info.dart');
    expect(
      info,
      contains("kAppVersion = '1.2.0'"),
      reason: 'lib/build_info.dart must mirror pubspec.yaml version (1.2.0).',
    );
    expect(
      info,
      contains('kAppVersionCode = 9'),
      reason: 'lib/build_info.dart must mirror pubspec.yaml versionCode (9).',
    );
  });

  test('android/app/src/main/res/values/strings.xml app_name is "do it" '
      '(v0.5a)', () {
    final strings = _read('android/app/src/main/res/values/strings.xml');
    expect(
      strings,
      contains('<string name="app_name">do it</string>'),
      reason:
          'The launcher label must read "do it" (v0.5a rename). The '
          'manifest uses android:label="@string/app_name" so this '
          'single source controls the launcher.',
    );
    expect(
      strings,
      isNot(contains('<string name="app_name">Streak</string>')),
      reason: 'v0.5a full-scope rename: no "Streak" app_name in strings.xml.',
    );
  });

  test('MethodChannel "doit/reminders" is the only reminders channel '
      '(v0.5a)', () {
    final bridge = _read('lib/reminders/reminder_bridge.dart');
    // Match either `MethodChannel('doit/reminders')` or
    // `MethodChannel("doit/reminders")` — the test only cares that
    // the channel name is "doit/reminders" and that there is
    // exactly one declaration site.
    final channelDeclarations = RegExp(
      '''MethodChannel\\(['"]doit/reminders['"]\\)''',
    ).allMatches(bridge);
    expect(
      channelDeclarations.length,
      1,
      reason:
          'lib/reminders/reminder_bridge.dart must declare the '
          'doit/reminders MethodChannel exactly once. v0.5a renamed '
          'it from streak/reminders; a duplicate declaration would '
          'break the platform-side lookup.',
    );
    expect(
      bridge,
      isNot(contains("'streak/reminders'")),
      reason:
          'v0.5a renamed the MethodChannel name; no streak/reminders '
          'string literal must remain in the bridge.',
    );
  });

  test('notification channel id is "doit.reminders" (v0.5a)', () {
    // The id is declared as a Dart constant in
    // `lib/reminders/notification_service.dart` so the widget
    // layer and the platform-side channel registration can
    // share a single source of truth. The value must be
    // exactly 'doit.reminders'.
    final source = _read('lib/reminders/notification_service.dart');
    expect(
      source,
      contains("'doit.reminders'"),
      reason:
          'The notification channel id must be exactly "doit.reminders" '
          '(v0.5a rename from streak.reminders). The id is used by '
          'Android to group notifications and survives app updates.',
    );
    expect(
      source,
      isNot(contains("'streak.reminders'")),
      reason: 'v0.5a full-scope rename: no streak.reminders string literal.',
    );
  });

  test('WorkManager backup task name is "doit.backup.nightly" (v0.5a)', () {
    final scheduler = _read('lib/services/backup_scheduler.dart');
    expect(
      scheduler,
      contains("'doit.backup.nightly'"),
      reason:
          'v0.5a renamed the WorkManager task name from '
          'streak.backup.nightly. The name is read at runtime by the '
          'workmanager plugin; the Kotlin side reads it from the '
          'intent Data map, so no Kotlin change was needed.',
    );
    expect(
      scheduler,
      isNot(contains("'streak.backup.nightly'")),
      reason: 'v0.5a full-scope rename: no streak.backup.nightly literal.',
    );
  });

  // ── v0.5a-fix rename pin ─────────────────────────────────────────
  // v0.5a renamed the user-facing identity (applicationId,
  // strings.xml, MethodChannel, etc.) but missed the Dart root
  // widget class `StreakApp` in lib/main.dart. The class is
  // app-level (it is the root widget of the do it app, not the
  // streak *feature*) so v0.5a-fix renames it to `DoItApp` and
  // updates every doc comment that referenced the old name.
  // This test pins the rename so a future accidental revert
  // fails CI before the v0.5e install block runs.
  test('lib/main.dart root widget class is DoItApp (v0.5a-fix)', () {
    final main = _read('lib/main.dart');
    expect(
      main,
      contains('class DoItApp extends StatelessWidget'),
      reason:
          'The root widget of the do it app must be named `DoItApp` '
          '(v0.5a-fix, was `StreakApp` until the v0.5a commit missed '
          'it). The class is app-level — it sits at the top of the '
          'widget tree — and a future revert to `StreakApp` would '
          'leave the Dart source code referencing the old app name.',
    );
    expect(
      main,
      isNot(contains('class StreakApp')),
      reason:
          'v0.5a-fix removed the `StreakApp` class name. The old name '
          'must not reappear in lib/main.dart.',
    );
    expect(
      main,
      contains('runApp(const DoItApp());'),
      reason: 'main() must mount `DoItApp` (was `StreakApp`).',
    );
  });

  // ── v1.1i adaptive-icon + app-name pins ─────────────────────────
  // v1.1i ships a custom launcher icon (adaptive-icon XML +
  // 3 vector layers) and a custom splash drawable. The
  // release_signing_test mirrors the mirror-pin pattern from
  // v0.5a / v1.0g / v1.1h: assert that the manifest still
  // references `@mipmap/ic_launcher` (Android resolves that to
  // the new adaptive-icon XML on API 26+), and pin the app
  // name + version together so a v1.2+ bump surfaces here too.

  test('AndroidManifest icon reference resolves to the adaptive-icon XML '
      'on API 26+ (v1.1i)', () {
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    expect(
      manifest,
      contains('android:icon="@mipmap/ic_launcher"'),
      reason:
          'Manifest must keep `@mipmap/ic_launcher` as the icon '
          'reference; Android resolves that to '
          '`mipmap-anydpi-v26/ic_launcher.xml` on API 26+ (the '
          'v1.1i adaptive-icon XML) and to the legacy '
          '`mipmap-*/ic_launcher.png` files on API 21..25.',
    );
    final adaptiveIcon = _read(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    );
    expect(
      adaptiveIcon,
      contains('<adaptive-icon'),
      reason: 'The API 26+ entry point must be an <adaptive-icon> XML',
    );
    expect(
      adaptiveIcon,
      contains('@drawable/ic_launcher_background'),
      reason: 'adaptive-icon must reference the brand-purple background',
    );
    expect(
      adaptiveIcon,
      contains('@drawable/ic_launcher_foreground'),
      reason:
          'adaptive-icon must reference the white-on-transparent foreground',
    );
    expect(
      adaptiveIcon,
      contains('@drawable/ic_launcher_monochrome'),
      reason:
          'adaptive-icon must reference the monochrome layer for '
          'Android 13+ themed icons',
    );
  });

  test('app_name + kAppVersion are pinned together at v1.2', () {
    final strings = _read('android/app/src/main/res/values/strings.xml');
    final buildInfo = _read('lib/build_info.dart');
    final pubspec = _read('pubspec.yaml');
    expect(
      strings,
      contains('<string name="app_name">do it</string>'),
      reason: 'app_name must remain "do it" (v0.5a rename).',
    );
    expect(
      buildInfo,
      contains("kAppVersion = '1.2.0'"),
      reason: 'kAppVersion must be 1.2.0 (v1.2 bump).',
    );
    expect(
      pubspec,
      contains('version: 1.2.0+9'),
      reason: 'pubspec.yaml version must be 1.2.0+9 (v1.2 bump).',
    );
  });
}
