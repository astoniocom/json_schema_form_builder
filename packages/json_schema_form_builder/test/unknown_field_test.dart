// UnknownField: the read-only marker of a field no handler accepts — the
// value as plain text behind a question-mark icon, never an editor.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
// The widget itself is internal (the facade exports the handler and the
// state); tests may reach into src.
import 'package:json_schema_form_builder/src/handlers/unknown/unknown_field.dart';

void main() {
  UnknownFieldState state({
    PresenceValue<dynamic> value = const PresenceValue.absent(),
    String? title,
    Object? type,
    FieldAnnotations? annotations,
    List<ValidationError>? errors,
  }) => UnknownFieldState(
    value: value,
    variants: null,
    rootSchema: null,
    title: title,
    type: type,
    fieldAnnotations: annotations,
    errors: errors,
  );

  Widget harness(UnknownFieldState fieldState) => MaterialApp(
    localizationsDelegates: JsonFormLocalizations.localizationsDelegates,
    supportedLocales: JsonFormLocalizations.supportedLocales,
    home: Scaffold(body: UnknownField(fieldState: fieldState)),
  );

  testWidgets('renders the value as read-only text behind the question-mark marker', (tester) async {
    await tester.pumpWidget(harness(state(value: const PresenceValue('mystery'), title: 'Field')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.question_mark_outlined), findsOneWidget);
    expect(find.text('mystery'), findsOneWidget);
    expect(find.text('Field'), findsOneWidget);
    // A marker, not an editor: no editable text anywhere.
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('an absent value renders the empty decorator, a null value renders "null"', (tester) async {
    await tester.pumpWidget(harness(state(title: 'Field')));
    await tester.pumpAndSettle();
    expect(tester.widget<InputDecorator>(find.byType(InputDecorator)).isEmpty, isTrue);

    await tester.pumpWidget(harness(state(value: const PresenceValue(null), title: 'Field')));
    await tester.pumpAndSettle();
    expect(tester.widget<InputDecorator>(find.byType(InputDecorator)).isEmpty, isFalse);
    expect(find.text('null'), findsOneWidget);
  });

  testWidgets('the label falls back to the recorded dispatch type when there is no title', (tester) async {
    await tester.pumpWidget(harness(state(value: const PresenceValue('v'), type: 'vector')));
    await tester.pumpAndSettle();
    expect(find.text('vector'), findsOneWidget);

    // An explicit title wins over the type.
    await tester.pumpWidget(harness(state(value: const PresenceValue('v'), type: 'vector', title: 'Named')));
    await tester.pumpAndSettle();
    expect(find.text('Named'), findsOneWidget);
    expect(find.text('vector'), findsNothing);
  });

  testWidgets('errors and the description surface in the decoration', (tester) async {
    await tester.pumpWidget(
      harness(
        state(
          value: const PresenceValue('v'),
          title: 'Field',
          annotations: FieldAnnotations(description: 'What this is'),
          errors: [ValidationError(ValidationErrorType.custom, path: const [], details: 'boom')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('boom'), findsOneWidget);
    // The helper text is suppressed while an error is shown, so only the
    // error is asserted here; the description alone:
    await tester.pumpWidget(
      harness(
        state(
          value: const PresenceValue('v'),
          title: 'Field',
          annotations: FieldAnnotations(description: 'What this is'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('What this is'), findsOneWidget);
  });
}
