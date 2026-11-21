import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget buildSubject({
    String? value,
    ValueChanged<String>? onChanged,
    String? title = 'When',
    bool required = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StringDateTimeField(
          value: value,
          onChanged: onChanged,
          title: title,
          required: required,
        ),
      ),
    );
  }

  /// The widget's own display convention: local time as "YYYY-MM-DD HH:mm".
  /// Recomputed here so the tests stay agnostic of the machine's time zone.
  String expectedDisplay(String iso) {
    final local = DateTime.parse(iso).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  group('StringDateTimeField', () {
    testWidgets('shows the UTC ISO value as local YYYY-MM-DD HH:mm', (tester) async {
      const iso = '2024-06-15T10:30:00Z';
      await tester.pumpWidget(buildSubject(value: iso, onChanged: (_) {}));

      expect(find.text(expectedDisplay(iso)), findsOneWidget);
    });

    testWidgets('an unparseable value is shown raw instead of being lost', (tester) async {
      await tester.pumpWidget(buildSubject(value: 'not-a-date', onChanged: (_) {}));

      expect(find.text('not-a-date'), findsOneWidget);
    });

    testWidgets('date picker then time picker; OK-OK returns the UTC ISO round-trip', (tester) async {
      // Confirming both pickers without changes recombines the same local
      // date/time; seconds are dropped by the picker flow, the source value
      // carries none, so the round-trip is exact (and time-zone agnostic).
      const iso = '2024-06-15T10:30:00Z';
      String? picked;
      await tester.pumpWidget(buildSubject(value: iso, onChanged: (v) => picked = v));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(picked, '2024-06-15T10:30:00.000Z');
    });

    testWidgets('cancelling the date picker changes nothing', (tester) async {
      String? picked;
      await tester.pumpWidget(buildSubject(value: '2024-06-15T10:30:00Z', onChanged: (v) => picked = v));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(picked, isNull);
      expect(find.byType(TimePickerDialog), findsNothing);
    });

    testWidgets('the clear button empties the value; hidden when required', (tester) async {
      String? changed;
      await tester.pumpWidget(buildSubject(value: '2024-06-15T10:30:00Z', onChanged: (v) => changed = v));

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(changed, '');

      await tester.pumpWidget(buildSubject(value: '2024-06-15T10:30:00Z', onChanged: (_) {}, required: true));
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('disabled without onChanged: no picker on tap', (tester) async {
      await tester.pumpWidget(buildSubject(value: '2024-06-15T10:30:00Z'));

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    });
  });
}
