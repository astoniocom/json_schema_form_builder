import 'package:flutter/material.dart';

/// Colors of the JSON token classes for one brightness.
///
/// The values follow the default VSCode JSON theme.
class _JsonPalette {
  const _JsonPalette({
    required this.key,
    required this.string,
    required this.number,
    required this.keyword,
  });

  final Color key;
  final Color string;
  final Color number;

  /// true / false / null.
  final Color keyword;
}

const _light = _JsonPalette(
  key: Color(0xFF0451A5),
  string: Color(0xFFA31515),
  number: Color(0xFF098658),
  keyword: Color(0xFF0000FF),
);

const _dark = _JsonPalette(
  key: Color(0xFF9CDCFE),
  string: Color(0xFFCE9178),
  number: Color(0xFFB5CEA8),
  keyword: Color(0xFF569CD6),
);

/// Highlights [text] as JSON into a [TextSpan] tree.
///
/// Built for an editable TextField, so it is lossless on any input: the
/// spans always carry exactly [text] (malformed drafts included — the user
/// types invalid JSON most of the time), only the colors differ. Punctuation
/// and anything unrecognized keep the default [style] color.
TextSpan highlightJson(String text, {required Brightness brightness, TextStyle? style}) {
  final palette = brightness == Brightness.dark ? _dark : _light;
  final spans = <TextSpan>[];
  // Start of the pending run of chars that take the default style.
  var plainStart = 0;
  var i = 0;

  void colored(int start, int end, Color color) {
    if (start > plainStart) spans.add(TextSpan(text: text.substring(plainStart, start)));
    spans.add(TextSpan(text: text.substring(start, end), style: TextStyle(color: color)));
    plainStart = end;
  }

  bool isDigit(int c) => c >= 0x30 && c <= 0x39;
  bool isWordChar(int c) => (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A) || isDigit(c) || c == 0x5F;

  while (i < text.length) {
    final c = text.codeUnitAt(i);

    // Strings; an unterminated one is colored to the end of the line.
    if (c == 0x22 /* " */) {
      final start = i;
      i++;
      while (i < text.length) {
        final d = text.codeUnitAt(i);
        if (d == 0x5C /* \ */) {
          i += 2; // The escaped char is part of the string whatever it is.
          continue;
        }
        i++;
        if (d == 0x22) break;
        if (d == 0x0A) {
          i--; // Keep the newline outside of the string token.
          break;
        }
      }
      if (i > text.length) i = text.length; // A lone '\' at the very end.
      // A string followed by a colon is a property key.
      var j = i;
      while (j < text.length && ' \t\r\n'.codeUnits.contains(text.codeUnitAt(j))) {
        j++;
      }
      final isKey = j < text.length && text.codeUnitAt(j) == 0x3A /* : */;
      colored(start, i, isKey ? palette.key : palette.string);
      continue;
    }

    // Numbers (including a leading minus and the e-notation chars).
    if (isDigit(c) || (c == 0x2D /* - */ && i + 1 < text.length && isDigit(text.codeUnitAt(i + 1)))) {
      final start = i;
      i++;
      while (i < text.length) {
        final d = text.codeUnitAt(i);
        if (!isDigit(d) && d != 0x2E /* . */ && d != 0x65 /* e */ && d != 0x45 /* E */ && d != 0x2B /* + */ && d != 0x2D /* - */) {
          break;
        }
        i++;
      }
      colored(start, i, palette.number);
      continue;
    }

    // true / false / null as standalone words.
    if (c == 0x74 /* t */ || c == 0x66 /* f */ || c == 0x6E /* n */) {
      final word = text.startsWith('true', i)
          ? 'true'
          : text.startsWith('false', i)
          ? 'false'
          : text.startsWith('null', i)
          ? 'null'
          : null;
      if (word != null) {
        final end = i + word.length;
        final leftBound = i == 0 || !isWordChar(text.codeUnitAt(i - 1));
        final rightBound = end >= text.length || !isWordChar(text.codeUnitAt(end));
        if (leftBound && rightBound) {
          colored(i, end, palette.keyword);
          i = end;
          continue;
        }
      }
    }

    i++;
  }

  if (text.length > plainStart) spans.add(TextSpan(text: text.substring(plainStart)));
  return TextSpan(style: style, children: spans);
}

/// A [TextEditingController] that renders its text through [highlightJson];
/// the light/dark palette is picked per build from the ambient theme.
///
/// Used by the RawField JSON editor and available to hosts building their
/// own JSON text fields.
class JsonHighlightingController extends TextEditingController {
  @override
  TextSpan buildTextSpan({required BuildContext context, required bool withComposing, TextStyle? style}) {
    // The composing region (IME input, e.g. dead keys) loses its underline
    // under highlighting; acceptable for a JSON editor.
    return highlightJson(text, brightness: Theme.of(context).brightness, style: style);
  }
}
