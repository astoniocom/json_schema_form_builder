import 'package:flutter/material.dart';

import 'common/examples_dropdown_mixin.dart';
import 'field_label.dart';
import 'form_theme.dart';

/// A field for JSON Schema strings with `format: "date"`: a read-only text
/// field driven by [showDatePicker]. An out-of-range value from the data is
/// clamped to the picker's range instead of crashing it.
class StringDateField extends StatefulWidget {
  /// Creates a date field; null [onChanged] renders it read-only.
  const StringDateField({
    this.value,
    this.title,
    this.onChanged,
    this.error,
    this.helpText,
    this.required = false,
    this.examples,
    super.key,
  });

  /// ISO 8601 date, e.g. "2026-07-20".
  final String? value;

  /// The field label.
  final String? title;

  /// Receives the picked ISO date (an empty string when cleared); null
  /// disables the field.
  final void Function(String value)? onChanged;

  /// Validation message; replaces [helpText] while non-empty.
  final String? error;

  /// Helper text under the field.
  final String? helpText;

  /// Marks the label with the required asterisk and hides the clear button.
  final bool required;

  /// Values offered in the examples dropdown (the suffix arrow button).
  final List<String>? examples;

  @override
  State<StringDateField> createState() => _StringDateFieldState();
}

class _StringDateFieldState extends State<StringDateField> with ExamplesDropdownMixin<String, StringDateField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.value ?? '';
  }

  @override
  void didUpdateWidget(covariant StringDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.value ?? '';
    if (newText != _controller.text) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    disposeExamplesOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _selectExample(String example) {
    // setState is needed so the clear button visibility, which depends
    // on _controller.text, is recomputed immediately.
    setState(() => _controller.text = example);
    widget.onChanged?.call(example);
  }

  Future<void> _pickDate() async {
    final firstDate = DateTime(1900);
    final lastDate = DateTime(2100);

    // initialDate must fall within [firstDate, lastDate], otherwise
    // showDatePicker fails on an assert (the value may come from data
    // and be out of range).
    var initial = DateTime.tryParse(_controller.text) ?? DateTime.now();
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null || !mounted) return;
    final iso = picked.toIso8601String().split('T').first; // YYYY-MM-DD
    setState(() => _controller.text = iso);
    widget.onChanged?.call(iso);
  }

  void _clear() {
    setState(() => _controller.text = '');
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final errorsLoc = widget.error;
    final hasExamples = widget.examples != null && widget.examples!.isNotEmpty && widget.onChanged != null;

    final Widget field = CompositedTransformTarget(
      link: layerLink,
      child: TextField(
        key: fieldKey,
        controller: _controller,
        readOnly: true,
        enabled: widget.onChanged != null,
        onTap: widget.onChanged != null ? _pickDate : null,
        decoration: InputDecoration(
          label: FieldLabel(
            label: widget.title,
            isRequired: widget.required,
          ),
          hintText: 'YYYY-MM-DD',
          errorText: (errorsLoc == null || errorsLoc.isEmpty) ? null : errorsLoc,
          helperText: widget.helpText,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasExamples)
                IconButton(
                  onPressed: () => toggleExamplesDropdown(widget.examples, _selectExample),
                  icon: Icon(isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                ),
              if (!widget.required && _controller.text.isNotEmpty)
                IconButton(
                  onPressed: widget.onChanged != null ? _clear : null,
                  icon: const Icon(Icons.clear),
                ),
              IconButton(
                onPressed: widget.onChanged != null ? _pickDate : null,
                icon: const Icon(Icons.event),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: FormTheme.fieldPaddingOf(context),
      child: field,
    );
  }
}
