import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation_example/main.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('renders the hand-composed form and validates the name', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    // Fields composed in main.dart are on screen.
    expect(find.text('Name'), findsWidgets);
    expect(find.text('Age'), findsWidgets);
    expect(find.text('Phones'), findsWidgets);

    // The empty name is reported both inline and in the errors panel,
    // and gates the submit button.
    expect(find.text('Name is required'), findsNWidgets(2));
    final submit = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit'));
    expect(submit.onPressed, isNull);

    // Filling the name clears the errors and unlocks the submit button.
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ada');
    // pumpAndSettle: the decorator's error text fades out with an animation.
    await tester.pumpAndSettle();
    expect(find.text('Name is required'), findsNothing);
    final submitAfter = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit'));
    expect(submitAfter.onPressed, isNotNull);
  });

  testWidgets('the add button appends a phone row, the bin removes it', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Phone 1'), findsNothing);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('Phone 1'), findsWidgets);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();
    expect(find.text('Phone 1'), findsNothing);
  });
}
