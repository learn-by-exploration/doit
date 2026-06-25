// Static-analysis guard for the CI 3-gate (SYS-057).
// The workflow file is parsed with a lightweight string check; we do
// not run GitHub Actions. The real verification is the CI run on
// every PR — which is exactly what this file is protecting from
// silent regression.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String relative) {
  return File(relative).readAsStringSync();
}

void main() {
  // The 3-gate steps must appear in the right order. The order is
  // the contract from `AGENTS.md` § "The 3-gate". This test fails
  // if the workflow reorders, drops, or typos any of the three
  // commands.
  test('CI workflow declares the three 3-gate steps in order', () {
    final workflow = _read('.github/workflows/ci.yml');

    // Search for the `run:` form so a header comment that
    // mentions the gate (e.g. a docstring at the top of the file)
    // does not poison the order check.
    final formatIdx = workflow.indexOf('dart format --output=none');
    final analyzeIdx = workflow.indexOf('flutter analyze --fatal-infos');
    final testIdx = workflow.indexOf('flutter test --coverage');

    expect(
      formatIdx,
      isNonNegative,
      reason: 'CI must run `dart format` (the first gate)',
    );
    expect(
      analyzeIdx,
      isNonNegative,
      reason: 'CI must run `flutter analyze --fatal-infos` (the second gate)',
    );
    expect(
      testIdx,
      isNonNegative,
      reason: 'CI must run `flutter test` (the third gate)',
    );

    expect(
      formatIdx < analyzeIdx,
      isTrue,
      reason: '`dart format` must come before `flutter analyze --fatal-infos`',
    );
    expect(
      analyzeIdx < testIdx,
      isTrue,
      reason: '`flutter analyze --fatal-infos` must come before `flutter test`',
    );
  });

  // The workflow must trigger on `pull_request` and on `push` to
  // `main`. A workflow that only fires on one of the two is not
  // the contract.
  test('CI workflow triggers on pull_request and push to main', () {
    final workflow = _read('.github/workflows/ci.yml');

    expect(
      workflow,
      contains('pull_request:'),
      reason: 'CI must run on every pull_request to main',
    );
    expect(
      workflow,
      contains('push:'),
      reason: 'CI must run on every push to main',
    );
    expect(
      workflow,
      contains('branches: [main]'),
      reason: 'CI push trigger must be scoped to main',
    );
  });

  // The job name must be `quality` (or another well-known label
  // like "3-gate"); it must use `ubuntu-latest` to match the
  // `subosito/flutter-action` setup the workflow assumes.
  test('CI workflow uses ubuntu-latest and subosito/flutter-action', () {
    final workflow = _read('.github/workflows/ci.yml');

    expect(
      workflow,
      contains('ubuntu-latest'),
      reason: 'CI must run on ubuntu-latest (matches the local dev box)',
    );
    expect(
      workflow,
      contains('subosito/flutter-action@v2'),
      reason:
          'CI must use the same subosito/flutter-action setup the rest '
          'of the org uses (board_box, card_box) for cache-hit reuse',
    );
    expect(
      workflow,
      contains("FLUTTER_VERSION: '3.44.0'"),
      reason:
          'CI must pin the Flutter version to 3.44.0 to match the '
          'pub environment constraint in pubspec.yaml',
    );
  });

  // The `flutter analyze` step must pass `--fatal-infos` so the
  // gate matches the contract. A step that runs `flutter analyze`
  // without the flag would let infos regress silently.
  test('CI workflow passes --fatal-infos to flutter analyze', () {
    final workflow = _read('.github/workflows/ci.yml');
    expect(
      workflow,
      contains('flutter analyze --fatal-infos'),
      reason: 'CI must pass --fatal-infos so analyzer infos fail the build',
    );
  });

  // `flutter pub get` must come before any flutter command that
  // needs deps. A missing `pub get` step turns the first
  // `flutter test` into a guaranteed failure.
  test('CI workflow runs flutter pub get before flutter analyze / test', () {
    final workflow = _read('.github/workflows/ci.yml');

    final pubGetIdx = workflow.indexOf('run: flutter pub get');
    final analyzeIdx = workflow.indexOf('flutter analyze --fatal-infos');
    final testIdx = workflow.indexOf('flutter test --coverage');

    expect(
      pubGetIdx,
      isNonNegative,
      reason: 'CI must run `flutter pub get` to install deps',
    );
    expect(
      pubGetIdx < analyzeIdx,
      isTrue,
      reason: '`flutter pub get` must run before `flutter analyze`',
    );
    expect(
      pubGetIdx < testIdx,
      isTrue,
      reason: '`flutter pub get` must run before `flutter test`',
    );
  });

  // SYS-026 / PR #32: the CI workflow must contain a grep step
  // that rejects `import 'package:http'`, `Uri.http(s)(`,
  // and `HttpClient()` in production code (`lib/` +
  // `android/app/src/main/`). The step's stdout comment
  // names the SYS- ID so a grep through CI history surfaces
  // the contract. Without this step a future PR that adds
  // an HTTP client would slip through the 3-gate.
  test('CI workflow rejects network calls in production code (SYS-026)', () {
    final workflow = _read('.github/workflows/ci.yml');

    expect(
      workflow,
      contains("import 'package:http"),
      reason:
          'CI workflow grep must look for `import \'package:http\'` to '
          'satisfy SYS-026 (no network calls with user data)',
    );
    expect(
      workflow,
      contains('Uri\\.https?\\('),
      reason:
          'CI workflow grep must look for `Uri.http(s)(...)` to satisfy '
          'SYS-026 (catches `dart:io` HTTP usage even when the package '
          'is not imported)',
    );
    expect(
      workflow,
      contains('SYS-026'),
      reason:
          'CI workflow grep step must reference the SYS- ID so a '
          'history grep surfaces the contract',
    );
    // The grep step must NOT scan `test/` (the dev-only
    // test harness that SYS-026 explicitly whitelists) or
    // `tool/` (design-time scripts). Both are mentioned in
    // the inline comment in the workflow file.
    expect(
      workflow,
      contains('--exclude-dir=test'),
      reason:
          'CI grep must exclude `test/` so the dev-only test harness '
          '(which may import `package:http` for `MockClient`) is not '
          'falsely flagged',
    );
    expect(
      workflow,
      contains('--exclude-dir=tool'),
      reason:
          'CI grep must exclude `tool/` so design-time scripts '
          '(e.g. `tool/regen_launcher_icons.py`) are not scanned',
    );
  });
}
