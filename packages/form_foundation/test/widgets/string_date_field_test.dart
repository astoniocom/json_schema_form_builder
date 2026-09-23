import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';

void main() {
  Widget buildSubject({
    String? value,
    ValueChanged<String>? onChanged,
    String? title = 'Date',
    bool required = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StringDateField(
          value: value,
          onChanged: onChanged,
          title: title,
          required: required,
        ),
      ),
    );
  }

  group('StringDateField', () {
    testWidgets('displays the ISO value and is read-only (picker-driven)', (tester) async {
      await tester.pumpWidget(buildSubject(value: '2024-06-15', onChanged: (_) {}));

      expect(find.text('2024-06-15'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    });

    testWidgets('tapping the field opens the date picker; OK returns the ISO date', (tester) async {
      String? picked;
      await tester.pumpWidget(buildSubject(value: '2024-06-15', onChanged: (v) => picked = v));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // OK confirms the initial date parsed from the value.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(picked, '2024-06-15');
    });

    testWidgets('an out-of-range value is clamped instead of crashing the picker', (tester) async {
      // initialDate outside [1900, 2100] fails showDatePicker's assert; the
      // field clamps it (the value may come from arbitrary data).
      await tester.pumpWidget(buildSubject(value: '1799-01-01', onChanged: (_) {}));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the clear button empties the value (optional field with a value)', (tester) async {
      String? changed;
      await tester.pumpWidget(buildSubject(value: '2024-06-15', onChanged: (v) => changed = v));

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(changed, '');
      expect(find.text('2024-06-15'), findsNothing);
    });

    testWidgets('no clear button when the field is required or empty', (tester) async {
      await tester.pumpWidget(buildSubject(value: '2024-06-15', onChanged: (_) {}, required: true));
      expect(find.byIcon(Icons.clear), findsNothing);

      await tester.pumpWidget(buildSubject(value: '', onChanged: (_) {}));
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('disabled without onChanged: no picker on tap', (tester) async {
      await tester.pumpWidget(buildSubject(value: '2024-06-15'));

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    });
  });
}
