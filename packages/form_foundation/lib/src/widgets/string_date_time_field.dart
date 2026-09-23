import 'package:flutter/material.dart';

import 'common/examples_dropdown_mixin.dart';
import 'field_label.dart';
import 'form_theme.dart';

/// Widget for a string field with format: "date-time" (RFC 3339 / ISO 8601).
///
/// Stores and exposes the value in UTC ISO 8601, e.g.
/// "2026-07-20T14:30:00.000Z", while showing the user the
/// date/time in the local time zone in a human-readable form.
class StringDateTimeField extends StatefulWidget {
  /// Creates a date-time field; null [onChanged] renders it read-only.
  const StringDateTimeField({
    this.value,
    this.title,
    this.onChanged,
    this.error,
    this.helpText,
    this.required = false,
    this.examples,
    super.key,
  });

  /// ISO 8601 date-time, e.g. "2026-07-20T14:30:00Z"
  final String? value;

  /// The field label.
  final String? title;

  /// Receives the picked moment as a UTC ISO 8601 string (an empty string
  /// when cleared); null disables the field.
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
  State<StringDateTimeField> createState() => _StringDateTimeFieldState();
}

class _StringDateTimeFieldState extends State<StringDateTimeField> with ExamplesDropdownMixin<String, StringDateTimeField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncControllerFromValue(widget.value);
  }

  @override
  void didUpdateWidget(covariant StringDateTimeField oldWidget) {
    if (widget.value != oldWidget.value) {
      _syncControllerFromValue(widget.value);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    disposeExamplesOverlay();
    _controller.dispose();
    super.dispose();
  }

  /// Brings controller.text in line with the external ISO value.
  /// If the value doesn't parse as a date, it is shown as is (raw),
  /// so that invalid data entered externally is not lost.
  void _syncControllerFromValue(String? isoValue) {
    if (isoValue == null || isoValue.isEmpty) {
      _controller.text = '';
      return;
    }
    final parsed = DateTime.tryParse(isoValue);
    _controller.text = parsed != null ? _formatDisplay(parsed.toLocal()) : isoValue;
  }

  String _formatDisplay(DateTime local) {
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  void _selectExample(String example) {
    // setState is needed so the clear button visibility, which depends
    // on _controller.text, is recomputed immediately.
    setState(() => _syncControllerFromValue(example));
    widget.onChanged?.call(example);
  }

  Future<void> _pickDateTime() async {
    final firstDate = DateTime(1900);
    final lastDate = DateTime(2100);

    // initialDate must fall within [firstDate, lastDate], otherwise
    // showDatePicker fails on an assert (the value may come from data
    // and be out of range).
    var current = DateTime.tryParse(widget.value ?? '')?.toLocal() ?? DateTime.now();
    if (current.isBefore(firstDate)) current = firstDate;
    if (current.isAfter(lastDate)) current = lastDate;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (pickedTime == null || !mounted) return;

    final combinedLocal = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    final iso = combinedLocal.toUtc().toIso8601String();
    setState(() => _syncControllerFromValue(iso));
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
        onTap: widget.onChanged != null ? _pickDateTime : null,
        decoration: InputDecoration(
          label: FieldLabel(
            label: widget.title,
            isRequired: widget.required,
          ),
          hintText: 'YYYY-MM-DD HH:MM',
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
                onPressed: widget.onChanged != null ? _pickDateTime : null,
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
