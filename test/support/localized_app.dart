// Test-only helper that wraps a widget in a MaterialApp with
// the v1.1h / ADR-031 / SYS-087 generated
// `AppLocalizations` delegate wired.
//
// The production root (`DoItApp` in `lib/main.dart`) wires
// the delegate at the MaterialApp level, but most widget
// tests mount their screen directly inside a plain
// `MaterialApp` so they can control theme / locale. Without
// the delegate, `AppLocalizations.of(context)` returns
// null and the new localized widgets crash on the `!`
// assertion in the generated code.
//
// Usage:
//
// ```dart
// Widget _wrap(...) => ChangeNotifierProvider(...,
//   child: localizedApp(home: MyScreen(...)));
// ```
//
// The helper keeps the existing per-test theme / locale
// overrides by accepting optional `theme` / `darkTheme` /
// `themeMode` / `locale` parameters. It does NOT mount
// `DoItApp` (which pulls in every service singleton); it
// only wires the localizations delegate on top of whatever
// `MaterialApp` the test would otherwise construct.
//
// Imports use a relative path because Dart's package
// resolver does not reach into `test/`; production code
// should keep importing `package:doit/l10n/...` and the
// generated delegate directly.

import 'package:doit/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

Widget localizedApp({
  required Widget home,
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode? themeMode,
  Locale? locale,
  List<NavigatorObserver>? navigatorObservers,
  Iterable<LocalizationsDelegate<dynamic>>? additionalDelegates,
}) {
  final delegates = <LocalizationsDelegate<dynamic>>[
    ...AppLocalizations.localizationsDelegates,
    ...?additionalDelegates,
  ];
  return MaterialApp(
    theme: theme,
    darkTheme: darkTheme,
    themeMode: themeMode,
    locale: locale,
    localizationsDelegates: delegates,
    supportedLocales: AppLocalizations.supportedLocales,
    navigatorObservers: navigatorObservers ?? const <NavigatorObserver>[],
    home: home,
  );
}
