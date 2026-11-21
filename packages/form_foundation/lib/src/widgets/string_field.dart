import 'package:material_ui/material_ui.dart';

import 'common/examples_dropdown_mixin.dart';
import 'common/text_value_sync_mixin.dart';
import 'field_label.dart';
import 'form_theme.dart';

/// A plain string editor. Any text — including the empty string — is a
/// valid value, so [onChanged] fires on every keystroke with the raw text.
class StringField extends StatefulWidget {
  /// Creates a string field; null [onChanged] renders it read-only.
  const StringField({
    this.value,
    this.title,
    this.onChanged,
    this.error,
    this.helpText,
    this.required = false,
    this.examples,
    this.maxLength,
    this.focusNode,
    super.key,
  });

  /// The current value; null shows an empty field.
  final String? value;

  /// The field label.
  final String? title;

  /// Receives the text on every edit; null disables the field.
  final void Function(String value)? onChanged;

  /// Validation message; replaces [helpText] while non-empty.
  final String? error;

  /// Helper text under the field.
  final String? helpText;

  /// Marks the label with the required asterisk.
  final bool required;

  /// Values offered in the examples dropdown (the suffix arrow button).
  final List<String>? examples;

  /// Hard input length limit (with the Material counter).
  final int? maxLength;

  /// External focus node; an internal one is created when null.
  final FocusNode? focusNode;

  @override
  State<StringField> createState() => _StringFieldState();
}

class _StringFieldState extends State<StringField> with ExamplesDropdownMixin<String, StringField>, TextValueSyncMixin<String, StringField> {
  @override
  String? get fieldValue => widget.value;

  @override
  FocusNode? get externalFocusNode => widget.focusNode;

  @override
  String formatValue(String? value) => value ?? '';

  /// For a string, any text is a valid value (including empty);
  /// there are no intermediate input states.
  @override
  String? parseValue(String text) => text;

  @override
  void initState() {
    super.initState();
    initTextValueSync();
  }

  @override
  void didUpdateWidget(covariant StringField oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncTextValueField(
      oldValue: oldWidget.value,
      oldFocusNode: oldWidget.focusNode,
    );
  }

  @override
  void dispose() {
    disposeExamplesOverlay();
    disposeTextValueSync();
    super.dispose();
  }

  void _selectExample(String example) {
    setControllerText(example);
    widget.onChanged?.call(example);
  }

  @override
  Widget build(BuildContext context) {
    final errorsLoc = widget.error;
    final hasExamples = widget.examples != null && widget.examples!.isNotEmpty && widget.onChanged != null;

    final Widget field = CompositedTransformTarget(
      link: layerLink,
      child: TextField(
        key: fieldKey,
        focusNode: focusNode,
        controller: controller,
        maxLength: widget.maxLength,
        enabled: widget.onChanged != null,
        decoration: InputDecoration(
          label: FieldLabel(
            label: widget.title,
            isRequired: widget.required,
          ),
          errorText: (errorsLoc == null || errorsLoc.isEmpty) ? null : errorsLoc,
          helperText: widget.helpText,
          suffixIcon: hasExamples
              ? IconButton(
                  onPressed: () => toggleExamplesDropdown(
                    widget.examples,
                    _selectExample,
                  ),
                  icon: Icon(
                    isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  ),
                )
              : null,
        ),
        onChanged: widget.onChanged,
      ),
    );

    return Padding(
      padding: FormTheme.fieldPaddingOf(context),
      child: field,
    );
  }
}
