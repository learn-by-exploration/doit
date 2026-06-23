// Build-time constants. The single source of truth for the version
// string and build code that is shown in the in-app About screen and
// asserted by `test/build_info_test.dart` against `pubspec.yaml`.
//
// Must mirror `pubspec.yaml` `version:`. Do not bump one without the
// other; the test fails on drift. The build system reads the
// `pubspec.yaml` value at compile time, while runtime Dart code
// reads this constant for display purposes (Flutter does not expose
// the pubspec version to runtime Dart without `--dart-define`).
const String kAppVersion = '1.2.0';
const int kAppVersionCode = 9;
