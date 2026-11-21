import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget buildSubject({
    String? value,
    ValueChanged<String>? onChanged,
    String? title = 'Name',
    String? error,
    String? helpText,
    List<String>? examples,
    bool required = false,
    int? maxLength,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StringField(
          value: value,
          onChanged: onChanged,
          title: title,
          error: error,
          helpText: helpText,
          examples: examples,
          required: required,
          maxLength: maxLength,
        ),
      ),
    );
  }

  group('StringField', () {
    testWidgets('displays the initial value', (tester) async {
      await tester.pumpWidget(buildSubject(value: 'hello'));

      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('typing calls onChanged with the raw text (empty included)', (tester) async {
      final changes = <String>[];

      await tester.pumpWidget(buildSubject(onChanged: changes.add));

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pumpAndSettle();
      expect(changes, ['abc']);

      // Clearing is a legal string value, not an intermediate state.
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(changes, ['abc', '']);
    });

    testWidgets('an external value update reaches the controller', (tester) async {
      await tester.pumpWidget(buildSubject(value: 'first'));
      await tester.pumpWidget(buildSubject(value: 'second'));

      expect(find.text('second'), findsOneWidget);
      expect(find.text('first'), findsNothing);
    });

    testWidgets('the parent echoing the value back does not reset the cursor mid-typing', (tester) async {
      // The regression TextValueSyncMixin exists for: parent stores the
      // value and rebuilds on every keystroke.
      String? stored;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => buildSubject(
            value: stored,
            onChanged: (v) => setState(() => stored = v),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pumpAndSettle();

      final controller = tester.widget<TextField>(find.byType(TextField)).controller!;
      expect(controller.text, 'ab');
      expect(stored, 'ab');
    });

    testWidgets('helper text is shown; an error replaces it (Material contract)', (tester) async {
      await tester.pumpWidget(buildSubject(helpText: 'a hint'));
      expect(find.text('a hint'), findsOneWidget);

      await tester.pumpWidget(buildSubject(error: 'bad value', helpText: 'a hint'));
      // The helper-to-error swap is animated; the helper leaves after it.
      await tester.pumpAndSettle();
      expect(find.text('bad value'), findsOneWidget);
      expect(find.text('a hint'), findsNothing);
    });

    testWidgets('selecting an example writes the value and calls onChanged', (tester) async {
      String? updated;
      await tester.pumpWidget(
        buildSubject(examples: ['foo', 'bar'], onChanged: (v) => updated = v),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('bar'));
      await tester.pumpAndSettle();

      expect(updated, 'bar');
      expect(find.text('bar'), findsOneWidget);
    });

    testWidgets('disabled without onChanged; the examples button is hidden', (tester) async {
      await tester.pumpWidget(buildSubject(value: 'x', examples: ['a']));

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('maxLength is enforced by the field', (tester) async {
      await tester.pumpWidget(buildSubject(onChanged: (_) {}, maxLength: 3));

      await tester.enterText(find.byType(TextField), 'abcdef');
      await tester.pumpAndSettle();

      final controller = tester.widget<TextField>(find.byType(TextField)).controller!;
      expect(controller.text, 'abc');
    });
  });
}
