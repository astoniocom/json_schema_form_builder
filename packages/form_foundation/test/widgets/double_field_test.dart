import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  /// Helper method for wrapping the widget in MaterialApp and Scaffold
  Widget buildSubject({
    double? value,
    ValueChanged<double?>? onChanged,
    String? title = 'Number',
    String? error,
    String? helpText,
    List<num>? examples,
    bool required = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DoubleField(
          value: value,
          onChanged: onChanged,
          title: title,
          error: error,
          helpText: helpText,
          examples: examples,
          required: required,
        ),
      ),
    );
  }

  group('DoubleField Tests', () {
    testWidgets('Displays the initial double value', (tester) async {
      await tester.pumpWidget(buildSubject(value: 3.15));

      expect(find.text('3.15'), findsOneWidget);
    });

    testWidgets('Automatically replaces a comma with a dot on input', (tester) async {
      double? updatedValue;

      await tester.pumpWidget(
        buildSubject(
          onChanged: (val) => updatedValue = val,
        ),
      );

      final textField = find.byType(TextFormField);
      await tester.enterText(textField, '3,15');
      await tester.pumpAndSettle();

      // Check that the comma in the text field was replaced with a dot
      expect(find.text('3.15'), findsOneWidget);
      // Check that the callback received the parsed number
      expect(updatedValue, 3.15);
    });

    testWidgets('Correctly handles negative number input', (tester) async {
      double? updatedValue;

      await tester.pumpWidget(
        buildSubject(
          onChanged: (val) => updatedValue = val,
        ),
      );

      final textField = find.byType(TextFormField);
      await tester.enterText(textField, '-42.5');
      await tester.pumpAndSettle();

      expect(find.text('-42.5'), findsOneWidget);
      expect(updatedValue, -42.5);
    });

    testWidgets(
      'Preserves intermediate state ("-", "3.", "-3.") without being reset by the parent widget',
      (tester) async {
        double? updatedValue;

        // Create the widget with a StatefulBuilder to simulate a parent update
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return buildSubject(
                value: updatedValue,
                onChanged: (val) {
                  setState(() {
                    updatedValue = val;
                  });
                },
              );
            },
          ),
        );

        final textField = find.byType(TextFormField);

        // 1. Check the intermediate input of a lone minus sign "-"
        await tester.enterText(textField, '-');
        await tester.pumpAndSettle();

        expect(find.text('-'), findsOneWidget);
        expect(updatedValue, isNull); // '-' does not parse into a double

        // 2. Extend it to a number with a trailing dot "3."
        await tester.enterText(textField, '3.');
        await tester.pumpAndSettle();

        expect(find.text('3.'), findsOneWidget);
        expect(updatedValue, 3.0);

        // 3. Append the fractional part "3.5"
        await tester.enterText(textField, '3.5');
        await tester.pumpAndSettle();

        expect(find.text('3.5'), findsOneWidget);
        expect(updatedValue, 3.5);
      },
    );

    testWidgets('Blocks input of invalid characters (letters, double dots)', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          onChanged: (_) {},
        ),
      );

      final textField = find.byType(TextFormField);

      // Try to enter text with letters and two dots
      await tester.enterText(textField, '3.1.4abc');
      await tester.pumpAndSettle();

      // The formatter must reject the invalid value and stop input at the first valid part
      expect(find.text('3.1.4abc'), findsNothing);
    });

    testWidgets('Selecting a value from the examples list (examples dropdown)', (tester) async {
      double? updatedValue;
      final examples = [3.14, 2.71, -10];

      await tester.pumpWidget(
        buildSubject(
          examples: examples,
          onChanged: (val) => updatedValue = val,
        ),
      );

      // Check that the dropdown icon is present
      final dropdownButton = find.byType(IconButton);
      expect(dropdownButton, findsOneWidget);

      // Open the examples overlay
      await tester.tap(dropdownButton);
      await tester.pumpAndSettle();

      // Find the "-10" example and tap it
      final exampleOption = find.text('-10');
      expect(exampleOption, findsOneWidget);

      await tester.tap(exampleOption);
      await tester.pumpAndSettle();

      // Check that the controller text and the callback value were updated
      expect(find.text('-10'), findsOneWidget);
      expect(updatedValue, -10.0);
    });

    testWidgets('A huge number is shown in e-notation and stays editable', (tester) async {
      double? updatedValue;
      double? value = 123123234234234234233242344123123123120.0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildSubject(
              value: value,
              onChanged: (val) {
                setState(() {
                  updatedValue = val;
                  value = val;
                });
              },
            );
          },
        ),
      );

      expect(find.text('1.2312323423423423e+38'), findsOneWidget);

      final textField = find.byType(TextFormField);

      // An intermediate state with a truncated exponent is not reset.
      await tester.enterText(textField, '2.5e');
      await tester.pumpAndSettle();
      expect(find.text('2.5e'), findsOneWidget);

      await tester.enterText(textField, '2.5e+38');
      await tester.pumpAndSettle();

      expect(find.text('2.5e+38'), findsOneWidget);
      expect(updatedValue, 2.5e38);
    });

    testWidgets('Digit limits: >18 mantissa digits and >3 exponent digits are rejected', (tester) async {
      await tester.pumpWidget(buildSubject(onChanged: (_) {}));

      final textField = find.byType(TextFormField);

      // 19 mantissa digits: the input is rejected entirely, the field is empty.
      await tester.enterText(textField, '1234567890123456789');
      await tester.pumpAndSettle();
      expect(find.text('1234567890123456789'), findsNothing);

      // 4 exponent digits are rejected; 3 (with a dot and a sign) pass.
      await tester.enterText(textField, '1.5e+3081');
      await tester.pumpAndSettle();
      expect(find.text('1.5e+3081'), findsNothing);

      await tester.enterText(textField, '1.5e+308');
      await tester.pumpAndSettle();
      expect(find.text('1.5e+308'), findsOneWidget);
    });

    testWidgets('Widget is disabled when onChanged == null', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          value: 10,
          examples: [10, 20],
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);

      // The examples button must not be displayed if the field is non-interactive
      expect(find.byType(IconButton), findsNothing);
    });
  });
}
