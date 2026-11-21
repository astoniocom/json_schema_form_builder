import 'package:form_foundation/form_foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/json_field_state.dart';
import '../../utils/utils.dart';
import 'unknown_field_state.dart';

/// The read-only rendering of a field no handler accepts: the value as text
/// behind a question-mark icon. A visible "this is unsupported" marker, not
/// an editor.
class UnknownField extends StatelessWidget {
  /// Creates an unknown field row.
  const UnknownField({
    required this.fieldState,
    super.key,
  });

  /// The state to display (any state renders; an UnknownFieldState also
  /// contributes its recorded type to the label).
  final JsonFieldState fieldState;

  @override
  Widget build(BuildContext context) {
    final fieldStateLoc = fieldState;
    final bool isRequired = fieldState.fieldAnnotations?.required ?? false;
    final value = fieldState.value;
    final title = fieldStateLoc.title ?? (fieldStateLoc is UnknownFieldState ? fieldStateLoc.type?.toString() : null);

    final field = InputDecorator(
      isEmpty: !fieldState.value.present,
      decoration: InputDecoration(
        label: FieldLabel(
          label: title,
          isRequired: isRequired,
        ),
        errorText: fieldState.errorsAsString,
        helperText: fieldState.fieldAnnotations?.description,
        prefixIcon: const Icon(Icons.question_mark_outlined),
      ),
      child: fieldState.value.present ? Text(valueAsString(value, notPresented: jsonFormLocalizationsOf(context).valueAbsentLabel)) : null,
    );

    return Padding(
      padding: FormTheme.of(context).fieldPadding,
      child: field,
    );
  }
}
