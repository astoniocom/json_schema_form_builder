import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  group('defaultValue at document extension points', () {
    test('buildStateForNewField seeds the schema default when there is no value', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({'type': 'string', 'default': 'Chuck'});
      final resolveContext = FieldResolveContext(path: [], rootSchema: schema);
      final handler = registry.handlersForSchema(schema: schema, resolveContext: resolveContext).first;

      final state = await buildNewFieldState(registry, schema, value: const PresenceValue.absent(), handler: handler);

      expect(state.valueOrNull, 'Chuck');
    });

    test('buildStateForNewField keeps an existing value', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({'type': 'string', 'default': 'Chuck'});
      final resolveContext = FieldResolveContext(path: [], rootSchema: schema);
      final handler = registry.handlersForSchema(schema: schema, resolveContext: resolveContext).first;

      final state = await buildNewFieldState(registry, schema, value: const PresenceValue('typed'), handler: handler);

      expect(state.valueOrNull, 'typed');
    });

    test(r'buildStateForNewField collects defaults hidden behind document-local $refs in property schemas', () async {
      // End-to-end wiring of schemaSeedValue's local-$ref expansion: the
      // extension-point pipeline passes resolveContext.rootSchema, so a
      // default behind a `#/$defs/...` pointer INSIDE a property is found.
      // (The item schema's own top-level $ref is resolved by the full
      // resolver regardless; the property-level one is the fixed case.)
      final registry = buildRegistry();
      final root = Schema.fromMap({
        r'$defs': {
          'withDefault': {'type': 'string', 'default': 'New contact'},
          'contact': {
            'type': 'object',
            'properties': {
              'name': {r'$ref': r'#/$defs/withDefault'},
            },
          },
        },
        'type': 'object',
        'properties': {
          'contacts': {
            'type': 'array',
            'items': {r'$ref': r'#/$defs/contact'},
          },
        },
      });
      final itemSchema = Schema.fromMap({r'$ref': r'#/$defs/contact'});

      final state = await registry.withValidationContext(
        itemSchema: itemSchema,
        rootSchema: root,
        body: (validationContext) => registry.buildStateForNewField(
          request: FieldBuildRequest(
            value: const PresenceValue.absent(),
            schemaSource: SchemaWithContext.maybe(itemSchema, validationContext),
            resolveContext: FieldResolveContext(path: ['contacts', '0'], rootSchema: root),
          ),
        ),
      );

      expect(state.valueOrNull, {'name': 'New contact'});
    });

    test('buildStateForNewField ignores a default the handler cannot edit', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({'type': 'string', 'default': 5});
      final resolveContext = FieldResolveContext(path: [], rootSchema: schema);
      final handler = registry.handlersForSchema(schema: schema, resolveContext: resolveContext).first;

      final state = await buildNewFieldState(registry, schema, value: const PresenceValue.absent(), handler: handler);

      expect(state.hasValue, isFalse);
    });

    test('buildStateForNewField seeds the schema const', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({'type': 'string', 'const': 'pinned'});
      final resolveContext = FieldResolveContext(path: [], rootSchema: schema);
      final handler = registry.handlersForSchema(schema: schema, resolveContext: resolveContext).first;

      final state = await buildNewFieldState(registry, schema, value: const PresenceValue.absent(), handler: handler);

      // A const-pinned field is read-only, so unless the const value is
      // written at the extension point, it would stay null forever.
      expect(state.valueOrNull, 'pinned');
      expect(state.fieldAnnotations?.readOnly, isTrue);
    });

    test('buildStateForNewField seeds object property defaults recursively', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'nested': {'type': 'string', 'default': 'nested array default'},
          'noDefault': {'type': 'string'},
          'inner': {
            'type': 'object',
            'properties': {
              'deep': {'type': 'integer', 'default': 5},
            },
          },
        },
      });

      final state = await buildNewFieldState(registry, schema, value: const PresenceValue.absent());

      expect(state.valueOrNull, {
        'nested': 'nested array default',
        'inner': {'deep': 5},
      });
    });

    test('an object default wins over the property defaults on its keys', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'nested': {'type': 'string', 'default': 'nested array default'},
        },
        'default': {'nested': 'def str'},
      });

      final state = await buildNewFieldState(registry, schema, value: const PresenceValue.absent());

      expect(state.valueOrNull, {'nested': 'def str'});
    });

    test('property defaults fill the keys an object default does not cover, deeply', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'a': {'type': 'string', 'default': 'prop default'},
          'b': {'type': 'string'},
          'inner': {
            'type': 'object',
            'properties': {
              'y': {'type': 'integer', 'default': 2},
            },
          },
        },
        'default': {
          'b': 'own default',
          'extra': 'kept',
          'inner': {'x': 1},
        },
      });

      final state = await buildNewFieldState(registry, schema, value: const PresenceValue.absent());

      expect(state.valueOrNull, {
        'a': 'prop default',
        'b': 'own default',
        'extra': 'kept',
        'inner': {'x': 1, 'y': 2},
      });
    });

    test('switching an anyOf branch seeds the branch defaults and drops the old branch keys', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'age': {'type': 'integer', 'title': 'Age'},
        },
        'anyOf': [
          {
            'title': 'First method of identification',
            'properties': {
              'firstName': {'type': 'string', 'title': 'First name', 'default': 'Chuck'},
              'lastName': {'type': 'string', 'title': 'Last name'},
            },
          },
          {
            'title': 'Second method of identification',
            'properties': {
              'idCode': {'type': 'string', 'title': 'ID code'},
            },
          },
        ],
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue({'age': 25, 'idCode': 'x'})))! as ObjectFieldState;

      final variants = state.variants!;
      final updated = state.applyVariantSwitch(
        oldState: variants[1] as ObjectFieldState,
        newState: variants[0] as ObjectFieldState,
      );

      expect(updated.valueOrNull, {'age': 25, 'firstName': 'Chuck'});
    });

    test('a readOnly default (the rjsf discriminator convention) is rewritten on every switch', () async {
      final registry = buildRegistry();
      // Structurally overlapping oneOf alternatives told apart only by the
      // readOnly "name" defaults: the user cannot edit the field, so the
      // value written by the previous branch must not survive the switch
      // (matches rjsf's sanitizeDataForNewSchema).
      final schema = Schema.fromMap({
        'oneOf': [
          {
            'type': 'object',
            'properties': {
              'name': {'type': 'string', 'default': 'first_option', 'readOnly': true},
            },
          },
          {
            'type': 'object',
            'properties': {
              'name': {'type': 'string', 'default': 'second_option', 'readOnly': true},
              'flag': {'type': 'boolean', 'default': false},
            },
          },
        ],
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue({'name': 'first_option'})))! as ObjectFieldState;

      final variants = state.variants!;
      final updated = state.applyVariantSwitch(
        oldState: variants[0] as ObjectFieldState,
        newState: variants[1] as ObjectFieldState,
      );

      // "name" is overwritten by the new branch's default despite carrying a
      // value; "flag" is seeded as an ordinary empty-field default.
      expect(updated.valueOrNull, {'name': 'second_option', 'flag': false});
    });

    test('a const-pinned child (the proper discriminator) is rewritten on every switch', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'oneOf': [
          {
            'type': 'object',
            'properties': {
              'name': {'const': 'first_option'},
            },
          },
          {
            'type': 'object',
            'properties': {
              'name': {'const': 'second_option'},
              'flag': {'type': 'boolean', 'default': false},
            },
          },
        ],
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue({'name': 'first_option'})))! as ObjectFieldState;

      final variants = state.variants!;
      final updated = state.applyVariantSwitch(
        oldState: variants[0] as ObjectFieldState,
        newState: variants[1] as ObjectFieldState,
      );

      expect(updated.valueOrNull, {'name': 'second_option', 'flag': false});
    });

    test('switching to a branch with no values writes an explicit empty object', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'object',
        'anyOf': [
          {
            'properties': {
              'foo': {'type': 'string'},
            },
          },
          {
            'properties': {
              'bar': {'type': 'string'},
            },
          },
        ],
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue({'foo': 'x'})))! as ObjectFieldState;

      final variants = state.variants!;
      final updated = state.applyVariantSwitch(
        oldState: variants[0] as ObjectFieldState,
        newState: variants[1] as ObjectFieldState,
      );

      // The old branch's keys are dropped (they belong to that branch only),
      // but the deliberate choice of a branch must stay in the document: {}
      // rather than absent (rjsf-like). An absent value would remove the
      // property's key -- and turn an array item into null.
      expect(updated.value.present, isTrue);
      expect(updated.valueOrNull, <String, Object?>{});
    });
  });

  group('const keyword handling', () {
    test('a const schema builds a read-only state', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({'const': 'foo', 'title': 'Foo'});

      final state = await buildRootState(registry, schema, value: const PresenceValue.absent());

      expect(state!.fieldAnnotations?.readOnly, isTrue);
    });

    Widget buildForm(JsonHandlerRegistry registry, JsonFieldState state, void Function(JsonFieldState) onChanged) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (context) => registry
                  .handlerForField(state)
                  .buildField(
                    context: context,
                    fieldState: state,
                    displayContext: FieldDisplayContext.root(formState: state),
                    onChanged: onChanged,
                  ),
            ),
          ),
        ),
      );
    }

    testWidgets('oneOf of const alternatives: field is not editable, switching writes the const value', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'title': 'Custom select widget with options, overriding the enum titles.',
        'oneOf': [
          {'const': 'foo', 'title': 'Foo'},
          {'const': 'bar', 'title': 'Bar'},
        ],
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue('foo'), title: schema.title))!;

      JsonFieldState? updated;
      await tester.pumpWidget(buildForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      // With the scalar content hidden, the parent title is rendered by the
      // EditorGroup framing the variant switcher.
      expect(find.text('Custom select widget with options, overriding the enum titles.'), findsOneWidget);

      // The selection fully determines a const-pinned value: no field is
      // rendered below the switcher (matches react-jsonschema-form, where a
      // oneOf of consts is just a select).
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bar').last);
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.valueOrNull, 'bar');
    });

    testWidgets('oneOf of const alternatives: picking an alternative seeds the value when it is absent', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'oneOf': [
          {'const': 'foo', 'title': 'Foo'},
          {'const': 'bar', 'title': 'Bar'},
        ],
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue.absent()))!;

      JsonFieldState? updated;
      await tester.pumpWidget(buildForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      // No forced pre-selection while the value matches no alternative:
      // otherwise picking the first alternative would not fire onChanged and
      // its value could only be set by switching away and back.
      final dropdown = tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>));
      expect(dropdown.value, isNull);

      // Picking the FIRST alternative must write its const value too.
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Foo').last);
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.valueOrNull, 'foo');
    });

    testWidgets('anyOf of single-element enums: switching writes the enum value', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'title': 'Color',
        'type': 'string',
        'anyOf': [
          {
            'type': 'string',
            'enum': ['#ff0000'],
            'title': 'Red',
          },
          {
            'type': 'string',
            'enum': ['#00ff00'],
            'title': 'Green',
          },
        ],
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue('#ff0000'), title: schema.title))!;

      JsonFieldState? updated;
      await tester.pumpWidget(buildForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      // A single-element enum pins the alternative the same way const does
      // (rjsf's isConstant): only the switcher is rendered.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(DropdownMenu<dynamic>), findsNothing);

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Green').last);
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.valueOrNull, '#00ff00');
    });

    testWidgets('a non-const alternative still renders its field below the switcher', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'oneOf': [
          {'const': 'foo', 'title': 'Foo'},
          {'type': 'string', 'title': 'Custom'},
        ],
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue.absent()))!;

      JsonFieldState? updated;
      await tester.pumpWidget(buildForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom').last);
      await tester.pumpAndSettle();

      // An editable alternative needs its input field, unlike a const one.
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isTrue);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.valueOrNull, 'hello');
    });

    testWidgets('readOnly: true disables a scalar field', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({'type': 'string', 'title': 'RO', 'readOnly': true});

      final state = (await buildRootState(registry, schema, value: const PresenceValue('fixed'), title: schema.title))!;

      await tester.pumpWidget(buildForm(registry, state, (_) {}));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(
        textField.enabled,
        isFalse,
        reason: 'fieldAnnotations.readOnly must null the content callback even when the caller passes onChanged',
      );
    });
  });
}
