import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:form_foundation/form_foundation.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/presence_value.dart';
import 'json_highlighter.dart';

/// A plain-props JSON text editor: syntax highlighting, pretty-printing,
/// parse-on-change and a careful sync with an externally changing value.
///
/// This is the presentation half of the raw JSON editing: RawField adapts a
/// RawFieldState to it for the form pipeline, and hosts embed it directly as
/// a standalone editor (see the demo's Schema/JSON tabs) without fabricating
/// field states.
class JsonEditor extends StatefulWidget {
  /// Creates a JSON editor; null [onChanged] renders it read-only.
  const JsonEditor({
    required this.value,
    this.onChanged,
    this.title,
    this.required = false,
    this.errorText,
    this.helperText,
    this.expands = false,
    this.style,
    super.key,
  });

  /// The current JSON value; `PresenceValue.absent()` renders as an empty
  /// editor. External changes are synced into the text without clobbering an
  /// unparseable draft the user is typing right now.
  final PresenceValue<dynamic> value;

  /// Called with `PresenceValue.absent()` when the input is cleared, `PresenceValue(null)`
  /// when the user types the JSON literal `null`, and `PresenceValue(x)` otherwise.
  ///
  /// The second argument (parseError) is non-null (a localized message) when
  /// the current text is not parseable JSON; the value then still holds the
  /// last successfully parsed one. Null disables the editor.
  final void Function(PresenceValue<dynamic> value, String? parseError)? onChanged;

  /// Field label; when null the editor renders without one (hosts like the
  /// demo tabs already carry their own headings). RawField supplies the
  /// localized "Value" fallback for form fields.
  final String? title;

  /// Marks the label with the required indicator.
  final bool required;

  /// External error shown under the editor; a local parse error takes
  /// precedence while present.
  final String? errorText;

  /// Helper text under the editor, hidden while an error is shown.
  final String? helperText;

  /// When true the editor fills the available height (a full-pane JSON
  /// editor); when false it stays a compact 5-line inline field.
  final bool expands;

  /// Overrides [FormTheme.codeTextStyleOf] for this editor.
  final TextStyle? style;

  @override
  State<JsonEditor> createState() => _JsonEditorState();
}

class _JsonEditorState extends State<JsonEditor> {
  late final TextEditingController _controller;
  String? _localError;
  late PresenceValue<dynamic> _syncedValue;

  static const _encoder = JsonEncoder.withIndent(' ');

  @override
  void initState() {
    super.initState();
    _syncedValue = widget.value;
    _controller = JsonHighlightingController()..text = _textFor(_syncedValue);
  }

  String _textFor(PresenceValue<dynamic> value) => value.present ? _formatJson(value.valueOrNull) : '';

  String _formatJson(Object? value) {
    try {
      return _encoder.convert(value);
    } catch (_) {
      assert(false, 'Can not encode value: $value');
      return value?.toString() ?? '';
    }
  }

  @override
  void didUpdateWidget(covariant JsonEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentValue = widget.value;

    // Sync ONLY if the external value has actually changed (e.g. arrived
    // from outside). PresenceValue.== is presence-aware and deep.
    if (currentValue == _syncedValue) return;
    _syncedValue = currentValue;

    if (!currentValue.present) {
      if (_controller.text.isNotEmpty) {
        _controller.text = '';
        _localError = null;
      }
      return;
    }

    // An empty field is not "mid-typing invalid JSON", so it is safe to
    // overwrite it with the new external value.
    if (_controller.text.trim().isEmpty) {
      _controller.text = _formatJson(currentValue.valueOrNull);
      _localError = null;
      return;
    }

    try {
      final currentTextDecoded = jsonDecode(_controller.text);
      if (!deepEquals(currentTextDecoded, currentValue.valueOrNull)) {
        _controller.text = _formatJson(currentValue.valueOrNull);
      }
    } catch (_) {
      // Do not overwrite the text while the user is right now typing invalid JSON,
      // to avoid interrupting the input and resetting the caret.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onChangedLoc = widget.onChanged;
    final combinedError = _localError ?? widget.errorText;

    return TextFormField(
      controller: _controller,
      maxLines: widget.expands ? null : 5,
      expands: widget.expands,
      textAlignVertical: widget.expands ? TextAlignVertical.top : null,
      keyboardType: TextInputType.multiline,
      enabled: onChangedLoc != null,
      style: widget.style ?? FormTheme.codeTextStyleOf(context),
      decoration: InputDecoration(
        label: FieldLabel(
          label: widget.title,
          isRequired: widget.required,
        ),
        errorText: combinedError,
        helperText: widget.helperText,
        alignLabelWithHint: true,
        hintText: '[1, 2, 3]',
        border: const OutlineInputBorder(),
      ),
      onChanged: onChangedLoc != null
          ? (v) {
              // Empty input means "no value", not a JSON syntax error.
              if (v.trim().isEmpty) {
                _syncedValue = const PresenceValue.absent();
                onChangedLoc(const PresenceValue.absent(), null);
                if (_localError == null) return;
                setState(() {
                  _localError = null;
                });
                return;
              }

              try {
                // Try to parse the entered text
                final decoded = jsonDecode(v);
                _syncedValue = PresenceValue<dynamic>(decoded);
                onChangedLoc(_syncedValue, null);

                // If parsing succeeded, clear the local error
                if (_localError == null) return;
                setState(() {
                  _localError = null;
                });
              } catch (e) {
                // The JSON is invalid: keep the last parsed value but report
                // the parse error, so the caller (and any validity-gated UI)
                // knows the editor content is not representable yet. The
                // parser detail (position info) is appended when available.
                final label = jsonFormLocalizationsOf(context).invalidJsonError;
                final error = e is FormatException && e.message.isNotEmpty ? '$label: ${e.message}' : label;
                onChangedLoc(_syncedValue, error);
                if (_localError != null) return;
                setState(() {
                  _localError = error;
                });
              }
            }
          : null,
    );
  }
}
