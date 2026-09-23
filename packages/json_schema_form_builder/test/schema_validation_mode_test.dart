// The SchemaValidationMode policy: a schema the validator cannot process
// (json_schema_builder throws instead of returning a verdict) must not
// block submission unless the mode is strict, and mode none skips value
// validation entirely.
//
// The throwing schema used throughout: `pattern: '['` makes the validator
// throw a FormatException (unterminated character class), which is exactly
// the "validator rejected the schema" situation reported by users.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
import 'package:json_schema_form_builder/src/handlers/object/object_entry_edit_dialog.dart';
import 'package:json_schema_form_builder/src/models/schema_validation_mode.dart' show validatorRejectedSchemaErrors;
import 'package:json_schema_form_builder/src/widgets/field_editor_screen.dart';

import 'helpers.dart';

final _throwingSchemaMap = {'type': 'string', 'pattern': '['};

void main() {
  group('validator-rejected-schema marker', () {
    test('the produced error is flagged and carries the exception', () {
      final errors = validatorRejectedSchemaErrors(const FormatException('boom'));

      expect(errors, hasLength(1));
      expect(errors.single.isValidatorRejectedSchema, isTrue);
      expect(errors.single.details, contains('json_schema_builder'));
      expect(errors.single.details, contains('boom'));
    });

    test('ordinary validation errors are not flagged', () async {
      final errors = await Schema.fromMap({'type': 'integer'}).validate('x');

      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.isValidatorRejectedSchema), isFalse);
    });
  });

  group('JsonHandlerRegistry.validateValue', () {
    test('a throwing schema surfaces as a flagged error (strict and lenient)', () async {
      for (final mode in [SchemaValidationMode.strict, SchemaValidationMode.lenient]) {
        final registry = standardJsonHandlerRegistry(validationMode: mode);

        final errors = await registry.validateValue(itemSchema: Schema.fromMap(_throwingSchemaMap), rootSchema: null, value: 'x');

        expect(errors, hasLength(1), reason: '$mode');
        expect(errors.single.isValidatorRejectedSchema, isTrue, reason: '$mode');
      }
    });

    test('mode none skips validation entirely', () async {
      final registry = standardJsonHandlerRegistry(validationMode: SchemaValidationMode.none);

      final errors = await registry.validateValue(itemSchema: Schema.fromMap(_throwingSchemaMap), rootSchema: null, value: 'x');

      expect(errors, isEmpty);
    });
  });

  group('JsonFieldState.isSubmittable', () {
    Future<JsonFieldState> stringState() async => (await buildRootState(buildRegistry(), Schema.fromMap({'type': 'string'}), value: const PresenceValue('x')))!;

    test('an unvalidated state is not submittable in any mode', () async {
      final state = await stringState();

      for (final mode in SchemaValidationMode.values) {
        expect(state.isSubmittable(mode), isFalse, reason: '$mode');
      }
    });

    test('a validated clean state is submittable in every mode', () async {
      final state = (await stringState()).applyErrors(const []);

      for (final mode in SchemaValidationMode.values) {
        expect(state.isSubmittable(mode), isTrue, reason: '$mode');
      }
    });

    test('a validator-rejected schema blocks only under strict', () async {
      final state = (await stringState()).applyErrors(validatorRejectedSchemaErrors(const FormatException('boom')));

      expect(state.isSubmittable(SchemaValidationMode.strict), isFalse);
      expect(state.isSubmittable(SchemaValidationMode.lenient), isTrue);
      expect(state.isSubmittable(SchemaValidationMode.none), isTrue);
    });

    test('a data error blocks under strict and lenient', () async {
      final dataErrors = await Schema.fromMap({'type': 'integer'}).validate('x');
      final state = (await stringState()).applyErrors(dataErrors);

      expect(state.isSubmittable(SchemaValidationMode.strict), isFalse);
      expect(state.isSubmittable(SchemaValidationMode.lenient), isFalse);
    });
  });

  group('entry edit dialog under a validator-rejected schema', () {
    Future<void> pumpDialog(WidgetTester tester, JsonHandlerRegistry registry) async {
      final rootSchema = Schema.fromMap({
        'type': 'object',
        'properties': {'k': _throwingSchemaMap},
      });
      final rootState = (await buildRootState(registry, rootSchema, value: const PresenceValue(<String, Object?>{})))!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ObjectEntryEditDialog(
              handlerRegistry: registry,
              displayContext: FieldDisplayContext.root(formState: rootState),
              fieldNamePatterns: const {},
              existingKey: 'k',
              schema: rootSchema as ObjectSchema,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    bool okEnabled(WidgetTester tester) => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'OK')).onPressed != null;

    Iterable<String> fieldErrors(WidgetTester tester) =>
        tester.widgetList<TextField>(find.byType(TextField)).map((w) => w.decoration?.errorText).nonNulls;

    testWidgets('strict: the error is shown and OK is blocked', (tester) async {
      await pumpDialog(tester, buildRegistry());

      expect(fieldErrors(tester).any((e) => e.contains('json_schema_builder')), isTrue);
      expect(okEnabled(tester), isFalse);
    });

    testWidgets('lenient: the error is shown but OK stays enabled', (tester) async {
      await pumpDialog(tester, standardJsonHandlerRegistry(validationMode: SchemaValidationMode.lenient));

      expect(fieldErrors(tester).any((e) => e.contains('json_schema_builder')), isTrue);
      expect(okEnabled(tester), isTrue);
    });

    testWidgets('none: no validation, no error, OK enabled', (tester) async {
      await pumpDialog(tester, standardJsonHandlerRegistry(validationMode: SchemaValidationMode.none));

      expect(fieldErrors(tester), isEmpty);
      expect(okEnabled(tester), isTrue);
    });
  });

  group('field editor screen under a validator-rejected schema', () {
    // The compact editor validates through registry.validateValue too:
    // before that a throwing schema was an unhandled async exception and a
    // permanently blocked OK, regardless of the mode.
    Future<void> pumpEditor(WidgetTester tester, JsonHandlerRegistry registry) async {
      final schema = Schema.fromMap(_throwingSchemaMap);
      final state = (await buildRootState(registry, schema, value: const PresenceValue('old')))!;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<JsonFieldState>(
                  builder: (_) => FieldEditorScreen(
                    initState: state,
                    registry: registry,
                    displayContext: FieldDisplayContext.root(formState: state),
                    fieldTitle: 'field',
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // OK is enabled only after an edit.
      await tester.enterText(find.byType(TextField), 'new');
      await tester.pumpAndSettle();
    }

    testWidgets('strict: OK does not close the editor', (tester) async {
      await pumpEditor(tester, buildRegistry());

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(FieldEditorScreen), findsOneWidget);
      final errorText = tester.widget<TextField>(find.byType(TextField)).decoration?.errorText;
      expect(errorText, contains('json_schema_builder'));
    });

    testWidgets('lenient: the error is shown but OK closes the editor', (tester) async {
      await pumpEditor(tester, standardJsonHandlerRegistry(validationMode: SchemaValidationMode.lenient));

      final errorText = tester.widget<TextField>(find.byType(TextField)).decoration?.errorText;
      expect(errorText, contains('json_schema_builder'));

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(FieldEditorScreen), findsNothing);
    });

    testWidgets('none: no error and OK closes the editor', (tester) async {
      await pumpEditor(tester, standardJsonHandlerRegistry(validationMode: SchemaValidationMode.none));

      expect(tester.widget<TextField>(find.byType(TextField)).decoration?.errorText, isNull);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(FieldEditorScreen), findsNothing);
    });
  });
}
