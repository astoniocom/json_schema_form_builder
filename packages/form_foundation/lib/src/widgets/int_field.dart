import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'common/examples_dropdown_mixin.dart';
import 'common/text_value_sync_mixin.dart';
import 'field_label.dart';
import 'form_theme.dart';

/// An integer editor: a text field accepting only an optional sign and
/// digits (up to the signed int64 length). Intermediate input ("-") is kept
/// in the field but reported as null until it parses.
class IntField extends StatefulWidget {
  /// Creates an integer field; null [onChanged] renders it read-only.
  const IntField({
    this.value,
    this.onChanged,
    this.title,
    this.error,
    this.helpText,
    this.examples,
    this.required = false,
    this.focusNode,
    super.key,
  });

  /// The current value; null shows an empty field.
  final int? value;

  /// Receives the parsed value on every edit (null while the text is not a
  /// number); null disables the field.
  final void Function(int? value)? onChanged;

  /// The field label.
  final String? title;

  /// Validation message; replaces [helpText] while non-empty.
  final String? error;

  /// Helper text under the field.
  final String? helpText;

  /// Values offered in the examples dropdown (the suffix arrow button).
  final List<int>? examples;

  /// Marks the label with the required asterisk.
  final bool required;

  /// External focus node; an internal one is created when null.
  final FocusNode? focusNode;

  @override
  State<IntField> createState() => _IntFieldState();
}

class _IntFieldState extends State<IntField> with ExamplesDropdownMixin<int, IntField>, TextValueSyncMixin<int, IntField> {
  static final RegExp _numberRegex = RegExp(r'^-?\d*$');

  @override
  int? get fieldValue => widget.value;

  @override
  FocusNode? get externalFocusNode => widget.focusNode;

  @override
  String formatValue(int? value) => value?.toString() ?? '';

  @override
  int? parseValue(String text) {
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  @override
  void initState() {
    super.initState();
    initTextValueSync();
  }

  @override
  void didUpdateWidget(covariant IntField oldWidget) {
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

  void _selectExample(int example) {
    setControllerText(formatValue(example));

    widget.onChanged?.call(example);
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onChanged != null;
    final hasExamples = widget.examples != null && widget.examples!.isNotEmpty && isInteractive;

    final Widget field = CompositedTransformTarget(
      link: layerLink,
      child: TextFormField(
        key: fieldKey,
        focusNode: focusNode,
        controller: controller,
        enabled: isInteractive,
        keyboardType: const TextInputType.numberWithOptions(
          signed: true,
        ),
        inputFormatters: [
          TextInputFormatter.withFunction((oldValue, newValue) {
            final text = newValue.text;

            // Limit to 19 characters (maximum length of a signed int64)
            if (text.length > 19) {
              return oldValue;
            }

            if (_numberRegex.hasMatch(text)) {
              return newValue;
            }
            return oldValue;
          }),
        ],
        decoration: InputDecoration(
          label: FieldLabel(
            label: widget.title,
            isRequired: widget.required,
          ),
          hintText: '42',
          helperText: widget.helpText,
          errorText: (widget.error != null && widget.error!.isNotEmpty) ? widget.error : null,
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
        onChanged: isInteractive
            ? (String value) {
                final intValue = parseValue(value);
                widget.onChanged?.call(intValue);
              }
            : null,
      ),
    );

    return Padding(
      padding: FormTheme.fieldPaddingOf(context),
      child: field,
    );
  }
}
