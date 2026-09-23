import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/src/widgets/field_label.dart';

void main() {
  Widget buildSubject({
    String? label,
    bool isRequired = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: FieldLabel(
          label: label,
          isRequired: isRequired,
        ),
      ),
    );
  }

  group('LabelWidget Tests', () {
    testWidgets('Displays plain label text without an asterisk', (tester) async {
      await tester.pumpWidget(buildSubject(label: 'Name'));

      expect(
        find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == 'Name',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Adds a red asterisk when isRequired = true', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          label: 'Phone',
          isRequired: true,
        ),
      );

      // The title and the asterisk are rendered as separate Text widgets in a Row
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('*'), findsOneWidget);

      // Check the asterisk color
      final starWidget = tester.widget<Text>(find.text('*'));
      final starContext = tester.element(find.text('*'));
      expect(
        starWidget.style?.color,
        Theme.of(starContext).colorScheme.error,
      );
    });

    testWidgets('Correctly handles a null label value without isRequired', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(RichText), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('Displays only the asterisk when label == null but isRequired = true', (tester) async {
      await tester.pumpWidget(buildSubject(isRequired: true));

      expect(find.text('*'), findsOneWidget);
    });

    testWidgets('Correctly handles an empty string in label', (tester) async {
      await tester.pumpWidget(buildSubject(label: ''));

      expect(find.byType(RichText), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}
