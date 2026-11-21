import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../utils/data_url.dart';
import 'field_label.dart';
import 'form_theme.dart';

/// A file picked by a [DataUrlFilePicker].
///
/// The package deliberately carries no file-picking plugin: the host
/// application supplies a picker (e.g. built on `file_selector`) and this
/// widget encodes the result into a data URL.
class PickedFileData {
  /// Creates the picker result.
  const PickedFileData({
    required this.name,
    required this.bytes,
    this.mimeType,
  });

  /// The file name, stored in the data URL's `name` parameter.
  final String name;

  /// The file content, base64-encoded into the data URL payload.
  final Uint8List bytes;

  /// Falls back to application/octet-stream when null or empty.
  final String? mimeType;
}

/// Returns the picked file, or null when the user cancelled the dialog.
typedef DataUrlFilePicker = Future<PickedFileData?> Function();

/// A field for JSON Schema strings with `format: "data-url"`.
///
/// The value is a data URL in the react-jsonschema-form flavor
/// (`data:<mime>;name=<urlencoded name>;base64,<payload>`); the widget shows
/// the decoded file name and size instead of the raw string.
class StringDataUrlField extends StatefulWidget {
  /// Creates a data-url field; picking needs both [onChanged] and [pickFile].
  const StringDataUrlField({
    this.value,
    this.title,
    this.onChanged,
    this.pickFile,
    this.error,
    this.helpText,
    this.required = false,
    this.noFileSelectedHint = 'No file selected',
    super.key,
  });

  /// The current data URL, or null/empty when no file is selected.
  final String? value;

  /// The field label.
  final String? title;

  /// Receives the encoded data URL; an empty string means "cleared".
  final void Function(String value)? onChanged;

  /// Host-supplied picker; when null the pick button is disabled.
  final DataUrlFilePicker? pickFile;

  /// Validation message; replaces [helpText] while non-empty.
  final String? error;

  /// Helper text under the field.
  final String? helpText;

  /// Marks the label with the required asterisk.
  final bool required;

  /// Hint shown while no file is selected. A parameter (with an English
  /// default) rather than a localization lookup: this package's widgets are
  /// presentation primitives and receive all their strings from the caller.
  final String noFileSelectedHint;

  @override
  State<StringDataUrlField> createState() => _StringDataUrlFieldState();
}

class _StringDataUrlFieldState extends State<StringDataUrlField> {
  final _controller = TextEditingController();

  bool get _canPick => widget.onChanged != null && widget.pickFile != null;

  @override
  void initState() {
    super.initState();
    _controller.text = _displayText(widget.value);
  }

  @override
  void didUpdateWidget(covariant StringDataUrlField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = _displayText(widget.value);
    if (newText != _controller.text) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _displayText(String? value) {
    if (value == null || value.isEmpty) return '';

    final parsed = DataUrl.tryParse(value);
    if (parsed == null) {
      // Not a data URL: show a truncated raw value so bad data stays visible.
      return value.length <= 40 ? value : '${value.substring(0, 40)}…';
    }

    final name = parsed.name ?? parsed.mimeType;
    return '$name (${_formatSize(parsed.byteLength)})';
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pick() async {
    final picked = await widget.pickFile!();
    if (picked == null || !mounted) return;

    final encoded = DataUrl.encode(
      bytes: picked.bytes,
      name: picked.name,
      mimeType: picked.mimeType,
    );
    setState(() => _controller.text = _displayText(encoded));
    widget.onChanged?.call(encoded);
  }

  void _clear() {
    setState(() => _controller.text = '');
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final errorsLoc = widget.error;

    final field = TextField(
      controller: _controller,
      readOnly: true,
      enabled: widget.onChanged != null,
      onTap: _canPick ? _pick : null,
      decoration: InputDecoration(
        label: FieldLabel(
          label: widget.title,
          isRequired: widget.required,
        ),
        hintText: widget.noFileSelectedHint,
        errorText: (errorsLoc == null || errorsLoc.isEmpty) ? null : errorsLoc,
        helperText: widget.helpText,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.required && _controller.text.isNotEmpty)
              IconButton(
                onPressed: widget.onChanged != null ? _clear : null,
                icon: const Icon(Icons.clear),
              ),
            IconButton(
              onPressed: _canPick ? _pick : null,
              icon: const Icon(Icons.attach_file),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: FormTheme.fieldPaddingOf(context),
      child: field,
    );
  }
}
