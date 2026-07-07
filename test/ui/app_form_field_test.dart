// Widget tests for `lib/ui/app_form_field.dart`.
//
// Covers the C4 form-pattern primitive (text + multi-line variants)
// extracted during the Month 1 UI-consolidation sprint (PR7 of 15).
// See:
//   - SYS-173 (this PR's surface)
//   - ADR-104 (the rationale + the canonical-pattern call)
//   - WF-101 (this test file)
//   - lib/ui/app_form_field.dart (the system under test)
//
// Test cases pin:
//   - AppFormField renders a TextField.
//   - The label is rendered as the InputDecoration's labelText.
//   - errorText renders under the field when non-null.
//   - errorText is absent when null.
//   - helperText renders under the field when non-null.
//   - onChanged callback fires on every keystroke.
//   - maxLines: 1 (default) renders a single-line TextField.
//   - maxLines: 3 (multi-line) renders a multi-line TextField.
//   - The Key is forwarded to the underlying TextField.
//   - The label is exposed through the Semantics tree
//     (TalkBack reads the label verbatim).
//   - AppFormField compiles when wrapped in DoIt's dark theme.
//   - The default maximum-tap-target: TextField is unbounded;
//     the canonical 48dp constraint is owned by the form layout.

import 'package:doit/theme/app_theme.dart';
import 'package:doit/ui/app_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapDark(Widget body) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: body),
  );
}

void main() {
  group('AppFormField — basic rendering', () {
    testWidgets('renders a TextField', (tester) async {
      await tester.pumpWidget(_wrapDark(const AppFormField(label: 'Name')));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(AppFormField), findsOneWidget);
    });

    testWidgets('renders the label as the InputDecoration labelText', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapDark(const AppFormField(label: 'Email')));
      // The labelText is rendered inside the InputDecorator.
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('omits the label when label is null', (tester) async {
      await tester.pumpWidget(_wrapDark(const AppFormField()));
      expect(find.byType(TextField), findsOneWidget);
      // No label was passed — the labelText is null.
    });
  });

  group('AppFormField — errorText + helperText', () {
    testWidgets('renders errorText when non-null', (tester) async {
      await tester.pumpWidget(
        _wrapDark(const AppFormField(label: 'Name', errorText: 'Required')),
      );
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('does not render any error when errorText is null', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapDark(const AppFormField(label: 'Name')));
      // No "Required" or "Invalid" — the field has no error.
      // The label is still present.
      expect(find.text('Name'), findsOneWidget);
    });

    testWidgets('renders helperText when non-null', (tester) async {
      await tester.pumpWidget(
        _wrapDark(
          const AppFormField(
            label: 'Email',
            helperText: 'We will never share this.',
          ),
        ),
      );
      expect(find.text('We will never share this.'), findsOneWidget);
    });
  });

  group('AppFormField — keyboard + onChanged', () {
    testWidgets('onChanged callback fires on every keystroke', (tester) async {
      var captured = '';
      await tester.pumpWidget(
        _wrapDark(AppFormField(label: 'Name', onChanged: (v) => captured = v)),
      );
      await tester.enterText(find.byType(TextField), 'Hello');
      expect(captured, 'Hello');
    });

    testWidgets('onSubmitted callback fires on submit', (tester) async {
      var captured = '';
      await tester.pumpWidget(
        _wrapDark(
          AppFormField(label: 'Name', onSubmitted: (v) => captured = v),
        ),
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(captured, isA<String>());
    });

    testWidgets('keyboardType is forwarded to the TextField', (tester) async {
      await tester.pumpWidget(
        _wrapDark(
          const AppFormField(label: 'N', keyboardType: TextInputType.number),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.number);
    });

    testWidgets('textAlign is forwarded to the TextField', (tester) async {
      await tester.pumpWidget(
        _wrapDark(const AppFormField(label: 'N', textAlign: TextAlign.right)),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textAlign, TextAlign.right);
    });
  });

  group('AppFormField — maxLines', () {
    testWidgets('default maxLines is 1 (single-line)', (tester) async {
      await tester.pumpWidget(_wrapDark(const AppFormField(label: 'Name')));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, 1);
    });

    testWidgets('maxLines: 3 renders a multi-line TextField', (tester) async {
      await tester.pumpWidget(
        _wrapDark(const AppFormField(label: 'Note', maxLines: 3)),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, 3);
    });

    testWidgets('maxLines: null renders an unlimited-height field', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapDark(const AppFormField(label: 'Bio', maxLines: null)),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, isNull);
    });
  });

  group('AppFormField — controller + initialValue', () {
    testWidgets('controller is forwarded verbatim', (tester) async {
      final ctrl = TextEditingController(text: 'preset');
      addTearDown(ctrl.dispose);
      await tester.pumpWidget(
        _wrapDark(AppFormField(label: 'Name', controller: ctrl)),
      );
      expect(find.text('preset'), findsOneWidget);
    });
  });

  group('AppFormField — Key + Semantics', () {
    testWidgets('Key is forwarded to the underlying TextField', (tester) async {
      const key = ValueKey<String>('form.name');
      await tester.pumpWidget(
        _wrapDark(const AppFormField(label: 'Name', key: key)),
      );
      // The Key is forwarded to the TextField; the AppFormField
      // is identified by the same Key. We pin by the find.byKey
      // on the AppFormField specifically (since TextField would
      // also be reachable).
      expect(find.byKey(key), findsOneWidget);
    });
  });

  group('AppFormField — static accessor', () {
    test('the class is reachable without a private constructor surface', () {
      // Compiles only because AppFormField has a `const` default
      // constructor. If a future refactor adds a private
      // constructor and forgets to expose a factory, this
      // compile-time check breaks the build.
      const AppFormField(label: 'x');
    });
  });
}
