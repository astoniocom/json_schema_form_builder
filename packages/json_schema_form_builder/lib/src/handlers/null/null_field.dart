import 'package:form_foundation/form_foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/json_field_state.dart';
import '../../models/presence_value.dart';
import '../../utils/utils.dart';
import 'null_field_state.dart';

/// The editor of `type: "null"` fields: a decorator row with a suffix button
/// toggling between the explicit JSON null and no value at all — the only
/// two states the type admits.
class NullField extends StatelessWidget {
  /// Creates a null field; null [onChanged] renders it read-only.
  const NullField({
    required this.fieldState,
    required this.onChanged,
    this.absentAllowed = true,
    super.key,
  });

  /// The state to render.
  final NullFieldState fieldState;

  /// Receives the updated state; null disables the field. Deliberately wide
  /// (the base state type): the widget only emits states, and the emitted
  /// copy is statically a JsonFieldState (see JsonFieldState.copyWith).
  final void Function(JsonFieldState)? onChanged;

  /// Whether clearing to an absent value is representable at this document
  /// position (see FieldDisplayContext.absentAllowed). When false — e.g. an
  /// array item, whose slot always holds a value — the reset button is not
  /// offered: its write would be coerced right back to null by the parent,
  /// so the control would do nothing.
  final bool absentAllowed;

  @override
  Widget build(BuildContext context) {
    final bool isReadOnly = onChanged == null || (fieldState.fieldAnnotations?.readOnly ?? false);
    final bool isRequired = fieldState.fieldAnnotations?.required ?? false;
    final value = fieldState.value;
    final l10n = jsonFormLocalizationsOf(context);

    Widget? suffixIcon;
    if (!isReadOnly) {
      if (value.present && !isRequired && absentAllowed) {
        suffixIcon = IconButton(
          tooltip: l10n.resetValueTooltip,
          onPressed: () => onChanged?.call(fieldState.copyWith(value: const PresenceValue.absent())),
          icon: const Text(
            'null',
            style: TextStyle(decoration: TextDecoration.lineThrough),
          ),
        );
      } else if (!value.present || value.value != null) {
        suffixIcon = IconButton(
          tooltip: l10n.setNullTooltip,
          onPressed: () => onChanged?.call(fieldState.copyWith(value: const PresenceValue(null))),
          icon: const Text('null'),
        );
      }
    }

    final field = InputDecorator(
      isEmpty: !fieldState.value.present,
      decoration: InputDecoration(
        enabled: !isReadOnly,
        label: FieldLabel(
          label: fieldState.title,
          isRequired: isRequired,
        ),
        errorText: fieldState.errorsAsString,
        helperText: fieldState.fieldAnnotations?.description,
        suffixIcon: suffixIcon,
      ),
      // The child must not collapse to null for an absent value: a null
      // child shrinks the decorator (no content line), so the field would
      // change height when the value is set/reset. The placeholder is a
      // space, NOT an empty string: with real fonts the engine computes an
      // empty paragraph's line metrics differently from a line with an
      // actual glyph, so Text('') still changes the field height (only the
      // uniform test font makes them equal).
      child: Text(value.present ? valueAsString(value) : ' '),
    );

    return Padding(
      padding: FormTheme.fieldPaddingOf(context),
      child: field,
    );
  }
}
