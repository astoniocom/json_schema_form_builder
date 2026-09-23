import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';

void main() {
  Widget buildSubject({
    dynamic value,
    String? labelText = 'Assignee',
    String? valueVerboseText,
    String? errorText,
    String? helperText,
    VoidCallback? onEdit,
    bool isRequired = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CollapsedValueField<dynamic>(
          labelText: labelText,
          value: value,
          valueVerboseText: valueVerboseText,
          errorText: errorText,
          helperText: helperText,
          onEdit: onEdit,
          isRequired: isRequired,
        ),
      ),
    );
  }

  group('CollapsedValueField', () {
    testWidgets('shows the label and the value text', (tester) async {
      await tester.pumpWidget(buildSubject(value: {'name': 'Ann'}, onEdit: () {}));

      expect(find.text('Assignee'), findsOneWidget);
      expect(find.text('{name: Ann}'), findsOneWidget);
    });

    testWidgets('valueVerboseText wins over value.toString()', (tester) async {
      await tester.pumpWidget(
        buildSubject(value: {'name': 'Ann'}, valueVerboseText: '1 field', onEdit: () {}),
      );

      expect(find.text('1 field'), findsOneWidget);
      expect(find.text('{name: Ann}'), findsNothing);
    });

    testWidgets('null and empty collections render as an empty decorator', (tester) async {
      for (final empty in [null, <Object?>[], <String, Object?>{}]) {
        await tester.pumpWidget(buildSubject(value: empty, onEdit: () {}));

        // No value text; the decorator reports isEmpty (label not floating).
        expect(tester.widget<InputDecorator>(find.byType(InputDecorator)).isEmpty, isTrue, reason: 'for $empty');
      }
    });

    testWidgets('the edit button calls onEdit', (tester) async {
      var edits = 0;
      await tester.pumpWidget(buildSubject(value: 'x', onEdit: () => edits++));

      await tester.tap(find.byIcon(Icons.edit));
      expect(edits, 1);
    });

    testWidgets('without onEdit the button and the decorator are disabled', (tester) async {
      await tester.pumpWidget(buildSubject(value: 'x'));

      expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
      expect(tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration.enabled, isFalse);
    });

    testWidgets('helper text is shown; an error replaces it (Material contract)', (tester) async {
      await tester.pumpWidget(buildSubject(value: 'x', helperText: 'hint', onEdit: () {}));
      expect(find.text('hint'), findsOneWidget);

      await tester.pumpWidget(buildSubject(value: 'x', errorText: 'required', helperText: 'hint', onEdit: () {}));
      // The helper-to-error swap is animated; the helper leaves after it.
      await tester.pumpAndSettle();
      expect(find.text('required'), findsOneWidget);
      expect(find.text('hint'), findsNothing);
    });
  });
}
