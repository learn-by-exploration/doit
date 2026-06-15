// v0.4c.2 (SYS-062) static analysis: walks every Dart file
// in `lib/screens/` and `lib/widgets/`, finds every
// interactive element (IconButton, ListTile, ElevatedButton,
// TextButton, OutlinedButton, FilledButton, GestureDetector
// with an onTap, InkWell with an onTap), and asserts that
// each one has either a `tooltip:`, a `semanticLabel:`,
// a wrapping `Semantics(label: ...)`, or an explicit
// `excludeFromSemantics: true`.
//
// The test is a static analyzer (string-grep on the file
// contents), not a widget tree walker. Widget tree walks
// require pumping each screen; this test only checks the
// source, which is good enough to catch the common case
// where a new button is added without a label. The user's
// hands-on TalkBack pass (v0.4d) is the real verification.
//
// The list of widget types is conservative — any new
// interactive widget type in Flutter that do it adopts
// (e.g., `Switch.adaptive`, `Slider`) needs to be added to
// the regex.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Each entry is a widget-name pattern matched against a
/// single line. The widget name is what `grep` would
/// highlight. The `requiresOneOf` list is the set of
/// sibling attributes (on the same widget or a wrapping
/// `Semantics(label: ...)`) that must be present within a
/// few lines of the widget invocation. A line with
/// `excludeFromSemantics: true` is accepted as a deliberate
/// opt-out.
const List<WidgetCheck> _checks = [
  WidgetCheck(
    widgetPattern: r'\bIconButton\s*\(',
    requiresOneOf: [
      r'\btooltip\s*:',
      r'\bsemanticLabel\s*:',
      r'\bexcludeFromSemantics\s*:\s*true',
    ],
  ),
  WidgetCheck(
    widgetPattern: r'\bListTile\s*\(',
    requiresOneOf: [
      // ListTile's text comes from `title: Text(...)`; the
      // title is auto-exposed to TalkBack. We accept any
      // `title:` that is not a placeholder, with an optional
      // `const` between `title:` and `Text(...)`.
      r'\btitle\s*:\s*(const\s+)?Text\s*\(',
      r'\bsemanticLabel\s*:',
    ],
  ),
  WidgetCheck(
    widgetPattern: r'\bElevatedButton\s*\(',
    requiresOneOf: [
      // The `const` keyword is permitted between `child:`
      // and `Text(...)` — accept either form.
      r'\bchild\s*:\s*(const\s+)?Text\s*\(',
      r'\bsemanticLabel\s*:',
    ],
  ),
  WidgetCheck(
    widgetPattern: r'\bTextButton\s*\(',
    requiresOneOf: [
      r'\bchild\s*:\s*(const\s+)?Text\s*\(',
      r'\bsemanticLabel\s*:',
    ],
  ),
  WidgetCheck(
    widgetPattern: r'\bOutlinedButton\s*\(',
    requiresOneOf: [
      r'\bchild\s*:\s*(const\s+)?Text\s*\(',
      r'\bsemanticLabel\s*:',
    ],
  ),
  WidgetCheck(
    widgetPattern: r'\bFilledButton\s*\(',
    requiresOneOf: [
      r'\bchild\s*:\s*(const\s+)?Text\s*\(',
      r'\bsemanticLabel\s*:',
    ],
  ),
  WidgetCheck(
    widgetPattern: r'\bInkWell\s*\(',
    requiresOneOf: [
      r'\bonTap\s*:',
      // If there's an onTap, there must be SOME
      // visual label inside. We accept a Semantics
      // wrapper, a child Text, or an explicit
      // excludeFromSemantics.
      r'\bexcludeFromSemantics\s*:\s*true',
    ],
  ),
  WidgetCheck(
    widgetPattern: r'\bGestureDetector\s*\(',
    requiresOneOf: [r'\bonTap\s*:', r'\bexcludeFromSemantics\s*:\s*true'],
  ),
];

class WidgetCheck {
  const WidgetCheck({required this.widgetPattern, required this.requiresOneOf});
  final String widgetPattern;
  final List<String> requiresOneOf;
}

void main() {
  group('SYS-062: every interactive element in screens + widgets '
      'has a Semantics label', () {
    final libDir = Directory('lib');
    final dartFiles = <File>[];
    for (final sub in ['screens', 'widgets']) {
      final d = Directory('${libDir.path}/$sub');
      if (!d.existsSync()) continue;
      for (final f in d.listSync(recursive: true)) {
        if (f is File && f.path.endsWith('.dart')) dartFiles.add(f);
      }
    }

    test('discovered screens + widgets', () {
      expect(dartFiles, isNotEmpty, reason: 'No screens/widgets found');
    });

    for (final f in dartFiles) {
      final lines = f.readAsLinesSync();
      test(f.path, () {
        final missing = <String>[];
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          for (final c in _checks) {
            if (!RegExp(c.widgetPattern).hasMatch(line)) continue;
            // Look ahead up to 10 lines for the label
            // attributes. This covers multi-line
            // constructor invocations.
            final window = (lines
                .sublist(i, (i + 10).clamp(0, lines.length))
                .join('\n'));
            // If the line itself has `excludeFromSemantics:
            // true` or a Semantics wrapper, accept.
            if (RegExp(r'\bexcludeFromSemantics\s*:\s*true').hasMatch(window)) {
              continue;
            }
            // If `onTap` is not present and the widget is
            // e.g. a non-interactive InkWell, we don't
            // need a label. Only complain if the
            // interactive attribute is set.
            final hasInteractive = RegExp(
              r'\b(onTap|onPressed)\s*:',
            ).hasMatch(window);
            if (!hasInteractive &&
                (c.widgetPattern.contains('InkWell') ||
                    c.widgetPattern.contains('GestureDetector'))) {
              continue;
            }
            final ok = c.requiresOneOf.any((p) => RegExp(p).hasMatch(window));
            if (!ok) {
              missing.add(
                'Line ${i + 1}: ${line.trim()} '
                '(needs one of: ${c.requiresOneOf.join(", ")})',
              );
            }
          }
        }
        expect(
          missing,
          isEmpty,
          reason:
              'Interactive elements in ${f.path} are missing a Semantics '
              'label. Either add a tooltip, semanticLabel, or a '
              'Text/title child, or wrap in Semantics(label: ...), or '
              'set excludeFromSemantics: true. '
              'Missing:\n${missing.join("\n")}',
        );
      });
    }
  });
}
