import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';

void main() {
  Widget buildSubject({
    String? value,
    ValueChanged<String>? onChanged,
    String? title = 'Time',
    bool required = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StringTimeField(
          value: value,
          onChanged: onChanged,
          title: title,
          required: required,
        ),
      ),
    );
  }

  group('StringTimeField', () {
    testWidgets('displays the value and is read-only (picker-driven)', (tester) async {
      await tester.pumpWidget(buildSubject(value: '13:45:00', onChanged: (_) {}));

      expect(find.text('13:45:00'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    });

    testWidgets('tapping opens the time picker; OK returns HH:mm:00', (tester) async {
      String? picked;
      await tester.pumpWidget(buildSubject(value: '13:45:00', onChanged: (v) => picked = v));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);

      // OK confirms the initial time parsed from the value.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(picked, '13:45:00');
    });

    testWidgets('a malformed value ("45:99") does not crash the picker', (tester) async {
      // Such a TimeOfDay would break the dial; the field falls back to now().
      await tester.pumpWidget(buildSubject(value: '45:99', onChanged: (_) {}));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the clear button empties the value; hidden when required', (tester) async {
      String? changed;
      await tester.pumpWidget(buildSubject(value: '13:45:00', onChanged: (v) => changed = v));

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(changed, '');

      await tester.pumpWidget(buildSubject(value: '13:45:00', onChanged: (_) {}, required: true));
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('disabled without onChanged: no picker on tap', (tester) async {
      await tester.pumpWidget(buildSubject(value: '13:45:00'));

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
    });
  });
}
