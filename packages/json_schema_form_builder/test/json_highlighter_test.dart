// The editor tabs feed highlightJson into an editable TextField, which
// requires the spans to carry exactly the source text whatever the input is:
// while typing, the text is malformed JSON most of the time.
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TextSpan highlight(String text, {Brightness brightness = Brightness.light}) =>
      highlightJson(text, brightness: brightness);

  Set<Color> colorsOf(TextSpan span) {
    final colors = <Color>{};
    span.visitChildren((child) {
      final color = child.style?.color;
      if (color != null) colors.add(color);
      return true;
    });
    return colors;
  }

  Color? colorOfFragment(TextSpan span, String fragment) {
    Color? found;
    span.visitChildren((child) {
      if (child is TextSpan && child.text == fragment) {
        found = child.style?.color;
        return false;
      }
      return true;
    });
    return found;
  }

  test('spans are lossless on any input', () {
    const inputs = [
      '',
      '{"a": [1, true, "x"], "b": null}',
      '{\n  "pretty": -1.2e+3,\n  "flag": false\n}',
      // Malformed drafts a user goes through while typing.
      '{"unterminated: "string',
      r'{"a": "trailing backslash \',
      r'"quote inside \" and out"',
      '{"a": tru',
      'random text, not json at all',
      '{"emoji": "🙂🙂", "кириллица": 42}',
      '"key on the next line"\n  : 1',
    ];
    for (final input in inputs) {
      expect(highlight(input).toPlainText(), input, reason: 'lossy on: $input');
    }
  });

  test('keys, string values, numbers and keywords get distinct colors', () {
    final span = highlight('{"key": "value", "n": 12.5, "flag": true}');

    final key = colorOfFragment(span, '"key"');
    final value = colorOfFragment(span, '"value"');
    final number = colorOfFragment(span, '12.5');
    final keyword = colorOfFragment(span, 'true');

    expect([key, value, number, keyword], everyElement(isNotNull));
    expect({key, value, number, keyword}.length, 4);
  });

  test('a word containing a keyword is not colored as one', () {
    final span = highlight('nullable');
    expect(colorsOf(span), isEmpty);
    expect(span.toPlainText(), 'nullable');
  });

  test('dark and light palettes differ', () {
    const code = '{"a": 1}';
    final light = colorsOf(highlight(code));
    final dark = colorsOf(highlight(code, brightness: Brightness.dark));
    expect(light, isNotEmpty);
    expect(light.intersection(dark), isEmpty);
  });
}
