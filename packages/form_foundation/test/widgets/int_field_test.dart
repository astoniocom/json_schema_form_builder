import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  /// Helper method for wrapping the widget in MaterialApp and Scaffold
  Widget buildSubject({
    int? value,
    ValueChanged<int?>? onChanged,
    String? title = 'Number',
    String? error,
    String? helpText,
    List<int>? examples,
    bool required = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: IntField(
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

  group('IntField Tests', () {
    testWidgets('Displays the initial int value', (tester) async {
      await tester.pumpWidget(buildSubject(value: 45));

      expect(find.text('45'), findsOneWidget);
    });

    testWidgets('Correctly handles positive integer input', (tester) async {
      int? updatedValue;

      await tester.pumpWidget(
        buildSubject(
          onChanged: (val) => updatedValue = val,
        ),
      );

      final textField = find.byType(TextFormField);
      await tester.enterText(textField, '100');
      await tester.pumpAndSettle();

      expect(find.text('100'), findsOneWidget);
      expect(updatedValue, 100);
    });

    testWidgets('Correctly handles negative number input', (tester) async {
      int? updatedValue;

      await tester.pumpWidget(
        buildSubject(
          onChanged: (val) => updatedValue = val,
        ),
      );

      final textField = find.byType(TextFormField);
      await tester.enterText(textField, '-50');
      await tester.pumpAndSettle();

      expect(find.text('-50'), findsOneWidget);
      expect(updatedValue, -50);
    });

    testWidgets(
      'Preserves intermediate state ("-") without being reset by the parent widget',
      (tester) async {
        int? updatedValue;

        // Use StatefulBuilder to simulate a parent rebuild on state updates
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

        // 1. Enter only the minus sign
        await tester.enterText(textField, '-');
        await tester.pumpAndSettle();

        // Check that the "-" sign stayed in the input even though updatedValue = null
        expect(find.text('-'), findsOneWidget);
        expect(updatedValue, isNull);

        // 2. Append digits to form the integer "-25"
        await tester.enterText(textField, '-25');
        await tester.pumpAndSettle();

        expect(find.text('-25'), findsOneWidget);
        expect(updatedValue, -25);
      },
    );

    testWidgets('Blocks input of decimal points, commas and letters', (tester) async {
      int? updatedValue;

      await tester.pumpWidget(
        buildSubject(
          onChanged: (val) => updatedValue = val,
        ),
      );

      final textField = find.byType(TextFormField);

      // Try to enter a fractional number or letters
      await tester.enterText(textField, '42.5abc,7');
      await tester.pumpAndSettle();

      // The formatter must reject invalid input
      expect(find.text('42.5abc,7'), findsNothing);
      expect(updatedValue, isNull);
    });

    testWidgets('Selecting a value from the examples list (examples dropdown)', (tester) async {
      int? updatedValue;
      final examples = [10, 20, -5];

      await tester.pumpWidget(
        buildSubject(
          examples: examples,
          onChanged: (val) => updatedValue = val,
        ),
      );

      // Check that the dropdown button is present
      final dropdownButton = find.byType(IconButton);
      expect(dropdownButton, findsOneWidget);

      // Open the examples overlay
      await tester.tap(dropdownButton);
      await tester.pumpAndSettle();

      // Find the "-5" example and select it
      final exampleOption = find.text('-5');
      expect(exampleOption, findsOneWidget);

      await tester.tap(exampleOption);
      await tester.pumpAndSettle();

      // Check the controller update and the onChanged call
      expect(find.text('-5'), findsOneWidget);
      expect(updatedValue, -5);
    });

    testWidgets('Field is disabled when onChanged == null', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          value: 10,
          examples: [10, 20],
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);

      // The examples icon must not be displayed
      expect(find.byType(IconButton), findsNothing);
    });
  });
}
