import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';

/// Tests of the turnkey [JsonSchemaForm] widget: the schema renders without
/// any host-side pipeline, edits flow out through onChanged, and the reported
/// state carries the validation verdict.
void main() {
  final personSchema = Schema.fromMap({
    'title': 'Person',
    'type': 'object',
    'required': ['name'],
    'properties': {
      'name': {'type': 'string', 'title': 'Name', 'minLength': 1},
      'age': {'type': 'integer', 'title': 'Age', 'minimum': 0},
    },
  });

  Widget harness(Widget child) {
    return MaterialApp(
      localizationsDelegates: JsonFormLocalizations.localizationsDelegates,
      supportedLocales: JsonFormLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  testWidgets('renders the fields declared by the schema', (tester) async {
    await tester.pumpWidget(harness(JsonSchemaForm(schema: personSchema)));
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsWidgets);
    expect(find.text('Age'), findsWidgets);
  });

  testWidgets('reports edits and the validation verdict through onChanged', (tester) async {
    JsonFieldState<Schema>? lastState;
    await tester.pumpWidget(
      harness(
        JsonSchemaForm(
          schema: personSchema,
          onChanged: (state) => lastState = state,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The initial build already reported a state: the required "name" is
    // missing, so a submit gate on isValid is closed from the start.
    expect(lastState, isNotNull);
    expect(lastState!.isValid, isFalse);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ada');
    await tester.pumpAndSettle();

    expect(lastState!.valueOrNull, {'name': 'Ada'});
    expect(lastState!.isValid, isTrue);
  });

  testWidgets('validateOnChange: false defers validation to validate()', (tester) async {
    final formKey = GlobalKey<JsonSchemaFormState>();
    JsonFieldState<Schema>? lastState;
    await tester.pumpWidget(
      harness(
        JsonSchemaForm(
          key: formKey,
          schema: personSchema,
          validateOnChange: false,
          onChanged: (state) => lastState = state,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Neither the initial build nor edits run validation in this mode.
    expect(lastState!.isValidated, isFalse);
    await tester.enterText(find.widgetWithText(TextField, 'Age'), '5');
    await tester.pumpAndSettle();
    expect(lastState!.isValidated, isFalse);

    // The required "name" is missing: on-demand validation reports it.
    final invalidVerdict = await formKey.currentState!.validate();
    await tester.pumpAndSettle();
    expect(invalidVerdict, isFalse);
    expect(lastState!.hasErrors, isTrue);

    // The next edit drops the stale verdict (on-demand convention) ...
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ada');
    await tester.pumpAndSettle();
    expect(lastState!.isValidated, isFalse);

    // ... and re-validating the fixed value passes.
    final validVerdict = await formKey.currentState!.validate();
    await tester.pumpAndSettle();
    expect(validVerdict, isTrue);
    expect(lastState!.isValid, isTrue);
  });

  testWidgets('validate() follows the registry validation mode for a validator-rejected schema', (tester) async {
    // `pattern: '['` makes json_schema_builder throw instead of returning a
    // verdict — the "validator rejected the schema" situation.
    final throwingSchema = Schema.fromMap({'type': 'string', 'pattern': '['});

    for (final (mode, expected) in [(SchemaValidationMode.strict, false), (SchemaValidationMode.lenient, true)]) {
      final formKey = GlobalKey<JsonSchemaFormState>();
      await tester.pumpWidget(
        harness(
          JsonSchemaForm(
            key: formKey,
            schema: throwingSchema,
            registry: standardJsonHandlerRegistry(validationMode: mode),
            initialValue: const PresenceValue('x'),
            validateOnChange: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The same gate as the edit dialogs' OK buttons: an unprocessable
      // schema blocks the whole form only under strict.
      final verdict = await formKey.currentState!.validate();
      await tester.pumpAndSettle();
      expect(verdict, expected, reason: '$mode');
    }
  });

  group('empty schema (no type constraints)', () {
    // An empty schema admits any JSON value — the extreme of a union type
    // list — so instead of the dead-end read-only unknown field the form
    // offers the regular Variant switcher with a branch per JSON type
    // (see synthesizedTypeBranchSchemas).
    testWidgets('an absent value shows the all-types switcher instead of a dead end', (tester) async {
      JsonFieldState<Schema>? lastState;
      await tester.pumpWidget(
        harness(JsonSchemaForm(schema: Schema.fromMap({}), onChanged: (state) => lastState = state)),
      );
      await tester.pumpAndSettle();

      // No branch is pre-selected (the absent value matches none): the
      // switcher shows its hint.
      expect(find.text('Select an option'), findsOneWidget);

      await tester.tap(find.text('Select an option'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('string').last);
      await tester.pumpAndSettle();

      // Picking a branch does not write yet (an untouched branch stays
      // absent, matching the union-type behavior) ...
      expect(lastState!.hasValue, isFalse);

      // ... the first edit in the branch editor does.
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pumpAndSettle();
      expect(lastState!.valueOrNull, 'hello');
    });

    testWidgets('the object branch offers the add-property button', (tester) async {
      await tester.pumpWidget(harness(JsonSchemaForm(schema: Schema.fromMap({}), onChanged: (_) {})));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select an option'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('object').last);
      await tester.pumpAndSettle();

      // The branch schema carries an explicit additionalProperties: true, so
      // the object editor is not a dead end even under the strict
      // requireExplicitAdditionalProperties policy.
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('a container value renders its editor once, inside the selected branch', (tester) async {
      await tester.pumpWidget(
        harness(
          JsonSchemaForm(
            schema: Schema.fromMap({}),
            initialValue: const PresenceValue([1, 2, 3]),
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The array branch is pre-selected and its editor shows the items —
      // exactly once: the base array editor must not render alongside the
      // switcher (the variants are complete alternatives, not refinements).
      expect(find.widgetWithText(TextField, '2'), findsOneWidget);
    });

    testWidgets('removing a property inside the object branch removes it from the value', (tester) async {
      JsonFieldState<Schema>? lastState;
      await tester.pumpWidget(
        harness(
          JsonSchemaForm(
            schema: Schema.fromMap({}),
            initialValue: const PresenceValue({'a': 1, 'b': 2}),
            onChanged: (state) => lastState = state,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A synthesized branch edits the whole value, so its write replaces
      // the value wholesale; the anyOf merge semantics would make the
      // removal invisible (the key just vanishes from the branch children).
      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();

      expect(lastState!.valueOrNull, {'b': 2});
    });

    testWidgets('an integer value pre-selects the integer branch of the switcher', (tester) async {
      await tester.pumpWidget(
        harness(JsonSchemaForm(schema: Schema.fromMap({}), initialValue: const PresenceValue(7), onChanged: (_) {})),
      );
      await tester.pumpAndSettle();

      // 7 satisfies both the integer and the number branches; the tie
      // resolves to the first in branch order — integer (index 1, after
      // string).
      expect(tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>)).value, 1);
      expect(find.widgetWithText(TextField, '7'), findsOneWidget);
    });
  });

  testWidgets('a declared anyOf of arrays renders the item rows once, inside the selected branch', (tester) async {
    await tester.pumpWidget(
      harness(
        JsonSchemaForm(
          schema: Schema.fromMap({
            'anyOf': [
              {
                'type': 'array',
                'items': {'type': 'string'},
              },
              {
                'type': 'array',
                'items': {'type': 'number'},
              },
            ],
          }),
          initialValue: const PresenceValue(['hello']),
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The base list editor must not render alongside the switcher: an
    // array branch renders every element itself, so the item (and its
    // remove button) appears exactly once.
    expect(find.widgetWithText(TextField, 'hello'), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
  });

  testWidgets('replacing the schema rebuilds the form and keeps the value', (tester) async {
    final renamedSchema = Schema.fromMap({
      'type': 'object',
      'properties': {
        'name': {'type': 'string', 'title': 'Full name'},
      },
    });

    Widget form(Schema schema) => harness(JsonSchemaForm(schema: schema, onChanged: (_) {}));

    await tester.pumpWidget(form(personSchema));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ada');
    await tester.pumpAndSettle();

    await tester.pumpWidget(form(renamedSchema));
    await tester.pumpAndSettle();

    // The new schema's label is used and the typed value survived.
    expect(find.text('Full name'), findsWidgets);
    expect(find.text('Ada'), findsWidgets);
  });
}
