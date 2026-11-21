import 'package:material_ui/material_ui.dart';

import 'field_label.dart';
import 'form_theme.dart';

/// A boolean editor: an [InputDecorator]-framed row with a trailing
/// [Checkbox], so it aligns with the text-based fields around it.
class BoolField extends StatelessWidget {
  /// Creates a boolean field; null [onChanged] renders it read-only.
  const BoolField({
    this.value,
    this.onChanged,
    this.title,
    this.error,
    this.helpText,
    this.required = false,
    this.tristate = false,
    this.displayValue,
    super.key,
  });

  /// The current value; null shows an indeterminate checkbox (no value yet).
  final bool? value;

  /// The field label.
  final String? title;

  /// Receives the next value of the checkbox cycle; null disables the field.
  final void Function(bool? value)? onChanged;

  /// Validation message; replaces [helpText] while non-empty.
  final String? error;

  /// Helper text under the field.
  final String? helpText;

  /// Marks the label with the required asterisk.
  final bool required;

  /// Whether the checkbox admits the third (null) state. A checkbox is
  /// inherently two-state, so this should be enabled only when null is a
  /// meaningful value of its own (e.g. a nullable-typed schema); otherwise
  /// a click cycling into null can silently clear the field.
  final bool tristate;

  /// Text shown inside the decorator next to the checkbox (e.g. the value of
  /// a non-boolean the checkbox editor was asked to display); empty keeps
  /// the row collapsed.
  final String? displayValue;

  /// Replicates the internal Checkbox cycle (false → true → [null, if
  /// allowed] → false), so that a tap on any part of the widget behaves
  /// identically to a tap directly on the checkbox.
  bool? _nextValue(bool? current) {
    switch (current) {
      case false:
        return true;
      case true:
        return tristate ? null : false;
      case null:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final boolValue = value;
    final isInteractive = onChanged != null;
    final hasDisplayValue = displayValue != null && displayValue!.isNotEmpty;

    final Widget field = InputDecorator(
      isEmpty: !hasDisplayValue,
      decoration: InputDecoration(
        enabled: isInteractive,
        label: FieldLabel(label: title, isRequired: required),
        errorText: (error == null || error!.isEmpty) ? null : error,
        helperText: helpText,
        suffixIcon: Checkbox(
          visualDensity: VisualDensity.compact,
          // value == null must be displayable even in two-state mode (an
          // untouched field carries no value yet); the write cycle is still
          // governed by _nextValue.
          tristate: tristate || boolValue == null,
          value: boolValue,
          onChanged: isInteractive ? (_) => onChanged!(_nextValue(boolValue)) : null,
        ),
      ),
      child: hasDisplayValue
          ? Text(
              displayValue!,
              style: Theme.of(context).textTheme.bodyLarge,
            )
          : const SizedBox.shrink(),
    );

    return Padding(
      padding: FormTheme.fieldPaddingOf(context),
      child: field,
    );
  }
}
