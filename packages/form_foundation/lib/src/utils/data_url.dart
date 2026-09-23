import 'dart:convert';

/// Parsed metadata of an RFC 2397 data URL, extended with the non-standard
/// `name` parameter used by react-jsonschema-form:
/// `data:<mime>;name=<urlencoded name>;base64,<payload>`.
class DataUrl {
  /// Creates parsed data URL metadata.
  const DataUrl({
    required this.mimeType,
    required this.byteLength,
    this.name,
  });

  /// The MIME type from the URL header (before the first `;`).
  final String mimeType;

  /// Decoded file name from the `name` parameter, if present.
  final String? name;

  /// Approximate decoded payload size in bytes.
  final int byteLength;

  /// Encodes [bytes] as a data URL compatible with react-jsonschema-form.
  static String encode({
    required List<int> bytes,
    required String name,
    String? mimeType,
  }) {
    final mime = (mimeType == null || mimeType.isEmpty) ? 'application/octet-stream' : mimeType;
    return 'data:$mime;name=${Uri.encodeComponent(name)};base64,${base64Encode(bytes)}';
  }

  /// Parses [value] as a data URL; returns null when it is not one.
  static DataUrl? tryParse(String value) {
    if (!value.startsWith('data:')) return null;
    final comma = value.indexOf(',');
    if (comma < 0) return null;

    final header = value.substring('data:'.length, comma);
    final payload = value.substring(comma + 1);
    final parts = header.split(';');

    // Per RFC 2397 an omitted media type means text/plain.
    final mime = parts.first.isNotEmpty ? parts.first : 'text/plain';

    String? name;
    var isBase64 = false;
    for (final part in parts.skip(1)) {
      if (part == 'base64') {
        isBase64 = true;
      } else if (part.startsWith('name=')) {
        final rawName = part.substring('name='.length);
        try {
          name = Uri.decodeComponent(rawName);
          // Uri.decodeComponent's documented failure mode for malformed
          // percent-encoding is ArgumentError, so catching it here is the
          // intended use of the API, not a swallowed programming error.
          // ignore: avoid_catching_errors
        } on ArgumentError {
          // Fall back to the raw value so the file stays identifiable.
          name = rawName;
        }
      }
    }

    final int byteLength;
    if (isBase64) {
      final padding = payload.endsWith('==') ? 2 : (payload.endsWith('=') ? 1 : 0);
      byteLength = payload.length * 3 ~/ 4 - padding;
    } else {
      byteLength = payload.length;
    }
    return DataUrl(mimeType: mime, name: name, byteLength: byteLength);
  }
}
