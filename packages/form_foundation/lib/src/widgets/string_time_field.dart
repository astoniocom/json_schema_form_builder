import 'package:material_ui/material_ui.dart';

import 'common/examples_dropdown_mixin.dart';
import 'field_label.dart';
import 'form_theme.dart';

/// A field for JSON Schema strings with `format: "time"`: a read-only text
/// field driven by [showTimePicker]. A malformed value from the data
/// ("45:99") falls back to the current time instead of crashing the picker.
class StringTimeField extends StatefulWidget {
  /// Creates a time field; null [onChanged] renders it read-only.
  const StringTimeField({
    this.value,
    this.title,
    this.onChanged,
    this.error,
    this.helpText,
    this.required = false,
    this.examples,
    super.key,
  });

  /// ISO 8601 time, e.g. "13:45:00".
  final String? value;

  /// The field label.
  final String? title;

  /// Receives the picked time as "HH:mm:00" (an empty string when cleared);
  /// null disables the field.
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
  State<StringTimeField> createState() => _StringTimeFieldState();
}

class _StringTimeFieldState extends State<StringTimeField> with ExamplesDropdownMixin<String, StringTimeField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.value ?? '';
  }

  @override
  void didUpdateWidget(covariant StringTimeField oldWidget) {
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

  TimeOfDay? _parseTimeOfDay(String value) {
    // Expecting "HH:mm" or "HH:mm:ss"
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    // The value comes from data and may be outside the valid ranges
    // ("45:99") — such a TimeOfDay would break the picker.
    if (hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00';
  }

  Future<void> _pickTime() async {
    final initial = _parseTimeOfDay(_controller.text) ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null || !mounted) return;
    final formatted = _formatTimeOfDay(picked);
    setState(() => _controller.text = formatted);
    widget.onChanged?.call(formatted);
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
        onTap: widget.onChanged != null ? _pickTime : null,
        decoration: InputDecoration(
          label: FieldLabel(
            label: widget.title,
            isRequired: widget.required,
          ),
          hintText: 'HH:MM:SS',
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
                onPressed: widget.onChanged != null ? _pickTime : null,
                icon: const Icon(Icons.schedule),
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
