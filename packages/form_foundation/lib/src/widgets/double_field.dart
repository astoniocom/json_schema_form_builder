import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'common/examples_dropdown_mixin.dart';
import 'common/text_value_sync_mixin.dart';
import 'field_label.dart';
import 'form_theme.dart';

/// A double editor: a text field accepting decimal and scientific notation
/// ("1.23e+38"), with a comma tolerated as the decimal separator.
/// Intermediate input ("-", "1.") is kept in the field but reported as null
/// until it parses.
class DoubleField extends StatefulWidget {
  /// Creates a double field; null [onChanged] renders it read-only.
  const DoubleField({
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
  final double? value;

  /// Receives the parsed value on every edit (null while the text is not a
  /// number); null disables the field.
  final void Function(double? value)? onChanged;

  /// The field label.
  final String? title;

  /// Validation message; replaces [helpText] while non-empty.
  final String? error;

  /// Helper text under the field.
  final String? helpText;

  /// Values offered in the examples dropdown (the suffix arrow button).
  final List<num>? examples;

  /// Marks the label with the required asterisk.
  final bool required;

  /// External focus node; an internal one is created when null.
  final FocusNode? focusNode;

  @override
  State<DoubleField> createState() => _DoubleFieldState();
}

class _DoubleFieldState extends State<DoubleField> with ExamplesDropdownMixin<num, DoubleField>, TextValueSyncMixin<double, DoubleField> {
  // Scientific notation must be accepted: huge doubles are displayed as
  // "1.23e+38" (formatValue), and without the exponent branch the formatter
  // would reject every edit of such a field, freezing it.
  static final RegExp _numberRegex = RegExp(r'^-?\d*\.?\d*([eE][+-]?\d*)?$');
  static final RegExp _trailingZerosRegex = RegExp(r'\.?0+$');
  static final RegExp _exponentSeparatorRegex = RegExp('[eE]');
  static final RegExp _nonDigitRegex = RegExp('[^0-9]');

  /// A double keeps ~17 significant digits and its exponent fits in 3 digits
  /// (double.maxFinite is ~1.8e308): longer input cannot be represented, so
  /// it is rejected instead of silently losing precision. Counts digits, not
  /// raw length, so the sign, the dot and the exponent do not eat the budget
  /// (the old `length > 18` check made e-notation values uneditable).
  static bool _exceedsDigitLimits(String text) {
    final eIndex = text.indexOf(_exponentSeparatorRegex);
    final mantissa = eIndex < 0 ? text : text.substring(0, eIndex);
    final exponent = eIndex < 0 ? '' : text.substring(eIndex + 1);
    return mantissa.replaceAll(_nonDigitRegex, '').length > 18 || exponent.replaceAll(_nonDigitRegex, '').length > 3;
  }

  @override
  double? get fieldValue => widget.value;

  @override
  FocusNode? get externalFocusNode => widget.focusNode;

  @override
  String formatValue(double? value) {
    if (value == null) return '';
    if (value == 0) {
      return value.isNegative ? '-0' : '0';
    }

    final str = value.toString();
    if (str.contains('e') || str.contains('E')) {
      final fixed = value.toStringAsFixed(12);
      // Trailing zeros can only be stripped from decimal notation: for
      // value >= 1e21 toStringAsFixed returns the exponential form
      // ("1e+30"), and stripping zeros would corrupt the value ("1e+3").
      if (!fixed.contains('e') && fixed.contains('.') && double.tryParse(fixed) == value) {
        return fixed.replaceAll(_trailingZerosRegex, '');
      }
      return str;
    }
    return str.endsWith('.0') ? str.substring(0, str.length - 2) : str;
  }

  @override
  double? parseValue(String text) {
    if (text.isEmpty) return null;
    final normalized = text.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  @override
  bool valuesEquivalent(double? parsed, double? target) {
    if (parsed == null && target == null) return true;
    if (parsed == null || target == null) return false;
    if (parsed == target) return true;
    return (parsed - target).abs() < 1e-11;
  }

  @override
  void initState() {
    super.initState();
    initTextValueSync();
  }

  @override
  void didUpdateWidget(covariant DoubleField oldWidget) {
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

  void _selectExample(num example) {
    final doubleVal = example.toDouble();

    setControllerText(formatValue(doubleVal));

    widget.onChanged?.call(doubleVal);
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
          decimal: true,
          signed: true,
        ),
        inputFormatters: [
          TextInputFormatter.withFunction((oldValue, newValue) {
            final text = newValue.text.replaceAll(',', '.');

            if (_exceedsDigitLimits(text)) {
              return oldValue;
            }

            if (_numberRegex.hasMatch(text)) {
              final baseOffset = newValue.selection.baseOffset < 0 ? text.length : newValue.selection.baseOffset;
              final extentOffset = newValue.selection.extentOffset < 0 ? text.length : newValue.selection.extentOffset;

              return TextEditingValue(
                text: text,
                selection: TextSelection(
                  baseOffset: baseOffset.clamp(0, text.length),
                  extentOffset: extentOffset.clamp(0, text.length),
                ),
              );
            }
            return oldValue;
          }),
        ],
        decoration: InputDecoration(
          label: FieldLabel(
            label: widget.title,
            isRequired: widget.required,
          ),
          hintText: '3.14',
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
                final doubleValue = parseValue(value);
                widget.onChanged?.call(doubleValue);
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
