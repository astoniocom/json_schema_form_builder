import 'package:material_ui/material_ui.dart';

import '../../form_foundation.dart';

/// The compact representation of a container field: a one-line summary of
/// [value] with an edit button that opens the full editor (usually a
/// dialog). Editors collapse into it when the available width is too small
/// for the inline form (see WidthThresholdBuilder).
class CollapsedValueField<T> extends StatelessWidget {
  /// Creates a collapsed field; null [onEdit] renders it disabled.
  const CollapsedValueField({
    required this.labelText,
    required this.value,
    this.helperText,
    this.errorText,
    this.onEdit,
    this.valueVerboseText,
    this.isRequired = false,
    super.key,
  });

  /// The field label.
  final String? labelText;

  /// Validation message; replaces [helperText] while non-empty.
  final String? errorText;

  /// Helper text under the field.
  final String? helperText;

  /// Opens the full editor; null renders the field (and its button) disabled.
  final VoidCallback? onEdit;

  /// The summarized value. Null and empty collections render as an empty
  /// decorator (no summary line).
  final dynamic value;

  /// The summary text; falls back to `value.toString()`.
  final String? valueVerboseText;

  /// Marks the label with the required asterisk.
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final valueLoc = value;
    final isEmpty = valueLoc == null || (valueLoc is Iterable && valueLoc.isEmpty) || (valueLoc is Map && valueLoc.isEmpty);
    final Widget field = InputDecorator(
      isEmpty: isEmpty,
      decoration: InputDecoration(
        label: FieldLabel(
          label: labelText,
          isRequired: isRequired,
        ),
        errorText: errorText,
        helperText: helperText,
        enabled: onEdit != null,
        suffixIcon: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onEdit,
        ),
      ),
      child: isEmpty ? const SizedBox.shrink() : Text(valueVerboseText ?? value.toString(), maxLines: 1),
    );

    return Padding(
      padding: FormTheme.fieldPaddingOf(context),
      child: field,
    );
  }
}
