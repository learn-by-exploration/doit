// `AppFormField` — the canonical form text input.
//
// Lifted from the bare `TextField` + inline `InputDecoration` pattern
// that recurred across the Add* screens (`add_habit.dart`,
// `add_event.dart`, `add_person.dart`, `add_routine.dart`,
// `mission_math.dart`, `mission_type.dart`) and the Group-edit
// screen (`person_groups.dart`).
//
// The primitive wraps a [TextField] with the project's canonical
// [InputDecoration] (label + outline border + contentPadding +
// errorText). The [maxLines] parameter flips the field into
// multi-line mode (defaults to 1 = single-line text field). The
// `keyboardType` + `onChanged` + `controller` + `initialValue`
// parameters are forwarded to the underlying [TextField] verbatim.
//
// When [initialValue] is non-null AND [controller] is null, the
// field is backed by an internally-managed [TextEditingController]
// so the framework's TextField contract (no `initialValue` on the
// constructor; set initial text via controller) is honored. This
// is the standard Flutter pattern for a "preset value" form field
// without the caller having to wire up a `StatefulWidget`.
//
// Extracted during the Month 1 UI-consolidation sprint
// (PR7 of 15). See:
//   - SYS-173 (this PR's surface)
//   - ADR-104 (the rationale + the canonical-pattern call)
//   - WF-101 (the test file)
//   - lib/ui/app_form_field.dart (the system under test)

import 'package:flutter/material.dart';

class AppFormField extends StatefulWidget {
  const AppFormField({
    super.key,
    this.label,
    this.errorText,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.autofocus = false,
    this.helperText,
    this.maxLines = 1,
    this.textAlign,
  });

  /// The floating label / floating-label text. Optional — pass
  /// `null` for a no-label form field.
  final String? label;

  /// The error text rendered under the field. Optional — pass
  /// `null` for a no-error state. The framework styles the
  /// helperText with the M3 error color when this is non-null.
  final String? errorText;

  /// Forwarded to the underlying [TextField.controller]. When
  /// non-null, [initialValue] is ignored (Flutter's contract).
  final TextEditingController? controller;

  /// Initial value for the field. Honored only when [controller]
  /// is null. Internally a [TextEditingController] is created
  /// and disposed in the [State].
  final String? initialValue;

  /// Forwarded to the underlying [TextField.onChanged]. Fires
  /// on every keystroke.
  final ValueChanged<String>? onChanged;

  /// Forwarded to the underlying [TextField.onSubmitted]. Fires
  /// when the user submits via the soft keyboard's "done" /
  /// "next" action.
  final ValueChanged<String>? onSubmitted;

  /// Forwarded to the underlying [TextField.keyboardType].
  /// Common values: `TextInputType.text`, `TextInputType.number`,
  /// `TextInputType.emailAddress`, `TextInputType.multiline`.
  final TextInputType? keyboardType;

  /// Forwarded to the underlying [TextField.autofocus]. When
  /// `true`, the field grabs focus on first build. Default
  /// `false` (per the project default — autofocus is opt-in
  /// for the "first field on a screen" pattern, not all
  /// fields).
  final bool autofocus;

  /// The helper text rendered under the field (replaces
  /// [errorText] visually when [errorText] is null). Optional.
  final String? helperText;

  /// Forwarded to the underlying [TextField.maxLines]. Default
  /// 1 (single-line). Set to `null` for an unlimited-height
  /// multi-line field.
  final int? maxLines;

  /// Forwarded to the underlying [TextField.textAlign]. Useful
  /// for compact numeric inputs (e.g., the "Every N days"
  /// field in `add_person.dart`) where the value is right-
  /// aligned for visual rhythm with the surrounding label.
  final TextAlign? textAlign;

  @override
  State<AppFormField> createState() => _AppFormFieldState();
}

class _AppFormFieldState extends State<AppFormField> {
  TextEditingController? _internalCtrl;

  TextEditingController? get _effectiveController {
    if (widget.controller != null) return widget.controller;
    if (_internalCtrl != null) return _internalCtrl;
    if (widget.initialValue != null) {
      _internalCtrl = TextEditingController(text: widget.initialValue);
    }
    return _internalCtrl;
  }

  @override
  void dispose() {
    _internalCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _effectiveController,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      keyboardType: widget.keyboardType,
      autofocus: widget.autofocus,
      maxLines: widget.maxLines,
      textAlign: widget.textAlign ?? TextAlign.start,
      // The canonical InputDecoration for the project. The
      // outline border is the M3 default (no override needed);
      // the label is the floating label; the helperText +
      // errorText render under the field.
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        helperText: widget.helperText,
      ),
    );
  }
}
