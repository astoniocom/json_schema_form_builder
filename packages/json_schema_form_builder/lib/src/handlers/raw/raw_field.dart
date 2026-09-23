import 'package:flutter/material.dart';
import 'package:form_foundation/form_foundation.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/presence_value.dart';
import 'json_editor.dart';
import 'raw_field_state.dart';

/// The form-field face of the raw JSON editor: adapts a [RawFieldState] to
/// the plain-props [JsonEditor] (which owns highlighting, parsing and value
/// sync) and applies the form field padding.
class RawField extends StatelessWidget {
  /// Creates a raw field around [state]; null [onChanged] renders it
  /// read-only.
  const RawField({
    required this.state,
    this.onChanged,
    this.expands = false,
    this.style,
    super.key,
  });

  /// The state to render (value, title, annotations, errors, parse error).
  final RawFieldState state;

  /// See [JsonEditor.onChanged]; the handler stores the parse error in
  /// [RawFieldState.parseError] so validity-gated UI (dialog OK buttons)
  /// sees the field as invalid.
  final void Function(PresenceValue<dynamic> value, String? parseError)? onChanged;

  /// See [JsonEditor.expands].
  final bool expands;

  /// See [JsonEditor.style].
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final formErrors = state.errorsAsString;

    return Padding(
      padding: FormTheme.fieldPaddingOf(context),
      child: JsonEditor(
        value: state.value,
        title: state.title ?? jsonFormLocalizationsOf(context).valueFallbackLabel,
        required: state.fieldAnnotations?.required ?? false,
        helperText: state.fieldAnnotations?.description,
        errorText: formErrors != null && formErrors.isNotEmpty ? formErrors : null,
        expands: expands,
        style: style,
        onChanged: onChanged,
      ),
    );
  }
}
